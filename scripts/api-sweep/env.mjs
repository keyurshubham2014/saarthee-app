// Env-var sweep (TASK-14 §6 step 5) and throwaway API instances (health 503 with the database unreachable).
// Throwaway environments are passed to child processes in memory only — never written to disk or printed.
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { API_DIR, env, readEnvFile, sleep } from './lib.mjs';

const TSX = path.join(API_DIR, 'node_modules/.bin/tsx');
const baseEnv = () => ({ PATH: process.env.PATH, HOME: process.env.HOME, NODE_ENV: 'development' });

/** Starts `src/server.ts` with exactly `vars`; resolves when it exits or after `ms` (then kills it). */
export function runServer(vars, ms = 15_000) {
  return new Promise((resolve) => {
    const child = spawn(TSX, ['src/server.ts'], { cwd: API_DIR, env: { ...baseEnv(), ...vars }, stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (out += d));
    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      resolve({ exited: false, code: null, out });
    }, ms);
    child.on('exit', (code) => {
      clearTimeout(timer);
      resolve({ exited: true, code, out });
    });
  });
}

/** Throwaway instance on `port` for a check; returns { url, stop }. */
export async function throwaway(overrides, port) {
  const vars = { ...env, API_PORT: String(port), LOG_FILE_DIR: '', AUDIT_LOG_FILE: '', JOBS_ENABLED: 'false', ...overrides };
  const child = spawn(TSX, ['src/server.ts'], { cwd: API_DIR, env: { ...baseEnv(), ...vars }, stdio: 'ignore' });
  const url = `http://127.0.0.1:${port}/api/v1`;
  for (let i = 0; i < 60; i++) {
    const ok = await fetch(`${url}/health`).then(() => true, () => false);
    if (ok) break;
    await sleep(250);
  }
  return { url, stop: () => child.kill('SIGTERM') };
}

/** Variable names declared in src/config (the zod schema keys). */
export function configVars() {
  const src = readFileSync(path.join(API_DIR, 'src/config/index.ts'), 'utf8');
  const body = src.slice(src.indexOf('const schema = z.object({'), src.indexOf('\n});', src.indexOf('const schema = z.object({')));
  return [...body.matchAll(/^\s{2}([A-Z][A-Z0-9_]+):/gm)].map((m) => m[1]);
}

/** For each var: does parseConfig fail when it is removed from the current (valid) env? One tsx process. */
async function classify(vars) {
  const full = { ...env, API_PORT: '4202' };
  const child = spawn(TSX, [path.join(path.dirname(new URL(import.meta.url).pathname), 'config-probe.ts')], {
    cwd: API_DIR,
    env: { ...baseEnv(), ...full, __SWEEP_FULL: JSON.stringify(full), __SWEEP_VARS: JSON.stringify(vars) },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let out = '';
  child.stdout.on('data', (d) => (out += d));
  child.stderr.on('data', (d) => (out += d));
  await new Promise((r) => child.on('exit', r));
  const line = out.split('\n').find((l) => l.startsWith('__SWEEP__'));
  if (!line) throw new Error('config classification failed');
  return JSON.parse(line.slice('__SWEEP__'.length));
}

/** Rows: { name, inExample, required, startupFails, message }. Required vars are proven by a real startup. */
export async function envSweep() {
  const vars = configVars();
  const example = readEnvFile(path.join(API_DIR, '.env.example'));
  const exampleText = readFileSync(path.join(API_DIR, '.env.example'), 'utf8');
  const cls = await classify(vars);
  const rows = [];
  for (const name of vars) {
    const inExample = name in example || new RegExp(`^#\\s*${name}=`, 'm').test(exampleText);
    const required = cls[name] !== null;
    let startupFails = null;
    let message = cls[name] ?? '';
    if (required) {
      const vars2 = { ...env, API_PORT: name === 'API_PORT' ? undefined : '4202' };
      delete vars2[name];
      const r = await runServer(vars2, 20_000);
      startupFails = r.exited && r.code !== 0 && r.out.includes(`Config error: ${name}`);
      message = (r.out.split('\n').find((l) => l.includes(`Config error: ${name}`)) ?? r.out.split('\n')[0] ?? '').trim();
    }
    rows.push({ name, inExample, required, startupFails, message });
  }
  return rows;
}

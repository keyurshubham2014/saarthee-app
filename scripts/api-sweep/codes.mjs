// Error-code sweep (TASK-14 §5.3): the list comes from ERROR_CODES in apps/api/src/lib/errors. For each code: where
// it is produced (this sweep, else Vitest files) and, when user-facing, the app ARB key (en + gu) that shows it.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { API_DIR, ROOT } from './lib.mjs';

/** Codes never shown in the app: webhook-only, legacy v1 pilot/admin flows retired by D11, generic fallback. */
export const NOT_USER_FACING = {
  BAD_SIGNATURE: 'mail webhook only (server to server)',
  INVITE_CODE_INVALID: 'v1 invite codes (retired, D11)',
  INVITE_CODE_TAKEN: 'v1 invite codes (retired, D11)',
  VERIFY_TOKEN_INVALID: 'v1 verify links (retired, D11)',
  VERIFY_TOKEN_REVOKED: 'v1 verify links (retired, D11)',
  COMPLAINT_EXCLUDED: 'v1 complaints (retired, D11)',
  COMPLAINT_ANONYMIZED: 'v1 complaints (retired, D11)',
  ENDPOINT_RETIRED: 'returned to v1 app builds only',
};

/**
 * Codes no mounted route can return in the assembled app (evidence in docs/v2/api-sweep-v2.md). Reported as
 * findings; ERROR_CODES is append-only, so they are not removed here.
 */
export const UNREACHABLE = {
  INVITE_CODE_INVALID: 'only in modules/public/invite.service.ts, which no router imports (/invite-codes/validate is 410)',
  INVITE_CODE_TAKEN: 'only in v1 invite-code create (reference.service); the admin write routes are 410',
  VERIFY_TOKEN_INVALID: 'lib/verifyToken is used only by requireVerifyToken/verify.service, neither mounted (/verify is 410)',
  VERIFY_TOKEN_REVOKED: 'same as VERIFY_TOKEN_INVALID',
  COMPLAINT_EXCLUDED: 'only in modules/reminders/reminders.service.ts, which no router imports',
  COMPLAINT_ANONYMIZED: 'same as COMPLAINT_EXCLUDED',
  OUT_OF_WARD: 'superseded: the TASK-11 pre-transition hook returns WARD_OUT_OF_SCOPE before lifecycle.service can throw it',
};

export function errorCodes() {
  const src = readFileSync(path.join(API_DIR, 'src/lib/errors/index.ts'), 'utf8');
  const block = src.slice(src.indexOf('export const ERROR_CODES'), src.indexOf('} as const;'));
  return [...block.matchAll(/^\s{2}([A-Z][A-Z0-9_]+): \{ status: (\d{3})/gm)].map((m) => ({ code: m[1], status: Number(m[2]) }));
}

function walk(dir, ext, out = []) {
  for (const f of readdirSync(dir)) {
    const p = path.join(dir, f);
    if (statSync(p).isDirectory()) walk(p, ext, out);
    else if (p.endsWith(ext)) out.push(p);
  }
  return out;
}

const rel = (p) => path.relative(ROOT, p);

export function codeTable(seenCodes) {
  const tests = walk(path.join(API_DIR, 'test'), '.ts').map((p) => ({ p, s: readFileSync(p, 'utf8') }));
  const dart = walk(path.join(ROOT, 'apps/mobile/lib'), '.dart').map((p) => ({ p, lines: readFileSync(p, 'utf8').split('\n') }));
  const arbEn = JSON.parse(readFileSync(path.join(ROOT, 'apps/mobile/lib/core/l10n/app_en.arb'), 'utf8'));
  const arbGu = JSON.parse(readFileSync(path.join(ROOT, 'apps/mobile/lib/core/l10n/app_gu.arb'), 'utf8'));
  return errorCodes().map(({ code, status }) => {
    const testHits = tests.filter((t) => new RegExp(`['"\`]${code}['"\`]`).test(t.s)).map((t) => path.basename(t.p));
    const fromTests = testHits.length ? `vitest: ${testHits.slice(0, 2).join(', ')}${testHits.length > 2 ? ` +${testHits.length - 2}` : ''}` : '';
    const produced = seenCodes.get(code) ?? (code in UNREACHABLE ? `unreachable — ${UNREACHABLE[code]}` : fromTests);
    const keys = new Set();
    const files = new Set();
    for (const f of dart) {
      f.lines.forEach((line, i) => {
        if (!line.includes(`'${code}'`)) return;
        files.add(rel(f.p));
        // Scan this case body only: stop at the next `case`/`default` once a non-case line was seen.
        let body = false;
        for (let j = i; j < Math.min(i + 6, f.lines.length); j++) {
          const l = f.lines[j];
          if (j > i && /^\s*(case\b|default\b)/.test(l) && body) break;
          if (j > i && !/^\s*case\b/.test(l)) body = true;
          if (/rateLimitMessage\(/.test(l)) {
            keys.add('errorRateLimited');
            break;
          }
          const m = l.match(/\b(?:l10n|l|loc|s|t|strings)\.([a-z][A-Za-z0-9]+)\b/);
          if (m && m[1] in arbEn) {
            keys.add(m[1]);
            break;
          }
        }
      });
    }
    const userFacing = !(code in NOT_USER_FACING);
    const arb = [...keys].map((k) => `${k}${k in arbEn ? '' : ' (no en)'}${k in arbGu ? '' : ' (no gu)'}`);
    let mobile;
    if (!userFacing) mobile = `n/a — ${NOT_USER_FACING[code]}`;
    else if (arb.length) mobile = arb.join(', ');
    else if (files.size) mobile = `handled in ${[...files].slice(0, 2).join(', ')} (no direct ARB key found)`;
    else mobile = 'MISSING — falls back to the generic error message';
    const missing = userFacing && arb.length === 0 && files.size === 0;
    const arbGap = arb.some((a) => a.includes('(no '));
    return { code, status, produced: produced || 'NOT PRODUCED', mobile, missing, arbGap, indirect: userFacing && !arb.length && files.size > 0 };
  });
}

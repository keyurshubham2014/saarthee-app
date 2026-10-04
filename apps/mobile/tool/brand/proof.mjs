// Proof sheet of the docs/brand SVG family on light, primary and dark grounds.
// usage: node proof.mjs <repoRoot> <out.png>
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { chromium } from 'playwright';

const [, , root, out] = process.argv;
const b = (f) => 'file://' + join(root, 'docs/brand', f);
const grounds = [['#FFFFFF', 'light'], ['#14674A', 'primary'], ['#131C18', 'dark']];
const base = ['mark.svg', 'mark-mono.svg', 'mark-reversed.svg', 'wordmark-en.svg', 'wordmark-gu.svg'];
const suf = { light: '', primary: '-reversed', dark: '-dark' };
const rows = grounds.map(([bg, name]) => `<div class="g" style="background:${bg}"><small>${name}</small>` +
  [...base, `lockup-horizontal-en${suf[name]}.svg`, `lockup-horizontal-gu${suf[name]}.svg`].map((f) => `<figure><img src="${b(f)}" style="height:${f.startsWith('mark') ? 72 : 56}px"><figcaption>${f}</figcaption></figure>`).join('') + '</div>').join('');
const html = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;padding:16px;background:#F3F6F1;font:12px system-ui}
.g{display:flex;flex-wrap:wrap;gap:24px;align-items:flex-end;padding:18px;border-radius:14px;margin-bottom:10px}
.g small,figcaption{color:#888}figure{margin:0;display:grid;gap:4px;justify-items:start}
</style>${rows}`;
const f = join(tmpdir(), 'brand-proof.html');
writeFileSync(f, html);
const br = await chromium.launch();
const p = await br.newPage({ viewport: { width: 1400, height: 400 } });
await p.goto('file://' + f);
await p.waitForTimeout(300);
await p.screenshot({ path: out, fullPage: true });
await br.close();

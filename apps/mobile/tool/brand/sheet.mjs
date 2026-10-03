// Close-up comparison sheet for a few variants: real 256/48/24/16 px plus
// 16 px and 24 dp mono rasters scaled up with nearest-neighbour.
// usage: node sheet.mjs <out.png> D,E,F,G   (needs @resvg/resvg-js + playwright)
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Resvg } from '@resvg/resvg-js';
import { chromium } from 'playwright';
import { variants, svg, glyph } from './variants.mjs';

const [, , out, keys = 'D,E,F,G'] = process.argv;
const png = (s, w) => 'data:image/png;base64,' + new Resvg(s, { fitTo: { mode: 'width', value: w } }).render().asPng().toString('base64');

const rows = keys.split(',').map((k) => {
  const v = variants[k];
  const real = [256, 48, 24, 16].map((s) => `<img src="${png(svg(v), s)}" width="${s}">`).join('');
  const zoom16 = `<img class="px" src="${png(svg(v), 16)}" width="128">`;
  const mono = `<img class="px mono" src="${png(glyph(v, { color: '#fff' }), 24)}" width="120">`;
  return `<div class="r"><b>${v.name}</b><div class="c">${real}${zoom16}${mono}</div></div>`;
}).join('');

const html = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;padding:16px;background:#F3F6F1;font:14px system-ui}
.r{background:#fff;border-radius:16px;padding:12px;margin-bottom:10px}
.c{display:flex;gap:20px;align-items:flex-end;margin-top:6px}
.px{image-rendering:pixelated}.mono{background:#202124;padding:6px;border-radius:8px}
</style>${rows}`;
const f = join(tmpdir(), 'brand-sheet.html');
writeFileSync(f, html);
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 900, height: 400 } });
await p.goto('file://' + f);
await p.screenshot({ path: out, fullPage: true });
await b.close();

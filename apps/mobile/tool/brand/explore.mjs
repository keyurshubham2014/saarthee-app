import { writeFileSync } from 'node:fs';
import { variants, svg, glyph } from './variants.mjs';

const out = process.argv[2];
const sizes = [16, 24, 48, 120, 256];

function row(key, v, theme) {
  const cells = sizes.map((s) => `<figure><div class="m">${svg(v, { size: s })}</div><figcaption>${s} px</figcaption></figure>`).join('');
  const zoom = `<figure><canvas class="z" data-v="${key}" width="16" height="16"></canvas><figcaption>16 px raster ×6</figcaption></figure>`;
  const zoom24 = `<figure><canvas class="z" data-v="${key}" data-mono="1" width="24" height="24"></canvas><figcaption>24 dp status bar ×4</figcaption></figure>`;
  const launcher = `<figure><div class="launch">${svg(v, { size: 64 })}</div><figcaption>circle mask 64</figcaption></figure>`;
  return `<div class="row ${theme}"><div class="lab"><b>${v.name}</b><small>${v.note}</small></div><div class="cells">${cells}${zoom}${zoom24}${launcher}</div></div>`;
}

const src = Object.fromEntries(Object.entries(variants).map(([k, v]) => [k, { full: svg(v, { size: 16 }), mono: glyph(v, { size: 24, color: '#fff' }) }]));

const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Saarthee Mark Explorations</title>
<style>
:root{--pg:#F3F6F1;--card:#fff;--ink:#17251E;--mute:#4E5E55;--line:#DCE5DE}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--pg:#131C18;--card:#1A2520;--ink:#E6EFE9;--mute:#A9B9AF;--line:#2A3830}}
:root[data-theme="dark"]{--pg:#131C18;--card:#1A2520;--ink:#E6EFE9;--mute:#A9B9AF;--line:#2A3830}
*{box-sizing:border-box}
body{margin:0;padding:24px 16px 48px;background:var(--pg);color:var(--ink);font:15px/1.5 system-ui,sans-serif}
h1{font-size:1.6rem;margin:0 0 4px}h2{font-size:1.15rem;margin:28px 0 8px}
p{max-width:75ch;color:var(--mute);margin:0 0 12px}
.row{border:1px solid var(--line);border-radius:18px;padding:14px;margin-bottom:12px;display:grid;gap:10px}
.row.light{background:#FFFFFF;color:#17251E}.row.dark{background:#131C18;color:#E6EFE9}
.row.light small{color:#4E5E55}.row.dark small{color:#A9B9AF}
.lab{display:grid;gap:2px}.lab small{max-width:80ch}
.cells{display:flex;flex-wrap:wrap;align-items:flex-end;gap:18px;overflow-x:auto}
figure{margin:0;display:grid;justify-items:center;gap:4px}
figcaption{font-size:12px;opacity:.75}
.m svg{display:block}
canvas.z{image-rendering:pixelated;width:96px;height:96px;border:1px solid #8888}
canvas.z[data-mono]{background:#202124}
.launch{width:64px;height:64px;border-radius:50%;overflow:hidden;background:#14674A}
.launch svg{display:block;transform:scale(1.16)}
</style></head><body>
<h1>Saarthee mark · explorations</h1>
<p>Four refinements of the DS §1 mark (rounded square, radius 28%, primary #14674A, white route rising to the upper right, sunrise #C24A1F dot). Each row shows real sizes 16 to 256 px, a 16 px raster zoomed so the pixel grid is visible, the single-colour glyph as an Android status-bar icon (24 dp, zoomed), and a circular launcher mask. The chosen variant is <b>D</b>; see <code>README.md</code>.</p>
<h2>On light</h2>
${Object.entries(variants).map(([k, v]) => row(k, v, 'light')).join('')}
<h2>On dark</h2>
${Object.entries(variants).map(([k, v]) => row(k, v, 'dark')).join('')}
<script>
const SRC = ${JSON.stringify(src)};
for (const c of document.querySelectorAll('canvas.z')) {
  const s = SRC[c.dataset.v][c.dataset.mono ? 'mono' : 'full'];
  const img = new Image();
  img.onload = () => { const x = c.getContext('2d'); x.drawImage(img, 0, 0, c.width, c.height); };
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s);
}
</script>
</body></html>`;
writeFileSync(out, html);

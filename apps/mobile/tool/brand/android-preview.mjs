// Proof of the Android brand res: converts the generated VectorDrawables back to
// SVG (so the XML itself is what gets checked) and shows them with launcher
// masks, themed tint, status bar and splash grounds, next to the legacy PNGs.
// usage: node android-preview.mjs <repoRoot> <out.png>
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { chromium } from 'playwright';

const [, , root, out] = process.argv;
const res = join(root, 'apps/mobile/android/app/src/main/res');
const attr = (s, n) => (s.match(new RegExp(`android:${n}="([^"]*)"`)) || [])[1];
const col = (c) => (c && c.length === 9 ? '#' + c.slice(3) + c.slice(1, 3) : c); // #AARRGGBB -> #RRGGBBAA

function vec(file, tint) {
  const x = readFileSync(join(res, file), 'utf8');
  const vp = attr(x, 'viewportWidth');
  const g = x.match(/<group([^>]*)>/)[1];
  const t = `translate(${attr(g, 'translateX') || 0} ${attr(g, 'translateY') || 0}) scale(${attr(g, 'scaleX') || 1})`;
  const paths = [...x.matchAll(/<path([^>]*)\/>/g)].map(([, p]) => {
    const stroke = attr(p, 'strokeColor');
    const fill = col(attr(p, 'fillColor'));
    return `<path d="${attr(p, 'pathData')}" fill="${tint && fill !== '#00000000' ? tint : fill}" stroke="${stroke ? tint || col(stroke) : 'none'}" stroke-width="${attr(p, 'strokeWidth') || 0}" stroke-linecap="round" stroke-linejoin="round"/>`;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${vp} ${vp}"><g transform="${t}">${paths}</g></svg>`;
}
const uri = (s) => 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s);
const fg = uri(vec('drawable/ic_launcher_foreground.xml'));
const mono = (c) => uri(vec('drawable/ic_launcher_monochrome.xml', c));
const cell = (inner, cap) => `<figure>${inner}<figcaption>${cap}</figcaption></figure>`;
// Adaptive: 108 dp layer shown at 2x; mask clips to the visible 72 dp.
const adaptive = (bg, img, radius) => `<div class="ad" style="border-radius:${radius}"><div style="background:${bg}"><img src="${img}"></div></div>`;
const safe = `<div class="ad sz"><div style="background:#14674A"><img src="${fg}"><i></i></div></div>`;

const png = (p) => 'file://' + join(res, p);
const html = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;padding:16px;background:#F3F6F1;font:12px system-ui;color:#444}
.row{display:flex;flex-wrap:wrap;gap:28px;align-items:flex-end;background:#fff;border-radius:14px;padding:16px;margin-bottom:10px}
figure{margin:0;display:grid;gap:6px;justify-items:center}
.ad{width:144px;height:144px;overflow:hidden;position:relative}
.ad>div{position:absolute;left:-36px;top:-36px;width:216px;height:216px}
.ad img{width:216px;height:216px}
.sz{overflow:visible;outline:1px dashed #aaa}.sz i{position:absolute;left:42px;top:42px;width:132px;height:132px;border:2px solid #f0a;border-radius:50%}
.sb{background:#202124;padding:10px 14px;border-radius:8px;display:flex;gap:10px;align-items:center;color:#fff}
.sp{width:160px;height:300px;border-radius:18px;display:grid;place-items:center}
.sp img{width:120px}
</style>
<div class="row">
${cell(adaptive('#14674A', fg, '50%'), 'circle mask')}
${cell(adaptive('#14674A', fg, '28%'), 'squircle-ish mask')}
${cell(adaptive('#14674A', fg, '0'), 'square (full 72 dp)')}
${cell(safe, '108 dp layer, pink = 66 dp safe zone')}
</div><div class="row">
${cell(adaptive('#D8E8DD', mono('#0F4D36'), '50%'), 'themed (light)')}
${cell(adaptive('#1E2B25', mono('#A9E5C4'), '50%'), 'themed (dark)')}
${cell(`<div class="sb"><img src="${uri(vec('drawable/ic_stat_saarthee.xml'))}" width="24"><img src="${uri(vec('drawable/ic_stat_saarthee.xml'))}" width="48" style="image-rendering:pixelated">9:41</div>`, 'ic_stat_saarthee 24 dp + 2x')}
${['mdpi', 'xxxhdpi'].map((d) => cell(`<img src="${png(`mipmap-${d}/ic_launcher.png`)}"> <img src="${png(`mipmap-${d}/ic_launcher_round.png`)}">`, `legacy ${d}`)).join('')}
</div><div class="row">
${cell(`<div class="sp" style="background:#14674A"><img src="${uri(vec('drawable/splash_mark.xml'))}"></div>`, 'splash v31 light')}
${cell(`<div class="sp" style="background:#131C18"><img src="${uri(vec('drawable-night/splash_mark.xml'))}"></div>`, 'splash v31 dark')}
${cell(`<div class="sp" style="background:#14674A"><img src="${png('drawable-xxhdpi/launch_mark.png')}" style="width:96px"></div>`, 'pre-12 light (96 dp)')}
${cell(`<div class="sp" style="background:#131C18"><img src="${png('drawable-night-xxhdpi/launch_mark.png')}" style="width:96px"></div>`, 'pre-12 dark')}
</div>`;
const f = join(tmpdir(), 'android-preview.html');
writeFileSync(f, html);
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1000, height: 400 } });
await p.goto('file://' + f);
await p.waitForTimeout(300);
await p.screenshot({ path: out, fullPage: true });
await b.close();

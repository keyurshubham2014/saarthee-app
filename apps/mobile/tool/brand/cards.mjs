// OG image (1200x630) and Play feature graphics (1024x500, en + gu).
// Fonts are the app's own TTFs via @font-face; the script fails if they fall back.
// usage: node cards.mjs <repoRoot>
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { chromium } from 'playwright';

const root = process.argv[2];
const font = (f) => 'file://' + join(root, 'apps/mobile/assets/fonts', f);
const lockup = (lang) => readFileSync(join(root, `docs/brand/lockup-horizontal-${lang}.svg`), 'utf8');
const T = {
  en: { tag: 'Report it. Track it. See it fixed.', sub: 'Civic issues in Amdavad, followed through to the fix.', ind: 'Independent citizen app. Not run by or linked to AMC.' },
  gu: { tag: 'ફરિયાદ કરો. ફોલો કરો. ઉકેલ જુઓ.', sub: 'અમદાવાદની નાગરિક સમસ્યાઓ, ઉકેલ સુધી.', ind: 'સ્વતંત્ર નાગરિક એપ. AMC દ્વારા સંચાલિત કે તેની સાથે જોડાયેલી નથી.' },
};

// Calm abstract street motif: soft lanes and a junction in Neem tints, bottom-right.
const motif = (w, h) => `<svg class="motif" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true">
  <g fill="none" stroke-linecap="round">
    <path d="M${w * 0.55} ${h + 20} C${w * 0.62} ${h * 0.7} ${w * 0.72} ${h * 0.62} ${w + 20} ${h * 0.58}" stroke="#D8E8DD" stroke-width="64"/>
    <path d="M${w * 0.78} ${h + 20} C${w * 0.8} ${h * 0.6} ${w * 0.86} ${h * 0.3} ${w * 0.9} -20" stroke="#E6F0E9" stroke-width="44"/>
    <path d="M${w * 0.55} ${h + 20} C${w * 0.62} ${h * 0.7} ${w * 0.72} ${h * 0.62} ${w + 20} ${h * 0.58}" stroke="#F3F6F1" stroke-width="3" stroke-dasharray="16 18"/>
    <path d="M${w * 0.68} ${h + 20} C${w * 0.74} ${h * 0.82} ${w * 0.84} ${h * 0.8} ${w + 20} ${h * 0.86}" stroke="#C3DCCB" stroke-width="22"/>
  </g>
  <circle cx="${w * 0.835}" cy="${h * 0.63}" r="14" fill="#C24A1F" opacity=".85"/>
</svg>`;

const page = (lang, w, h) => `<!doctype html><html lang="${lang}"><meta charset="utf-8"><style>
@font-face{font-family:Baloo;src:url(${font('BalooBhai2-Bold.ttf')});font-weight:700}
@font-face{font-family:Mukta;src:url(${font('MuktaVaani-Medium.ttf')});font-weight:500}
@font-face{font-family:Mukta;src:url(${font('MuktaVaani-Regular.ttf')});font-weight:400}
*{margin:0;box-sizing:border-box}
body{width:${w}px;height:${h}px;background:#F3F6F1;position:relative;overflow:hidden;color:#17251E}
.motif{position:absolute;inset:0}
.c{position:absolute;left:${w * 0.065}px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;gap:${h * 0.045}px;width:${w * 0.72}px}
.c svg{height:${h * 0.15}px;width:auto;align-self:flex-start}
h1{font:700 ${h * 0.098}px/1.12 Baloo;color:#14674A;letter-spacing:-.01em}
p{font:500 ${h * 0.045}px/1.4 Mukta;color:#3A4A41}
small{font:400 ${h * 0.03}px/1.4 Mukta;color:#4E5E55}
</style><body>${motif(w, h)}<div class="c">${lockup(lang)}<h1>${T[lang].tag}</h1><p>${T[lang].sub}</p><small>${T[lang].ind}</small></div></body></html>`;

const jobs = [
  ['en', 1200, 630, 'docs/brand/web/og-image.png'],
  ['en', 1024, 500, 'docs/brand/play/feature-graphic-en.png'],
  ['gu', 1024, 500, 'docs/brand/play/feature-graphic-gu.png'],
];
const b = await chromium.launch();
for (const [lang, w, h, out] of jobs) {
  const f = join(tmpdir(), `card-${lang}-${w}.html`);
  writeFileSync(f, page(lang, w, h));
  const p = await b.newPage({ viewport: { width: w, height: h } });
  await p.goto('file://' + f);
  await p.evaluate(() => document.fonts.ready);
  const fonts = await p.evaluate(() => [...document.fonts].map((x) => `${x.family}:${x.status}`));
  if (fonts.some((x) => !x.endsWith('loaded'))) throw new Error('font fallback: ' + fonts);
  mkdirSync(join(root, out, '..'), { recursive: true });
  await p.screenshot({ path: join(root, out) });
  console.log(out, fonts.join(' '));
  await p.close();
}
await b.close();

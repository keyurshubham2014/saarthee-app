// Writes the logo SVG family into docs/brand/ (text converted to paths).
// usage: node logos.mjs <repoRoot>
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { variants, C } from './variants.mjs';
import { shape } from './text.mjs';

const root = process.argv[2];
const out = (f, s) => writeFileSync(join(root, 'docs/brand', f), s + '\n');
const BALOO = join(root, 'apps/mobile/assets/fonts/BalooBhai2-Bold.ttf');
const INK = '#17251E';
const M = variants.E;
const [cx, cy, r] = M.dot;

const glyph = (route, dot) =>
  `<path d="${M.path}" fill="none" stroke="${route}" stroke-width="${M.stroke}" stroke-linecap="round" stroke-linejoin="round"/>` +
  `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${dot}"/>`;
const markBody = (sq = C.primary, route = C.white, dot = C.sunrise) =>
  `<rect width="100" height="100" rx="28" fill="${sq}"/>${glyph(route, dot)}`;
const head = (w, h, label, note) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${fx(w)} ${fx(h)}" width="${fx(w)}" height="${fx(h)}" role="img" aria-label="${label}">\n  <!-- ${note} -->\n  `;
const fx = (n) => +n.toFixed(2);

// Mono: one ink, glyph knocked out of the square (works on any light surface).
out('mark-mono.svg', head(100, 100, 'Saarthee', 'Single-colour mark: glyph knocked out of the square. Recolour the one fill.') +
  `<mask id="k"><rect width="100" height="100" fill="#fff"/>${glyph('#000', '#000')}</mask>` +
  `<rect width="100" height="100" rx="28" fill="${INK}" mask="url(#k)"/>\n</svg>`);

// Reversed: for primary or dark backgrounds.
out('mark-reversed.svg', head(100, 100, 'Saarthee', 'Reversed mark for primary/dark surfaces: white square, primary route, sunrise dot.') +
  markBody(C.white, C.primary, C.sunrise) + '\n</svg>');

function bbox(d) {
  const n = d.match(/-?\d*\.?\d+/g).map(Number);
  let y0 = Infinity, y1 = -Infinity;
  for (let i = 1; i < n.length; i += 2) { y0 = Math.min(y0, n[i]); y1 = Math.max(y1, n[i]); }
  return { y0, y1 };
}

const words = { en: 'Saarthee', gu: 'સારથી' };
const SIZE = 64; // wordmark font size in mark units (mark = 100)
for (const [lang, text] of Object.entries(words)) {
  const { d, width } = shape(text, BALOO, SIZE);
  const { y0, y1 } = bbox(d);
  const pad = 2;
  const h = y1 - y0 + pad * 2;
  const note = `Wordmark "${text}", Baloo Bhai 2 Bold ${SIZE}, shaped with HarfBuzz and converted to paths.`;
  out(`wordmark-${lang}.svg`, head(width, h, text, note) +
    `<path transform="translate(0 ${fx(pad - y0)})" fill="${C.primary}" d="${d}"/>\n</svg>`);

  // Horizontal lockup: mark 100, gap 24 (≈ clear space), wordmark optically
  // centred on the mark's vertical centre (ink centre of the word).
  const gap = 24;
  const ty = 50 - (y0 + y1) / 2;
  const W = 100 + gap + width;
  // Colourways: default (light surfaces), -dark (DS dark bg #131C18, text in
  // dark primary #7BD3A6), -reversed (on primary: white square, white text).
  const ways = [
    ['', markBody(), C.primary, 'light surfaces'],
    ['-dark', markBody(), '#7BD3A6', 'dark surfaces (#131C18)'],
    ['-reversed', markBody(C.white, C.primary, C.sunrise), C.white, 'primary #14674A surfaces'],
  ];
  for (const [suffix, mark, ink, use] of ways) {
    out(`lockup-horizontal-${lang}${suffix}.svg`, head(W, 100, `Saarthee · ${text}`, `Horizontal lockup for ${use}: mark + ${note}`) +
      mark + `<path transform="translate(${100 + gap} ${fx(ty)})" fill="${ink}" d="${d}"/>\n</svg>`);
  }
}
console.log('ok');

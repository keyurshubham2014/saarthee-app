// Web icons, favicon.svg and Play icon from the master geometry (variant E).
// usage: node web.mjs <repoRoot>
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { Resvg } from '@resvg/resvg-js';
import { variants, C } from './variants.mjs';

const root = process.argv[2];
const M = variants.E;
const [cx, cy, r] = M.dot;
const glyph = `<path d="${M.path}" fill="none" stroke="${C.white}" stroke-width="${M.stroke}" stroke-linecap="round" stroke-linejoin="round"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="${C.sunrise}"/>`;
const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${body}</svg>`;
const mark = svg(`<rect width="100" height="100" rx="28" fill="${C.primary}"/>${glyph}`);
// Maskable: full-bleed primary, glyph inside the 80% safe circle (scale 0.8).
const maskable = svg(`<rect width="100" height="100" fill="${C.primary}"/><g transform="translate(10 10) scale(0.8)">${glyph}</g>`);
// Play icon: 512 full-bleed square (Play applies its own 30% corner mask).
const play = svg(`<rect width="100" height="100" fill="${C.primary}"/><g transform="translate(9 9) scale(0.82)">${glyph}</g>`);

const put = (p, data) => { mkdirSync(dirname(join(root, p)), { recursive: true }); writeFileSync(join(root, p), data); };
const png = (s, w) => new Resvg(s, { fitTo: { mode: 'width', value: w } }).render().asPng();

put('apps/mobile/web/favicon.png', png(mark, 32));
put('apps/mobile/web/icons/Icon-192.png', png(mark, 192));
put('apps/mobile/web/icons/Icon-512.png', png(mark, 512));
put('apps/mobile/web/icons/Icon-maskable-192.png', png(maskable, 192));
put('apps/mobile/web/icons/Icon-maskable-512.png', png(maskable, 512));
put('docs/brand/web/favicon.svg', readFileSync(join(root, 'docs/brand/mark.svg')));
put('docs/brand/play/icon-512.png', png(play, 512));

const mf = join(root, 'apps/mobile/web/manifest.json');
let m = {};
try { m = JSON.parse(readFileSync(mf, 'utf8')); } catch { /* no web/ yet */ }
const icon = (s, purpose) => ({ src: `icons/Icon-${purpose === 'maskable' ? 'maskable-' : ''}${s}.png`, sizes: `${s}x${s}`, type: 'image/png', ...(purpose ? { purpose } : {}) });
m = {
  ...m,
  name: 'Saarthee',
  short_name: 'Saarthee',
  start_url: m.start_url || '.',
  display: m.display || 'standalone',
  background_color: '#F3F6F1',
  theme_color: C.primary,
  description: 'Saarthee · સારથી: report civic issues in Amdavad and track them until they are fixed. Independent citizen app, not run by or linked to AMC.',
  orientation: m.orientation || 'portrait-primary',
  prefer_related_applications: false,
  icons: [icon(192), icon(512), icon(192, 'maskable'), icon(512, 'maskable')],
};
writeFileSync(mf, JSON.stringify(m, null, 4) + '\n');
console.log('ok');

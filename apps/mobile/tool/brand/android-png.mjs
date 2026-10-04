// Renders legacy launcher PNGs and the pre-12 splash bitmap with resvg.
// usage: node android-png.mjs <repoRoot>
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { Resvg } from '@resvg/resvg-js';
import { variants, C } from './variants.mjs';

const root = process.argv[2];
const res = join(root, 'apps/mobile/android/app/src/main/res');
const M = variants.E;
const [cx, cy, r] = M.dot;
const glyph = (route, dot) =>
  `<path d="${M.path}" fill="none" stroke="${route}" stroke-width="${M.stroke}" stroke-linecap="round" stroke-linejoin="round"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="${dot}"/>`;
const wrap = (body, vb = '0 0 100 100') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}">${body}</svg>`;
const png = (svg, px) => new Resvg(svg, { fitTo: { mode: 'width', value: px } }).render().asPng();
const write = (dir, name, buf) => { mkdirSync(join(res, dir), { recursive: true }); writeFileSync(join(res, dir, name), buf); };

const DPI = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

// Legacy square icon: 48 dp, mark inset 2 dp (keyline 44 dp). Round: 44 dp circle.
const square = wrap(`<g transform="translate(4.17 4.17) scale(0.9167)"><rect width="100" height="100" rx="28" fill="${C.primary}"/>${glyph(C.white, C.sunrise)}</g>`);
const round = wrap(`<circle cx="50" cy="50" r="45.83" fill="${C.primary}"/><g transform="translate(9 9) scale(0.82)">${glyph(C.white, C.sunrise)}</g>`);
// Pre-12 splash bitmap: glyph only, 96 dp, light and night colourways.
const splash = wrap(glyph(C.white, C.sunrise));
const splashNight = wrap(glyph('#7BD3A6', C.sunrise));

for (const [d, k] of Object.entries(DPI)) {
  write(`mipmap-${d}`, 'ic_launcher.png', png(square, 48 * k));
  write(`mipmap-${d}`, 'ic_launcher_round.png', png(round, 48 * k));
  write(`drawable-${d}`, 'launch_mark.png', png(splash, 96 * k));
  write(`drawable-night-${d}`, 'launch_mark.png', png(splashNight, 96 * k));
}
console.log('ok');

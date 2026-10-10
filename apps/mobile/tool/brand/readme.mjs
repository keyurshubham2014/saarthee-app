// Artwork for the repository README, written to docs/brand/readme/.
// GitHub shows SVGs through <img>, so every word is shaped with HarfBuzz and
// converted to paths (text.mjs); the screenshot rows are Playwright renders of
// the v2 evidence screenshots in phone frames on a transparent background.
// Copy comes from approved strings (cards.mjs taglines, app_*.arb labels).
// usage: node readme.mjs <repoRoot>
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { chromium } from 'playwright';
import sharp from 'sharp';
import { shape } from './text.mjs';

const root = process.argv[2];
const OUT = join(root, 'docs/brand/readme');
mkdirSync(join(OUT, 'features'), { recursive: true });
const fontDir = join(root, 'apps/mobile/assets/fonts');
const F = {
  baloo: join(fontDir, 'BalooBhai2-Bold.ttf'),
  balooSemi: join(fontDir, 'BalooBhai2-SemiBold.ttf'),
  mukta: join(fontDir, 'MuktaVaani-Medium.ttf'),
  muktaSemi: join(fontDir, 'MuktaVaani-SemiBold.ttf'),
  icons: '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
};
const fx = (n) => +n.toFixed(2);
const write = (f, s) => { writeFileSync(join(OUT, f), s + '\n'); console.log('docs/brand/readme/' + f); };
const svg = (w, h, label, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="${label}">\n${body}\n</svg>`;

// Text as a path. `align` is start | middle | end around x; y is the baseline.
function text(str, font, size, x, y, fill, align = 'start') {
  const { d, width } = shape(str, font, size);
  const dx = align === 'middle' ? x - width / 2 : align === 'end' ? x - width : x;
  return { el: `<path transform="translate(${fx(dx)} ${fx(y)})" fill="${fill}" d="${d}"/>`, width };
}
// Largest size <= max at which str fits in maxW.
const fit = (str, font, max, maxW) => Math.min(max, (maxW / shape(str, font, 100).width) * 100);
const icon = (cp, size, x, y, fill) => text(String.fromCodePoint(cp), F.icons, size, x, y + size, fill).el;

// A brand lockup nested at (x, y) with the given height.
function lockup(name, x, y, h) {
  const src = readFileSync(join(root, 'docs/brand', name), 'utf8');
  const [, vw, vh] = src.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/);
  const inner = src.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '').replace(/<!--[\s\S]*?-->/g, '');
  return { el: `<svg x="${x}" y="${y}" width="${fx((h * vw) / vh)}" height="${h}" viewBox="0 0 ${vw} ${vh}">${inner}</svg>`, w: (h * vw) / vh };
}

const T = {
  tag: 'Report it. Track it. See it fixed.',
  tagGu: 'ફરિયાદ કરો. ફોલો કરો. ઉકેલ જુઓ.',
  sub: 'Civic issues in Amdavad, followed through to the fix.',
  ind: 'Independent citizen app. Not run by or linked to AMC.',
};

// ---- Hero (light: primary panel; dark: DS dark surface) -------------------
const HERO = {
  light: { bg: '#14674A', lane: '#1B7553', lane2: '#1F7D59', lane3: '#238762', dash: '#3E9C75', lock: 'lockup-horizontal-en-reversed.svg', tag: '#FFFFFF', gu: '#E1F0E7', sub: '#BFE0CD', pill: '#FFFFFF', pillLine: '#5FA585' },
  dark: { bg: '#131C18', lane: '#18241F', lane2: '#1B2923', lane3: '#1F3029', dash: '#2E4A3D', lock: 'lockup-horizontal-en-dark.svg', tag: '#E8F2EC', gu: '#7BD3A6', sub: '#A9C1B4', pill: '#CFE3D8', pillLine: '#2E4A3D' },
};
for (const [mode, c] of Object.entries(HERO)) {
  const W = 1280, H = 420, X = 72, colW = 760;
  const m = (k) => fx(k);
  const motif = `<g clip-path="url(#card)" fill="none" stroke-linecap="round">
  <path d="M${m(W * 0.6)} ${H + 20} C${m(W * 0.66)} ${m(H * 0.7)} ${m(W * 0.76)} ${m(H * 0.6)} ${W + 20} ${m(H * 0.56)}" stroke="${c.lane}" stroke-width="80"/>
  <path d="M${m(W * 0.8)} ${H + 20} C${m(W * 0.82)} ${m(H * 0.6)} ${m(W * 0.87)} ${m(H * 0.3)} ${m(W * 0.91)} -20" stroke="${c.lane2}" stroke-width="56"/>
  <path d="M${m(W * 0.6)} ${H + 20} C${m(W * 0.66)} ${m(H * 0.7)} ${m(W * 0.76)} ${m(H * 0.6)} ${W + 20} ${m(H * 0.56)}" stroke="${c.dash}" stroke-width="3" stroke-dasharray="18 20"/>
  <path d="M${m(W * 0.7)} ${H + 20} C${m(W * 0.76)} ${m(H * 0.84)} ${m(W * 0.86)} ${m(H * 0.82)} ${W + 20} ${m(H * 0.88)}" stroke="${c.lane3}" stroke-width="26"/>
  <circle cx="${m(W * 0.848)}" cy="${m(H * 0.615)}" r="16" fill="#C24A1F" stroke="none"/>
</g>`;
  const lk = lockup(c.lock, X, 60, 64);
  const tag = text(T.tag, F.baloo, fit(T.tag, F.baloo, 60, colW), X, 210, c.tag);
  const gu = text(T.tagGu, F.balooSemi, fit(T.tagGu, F.balooSemi, 36, colW), X, 268, c.gu);
  const sub = text(T.sub, F.mukta, 22, X, 316, c.sub);
  const pillText = text(T.ind, F.mukta, 16, X + 20, 367, c.pill);
  const pill = `<rect x="${X}" y="342" width="${fx(pillText.width + 40)}" height="36" rx="18" fill="none" stroke="${c.pillLine}" stroke-width="1.5"/>`;
  write(`hero-${mode}.svg`, svg(W, H, `Saarthee: ${T.tag} ${T.tagGu}`,
    `<defs><clipPath id="card"><rect width="${W}" height="${H}" rx="28"/></clipPath></defs>
<rect width="${W}" height="${H}" rx="28" fill="${c.bg}"/>
${motif}
${lk.el}
${tag.el}
${gu.el}
${sub.el}
${pill}${pillText.el}`));
}

// ---- Feature tiles (Report is the only sunrise tile, DS §2) ----------------
const FEATURES = {
  report: 0xe4b6, follow: 0xe661, verify: 0xe699, map: 0xe3c8,
  alerts: 0xe450, 'my-ward': 0xe089, services: 0xe6c6, staff: 0xe1b1,
};
for (const [name, cp] of Object.entries(FEATURES)) {
  const [bg, fg] = name === 'report' ? ['#C24A1F', '#FFFFFF'] : ['#E1F0E7', '#14674A'];
  write(`features/${name}.svg`, svg(96, 96, name, `<rect width="96" height="96" rx="27" fill="${bg}"/>${icon(cp, 48, 24, 24, fg)}`));
}

// ---- Issue lifecycle (DS status colours, EN + GU labels from the ARB) ------
// The canvas is transparent: chips carry their own tint, connectors and
// captions use a mid grey that reads on GitHub's light and dark themes.
const STEPS = [
  { en: 'Reported', gu: 'નોંધાઈ', fg: '#4B5768', bg: '#EDF0F4', cp: 0xe504, cap: 'A resident reports it' },
  { en: 'Acknowledged', gu: 'સ્વીકારાઈ', fg: '#1F5FAE', bg: '#E5EEFA', cp: 0xe3cf, cap: 'Sent and acknowledged' },
  { en: 'In progress', gu: 'કામ ચાલુ', fg: '#8A5300', bg: '#FFF3DC', cp: 0xe189, cap: 'Work under way' },
  { en: 'Fixed', gu: 'ઉકેલાઈ', fg: '#1A7340', bg: '#E6F4EC', cp: 0xe159, cap: 'Marked fixed' },
  { en: 'Verified', gu: 'ચકાસાઈ', fg: '#0E5233', bg: '#DDEFE5', cp: 0xe699, cap: 'A neighbour confirms it' },
];
const REOPEN = { en: 'Reopened', gu: 'ફરી ખૂલી', fg: '#B4400F', bg: '#FDEDE4', cp: 0xe523, cap: 'Not fixed? It reopens' };
{
  const W = 1290, CW = 204, CH = 76, GAP = 55, X0 = 20, Y0 = 20, GREY = '#8A978F';
  const chip = (s, x, y) => {
    const en = text(s.en, F.muktaSemi, 20, x + 66, y + 34, s.fg);
    const gu = text(s.gu, F.mukta, 17, x + 66, y + 60, s.fg);
    return `<rect x="${x}" y="${y}" width="${CW}" height="${CH}" rx="20" fill="${s.bg}" stroke="${s.fg}" stroke-opacity=".25"/>` +
      icon(s.cp, 32, x + 22, y + 22, s.fg) + en.el + gu.el;
  };
  const caption = (s, cx, y) => text(s.cap, F.mukta, 15, cx, y, GREY, 'middle').el;
  const arrow = `<marker id="a" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="${GREY}"/></marker>`;
  let body = `<defs>${arrow}</defs>`;
  STEPS.forEach((s, i) => {
    const x = X0 + i * (CW + GAP);
    body += chip(s, x, Y0) + caption(s, x + CW / 2, Y0 + CH + 26);
    if (i) body += `<path d="M${x - GAP + 8} ${Y0 + CH / 2} H${x - 8}" stroke="${GREY}" stroke-width="2.5" marker-end="url(#a)"/>`;
  });
  // Fixed -> Reopened (down), Reopened -> In progress (back, dashed).
  const fixX = X0 + 3 * (CW + GAP), progX = X0 + 2 * (CW + GAP), ry = Y0 + CH + 74;
  body += `<path d="M${fixX + CW / 2} ${Y0 + CH + 40} V${ry - 8}" stroke="${GREY}" stroke-width="2.5" marker-end="url(#a)"/>`;
  body += chip(REOPEN, fixX, ry);
  body += `<path d="M${fixX - 8} ${ry + CH / 2} H${progX + CW / 2} V${Y0 + CH + 40}" fill="none" stroke="${GREY}" stroke-width="2.5" stroke-dasharray="7 6" marker-end="url(#a)"/>`;
  body += text(REOPEN.cap, F.mukta, 15, fixX + CW + 18, ry + CH / 2 + 5, GREY).el;
  write('lifecycle.svg', svg(W, ry + CH + 20, 'Issue lifecycle: Reported, Acknowledged, In progress, Fixed, Verified; a Not fixed check reopens it', body));
}

// ---- "For developers" banner ----------------------------------------------
for (const [mode, c] of Object.entries({
  light: { bg: '#E1F0E7', h: '#0E4A35', p: '#4E5E55' },
  dark: { bg: '#18241F', h: '#E8F2EC', p: '#A9C1B4' },
})) {
  const mark = lockup('mark.svg', 40, 28, 64);
  const h = text('For developers', F.baloo, 36, 128, 70, c.h);
  const p = text('Run it locally, test it, and contribute.', F.mukta, 18, 128, 98, c.p);
  write(`developers-${mode}.svg`, svg(1280, 120, 'For developers', `<rect width="1280" height="120" rx="24" fill="${c.bg}"/>${mark.el}${h.el}${p.el}`));
}

// ---- Screenshot rows (Playwright) -----------------------------------------
const EV = join(root, 'docs/demo/v2-evidence');
const shot = (f) => 'file://' + join(EV, f);
const ROWS = {
  'phones-citizen': [['61-home-polish.png', 'Home'], ['16d-report-step2-blurred.png', 'Report · faces blurred on device'], ['104-map-2000-clusters.png', 'Map'], ['105-marked-fixed-detail.png', 'Follow it to the fix']],
  'phones-ward': [['25-alerts-warning.png', 'Ward alerts'], ['20-myward.png', 'My Ward'], ['71-services-directory.png', 'Services']],
  'phones-gujarati': [['gu-pass/01-home.png', 'હોમ'], ['gu-pass/05-report.png', 'નોંધાવો'], ['gu-pass/04-my-ward.png', 'મારો વોર્ડ'], ['gu-pass/03-alerts.png', 'ચેતવણી']],
};
const css = `@font-face{font-family:Mukta;src:url(file://${F.muktaSemi});font-weight:600}
*{margin:0;box-sizing:border-box}html,body{background:transparent}
.row{display:flex;gap:44px;padding:28px 36px 32px;width:max-content;align-items:flex-start}
.p{display:flex;flex-direction:column;align-items:center;gap:18px}
.f{width:316px;padding:9px;border-radius:44px;background:#17251E;box-shadow:0 18px 36px -14px rgba(14,74,53,.45),0 2px 6px rgba(0,0,0,.18)}
.f img{display:block;width:298px;border-radius:36px}
.c{font:600 19px/1 Mukta;color:#0E4A35;background:#E1F0E7;padding:9px 18px 8px;border-radius:999px}
.b{width:1180px;margin:28px 36px 36px;border-radius:16px;overflow:hidden;background:#fff;box-shadow:0 18px 40px -16px rgba(14,74,53,.45),0 2px 6px rgba(0,0,0,.18)}
.bar{height:40px;background:#E8EFEA;display:flex;align-items:center;gap:8px;padding:0 16px}
.bar i{width:12px;height:12px;border-radius:50%;background:#B9C6BE}
.v{height:250px;overflow:hidden}.v img{display:block;width:100%}`;
const pages = Object.fromEntries(Object.entries(ROWS).map(([k, items]) => [k,
  `<div class="row">${items.map(([f, c]) => `<div class="p"><div class="f"><img src="${shot(f)}"></div><div class="c">${c}</div></div>`).join('')}</div>`]));
pages['staff-console'] = `<div class="b"><div class="bar"><i></i><i></i><i></i></div><div class="v"><img src="${shot('web/staff-dashboard-moderator.jpg')}"></div></div>`;

const b = await chromium.launch();
for (const [name, html] of Object.entries(pages)) {
  const f = join(tmpdir(), `readme-${name}.html`);
  writeFileSync(f, `<!doctype html><meta charset="utf-8"><style>${css}</style><body>${html}</body>`);
  const p = await b.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1.5 });
  await p.goto('file://' + f);
  await p.waitForLoadState('networkidle');
  await p.evaluate(() => document.fonts.ready);
  const fonts = await p.evaluate(() => [...document.fonts].map((x) => `${x.family}:${x.status}`));
  if (name !== 'staff-console' && fonts.some((x) => !x.endsWith('loaded'))) throw new Error('font fallback: ' + fonts);
  const el = await p.$('body > div');
  const png = await el.screenshot({ omitBackground: true });
  await sharp(png).png({ palette: true, quality: 92, effort: 10 }).toFile(join(OUT, name + '.png'));
  console.log(`docs/brand/readme/${name}.png`);
  await p.close();
}
await b.close();

// Builds docs/brand/brand-guide.html: self-contained (Baloo Bhai 2 and Mukta Vaani
// embedded as base64; only Material Symbols Rounded loads from Google Fonts).
// usage: node guide.mjs <repoRoot>
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { palette, dark, statuses, categories, type, dos, donts } from './guide-data.mjs';
import { CSS } from './guide-css.mjs';

const root = process.argv[2];
const b64 = (f) => readFileSync(join(root, 'apps/mobile/assets/fonts', f)).toString('base64');
const face = (fam, f, w) => `@font-face{font-family:${fam};font-weight:${w};font-display:block;src:url(data:font/ttf;base64,${b64(f)}) format('truetype')}`;
const svgOf = (f) => readFileSync(join(root, 'docs/brand', f), 'utf8').replace(/<!--[\s\S]*?-->/g, '').trim();
const ico = (n, fill = 0) => `<span class="ms${fill ? ' f' : ''}" aria-hidden="true">${n}</span>`;
const mark = svgOf('mark.svg');

const sec = (id, title, body) => `<section id="${id}"><h2>${title}</h2>${body}</section>`;

const markSec = sec('mark', 'The mark', `
<p>A road rises from the lower left, turns right and runs on to a sunrise dot, the destination: "the way forward". Rounded square, radius 28% of its size, in primary #14674A. Master: <code>docs/brand/mark.svg</code>.</p>
<div class="row">
  <figure class="clear"><div class="cs">${mark}</div><figcaption>Clear space: 25% of the mark size on every side</figcaption></figure>
  <figure><div class="sizes">${[16, 24, 32, 48, 72].map((s) => `<div style="width:${s}px">${mark}</div>`).join('')}</div><figcaption>Minimum: 16 px on screen (favicon), 24 dp in the app, 10 mm in print</figcaption></figure>
</div>
<div class="row grounds">
  <figure class="g light">${mark}<figcaption>Light</figcaption></figure>
  <figure class="g darkg">${mark}<figcaption>Dark #131C18</figcaption></figure>
  <figure class="g prim">${svgOf('mark-reversed.svg')}<figcaption>On primary: reversed</figcaption></figure>
  <figure class="g light">${svgOf('mark-mono.svg')}<figcaption>One colour</figcaption></figure>
</div>
<div class="lockups">${svgOf('lockup-horizontal-en.svg')}${svgOf('lockup-horizontal-gu.svg')}</div>
<p class="note">Lockups: mark and wordmark side by side, one language each. Never stack English over Gujarati.</p>`);

const doSec = sec('do', 'Do and don’t', `<div class="row two">
<div class="card ok"><h3>${ico('check_circle', 1)} Do</h3><ul>${dos.map((d) => `<li>${d}</li>`).join('')}</ul></div>
<div class="card no"><h3>${ico('block')} Don’t</h3><ul>${donts.map((d) => `<li>${d}</li>`).join('')}</ul></div></div>`);

const sw = ([n, h, u]) => `<div class="sw"><i style="background:${h}"></i><b>${n}</b><code>${h}</code>${u ? `<small>${u}</small>` : ''}</div>`;
const palSec = sec('palette', 'Palette', `<h3>Light (Neem)</h3><div class="sws">${palette.map(sw).join('')}</div>
<h3>Dark</h3><div class="sws">${dark.map(sw).join('')}</div>
<p class="note">Sunrise appears at most once per screen, only on the Report action. Everything else that is interactive uses primary.</p>`);

const typeSec = sec('type', 'Typography', `<p>Baloo Bhai 2 for display and headings (never below 16 sp), Mukta Vaani for body, labels and buttons. Both are by Ek Type, OFL, and cover Gujarati and Latin.</p>
<table class="type">${type.map(([r, f, s, w, lh, t]) => `<tr><td><code>${r}</code><small>${f === 'Baloo' ? 'Baloo Bhai 2' : 'Mukta Vaani'} ${s}/${lh} · ${w}</small></td><td style="font:${w} ${s}px/${lh}px ${f}">${t}</td></tr>`).join('')}</table>`);

const iconSec = sec('icons', 'Icon style', `<p>Material Symbols <b>Rounded</b>, weight 400, 24 dp. Filled only for the selected nav tab and the Report "+". No illustrations, mascots or clip art.</p>
<div class="nav">${[['home', 'Home', 1], ['map', 'Map'], ['add', 'Report', 2], ['notifications', 'Alerts'], ['person', 'Me']].map(([n, l, s]) =>
  `<div class="tab${s === 1 ? ' sel' : ''}${s === 2 ? ' rep' : ''}">${ico(n, s ? 1 : 0)}<span>${l}</span></div>`).join('')}</div>`);

const catSec = sec('categories', 'Category badges (14)', `<p>Glyph in the category colour on a 12% tint, in a 40 dp rounded square (radius 14).</p>
<div class="cats">${categories.map(([s, h, i]) => `<div class="cat"><i style="color:${h};background:${h}1F">${ico(i)}</i><span>${s}</span></div>`).join('')}</div>`);

const statSec = sec('status', 'Status chips (7)', `<div class="chips">${statuses.map(([en, gu, solid, tint, i]) =>
  `<span class="chip" style="color:${solid};background:${tint}">${ico(i)}${en}</span><span class="chip solid" style="background:${solid}">${ico(i)}${gu}</span>`).join('')}</div>`);

const indep = `<footer class="indep">${ico('info')}<div><b>Independent citizen app. Not run by or linked to AMC.</b><span>નાગરિકોની સ્વતંત્ર એપ. AMC દ્વારા ચલાવાતી કે તેની સાથે જોડાયેલી નથી.</span></div></footer>`;

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Saarthee Brand Guide</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,400,0..1,0&display=block">
<style>${face('Baloo', 'BalooBhai2-Bold.ttf', 700)}${face('Baloo', 'BalooBhai2-SemiBold.ttf', 600)}${face('Mukta', 'MuktaVaani-Regular.ttf', 400)}${face('Mukta', 'MuktaVaani-SemiBold.ttf', 600)}${CSS}</style></head>
<body><header class="hero">${svgOf('lockup-horizontal-en-reversed.svg')}<div><h1>Brand guide</h1><p>Saarthee · સારથી. Report it. Track it. See it fixed.</p></div></header>
<main>${markSec}${doSec}${palSec}${typeSec}${iconSec}${catSec}${statSec}${indep}</main></body></html>`;
writeFileSync(join(root, 'docs/brand/brand-guide.html'), html);
console.log('ok', (html.length / 1e6).toFixed(2), 'MB');

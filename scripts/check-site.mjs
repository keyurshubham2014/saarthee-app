#!/usr/bin/env node
// Static checks for infra/site (V2 TASK-13 AC-12 support; M-13-10 still compares by eye).
//   node scripts/check-site.mjs            — structure + content rules (CI)
//   node scripts/check-site.mjs --release  — also fails on placeholders (data-todo) and the draft banner
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../infra/site');
const release = process.argv.includes('--release');
const errors = [];
const read = (p) => readFileSync(path.join(root, p), 'utf8');

const INDEPENDENCE_EN = 'Saarthee is an independent app. It is not made by or affiliated with the Amdavad Municipal Corporation.';
const INDEPENDENCE_GU = 'સારથી એક સ્વતંત્ર ઍપ છે. તે અમદાવાદ મ્યુનિસિપલ કોર્પોરેશન દ્વારા બનાવવામાં આવી નથી કે તેની સાથે જોડાયેલી નથી.';

const pages = {
  'index.html': [],
  'privacy/index.html': [
    // Spec §11 retention promises and display rule, in both languages.
    '2 years after the issue is closed', 'Server logs: 14 days', 'Notifications: 90 days', 'backups: 35 days',
    'A resident of &lt;ward&gt;', 'aged 18 and over', 'Delete my account', 'Download my data',
    'સમસ્યા બંધ થયાના 2 વર્ષ પછી', 'સર્વર લૉગ: 14 દિવસ', 'નોટિફિકેશન: 90 દિવસ', 'બેકઅપ: 35 દિવસ',
    '&lt;વોર્ડ&gt;ના એક રહેવાસી', '18 વર્ષ',
  ],
  'delete-account/index.html': ['Me</strong>', 'Privacy &amp; data', 'Delete my account', '30 days', '30 દિવસમાં'],
  '404.html': [],
};

for (const [page, phrases] of Object.entries(pages)) {
  if (!existsSync(path.join(root, page))) {
    errors.push(`${page}: missing`);
    continue;
  }
  const html = read(page);
  if (!/^<!doctype html>/i.test(html)) errors.push(`${page}: no doctype`);
  if (!/<title>[^<]{3,60}<\/title>/.test(html)) errors.push(`${page}: no <title>`);
  if (!html.includes('name="viewport"')) errors.push(`${page}: no viewport meta`);
  if (/<script\b/i.test(html)) errors.push(`${page}: scripts are not allowed (CSP default-src 'none')`);
  if (/\bstyle="/i.test(html)) errors.push(`${page}: inline styles are blocked by the CSP`);
  if (/https?:\/\/(?!www\.)/i.test(html.replace(/<!--[\s\S]*?-->/g, ''))) errors.push(`${page}: external URL found`);
  if (/AMC logo|amc-logo|ahmedabadcity\.gov\.in/i.test(html)) errors.push(`${page}: AMC marks/links are not allowed (D1)`);
  if (page !== '404.html') {
    if (!html.includes(INDEPENDENCE_EN)) errors.push(`${page}: English independence line missing`);
    if (!html.includes(INDEPENDENCE_GU)) errors.push(`${page}: Gujarati independence line missing`);
  }
  for (const p of phrases) if (!html.includes(p)) errors.push(`${page}: expected text "${p}"`);
  for (const m of html.matchAll(/(?:href|src)="(\/[^"#]*)/g)) {
    let target = m[1];
    if (target.endsWith('/')) target += 'index.html';
    if (!existsSync(path.join(root, target))) errors.push(`${page}: broken link ${m[1]}`);
  }
  if (release) {
    if (html.includes('data-todo=')) errors.push(`${page}: placeholder (data-todo) left in`);
    if (html.includes('class="draft"')) errors.push(`${page}: draft banner left in (legal review open?)`);
  }
}
for (const f of ['style.css', 'favicon.svg', 'og-image.png', '_headers']) {
  if (!existsSync(path.join(root, f))) errors.push(`${f}: missing`);
}
if (/<script/i.test(read('favicon.svg'))) errors.push('favicon.svg: contains a script');

if (errors.length) {
  console.error(`check-site: ${errors.length} problem(s)\n- ${errors.join('\n- ')}`);
  process.exit(1);
}
console.log(`check-site: ok (${Object.keys(pages).length} pages${release ? ', release mode' : ''})`);

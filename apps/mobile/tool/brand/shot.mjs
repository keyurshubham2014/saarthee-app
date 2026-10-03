// usage: node shot.mjs <html> <png> [width] [scheme] [fullPage]
import { chromium } from 'playwright';
const [, , file, png, width = '1280', scheme = 'light', full = '1'] = process.argv;
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: +width, height: 800 }, colorScheme: scheme, deviceScaleFactor: 1 });
await page.goto('file://' + file);
await page.waitForLoadState('networkidle');
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(400);
const fonts = await page.evaluate(() => [...document.fonts].map((f) => `${f.family}|${f.weight}|${f.status}`));
console.log(JSON.stringify(fonts));
await page.screenshot({ path: png, fullPage: full === '1' });
await browser.close();

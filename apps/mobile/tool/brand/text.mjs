// Text-to-path with real OpenType shaping (harfbuzzjs >= 1.6, ESM class API),
// so Gujarati matras and conjuncts render exactly as the font intends.
import { readFileSync } from 'node:fs';
import { Blob, Face, Font, Buffer, shape as hbShape } from 'harfbuzzjs';

const cache = new Map();
function font(path) {
  if (!cache.has(path)) {
    const face = new Face(new Blob(readFileSync(path)), 0);
    cache.set(path, { f: new Font(face), upem: face.upem });
  }
  return cache.get(path);
}

// Returns { d, width } where d is an SVG path at `size` px font size,
// baseline at y = 0, origin at x = 0 (y-down, SVG convention).
export function shape(text, fontPath, size) {
  const { f, upem } = font(fontPath);
  const buf = new Buffer();
  buf.addText(text);
  buf.guessSegmentProperties();
  hbShape(f, buf);
  const infos = buf.getGlyphInfos();
  const pos = buf.getGlyphPositions();
  const k = size / upem;
  let x = 0;
  const parts = [];
  infos.forEach((g, i) => {
    const p = pos[i];
    const ox = x + p.xOffset;
    const oy = p.yOffset;
    const raw = f.glyphToPath(g.codepoint);
    // raw is font units, y-up; coordinates are "x,y" or "x y" pairs.
    parts.push(raw.replace(/(-?\d*\.?\d+(?:e-?\d+)?)[ ,](-?\d*\.?\d+(?:e-?\d+)?)/g, (_, a, b) =>
      `${((+a + ox) * k).toFixed(2)} ${(-(+b + oy) * k).toFixed(2)}`));
    x += p.xAdvance;
  });
  return { d: parts.join(''), width: x * k };
}

// Exploration variants of the Saarthee mark, 100x100 units.
export const C = { primary: '#14674A', sunrise: '#C24A1F', white: '#FFFFFF' };

export const variants = {
  A: {
    name: 'A · Preview route',
    note: 'Founder preview geometry (48 grid scaled to 100): three-turn route, thin stroke, white-ringed dot.',
    route: [[26, 69.8], [42.7, 53.1], [55.2, 62.5], [68.8, 43.8]],
    stroke: 8.75, dot: [74.2, 34.6, 9.2], ring: 4.2,
  },
  B: {
    name: 'B · Bold route',
    note: 'Same story, heavier: stroke 11, flatter dip, dot detached by a clear gap. No ring.',
    route: [[24, 71], [42, 53], [54, 62], [67, 46]],
    stroke: 11, dot: [76.5, 31.5, 10.5], ring: 0,
  },
  C: {
    name: 'C · Curved road',
    note: 'Smooth S-curve road rising to the dot. Softer, but reads as a wave or a graph at small sizes.',
    path: 'M24 72 C38 72 40 52 52 52 S64 44 66 42',
    stroke: 11, dot: [75, 32, 10.5], ring: 0,
  },
  D: {
    name: 'D · Refined route (rejected: reads as trending_up)',
    note: 'B weight (stroke 11), dot placed on the line of the last segment with a 3.6-unit natural gap, whole glyph optically centred (bbox 15–85 × 22.5–77.5). Separates cleanly in one colour without masks.',
    route: [[20.5, 72], [38.5, 54], [50.5, 63.5], [62.5, 48.5]],
    stroke: 11, dot: [74.5, 33, 10.5], ring: 0,
  },
  E: {
    name: 'E · Road turn (chosen)',
    note: 'Navigation turn: a road rises from the bottom-left, turns right on a generous 18-unit corner and runs on to the dot (the destination) across a 6-unit gap. Glyph bbox 18–83 × 22.5–79, optically centred.',
    path: 'M24 73 L24 51 Q24 33 42 33 L50 33',
    stroke: 12, dot: [72.5, 33, 10.5], ring: 0,
  },
  F: {
    name: 'F · Chevron ahead',
    note: 'One bold rounded chevron pointing up-right, the dot just ahead of its tip.',
    path: 'M30 40 L58 40 L58 68',
    stroke: 12, dot: [73, 25, 10], ring: 0,
  },
  G: {
    name: 'G · Winding lane',
    note: 'A lane with two soft curves at an even stroke, climbing to the dot.',
    path: 'M24 79 C24 63 48 69 48 55 C48 47 50.4 43.8 56 39',
    stroke: 11, dot: [73.6, 25.8, 10.5], ring: 0,
  },
};

function routeD(v) {
  if (v.path) return v.path;
  return v.route.map((p, i) => `${i ? 'L' : 'M'}${p[0]} ${p[1]}`).join(' ');
}

export function svg(v, { size = 100, square = C.primary, route = C.white, dot = C.sunrise, bg } = {}) {
  const [cx, cy, r] = v.dot;
  const parts = [];
  if (bg) parts.push(`<rect width="100" height="100" fill="${bg}"/>`);
  parts.push(`<rect width="100" height="100" rx="28" fill="${square}"/>`);
  parts.push(`<path d="${routeD(v)}" fill="none" stroke="${route}" stroke-width="${v.stroke}" stroke-linecap="round" stroke-linejoin="round"/>`);
  if (v.gap) parts.push(`<circle cx="${cx}" cy="${cy}" r="${r + v.gap}" fill="${square}"/>`);
  if (v.ring) parts.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="${dot}" stroke="${route}" stroke-width="${v.ring}"/>`);
  else parts.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="${dot}"/>`);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="${size}" height="${size}">${parts.join('')}</svg>`;
}

// Glyph only (route + dot), single colour, for notification / themed icon.
export function glyph(v, { size = 100, color = '#000' } = {}) {
  const [cx, cy, r] = v.dot;
  const mask = v.gap
    ? `<mask id="m"><rect width="100" height="100" fill="#fff"/><circle cx="${cx}" cy="${cy}" r="${r + v.gap}" fill="#000"/></mask>`
    : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="${size}" height="${size}">${mask}<path d="${routeD(v)}" fill="none" stroke="${color}" stroke-width="${v.stroke}" stroke-linecap="round" stroke-linejoin="round"${v.gap ? ' mask="url(#m)"' : ''}/><circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}"/></svg>`;
}

// Groups 1 (health), 3 (geo), 4 (categories) — public reads (TASK-14 §5.3).
import { check, expect, get, section, uuid } from './lib.mjs';
import { throwaway } from './env.mjs';

/** Interior points (ST_PointOnSurface of the ward polygons); the sweep asserts them via /geo/locate. */
export const PT18 = { lat: 23.02859, lng: 72.553223 };
export const PT15 = { lat: 23.049796, lng: 72.613741 };
export const NEAR_OUTSIDE = { lat: 23.14, lng: 72.58 };
export const FAR_OUTSIDE = { lat: 24.5, lng: 72.5 };

export async function g1Health() {
  section('1 Health');
  const h = await get('/health');
  check('GET /health → 200 status ok, db up', h.status === 200 && h.data?.status === 'ok' && h.data?.db === 'up', `${h.status}`);
  // Throwaway instance whose database is unreachable (the shared dev database is never stopped).
  const t = await throwaway({ DATABASE_URL: 'postgresql://sweep:sweep@127.0.0.1:1/none' }, 4201);
  try {
    expect('GET /health with the database unreachable → 503 SERVICE_UNAVAILABLE', await get(`${t.url}/health`), 503, 'SERVICE_UNAVAILABLE');
  } finally {
    t.stop();
  }
}

export async function g3Geo(ctx) {
  section('3 Geo');
  const wards = await get('/wards');
  ctx.wards = wards.data?.items ?? [];
  check('GET /wards → 200 with 48 wards', wards.status === 200 && ctx.wards.length === 48, `${wards.status} n=${ctx.wards.length}`);
  ctx.ward18 = ctx.wards.find((w) => w.number === 18);
  ctx.ward15 = ctx.wards.find((w) => w.number === 15);
  const w = await get(`/wards/${ctx.ward18?.id}`);
  check('GET /wards/{id} → 200 ward 18', w.status === 200 && w.data?.number === 18, `${w.status}`);
  expect('GET /wards/{unknown id} → 404 NOT_FOUND', await get(`/wards/${uuid()}`), 404, 'NOT_FOUND');
  expect('GET /wards/{not-a-uuid} → 400 VALIDATION_FAILED', await get('/wards/abc'), 400, 'VALIDATION_FAILED');
  const z = await get('/zones');
  check('GET /zones → 200 with zones', z.status === 200 && (z.data?.items?.length ?? 0) >= 6, `${z.status} n=${z.data?.items?.length}`);
  const l18 = await get(`/geo/locate?lat=${PT18.lat}&lng=${PT18.lng}`);
  check('GET /geo/locate inside ward 18 → match inside, confirm false', l18.data?.ward?.number === 18 && l18.data?.match === 'inside' && l18.data?.confirm === false, `${l18.status} ${l18.data?.match}`);
  const l15 = await get(`/geo/locate?lat=${PT15.lat}&lng=${PT15.lng}`);
  check('GET /geo/locate inside ward 15 → ward 15', l15.data?.ward?.number === 15, `${l15.status}`);
  const near = await get(`/geo/locate?lat=${NEAR_OUTSIDE.lat}&lng=${NEAR_OUTSIDE.lng}`);
  check('GET /geo/locate just outside the polygons → nearest ward + confirm:true', near.status === 200 && near.data?.match === 'nearest' && near.data?.confirm === true, `${near.status} ${near.data?.match} ${near.data?.distanceM} m`);
  expect('GET /geo/locate far outside → 422 OUTSIDE_SERVICE_AREA', await get(`/geo/locate?lat=${FAR_OUTSIDE.lat}&lng=${FAR_OUTSIDE.lng}`), 422, 'OUTSIDE_SERVICE_AREA');
  expect('GET /geo/locate bad coords → 400 VALIDATION_FAILED', await get('/geo/locate?lat=abc&lng=72.5'), 400, 'VALIDATION_FAILED');
  expect('GET /geo/locate lat out of range → 400 VALIDATION_FAILED', await get('/geo/locate?lat=123&lng=72.5'), 400, 'VALIDATION_FAILED');
}

export async function g4Categories(ctx) {
  section('4 Categories');
  const c = await get('/categories');
  ctx.categories = c.data?.items ?? [];
  check('GET /categories → 200 with active categories', c.status === 200 && ctx.categories.length >= 10, `${c.status} n=${ctx.categories.length}`);
  ctx.cat = ctx.categories.find((x) => x.slug === 'roads') ?? ctx.categories.find((x) => !x.sensitive) ?? ctx.categories[0];
  check('categories carry slug, names in en+gu', ctx.categories.every((x) => x.slug && x.nameEn && x.nameGu));
}

/** Runs last: exhausts the 120/IP/min public read budget on /categories. */
export async function g4RateLimit() {
  section('4 Categories — public read limit (runs last)');
  let first429 = 0;
  let last;
  for (let i = 1; i <= 125; i++) {
    last = await get('/categories');
    if (last.status === 429) {
      first429 = i;
      break;
    }
  }
  check('GET /categories → 429 RATE_LIMITED within 121 requests/min', first429 > 0 && first429 <= 121 && last.data?.error?.code === 'RATE_LIMITED', `first 429 at request ${first429}`);
  check('429 carries Retry-After', Boolean(last.headers.get('retry-after')));
}

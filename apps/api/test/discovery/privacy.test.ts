// T-07-12 privacy scan (REQ-S-006): no public response carries reporter id, name or phone, a
// client_submission_id or a CCRS number — anonymously or as another citizen.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { clearFeedCache } from '../../src/modules/feed';
import { resetDb } from '../helpers/db';
import { api, get, INSIDE, photoIssue, PII, piiReporter, seedReference, user, ward } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
  clearFeedCache();
});

describe('privacy scan across public discovery responses', () => {
  it('feed, list, detail, map, events, nearby and /i/{id}', async () => {
    const reporter = await piiReporter();
    const { issue } = await photoIssue(reporter.user.id, { ccrsNumber: 'CCRS-777001', status: 'sent', description: 'Deep pothole near the bus stop' });
    await prisma.issueEvent.create({ data: { issueId: issue.id, actorId: reporter.user.id, actorRole: 'citizen', type: 'ccrs_linked', note: 'via:web' } });
    const w = await ward(1);
    const forbidden = [reporter.user.id, PII.name, PII.phone, issue.clientSubmissionId, 'CCRS-777001', reporter.user.firebaseUid ?? 'no-uid'];
    const other = await user();
    const paths = [
      `/api/v1/feed?ward=${w.id}`,
      `/api/v1/issues?ward=${w.id}`,
      `/api/v1/issues/${issue.id}`,
      `/api/v1/issues/${issue.id}?lang=gu`,
      `/api/v1/map/issues?bbox=72.49,22.99,72.52,23.02&zoom=12`,
      `/api/v1/map/issues?bbox=72.49,22.99,72.52,23.02&zoom=16`,
      `/api/v1/issues/${issue.id}/events`,
      `/api/v1/issues/nearby?lat=${INSIDE.lat}&lng=${INSIDE.lng}&category=roads`,
      `/i/${issue.id}`,
    ];
    for (const auth of [undefined, other.auth]) {
      for (const p of paths) {
        const res = await (auth ? api().get(p).set(auth) : api().get(p));
        expect(res.status, p).toBe(200);
        const text = res.text || JSON.stringify(res.body);
        for (const f of forbidden) expect(text.includes(f), `${p} leaks ${f}`).toBe(false);
        for (const key of ['reporterId', 'reporter_id', 'phoneE164', 'displayName', 'clientSubmissionId', 'ccrsNumber', 'legacyComplaintId']) {
          expect(text.includes(`"${key}"`), `${p} has key ${key}`).toBe(false);
        }
      }
    }
    const detail = await get(`/api/v1/issues/${issue.id}`);
    expect(detail.body.issue.reporterLabel).toEqual({ en: `A resident of ${w.nameEn}`, gu: `${w.nameGu}ના રહેવાસી` });
  });
});

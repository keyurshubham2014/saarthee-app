// T-12-13 (AC-12): GET /me/export includes rsvps; DELETE /me removes RSVPs and frees seats on future drives.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { signIn, useFakeFirebase } from '../auth/helpers';
import { goingRsvp, inHours, makeInitiative, roleUser } from '../services/helpers';

const gw = useFakeFirebase();
beforeEach(resetDb);

describe('T-12-13 privacy hooks for rsvps', () => {
  it('exports the user’s RSVPs and erases them, decrementing only future drives', async () => {
    const me = await signIn(gw);
    const other = await roleUser();
    const future = await makeInitiative({ startsAt: inHours(48), titleEn: 'Future drive' });
    const past = await makeInitiative({ startsAt: inHours(-48), endsAt: inHours(-46), status: 'completed', titleEn: 'Past drive' });
    await goingRsvp(future.id, me.user.id);
    await goingRsvp(future.id, other.user.id);
    await goingRsvp(past.id, me.user.id);

    const exp = await api().get('/api/v1/me/export').set(me.auth);
    expect(exp.status).toBe(200);
    const body = typeof exp.body === 'object' && Object.keys(exp.body).length > 0 ? exp.body : JSON.parse(exp.text);
    expect(body.rsvps).toHaveLength(2);
    expect(body.rsvps[0]).toMatchObject({ initiativeId: future.id, titleEn: 'Future drive', status: 'going' });

    const del = await api().delete('/api/v1/me').set(me.auth).send({ confirm: 'DELETE' });
    expect(del.status).toBe(204);
    expect(await prisma.rsvp.count({ where: { userId: me.user.id } })).toBe(0);
    expect((await prisma.initiative.findUniqueOrThrow({ where: { id: future.id } })).goingCount).toBe(1);
    expect((await prisma.initiative.findUniqueOrThrow({ where: { id: past.id } })).goingCount).toBe(1);
    expect(await prisma.rsvp.count({ where: { userId: other.user.id } })).toBe(1);
  });
});

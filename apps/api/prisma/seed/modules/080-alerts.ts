import type { AlertSeverity, AlertStatus, AlertType, Prisma } from '@prisma/client';
import { defineSeedModule } from '../types';
import { seedUserId } from './040-citizens';

/**
 * V2 TASK-08: fictional sample alerts (every severity and status), extra-ward subscriptions for two sample
 * citizens and inbox rows of every kind for Asha (21). Fixed ids; create-if-missing, so a second run changes
 * nothing. Needs the wards module (060) for ward targets; skips with a log line when no wards exist.
 */
const alertId = (nn: number) => `5eed0008-0000-4000-8000-0000000000${String(nn).padStart(2, '0')}`;
const HOUR = 3_600_000;
const MOD = seedUserId(25);
const SRC = { sourceName: 'AMC (sample data)', sourceUrl: 'https://ahmedabadcity.gov.in' };

interface Sample {
  nn: number;
  type: AlertType;
  severity: AlertSeverity;
  status: AlertStatus;
  en: [string, string];
  gu: [string, string];
  fromH: number;
  toH: number;
  wards: number[] | 'city';
  approvals: number;
  supersedes?: number;
  retracted?: string;
  sachet?: boolean;
}

const SAMPLES: Sample[] = [
  { nn: 1, type: 'water_timing', severity: 'info', status: 'published', en: ['Water timing changed in Paldi', 'Morning supply will be from 6:30 to 8:30 this week (sample).'], gu: ['પાલડીમાં પાણીનો સમય બદલાયો', 'આ અઠવાડિયે સવારે 6:30 થી 8:30 પાણી આવશે (નમૂનો).'], fromH: -2, toH: 48, wards: [12], approvals: 1 },
  { nn: 2, type: 'road_closure', severity: 'advisory', status: 'published', en: ['Road closed near the ward office', 'One lane closed for drainage work until evening (sample).'], gu: ['વોર્ડ ઓફિસ પાસે રસ્તો બંધ', 'ગટર કામ માટે સાંજ સુધી એક લેન બંધ (નમૂનો).'], fromH: -1, toH: 10, wards: [12, 15], approvals: 1 },
  { nn: 3, type: 'water_cut', severity: 'warning', status: 'published', en: ['Water cut tomorrow morning', 'No supply from 10:00 to 16:00 for pipeline repair (sample).'], gu: ['આવતીકાલે સવારે પાણી બંધ', 'પાઇપલાઇન સમારકામ માટે 10:00 થી 16:00 પાણી બંધ (નમૂનો).'], fromH: 20, toH: 30, wards: [12], approvals: 2 },
  { nn: 4, type: 'heat', severity: 'critical', status: 'published', en: ['Severe heat today', 'Stay indoors from noon to 4 pm and drink water often (sample).'], gu: ['આજે તીવ્ર ગરમી', 'બપોરે 12 થી 4 ઘરમાં રહો અને વારંવાર પાણી પીઓ (નમૂનો).'], fromH: -3, toH: 12, wards: 'city', approvals: 2 },
  { nn: 5, type: 'rain_flood', severity: 'warning', status: 'pending_approval', en: ['Waterlogging likely in low areas', 'Avoid underpasses during heavy rain tonight (sample).'], gu: ['નીચાણવાળા વિસ્તારમાં પાણી ભરાવાની શક્યતા', 'આજે રાત્રે ભારે વરસાદમાં અંડરપાસ ટાળો (નમૂનો).'], fromH: 2, toH: 20, wards: [12, 15], approvals: 1 },
  { nn: 6, type: 'health', severity: 'advisory', status: 'expired', en: ['Dengue check drive ended', 'Thank you for clearing standing water (sample).'], gu: ['ડેન્ગ્યુ તપાસ અભિયાન પૂર્ણ', 'ભરાયેલું પાણી સાફ કરવા બદલ આભાર (નમૂનો).'], fromH: -72, toH: -24, wards: [12], approvals: 1 },
  { nn: 7, type: 'road_closure', severity: 'info', status: 'retracted', en: ['Road closure (sent by mistake)', 'This closure notice was sent to the wrong ward (sample).'], gu: ['રસ્તો બંધ (ભૂલથી મોકલ્યું)', 'આ સૂચના ખોટા વોર્ડમાં મોકલાઈ હતી (નમૂનો).'], fromH: -30, toH: 20, wards: [15], approvals: 1, retracted: 'Sent to the wrong ward' },
  { nn: 8, type: 'water_cut', severity: 'advisory', status: 'expired', en: ['Water cut on Friday', 'Supply off on Friday morning (sample).'], gu: ['શુક્રવારે પાણી બંધ', 'શુક્રવારે સવારે પાણી બંધ (નમૂનો).'], fromH: -10, toH: -1, wards: [15], approvals: 1 },
  { nn: 9, type: 'water_cut', severity: 'advisory', status: 'published', en: ['Water cut moved to Saturday', 'Supply off on Saturday morning instead of Friday (sample).'], gu: ['પાણી બંધ શનિવારે ખસેડાયું', 'શુક્રવારને બદલે શનિવારે સવારે પાણી બંધ (નમૂનો).'], fromH: -1, toH: 40, wards: [15], approvals: 1, supersedes: 8 },
  { nn: 10, type: 'heat', severity: 'warning', status: 'draft', en: ['Heat wave likely over Ahmedabad', 'Maximum temperature 44–45 °C likely (sample SACHET draft).'], gu: ['', ''], fromH: 1, toH: 30, wards: 'city', approvals: 0, sachet: true },
];

export default defineSeedModule({
  name: 'alerts',
  requires: ['alerts', 'alert_wards', 'subscriptions', 'wards'],
  async run({ prisma, log }) {
    const wards = await prisma.ward.findMany({ select: { id: true, number: true } });
    if (wards.length === 0) return log('Seed alerts: no wards (run the wards module first) — skipped');
    const ward = (n: number) => wards.find((w) => w.number === n)?.id ?? wards[0]!.id;
    const now = Date.now();
    let created = 0;
    for (const s of SAMPLES) {
      const id = alertId(s.nn);
      if (await prisma.alert.findUnique({ where: { id }, select: { id: true } })) continue;
      const published = s.status === 'published' || s.status === 'expired' || s.status === 'retracted';
      const data: Prisma.AlertUncheckedCreateInput = {
        id, type: s.type, severity: s.severity, status: s.status,
        titleEn: s.en[0], bodyEn: s.en[1], titleGu: s.gu[0], bodyGu: s.gu[1], ...SRC,
        validFrom: new Date(now + s.fromH * HOUR), validTo: new Date(now + s.toH * HOUR),
        targetScope: s.wards === 'city' ? 'city' : 'wards',
        createdBy: s.sachet ? null : MOD,
        approvedBy: Array.from({ length: s.approvals }, (_, i) => (i === 0 ? MOD : '5eed0008-0000-4000-8000-00000000ad01')),
        submittedAt: s.status === 'draft' ? null : new Date(now - 4 * HOUR),
        publishedAt: published ? new Date(now + Math.min(s.fromH, 0) * HOUR - HOUR) : null,
        supersedesId: s.supersedes ? alertId(s.supersedes) : null,
        ...(s.retracted ? { retractedAt: new Date(now - 2 * HOUR), retractedBy: MOD, retractionReason: s.retracted } : {}),
        ...(s.sachet ? { origin: 'sachet' as const, originRef: 'IN-SAMPLE-0000000001', sourceName: 'NDMA SACHET (IMD Ahmedabad)', sourceUrl: 'https://sachet.ndma.gov.in' } : {}),
      };
      await prisma.alert.create({ data });
      const ids = s.wards === 'city' ? wards.map((w) => w.id) : [...new Set(s.wards.map(ward))];
      await prisma.alertWard.createMany({ data: ids.map((wardId) => ({ alertId: id, wardId })) });
      created++;
    }
    await prisma.user.updateMany({ where: { id: seedUserId(21), homeWardId: null }, data: { homeWardId: ward(12) } });
    await prisma.user.updateMany({ where: { id: seedUserId(22), homeWardId: null }, data: { homeWardId: ward(15) } });
    for (const [nn, extra] of [[21, 15], [22, 12]] as const) {
      const userId = seedUserId(nn);
      if (!(await prisma.subscription.findFirst({ where: { userId } }))) {
        await prisma.subscription.createMany({ data: [{ userId, scope: 'ward', scopeId: ward(extra) }, { userId, scope: 'city' }] });
      }
    }
    const asha = seedUserId(21);
    if ((await prisma.notification.count({ where: { userId: asha } })) === 0) {
      const row = (kind: string, refId: string | null, route: string, en: string, gu: string, hoursAgo: number, read: boolean) => ({
        userId: asha, kind, refId, route, channel: kind === 'alert' ? 'alerts' : 'updates', titleEn: en, titleGu: gu,
        bodyEn: en, bodyGu: gu, status: 'sent', sentAt: new Date(now - hoursAgo * HOUR), createdAt: new Date(now - hoursAgo * HOUR),
        readAt: read ? new Date(now - hoursAgo * HOUR + 60_000) : null,
      });
      await prisma.notification.createMany({
        data: [
          row('alert', alertId(4), `/alerts/${alertId(4)}`, 'Severe heat today', 'આજે તીવ્ર ગરમી', 3, false),
          row('alert', alertId(1), `/alerts/${alertId(1)}`, 'Water timing changed in Paldi', 'પાલડીમાં પાણીનો સમય બદલાયો', 2, false),
          row('issue_update', null, '/me/notifications', 'Your report is in progress (sample)', 'તમારી ફરિયાદ પર કામ ચાલુ છે (નમૂનો)', 30, true),
          row('initiative', null, '/me/notifications', 'Tree planting drive on Sunday (sample)', 'રવિવારે વૃક્ષારોપણ અભિયાન (નમૂનો)', 50, false),
        ],
      });
    }
    log(`Seed alerts: ${created} sample alerts created`);
  },
});

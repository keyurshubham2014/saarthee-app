import { seedServices } from '../../../src/modules/services/seed';
import { defineSeedModule } from '../types';

/** Fixed ids for the three dev seasonal tips (create-if-missing keeps the seed idempotent). */
export const seedTipId = (n: number) => `5eed0012-0000-4000-8000-0000000001${String(n).padStart(2, '0')}`;

/**
 * V2 TASK-12: the verified AMC services (same code path as `npm run services:seed`, insert-missing-only)
 * plus three fictional-window seasonal tips for development (staff set real windows in production).
 */
export default defineSeedModule({
  name: 'services',
  requires: ['services', 'service_tips'],
  async run({ prisma, log }) {
    const r = await seedServices(prisma);
    log(`Seed services: inserted=${r.inserted} unchanged=${r.unchanged}`);
    const year = new Date().getUTCFullYear();
    const day = (m: number, d: number) => new Date(Date.UTC(year, m - 1, d));
    const ptax = await prisma.service.findUnique({ where: { slug: 'property-tax-pay' }, select: { id: true } });
    const uhc = await prisma.service.findUnique({ where: { slug: 'urban-health-centres' }, select: { id: true } });
    const tips = [
      {
        id: seedTipId(1),
        titleEn: 'Property tax early-payment rebate',
        titleGu: 'મિલકત વેરો વહેલો ભરવા પર વળતર',
        bodyEn: "AMC usually offers a rebate for paying property tax early in the year. Check the official page for this year's dates.",
        bodyGu: 'વર્ષની શરૂઆતમાં મિલકત વેરો ભરવા પર AMC સામાન્ય રીતે વળતર આપે છે. આ વર્ષની તારીખો સત્તાવાર પેજ પર જુઓ.',
        serviceId: ptax?.id ?? null,
        activeFrom: day(4, 1),
        activeTo: day(5, 31),
      },
      {
        id: seedTipId(2),
        titleEn: 'Monsoon: report waterlogging early',
        titleGu: 'ચોમાસું: પાણી ભરાવાની જાણ વહેલી કરો',
        bodyEn: "Report waterlogging and open drains early. Keep AMC's flood helpline handy.",
        bodyGu: 'પાણી ભરાવું અને ખુલ્લી ગટરની જાણ વહેલી કરો. AMCની પૂર હેલ્પલાઇન હાથવગી રાખો.',
        serviceId: null,
        activeFrom: day(6, 1),
        activeTo: day(10, 15),
      },
      {
        id: seedTipId(3),
        titleEn: 'Heat alert: look after each other',
        titleGu: 'ગરમીની ચેતવણી: એકબીજાનું ધ્યાન રાખો',
        bodyEn: 'During heat alerts, drink water often and check on older neighbours. Urban health centres can help.',
        bodyGu: 'ગરમીની ચેતવણી વખતે વારંવાર પાણી પીઓ અને વૃદ્ધ પડોશીઓની ખબર રાખો. અર્બન હેલ્થ સેન્ટર મદદ કરી શકે.',
        serviceId: uhc?.id ?? null,
        activeFrom: day(4, 1),
        activeTo: day(6, 30),
      },
    ];
    for (const t of tips) {
      if (await prisma.serviceTip.findUnique({ where: { id: t.id }, select: { id: true } })) continue;
      await prisma.serviceTip.create({ data: t });
    }
  },
});

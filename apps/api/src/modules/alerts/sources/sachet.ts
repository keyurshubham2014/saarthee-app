import type { AlertSeverity, AlertType } from '@prisma/client';
import { config } from '../../../config';
import { AHMEDABAD, mapSeverity, mapType, parseCap, parseRss, polygonToWkt, type CapAlert } from './cap';
import { httpFetchText, type FetchText } from './http';

/** One candidate draft from a feed (never published automatically). */
export interface DraftInput {
  origin: 'sachet' | 'imd';
  originRef: string;
  msgType: string;
  type: AlertType;
  severity: AlertSeverity;
  titleEn: string;
  titleGu: string;
  bodyEn: string;
  bodyGu: string;
  sourceName: string;
  sourceUrl: string;
  validFrom: Date;
  validTo: Date;
  /** areaDesc mentions Ahmedabad (en or gu). */
  areaMatched: boolean;
  /** WKT polygons (lon lat) from the CAP areas. */
  polygons: string[];
}

/** Feed adapter contract (§5.3): SACHET now, IMD once access and a sample response exist. */
export interface AlertSource {
  name: 'sachet' | 'imd';
  fetchDrafts(): Promise<{ drafts: DraftInput[]; failed: number }>;
}

const clip = (s: string, n: number) => (s.length <= n ? s : `${s.slice(0, n - 1).trimEnd()}…`);

/** Maps one CAP alert to a draft (§5.3 mapping). Returns null when it has no usable English info block. */
export function capToDraft(cap: CapAlert, link: string): DraftInput | null {
  const en = cap.infos.find((i) => i.language.toLowerCase().startsWith('en')) ?? cap.infos[0];
  if (!en || !en.expires) return null;
  const gu = cap.infos.find((i) => i.language.toLowerCase().startsWith('gu'));
  const body = (i: typeof en) => i.description || i.instruction || i.headline;
  const areas = cap.infos.flatMap((i) => i.areas);
  const sender = en.senderName || cap.sender || 'NDMA';
  const validTo = new Date(en.expires);
  const fromText = en.onset ?? en.effective ?? cap.sent;
  let validFrom = new Date(fromText);
  if (Number.isNaN(validFrom.getTime()) || validFrom >= validTo) validFrom = new Date(cap.sent);
  if (Number.isNaN(validTo.getTime()) || Number.isNaN(validFrom.getTime()) || validFrom >= validTo) return null;
  return {
    origin: 'sachet',
    originRef: cap.identifier,
    msgType: cap.msgType,
    type: mapType(en.event),
    severity: mapSeverity(en.severity),
    titleEn: clip(en.headline || en.event, 80),
    titleGu: gu ? clip(gu.headline || gu.event, 80) : '',
    bodyEn: clip(body(en), 500),
    bodyGu: gu ? clip(body(gu), 500) : '',
    sourceName: clip(`NDMA SACHET (${sender})`, 80),
    sourceUrl: link,
    validFrom,
    validTo,
    areaMatched: areas.some((a) => AHMEDABAD.test(a.areaDesc)),
    polygons: areas.flatMap((a) => a.polygons.map(polygonToWkt).filter((w): w is string => !!w)),
  };
}

/** SACHET RSS → CAP files → drafts. Per-item failures are counted, never thrown. */
export function sachetSource(fetchText: FetchText = httpFetchText, feedUrl: string = config.SACHET_FEED_URL): AlertSource {
  return {
    name: 'sachet',
    async fetchDrafts() {
      const feed = await fetchText(feedUrl);
      if (feed.status === 'not_modified') return { drafts: [], failed: 0 };
      const drafts: DraftInput[] = [];
      let failed = 0;
      for (const item of parseRss(feed.body)) {
        try {
          const capRes = await fetchText(item.link);
          if (capRes.status === 'not_modified') continue;
          const d = capToDraft(parseCap(capRes.body), item.link);
          if (d) drafts.push(d);
          else failed++;
        } catch {
          failed++;
        }
      }
      return { drafts, failed };
    },
  };
}

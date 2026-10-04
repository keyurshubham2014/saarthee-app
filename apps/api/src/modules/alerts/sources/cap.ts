import { XMLParser } from 'fast-xml-parser';
import type { AlertSeverity, AlertType } from '@prisma/client';

/** OASIS CAP 1.2 as published by NDMA SACHET (namespace prefix `cap:`, stripped here). */
export interface CapArea {
  areaDesc: string;
  /** CAP polygons: "lat,lon lat,lon …" (closed rings). */
  polygons: string[];
}

export interface CapInfo {
  language: string;
  event: string;
  severity: string;
  effective?: string;
  onset?: string;
  expires?: string;
  headline: string;
  description: string;
  instruction: string;
  senderName: string;
  areas: CapArea[];
}

export interface CapAlert {
  identifier: string;
  sender: string;
  sent: string;
  msgType: string;
  infos: CapInfo[];
}

const ARRAYS = new Set(['item', 'info', 'area', 'polygon']);

const parser = new XMLParser({
  removeNSPrefix: true,
  ignoreAttributes: true,
  parseTagValue: false,
  trimValues: true,
  processEntities: true,
  isArray: (name) => ARRAYS.has(name),
});

const str = (v: unknown): string => (typeof v === 'string' ? v : typeof v === 'number' ? String(v) : '');

/** RSS 2.0 feed → CAP links (`<link>`) and ids (`<guid>`), in feed order. */
export function parseRss(xml: string): { link: string; guid: string }[] {
  const doc = parser.parse(xml) as { rss?: { channel?: { item?: Record<string, unknown>[] } } };
  return (doc.rss?.channel?.item ?? []).map((i) => ({ link: str(i.link), guid: str(i.guid) })).filter((i) => i.link.startsWith('https://'));
}

export function parseCap(xml: string): CapAlert {
  const doc = parser.parse(xml) as { alert?: Record<string, unknown> };
  const a = doc.alert;
  if (!a || !str(a.identifier)) throw new Error('not a CAP alert');
  const infos = ((a.info as Record<string, unknown>[] | undefined) ?? []).map((i) => ({
    language: str(i.language) || 'en-US',
    event: str(i.event),
    severity: str(i.severity),
    effective: str(i.effective) || undefined,
    onset: str(i.onset) || undefined,
    expires: str(i.expires) || undefined,
    headline: str(i.headline),
    description: str(i.description),
    instruction: str(i.instruction),
    senderName: str(i.senderName),
    areas: ((i.area as Record<string, unknown>[] | undefined) ?? []).map((ar) => ({
      areaDesc: str(ar.areaDesc),
      polygons: ((ar.polygon as unknown[] | undefined) ?? []).map(str).filter(Boolean),
    })),
  }));
  return { identifier: str(a.identifier), sender: str(a.sender), sent: str(a.sent), msgType: str(a.msgType), infos };
}

export function mapSeverity(capSeverity: string): AlertSeverity {
  switch (capSeverity.toLowerCase()) {
    case 'extreme':
      return 'critical';
    case 'severe':
      return 'warning';
    case 'moderate':
      return 'advisory';
    default:
      return 'info';
  }
}

export function mapType(event: string): AlertType {
  const e = event.toLowerCase();
  if (e.includes('heat')) return 'heat';
  if (/rain|flood|thunder|cyclone/.test(e)) return 'rain_flood';
  return 'other';
}

export const AHMEDABAD = /ahmedabad|અમદાવાદ/i;

/** CAP polygon text → WKT POLYGON (lon lat order); null when malformed. */
export function polygonToWkt(text: string): string | null {
  const pts = text
    .trim()
    .split(/\s+/)
    .map((p) => p.split(',').map(Number));
  if (pts.length < 4 || pts.some((p) => p.length !== 2 || p.some((n) => !Number.isFinite(n)))) return null;
  const first = pts[0]!;
  const last = pts[pts.length - 1]!;
  if (first[0] !== last[0] || first[1] !== last[1]) pts.push(first);
  return `POLYGON((${pts.map(([lat, lon]) => `${lon} ${lat}`).join(', ')}))`;
}

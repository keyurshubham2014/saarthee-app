import { prisma } from '../../lib/db';
import { csvRow, type CsvValue } from '../../lib/csv';

export type ExportType = 'complaints' | 'verifications' | 'reminders';

interface ComplaintExportRow {
  id: string;
  created_at: Date;
  source_tag: string;
  group_label: string | null;
  category_name: string;
  ccrs_number_raw: string;
  ccrs_number_normalized: string;
  ccrs_duplicate_flag: boolean;
  latitude: CsvValue;
  longitude: CsvValue;
  gps_accuracy_m: CsvValue;
  device_captured_at: Date;
  phone_e164: string | null;
  consent_given_at: Date;
  consent_text_version: string;
  app_platform: string;
  app_version: string;
  ward_code: string | null;
  status: string;
  reminder_count: number;
  last_reminder_at: Date | null;
  verification_count: number;
  latest_result: string | null;
  latest_verified_at: Date | null;
  is_excluded: boolean;
  exclusion_reason: string | null;
  exclusion_note: string | null;
  excluded_at: Date | null;
  anonymized_at: Date | null;
}

/** Builds the CSV text. Phone numbers appear only for complaints with includePhone=true (03 §4.6). */
export async function buildExport(type: ExportType, includePhone: boolean): Promise<string> {
  if (type === 'complaints') {
    const rows = await prisma.$queryRaw<ComplaintExportRow[]>`
      SELECT c.id, c.created_at, c.source_tag::text AS source_tag, ic.group_label, cat.name AS category_name,
             c.ccrs_number_raw, c.ccrs_number_normalized, c.ccrs_duplicate_flag, c.latitude, c.longitude,
             c.gps_accuracy_m, c.device_captured_at, c.phone_e164, c.consent_given_at, c.consent_text_version,
             c.app_platform::text AS app_platform, c.app_version, c.ward_code, s.status, s.reminder_count,
             s.last_reminder_at, s.verification_count, s.latest_result::text AS latest_result, s.latest_verified_at,
             c.is_excluded, c.exclusion_reason::text AS exclusion_reason, c.exclusion_note, c.excluded_at, c.anonymized_at
      FROM complaints c
      JOIN complaint_status_v s ON s.complaint_id = c.id
      JOIN ccrs_categories cat ON cat.id = c.category_id
      LEFT JOIN invite_codes ic ON ic.id = c.invite_code_id
      ORDER BY c.created_at, c.id`;
    const head = [
      'id', 'created_at', 'source_tag', 'group_label', 'category', 'ccrs_number_raw', 'ccrs_number_normalized',
      'ccrs_duplicate_flag', 'latitude', 'longitude', 'gps_accuracy_m', 'device_captured_at',
      ...(includePhone ? ['phone_e164'] : []),
      'consent_given_at', 'consent_text_version', 'app_platform', 'app_version', 'ward_code', 'status',
      'reminder_count', 'last_reminder_at', 'verification_count', 'latest_result', 'latest_verified_at',
      'is_excluded', 'exclusion_reason', 'exclusion_note', 'excluded_at', 'anonymized_at',
    ];
    let out = csvRow(head);
    for (const r of rows) {
      out += csvRow([
        r.id, r.created_at, r.source_tag, r.group_label, r.category_name, r.ccrs_number_raw, r.ccrs_number_normalized,
        r.ccrs_duplicate_flag, r.latitude, r.longitude, r.gps_accuracy_m, r.device_captured_at,
        ...(includePhone ? [r.phone_e164] : []),
        r.consent_given_at, r.consent_text_version, r.app_platform, r.app_version, r.ward_code, r.status,
        r.reminder_count, r.last_reminder_at, r.verification_count, r.latest_result, r.latest_verified_at,
        r.is_excluded, r.exclusion_reason, r.exclusion_note, r.excluded_at, r.anonymized_at,
      ]);
    }
    return out;
  }

  if (type === 'verifications') {
    const rows = await prisma.verification.findMany({
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      include: { photo: { select: { sha256: true } }, complaint: { select: { photo: { select: { sha256: true } } } } },
    });
    let out = csvRow([
      'id', 'complaint_id', 'reminder_id', 'result', 'created_at', 'device_captured_at', 'latitude', 'longitude',
      'gps_accuracy_m', 'distance_from_report_m', 'same_image_as_report', 'note', 'app_platform', 'app_version',
    ]);
    for (const v of rows) {
      out += csvRow([
        v.id, v.complaintId, v.reminderId, v.result, v.createdAt, v.deviceCapturedAt, v.latitude, v.longitude,
        v.gpsAccuracyM, v.distanceFromReportM, v.photo.sha256 === v.complaint.photo.sha256, v.note, v.appPlatform,
        v.appVersion,
      ]);
    }
    return out;
  }

  // Reminders: never the token hash.
  const rows = await prisma.reminder.findMany({
    orderBy: [{ sentAt: 'asc' }, { id: 'asc' }],
    select: {
      id: true,
      complaintId: true,
      channel: true,
      sentAt: true,
      expiresAt: true,
      revokedAt: true,
      sender: { select: { displayName: true } },
    },
  });
  let out = csvRow(['id', 'complaint_id', 'channel', 'sent_by', 'sent_at', 'expires_at', 'revoked_at']);
  for (const r of rows) {
    out += csvRow([r.id, r.complaintId, r.channel, r.sender.displayName, r.sentAt, r.expiresAt, r.revokedAt]);
  }
  return out;
}

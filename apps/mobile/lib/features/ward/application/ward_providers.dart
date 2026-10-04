import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/app_error.dart';
import '../data/ward_api.dart';
import '../data/ward_models.dart';

/// Last successful My Ward response per ward id, for the offline state
/// ("last cached ward"). Session-scoped (ASSUMPTION TASK-09 §5.6).
final wardRepsCacheProvider = Provider<Map<String, WardRepresentatives>>(
  (ref) => <String, WardRepresentatives>{},
);

/// Representatives for one ward; offline → the cached copy when present.
final wardRepresentativesProvider = FutureProvider.autoDispose
    .family<WardRepresentatives, String>((ref, wardId) async {
      final cache = ref.read(wardRepsCacheProvider);
      try {
        final r = await ref.read(wardApiProvider).wardRepresentatives(wardId);
        cache[wardId] = r;
        return r;
      } catch (e) {
        final err = AppError.from(e);
        final cached = cache[wardId];
        if (err.isOffline && cached != null) return cached.asCached();
        throw err;
      }
    });

final repDetailProvider = FutureProvider.autoDispose.family<RepDetail, String>((
  ref,
  id,
) async {
  try {
    return await ref.read(wardApiProvider).representative(id);
  } catch (e) {
    throw AppError.from(e);
  }
});

/// Last scorecard per ward (offline fallback, session-scoped).
final scorecardCacheProvider = Provider<Map<String, WardScorecard>>(
  (ref) => <String, WardScorecard>{},
);

final wardScorecardProvider = FutureProvider.autoDispose
    .family<WardScorecard, String>((ref, wardId) async {
      final cache = ref.read(scorecardCacheProvider);
      try {
        final s = await ref.read(wardApiProvider).scorecard(wardId);
        cache[wardId] = s;
        return s;
      } catch (e) {
        final err = AppError.from(e);
        final cached = cache[wardId];
        if (err.isOffline && cached != null) return cached;
        throw err;
      }
    });

/// New idempotency key for a message draft; the form keeps it until the
/// send succeeds so a retry never sends twice.
String newClientMessageId() => const Uuid().v4();

/// Error copy key for a failed relay send (screen maps it to ARB strings).
enum RelayFailure {
  consent,
  rateRep,
  rateDaily,
  language,
  noContact,
  offline,
  invalid,
  other,
}

RelayFailure relayFailureOf(Object error) {
  final e = AppError.from(error);
  if (e.isOffline) return RelayFailure.offline;
  switch (e.code) {
    case 'CONSENT_REQUIRED':
      return RelayFailure.consent;
    case 'RATE_LIMITED':
      final scope = e.details.where((d) => d.field == 'scope').firstOrNull;
      return scope?.issue == 'daily'
          ? RelayFailure.rateDaily
          : RelayFailure.rateRep;
    case 'MESSAGE_LANGUAGE':
      return RelayFailure.language;
    case 'REP_NO_CONTACT':
      return RelayFailure.noContact;
    case 'VALIDATION_FAILED':
      return RelayFailure.invalid;
    default:
      return RelayFailure.other;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../services/data/services_repository.dart' show Cached;
import '../data/initiative_models.dart';
import '../data/initiatives_repository.dart';

/// Upcoming drives for a ward (+ city-wide), or the whole city when null.
final initiativesListProvider = FutureProvider.autoDispose
    .family<Cached<List<Initiative>>, String?>(
      (ref, wardId) =>
          ref.watch(initiativesRepositoryProvider).list(wardId: wardId),
    );

/// Outcome of an RSVP action, for the screen's message.
enum RsvpOutcome { ok, full, notOpen, started, failed }

RsvpOutcome _outcome(AppError e) => switch (e.code) {
  'INITIATIVE_FULL' => RsvpOutcome.full,
  'INITIATIVE_NOT_OPEN' => RsvpOutcome.notOpen,
  'INITIATIVE_STARTED' => RsvpOutcome.started,
  _ => RsvpOutcome.failed,
};

/// One initiative plus its RSVP actions. The morph only happens after the
/// server confirms (§5.6 — no optimistic state).
class InitiativeDetailController extends AsyncNotifier<Initiative> {
  InitiativeDetailController(this.id);

  final String id;

  InitiativesRepository get _repo => ref.read(initiativesRepositoryProvider);

  @override
  Future<Initiative> build() =>
      ref.watch(initiativesRepositoryProvider).get(id);

  Future<void> reload() async {
    state = await AsyncValue.guard(() => _repo.get(id));
  }

  Future<RsvpOutcome> rsvp() async {
    final current = state.value;
    try {
      final r = await _repo.rsvp(id);
      if (current != null) {
        state = AsyncData(
          current.copyWith(goingCount: r.goingCount, myRsvp: 'going'),
        );
      }
      return RsvpOutcome.ok;
    } catch (e) {
      final outcome = _outcome(AppError.from(e));
      if (outcome == RsvpOutcome.full &&
          current != null &&
          current.capacity != null) {
        state = AsyncData(current.copyWith(goingCount: current.capacity));
      } else if (outcome == RsvpOutcome.notOpen ||
          outcome == RsvpOutcome.started) {
        await reload();
      }
      return outcome;
    }
  }

  Future<RsvpOutcome> cancel() async {
    final current = state.value;
    try {
      final r = await _repo.cancelRsvp(id);
      if (current != null) {
        state = AsyncData(
          current.copyWith(goingCount: r.goingCount, myRsvp: 'cancelled'),
        );
      }
      return RsvpOutcome.ok;
    } catch (e) {
      return _outcome(AppError.from(e));
    }
  }
}

final initiativeDetailProvider = AsyncNotifierProvider.autoDispose
    .family<InitiativeDetailController, Initiative, String>(
      InitiativeDetailController.new,
    );

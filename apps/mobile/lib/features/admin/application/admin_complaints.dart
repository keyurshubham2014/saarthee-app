import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../data/admin_api_error.dart';
import '../data/models/complaint_detail.dart';
import '../data/models/complaint_summary.dart';
import '../data/models/rate_row.dart';
import '../data/models/reminder_result.dart';
import 'admin_auth.dart';

AdminApiError asAdminError(Object error) =>
    error is AdminApiError ? error : const AdminApiError.unknown();

/// Paged complaint list state.
class ComplaintListState {
  const ComplaintListState({
    this.items = const <ComplaintSummary>[],
    this.nextCursor,
    this.loading = false,
    this.error,
    this.loadingMore = false,
    this.loadMoreError,
    this.loaded = false,
  });

  final List<ComplaintSummary> items;
  final String? nextCursor;
  final bool loading;
  final AdminApiError? error;
  final bool loadingMore;
  final AdminApiError? loadMoreError;
  final bool loaded;

  bool get hasMore => nextCursor != null;
}

/// `adminComplaintsProvider` (02 §5.2), family by filter.
final adminComplaintsProvider =
    NotifierProvider.family<
      ComplaintListController,
      ComplaintListState,
      ComplaintFilter
    >(ComplaintListController.new);

class ComplaintListController extends Notifier<ComplaintListState> {
  ComplaintListController(this.filter);

  final ComplaintFilter filter;
  int _generation = 0;

  @override
  ComplaintListState build() {
    _generation++;
    unawaited(Future<void>.microtask(refresh));
    return const ComplaintListState(loading: true);
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = ComplaintListState(
      items: state.items,
      nextCursor: state.nextCursor,
      loading: true,
      loaded: state.loaded,
    );
    try {
      final page = await ref
          .read(adminComplaintsRepositoryProvider)
          .list(filter);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = ComplaintListState(
        items: page.items,
        nextCursor: page.nextCursor,
        loaded: true,
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = ComplaintListState(
        items: state.items,
        nextCursor: state.nextCursor,
        error: asAdminError(e),
        loaded: state.loaded,
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.loading) {
      return;
    }
    final generation = _generation;
    state = ComplaintListState(
      items: state.items,
      nextCursor: cursor,
      loadingMore: true,
      loaded: true,
    );
    try {
      final page = await ref
          .read(adminComplaintsRepositoryProvider)
          .list(filter, cursor: cursor);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = ComplaintListState(
        items: <ComplaintSummary>[...state.items, ...page.items],
        nextCursor: page.nextCursor,
        loaded: true,
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = ComplaintListState(
        items: state.items,
        nextCursor: cursor,
        loadMoreError: asAdminError(e),
        loaded: true,
      );
    }
  }
}

/// Due badge count: first page of `due=true` with `limit=200`.
/// Null while unknown or on error (badge hidden).
final dueCountProvider = FutureProvider<int?>((ref) async {
  try {
    final page = await ref
        .read(adminComplaintsRepositoryProvider)
        .list(ComplaintFilter.dueOnly, limit: 200);
    return page.items.length;
  } on AdminApiError {
    return null;
  }
}, retry: (_, _) => null);

/// `ratesProvider` (02 §5.2).
final ratesProvider = FutureProvider<RatesSnapshot>(
  (ref) => ref.read(adminRatesRepositoryProvider).get(),
  retry: (_, _) => null,
);

/// Report photo bytes for a complaint (admin endpoint).
final adminReportPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, complaintId) =>
          ref.read(adminComplaintsRepositoryProvider).reportPhoto(complaintId),
      retry: (_, _) => null,
    );

/// Verification photo bytes (admin endpoint).
final adminVerificationPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, verificationId) => ref
          .read(adminComplaintsRepositoryProvider)
          .verificationPhoto(verificationId),
      retry: (_, _) => null,
    );

/// Complaint IDs with a reminder request in flight.
final reminderSenderProvider = NotifierProvider<ReminderSender, Set<String>>(
  ReminderSender.new,
);

class ReminderSender extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Creates one reminder. Returns null if one is already in flight for this
  /// complaint (double-tap guard). Throws [AdminApiError] on failure.
  Future<ReminderResult?> send(String complaintId) async {
    if (state.contains(complaintId)) {
      return null;
    }
    state = <String>{...state, complaintId};
    try {
      return await ref
          .read(adminComplaintsRepositoryProvider)
          .createReminder(complaintId);
    } on AdminApiError catch (e) {
      if (e.code == AdminErrorCodes.complaintExcluded ||
          e.code == AdminErrorCodes.complaintAnonymized) {
        refreshComplaintData(ref.invalidate);
      }
      rethrow;
    } finally {
      if (ref.mounted) {
        state = <String>{...state}..remove(complaintId);
      }
    }
  }
}

/// Refreshes every complaint list, the due badge, the rates and details
/// after a mutation (no optimistic updates, 02 §5.3).
void refreshComplaintData(
  void Function(ProviderOrFamily provider) invalidate, {
  String? complaintId,
}) {
  invalidate(adminComplaintsProvider);
  invalidate(dueCountProvider);
  invalidate(ratesProvider);
  if (complaintId != null) {
    invalidate(complaintDetailProvider(complaintId));
  } else {
    invalidate(complaintDetailProvider);
  }
}

/// `complaintDetailProvider` (02 §5.2), family by complaint ID.
final complaintDetailProvider = FutureProvider.autoDispose
    .family<ComplaintDetail, String>(
      (ref, id) => ref.read(adminComplaintsRepositoryProvider).detail(id),
      retry: (_, _) => null,
    );

/// Which detail action is running (`revoke:<id>`, `exclude`, `include`,
/// `anonymize`), or null.
final complaintActionsProvider = NotifierProvider.autoDispose
    .family<ComplaintActions, String?, String>(ComplaintActions.new);

class ComplaintActions extends Notifier<String?> {
  ComplaintActions(this.complaintId);

  final String complaintId;

  @override
  String? build() => null;

  Future<void> _run(String action, Future<void> Function() body) async {
    if (state != null) {
      return;
    }
    state = action;
    try {
      await body();
      refreshComplaintData(ref.invalidate, complaintId: complaintId);
    } finally {
      if (ref.mounted) {
        state = null;
      }
    }
  }

  Future<void> revokeReminder(String reminderId) => _run(
    'revoke:$reminderId',
    () =>
        ref.read(adminComplaintsRepositoryProvider).revokeReminder(reminderId),
  );

  Future<void> exclude({required String reason, String? note}) => _run(
    'exclude',
    () => ref
        .read(adminComplaintsRepositoryProvider)
        .setExclusion(
          complaintId,
          isExcluded: true,
          reason: reason,
          note: note,
        ),
  );

  Future<void> includeAgain() => _run(
    'include',
    () => ref
        .read(adminComplaintsRepositoryProvider)
        .setExclusion(complaintId, isExcluded: false),
  );

  Future<void> anonymize() => _run(
    'anonymize',
    () => ref.read(adminComplaintsRepositoryProvider).anonymize(complaintId),
  );
}

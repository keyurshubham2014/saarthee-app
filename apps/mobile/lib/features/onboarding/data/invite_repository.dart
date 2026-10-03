import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class InviteRepository {
  InviteRepository(this._api);

  final ApiClient _api;

  /// POST /invite-codes/validate → group label. Throws `AppError`.
  Future<String> validate(String code) async {
    final res = await _api.postJson(
      '/invite-codes/validate',
      body: {'code': code},
    );
    return '${res['groupLabel'] ?? ''}';
  }
}

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(ref.watch(apiClientProvider)),
);

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import 'account_models.dart';

/// Citizen account endpoints (TASK-04 §5.3). The session interceptor adds
/// `Authorization`; screens never call this directly (application layer).
abstract interface class AccountApi {
  Future<SessionGrant> exchange({
    required String idToken,
    required bool ageConfirmed,
    required String language,
    String? homeWardId,
    String? installId,
  });
  Future<void> logout({String? installId});
  Future<Me> getMe();
  Future<Me> patchMe(Map<String, Object?> fields);
  Future<List<MeConsent>> setConsent(ConsentPurpose purpose, bool granted);
  Future<String> exportData();
  Future<void> deleteAccount();
  Future<void> registerDevice(Map<String, Object?> body);
}

class HttpAccountApi implements AccountApi {
  HttpAccountApi(this._client);

  final ApiClient _client;

  @override
  Future<SessionGrant> exchange({
    required String idToken,
    required bool ageConfirmed,
    required String language,
    String? homeWardId,
    String? installId,
  }) async {
    final res = await _client.postJson(
      '/auth/firebase',
      body: {
        'idToken': idToken,
        'ageConfirmed': ageConfirmed,
        'consents': [
          {'purpose': 'core_service', 'textVersion': kConsentTextVersion},
        ],
        'language': language,
        'homeWardId': ?homeWardId,
        'installId': ?installId,
      },
    );
    return SessionGrant.fromJson(res);
  }

  @override
  Future<void> logout({String? installId}) async {
    await _client.postJson('/auth/logout', body: {'installId': ?installId});
  }

  @override
  Future<Me> getMe() async => Me.fromJson(await _client.getJson('/me'));

  @override
  Future<Me> patchMe(Map<String, Object?> fields) async =>
      Me.fromJson(await _client.patchJson('/me', body: fields));

  @override
  Future<List<MeConsent>> setConsent(
    ConsentPurpose purpose,
    bool granted,
  ) async {
    final res = await _client.postJson(
      '/me/consents',
      body: {
        'purpose': purpose.wire,
        'granted': granted,
        'textVersion': kConsentTextVersion,
      },
    );
    return Me.consentsFromJson(res['consents']);
  }

  @override
  Future<String> exportData() async {
    final res = await _client.getJson('/me/export');
    return const JsonEncoder.withIndent('  ').convert(res);
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.dio.delete<dynamic>('/me', data: {'confirm': 'DELETE'});
    } catch (e) {
      throw AppError.from(e);
    }
  }

  @override
  Future<void> registerDevice(Map<String, Object?> body) async {
    await _client.postJson('/devices', body: body);
  }
}

final accountApiProvider = Provider<AccountApi>(
  (ref) => HttpAccountApi(ref.watch(apiClientProvider)),
);

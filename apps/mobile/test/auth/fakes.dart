import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:saarthee/core/api/api_client.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/push/push_messaging.dart';
import 'package:saarthee/features/auth/data/account_api.dart';
import 'package:saarthee/features/auth/data/account_models.dart';
import 'package:saarthee/features/auth/data/auth_gateway.dart';
import 'package:saarthee/features/auth/data/secure_store.dart';
import 'package:saarthee/features/me/application/me_controller.dart';

/// Fictional test number and code (never real).
const testPhoneDigits = '9000000001';
const testCode = '123456';

class FakeAuthGateway implements AuthGateway {
  final List<String> calls = [];
  int signOuts = 0;

  /// Code verify behaviour: null = success, else the error code to throw.
  String? verifyError;

  @override
  bool get isConfigured => true;

  @override
  Future<String> sendCode(String phoneE164) async {
    calls.add('send');
    return 'verification-1';
  }

  @override
  Future<FirebaseSignIn> verifyCode(String verificationId, String code) async {
    calls.add('verify');
    if (verifyError != null) throw AuthGatewayException(verifyError!);
    if (code != testCode) {
      throw const AuthGatewayException(AuthGatewayException.wrongCode);
    }
    return const FirebaseSignIn(idToken: 'firebase-id-token', uid: 'uid-1');
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      'firebase-id-token';

  @override
  Future<void> signOut() async => signOuts++;
}

Me sampleMe({
  String? name,
  bool notifications = true,
  String language = 'en',
}) => Me(
  id: 'user-1',
  displayName: name,
  phoneMasked: '+91 ••••• ••001',
  language: language,
  role: 'citizen',
  homeWard: null,
  consents: [
    const MeConsent(
      purpose: ConsentPurpose.coreService,
      granted: true,
      textVersion: 'v2-1',
    ),
    MeConsent(
      purpose: ConsentPurpose.notifications,
      granted: notifications,
      textVersion: 'v2-1',
    ),
  ],
);

class FakeAccountApi implements AccountApi {
  final List<String> calls = [];
  final List<Map<String, Object?>> patches = [];
  final List<Map<String, Object?>> devices = [];

  /// First exchange without age → AGE_CONFIRMATION_REQUIRED (new account).
  bool newAccount = false;
  Me me = sampleMe();

  @override
  Future<SessionGrant> exchange({
    required String idToken,
    required bool ageConfirmed,
    required String language,
    String? homeWardId,
    String? installId,
  }) async {
    calls.add('exchange(age=$ageConfirmed)');
    if (newAccount && !ageConfirmed) {
      throw const AppError(code: 'AGE_CONFIRMATION_REQUIRED', statusCode: 403);
    }
    return SessionGrant(
      accessToken: 'session-jwt',
      expiresAt: DateTime(2030),
      me: me,
      isNew: newAccount,
    );
  }

  @override
  Future<void> logout({String? installId}) async => calls.add('logout');

  @override
  Future<Me> getMe() async {
    calls.add('getMe');
    return me;
  }

  @override
  Future<Me> patchMe(Map<String, Object?> fields) async {
    calls.add('patchMe');
    patches.add(fields);
    return me;
  }

  @override
  Future<List<MeConsent>> setConsent(
    ConsentPurpose purpose,
    bool granted,
  ) async {
    calls.add('consent(${purpose.wire},$granted)');
    me = me.copyWith(
      consents: [
        for (final c in me.consents)
          if (c.purpose != purpose) c,
        MeConsent(purpose: purpose, granted: granted, textVersion: 'v2-1'),
      ],
    );
    return me.consents;
  }

  @override
  Future<String> exportData() async {
    calls.add('export');
    return '{"profile":{}}';
  }

  @override
  Future<void> deleteAccount() async => calls.add('delete');

  @override
  Future<void> registerDevice(Map<String, Object?> body) async =>
      devices.add(body);
}

class FakeFileSharer implements FileSharer {
  final List<String> shared = [];

  @override
  Future<void> share(File file, {required String subject}) async =>
      shared.add(file.path);
}

class MemoryExportWriter implements ExportFileWriter {
  @override
  Future<File> write(String name, String contents) async {
    final dir = await Directory.systemTemp.createTemp('saarthee-export');
    return File('${dir.path}/$name').writeAsString(contents);
  }
}

/// Overrides for an app with the fake gateway, API, secure store and push.
List authOverrides({
  required FakeAuthGateway gateway,
  required FakeAccountApi api,
  MemorySecureStore? store,
  LocalOnlyPushMessaging? push,
  bool signedIn = false,
  RecordingAdapter? http,
}) {
  final s = store ?? MemorySecureStore();
  if (signedIn) s.values[SecureKeys.sessionToken] = 'session-jwt';
  return [
    authGatewayProvider.overrideWithValue(gateway),
    accountApiProvider.overrideWithValue(api),
    secureStoreProvider.overrideWithValue(s),
    pushMessagingProvider.overrideWithValue(push ?? LocalOnlyPushMessaging()),
    fileSharerProvider.overrideWithValue(FakeFileSharer()),
    exportFileWriterProvider.overrideWithValue(MemoryExportWriter()),
    dioProvider.overrideWithValue(
      Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = http ?? RecordingAdapter(),
    ),
  ];
}

/// Records every HTTP call made through dio and answers 200 `{}`.
class RecordingAdapter implements HttpClientAdapter {
  final List<({String method, String path, Object? body})> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      method: options.method,
      path: options.path,
      body: options.data,
    ));
    return ResponseBody.fromString(
      jsonEncode(<String, Object>{}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

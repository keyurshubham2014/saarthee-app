// Real-API helpers for integration_test/report_verify_test.dart (TASK-06 I-06-01).
// Sign-in goes through the Firebase Auth Emulator REST API (phone OTP read from
// the emulator), then POST /auth/firebase; nothing here prints tokens or codes.
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

const apiBase = String.fromEnvironment('API_BASE_URL');
const emulatorHost = String.fromEnvironment('AUTH_EMULATOR_HOST');
const firebaseProject = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'demo-saarthee',
);

/// Seeded "Sample Moderator Esha" (prisma/seed/modules/040-citizens.ts).
const moderatorPhone = String.fromEnvironment(
  'MODERATOR_PHONE',
  defaultValue: '+919000000025',
);

/// A point inside an Ahmedabad ward of the dev seed (also the fake GPS base).
const issueLat = 23.0225;
const issueLng = 72.5714;

final _rand = Random();

/// Fresh fictional test number `+91900007xxxx` (never a real subscriber range used by seeds).
String newTestPhone() => '+91900007${_rand.nextInt(9000) + 1000}';

/// Phone OTP on the Auth Emulator → ID token → Saarthee access token.
Future<String> signIn(String phone) async {
  final emu = Dio(BaseOptions(baseUrl: 'http://$emulatorHost'));
  const idt = '/identitytoolkit.googleapis.com/v1';
  final sent = await emu.post<Map<String, dynamic>>(
    '$idt/accounts:sendVerificationCode?key=demo-key',
    data: {'phoneNumber': phone, 'recaptchaToken': 'emulator'},
  );
  final session = sent.data!['sessionInfo'] as String;
  final codes = await emu.get<Map<String, dynamic>>(
    '/emulator/v1/projects/$firebaseProject/verificationCodes',
  );
  final code =
      (codes.data!['verificationCodes'] as List)
              .cast<Map<String, dynamic>>()
              .lastWhere((c) => c['sessionInfo'] == session)['code']
          as String;
  final signedIn = await emu.post<Map<String, dynamic>>(
    '$idt/accounts:signInWithPhoneNumber?key=demo-key',
    data: {'sessionInfo': session, 'code': code},
  );
  final res = await Dio(BaseOptions(baseUrl: apiBase))
      .post<Map<String, dynamic>>(
        '/auth/firebase',
        data: {
          'idToken': signedIn.data!['idToken'],
          'ageConfirmed': true,
          'consents': [
            {'purpose': 'core_service', 'textVersion': 'v2-1'},
          ],
          'language': 'en',
        },
      );
  return res.data!['accessToken'] as String;
}

/// Dio for one signed-in user.
Dio userDio(String token) => Dio(
  BaseOptions(baseUrl: apiBase, headers: {'Authorization': 'Bearer $token'}),
);

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(90, 110, 60));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// The reporter files a roads issue at (issueLat, issueLng) through the API
/// (TASK-05 endpoints). Returns the issue id.
Future<String> reportIssue(Dio reporter) async {
  final photo = await reporter.post<Map<String, dynamic>>(
    '/photos',
    data: FormData.fromMap({
      'purpose': 'report',
      'blurApplied': 'false',
      'photo': MultipartFile.fromBytes(
        _jpeg(),
        filename: 'report.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    }),
  );
  Map<String, dynamic> body([String? wardId]) => {
    'clientSubmissionId': _uuid(),
    'categorySlug': 'roads',
    'photoIds': [photo.data!['photoId']],
    'latitude': issueLat,
    'longitude': issueLng,
    'gpsAccuracyM': 8,
    'pinAdjusted': false,
    'deviceCapturedAt': DateTime.now().toUtc().toIso8601String(),
    'platform': 'android',
    'appVersion': '2.0.0',
    'confirmedWardId': ?wardId,
  };
  try {
    final res = await reporter.post<Map<String, dynamic>>(
      '/issues',
      data: body(),
    );
    return (res.data!['issue'] as Map)['id'] as String;
  } on DioException catch (e) {
    final details =
        ((e.response?.data as Map?)?['error'] as Map?)?['details'] as List?;
    final suggested =
        details?.cast<Map>().firstOrNull?['suggestedWardId'] as String?;
    if (suggested == null) rethrow;
    final res = await reporter.post<Map<String, dynamic>>(
      '/issues',
      data: body(suggested),
    );
    return (res.data!['issue'] as Map)['id'] as String;
  }
}

/// Staff status change through `POST /issues/{id}/status` (single writer).
Future<void> setStatus(Dio staff, String issueId, String to) async {
  final current = await lifecycleStatus(staff, issueId);
  await staff.post<void>(
    '/issues/$issueId/status',
    data: {
      'to': to,
      'expectedStatus': current,
      'clientActionId': _uuid(),
      'note': 'Integration test',
    },
  );
}

Future<String> lifecycleStatus(Dio dio, String issueId) async {
  final res = await dio.get<Map<String, dynamic>>('/issues/$issueId/lifecycle');
  return (res.data!['issue'] as Map)['status'] as String;
}

String _uuid() {
  String hex(int n) =>
      List.generate(n, (_) => _rand.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${'89ab'[_rand.nextInt(4)]}${hex(3)}-${hex(12)}';
}

import 'dart:async';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/map/civic_map.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/features/report/data/report_api.dart';
import 'package:saarthee/features/report/data/report_models.dart';

import '../auth/fakes.dart';
import '../helpers/fake_wards.dart';

const kSlugs = [
  'roads', 'water', 'drainage', 'garbage', 'streetlight', 'trees', 'animals', //
  'health', 'toilets', 'encroachment', 'traffic', 'property', 'building',
  'other',
];

List<ReportCategory> fakeCategories() => [
  for (final (i, s) in kSlugs.indexed)
    ReportCategory(
      id: 'cat-$i',
      slug: s,
      nameEn: s,
      nameGu: s,
      slaDays: 7,
      sensitive: s == 'encroachment' || s == 'building',
      amcProblemTypes: s == 'other'
          ? const []
          : [
              AmcProblemType(
                id: 'amc-$s',
                deptEn: 'Engineering',
                deptGu: 'ઇજનેર વિભાગ',
                problemEn: 'Road-Repair Require',
                problemGu: 'રસ્તાનું સમારકામ',
                isPrimary: true,
              ),
            ],
    ),
];

/// Scriptable report API.
class FakeReportApi implements ReportApi {
  List<ReportCategory> categoryList = fakeCategories();
  AppError? categoriesError;
  Completer<void>? categoriesGate;
  List<NearbyIssue> nearbyItems = const [];
  AppError? submitError;
  Completer<int>? meTooCompleter;
  final List<Map<String, Object?>> submits = [];
  final List<String> uploads = [];
  final List<String> meToos = [];
  String issueId = '3f9a2c1b-0000-4000-8000-000000000001';

  @override
  Future<List<ReportCategory>> categories() async {
    await categoriesGate?.future;
    final e = categoriesError;
    if (e != null) throw e;
    return categoryList;
  }

  @override
  Future<String> uploadPhoto(
    String filePath, {
    required bool blurApplied,
    void Function(double progress)? onProgress,
  }) async {
    uploads.add('$filePath blur=$blurApplied');
    return 'photo-${uploads.length}';
  }

  @override
  Future<List<NearbyIssue>> nearby(double lat, double lng, String slug) async =>
      nearbyItems;

  @override
  Future<Map<String, dynamic>> submit(Map<String, Object?> body) async {
    submits.add(body);
    final e = submitError;
    if (e != null) throw e;
    return {
      'issue': {
        'id': issueId,
        'status': 'reported',
        'visibility': body['structuredReason'] == null ? 'public' : 'hidden',
        'wardNameEn': 'Paldi',
        'wardNameGu': 'પાલડી',
      },
      'amcHandoff': {
        'problemTypes': [
          {
            'id': 'amc-roads',
            'deptEn': 'Engineering',
            'deptGu': 'ઇજનેર વિભાગ',
            'problemEn': 'Road-Repair Require',
            'problemGu': 'રસ્તાનું સમારકામ',
            'isPrimary': true,
          },
        ],
      },
    };
  }

  @override
  Future<int> meToo(String issueId) {
    meToos.add(issueId);
    return meTooCompleter?.future ?? Future.value(1);
  }

  @override
  Future<void> linkCcrs(String issueId, String number, String filedVia) async {}
}

/// A real 64×48 JPEG in the system temp folder.
String writeTestJpeg([String name = 'shot.jpg']) {
  final dir = Directory.systemTemp.createTempSync('report-test');
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  final f = File('${dir.path}/$name')..writeAsBytesSync(img.encodeJpg(image));
  return f.path;
}

/// Camera, GPS and permission without platform channels.
class FakeEvidenceCapture implements EvidenceCapture {
  FakeEvidenceCapture({
    this.access = LocationAccess.granted,
    this.fix = const Fix(latitude: 23.0225, longitude: 72.5714, accuracy: 8),
    this.autoPhoto = true,
  });

  LocationAccess access;
  Fix? fix;
  bool autoPhoto;
  int cameraOpens = 0;

  @override
  Future<LocationAccess> locationAccess({bool request = true}) async => access;

  @override
  Future<bool> openSettings(LocationAccess access) async => true;

  @override
  Future<CapturedPhoto?> takePhoto() async {
    cameraOpens++;
    if (!autoPhoto) return null;
    return CapturedPhoto(
      path: writeTestJpeg(),
      capturedAt: DateTime(2026, 10, 3, 14, 19),
    );
  }

  @override
  Future<CapturedPhoto?> recoverLostPhoto() async => null;

  @override
  Future<Fix?> currentFix() async => fix;
}

/// Overrides for report tests: fakes for the API, capture, wards, map tiles
/// and the photo folder, plus a signed-in session.
List reportOverrides({
  required FakeReportApi api,
  FakeEvidenceCapture? capture,
  FakeWardsRepository? wards,
  bool signedIn = true,
}) {
  final dir = Directory.systemTemp.createTempSync('report-photos');
  return [
    ...authOverrides(
      gateway: FakeAuthGateway(),
      api: FakeAccountApi(),
      signedIn: signedIn,
    ),
    reportApiProvider.overrideWithValue(api),
    evidenceCaptureProvider.overrideWithValue(capture ?? FakeEvidenceCapture()),
    wardsRepositoryProvider.overrideWithValue(wards ?? FakeWardsRepository()),
    mapTilesEnabledProvider.overrideWithValue(false),
    reportPhotoDirProvider.overrideWith((ref) async => dir),
  ];
}

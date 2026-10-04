// F-02-03 (TASK-02 AC-11): the app's WardsRepository against the local API
// on the emulator. Run by the integrator with the API on :4000:
//   flutter test integration_test/ward_locate_test.dart -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
// The three points are passed straight to `locate` (the GPS half is covered
// by M-02-04 with `adb emu geo fix`).
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saarthee/core/config/app_config.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paldi cross-roads (inside ward 30, same point as API T-02-03).
const paldi = (lat: 23.012, lng: 72.56);

/// 1 km due west of the city's westmost vertex (Thaltej, ward 8) —
/// outside every ward but within GEO_NEAREST_MAX_M (3 km).
const nearEdge = (lat: 23.052023, lng: 72.43748);

/// Gandhinagar — far outside the city.
const gandhinagar = (lat: 23.2156, lng: 72.6369);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiWardsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = ApiWardsRepository(
      dio: Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
      prefs: await SharedPreferences.getInstance(),
      languageCode: 'gu',
    );
  });

  testWidgets('inside Paldi → ward 30, inside, confirm false', (_) async {
    final r = await repo.locate(paldi.lat, paldi.lng);
    expect(r.ward.number, 30);
    expect(r.ward.nameEn, 'Paldi');
    expect(r.ward.zone.code, 'west');
    expect(r.match, WardMatch.inside);
    expect(r.confirm, isFalse);
    expect(r.distanceM, 0);
    expect(r.boundaryVersion, isNotEmpty);
  });

  testWidgets('1 km outside the edge → nearest ward 8, confirm', (_) async {
    final r = await repo.locate(nearEdge.lat, nearEdge.lng);
    expect(r.ward.number, 8);
    expect(r.match, WardMatch.nearest);
    expect(r.confirm, isTrue);
    expect(r.distanceM, inInclusiveRange(800, 1200));
  });

  testWidgets('Gandhinagar → OutsideServiceArea', (_) async {
    await expectLater(
      repo.locate(gandhinagar.lat, gandhinagar.lng),
      throwsA(isA<OutsideServiceArea>()),
    );
  });

  testWidgets('ward list → 48 wards in 7 zones with boundaryVersion', (
    _,
  ) async {
    final r = await repo.listWards();
    expect(r.fromCache, isFalse);
    expect(r.wards, hasLength(48));
    expect(r.wards.map((w) => w.zone.code).toSet(), hasLength(7));
    expect(r.boundaryVersion, isNotEmpty);
  });
}

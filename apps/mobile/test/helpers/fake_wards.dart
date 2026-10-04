import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/ward_providers.dart';
import 'package:saarthee/core/wards/wards_repository.dart';

const westZone = Zone(
  id: 'z-w',
  code: 'W',
  nameEn: 'West',
  nameGu: 'પશ્ચિમ',
);
const northZone = Zone(
  id: 'z-n',
  code: 'N',
  nameEn: 'North',
  nameGu: 'ઉત્તર',
);

const paldi = Ward(
  id: 'w12',
  number: 12,
  nameEn: 'Paldi',
  nameGu: 'પાલડી',
  zone: westZone,
);
const vasna = Ward(
  id: 'w13',
  number: 13,
  nameEn: 'Vasna',
  nameGu: 'વાસણા',
  zone: westZone,
);
const naroda = Ward(
  id: 'w2',
  number: 2,
  nameEn: 'Naroda',
  nameGu: 'નરોડા',
  zone: northZone,
);

const testWards = [naroda, paldi, vasna];

/// Scriptable wards repository.
class FakeWardsRepository implements WardsRepository {
  FakeWardsRepository({
    this.list = const WardsResult(testWards, fromCache: false),
    this.listError,
    this.locateResult = const WardLocateResult(ward: paldi, confirm: false),
    this.locateError,
  });

  WardsResult list;
  WardFailure? listError;
  WardLocateResult locateResult;
  WardFailure? locateError;
  int listCalls = 0;

  @override
  Future<WardsResult> listWards() async {
    listCalls++;
    if (listError != null) throw WardException(listError!);
    return list;
  }

  @override
  Future<WardLocateResult> locate(double lat, double lng) async {
    if (locateError != null) throw WardException(locateError!);
    return locateResult;
  }
}

/// Device position fake: Ahmedabad, or a scripted failure.
class FakeDeviceLocator implements DeviceLocator {
  FakeDeviceLocator({this.failure});

  LocatorFailure? failure;
  int settingsOpened = 0;

  @override
  Future<({double lat, double lng})> currentPosition() async {
    if (failure != null) throw LocatorException(failure!);
    return (lat: 23.0225, lng: 72.5714);
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

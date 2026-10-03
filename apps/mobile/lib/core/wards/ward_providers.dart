import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../config/timings.dart';
import '../settings/app_settings.dart';
import '../settings/preference_sync.dart';
import 'ward.dart';
import 'wards_repository.dart';

/// The citizen's home ward, persisted as `v2.homeWard` (absent when
/// skipped). Changes notify [PreferenceSync].
class HomeWardController extends Notifier<Ward?> {
  @override
  Ward? build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.homeWard);
    if (raw == null) return null;
    try {
      return Ward.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> set(Ward? ward) async {
    state = ward;
    final prefs = ref.read(sharedPreferencesProvider);
    if (ward == null) {
      await prefs.remove(PrefKeys.homeWard);
    } else {
      await prefs.setString(PrefKeys.homeWard, jsonEncode(ward.toPrefsJson()));
    }
    await ref.read(preferenceSyncProvider).homeWardChanged(ward);
  }
}

final homeWardProvider = NotifierProvider<HomeWardController, Ward?>(
  HomeWardController.new,
);

/// Ward list for the picker, falling back to the cache when offline.
final wardsListProvider = FutureProvider.autoDispose<WardsResult>(
  (ref) => ref.watch(wardsRepositoryProvider).listWards(),
);

/// Why the device could not give a position.
enum LocatorFailure { denied, deniedForever, serviceOff, unavailable }

class LocatorException implements Exception {
  const LocatorException(this.failure);

  final LocatorFailure failure;
}

/// Device position port (fake in tests). Location is used once for the
/// ward lookup and never stored.
abstract interface class DeviceLocator {
  Future<({double lat, double lng})> currentPosition();
  Future<bool> openAppSettings();
}

class GeolocatorDeviceLocator implements DeviceLocator {
  const GeolocatorDeviceLocator();

  @override
  Future<({double lat, double lng})> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocatorException(LocatorFailure.serviceOff);
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      throw const LocatorException(LocatorFailure.deniedForever);
    }
    if (p == LocationPermission.denied) {
      throw const LocatorException(LocatorFailure.denied);
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: AppTimings.locationTimeout,
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lng: last.longitude);
      throw const LocatorException(LocatorFailure.unavailable);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

final deviceLocatorProvider = Provider<DeviceLocator>(
  (ref) => const GeolocatorDeviceLocator(),
);

/// GPS → `/geo/locate`. Throws [LocatorException] or [WardException].
final locateWardProvider = Provider<Future<WardLocateResult> Function()>((
  ref,
) {
  return () async {
    final pos = await ref.read(deviceLocatorProvider).currentPosition();
    return ref.read(wardsRepositoryProvider).locate(pos.lat, pos.lng);
  };
});

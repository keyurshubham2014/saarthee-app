import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Weak-GPS threshold (02 D12, assumed 50 m).
const double kWeakGpsMeters = 50;

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

class CapturedPhoto {
  const CapturedPhoto({required this.path, required this.capturedAt});

  final String path;
  final DateTime capturedAt;
}

class Fix {
  const Fix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;

  bool get isWeak => accuracy > kWeakGpsMeters;
}

/// Camera-only capture and GPS fix shared by the report and verify flows
/// (02 §4.7, §4.14). Compression happens on the device through the picker:
/// long edge ≤ 1,600 px, JPEG quality 80 (02 §8.2).
class EvidenceCapture {
  EvidenceCapture({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<LocationAccess> locationAccess({bool request = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied && request) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  Future<bool> openSettings(LocationAccess access) =>
      access == LocationAccess.serviceDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();

  /// Opens the camera (never the gallery). Returns null when cancelled.
  Future<CapturedPhoto?> takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return CapturedPhoto(path: file.path, capturedAt: DateTime.now());
  }

  /// Current position with accuracy, or null when unavailable.
  Future<Fix?> currentFix() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return Fix(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      return Fix(
        latitude: last.latitude,
        longitude: last.longitude,
        accuracy: last.accuracy,
      );
    }
  }
}

final evidenceCaptureProvider = Provider<EvidenceCapture>(
  (ref) => EvidenceCapture(),
);

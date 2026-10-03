import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/wards/ward.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/wards/wards_repository.dart';

enum WardStepPhase {
  idle,
  locating,
  found,
  locationOff,
  outsideCity,
  unavailable,
}

class WardStepState {
  const WardStepState(this.phase, {this.result});

  final WardStepPhase phase;
  final WardLocateResult? result;

  static const idle = WardStepState(WardStepPhase.idle);
}

/// Onboarding ward step (TASK-03 §5.4): GPS lookup with every failure
/// mapped to a recoverable state; finishing (with or without a ward) sets
/// `v2.onboardingDone`.
class WardStepController extends Notifier<WardStepState> {
  @override
  WardStepState build() => WardStepState.idle;

  Future<void> useLocation() async {
    state = const WardStepState(WardStepPhase.locating);
    try {
      final result = await ref.read(locateWardProvider)();
      state = WardStepState(WardStepPhase.found, result: result);
    } on LocatorException catch (e) {
      state = WardStepState(
        e.failure == LocatorFailure.unavailable
            ? WardStepPhase.unavailable
            : WardStepPhase.locationOff,
      );
    } on WardException catch (e) {
      state = WardStepState(
        e.failure == WardFailure.outsideCity
            ? WardStepPhase.outsideCity
            : WardStepPhase.unavailable,
      );
    } catch (_) {
      state = const WardStepState(WardStepPhase.unavailable);
    }
  }

  void reset() => state = WardStepState.idle;

  Future<void> openSettings() =>
      ref.read(deviceLocatorProvider).openAppSettings();

  /// Saves [ward] (null = skipped) and completes onboarding.
  Future<void> finish(Ward? ward) async {
    if (ward != null) await ref.read(homeWardProvider.notifier).set(ward);
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
  }
}

final wardStepControllerProvider =
    NotifierProvider.autoDispose<WardStepController, WardStepState>(
      WardStepController.new,
    );

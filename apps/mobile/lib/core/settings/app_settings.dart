import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

class AppSettings {
  const AppSettings({
    required this.installId,
    required this.onboardingDone,
    this.inviteCode,
    this.groupLabel,
  });

  final String installId;
  final String? inviteCode;
  final String? groupLabel;
  final bool onboardingDone;
}

/// Install ID, invite code, group label, onboarding flag (02 §5.2).
class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kInstallId = 'installId';
  static const _kInviteCode = 'inviteCode';
  static const _kGroupLabel = 'groupLabel';
  static const _kOnboardingDone = 'onboardingDone';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    var installId = prefs.getString(_kInstallId);
    if (installId == null || installId.isEmpty) {
      installId = const Uuid().v4();
      prefs.setString(_kInstallId, installId);
    }
    return AppSettings(
      installId: installId,
      inviteCode: prefs.getString(_kInviteCode),
      groupLabel: prefs.getString(_kGroupLabel),
      onboardingDone: prefs.getBool(_kOnboardingDone) ?? false,
    );
  }

  Future<void> setInviteCode(String code, String groupLabel) async {
    await _prefs.setString(_kInviteCode, code);
    await _prefs.setString(_kGroupLabel, groupLabel);
    state = AppSettings(
      installId: state.installId,
      inviteCode: code,
      groupLabel: groupLabel,
      onboardingDone: state.onboardingDone,
    );
  }

  Future<void> clearInviteCode() async {
    await _prefs.remove(_kInviteCode);
    await _prefs.remove(_kGroupLabel);
    state = AppSettings(
      installId: state.installId,
      onboardingDone: state.onboardingDone,
    );
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_kOnboardingDone, true);
    state = AppSettings(
      installId: state.installId,
      inviteCode: state.inviteCode,
      groupLabel: state.groupLabel,
      onboardingDone: true,
    );
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

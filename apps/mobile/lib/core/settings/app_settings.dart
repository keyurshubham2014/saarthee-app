import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// Device storage keys (TASK-03 §5.2). v2 keys are prefixed `v2.`.
class PrefKeys {
  const PrefKeys._();

  static const installId = 'installId';
  static const languageCode = 'v2.languageCode';
  static const themeMode = 'v2.themeMode';
  static const animationsEnabled = 'v2.animationsEnabled';
  static const onboardingDone = 'v2.onboardingDone';
  static const homeWard = 'v2.homeWard';
  static const wardsCache = 'v2.wardsCache';

  /// v1 keys removed on the first v2 launch (D11 retirement).
  static const retiredV1 = <String>[
    'inviteCode',
    'groupLabel',
    'onboardingDone',
    'reportDraft',
    'myReports',
    'lastCategories',
  ];
}

class AppSettings {
  const AppSettings({required this.installId, required this.onboardingDone});

  final String installId;
  final bool onboardingDone;
}

/// Install ID and the v2 onboarding flag. `build` also migrates v1 storage:
/// the invite code, group label, v1 onboarding flag and v1 report draft are
/// deleted so the app opens v2 onboarding (AC-15).
class AppSettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    for (final key in PrefKeys.retiredV1) {
      if (prefs.containsKey(key)) prefs.remove(key);
    }
    var installId = prefs.getString(PrefKeys.installId);
    if (installId == null || installId.isEmpty) {
      installId = const Uuid().v4();
      prefs.setString(PrefKeys.installId, installId);
    }
    return AppSettings(
      installId: installId,
      onboardingDone: prefs.getBool(PrefKeys.onboardingDone) ?? false,
    );
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(PrefKeys.onboardingDone, true);
    state = AppSettings(installId: state.installId, onboardingDone: true);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

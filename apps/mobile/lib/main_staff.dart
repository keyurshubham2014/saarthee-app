import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/api_url_policy.dart';
import 'core/config/app_config.dart';
import 'core/config/config_error_app.dart';
import 'core/settings/app_settings.dart';
import 'features/auth/data/secure_store.dart';
import 'features/staff/shell/session_storage_store.dart';
import 'features/staff/shell/staff_app.dart';

/// Staff console web entry (TASK-10, REQ-F-048):
/// `flutter build web -t lib/main_staff.dart --release --dart-define=API_BASE_URL=…`.
/// Imports only the staff feature, the sign-in flow and core — no camera
/// or capture pipeline (checked by test/staff/import_boundary_test.dart).
/// Sessions live in memory + `sessionStorage`, never `localStorage`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.assertValid();
  if (!apiBaseUrlIsAllowed(AppConfig.apiBaseUrl, currentBuildMode)) {
    runApp(const ConfigErrorApp());
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(SessionStorageStore()),
      ],
      retry: (_, _) => null,
      child: const StaffWebApp(),
    ),
  );
}

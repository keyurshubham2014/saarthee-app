import 'package:flutter/foundation.dart';

/// Build-time configuration passed with `--dart-define` (05 §2.2).
class AppConfig {
  const AppConfig._();

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'saarthee',
  );
  static const String ccrsWebUrl = String.fromEnvironment(
    'CCRS_WEB_URL',
    defaultValue: 'https://www.amccrs.com/',
  );
  static const String ccrsWhatsappNumber = String.fromEnvironment(
    'CCRS_WHATSAPP_NUMBER',
    defaultValue: '+917567855303',
  );
  static const String amcHelpline = String.fromEnvironment(
    'AMC_HELPLINE',
    defaultValue: '155303',
  );
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Grievance contact shown on About (empty until published).
  static const String grievanceEmail = String.fromEnvironment(
    'GRIEVANCE_EMAIL',
  );

  /// Fails fast in debug builds when the API base URL was not provided.
  static void assertValid() {
    if (kDebugMode && apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is empty. Run with --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1',
      );
    }
  }
}

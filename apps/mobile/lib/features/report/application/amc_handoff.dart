import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/data/account_api.dart';
import '../../auth/data/account_models.dart';

/// Opens an external URI; false when no app could handle it.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  },
);

const String kAmcHandoffConsentKey = 'v2.amcHandoffConsent';

enum HandoffTarget { web, whatsapp, phone }

/// "File with AMC too" (TASK-05 §5.4, REQ-F-018): CCRS web, WhatsApp, the
/// 155303 helpline. The first hand-off tap records consent
/// `share_with_amc_handoff` (once per install).
class AmcHandoff {
  AmcHandoff(this._ref);

  final Ref _ref;

  static Uri uriFor(HandoffTarget t) => switch (t) {
    HandoffTarget.web => Uri.parse(AppConfig.ccrsWebUrl),
    HandoffTarget.whatsapp => Uri.parse(
      'https://wa.me/${AppConfig.ccrsWhatsappNumber.replaceAll(RegExp(r'[^0-9]'), '')}',
    ),
    HandoffTarget.phone => Uri(scheme: 'tel', path: AppConfig.amcHelpline),
  };

  Future<bool> open(HandoffTarget target) async {
    await recordConsentOnce();
    return _ref.read(urlOpenerProvider)(uriFor(target));
  }

  Future<void> recordConsentOnce() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs.getBool(kAmcHandoffConsentKey) == true) return;
    try {
      await _ref
          .read(accountApiProvider)
          .setConsent(ConsentPurpose.shareWithAmcHandoff, true);
      await prefs.setBool(kAmcHandoffConsentKey, true);
    } on Object {
      // Retried on the next hand-off tap; never blocks the citizen.
    }
  }
}

final amcHandoffProvider = Provider<AmcHandoff>(AmcHandoff.new);

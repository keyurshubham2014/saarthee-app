import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';

/// Event property values for `ccrs_handoff_clicked {target}` (03 §11).
enum HandoffTarget { web, whatsapp, call }

/// Opens AMC's own channels (02 §4.5). URLs and numbers come from
/// dart-defines only.
class HandoffLauncher {
  const HandoffLauncher();

  Uri uriFor(HandoffTarget t) => switch (t) {
    HandoffTarget.web => Uri.parse(AppConfig.ccrsWebUrl),
    HandoffTarget.whatsapp => Uri.parse(
      'https://wa.me/${AppConfig.ccrsWhatsappNumber.replaceAll(RegExp(r'\D'), '')}',
    ),
    HandoffTarget.call => Uri(scheme: 'tel', path: AppConfig.amcHelpline),
  };

  Future<bool> open(HandoffTarget t) async {
    try {
      return await launchUrl(uriFor(t), mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

final handoffLauncherProvider = Provider<HandoffLauncher>(
  (ref) => const HandoffLauncher(),
);

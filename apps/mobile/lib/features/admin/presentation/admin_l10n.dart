import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_localizations.dart';

export '../../../core/l10n/app_localizations.dart' show AppLocalizations;

/// Localized strings for admin screens, independent of the generator's
/// `nullable-getter` setting.
AppLocalizations adminL10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations)!;

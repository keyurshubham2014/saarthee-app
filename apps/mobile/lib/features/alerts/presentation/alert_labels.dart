import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/alerts/validity_format.dart';
import '../../../core/widgets/chips.dart';
import '../data/alert_models.dart';

/// "Ward 12 Paldi" / "Wards 12, 15" / "West zone" / "All of Ahmedabad".
String alertAreaLabel(AppLocalizations l10n, String lang, Alert a) {
  switch (a.scope) {
    case 'city':
      return l10n.alertsAreaCity;
    case 'zone':
      final name = lang == 'gu' ? a.zoneNameGu : a.zoneNameEn;
      return l10n.alertsAreaZone(name ?? a.zoneCode?.toUpperCase() ?? '');
    default:
      if (a.wards.length == 1) {
        final w = a.wards.single;
        return l10n.alertsAreaWard(
          w.number,
          lang == 'gu' ? w.nameGu : w.nameEn,
        );
      }
      if (a.wardNumbers.length == 1 && a.wards.isEmpty) {
        return l10n.alertsAreaWards('${a.wardNumbers.single}');
      }
      return l10n.alertsAreaWards(a.wardNumbers.join(', '));
  }
}

String alertTypeLabel(AppLocalizations l10n, AlertType t) => switch (t) {
  AlertType.waterCut => l10n.alertTypeWaterCut,
  AlertType.waterTiming => l10n.alertTypeWaterTiming,
  AlertType.roadClosure => l10n.alertTypeRoadClosure,
  AlertType.heat => l10n.alertTypeHeat,
  AlertType.rainFlood => l10n.alertTypeRainFlood,
  AlertType.health => l10n.alertTypeHealth,
  AlertType.initiative => l10n.alertTypeInitiative,
  AlertType.other => l10n.alertTypeOther,
};

String alertValidityLabel(AppLocalizations l10n, String lang, Alert a) =>
    formatAlertValidity(l10n, lang, a.validFrom, a.validTo);

/// TalkBack: "Critical alert: <title>, until <time>".
String alertSemanticsLabel(AppLocalizations l10n, String lang, Alert a) =>
    l10n.alertsCardSemantics(
      alertSeverityLabel(l10n, a.severity),
      a.title(lang),
      formatAlertEnd(lang, a.validTo),
    );

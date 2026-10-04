import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Makes `intl` format in the app language. Without it every `DateFormat` or
/// `NumberFormat` built without a locale (e.g. `Formatters.date(d)`) used
/// en_US, so Gujarati screens showed English month names. Call from the
/// `MaterialApp.builder`, which sits under `Localizations`.
void syncIntlLocale(BuildContext context) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  if (Intl.defaultLocale != tag) Intl.defaultLocale = tag;
}

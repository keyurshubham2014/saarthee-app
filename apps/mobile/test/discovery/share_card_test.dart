// W-07-05 share card (en + gu): category, title, ward, status, affected
// count and independence line; never reporter information.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/features/discovery/data/discovery_models.dart';
import 'package:saarthee/features/discovery/presentation/share_issue.dart';

import 'fakes.dart';
import 'harness.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('gu')]) {
    testWidgets('W-07-05 share card (${locale.languageCode})', (t) async {
      final d = IssueDetail.fromJson(detailJson('s1', meToo: 7));
      await pumpDiscovery(
        t,
        home: Scaffold(body: IssueShareCard(detail: d)),
        api: FakeDiscoveryApi(),
        locale: locale,
      );
      await t.pump();
      expect(find.text('Pothole · Paldi'), findsOneWidget);
      expect(
        find.text(locale.languageCode == 'gu' ? 'પાલડી' : 'Paldi'),
        findsOneWidget,
      );
      expect(
        find.textContaining(locale.languageCode == 'gu' ? 'AMC' : 'Not run by'),
        findsOneWidget,
      );
      expect(find.textContaining('7'), findsWidgets);
      expect(find.textContaining('resident of'), findsNothing);
      expect(find.textContaining('રહેવાસીએ'), findsNothing);
    });
  }

  test(
    'Gujarati share links open the Gujarati page; English links stay plain',
    () {
      final d = IssueDetail.fromJson(detailJson('i-9'));
      final gu = issueShareText(lookupAppLocalizations(const Locale('gu')), d);
      final en = issueShareText(lookupAppLocalizations(const Locale('en')), d);
      expect(gu, contains('/i/i-9?lang=gu'));
      expect(en, contains('/i/i-9'));
      expect(en, isNot(contains('lang=')));
    },
  );
}

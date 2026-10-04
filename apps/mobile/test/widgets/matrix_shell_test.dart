// V2-TASK-14 AC-1: app bar (language switch, bell badge), bottom
// navigation (5 tabs, labels, selected state), Home header + `sunrise`
// Report card across the matrix.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/locale_controller.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';
import 'package:saarthee/features/inbox/application/inbox_controller.dart';
import 'package:saarthee/features/inbox/presentation/inbox_bell.dart';

import '../helpers/component_matrix.dart';

void main() {
  componentMatrix(
    'SaartheeAppBar title, subtitle, language switch, bell badge',
    (l10n) => Column(
      children: [
        SaartheeAppBar(
          title: l10n.navAlerts,
          subtitle: 'Navrangpura',
          onBack: () {},
          bell: const InboxBell(),
        ),
      ],
    ),
    scroll: false,
    overrides: [inboxUnreadCountProvider.overrideWithValue(3)],
    check: (t, l10n) async {
      expect(find.text(l10n.navAlerts), findsOneWidget);
      expect(find.byTooltip(l10n.commonBack), findsOneWidget);
      expectSemantics(l10n.inboxBellLabel(3));
      expect(find.text('3'), findsOneWidget, reason: 'badge count');
      final toggle = find.byKey(const Key('languageToggle'));
      expect(find.byTooltip(l10n.languageSwitchToGujarati), findsOneWidget);
      final container = ProviderScope.containerOf(t.element(toggle));
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(container.read(localeProvider).languageCode, 'gu');
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(container.read(localeProvider).languageCode, 'en');
    },
  );

  componentMatrix(
    'SaartheeNavigationBar 5 labelled tabs, selected state',
    (l10n) => Align(
      alignment: Alignment.bottomCenter,
      child: SaartheeNavigationBar(selectedIndex: 3, onSelected: (_) {}),
    ),
    scroll: false,
    check: (t, l10n) async {
      final labels = [
        l10n.navHome,
        l10n.navMap,
        l10n.navReport,
        l10n.navAlerts,
        l10n.navMyWard,
      ];
      for (var i = 0; i < labels.length; i++) {
        expect(find.byKey(Key('nav.$i')), findsOneWidget);
        expectSemanticsContaining(labels[i]);
      }
      final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 3);
      expect(bar.destinations, hasLength(5));
      final node = t.getSemantics(find.byKey(const Key('nav.3')));
      expect(node, containsSemantics(isSelected: true));
    },
  );

  componentMatrix(
    'HomeHeader with sunrise Report card',
    (l10n) => HomeHeader(
      wardLabel: 'Navrangpura',
      onWardTap: () {},
      onReport: () {},
      onBell: () {},
    ),
    check: (t, l10n) async {
      expect(find.byKey(const Key('homeHeader.band')), findsOneWidget);
      expect(find.text(l10n.homeReportCardTitle), findsOneWidget);
      expect(find.text(l10n.homeReportCardHint), findsOneWidget);
      expectSemantics(
        '${l10n.homeReportCardTitle}. ${l10n.homeReportCardHint}',
      );
      expectSemantics('Navrangpura');
      expect(find.byTooltip(l10n.commonNotifications), findsOneWidget);
      final card = t.widget<Material>(find.byKey(const Key('reportCard')));
      final ctx = t.element(find.byKey(const Key('reportCard')));
      expect(card.color, SaartheeColors.of(ctx).sunrise);
      final size = t.getSize(find.byKey(const Key('reportCard')));
      expect(size.height, greaterThanOrEqualTo(56));
    },
  );
}

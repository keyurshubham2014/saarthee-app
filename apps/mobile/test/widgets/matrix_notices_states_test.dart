// V2-TASK-14 AC-1: banners (offline, election, independence), empty /
// loading / error / offline states, toast and step header.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/component_matrix.dart';
import '../helpers/motion.dart';

void main() {
  componentMatrix(
    'NoticeBanner offline / election / independence',
    (l10n) => Column(
      children: [
        NoticeBanner(kind: NoticeKind.offline, onRetry: () {}),
        const NoticeBanner(kind: NoticeKind.electionMode),
        const NoticeBanner(kind: NoticeKind.independence),
        const IndependenceNotice(),
      ],
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.commonOfflineBanner), findsOneWidget);
      expect(find.text(l10n.componentElectionBanner), findsOneWidget);
      expect(find.text(l10n.commonIndependenceNotice), findsWidgets);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expectSemanticsContaining(l10n.commonOfflineBanner);
      expectSemanticsContaining(l10n.componentElectionBanner);
    },
  );

  componentMatrix(
    'EmptyState / ErrorState / OfflineState',
    (l10n) => Column(
      children: [
        EmptyState(
          message: l10n.commonNotifications,
          actionLabel: l10n.commonGoHome,
          onAction: () {},
        ),
        ErrorState(
          message: l10n.wardPickerError,
          onRetry: () {},
          secondaryLabel: l10n.commonBack,
          onSecondary: () {},
        ),
        OfflineState(onRetry: () {}),
      ],
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.commonNotifications), findsOneWidget);
      expect(find.text(l10n.wardPickerError), findsOneWidget);
      expect(find.text(l10n.componentOfflineState), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsNWidgets(2));
      expectSemanticsContaining(l10n.wardPickerError);
      expectSemanticsContaining(l10n.commonRetry);
    },
  );

  componentMatrix(
    'SkeletonList loading state is one "Loading" node',
    (l10n) => const SkeletonList(count: 3),
    settle: false,
    check: (t, l10n) async => expectSemantics(l10n.commonLoading),
  );

  componentMatrix(
    'SaartheeToast success / info / error on primaryDark',
    (l10n) => Column(
      children: [
        SaartheeToast(message: l10n.componentMessage, checkProgress: 1),
        SaartheeToast(message: l10n.commonLoading, kind: ToastKind.info),
        SaartheeToast(message: l10n.wardPickerError, kind: ToastKind.error),
      ],
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.componentMessage), findsOneWidget);
      expectSemantics(l10n.componentDone);
      final m = t.widget<Material>(find.byKey(const Key('toast')).first);
      final ctx = t.element(find.byKey(const Key('toast')).first);
      expect(m.color, SaartheeColors.of(ctx).primaryDark);
    },
  );

  componentMatrix(
    'StepHeader "Step n of 3" with next hint',
    (l10n) => StepHeader(
      step: 2,
      total: 3,
      nextHint: l10n.reportFlowHintDetails,
      onBack: () {},
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.commonStepOf(2, 3)), findsOneWidget);
      expectSemantics(l10n.commonStepOf(2, 3));
      expect(find.byTooltip(l10n.commonBack), findsOneWidget);
    },
  );

  for (final locale in matrixLocales) {
    testWidgets('showSaartheeToast is announced · ${locale.languageCode}', (
      t,
    ) async {
      final announced = captureMatrixAnnouncements(t);
      final l10n = lookupAppLocalizations(locale);
      await pumpMotion(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSaartheeToast(context, l10n.componentDone),
            child: Text(l10n.commonContinue),
          ),
        ),
        locale: locale,
      );
      await t.tap(find.text(l10n.commonContinue));
      await t.pump();
      expect(announced, contains(l10n.componentDone));
      expect(find.byType(SaartheeToast), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(find.byType(SaartheeToast), findsNothing);
    });
  }
}

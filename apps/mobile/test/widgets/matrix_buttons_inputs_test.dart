// V2-TASK-14 AC-1: buttons (progress, disabled), inputs (label, optional
// suffix, error text) and the error summary (focus) across the matrix.
import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/component_matrix.dart';

void main() {
  componentMatrix(
    'Primary / submit / secondary / tertiary buttons',
    (l10n) => Column(
      children: [
        PrimaryButton(label: l10n.commonContinue, onPressed: () {}),
        PrimaryButton(label: l10n.commonGoHome, onPressed: null),
        SubmitReportButton(label: l10n.reportFlowSubmit, onPressed: () {}),
        SecondaryButton(label: l10n.reportPhotoRetake, onPressed: () {}),
        TertiaryButton(label: l10n.commonBack, onPressed: () {}),
      ],
    ),
    check: (t, l10n) async {
      for (final word in [
        l10n.commonContinue,
        l10n.commonGoHome,
        l10n.reportFlowSubmit,
        l10n.reportPhotoRetake,
        l10n.commonBack,
      ]) {
        expect(find.text(word), findsOneWidget);
        expectSemanticsContaining(word);
      }
      final disabled = t.widget<FilledButton>(
        find.ancestor(
          of: find.text(l10n.commonGoHome),
          matching: find.byType(FilledButton),
        ),
      );
      expect(disabled.onPressed, isNull, reason: 'disabled button');
      for (final e in find.byType(FilledButton).evaluate()) {
        expect(e.size!.height, greaterThanOrEqualTo(48), reason: '48 dp');
      }
    },
  );

  componentMatrix(
    'PrimaryButton loading shows progress and "Working"',
    (l10n) => PrimaryButton(
      label: l10n.commonContinue,
      onPressed: () {},
      isLoading: true,
    ),
    settle: false,
    check: (t, l10n) async {
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.commonContinue), findsNothing);
      expectSemantics(l10n.commonWorking);
    },
  );

  componentMatrix(
    'LabeledTextField label, optional suffix, error text',
    (l10n) => Column(
      children: [
        LabeledTextField(
          label: l10n.reportFlowDescriptionLabel,
          hint: l10n.reportFlowDescriptionHint,
          optional: true,
        ),
        LabeledTextField(
          label: l10n.reportFlowDescriptionLabel,
          error: l10n.authErrorConsentRequired,
        ),
      ],
    ),
    check: (t, l10n) async {
      final optional =
          '${l10n.reportFlowDescriptionLabel} ${l10n.commonOptional}';
      expect(find.textContaining(l10n.commonOptional), findsWidgets);
      expectSemanticsContaining(optional);
      expect(find.text(l10n.authErrorConsentRequired), findsOneWidget);
      expectSemanticsContaining(l10n.authErrorConsentRequired);
    },
  );

  componentMatrix(
    'ErrorSummary takes focus and lists linked items',
    (l10n) => ErrorSummary(
      items: [
        ErrorSummaryItem(l10n.authErrorAgeRequired, onTap: () {}),
        ErrorSummaryItem(l10n.authErrorConsentRequired),
      ],
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.commonErrorSummaryTitle), findsOneWidget);
      expect(find.text(l10n.authErrorAgeRequired), findsOneWidget);
      expect(find.text(l10n.authErrorConsentRequired), findsOneWidget);
      final focus = t.widget<Focus>(
        find
            .ancestor(
              of: find.text(l10n.commonErrorSummaryTitle),
              matching: find.byType(Focus),
            )
            .last,
      );
      expect(focus.focusNode!.hasFocus, isTrue, reason: 'summary focused');
      expectSemanticsContaining(l10n.authErrorAgeRequired);
    },
  );
}

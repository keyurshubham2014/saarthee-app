// T-03-09 states, banners, toast; T-03-25 skeleton shimmer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';

void main() {
  testWidgets('EmptyState: 56 dp icon circle + one action', (t) async {
    var taps = 0;
    await pumpMotion(
      t,
      EmptyState(message: 'Nothing here', actionLabel: 'Add', onAction: () => taps++),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    await t.tap(find.text('Add'));
    expect(taps, 1);
    expect(AppSpacing.emptyIcon, 56);
  });

  testWidgets('ErrorState: Try again fires', (t) async {
    var retries = 0;
    await pumpMotion(t, ErrorState(message: 'Failed', onRetry: () => retries++));
    await t.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('NoticeBanner variants render their copy', (t) async {
    await pumpMotion(
      t,
      const Column(
        children: [
          NoticeBanner(kind: NoticeKind.offline),
          NoticeBanner(kind: NoticeKind.independence),
          NoticeBanner(kind: NoticeKind.electionMode),
          NoticeBanner(kind: NoticeKind.info, message: 'Hello'),
        ],
      ),
    );
    expect(
      find.text("You're offline. Your report is saved and will send automatically."),
      findsOneWidget,
    );
    expect(
      find.text('Independent citizen app. Not run by or linked to AMC.'),
      findsOneWidget,
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('toast: primaryDark, radius 18, 4 s hold, success haptic', (t) async {
    final fake = FakeSaartheeHaptics();
    await pumpMotion(
      t,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSaartheeToast(context, 'Saved'),
          child: const Text('go'),
        ),
      ),
      haptics: fake,
    );
    await t.tap(find.text('go'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Saved'), findsOneWidget);
    expect(fake.calls, contains('success'));
    final material = t.widget<Material>(
      find.ancestor(of: find.text('Saved'), matching: find.byType(Material)).first,
    );
    final ctx = t.element(find.text('Saved'));
    expect(material.color, SaartheeColors.of(ctx).primaryDark);
    expect(material.borderRadius, AppRadii.cardRadius);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Saved'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  group('T-03-25 skeleton', () {
    testWidgets('shimmers at 1.2 s, stops and cross-fades on data', (t) async {
      final loading = ValueNotifier(true);
      await pumpMotion(
        t,
        ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (_, l, _) =>
              SkeletonSwitcher(loading: l, child: const Text('Loaded')),
        ),
      );
      final state = t.state<SkeletonListState>(find.byType(SkeletonList));
      expect(state.isShimmering, isTrue);
      loading.value = false;
      await t.pump();
      await t.pump(const Duration(milliseconds: 280));
      expect(state.isShimmering, isFalse);
      // Settles (no loop left running) once the cross-fade is done.
      await t.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Loaded'), findsOneWidget);
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('static under reduced motion', (t) async {
      await pumpMotion(t, const SkeletonList(), reduced: true);
      await t.pump();
      final state = t.state<SkeletonListState>(find.byType(SkeletonList));
      expect(state.isShimmering, isFalse);
    });
  });
}

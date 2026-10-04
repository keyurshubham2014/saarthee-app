import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/capture/evidence_capture.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/motion_widgets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/photo_pipeline.dart';
import '../application/report_draft_controller.dart';
import 'step_details.dart';
import 'step_photo.dart';
import 'step_what.dart';

/// The Report tab (TASK-05 §5.4, DS §8): one persistent `StepHeader` whose
/// progress bar animates 1/3 → 2/3 → 3/3, over a shared-axis X body
/// (`medium`; reversed on Back). Reduced motion → 100 ms cross-fade.
class ReportFlowScreen extends ConsumerStatefulWidget {
  const ReportFlowScreen({super.key, this.stepParam});

  /// `?step=what|photo|details` from a deep link or a retired v1 route.
  final String? stepParam;

  @override
  ConsumerState<ReportFlowScreen> createState() => _ReportFlowScreenState();
}

class _ReportFlowScreenState extends ConsumerState<ReportFlowScreen> {
  ReportStep _shown = ReportStep.what;
  bool _reverse = false;
  bool _tilesShown = false;

  @override
  void initState() {
    super.initState();
    _applyParam();
    _shown = ref.read(reportDraftProvider)?.step ?? ReportStep.what;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  void _applyParam() {
    final want = ReportStep.values.where((s) => s.name == widget.stepParam);
    final draft = ref.read(reportDraftProvider);
    if (want.isEmpty || draft?.categorySlug == null) return;
    if (want.first == ReportStep.details && (draft?.photos.isEmpty ?? true)) {
      return;
    }
    Future.microtask(
      () => ref.read(reportDraftProvider.notifier).goTo(want.first),
    );
  }

  /// image_picker lost-data recovery (Android) and pending uploads.
  Future<void> _recover() async {
    final pipeline = ref.read(reportPhotoPipelineProvider);
    try {
      final lost = await ref.read(evidenceCaptureProvider).recoverLostPhoto();
      if (lost != null && ref.read(reportDraftProvider)?.categorySlug != null) {
        await pipeline.addCaptured(lost);
      }
    } on LostPhotoException {
      if (mounted) {
        showSaartheeToast(
          context,
          AppLocalizations.of(context).reportFlowRecoverFailed,
          kind: ToastKind.error,
        );
      }
    } on Object {
      // No lost data API on this platform (tests, iOS).
    }
    await pipeline.resumePending();
  }

  void _back() {
    final step = ref.read(reportDraftProvider)?.step ?? ReportStep.what;
    if (step == ReportStep.what) return;
    ref
        .read(reportDraftProvider.notifier)
        .goTo(ReportStep.values[step.index - 1]);
  }

  Widget _body(ReportStep step) => switch (step) {
    ReportStep.what => StepWhat(popIn: !_tilesShown),
    ReportStep.photo => const StepPhoto(),
    ReportStep.details => const StepDetails(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step =
        ref.watch(reportDraftProvider.select((d) => d?.step)) ??
        ReportStep.what;
    if (step != _shown) {
      _reverse = step.index < _shown.index;
      _shown = step;
    }
    final body = _body(step);
    if (step == ReportStep.what) _tilesShown = true;
    final scheme = SaartheeMotion.of(context);
    final c = SaartheeColors.of(context);
    return PopScope(
      canPop: step == ReportStep.what,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s8,
                  AppSpacing.s8,
                  AppSpacing.gutter,
                  AppSpacing.s8,
                ),
                child: StepHeader(
                  key: const Key('report.stepHeader'),
                  step: step.index + 1,
                  total: 3,
                  nextHint: switch (step) {
                    ReportStep.what => l10n.reportFlowHintPhoto,
                    ReportStep.photo => l10n.reportFlowHintDetails,
                    ReportStep.details => null,
                  },
                  onBack: step == ReportStep.what ? null : _back,
                ),
              ),
              Expanded(
                child: PageTransitionSwitcher(
                  duration: scheme.medium.duration,
                  reverse: _reverse,
                  transitionBuilder: (child, animation, secondary) =>
                      SaartheeTransitions.page(
                        scheme: scheme,
                        animation: animation,
                        secondaryAnimation: secondary,
                        fillColor: c.background,
                        child: child,
                      ),
                  child: KeyedSubtree(
                    key: ValueKey('report.step.${step.name}'),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

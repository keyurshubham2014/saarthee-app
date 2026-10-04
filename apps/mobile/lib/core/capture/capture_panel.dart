import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';
import 'capture_controller.dart';
import 'evidence_capture.dart';

/// Capture UI shared by report step 4 and verify photo: permission
/// explanation, "Take photo" (camera only), preview with Retake / "Use this
/// photo", weak-GPS and no-location states.
class CapturePanel extends ConsumerStatefulWidget {
  const CapturePanel({
    super.key,
    required this.onUse,
    this.takeLabel,
    this.keyPrefix = 'capture',
  });

  /// Called with the accepted photo and its fix.
  final Future<void> Function(CapturedPhoto photo, Fix fix) onUse;
  final String? takeLabel;
  final String keyPrefix;

  @override
  ConsumerState<CapturePanel> createState() => _CapturePanelState();
}

class _CapturePanelState extends ConsumerState<CapturePanel>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from settings: re-check permission.
    if (state == AppLifecycleState.resumed &&
        ref.read(captureControllerProvider).blockedByPermission) {
      ref.read(captureControllerProvider.notifier).refreshAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(captureControllerProvider);
    final c = ref.read(captureControllerProvider.notifier);

    if (s.photo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.reportPhotoPreviewLabel,
            child: EvidencePhoto(
              image: FileImage(File(s.photo!.path)),
              capturedAt: s.photo!.capturedAt,
              accuracyMeters: s.fix?.accuracy,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (s.busy) const LinearProgressIndicator(),
          if (s.locationFailed) ...[
            InlineFieldError(message: l10n.reportPhotoLocationUnavailable),
            const SizedBox(height: AppSpacing.s8),
            SecondaryButton(
              label: l10n.reportPhotoWeakGpsRetry,
              icon: SaartheeIcons.myLocation,
              onPressed: c.retryLocation,
            ),
          ],
          if (s.fix != null && s.fix!.isWeak && !s.weakAccepted) ...[
            _Warning(text: l10n.reportPhotoWeakGps),
            const SizedBox(height: AppSpacing.s8),
            SecondaryButton(
              key: Key('${widget.keyPrefix}.weakRetry'),
              label: l10n.reportPhotoWeakGpsRetry,
              icon: SaartheeIcons.myLocation,
              onPressed: c.retryLocation,
            ),
            const SizedBox(height: AppSpacing.s8),
            SecondaryButton(
              key: Key('${widget.keyPrefix}.weakContinue'),
              label: l10n.reportPhotoWeakGpsContinue,
              onPressed: c.acceptWeak,
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: Key('${widget.keyPrefix}.retake'),
                  label: l10n.reportPhotoRetake,
                  icon: SaartheeIcons.camera,
                  onPressed: s.busy ? null : c.takePhoto,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: FilledButton(
                  key: Key('${widget.keyPrefix}.use'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
                  ),
                  onPressed: s.canUse && !s.busy
                      ? () async {
                          await widget.onUse(s.photo!, s.fix!);
                          // onUse usually swaps this panel out, which disposes
                          // the autoDispose controller; only reset if still here.
                          if (mounted) c.reset();
                        }
                      : null,
                  child: Text(l10n.reportPhotoUse, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.blockedByPermission) ...[
          _Warning(
            text: s.access == LocationAccess.serviceDisabled
                ? l10n.reportPhotoLocationOff
                : l10n.reportPhotoLocationDenied,
          ),
          const SizedBox(height: AppSpacing.s8),
          SecondaryButton(
            key: Key('${widget.keyPrefix}.openSettings'),
            label: l10n.commonOpenSettings,
            icon: SaartheeIcons.settings,
            onPressed: c.openSettings,
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        SecondaryButton(
          key: Key('${widget.keyPrefix}.take'),
          label: widget.takeLabel ?? l10n.reportPhotoTake,
          icon: SaartheeIcons.camera,
          isLoading: s.busy,
          onPressed: c.takePhoto,
        ),
        if (s.busy) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.commonLoading, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: SaartheeColors.of(context).warningTint,
          borderRadius: AppRadii.cardRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              SaartheeIcons.warning,
              color: SaartheeColors.of(context).warning,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

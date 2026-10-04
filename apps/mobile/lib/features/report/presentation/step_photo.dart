import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/capture/evidence_capture.dart';
import '../../../core/config/timings.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward.dart';
import '../../../core/widgets/widgets.dart';
import '../application/photo_pipeline.dart';
import '../application/report_draft_controller.dart';
import '../application/report_providers.dart';
import 'duplicate_panel.dart';
import 'motion/photo_fly_in.dart';
import 'photo_strip.dart';
import 'place_panel.dart';

/// Step 2 "Add a photo and check the place" (TASK-05 §5.4).
class StepPhoto extends ConsumerStatefulWidget {
  const StepPhoto({super.key});

  @override
  ConsumerState<StepPhoto> createState() => _StepPhotoState();
}

class _StepPhotoState extends ConsumerState<StepPhoto> {
  final _takeKey = GlobalKey(debugLabel: 'report.take');
  final _slotKeys = List.generate(3, (i) => GlobalKey(debugLabel: 'slot$i'));
  LocationAccess? _access;
  bool _capturing = false;
  PinKey? _settled;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final draft = ref.read(reportDraftProvider);
    final cap = ref.read(evidenceCaptureProvider);
    final access = await cap.locationAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == LocationAccess.granted && draft?.fix == null) {
      final fix = await cap.currentFix();
      if (fix != null && mounted) {
        ref
            .read(reportDraftProvider.notifier)
            .setFix(
              LatLngFix(
                lat: fix.latitude,
                lng: fix.longitude,
                accuracyM: fix.accuracy,
              ),
            );
      }
    }
    // Camera first for a new draft.
    if (mounted && (ref.read(reportDraftProvider)?.photos.isEmpty ?? true)) {
      await _takePhoto();
    }
  }

  Future<void> _takePhoto() async {
    final count = ref.read(reportDraftProvider)?.photos.length ?? 0;
    if (_capturing || count >= 3) return;
    _capturing = true;
    try {
      final shot = await ref.read(evidenceCaptureProvider).takePhoto();
      if (shot == null || !mounted) return;
      final from = globalRectOf(_takeKey);
      final to = globalRectOf(_slotKeys[count]);
      final adding = ref.read(reportPhotoPipelineProvider).addCaptured(shot);
      if (from != null && to != null && mounted) {
        await flyPhotoIn(
          context: context,
          from: from,
          to: to,
          image: FileImage(File(shot.path)),
        );
      }
      await adding;
    } finally {
      _capturing = false;
    }
  }

  void _syncWard(WardLocateResult? r) {
    final ctl = ref.read(reportDraftProvider.notifier);
    final current = ref.read(reportDraftProvider)?.ward;
    if (r == null) {
      ctl.setWard(null);
      return;
    }
    if (current?.id == r.ward.id) return;
    ctl.setWard(
      DraftWard(
        id: r.ward.id,
        nameEn: r.ward.nameEn,
        nameGu: r.ward.nameGu,
        zoneEn: r.ward.zone.nameEn,
        zoneGu: r.ward.zone.nameGu,
        confirm: r.confirm,
      ),
    );
  }

  void _onPin(LatLngFix pin) {
    final key = (lat: pin.lat, lng: pin.lng);
    if (_settled == key) return;
    _debounce?.cancel();
    _debounce = Timer(AppTimings.nearbyDebounce, () {
      if (mounted) setState(() => _settled = key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final draft = ref.watch(reportDraftProvider);
    if (draft == null) return const SizedBox.shrink();
    final pin = draft.pin;
    if (pin != null) {
      _onPin(pin);
      final lookup = ref.watch(pinWardProvider((lat: pin.lat, lng: pin.lng)));
      if (lookup.hasValue && lookup.value?.ward.id != draft.ward?.id) {
        // Never write a provider while the tree is building.
        Future.microtask(() {
          if (mounted) _syncWard(lookup.value);
        });
      }
      if (!ref.read(pinDroppedProvider).contains(draft.clientSubmissionId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(pinDroppedProvider.notifier)
                .mark(draft.clientSubmissionId);
          }
        });
      }
    }
    final denied = _access != null && _access != LocationAccess.granted;
    final outside =
        pin != null &&
        ref.watch(pinWardProvider((lat: pin.lat, lng: pin.lng))).value ==
            null &&
        ref.watch(pinWardProvider((lat: pin.lat, lng: pin.lng))).hasValue;
    final canContinue =
        draft.photos.isNotEmpty &&
        pin != null &&
        draft.wardReady &&
        !denied &&
        !outside;
    final pipeline = ref.read(reportPhotoPipelineProvider);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('report.photo'),
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.reportFlowStepPhotoTitle,
                  style: text.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              PhotoStrip(
                photos: draft.photos,
                slotKeys: _slotKeys,
                onRemove: (p) => ref
                    .read(reportDraftProvider.notifier)
                    .removePhoto(p.localPath),
                onRetry: (p) => pipeline.upload(p.localPath),
                onBlurMore: (p) => context.push(
                  Uri(
                    path: '/report/photo/blur',
                    queryParameters: {'path': p.localPath},
                  ).toString(),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              if (draft.photos.length < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: KeyedSubtree(
                    key: _takeKey,
                    child: SecondaryButton(
                      key: const Key('report.takePhoto'),
                      label: draft.photos.isEmpty
                          ? l10n.reportPhotoTake
                          : l10n.reportFlowAddAnotherPhoto,
                      icon: SaartheeIcons.addPhoto,
                      onPressed: _takePhoto,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s16),
              if (denied) ...[
                Text(
                  l10n.reportFlowLocationNeeded,
                  key: const Key('report.locationDenied'),
                  style: text.bodyMedium,
                ),
                TertiaryButton(
                  label: l10n.commonOpenSettings,
                  onPressed: () =>
                      ref.read(evidenceCaptureProvider).openSettings(_access!),
                ),
              ] else if (pin == null)
                Text(l10n.reportFlowLocating, style: text.bodyMedium)
              else
                PlacePanel(
                  draft: draft,
                  belowMap: _settled == null
                      ? null
                      : DuplicatePanel(
                          slug: draft.categorySlug!,
                          pin: _settled!,
                          dismissed: draft.dismissedDuplicateIds,
                        ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: PrimaryButton(
            key: const Key('report.continue'),
            label: l10n.commonContinue,
            pinned: true,
            onPressed: canContinue
                ? () => ref
                      .read(reportDraftProvider.notifier)
                      .goTo(ReportStep.details)
                : null,
          ),
        ),
      ],
    );
  }
}

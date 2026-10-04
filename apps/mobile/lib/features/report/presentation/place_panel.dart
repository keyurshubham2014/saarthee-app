import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/map/civic_map.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import '../application/report_providers.dart';

/// Metres per arrow press of the non-drag pin mover (TASK-05 §5.4).
const double kPinStepM = 5;

/// Mini-map with the pin, "Adjust pin" (pan under the pin, or arrows in
/// 5 m steps), the ward label and the confirm / outside / weak-GPS notes.
class PlacePanel extends ConsumerStatefulWidget {
  const PlacePanel({super.key, required this.draft, this.belowMap});

  final ReportDraft draft;

  /// Slot under the map's bottom edge (the duplicate card slides from here).
  final Widget? belowMap;

  @override
  ConsumerState<PlacePanel> createState() => _PlacePanelState();
}

class _PlacePanelState extends ConsumerState<PlacePanel> {
  final _map = MapController();
  bool _adjusting = false;
  LatLng? _center;

  ReportDraftController get _ctl => ref.read(reportDraftProvider.notifier);

  void _arrow(int dLatSign, int dLngSign) {
    final pin = widget.draft.pin!;
    final dLat = kPinStepM / 111320 * dLatSign;
    final dLng =
        kPinStepM / (111320 * math.cos(pin.lat * math.pi / 180)) * dLngSign;
    final next = LatLng(pin.lat + dLat, pin.lng + dLng);
    _ctl.movePin(next.latitude, next.longitude);
    try {
      _map.move(next, _map.camera.zoom);
    } on Object {
      // Map not laid out yet (tests without a viewport).
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final d = widget.draft;
    final pin = d.pin!;
    final dropped = ref
        .watch(pinDroppedProvider)
        .contains(d.clientSubmissionId);
    final ward = d.ward;
    final lookup = ref.watch(pinWardProvider((lat: pin.lat, lng: pin.lng)));
    final outside = lookup.hasValue && lookup.value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CivicMap(
          key: const Key('report.map'),
          center: LatLng(pin.lat, pin.lng),
          mapController: _map,
          adjusting: _adjusting,
          dropPin: !dropped,
          semanticLabel: l10n.reportFlowMapLabel,
          attribution: l10n.reportFlowMapAttribution,
          onCenterChanged: (p) => _center = p,
        ),
        ?widget.belowMap,
        const SizedBox(height: AppSpacing.s8),
        if (ward != null && !outside)
          Text(
            l10n.reportFlowInWard(ward.name(lang), ward.zone(lang)),
            key: const Key('report.wardLabel'),
            style: text.titleSmall,
          ),
        if (outside)
          Text(
            l10n.reportFlowOutsideArea,
            key: const Key('report.outside'),
            style: text.bodyMedium?.copyWith(color: c.error),
          ),
        if (ward != null && ward.confirm && !ward.confirmed && !outside) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.reportFlowWardConfirm(ward.name(lang)),
            style: text.bodyMedium,
          ),
          Wrap(
            spacing: AppSpacing.s8,
            children: [
              TextButton(
                key: const Key('report.ward.yes'),
                onPressed: _ctl.confirmWard,
                child: Text(l10n.reportFlowWardYes),
              ),
              TextButton(
                onPressed: () => setState(() => _adjusting = true),
                child: Text(l10n.reportFlowWardChooseAnother),
              ),
            ],
          ),
        ],
        if ((d.fix?.accuracyM ?? 0) > 50 && !d.pinAdjusted)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(
              l10n.reportFlowWeakGps,
              key: const Key('report.weakGps'),
              style: text.bodyMedium?.copyWith(color: c.warning),
            ),
          ),
        const SizedBox(height: AppSpacing.s8),
        if (!_adjusting)
          Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton(
              key: const Key('report.adjustPin'),
              label: l10n.reportFlowAdjustPin,
              icon: SaartheeIcons.location,
              onPressed: () => setState(() => _adjusting = true),
            ),
          )
        else
          Row(
            children: [
              IconButton(
                tooltip: l10n.reportFlowMovePinWest,
                onPressed: () => _arrow(0, -1),
                icon: const Icon(SaartheeIcons.back),
              ),
              IconButton(
                tooltip: l10n.reportFlowMovePinNorth,
                onPressed: () => _arrow(1, 0),
                icon: Transform.rotate(
                  angle: math.pi / 2,
                  child: const Icon(SaartheeIcons.back),
                ),
              ),
              IconButton(
                tooltip: l10n.reportFlowMovePinSouth,
                onPressed: () => _arrow(-1, 0),
                icon: Transform.rotate(
                  angle: -math.pi / 2,
                  child: const Icon(SaartheeIcons.back),
                ),
              ),
              IconButton(
                tooltip: l10n.reportFlowMovePinEast,
                onPressed: () => _arrow(0, 1),
                icon: const Icon(SaartheeIcons.forward),
              ),
              const Spacer(),
              TextButton(
                key: const Key('report.pinDone'),
                onPressed: () {
                  final p = _center;
                  if (p != null) _ctl.movePin(p.latitude, p.longitude);
                  setState(() => _adjusting = false);
                },
                child: Text(l10n.reportFlowPinDone),
              ),
            ],
          ),
      ],
    );
  }
}

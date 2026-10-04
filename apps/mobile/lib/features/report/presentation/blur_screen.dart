import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/capture/blur/face_plate_detector.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/photo_pipeline.dart';
import '../application/report_draft_controller.dart';
import 'pinned_action.dart';

/// `/report/photo/blur` (TASK-05 §5.4, REQ-S-007 P1): manual blur tool. Tap
/// blurs a square around the point, drag blurs the dragged rectangle; Undo
/// removes the last box; Done pixelates on the device and re-uploads.
class BlurScreen extends ConsumerStatefulWidget {
  const BlurScreen({super.key, required this.photoPath});

  final String photoPath;

  @override
  ConsumerState<BlurScreen> createState() => _BlurScreenState();
}

class _BlurScreenState extends ConsumerState<BlurScreen> {
  final List<BlurBox> _boxes = [];
  Offset? _dragStart;
  Rect? _dragRect;
  bool _saving = false;

  static const double _tapBox = 0.15;

  BlurBox _fromRect(Rect r, Size s) => BlurBox(
    (r.left / s.width).clamp(0.0, 1.0),
    (r.top / s.height).clamp(0.0, 1.0),
    (r.width / s.width).clamp(0.0, 1.0),
    (r.height / s.height).clamp(0.0, 1.0),
  );

  Future<void> _done() async {
    setState(() => _saving = true);
    await ref
        .read(reportPhotoPipelineProvider)
        .applyManualBlur(widget.photoPath, List.of(_boxes));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    // The automatic pass ran on this photo unless the detector is missing
    // or failed / timed out (then the photo is not marked blurred).
    final photo = ref
        .watch(reportDraftProvider)
        ?.photos
        .where((p) => p.localPath == widget.photoPath)
        .firstOrNull;
    final auto =
        ref.watch(faceAndPlateDetectorProvider) is! UnavailableDetector &&
        (photo?.blurApplied ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportBlurTitle),
        actions: [
          TextButton(
            onPressed: _boxes.isEmpty
                ? null
                : () => setState(_boxes.removeLast),
            child: Text(l10n.reportBlurUndo),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Text(
              auto ? l10n.reportBlurHint : l10n.reportBlurUnavailable,
              key: const Key('report.blur.note'),
              style: text.bodyMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = box.biggest;
                    return GestureDetector(
                      key: const Key('report.blur.canvas'),
                      onTapUp: (d) {
                        final w = size.width * _tapBox;
                        final h = size.height * _tapBox;
                        final r = Rect.fromCenter(
                          center: d.localPosition,
                          width: w,
                          height: h,
                        );
                        setState(() => _boxes.add(_fromRect(r, size)));
                      },
                      onPanStart: (d) => _dragStart = d.localPosition,
                      onPanUpdate: (d) => setState(
                        () => _dragRect = Rect.fromPoints(
                          _dragStart!,
                          d.localPosition,
                        ),
                      ),
                      onPanEnd: (_) => setState(() {
                        if (_dragRect != null) {
                          _boxes.add(_fromRect(_dragRect!, size));
                        }
                        _dragRect = null;
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(widget.photoPath), fit: BoxFit.fill),
                          for (final b in _boxes)
                            Positioned(
                              left: b.left * size.width,
                              top: b.top * size.height,
                              width: b.width * size.width,
                              height: b.height * size.height,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.textPrimary.withValues(alpha: 0.55),
                                  border: Border.all(
                                    color: c.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          if (_dragRect != null)
                            Positioned.fromRect(
                              rect: _dragRect!,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: c.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          PinnedAction(
            child: PrimaryButton(
              key: const Key('report.blur.done'),
              label: l10n.reportBlurDone,
              pinned: true,
              isLoading: _saving,
              onPressed: _saving ? null : _done,
            ),
          ),
        ],
      ),
    );
  }
}

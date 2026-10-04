// TASK-14 step 17 host driver for integration_test/motion_perf_test.dart.
// For every `MO-nn` trace: writes build/motion/MO-nn.timeline.json and
// MO-nn.timeline_summary.json, prints one result row, and fails the run
// when a moment has worst build or raster > 16 ms, any missed-budget frame,
// or (unless exempt) a layout pass after the moment's first frame.
//
// Environment (host side):
//   MOTION_BUDGET_MS=16     frame budget in ms (default 16)
//   MOTION_LAYOUT_GATE=0    report layout passes but do not fail on them
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

const _outDir = 'build/motion';

/// DS §6 exemptions: the report progress bar and the timeline step expand
/// animate size inside a clip.
const _layoutExempt = {'MO-10', 'MO-14'};

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null || data.isEmpty) {
      throw StateError('No traces reported (did every moment skip?)');
    }
    final budget = double.parse(
      Platform.environment['MOTION_BUDGET_MS'] ?? '16',
    );
    final layoutGate = Platform.environment['MOTION_LAYOUT_GATE'] != '0';
    final failures = <String>[];
    stdout.writeln(
      'moment | worst build ms | worst raster ms | '
      'missed build | missed raster | layouts after frame 1 | result',
    );
    for (final key in data.keys.toList()..sort()) {
      final timeline = Timeline.fromJson(
        Map<String, dynamic>.from(data[key] as Map),
      );
      final summary = TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(
        key,
        destinationDirectory: _outDir,
        pretty: true,
      );
      final s = summary.summaryJson;
      final build = (s['worst_frame_build_time_millis'] as num?) ?? 0;
      final raster = (s['worst_frame_rasterizer_time_millis'] as num?) ?? 0;
      final missedBuild = (s['missed_frame_build_budget_count'] as num?) ?? 0;
      final missedRaster =
          (s['missed_frame_rasterizer_budget_count'] as num?) ?? 0;
      final layouts = layoutsAfterFirstFrame(timeline);
      final reasons = [
        if (build > budget) 'build ${build.toStringAsFixed(1)} ms',
        if (raster > budget) 'raster ${raster.toStringAsFixed(1)} ms',
        if (missedBuild > 0) '$missedBuild missed build frames',
        if (missedRaster > 0) '$missedRaster missed raster frames',
        if (layoutGate && layouts > 0 && !_layoutExempt.contains(key))
          '$layouts layout passes after the first frame',
      ];
      stdout.writeln(
        '$key | ${build.toStringAsFixed(1)} | ${raster.toStringAsFixed(1)} | '
        '$missedBuild | $missedRaster | $layouts | '
        '${reasons.isEmpty ? 'PASS' : 'FAIL'}',
      );
      if (reasons.isNotEmpty) failures.add('$key: ${reasons.join(', ')}');
    }
    if (failures.isNotEmpty) {
      throw StateError(
        'Motion budget exceeded (traces in $_outDir):\n'
        '${failures.join('\n')}',
      );
    }
  },
);

/// Frames after the moment's first frame that laid out at least one
/// RenderObject. `LAYOUT` (PipelineOwner.flushLayout) is emitted every
/// frame; with `debugProfileLayoutsEnabled` each RenderObject layout nests
/// its own event inside it, so a `LAYOUT` span with children = a real pass.
int layoutsAfterFirstFrame(Timeline timeline) {
  final events = [
    for (final e in timeline.events ?? const <TimelineEvent>[])
      if (e.timestampMicros != null) e,
  ]..sort((a, b) => a.timestampMicros!.compareTo(b.timestampMicros!));
  final frameStarts = [
    for (final e in events)
      if (e.name == 'Frame' && e.phase == 'B') e.timestampMicros!,
  ];
  if (frameStarts.length < 2) return 0;
  final from = frameStarts[1];
  bool isLayout(TimelineEvent e) => e.name?.startsWith('LAYOUT') ?? false;
  var passes = 0;
  int? openThread;
  var nested = 0;
  for (final e in events) {
    if (e.timestampMicros! < from) continue;
    if (isLayout(e) && e.phase == 'B') {
      openThread = e.threadId;
      nested = 0;
    } else if (isLayout(e) && e.phase == 'E' && e.threadId == openThread) {
      if (nested > 0) passes++;
      openThread = null;
    } else if (openThread != null &&
        e.threadId == openThread &&
        e.phase == 'B') {
      nested++;
    }
  }
  return passes;
}

// V2-TASK-14 step 17: the perf driver's "layout pass after the first
// frame" counter on synthetic timelines.
import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_driver/perf_driver.dart' show layoutsAfterFirstFrame;

Map<String, dynamic> _e(String name, String ph, int ts, {int tid = 1}) => {
  'name': name,
  'ph': ph,
  'ts': ts,
  'tid': tid,
  'pid': 1,
};

Timeline _timeline(List<Map<String, dynamic>> events) =>
    Timeline.fromJson({'traceEvents': events});

void main() {
  test('empty LAYOUT spans (nothing dirty) are not layout passes', () {
    final t = _timeline([
      for (final f in [0, 16000, 32000]) ...[
        _e('Frame', 'B', f),
        _e('LAYOUT', 'B', f + 100),
        _e('LAYOUT', 'E', f + 200),
        _e('Frame', 'E', f + 900),
      ],
    ]);
    expect(layoutsAfterFirstFrame(t), 0);
  });

  test('a RenderObject layout inside LAYOUT after frame 1 counts', () {
    final t = _timeline([
      _e('Frame', 'B', 0),
      _e('LAYOUT', 'B', 100),
      _e('RenderFlex', 'B', 120),
      _e('RenderFlex', 'E', 150),
      _e('LAYOUT', 'E', 200),
      _e('Frame', 'B', 16000),
      _e('LAYOUT', 'B', 16100),
      _e('RenderParagraph', 'B', 16120),
      _e('RenderParagraph', 'E', 16130),
      _e('LAYOUT', 'E', 16200),
      _e('Frame', 'B', 32000),
      _e('LAYOUT', 'B', 32100),
      _e('LAYOUT', 'E', 32200),
    ]);
    // Frame 1's layout is allowed; frame 2 had one pass; frame 3 none.
    expect(layoutsAfterFirstFrame(t), 1);
  });

  test('events on another thread do not count', () {
    final t = _timeline([
      _e('Frame', 'B', 0),
      _e('Frame', 'B', 16000),
      _e('LAYOUT', 'B', 16100),
      _e('GPURasterizer::Draw', 'B', 16120, tid: 2),
      _e('LAYOUT', 'E', 16200),
    ]);
    expect(layoutsAfterFirstFrame(t), 0);
  });
}

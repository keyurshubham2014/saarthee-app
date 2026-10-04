// S-10-01 / §7.2: the staff web entry (`lib/main_staff.dart`) reaches only
// the staff feature, the sign-in flow and core — never the camera/capture
// pipeline, the report flow or the citizen app shell.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _import = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Transitive `lib/` files and external packages reachable from [entry].
({Set<String> files, Set<String> packages}) reach(String entry) {
  final files = <String>{};
  final packages = <String>{};
  final queue = [File(entry).absolute.path];
  final lib = Directory('lib').absolute.path;
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!files.add(path)) continue;
    final src = File(path).readAsStringSync();
    for (final m in _import.allMatches(src)) {
      final uri = m.group(1)!;
      if (uri.startsWith('dart:')) continue;
      if (uri.startsWith('package:saarthee/')) {
        queue.add('$lib/${uri.substring('package:saarthee/'.length)}');
      } else if (uri.startsWith('package:')) {
        packages.add(uri.substring(8).split('/').first);
      } else {
        queue.add(File(path).parent.uri.resolve(uri).toFilePath());
      }
    }
  }
  return (
    files: files.map((f) => f.substring(lib.length + 1)).toSet(),
    packages: packages,
  );
}

void main() {
  test('main_staff.dart imports only staff, auth and core code; no capture plugins', () {
    final r = reach('lib/main_staff.dart');
    // Shared data models / labels used by the mounted TASK-08/12 staff screens.
    const shared = {
      'features/alerts/data/alert_models.dart',
      'features/alerts/presentation/alert_labels.dart',
      'features/services/data/service_models.dart',
      'router/route_helpers.dart',
      'router/staff_routes.dart',
      'main_staff.dart',
    };
    final outside = r.files.where(
      (f) =>
          !f.startsWith('core/') &&
          !f.startsWith('features/staff/') &&
          !f.startsWith('features/auth/') &&
          !shared.contains(f),
    );
    expect(outside.toList()..sort(), isEmpty);
    expect(
      r.files.where(
        (f) => f.startsWith('core/capture/') || f.contains('report/'),
      ),
      isEmpty,
    );
    expect(r.packages.intersection({'camera', 'flutter_map'}), isEmpty);
  });
}

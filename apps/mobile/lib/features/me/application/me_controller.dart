import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/push/push_registrar.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/account_api.dart';
import '../../auth/data/account_models.dart';
import 'account_preference_sync.dart';

/// `GET /me` for the profile and privacy screens; null when signed out.
final meProvider = FutureProvider.autoDispose<Me?>((ref) async {
  final notifier = ref.read(sessionProvider.notifier);
  await notifier.ready;
  final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
  if (!signedIn) return null;
  return notifier.refreshMe();
});

/// Profile and privacy actions (TASK-04 §5.4). Screens call these; errors
/// are rethrown as `AppError` for the screen to show.
class MeActions {
  MeActions(this._ref);

  final Ref _ref;

  AccountApi get _api => _ref.read(accountApiProvider);

  Future<Me> saveDisplayName(String? name) async {
    final me = await _api.patchMe({'displayName': name});
    _ref.read(sessionProvider.notifier).setMe(me);
    _ref.invalidate(meProvider);
    return me;
  }

  /// Consent switch. Notifications on/off also switches push on this device.
  Future<void> setConsent(ConsentPurpose purpose, bool granted) async {
    final consents = await _api.setConsent(purpose, granted);
    final session = _ref.read(sessionProvider);
    if (session.me != null) {
      _ref
          .read(sessionProvider.notifier)
          .setMe(session.me!.copyWith(consents: consents));
    }
    if (purpose == ConsentPurpose.notifications) {
      final registrar = _ref.read(pushRegistrarProvider);
      if (granted && !registrar.enabled) {
        await registrar.enable();
      } else {
        await syncPush(_ref);
      }
    }
    _ref.invalidate(meProvider);
  }

  /// Downloads `GET /me/export` into the app cache, opens the share sheet,
  /// then deletes the temp file.
  Future<void> exportAndShare({required String subject}) async {
    final json = await _api.exportData();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final file = await _ref
        .read(exportFileWriterProvider)
        .write('saarthee-my-data-$day.json', json);
    try {
      await _ref.read(fileSharerProvider).share(file, subject: subject);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> signOut() async {
    await _ref.read(sessionProvider.notifier).signOut();
    await syncPush(_ref);
  }

  Future<void> deleteAccount() async {
    await _ref.read(sessionProvider.notifier).deleteAccount();
    await syncPush(_ref);
  }
}

final meActionsProvider = Provider<MeActions>(MeActions.new);

/// Writes the export to the app cache (overridden in tests).
abstract interface class ExportFileWriter {
  Future<File> write(String name, String contents);
}

class CacheExportFileWriter implements ExportFileWriter {
  const CacheExportFileWriter();

  @override
  Future<File> write(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name').writeAsString(contents, flush: true);
  }
}

final exportFileWriterProvider = Provider<ExportFileWriter>(
  (ref) => const CacheExportFileWriter(),
);

/// Share sheet port (share_plus; faked in tests).
abstract interface class FileSharer {
  Future<void> share(File file, {required String subject});
}

class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> share(File file, {required String subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
  }
}

final fileSharerProvider = Provider<FileSharer>(
  (ref) => const SharePlusFileSharer(),
);

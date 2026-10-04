import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/rep_claim_api.dart';

export '../../staff/shared/rep_shared.dart' show repErrorMessage;

/// Camera or gallery evidence picker (claims accept either; overridable in
/// tests). Compressed on the device like report photos.
class ClaimPhotoPicker {
  ClaimPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pick({required bool camera}) async {
    final f = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    return f?.path;
  }
}

final claimPhotoPickerProvider = Provider<ClaimPhotoPicker>(
  (ref) => ClaimPhotoPicker(),
);

enum EvidenceState { uploading, done, failed }

class EvidenceItem {
  const EvidenceItem({required this.path, required this.state, this.photoId});

  final String path;
  final EvidenceState state;
  final String? photoId;

  EvidenceItem copy({EvidenceState? state, String? photoId}) => EvidenceItem(
    path: path,
    state: state ?? this.state,
    photoId: photoId ?? this.photoId,
  );
}

class ClaimDraft {
  const ClaimDraft({this.photos = const [], this.note = ''});

  final List<EvidenceItem> photos;
  final String note;

  List<String> get photoIds => [
    for (final p in photos)
      if (p.state == EvidenceState.done) p.photoId!,
  ];

  bool get ready =>
      photoIds.isNotEmpty && photos.every((p) => p.state == EvidenceState.done);

  ClaimDraft copy({List<EvidenceItem>? photos, String? note}) =>
      ClaimDraft(photos: photos ?? this.photos, note: note ?? this.note);
}

/// In-memory claim draft per representative (kept while offline; never
/// persisted to disk because evidence is personal).
class ClaimDraftController extends Notifier<ClaimDraft> {
  ClaimDraftController(this.repId);

  final String repId;
  static const maxPhotos = 3;

  @override
  ClaimDraft build() => const ClaimDraft();

  RepClaimApi get _api => ref.read(repClaimApiProvider);

  Future<void> add(String path) async {
    if (state.photos.length >= maxPhotos) return;
    state = state.copy(
      photos: [
        ...state.photos,
        EvidenceItem(path: path, state: EvidenceState.uploading),
      ],
    );
    await _upload(path);
  }

  Future<void> retry(String path) => _upload(path);

  void remove(String path) => state = state.copy(
    photos: [
      for (final p in state.photos)
        if (p.path != path) p,
    ],
  );

  void setNote(String note) => state = state.copy(note: note);

  void clear() => state = const ClaimDraft();

  void _set(String path, EvidenceItem Function(EvidenceItem) f) => state = state
      .copy(photos: [for (final p in state.photos) p.path == path ? f(p) : p]);

  Future<void> _upload(String path) async {
    _set(path, (p) => p.copy(state: EvidenceState.uploading));
    try {
      final id = await _api.uploadEvidence(path);
      _set(path, (p) => p.copy(state: EvidenceState.done, photoId: id));
    } catch (_) {
      _set(path, (p) => p.copy(state: EvidenceState.failed));
    }
  }

  Future<String> submit() => _api.submit(
    repId,
    state.photoIds,
    state.note.isEmpty ? null : state.note,
  );
}

final claimDraftProvider =
    NotifierProvider.family<ClaimDraftController, ClaimDraft, String>(
      ClaimDraftController.new,
    );

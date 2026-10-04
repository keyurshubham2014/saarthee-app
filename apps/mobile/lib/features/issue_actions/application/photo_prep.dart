import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/capture/blur/face_plate_detector.dart';
import '../data/issue_actions_api.dart';

/// After / verification photos get the same on-device face and number-plate
/// blur as report photos (TASK-05 detector + renderer), then are uploaded
/// with `purpose` and the issue id. Returns the photo id.
Future<String> uploadIssuePhoto(
  Ref ref,
  String issueId,
  String path,
  String purpose,
) async {
  final boxes = await ref.read(faceAndPlateDetectorProvider).detect(path);
  var upload = path;
  final blurred = boxes != null && boxes.isNotEmpty;
  if (blurred) {
    upload = path.replaceFirst(
      RegExp(r'(\.jpe?g)?$', caseSensitive: false),
      '_blur.jpg',
    );
    await renderBlurredFile(path, upload, boxes);
  }
  return ref
      .read(issueActionsApiProvider)
      .uploadPhoto(issueId, upload, purpose, blurApplied: blurred);
}

/// Provider form so widgets (which hold a `WidgetRef`) can call it.
final issuePhotoUploaderProvider = Provider<IssuePhotoUploader>(
  IssuePhotoUploader.new,
);

class IssuePhotoUploader {
  IssuePhotoUploader(this._ref);
  final Ref _ref;

  Future<String> upload(String issueId, String path, String purpose) =>
      uploadIssuePhoto(_ref, issueId, path, purpose);
}

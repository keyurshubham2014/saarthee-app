import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../categories/staff_category_models.dart';
import '../shared/staff_labels.dart';
import '../shell/staff_motion.dart';
import 'staff_issue_models.dart';

/// Picks an after photo (camera in the app, a file on the web build) and
/// returns JPEG bytes; tests override it.
final staffPhotoPickerProvider = Provider<Future<List<int>?> Function()>((ref) => () async {
  final file = await ImagePicker().pickImage(
    source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
    imageQuality: 85,
    maxWidth: 2048,
  );
  return file?.readAsBytes();
});

Widget _actions(BuildContext ctx, AppLocalizations l10n, {required VoidCallback? onOk, String? okLabel, Key? okKey}) => Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.staffCancel)),
    const SizedBox(width: AppSpacing.s8),
    FilledButton(key: okKey, onPressed: onOk, child: Text(okLabel ?? l10n.staffConfirm)),
  ],
);

Widget _dialog(BuildContext ctx, String title, Key key, List<Widget> children) => Dialog(
  key: key,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sheet)),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(title, style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: AppSpacing.s16), ...children],
        ),
      ),
    ),
  ),
);

/// "Not accepted…": reason radio + optional note.
Future<({String reason, String? note})?> showRejectDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final note = TextEditingController();
  String? reason;
  return showStaffDialog(context, (ctx) => StatefulBuilder(
    builder: (ctx, setState) => _dialog(ctx, l10n.staffIssueReject, const Key('staff.rejectDialog'), [
      RadioGroup<String>(
        groupValue: reason,
        onChanged: (v) => setState(() => reason = v),
        child: Column(children: [
          for (final r in rejectReasons)
            RadioListTile<String>(key: Key('staff.reject.$r'), value: r, title: Text(rejectReasonLabel(l10n, r))),
        ]),
      ),
      TextField(controller: note, maxLength: 500, decoration: InputDecoration(labelText: l10n.staffIssueNote)),
      _actions(ctx, l10n, okKey: const Key('staff.reject.ok'),
          onOk: reason == null ? null : () => Navigator.of(ctx).pop((reason: reason!, note: note.text.trim()))),
    ]),
  ));
}

/// "Change category or ward".
Future<({String? categoryId, String? wardId})?> showRecategoriseDialog(BuildContext context, StaffIssue issue) {
  final l10n = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  String? categoryId = issue.categoryId;
  String? wardId = issue.ward?.id;
  return showStaffDialog(context, (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final cats = ref.watch(staffCategoriesProvider).value?.items ?? const <StaffCategory>[];
      final wards = ref.watch(wardsListProvider).value?.wards ?? const [];
      return StatefulBuilder(
        builder: (ctx, setState) => _dialog(ctx, l10n.staffIssueChange, const Key('staff.recatDialog'), [
          DropdownButtonFormField<String>(
            key: const Key('staff.recat.category'),
            initialValue: cats.any((c) => c.id == categoryId) ? categoryId : null,
            decoration: InputDecoration(labelText: l10n.staffIssueCategory),
            items: [for (final c in cats.where((c) => c.isActive)) DropdownMenuItem(value: c.id, child: Text(c.name(lang)))],
            onChanged: (v) => setState(() => categoryId = v),
          ),
          const SizedBox(height: AppSpacing.s12),
          DropdownButtonFormField<String>(
            key: const Key('staff.recat.ward'),
            initialValue: wards.any((w) => w.id == wardId) ? wardId : null,
            decoration: InputDecoration(labelText: l10n.staffIssueWard),
            items: [for (final w in wards) DropdownMenuItem(value: w.id, child: Text(staffWardText(w, lang)))],
            onChanged: (v) => setState(() => wardId = v),
          ),
          const SizedBox(height: AppSpacing.s16),
          _actions(ctx, l10n, okLabel: l10n.staffSave, okKey: const Key('staff.recat.ok'), onOk: () {
            final cat = categoryId != issue.categoryId ? categoryId : null;
            final ward = wardId != issue.ward?.id ? wardId : null;
            Navigator.of(ctx).pop(cat == null && ward == null ? null : (categoryId: cat, wardId: ward));
          }),
        ]),
      );
    },
  ));
}

/// "Merge into…": open reports within 500 m, nearest first, distance shown.
Future<String?> showMergeDialog(BuildContext context, StaffIssue issue) {
  final l10n = AppLocalizations.of(context);
  return showStaffDialog(context, (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final value = ref.watch(mergeCandidatesProvider(issue.id));
      final list = value.value;
      return _dialog(ctx, l10n.staffIssueMerge, const Key('staff.mergeDialog'), [
        if (list == null && value.hasError) Text(l10n.staffLoadError),
        if (list == null && !value.hasError) const Center(child: CircularProgressIndicator()),
        if (list != null && list.isEmpty) Text(l10n.staffIssueMergeEmpty, key: const Key('staff.merge.empty')),
        if (list != null)
          for (final m in list)
            ListRow(
              key: Key('staff.merge.${m.id}'),
              leading: CategoryBadge(slug: m.categorySlug),
              title: m.title,
              subtitle: [l10n.staffIssueMergeDistance(m.distanceM), if (m.far) l10n.staffIssueMergeFar].join(' · '),
              onTap: () => Navigator.of(ctx).pop(m.id),
            ),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.staffCancel))),
      ]);
    },
  ));
}

/// "Mark as fixed": optional after photo + note.
Future<({List<int>? photo, String? note})?> showMarkFixedDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final note = TextEditingController();
  List<int>? photo;
  return showStaffDialog(context, (ctx) => StatefulBuilder(
    builder: (ctx, setState) => _dialog(ctx, l10n.staffIssueMarkFixed, const Key('staff.fixedDialog'), [
      Text(l10n.staffIssueConfirmFixed),
      const SizedBox(height: AppSpacing.s12),
      SecondaryButton(
        key: const Key('staff.fixed.photo'),
        label: photo == null ? l10n.staffIssueAfterPhoto : l10n.staffIssueAfterPhotoAdded,
        icon: photo == null ? SaartheeIcons.addPhoto : SaartheeIcons.check,
        onPressed: () async {
          final bytes = await ref.read(staffPhotoPickerProvider)();
          if (bytes != null) setState(() => photo = bytes);
        },
      ),
      const SizedBox(height: AppSpacing.s12),
      TextField(controller: note, maxLength: 500, decoration: InputDecoration(labelText: l10n.staffIssueNote)),
      _actions(ctx, l10n, okLabel: l10n.staffIssueMarkFixed, okKey: const Key('staff.fixed.ok'),
          onOk: () => Navigator.of(ctx).pop((photo: photo, note: note.text.trim()))),
    ]),
  ));
}

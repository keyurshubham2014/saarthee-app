import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shell/staff_motion.dart';

/// Loading skeleton → content / error, cross-faded over `short` (DS §6
/// staff row); reduced motion → instant.
class StaffAsync<T> extends StatelessWidget {
  const StaffAsync({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.skeletonCount = 4,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget child = value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => SkeletonList(key: const Key('staff.loading'), count: skeletonCount),
      error: (_, _) => ErrorState(
        key: const Key('staff.error'),
        message: l10n.staffLoadError,
        onRetry: onRetry,
      ),
      data: (d) => KeyedSubtree(key: const Key('staff.data'), child: builder(d)),
    );
    return AnimatedSwitcher(
      duration: staffFade(context),
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
      child: child,
    );
  }
}

/// Card container: surface, radius 18, 1 px border (DS §4/§5).
class StaffCard extends StatelessWidget {
  const StaffCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.s16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

/// Section heading inside a staff page.
class StaffSectionTitle extends StatelessWidget {
  const StaffSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s20, bottom: AppSpacing.s8),
    child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
  );
}

/// Confirm dialog stating the effect; returns true when confirmed.
Future<bool> confirmStaffAction(BuildContext context, {required String title, required String effect}) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showStaffDialog<bool>(
    context,
    (ctx) => AlertDialog(
      key: const Key('staff.confirm'),
      title: Text(title),
      content: Text(effect),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.staffCancel)),
        FilledButton(
          key: const Key('staff.confirm.ok'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.staffConfirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Asks for a required reason (≤ 200); returns null when cancelled.
Future<String?> askStaffReason(BuildContext context, {required String title, String? effect}) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  final result = await showStaffDialog<String>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        key: const Key('staff.reasonDialog'),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (effect != null) Text(effect),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              key: const Key('staff.reason'),
              controller: controller,
              maxLength: 200,
              decoration: InputDecoration(labelText: l10n.staffUsersReasonHint),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.staffCancel)),
          FilledButton(
            key: const Key('staff.reason.ok'),
            onPressed: controller.text.trim().isEmpty ? null : () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.staffConfirm),
          ),
        ],
      ),
    ),
  );
  // The controller is not disposed here: the dialog still reads it while it
  // fades out.
  return result;
}

/// Error text for a failed staff action.
String staffErrorText(AppLocalizations l10n, Object e) =>
    l10n.staffActionError(e is AppError ? e.message : l10n.staffLoadError);

bool isStaleError(Object e) =>
    e is AppError && (e.code == 'ISSUE_STATE_INVALID' || e.code == 'INVALID_TRANSITION' || e.code == 'NOT_FOUND');

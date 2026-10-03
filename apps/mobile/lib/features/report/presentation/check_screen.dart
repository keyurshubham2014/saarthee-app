import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import '../application/report_submit_controller.dart';
import 'report_step_mixin.dart';

/// Step 6: Check your answers (02 §4.9).
class CheckScreen extends ConsumerStatefulWidget {
  const CheckScreen({super.key});

  @override
  ConsumerState<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends ConsumerState<CheckScreen>
    with ReportStepMixin {
  @override
  String get stepRoute => ReportRoutes.check;

  void _change(String route) => context.go('$route?from=check');

  Future<void> _send() async {
    final ok = await ref.read(reportSubmitProvider.notifier).send();
    if (ok && mounted) context.go(ReportRoutes.done);
  }

  /// Server problems as summary items linking to the step to fix.
  List<ErrorSummaryItem> _summary(AppLocalizations l10n, AppError e) {
    String routeFor(String field) {
      if (field.startsWith('phone') || field.startsWith('consent')) {
        return ReportRoutes.phone;
      }
      if (field.startsWith('ccrs')) return ReportRoutes.number;
      if (field.startsWith('category')) return ReportRoutes.category;
      return ReportRoutes.photo;
    }

    String messageFor(String field) {
      if (field.startsWith('phone')) return l10n.reportPhoneError;
      if (field.startsWith('consent')) return l10n.reportConsentError;
      if (field.startsWith('ccrs')) return l10n.reportNumberError;
      if (field.startsWith('category')) return l10n.errorCategoryInactive;
      if (field.startsWith('deviceCapturedAt')) return l10n.reportErrorClock;
      if (field == 'latitude' || field == 'longitude') {
        return l10n.reportErrorLocation;
      }
      if (field.startsWith('photo')) return l10n.reportErrorPhotoExpired;
      return l10n.errorValidationFailed;
    }

    switch (e.code) {
      case 'VALIDATION_FAILED' when e.details.isNotEmpty:
        final seen = <String>{};
        return [
          for (final d in e.details)
            if (seen.add(messageFor(d.field)))
              ErrorSummaryItem(
                messageFor(d.field),
                onTap: () => _change(routeFor(d.field)),
              ),
        ];
      case 'PHOTO_UNUSABLE':
        return [
          ErrorSummaryItem(
            l10n.errorPhotoUnusable,
            onTap: () => _change(ReportRoutes.photo),
          ),
        ];
      case 'CATEGORY_INACTIVE':
        return [
          ErrorSummaryItem(
            l10n.errorCategoryInactive,
            onTap: () => _change(ReportRoutes.category),
          ),
        ];
      default:
        return [ErrorSummaryItem(appErrorMessage(l10n, e))];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = ref.watch(reportDraftProvider);
    final submit = ref.watch(reportSubmitProvider);
    final offline = ref.watch(isOfflineProvider);
    final sending = submit.status == SubmitStatus.sending;
    final error = submit.error;

    if (d == null) {
      return StepScaffold(
        title: l10n.reportCheckTitle,
        onBack: () => context.go('/'),
        actions: [
          PrimaryButton(
            label: l10n.commonGoHome,
            onPressed: () => context.go('/'),
          ),
        ],
        children: const [],
      );
    }

    final complete =
        d.categoryId != null &&
        (d.ccrsNumber ?? '').isNotEmpty &&
        d.photoId != null &&
        (d.phone ?? '').isNotEmpty &&
        d.consentGiven;

    Widget row(String label, String? value, String route, {Widget? extra}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.titleMedium),
                  ),
                  Semantics(
                    label: l10n.reportCheckChangeLabel(label),
                    excludeSemantics: true,
                    button: true,
                    child: TextButton(
                      key: Key('report.check.change.$route'),
                      onPressed: sending ? null : () => _change(route),
                      child: Text(l10n.commonChange),
                    ),
                  ),
                ],
              ),
              if (extra != null)
                extra
              else
                Text(
                  value ?? l10n.reportCheckMissing,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: value == null ? AppColors.notFixed : null,
                  ),
                ),
            ],
          ),
        );

    return StepScaffold(
      step: 6,
      total: kReportSteps,
      title: l10n.reportCheckTitle,
      onBack: () => context.go(ReportRoutes.phone),
      showOfflineBanner: offline || (error?.isOffline ?? false),
      onRetryOffline: error?.isOffline == true ? _send : null,
      actions: [
        PrimaryButton(
          key: const Key('report.check.send'),
          label: l10n.commonSend,
          loading: sending,
          onPressed: complete ? _send : null,
        ),
      ],
      children: [
        if (error != null && !error.isOffline) ...[
          AppErrorSummary(items: _summary(l10n, error)),
          const SizedBox(height: AppSpacing.lg),
        ],
        row(l10n.reportCheckCategory, d.categoryName, ReportRoutes.category),
        const Divider(),
        row(l10n.reportCheckNumber, d.ccrsNumber, ReportRoutes.number),
        const Divider(),
        row(
          l10n.reportCheckPhoto,
          null,
          ReportRoutes.photo,
          extra: d.photoPath == null
              ? Text(
                  l10n.reportCheckMissing,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.notFixed,
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 160,
                    child: EvidencePhoto(
                      image: FileImage(File(d.photoPath!)),
                      capturedAt: d.deviceCapturedAt,
                      accuracyMeters: d.gpsAccuracyM,
                    ),
                  ),
                ),
        ),
        const Divider(),
        row(
          l10n.reportCheckPhone,
          (d.phone ?? '').isEmpty ? null : Formatters.phone(d.phone!),
          ReportRoutes.phone,
        ),
      ],
    );
  }
}

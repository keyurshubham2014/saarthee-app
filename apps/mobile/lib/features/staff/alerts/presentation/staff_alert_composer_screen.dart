import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/app_error.dart';
import '../../../../core/config/timings.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/wards/ward.dart';
import '../../../../core/wards/ward_providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../alerts/data/alert_models.dart';
import '../../../alerts/presentation/alert_labels.dart';
import '../../shared/staff_errors.dart';
import '../../shared/staff_shared.dart';
import '../application/staff_alerts_providers.dart';
import '../data/staff_alerts_api.dart';
import 'composer_fields.dart';
import 'composer_preview.dart';

/// `/staff/alerts/new` and editing a draft (REQ-F-035): labelled fields with
/// counters, error summary at the top (focused, links to fields), live
/// preview in both languages, "Save draft".
class StaffAlertComposerScreen extends ConsumerStatefulWidget {
  const StaffAlertComposerScreen({super.key, this.existing, this.now});

  final StaffAlert? existing;

  /// Test clock.
  final DateTime? now;

  @override
  ConsumerState<StaffAlertComposerScreen> createState() =>
      StaffAlertComposerScreenState();
}

class StaffAlertComposerScreenState
    extends ConsumerState<StaffAlertComposerScreen> {
  late final DateTime _now = widget.now ?? DateTime.now().toUtc();
  late final ComposerDraft d = widget.existing == null
      ? ComposerDraft(
          validFrom: _now,
          validTo: _now.add(AppTimings.composerDefaultSpan),
        )
      : ComposerDraft.from(widget.existing!);
  Map<String, String> problems = {};
  final summaryFocus = FocusNode(debugLabel: 'composerSummary');
  final Map<String, FocusNode> _focus = {
    for (final f in [
      'titleEn',
      'titleGu',
      'bodyEn',
      'bodyGu',
      'sourceName',
      'sourceUrl',
    ])
      f: FocusNode(),
  };
  bool _busy = false;

  @override
  void dispose() {
    summaryFocus.dispose();
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => problems = composerProblems(d, now: _now));
    if (problems.isNotEmpty) {
      summaryFocus.requestFocus();
      return;
    }
    setState(() => _busy = true);
    final api = ref.read(staffAlertsApiProvider);
    try {
      final saved = widget.existing == null
          ? await api.create(d.toJson())
          : await api.update(widget.existing!.id, d.toJson());
      if (mounted) context.pushReplacement('/staff/alerts/${saved.id}');
    } catch (e) {
      final err = AppError.from(e);
      setState(
        () => problems = {
          for (final x in err.details)
            composerServerField(x.field): composerServerProblem(
              x.issue,
              field: composerServerField(x.field),
            ),
        },
      );
      if (problems.isEmpty && mounted) {
        showSaartheeToast(
          context,
          staffErrorMessage(AppLocalizations.of(context), err),
          kind: ToastKind.error,
        );
      }
      summaryFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _err(String field) => problems[field] == null
      ? null
      : composerProblemText(AppLocalizations.of(context), problems[field]!);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final wards = ref.watch(wardsListProvider).value?.wards ?? const <Ward>[];
    final zones = {for (final w in wards) w.zone.id: w.zone}.values.toList();
    void set(VoidCallback f) => setState(f);
    final labels = {
      'titleEn': l10n.staffAlertsFieldTitleEn,
      'titleGu': l10n.staffAlertsFieldTitleGu,
      'bodyEn': l10n.staffAlertsFieldBodyEn,
      'bodyGu': l10n.staffAlertsFieldBodyGu,
      'sourceName': l10n.staffAlertsFieldSourceName,
      'sourceUrl': l10n.staffAlertsFieldSourceUrl,
      'validTo': l10n.staffAlertsFieldValidTo,
      'validFrom': l10n.staffAlertsFieldValidFrom,
      'area': l10n.staffAlertsFieldArea,
      'type': l10n.staffAlertsFieldType,
      'severity': l10n.staffAlertsFieldSeverity,
    };
    return StaffPageScaffold(
      title: l10n.staffAlertsNew,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (problems.isNotEmpty)
            Focus(
              focusNode: summaryFocus,
              child: Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('composerErrorSummary'),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: SaartheeColors.of(context).errorTint,
                    borderRadius: AppRadii.controlRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.staffAlertsErrorSummary),
                      for (final f in problems.keys)
                        TextButton(
                          onPressed: () => _focus[f]?.requestFocus(),
                          child: Text(
                            '${labels[f] ?? l10n.staffAlertsFieldGeneric}: ${_err(f)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          FieldLabel(l10n.staffAlertsFieldType),
          DropdownButton<String>(
            value: d.type,
            isExpanded: true,
            items: [
              for (final t in AlertType.values)
                DropdownMenuItem(
                  value: t.api,
                  child: Text(alertTypeLabel(l10n, t)),
                ),
            ],
            onChanged: (v) => set(() => d.type = v ?? d.type),
          ),
          FieldLabel(l10n.staffAlertsFieldSeverity),
          Text(
            l10n.staffAlertsSeverityHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          RadioGroup<String>(
            groupValue: d.severity,
            onChanged: (v) => set(() => d.severity = v ?? d.severity),
            child: Column(
              children: [
                for (final s in AlertSeverity.values)
                  RadioListTile<String>(
                    value: s.name,
                    title: Text(alertSeverityLabel(l10n, s)),
                  ),
              ],
            ),
          ),
          for (final (f, max, lines) in [
            ('titleEn', 80, 1),
            ('titleGu', 80, 1),
            ('bodyEn', 500, 3),
            ('bodyGu', 500, 3),
            ('sourceName', 80, 1),
            ('sourceUrl', 500, 1),
          ])
            ComposerTextField(
              key: ValueKey('composer.$f'),
              label: labels[f]!,
              initial: d.toJson()[f] as String,
              max: max,
              lines: lines,
              focusNode: _focus[f],
              error: _err(f),
              onChanged: (v) => set(() => _assign(f, v)),
            ),
          IstDateTimeField(
            label: labels['validFrom']!,
            value: d.validFrom,
            lang: lang,
            onChanged: (v) => set(() => d.validFrom = v),
          ),
          IstDateTimeField(
            label: labels['validTo']!,
            value: d.validTo,
            lang: lang,
            error: _err('validTo'),
            onChanged: (v) => set(() => d.validTo = v),
          ),
          ComposerArea(
            draft: d,
            wards: wards,
            zones: zones,
            lang: lang,
            error: _err('area'),
            onChanged: () => set(() {}),
          ),
          ComposerPreview(draft: d),
          const SizedBox(height: AppSpacing.s16),
          PrimaryButton(
            key: const ValueKey('composerSave'),
            label: l10n.staffAlertsSaveDraft,
            isLoading: _busy,
            onPressed: _busy ? null : save,
          ),
        ],
      ),
    );
  }

  void _assign(String f, String v) => switch (f) {
    'titleEn' => d.titleEn = v,
    'titleGu' => d.titleGu = v,
    'bodyEn' => d.bodyEn = v,
    'bodyGu' => d.bodyGu = v,
    'sourceName' => d.sourceName = v,
    _ => d.sourceUrl = v,
  };
}

/// `/staff/alerts/:id/edit`: loads the alert, then the composer.
class StaffAlertEditScreen extends ConsumerWidget {
  const StaffAlertEditScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(staffAlertProvider(id))
      .when(
        loading: () => const Scaffold(body: SkeletonList(count: 4)),
        error: (_, _) => Scaffold(
          body: ErrorState(
            message: AppLocalizations.of(context).staffAlertsLoadError,
            onRetry: () => ref.invalidate(staffAlertProvider(id)),
          ),
        ),
        data: (a) => StaffAlertComposerScreen(existing: a),
      );
}

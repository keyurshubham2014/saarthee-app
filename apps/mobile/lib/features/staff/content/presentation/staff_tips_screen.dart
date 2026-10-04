import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/wards/ward_providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../services/data/service_models.dart' show pick;
import '../application/content_validators.dart';
import '../data/staff_content_api.dart';
import 'content_form.dart';
import 'staff_gate.dart';

final staffTipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(staffContentApiProvider).tips(),
    );

/// `/staff/tips` (admin): seasonal tips with their active window; Edit,
/// Delete and New.
class StaffTipsScreen extends ConsumerWidget {
  const StaffTipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(staffTipsProvider);
    return StaffPage(
      title: l10n.staffContentTipsTitle,
      roles: adminOnly,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('staff.tips.new'),
        onPressed: () => context.push('/staff/tips/new'),
        icon: const Icon(SaartheeIcons.add),
        label: Text(l10n.staffContentNewTip),
      ),
      child: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => ErrorState(
          message: l10n.staffContentLoadError,
          onRetry: () => ref.invalidate(staffTipsProvider),
        ),
        data: (rows) => ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final t = rows[i];
            final id = '${t['id']}';
            return ListTile(
              key: Key('staff.tip.$id'),
              title: Text(
                pick(
                  Localizations.localeOf(context).languageCode,
                  str(t['titleEn']),
                  str(t['titleGu']),
                ),
              ),
              subtitle: Text(
                '${t['activeFrom']} – ${t['activeTo']}${t['isActive'] == true ? '' : ' · ${l10n.staffContentInactive}'}',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: l10n.staffContentEdit,
                    icon: const Icon(SaartheeIcons.editNote),
                    onPressed: () => context.push('/staff/tips/$id', extra: t),
                  ),
                  IconButton(
                    tooltip: l10n.staffContentDelete,
                    icon: const Icon(SaartheeIcons.delete),
                    onPressed: () async {
                      await ref.read(staffContentApiProvider).deleteTip(id);
                      ref.invalidate(staffTipsProvider);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// `/staff/tips/new` and `/staff/tips/:id` (admin).
class StaffTipFormScreen extends ConsumerWidget {
  const StaffTipFormScreen({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final v = ContentValidators(l10n);
    final e = existing;
    final wards = ref.watch(wardsListProvider).value?.wards ?? const [];
    String s(String k) => e == null || e[k] == null ? '' : '${e[k]}';
    final wardNumber =
        wards
            .where((w) => w.id == s('wardId'))
            .map((w) => '${w.number}')
            .firstOrNull ??
        '';

    Future<Map<String, String>?> submit(FormValues f) async {
      final ward = '${f['wardNumber']}'.trim();
      final wardId = ward.isEmpty
          ? null
          : wards
                .where((w) => '${w.number}' == ward)
                .map((w) => w.id)
                .firstOrNull;
      if (ward.isNotEmpty && wardId == null) {
        return {'wardNumber': l10n.staffContentErrorNumber};
      }
      if ('${f['activeTo']}'.compareTo('${f['activeFrom']}') < 0) {
        return {'activeTo': l10n.staffContentErrorDate};
      }
      final slug = '${f['serviceSlug']}'.trim();
      final body = <String, Object?>{
        for (final k in [
          'titleEn',
          'titleGu',
          'bodyEn',
          'bodyGu',
          'activeFrom',
          'activeTo',
          'isActive',
        ])
          k: f[k],
        'serviceSlug': slug.isEmpty ? null : slug,
        'wardId': wardId,
      };
      final api = ref.read(staffContentApiProvider);
      if (e == null) {
        await api.createTip(body);
      } else {
        await api.updateTip('${e['id']}', body);
      }
      ref.invalidate(staffTipsProvider);
      if (context.mounted) {
        showSaartheeToast(context, l10n.staffContentSaved);
        leaveForm(context, '/staff/tips');
      }
      return null;
    }

    return StaffPage(
      title: e == null
          ? l10n.staffContentNewTip
          : pick(
              Localizations.localeOf(context).languageCode,
              s('titleEn'),
              s('titleGu'),
            ),
      roles: adminOnly,
      child: ContentForm(
        key: const Key('staff.tipForm'),
        submitLabel: l10n.staffContentSave,
        onSubmit: submit,
        rows: [
          [
            FieldSpec.text(
              'titleEn',
              l10n.staffContentFieldTitleEn,
              initial: s('titleEn'),
              validator: (x) => v.required(x, max: 80),
            ),
            FieldSpec.text(
              'titleGu',
              l10n.staffContentFieldTitleGu,
              initial: s('titleGu'),
              validator: (x) => v.required(x, max: 80),
            ),
          ],
          [
            FieldSpec.text(
              'bodyEn',
              l10n.staffContentFieldBodyEn,
              initial: s('bodyEn'),
              maxLines: 3,
              validator: (x) => v.required(x, max: 240),
            ),
            FieldSpec.text(
              'bodyGu',
              l10n.staffContentFieldBodyGu,
              initial: s('bodyGu'),
              maxLines: 3,
              validator: (x) => v.required(x, max: 240),
            ),
          ],
          [
            FieldSpec.text(
              'serviceSlug',
              l10n.staffContentFieldServiceSlug,
              initial: s('serviceSlug'),
            ),
          ],
          [
            FieldSpec.text(
              'wardNumber',
              l10n.staffContentFieldWardNumber,
              initial: wardNumber,
              validator: (x) => v.wholeNumber(x, optional: true),
            ),
          ],
          [
            FieldSpec.text(
              'activeFrom',
              l10n.staffContentFieldActiveFrom,
              initial: s('activeFrom'),
              validator: v.date,
            ),
            FieldSpec.text(
              'activeTo',
              l10n.staffContentFieldActiveTo,
              initial: s('activeTo'),
              validator: v.date,
            ),
          ],
          [
            FieldSpec.toggle(
              'isActive',
              l10n.staffContentFieldActive,
              initialBool: e == null || e['isActive'] == true,
            ),
          ],
        ],
      ),
    );
  }
}

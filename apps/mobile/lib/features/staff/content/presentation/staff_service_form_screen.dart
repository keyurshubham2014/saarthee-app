import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/app_error.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../services/data/service_models.dart' show serviceCategories;
import '../application/content_validators.dart';
import '../data/staff_content_api.dart';
import 'content_form.dart';
import 'staff_gate.dart';
import 'staff_services_screen.dart';

/// `/staff/services/new` and `/staff/services/:id` (admin): every editable
/// service field, https link check, numbered-steps check, "Mark content
/// verified today".
class StaffServiceFormScreen extends ConsumerWidget {
  const StaffServiceFormScreen({super.key, this.existing});

  /// The row being edited (from the list), or null for a new service.
  final Map<String, dynamic>? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final v = ContentValidators(l10n);
    final e = existing;
    String s(String k) => e == null ? '' : '${e[k] ?? ''}';
    bool b(String k, bool fallback) => e == null ? fallback : e[k] == true;

    Future<Map<String, String>?> submit(FormValues values) async {
      final api = ref.read(staffContentApiProvider);
      final body = <String, Object?>{
        ...values,
        'sortOrder': int.parse('${values['sortOrder']}'),
      }..remove('markVerified');
      if (values['markVerified'] == true) body['markVerified'] = true;
      try {
        if (e == null) {
          await api.createService(body);
        } else {
          await api.updateService('${e['id']}', body);
        }
      } on AppError catch (err) {
        if (err.code == 'SLUG_TAKEN') {
          return {'slug': l10n.staffContentErrorSlugTaken};
        }
        rethrow;
      }
      ref.invalidate(staffServicesProvider);
      if (context.mounted) {
        showSaartheeToast(context, l10n.staffContentSaved);
        leaveForm(context, '/staff/services');
      }
      return null;
    }

    return StaffPage(
      title: e == null ? l10n.staffContentNewService : s('nameEn'),
      roles: adminOnly,
      child: ContentForm(
        key: const Key('staff.serviceForm'),
        submitLabel: l10n.staffContentSave,
        onSubmit: submit,
        rows: [
          [
            FieldSpec.text(
              'slug',
              l10n.staffContentFieldSlug,
              initial: s('slug'),
              validator: v.slug,
            ),
            FieldSpec.text(
              'category',
              l10n.staffContentFieldCategory,
              initial: s('category').isEmpty
                  ? serviceCategories.first
                  : s('category'),
              validator: (x) => serviceCategories.contains(x.trim())
                  ? null
                  : l10n.staffContentErrorRequired,
            ),
          ],
          [
            FieldSpec.text(
              'nameEn',
              l10n.staffContentFieldNameEn,
              initial: s('nameEn'),
              validator: (x) => v.required(x, max: 80),
            ),
            FieldSpec.text(
              'nameGu',
              l10n.staffContentFieldNameGu,
              initial: s('nameGu'),
              validator: (x) => v.required(x, max: 80),
            ),
          ],
          [
            FieldSpec.text(
              'department',
              l10n.staffContentFieldDepartmentEn,
              initial: s('department'),
              validator: (x) => v.required(x, max: 100),
            ),
            FieldSpec.text(
              'departmentGu',
              l10n.staffContentFieldDepartmentGu,
              initial: s('departmentGu'),
              validator: (x) => v.required(x, max: 100),
            ),
          ],
          [
            FieldSpec.text(
              'summaryEn',
              l10n.staffContentFieldSummaryEn,
              initial: s('summaryEn'),
              maxLines: 3,
              validator: (x) => v.required(x, max: 300),
            ),
            FieldSpec.text(
              'summaryGu',
              l10n.staffContentFieldSummaryGu,
              initial: s('summaryGu'),
              maxLines: 3,
              validator: (x) => v.required(x, max: 300),
            ),
          ],
          [
            FieldSpec.text(
              'howToEn',
              l10n.staffContentFieldHowToEn,
              initial: s('howToEn'),
              maxLines: 6,
              validator: v.steps,
            ),
            FieldSpec.text(
              'howToGu',
              l10n.staffContentFieldHowToGu,
              initial: s('howToGu'),
              maxLines: 6,
              validator: v.steps,
            ),
          ],
          [
            FieldSpec.text(
              'url',
              l10n.staffContentFieldUrl,
              initial: s('url'),
              validator: v.https,
              keyboardType: TextInputType.url,
            ),
          ],
          [
            FieldSpec.text(
              'sortOrder',
              l10n.staffContentFieldSortOrder,
              initial: e == null ? '100' : s('sortOrder'),
              validator: v.wholeNumber,
              keyboardType: TextInputType.number,
            ),
          ],
          [
            FieldSpec.toggle(
              'online',
              l10n.staffContentFieldOnline,
              initialBool: b('online', false),
            ),
          ],
          [
            FieldSpec.toggle(
              'visitWardOffice',
              l10n.staffContentFieldWardOffice,
              initialBool: b('visitWardOffice', false),
            ),
          ],
          [
            FieldSpec.toggle(
              'isActive',
              l10n.staffContentFieldActive,
              initialBool: b('isActive', true),
            ),
          ],
          if (e != null)
            [FieldSpec.toggle('markVerified', l10n.staffContentMarkVerified)],
        ],
      ),
    );
  }
}

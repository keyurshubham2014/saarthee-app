import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/wards/ward_providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../application/content_validators.dart';
import '../data/staff_content_api.dart';
import 'content_form.dart';
import 'staff_gate.dart';
import 'staff_initiatives_screen.dart';

const _types = ['tree_drive', 'cleanup', 'health_camp', 'other'];
const _organisers = ['AMC', 'RWA', 'NGO', 'Saarthee'];

/// `/staff/initiatives/new` and `/staff/initiatives/:id` (admin): titles,
/// descriptions, type, organiser + name, source (needed for AMC), ward
/// number (blank = city-wide), place, map pin, start/end (IST), capacity.
/// New drives are saved as drafts; Publish is on the list.
class StaffInitiativeFormScreen extends ConsumerWidget {
  const StaffInitiativeFormScreen({super.key, this.existing});

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
    String? oneOf(String x, List<String> allowed) =>
        allowed.contains(x.trim()) ? null : allowed.join(' / ');
    double? num(Object? x) => double.tryParse('$x'.trim());

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
      if (f['organiser'] == 'AMC' && '${f['sourceUrl']}'.isEmpty) {
        return {'sourceUrl': l10n.staffContentErrorHttps};
      }
      final body = <String, Object?>{
        for (final k in [
          'titleEn',
          'titleGu',
          'descriptionEn',
          'descriptionGu',
          'type',
          'organiser',
          'organiserName',
          'locationTextEn',
          'locationTextGu',
        ])
          k: f[k],
        'sourceUrl': '${f['sourceUrl']}'.isEmpty ? null : f['sourceUrl'],
        'wardId': wardId,
        'lat': num(f['lat']),
        'lng': num(f['lng']),
        'startsAt': istInputToIso('${f['startsAt']}'),
        'endsAt': istInputToIso('${f['endsAt']}'),
        'capacity': int.tryParse('${f['capacity']}'),
      };
      final api = ref.read(staffContentApiProvider);
      if (e == null) {
        await api.createInitiative(body);
      } else {
        await api.updateInitiative('${e['id']}', body);
      }
      ref.invalidate(staffInitiativesProvider);
      if (context.mounted) {
        showSaartheeToast(context, l10n.staffContentSaved);
        context.pop();
      }
      return null;
    }

    return StaffPage(
      title: e == null ? l10n.staffContentNewInitiative : s('titleEn'),
      roles: adminOnly,
      child: ContentForm(
        key: const Key('staff.initiativeForm'),
        submitLabel: l10n.staffContentSave,
        onSubmit: submit,
        rows: [
          [
            FieldSpec.text(
              'titleEn',
              l10n.staffContentFieldTitleEn,
              initial: s('titleEn'),
              validator: (x) => v.required(x, max: 100),
            ),
            FieldSpec.text(
              'titleGu',
              l10n.staffContentFieldTitleGu,
              initial: s('titleGu'),
              validator: (x) => v.required(x, max: 100),
            ),
          ],
          [
            FieldSpec.text(
              'descriptionEn',
              l10n.staffContentFieldDescriptionEn,
              initial: s('descriptionEn'),
              maxLines: 4,
              validator: v.required,
            ),
            FieldSpec.text(
              'descriptionGu',
              l10n.staffContentFieldDescriptionGu,
              initial: s('descriptionGu'),
              maxLines: 4,
              validator: v.required,
            ),
          ],
          [
            FieldSpec.text(
              'type',
              l10n.staffContentFieldType(_types.join(' / ')),
              initial: e == null ? 'cleanup' : s('type'),
              validator: (x) => oneOf(x, _types),
            ),
            FieldSpec.text(
              'organiser',
              l10n.staffContentFieldOrganiser(_organisers.join(' / ')),
              initial: e == null ? 'RWA' : s('organiser'),
              validator: (x) => oneOf(x, _organisers),
            ),
          ],
          [
            FieldSpec.text(
              'organiserName',
              l10n.staffContentFieldOrganiserName,
              initial: s('organiserName'),
              validator: (x) => v.required(x, max: 100),
            ),
            FieldSpec.text(
              'sourceUrl',
              l10n.staffContentFieldSourceUrl,
              initial: s('sourceUrl'),
              validator: v.optionalHttps,
            ),
          ],
          [
            FieldSpec.text(
              'locationTextEn',
              l10n.staffContentFieldPlaceEn,
              initial: s('locationTextEn'),
              validator: (x) => v.required(x, max: 200),
            ),
            FieldSpec.text(
              'locationTextGu',
              l10n.staffContentFieldPlaceGu,
              initial: s('locationTextGu'),
              validator: (x) => v.required(x, max: 200),
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
              'lat',
              l10n.staffContentFieldLat,
              initial: s('lat'),
              keyboardType: TextInputType.number,
            ),
            FieldSpec.text(
              'lng',
              l10n.staffContentFieldLng,
              initial: s('lng'),
              keyboardType: TextInputType.number,
            ),
          ],
          [
            FieldSpec.text(
              'startsAt',
              l10n.staffContentFieldStart,
              initial: isoToIstInput(s('startsAt')),
              validator: v.dateTime,
            ),
            FieldSpec.text(
              'endsAt',
              l10n.staffContentFieldEnd,
              initial: isoToIstInput(s('endsAt')),
              validator: v.dateTime,
            ),
          ],
          [
            FieldSpec.text(
              'capacity',
              l10n.staffContentFieldCapacity,
              initial: s('capacity'),
              keyboardType: TextInputType.number,
              validator: (x) => v.wholeNumber(x, optional: true),
            ),
          ],
        ],
      ),
    );
  }
}

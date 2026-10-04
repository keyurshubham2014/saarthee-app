import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_api.dart';
import '../shared/staff_shared.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';
import 'staff_category_models.dart';

/// Categories (TASK-10 §5.4): the 14 categories with a badge preview; edit
/// names gu/en, icon, DS §2 colour token, SLA days, sensitive, active, order.
class StaffCategoriesScreen extends ConsumerWidget {
  const StaffCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = SaartheeColors.of(context);
    return StaffPageScaffold(
      title: l10n.staffCategoriesTitle,
      body: StaffAsync<StaffCategories>(
        value: ref.watch(staffCategoriesProvider),
        onRetry: () => ref.invalidate(staffCategoriesProvider),
        builder: (data) => ListView(
          children: [
            for (final cat in data.items)
              Opacity(
                opacity: cat.isActive ? 1 : 0.6,
                child: ListRow(
                  key: Key('staff.categories.${cat.slug}'),
                  leading: CategoryBadge(slug: cat.slug),
                  title: cat.name(lang),
                  subtitle:
                      '${cat.slug} · ${l10n.staffCategoriesDays(cat.slaDays)}',
                  trailing: cat.isActive
                      ? null
                      : ToneChip(
                          tone: IssueStatusStyle.styles[IssueStatus.reported]!,
                          label: l10n.staffCategoriesInactive,
                        ),
                  onTap: () => showStaffDialog<void>(
                    context,
                    (_) => _EditCategory(category: cat, options: data),
                  ),
                ),
              ),
            Divider(height: 1, color: c.border),
          ],
        ),
      ),
    );
  }
}

class _EditCategory extends ConsumerStatefulWidget {
  const _EditCategory({required this.category, required this.options});

  final StaffCategory category;
  final StaffCategories options;

  @override
  ConsumerState<_EditCategory> createState() => _EditCategoryState();
}

class _EditCategoryState extends ConsumerState<_EditCategory> {
  late final _en = TextEditingController(text: widget.category.nameEn);
  late final _gu = TextEditingController(text: widget.category.nameGu);
  late final _sla = TextEditingController(text: '${widget.category.slaDays}');
  late final _order = TextEditingController(
    text: '${widget.category.sortOrder}',
  );
  late String _icon = widget.category.icon;
  late String _colour = widget.category.colourToken;
  late bool _sensitive = widget.category.sensitive;
  late bool _active = widget.category.isActive;
  bool _saving = false;
  bool _tried = false;

  @override
  void dispose() {
    for (final c in [_en, _gu, _sla, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nameError(AppLocalizations l10n, String v) =>
      v.trim().length < 2 || v.trim().length > 60
      ? l10n.staffCategoriesNameError
      : null;
  String? _intError(String v, int min, int max, String message) {
    final n = int.tryParse(v.trim());
    return n == null || n < min || n > max ? message : null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final errors = [
      _nameError(l10n, _en.text),
      _nameError(l10n, _gu.text),
      _intError(_sla.text, 1, 90, l10n.staffCategoriesSlaError),
      _intError(_order.text, 0, 999, l10n.staffCategoriesOrderError),
    ];
    if (errors.any((e) => e != null)) return;
    setState(() => _saving = true);
    try {
      await ref.read(staffApiProvider).patchCategory(
        widget.category.id,
        <String, dynamic>{
          'nameEn': _en.text.trim(),
          'nameGu': _gu.text.trim(),
          'icon': _icon,
          'colourToken': _colour,
          'slaDays': int.parse(_sla.text.trim()),
          'sensitive': _sensitive,
          'isActive': _active,
          'sortOrder': int.parse(_order.text.trim()),
        },
      );
      ref.invalidate(staffCategoriesProvider);
      if (!mounted) return;
      showStaffToast(context, l10n.staffDone);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showStaffToast(context, staffErrorText(l10n, e), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    InputDecoration deco(String label, String? error) =>
        InputDecoration(labelText: label, errorText: _tried ? error : null);
    return Dialog(
      key: const Key('staff.categoryDialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.staffCategoriesEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                key: const Key('staff.cat.nameEn'),
                controller: _en,
                decoration: deco(
                  l10n.staffCategoriesNameEn,
                  _nameError(l10n, _en.text),
                ),
              ),
              TextField(
                key: const Key('staff.cat.nameGu'),
                controller: _gu,
                decoration: deco(
                  l10n.staffCategoriesNameGu,
                  _nameError(l10n, _gu.text),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: widget.options.icons.contains(_icon)
                    ? _icon
                    : null,
                decoration: InputDecoration(
                  labelText: l10n.staffCategoriesIcon,
                ),
                items: [
                  for (final i in widget.options.icons)
                    DropdownMenuItem(value: i, child: Text(i)),
                ],
                onChanged: (v) => setState(() => _icon = v ?? _icon),
              ),
              DropdownButtonFormField<String>(
                initialValue: widget.options.colourTokens.contains(_colour)
                    ? _colour
                    : null,
                decoration: InputDecoration(
                  labelText: l10n.staffCategoriesColour,
                ),
                items: [
                  for (final t in widget.options.colourTokens)
                    DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          CategoryBadge(
                            slug: t.replaceFirst('category.', ''),
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(t),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _colour = v ?? _colour),
              ),
              TextField(
                key: const Key('staff.cat.sla'),
                controller: _sla,
                keyboardType: TextInputType.number,
                decoration: deco(
                  l10n.staffCategoriesSla,
                  _intError(_sla.text, 1, 90, l10n.staffCategoriesSlaError),
                ),
              ),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: deco(
                  l10n.staffCategoriesOrder,
                  _intError(
                    _order.text,
                    0,
                    999,
                    l10n.staffCategoriesOrderError,
                  ),
                ),
              ),
              SwitchListTile(
                value: _sensitive,
                title: Text(l10n.staffCategoriesSensitive),
                onChanged: (v) => setState(() => _sensitive = v),
              ),
              SwitchListTile(
                value: _active,
                title: Text(l10n.staffCategoriesActive),
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.staffCancel),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  FilledButton(
                    key: const Key('staff.cat.save'),
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.staffSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/admin_complaints.dart';
import '../../application/admin_reference.dart';
import '../../data/admin_api_error.dart';
import '../../data/models/reference_data.dart';
import '../admin_format.dart';
import '../admin_l10n.dart';
import '../shell/admin_session_guard.dart';
import '../widgets/admin_tokens.dart';
import '../widgets/admin_widgets.dart';

/// `/admin/categories` (02 §4.22, TASK-09).
class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  /// Local order while a reorder is being saved.
  List<AdminCategory>? _pending;
  final Set<String> _busy = <String>{};

  bool get _saving => _pending != null;

  Future<void> _reorder(List<AdminCategory> items, int from, int to) async {
    final l10n = adminL10n(context);
    if (_saving) {
      return;
    }
    final next = [...items];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() => _pending = next);
    try {
      await ref.read(adminReferenceActionsProvider).reorderCategories(next);
      if (mounted) {
        showAdminSnack(context, l10n.adminSaved);
      }
    } on AdminApiError catch (e) {
      if (mounted && !e.isSessionEnded) {
        showAdminSnack(context, l10n.adminReorderFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _pending = null);
      }
    }
  }

  Future<void> _toggle(AdminCategory c) async {
    final l10n = adminL10n(context);
    setState(() => _busy.add(c.id));
    try {
      await ref
          .read(adminReferenceActionsProvider)
          .updateCategory(c.id, isActive: !c.isActive);
      if (mounted) {
        showAdminSnack(context, l10n.adminSaved);
      }
    } on AdminApiError catch (e) {
      if (mounted && !e.isSessionEnded) {
        showAdminSnack(context, adminErrorMessage(l10n, e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(c.id));
      }
    }
  }

  Future<void> _edit(AdminCategory? c, int nextSort) async {
    final l10n = adminL10n(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _CategorySheet(category: c, defaultSort: nextSort),
    );
    if (saved == true && mounted) {
      showAdminSnack(context, l10n.adminSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final tokens = AdminTokens.of(context);
    final categories = ref.watch(adminCategoriesProvider);
    final items = _pending ?? categories.value;
    final nextSort = items == null || items.isEmpty
        ? 10
        : items.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 10;

    final note = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: AdminMessageBanner(
        message: l10n.adminCategoriesPlaceholderNote,
        icon: SaartheeIcons.info,
        isError: false,
      ),
    );

    Widget body;
    if (items != null) {
      body = items.isEmpty
          ? ListView(
              children: <Widget>[
                note,
                AdminEmptyState(
                  icon: SaartheeIcons.category,
                  message: l10n.adminCategoriesEmpty,
                  actionLabel: l10n.adminAddCategory,
                  onAction: () => _edit(null, nextSort),
                ),
              ],
            )
          : ReorderableListView.builder(
              header: note,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              onReorderItem: (from, to) => _reorder(items, from, to),
              itemBuilder: (context, i) {
                final c = items[i];
                final busy = _busy.contains(c.id) || _saving;
                return ListTile(
                  key: ValueKey<String>(c.id),
                  minTileHeight: 64,
                  leading: ReorderableDragStartListener(
                    index: i,
                    enabled: !_saving,
                    child: const Icon(SaartheeIcons.dragHandle),
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    [
                      if (c.ccrsLabel != null) c.ccrsLabel!,
                      c.isActive ? l10n.adminActive : l10n.adminInactive,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.isActive ? tokens.textMuted : tokens.notFixed,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: l10n.adminMoreActions,
                    enabled: !busy,
                    onSelected: (action) {
                      switch (action) {
                        case 'up':
                          _reorder(items, i, i - 1);
                        case 'down':
                          _reorder(items, i, i + 1);
                        case 'edit':
                          _edit(c, nextSort);
                        case 'toggle':
                          _toggle(c);
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      if (i > 0)
                        PopupMenuItem<String>(
                          value: 'up',
                          child: Text(l10n.adminMoveUp),
                        ),
                      if (i < items.length - 1)
                        PopupMenuItem<String>(
                          value: 'down',
                          child: Text(l10n.adminMoveDown),
                        ),
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text(l10n.adminEdit),
                      ),
                      PopupMenuItem<String>(
                        value: 'toggle',
                        child: Text(
                          c.isActive
                              ? l10n.adminDeactivate
                              : l10n.adminActivate,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
    } else if (categories.hasError) {
      body = ListView(
        children: <Widget>[
          AdminErrorView(
            title: l10n.adminCategoriesLoadFailed,
            error: asAdminError(categories.error!),
            onRetry: () => ref.invalidate(adminCategoriesProvider),
          ),
        ],
      );
    } else {
      body = const AdminSkeletonList(height: 64);
    }

    return AdminSessionGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.adminCategoriesTitle)),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('adminAddCategory'),
          onPressed: _saving ? null : () => _edit(null, nextSort),
          icon: const Icon(SaartheeIcons.add),
          label: Text(l10n.adminAddCategory),
        ),
        body: SafeArea(child: AdminContentWidth(child: body)),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.category, required this.defaultSort});
  final AdminCategory? category;
  final int defaultSort;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _ccrs = TextEditingController(text: widget.category?.ccrsLabel);
  late final _sort = TextEditingController(
    text: '${widget.category?.sortOrder ?? widget.defaultSort}',
  );
  bool _busy = false;
  String? _nameError;
  AdminApiError? _error;

  @override
  void dispose() {
    _name.dispose();
    _ccrs.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = adminL10n(context);
    setState(() {
      _nameError = null;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    final actions = ref.read(adminReferenceActionsProvider);
    final sort = int.parse(_sort.text.trim());
    try {
      final c = widget.category;
      if (c == null) {
        await actions.createCategory(
          name: _name.text,
          ccrsLabel: _ccrs.text,
          sortOrder: sort,
        );
      } else {
        await actions.updateCategory(
          c.id,
          name: _name.text,
          ccrsLabel: _ccrs.text,
          sortOrder: sort,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AdminApiError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (e.statusCode == 409) {
          _nameError = l10n.adminCategoryDuplicate;
        } else {
          _error = e;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.category == null
                    ? l10n.adminAddCategory
                    : l10n.adminEditCategory,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_error != null) ...<Widget>[
                AdminMessageBanner(message: adminErrorMessage(l10n, _error!)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('adminCategoryName'),
                controller: _name,
                enabled: !_busy,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l10n.adminCategoryNameLabel,
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  return t.isEmpty || t.length > 100
                      ? l10n.adminCategoryNameRequired
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('adminCategoryCcrs'),
                controller: _ccrs,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l10n.adminCategoryCcrsLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('adminCategorySort'),
                controller: _sort,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.adminCategorySortLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return n == null || n < 0
                      ? l10n.adminCategorySortInvalid
                      : null;
                },
              ),
              const SizedBox(height: 20),
              AdminPrimaryButton(
                key: const Key('adminCategorySubmit'),
                label: widget.category == null
                    ? l10n.adminCreate
                    : l10n.adminSave,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

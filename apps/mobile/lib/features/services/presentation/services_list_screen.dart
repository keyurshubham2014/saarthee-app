import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/services_providers.dart';
import '../data/service_models.dart';
import 'widgets/service_badges.dart';

/// `/services` (TASK-12 §5.4): independence banner, search, category chips
/// and the directory. Offline → last cached list with the offline banner.
class ServicesListScreen extends ConsumerStatefulWidget {
  const ServicesListScreen({super.key});

  @override
  ConsumerState<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends ConsumerState<ServicesListScreen> {
  final _search = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final async = ref.watch(servicesListProvider);

    Widget body() => async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => AppError.from(e).isOffline
          ? OfflineState(onRetry: () => ref.invalidate(servicesListProvider))
          : ErrorState(
              message: l10n.servicesLoadError,
              onRetry: () => ref.invalidate(servicesListProvider),
            ),
      data: (res) {
        final items = filterServices(
          res.value,
          category: _category,
          query: _search.text,
        );
        return ListView(
          key: const Key('services.list'),
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          children: [
            if (res.fromCache)
              NoticeBanner(
                key: const Key('services.offline'),
                kind: NoticeKind.offline,
                message: l10n.servicesOfflineCached,
              ),
            if (items.isEmpty)
              EmptyState(
                key: const Key('services.empty'),
                icon: SaartheeIcons.searchOff,
                message: l10n.servicesNoMatch(_search.text.trim()),
              )
            else
              for (final s in items)
                ServiceRow(
                  service: s,
                  lang: lang,
                  onTap: () => context.push('/services/${s.slug}'),
                ),
          ],
        );
      },
    );

    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.servicesTitle),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.s8,
              AppSpacing.gutter,
              0,
            ),
            child: NoticeBanner(
              key: const Key('services.independence'),
              kind: NoticeKind.independence,
              message: l10n.servicesIndependence,
              rounded: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: TextField(
              key: const Key('services.search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.servicesSearchHint,
                prefixIcon: const Icon(SaartheeIcons.search),
              ),
            ),
          ),
          SizedBox(
            height: AppSpacing.touchTarget + AppSpacing.s8,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              children: [
                for (final cat in <String?>[null, ...serviceCategories])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: AppFilterChip(
                      key: Key('services.chip.${cat ?? 'all'}'),
                      label: serviceCategoryLabel(l10n, cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: body()),
        ],
      ),
    );
  }
}

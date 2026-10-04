import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/ward_providers.dart';
import 'ward_reps_section.dart';

/// `/ward/:id` — another ward's representatives (TASK-09 §5.4). The My Ward
/// tab shows the home ward through the same [WardRepresentativesSection].
class WardScreen extends ConsumerWidget {
  const WardScreen({super.key, required this.wardId});

  final String wardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final ward = ref.watch(wardRepresentativesProvider(wardId)).value?.ward;
    final zone = lang == 'gu' ? ward?.zoneGu : ward?.zoneEn;
    return Scaffold(
      appBar: SaartheeAppBar(
        title: ward == null
            ? l10n.navMyWard
            : l10n.wardDisplayName(ward.number, ward.name(lang)),
        subtitle: zone == null ? null : l10n.wardZone(zone),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(wardRepresentativesProvider(wardId).future),
        child: ListView(
          children: [
            WardRepresentativesSection(wardId: wardId),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }
}

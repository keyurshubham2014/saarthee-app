import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../motion/count_up.dart';
import '../motion/pressable.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../utils/initials.dart';
import 'chips.dart';
import 'photos.dart';

/// Localized category name for a slug (DS §2, 14 slugs; unknown → Other).
String categoryLabel(AppLocalizations l10n, String slug) => switch (slug) {
  'roads' => l10n.categoryRoads,
  'water' => l10n.categoryWater,
  'drainage' => l10n.categoryDrainage,
  'garbage' => l10n.categoryGarbage,
  'streetlight' => l10n.categoryStreetlight,
  'trees' => l10n.categoryTrees,
  'animals' => l10n.categoryAnimals,
  'health' => l10n.categoryHealth,
  'toilets' => l10n.categoryToilets,
  'encroachment' => l10n.categoryEncroachment,
  'traffic' => l10n.categoryTraffic,
  'property' => l10n.categoryProperty,
  'building' => l10n.categoryBuilding,
  _ => l10n.categoryOther,
};

/// Category glyph in its colour on a 12% tint, in a 40 dp rounded square
/// (radius 14). Semantics = the category name.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.slug,
    this.size = AppSpacing.categoryBadge,
  });

  final String slug;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final style = CategoryStyle.of(slug);
    return Semantics(
      label: categoryLabel(AppLocalizations.of(context), slug),
      image: true,
      child: Container(
        key: ValueKey('categoryBadge.$slug'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.tint(c),
          borderRadius: AppRadii.controlRadius,
        ),
        child: Icon(style.icon, color: style.glyph(c), size: size * 0.55),
      ),
    );
  }
}

/// Stat tile (DS §5): `surfaceAlt`, radius 14, number (numeric, counting
/// up) and a bodySmall label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.animate = true,
  });

  final int value;
  final String label;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadii.controlRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CountUp(
            value: value,
            animate: animate,
            style: AppTypography.numeric(c),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// List row (DS §5): ≥ 56 dp (72 two-line), leading slot (40 dp badge),
/// trailing chip or chevron, whole row tappable.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: NeemFixed.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.s8,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: text.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  trailing!,
                ] else if (onTap != null && showChevron)
                  Icon(SaartheeIcons.chevronRight, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Issue card (DS §5): radius 18, 1 px border + soft shadow, 4:3 photo,
/// category badge, title (Mukta Vaani titleMedium), "Ward · age", status
/// chip, "Me too" count, overdue tag. Data is passed in (no API here).
class IssueCard extends StatelessWidget {
  const IssueCard({
    super.key,
    required this.title,
    required this.categorySlug,
    required this.wardAndAge,
    required this.status,
    this.meTooCount = 0,
    this.overdue = false,
    this.photo,
    this.photoLabel,
    this.onTap,
    this.heroId,
  });

  /// TASK-07: with an issue id, the photo and title carry the
  /// `issue-photo-<id>` / `issue-title-<id>` Hero tags (card → detail, DS §6).
  final String? heroId;

  final String title;
  final String categorySlug;
  final String wardAndAge;
  final IssueStatus status;
  final int meTooCount;
  final bool overdue;
  final ImageProvider? photo;
  final String? photoLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      enabled: onTap != null,
      child: Container(
        decoration: AppElevation.cardDecoration(c),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: NeemFixed.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photo != null || photoLabel != null)
                  _maybeHero(
                    heroId == null ? null : 'issue-photo-$heroId',
                    PhotoThumb(
                      image: photo,
                      semanticLabel: photoLabel ?? title,
                      radius: 0,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategoryBadge(slug: categorySlug),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _maybeHero(
                                  heroId == null ? null : 'issue-title-$heroId',
                                  Material(
                                    type: MaterialType.transparency,
                                    child: Text(title, style: text.titleMedium),
                                  ),
                                ),
                                Text(wardAndAge, style: text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(status: status),
                          if (overdue) const OverdueTag(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                SaartheeIcons.thumbUp,
                                size: AppSpacing.iconSmall,
                                color: c.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                l10n.componentMeTooCount(meTooCount),
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _maybeHero(String? tag, Widget child) =>
    tag == null ? child : Hero(tag: tag, child: child);

/// One step of a [StatusTimeline].
class TimelineStep {
  const TimelineStep({
    required this.status,
    this.actor,
    this.date,
    this.isFuture = false,
    this.extra,
  });

  final IssueStatus status;
  final String? actor;
  final String? date;
  final bool isFuture;

  /// After-photo and "Yes, fixed" / "Still not fixed" slot.
  final Widget? extra;
}

/// Vertical stepper (DS §5): 14 dp dots in the status colour, actor and
/// date per step, future steps hollow grey.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: AppSpacing.s24,
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.s4),
                      Container(
                        key: ValueKey('timeline.dot.$i'),
                        width: AppSpacing.timelineDot,
                        height: AppSpacing.timelineDot,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].isFuture
                              ? NeemFixed.transparent
                              : IssueStatusStyle.of(steps[i].status).solid,
                          border: steps[i].isFuture
                              ? Border.all(color: c.borderStrong, width: 2)
                              : null,
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(child: Container(width: 2, color: c.border)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issueStatusLabel(l10n, steps[i].status),
                          style: text.titleMedium?.copyWith(
                            color: steps[i].isFuture ? c.textSecondary : null,
                          ),
                        ),
                        if (steps[i].actor != null || steps[i].date != null)
                          Text(
                            [?steps[i].actor, ?steps[i].date].join(' · '),
                            style: text.bodySmall,
                          ),
                        if (steps[i].extra != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          steps[i].extra!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Alert card (DS §5): tint of the severity, severity icon + word, title,
/// area, validity, source line. No side bar. Critical = solid banner with
/// white text.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.severity,
    required this.title,
    required this.area,
    required this.validity,
    required this.source,
    this.onTap,
  });

  final AlertSeverity severity;
  final String title;
  final String area;
  final String validity;
  final String source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final tone = AlertSeverityStyle.of(severity);
    final critical = severity == AlertSeverity.critical;
    final bg = critical ? tone.solid : (c.isDark ? c.surfaceAlt : tone.tint);
    final fg = critical ? NeemFixed.white : c.textPrimary;
    final accent = critical
        ? NeemFixed.white
        : (c.isDark ? tone.tint : tone.solid);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        key: ValueKey('alertCard.${severity.name}'),
        color: bg,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(tone.icon, color: accent, size: AppSpacing.iconSmall),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      alertSeverityLabel(l10n, severity),
                      style: text.labelMedium?.copyWith(color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(title, style: text.titleMedium?.copyWith(color: fg)),
                const SizedBox(height: AppSpacing.s4),
                Text(area, style: text.bodyMedium?.copyWith(color: fg)),
                Text(validity, style: text.bodySmall?.copyWith(color: fg)),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  l10n.componentAlertSource(source),
                  style: text.bodySmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Representative row (DS §5): initials avatar, name, role, ward, party as
/// plain text, "Message" button (callback only). Never a personal number.
class RepresentativeRow extends StatelessWidget {
  const RepresentativeRow({
    super.key,
    required this.name,
    required this.role,
    required this.ward,
    this.party,
    this.onMessage,
  });

  final String name;
  final String role;
  final String ward;
  final String? party;
  final VoidCallback? onMessage;

  String get _initials => initialsOf(name);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final message = onMessage == null
        ? null
        : OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(SaartheeIcons.message, size: AppSpacing.iconSmall),
            label: Text(l10n.componentMessage),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                AppSpacing.touchTarget,
                AppSpacing.touchTarget,
              ),
            ),
          );
    // Large text (≥ 1.5×, DS §7): the button moves under the name so the
    // name column keeps its width instead of the row overflowing.
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: text.titleMedium),
        Text([role, ward, ?party].join(' · '), style: text.bodySmall),
        if (stacked && message != null) ...[
          const SizedBox(height: AppSpacing.s8),
          message,
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: c.primaryContainer,
              child: Text(
                _initials,
                style: text.titleMedium?.copyWith(color: c.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: details),
          if (!stacked && message != null) message,
        ],
      ),
    );
  }
}

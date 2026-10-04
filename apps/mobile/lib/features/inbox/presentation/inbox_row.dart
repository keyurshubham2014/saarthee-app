import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/alerts/validity_format.dart';
import '../data/inbox_models.dart';

/// Row compress scale during swipe-to-read (DS §6 Inbox).
const double inboxRowCompressScale = 0.97;

/// One inbox row (REQ-F-040/065): unread rows bold with a `primary` dot.
/// Swiping end-to-start past the threshold marks it read: the row compresses
/// (`instant`) and springs back (`springIn`), stays in the list, the dot fades
/// and the title weight cross-fades (`short`). TalkBack: "Mark as read".
class InboxRow extends StatefulWidget {
  const InboxRow({
    super.key,
    required this.item,
    required this.lang,
    required this.onOpen,
    required this.onMarkRead,
  });

  final InboxItem item;
  final String lang;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;

  @override
  State<InboxRow> createState() => InboxRowState();
}

class InboxRowState extends State<InboxRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController compress = AnimationController(vsync: this);

  Future<void> _compressAndSpring() async {
    final motion = SaartheeMotion.of(context);
    if (!motion.transforms) return;
    compress.duration = motion.instant.duration;
    await compress.forward(from: 0);
    if (!mounted) return;
    compress.duration = motion.springIn.duration;
    await compress.reverse();
  }

  void _swiped() {
    if (!widget.item.unread) return;
    widget.onMarkRead();
    _compressAndSpring();
  }

  @override
  void dispose() {
    compress.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.item.kind) {
    'alert' => SaartheeIcons.navAlerts,
    'issue_update' => SaartheeIcons.statusInProgress,
    'initiative' => SaartheeIcons.group,
    _ => SaartheeIcons.notifications,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final motion = SaartheeMotion.of(context);
    final unread = widget.item.unread;
    final row = InkWell(
      onTap: widget.onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: c.textSecondary),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: motion.short.duration,
                    curve: motion.short.curve,
                    style: (text.titleSmall ?? const TextStyle()).copyWith(
                      color: c.textPrimary,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                    ),
                    child: Text(widget.item.title),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    widget.item.body,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatInboxTime(widget.lang, widget.item.createdAt),
                  style: text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.s8),
                AnimatedOpacity(
                  key: ValueKey('inboxDot.${widget.item.id}'),
                  opacity: unread ? 1 : 0,
                  duration: motion.short.duration,
                  curve: motion.short.curve,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: c.primary,
                      shape: const CircleBorder(),
                    ),
                    child: const SizedBox.square(dimension: AppSpacing.s8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: unread ? l10n.inboxUnread : null,
      customSemanticsActions: unread
          ? {
              CustomSemanticsAction(label: l10n.inboxMarkRead):
                  widget.onMarkRead,
            }
          : const {},
      child: Dismissible(
        key: ValueKey('inboxRow.${widget.item.id}'),
        direction: DismissDirection.endToStart,
        movementDuration: motion.short.duration,
        background: ColoredBox(color: c.surfaceAlt),
        confirmDismiss: (_) async {
          _swiped();
          return false;
        },
        child: AnimatedBuilder(
          animation: compress,
          builder: (context, child) => Transform.scale(
            scale: 1 - (1 - inboxRowCompressScale) * compress.value,
            child: child,
          ),
          child: ColoredBox(color: c.surface, child: row),
        ),
      ),
    );
  }
}

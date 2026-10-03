import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../admin_l10n.dart';
import '../../data/admin_api_error.dart';
import '../../data/models/complaint_summary.dart';
import '../admin_format.dart';
import 'admin_tokens.dart';

/// Screen padding (02 §2.1: 20 horizontal on phones).
const EdgeInsets adminScreenPadding = EdgeInsets.symmetric(
  horizontal: 20,
  vertical: 16,
);

/// Max content width for large screens (02 §2.2).
class AdminContentWidth extends StatelessWidget {
  const AdminContentWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
}

/// Full-width primary action with in-button progress (02 §9.3).
class AdminPrimaryButton extends StatelessWidget {
  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
        onPressed: busy ? null : onPressed,
        child: busy
            ? Semantics(
                label: label,
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

/// Secondary full-width action.
class AdminSecondaryButton extends StatelessWidget {
  const AdminSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
      onPressed: busy ? null : onPressed,
      child: busy
          ? Semantics(
              label: label,
              child: const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    ),
  );
}

/// Centered icon + message + optional action.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error message (keyed by backend code) with a Retry button.
class AdminErrorView extends StatelessWidget {
  const AdminErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title,
  });

  final AdminApiError error;
  final VoidCallback onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            error.isNetwork ? SaartheeIcons.offline : SaartheeIcons.error,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          Text(
            adminErrorMessage(l10n, error),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onRetry,
            icon: const Icon(SaartheeIcons.refresh),
            label: Text(l10n.adminRetry),
          ),
        ],
      ),
    );
  }
}

/// Inline error banner (also announced to screen readers).
class AdminMessageBanner extends StatefulWidget {
  const AdminMessageBanner({
    super.key,
    required this.message,
    this.icon = SaartheeIcons.error,
    this.isError = true,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  State<AdminMessageBanner> createState() => _AdminMessageBannerState();
}

class _AdminMessageBannerState extends State<AdminMessageBanner> {
  @override
  void initState() {
    super.initState();
    _announce();
  }

  @override
  void didUpdateWidget(AdminMessageBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _announce();
    }
  }

  void _announce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.message,
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = adminL10n(context);
    final background = widget.isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = widget.isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(widget.icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.message, style: TextStyle(color: foreground)),
            ),
            if (widget.onRetry != null)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: foreground,
                ),
                onPressed: widget.onRetry,
                child: Text(l10n.adminRetry),
              ),
          ],
        ),
      ),
    );
  }
}

/// Status chip: colour + icon + word (02 §2.1).
class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});
  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final tokens = AdminTokens.of(context);
    final (IconData icon, Color bg, Color fg) = switch (status) {
      ComplaintStatus.verifiedFixed => (
        SaartheeIcons.success,
        tokens.fixedTint,
        tokens.fixed,
      ),
      ComplaintStatus.verifiedNotFixed => (
        SaartheeIcons.cancel,
        tokens.notFixedTint,
        tokens.notFixed,
      ),
      ComplaintStatus.reminded => (
        SaartheeIcons.hourglass,
        tokens.waitingTint,
        tokens.ink,
      ),
      ComplaintStatus.filed => (
        SaartheeIcons.description,
        tokens.neutralTint,
        tokens.ink,
      ),
    };
    return AdminTag(
      icon: icon,
      label: statusLabel(l10n, status),
      background: bg,
      foreground: fg,
    );
  }
}

/// Small rounded tag with icon and word.
class AdminTag extends StatelessWidget {
  const AdminTag({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: foreground),
          ),
        ),
      ],
    ),
  );
}

/// Grey placeholder rows while a list loads (02 §9.3).
class AdminSkeletonList extends StatelessWidget {
  const AdminSkeletonList({super.key, this.count = 5, this.height = 112});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: adminScreenPadding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => ExcludeSemantics(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Authenticated photo loaded through a bytes provider.
class AdminPhoto extends ConsumerWidget {
  const AdminPhoto({
    super.key,
    required this.provider,
    required this.semanticLabel,
    this.size,
    this.aspectRatio = 1,
  });

  final ProviderListenable<AsyncValue<Uint8List>> provider;
  final String semanticLabel;
  final double? size;
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final scheme = Theme.of(context).colorScheme;
    final photo = ref.watch(provider);
    Widget placeholder(IconData icon, String? text) => Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: scheme.onSurfaceVariant),
          if (text != null && (size == null || size! > 96))
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
    final child = photo.when(
      data: (bytes) => Image.memory(
        bytes,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            placeholder(SaartheeIcons.brokenImage, l10n.adminPhotoUnavailable),
      ),
      loading: () => placeholder(SaartheeIcons.image, null),
      error: (e, _) {
        final deleted =
            e is AdminApiError && e.code == AdminErrorCodes.photoDeleted;
        return Semantics(
          label: deleted ? l10n.adminErrorPhotoDeleted : semanticLabel,
          child: placeholder(
            deleted ? SaartheeIcons.hideImage : SaartheeIcons.brokenImage,
            deleted ? l10n.adminErrorPhotoDeleted : l10n.adminPhotoUnavailable,
          ),
        );
      },
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(size != null ? 12 : 16),
      child: child,
    );
    if (size != null) {
      return SizedBox.square(dimension: size, child: clipped);
    }
    return AspectRatio(aspectRatio: aspectRatio, child: clipped);
  }
}

/// Photo placeholder when a complaint has no photo or it was removed.
class AdminPhotoPlaceholder extends StatelessWidget {
  const AdminPhotoPlaceholder({
    super.key,
    required this.label,
    this.icon = SaartheeIcons.imageMissing,
    this.size,
  });

  final String label;
  final IconData icon;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size != null ? 12 : 16),
        child: Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: scheme.onSurfaceVariant),
              if (size == null || size! > 96)
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
    if (size != null) {
      return SizedBox.square(dimension: size, child: box);
    }
    return AspectRatio(aspectRatio: 1, child: box);
  }
}

/// Shows a snackbar with [message].
void showAdminSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

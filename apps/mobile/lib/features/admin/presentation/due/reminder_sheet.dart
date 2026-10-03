import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_l10n.dart';
import '../../application/admin_complaints.dart';
import '../../data/admin_api_error.dart';
import '../../data/models/reminder_result.dart';
import '../admin_format.dart';
import '../widgets/admin_widgets.dart';

/// Click-to-chat URL `https://wa.me/<digits>?text=<urlencoded>`
/// (ASSUMPTION per TASK-06 §5.6; PRD Q8).
Uri whatsAppUri(String phoneE164, String message) {
  final digits = phoneE164.replaceAll(RegExp(r'[^0-9]'), '');
  // Without a number, wa.me lets the operator pick the chat.
  final target = digits.isEmpty ? '' : digits;
  return Uri.parse(
    'https://wa.me/$target?text=${Uri.encodeComponent(message)}',
  );
}

/// Sends a reminder for [complaintId] and opens the reminder sheet.
/// Errors are shown as a snackbar keyed by backend code. Afterwards the
/// complaint lists, badge and detail are refreshed.
Future<void> sendReminderFlow(
  BuildContext context,
  WidgetRef ref,
  String complaintId,
) async {
  final l10n = adminL10n(context);
  final messenger = ScaffoldMessenger.of(context);
  ReminderResult? result;
  try {
    result = await ref.read(reminderSenderProvider.notifier).send(complaintId);
  } on AdminApiError catch (e) {
    if (e.isSessionEnded) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(adminErrorMessage(l10n, e)),
          action: e.isNetwork
              ? SnackBarAction(
                  label: l10n.adminRetry,
                  onPressed: () {
                    if (context.mounted) {
                      sendReminderFlow(context, ref, complaintId);
                    }
                  },
                )
              : null,
        ),
      );
    return;
  }
  if (result == null || !context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReminderSheet(result: result!),
  );
  refreshComplaintData(ref.invalidate, complaintId: complaintId);
}

/// Bottom sheet with the message preview, "Open WhatsApp" and "Copy message"
/// (02 §4.18). The message and phone stay in memory only.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, required this.result});
  final ReminderResult result;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  bool _whatsAppFailed = false;

  Future<void> _openWhatsApp() async {
    final uri = whatsAppUri(widget.result.phoneE164, widget.result.messageText);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
    if (!opened && mounted) {
      setState(() => _whatsAppFailed = true);
    }
  }

  Future<void> _copy() async {
    final l10n = adminL10n(context);
    await Clipboard.setData(ClipboardData(text: widget.result.messageText));
    if (mounted) {
      showAdminSnack(context, l10n.adminCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final r = widget.result;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.adminReminderSheetTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (r.phoneE164.isNotEmpty)
            Text(
              l10n.adminReminderTo(formatPhone(r.phoneE164)),
              style: theme.textTheme.titleMedium,
            ),
          const SizedBox(height: 16),
          Text(
            l10n.adminReminderMessageLabel,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              r.messageText,
              key: const Key('adminReminderMessageText'),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.adminReminderLinkLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(
            r.verifyLink,
            key: const Key('adminReminderLinkText'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          if (_whatsAppFailed) ...<Widget>[
            AdminMessageBanner(message: l10n.adminWhatsAppFailed),
            const SizedBox(height: 12),
          ],
          AdminPrimaryButton(
            key: const Key('adminOpenWhatsApp'),
            icon: SaartheeIcons.chat,
            label: l10n.adminOpenWhatsApp,
            onPressed: _openWhatsApp,
          ),
          const SizedBox(height: 12),
          AdminSecondaryButton(
            key: const Key('adminCopyMessage'),
            icon: SaartheeIcons.copy,
            label: l10n.adminCopyMessage,
            onPressed: _copy,
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.adminClose),
          ),
        ],
      ),
    );
  }
}

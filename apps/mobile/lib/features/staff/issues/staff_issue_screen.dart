import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../shared/staff_shared.dart';
import 'staff_issue_panel.dart';

/// `/staff/issues/:id` — issue tools as a page (phones, deep links).
class StaffIssueScreen extends StatelessWidget {
  const StaffIssueScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => StaffPageScaffold(
    title: AppLocalizations.of(context).staffIssueTitle,
    body: StaffIssuePanel(
      issueId: id,
      onHandled: () {
        final router = GoRouter.of(context);
        if (router.canPop()) router.pop();
      },
    ),
  );
}

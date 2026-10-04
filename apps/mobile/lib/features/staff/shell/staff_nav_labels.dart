import '../../../core/l10n/app_localizations.dart';
import '../shared/staff_shared.dart';

/// Resolves a `StaffNavItem.labelKey` (TASK-08/10/12 keys) to its text.
String staffNavLabel(AppLocalizations l10n, String key) => switch (key) {
  'staffNavDashboard' => l10n.staffNavDashboard,
  'staffNavModeration' => l10n.staffNavModeration,
  'staffAlertsTitle' => l10n.staffAlertsTitle,
  'staffContentServicesTitle' => l10n.staffContentServicesTitle,
  'staffContentInitiativesTitle' => l10n.staffContentInitiativesTitle,
  'staffContentTipsTitle' => l10n.staffContentTipsTitle,
  'staffNavCategories' => l10n.staffNavCategories,
  'staffNavUsers' => l10n.staffNavUsers,
  'staffNavSettings' => l10n.staffNavSettings,
  'staffNavExports' => l10n.staffNavExports,
  // TASK-11.
  'wardDashNav' => l10n.wardDashNav,
  'wardDashIssuesNav' => l10n.wardDashIssuesNav,
  'repMsgNav' => l10n.repMsgNav,
  'repClaimNav' => l10n.repClaimNav,
  _ => key,
};

String staffSectionLabel(AppLocalizations l10n, StaffNavSection s) =>
    switch (s) {
      StaffNavSection.work => l10n.staffNavSectionWork,
      StaffNavSection.content => l10n.staffNavSectionContent,
      StaffNavSection.admin => l10n.staffNavSectionAdmin,
    };

String staffRoleLabel(AppLocalizations l10n, String role) => switch (role) {
  'admin' => l10n.staffRoleAdmin,
  'moderator' => l10n.staffRoleModerator,
  'representative' => l10n.staffRoleRepresentative,
  _ => l10n.staffRoleCitizen,
};

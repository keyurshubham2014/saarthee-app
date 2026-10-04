import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/chips.dart';
import '../data/issue_models.dart';

/// One row of the lifecycle timeline (DS §5 status timeline).
class TimelineRow {
  const TimelineRow({
    required this.id,
    required this.status,
    required this.title,
    this.actor,
    this.date,
    this.photoUrl,
  });

  /// Event id: rows are diffed by it so only new ones animate.
  final String id;

  /// Dot colour (the status at that moment).
  final IssueStatus status;
  final String title;
  final String? actor, date, photoUrl;
}

/// Privacy-safe actor text (TASK-06 §5.4): "A resident of Paldi",
/// "Ward corporator `name`", "Saarthee moderator", "Saarthee".
String timelineActor(AppLocalizations l10n, IssueEventItem e, bool gu) {
  final ward = (gu ? e.wardNameGu : e.wardNameEn) ?? '';
  final name = (gu ? e.actorNameGu : e.actorNameEn) ?? '';
  return switch (e.actorKind) {
    'resident' => l10n.issueActionsActorResident(ward).trim(),
    'representative' when e.repRole == 'corporator' =>
      l10n.issueActionsActorCorporator(name).trim(),
    'representative' => l10n.issueActionsActorRepresentative(name).trim(),
    'moderator' => l10n.issueActionsActorModerator,
    _ => l10n.issueActionsActorSystem,
  };
}

/// Maps events (oldest first) to rows. Status events show the status word;
/// verification, escalation, CCRS and overdue events show what happened in
/// the colour of the status at that time. Comments are not shown.
List<TimelineRow> timelineRows(
  AppLocalizations l10n,
  List<IssueEventItem> events, {
  required String localeName,
}) {
  final gu = localeName.startsWith('gu');
  var status = IssueStatus.reported;
  final rows = <TimelineRow>[];
  for (final e in events) {
    final isStatus =
        e.toStatus != null &&
        (e.type == 'status_change' ||
            e.type == 'rejected' ||
            e.type == 'merged');
    if (isStatus) status = issueStatusFromApi(e.toStatus);
    final String? title = isStatus
        ? issueStatusLabel(l10n, status)
        : switch (e.type) {
            'verification' =>
              e.answer == 'not_fixed'
                  ? l10n.issueActionsTimelineAnswerNotFixed
                  : l10n.issueActionsTimelineAnswerFixed,
            'escalated' => l10n.issueActionsTimelineEscalated,
            'ccrs_linked' => l10n.issueActionsTimelineCcrsLinked,
            'ccrs_closed' => l10n.issueActionsTimelineCcrsClosed,
            'system' when e.note == 'overdue' =>
              l10n.issueActionsTimelineOverdue,
            _ => null,
          };
    if (title == null) continue;
    rows.add(
      TimelineRow(
        id: e.id,
        status: status,
        title: title,
        actor: timelineActor(l10n, e, gu),
        date: e.createdAt == null
            ? null
            : Formatters.shortDate(e.createdAt!, localeName),
        photoUrl: isStatus && status == IssueStatus.markedFixed
            ? (e.photoUrls.isEmpty ? null : e.photoUrls.first)
            : null,
      ),
    );
  }
  return rows;
}

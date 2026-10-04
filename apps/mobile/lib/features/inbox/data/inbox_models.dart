import '../../../core/theme/tokens.dart';
import '../../alerts/data/alert_models.dart';

/// One row of `GET /me/notifications` (title/body already in the user's
/// language; alert rows carry the alert's live title and status).
class InboxItem {
  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.readAt,
    this.alertSeverity,
    this.alertStatus,
  });

  final String id;

  /// `alert`, `issue_update`, `initiative` or `system`.
  final String kind;
  final String? route;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final AlertSeverity? alertSeverity;
  final String? alertStatus;

  bool get unread => readAt == null;

  InboxItem markedRead(DateTime at) => InboxItem(
    id: id,
    kind: kind,
    route: route,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? at,
    alertSeverity: alertSeverity,
    alertStatus: alertStatus,
  );

  InboxItem markedUnread() => InboxItem(
    id: id,
    kind: kind,
    route: route,
    title: title,
    body: body,
    createdAt: createdAt,
    alertSeverity: alertSeverity,
    alertStatus: alertStatus,
  );

  factory InboxItem.fromJson(Map<String, dynamic> j) {
    final alert = (j['alert'] as Map?)?.cast<String, dynamic>();
    return InboxItem(
      id: j['id'] as String,
      kind: j['kind'] as String? ?? 'system',
      route: j['route'] as String?,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
      readAt: j['readAt'] == null
          ? null
          : DateTime.parse(j['readAt'] as String),
      alertSeverity: alert == null ? null : parseSeverity(alert['severity']),
      alertStatus: alert?['status'] as String?,
    );
  }
}

class InboxPage {
  const InboxPage({required this.items, required this.unreadCount});

  final List<InboxItem> items;
  final int unreadCount;

  factory InboxPage.fromJson(Map<String, dynamic> j) => InboxPage(
    items: [
      for (final i in (j['items'] as List? ?? const []))
        InboxItem.fromJson((i as Map).cast<String, dynamic>()),
    ],
    unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
  );
}

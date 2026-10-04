import '../../../core/theme/tokens.dart';

/// Server status string → the DS status (`sent` shows as Acknowledged;
/// `merged` as Reported with the merge banner on detail).
IssueStatus parseIssueStatus(String? s) => switch (s) {
  'sent' => IssueStatus.sent,
  'acknowledged' => IssueStatus.acknowledged,
  'in_progress' => IssueStatus.inProgress,
  'marked_fixed' => IssueStatus.markedFixed,
  'verified' => IssueStatus.verified,
  'reopened' => IssueStatus.reopened,
  'rejected' => IssueStatus.rejected,
  _ => IssueStatus.reported,
};

DateTime _date(Object? v) =>
    DateTime.tryParse(v as String? ?? '')?.toLocal() ?? DateTime(2026);

/// Card shape (feed, lists, map preview; TASK-07 §5.2). No reporter data.
class IssueCardData {
  const IssueCardData({
    required this.id,
    required this.title,
    required this.categorySlug,
    required this.status,
    required this.isOverdue,
    required this.createdAt,
    required this.meTooCount,
    this.displayStatus = '',
    this.wardNameEn,
    this.wardNameGu,
    this.thumbnailUrl,
    this.pendingReview = false,
  });

  factory IssueCardData.fromJson(Map<String, dynamic> j) => IssueCardData(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    categorySlug: j['categorySlug'] as String? ?? 'other',
    status: parseIssueStatus(j['status'] as String?),
    displayStatus: j['displayStatus'] as String? ?? '',
    isOverdue: j['isOverdue'] == true,
    wardNameEn: j['wardNameEn'] as String?,
    wardNameGu: j['wardNameGu'] as String?,
    createdAt: _date(j['createdAt']),
    meTooCount: (j['meTooCount'] as num?)?.toInt() ?? 0,
    thumbnailUrl: j['thumbnailUrl'] as String?,
    pendingReview: j['pendingReview'] == true,
  );

  final String id, title, categorySlug, displayStatus;
  final IssueStatus status;
  final bool isOverdue, pendingReview;
  final String? wardNameEn, wardNameGu, thumbnailUrl;
  final DateTime createdAt;
  final int meTooCount;

  String? wardName(String lang) => lang == 'gu' ? wardNameGu : wardNameEn;

  IssueCardData withMeTooCount(int n) => IssueCardData(
    id: id,
    title: title,
    categorySlug: categorySlug,
    status: status,
    displayStatus: displayStatus,
    isOverdue: isOverdue,
    wardNameEn: wardNameEn,
    wardNameGu: wardNameGu,
    createdAt: createdAt,
    meTooCount: n,
    thumbnailUrl: thumbnailUrl,
    pendingReview: pendingReview,
  );
}

/// One page of `GET /issues`.
class IssuePage {
  const IssuePage(this.items, this.nextCursor);

  factory IssuePage.fromJson(Map<String, dynamic> j) => IssuePage([
    for (final i in (j['items'] as List? ?? const []))
      IssueCardData.fromJson(Map<String, dynamic>.from(i as Map)),
  ], j['nextCursor'] as String?);

  final List<IssueCardData> items;
  final String? nextCursor;
}

/// `GET /issues/{id}` (public issue + viewer capabilities).
class IssueDetail {
  const IssueDetail({
    required this.id,
    required this.title,
    required this.categorySlug,
    required this.categoryNameEn,
    required this.categoryNameGu,
    required this.status,
    required this.displayStatus,
    required this.isOverdue,
    required this.slaDueAt,
    required this.createdAt,
    required this.meTooCount,
    required this.followerCount,
    required this.reportPhotos,
    required this.afterPhotos,
    required this.blurApplied,
    required this.viewer,
    this.wardNameEn,
    this.wardNameGu,
    this.wardId,
    this.description,
    this.mergedIntoId,
    this.rejectionReason,
    this.pendingReview = false,
    this.lat,
    this.lng,
  });

  factory IssueDetail.fromJson(Map<String, dynamic> body) {
    final j = Map<String, dynamic>.from(body['issue'] as Map);
    final cat = Map<String, dynamic>.from(j['category'] as Map? ?? const {});
    final ward = j['ward'] == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(j['ward'] as Map);
    final photos = Map<String, dynamic>.from(j['photos'] as Map? ?? const {});
    final loc = Map<String, dynamic>.from(j['location'] as Map? ?? const {});
    List<String> urls(String k) => [
      for (final u in (photos[k] as List? ?? const [])) u as String,
    ];
    return IssueDetail(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      categorySlug: cat['slug'] as String? ?? 'other',
      categoryNameEn: cat['nameEn'] as String? ?? '',
      categoryNameGu: cat['nameGu'] as String? ?? '',
      status: parseIssueStatus(j['status'] as String?),
      displayStatus: j['displayStatus'] as String? ?? '',
      isOverdue: j['isOverdue'] == true,
      slaDueAt: _date(j['slaDueAt']),
      createdAt: _date(j['createdAt']),
      meTooCount: (j['meTooCount'] as num?)?.toInt() ?? 0,
      followerCount: (j['followerCount'] as num?)?.toInt() ?? 0,
      reportPhotos: urls('report'),
      afterPhotos: [...urls('after'), ...urls('verification')],
      blurApplied: j['blurApplied'] == true,
      wardId: ward['id'] as String?,
      wardNameEn: ward['nameEn'] as String?,
      wardNameGu: ward['nameGu'] as String?,
      description: j['description'] as String?,
      mergedIntoId: j['mergedIntoId'] as String?,
      rejectionReason: j['rejectionReason'] as String?,
      pendingReview: j['visibility'] == 'hidden',
      lat: (loc['lat'] as num?)?.toDouble(),
      lng: (loc['lng'] as num?)?.toDouble(),
      viewer: ViewerCaps.fromJson(
        Map<String, dynamic>.from(body['viewer'] as Map? ?? const {}),
      ),
    );
  }

  final String id, title, categorySlug, categoryNameEn, categoryNameGu;
  final String displayStatus;
  final IssueStatus status;
  final bool isOverdue, blurApplied, pendingReview;
  final DateTime slaDueAt, createdAt;
  final int meTooCount, followerCount;
  final List<String> reportPhotos, afterPhotos;
  final String? wardId, wardNameEn, wardNameGu, description;
  final String? mergedIntoId, rejectionReason;
  final double? lat, lng;
  final ViewerCaps viewer;

  String categoryName(String lang) =>
      lang == 'gu' ? categoryNameGu : categoryNameEn;
  String wardName(String lang) =>
      (lang == 'gu' ? wardNameGu : wardNameEn) ?? '';
  bool get isOpen => const {
    IssueStatus.reported,
    IssueStatus.sent,
    IssueStatus.acknowledged,
    IssueStatus.inProgress,
    IssueStatus.reopened,
  }.contains(status);
}

class ViewerCaps {
  const ViewerCaps({
    this.signedIn = false,
    this.isReporter = false,
    this.hasMeToo = false,
    this.isFollowing = false,
    this.canMeToo = false,
    this.canLinkCcrs = false,
    this.canEscalate = false,
  });

  factory ViewerCaps.fromJson(Map<String, dynamic> j) => ViewerCaps(
    signedIn: j['signedIn'] == true,
    isReporter: j['isReporter'] == true,
    hasMeToo: j['hasMeToo'] == true,
    isFollowing: j['isFollowing'] == true,
    canMeToo: j['canMeToo'] == true,
    canLinkCcrs: j['canLinkCcrs'] == true,
    canEscalate: j['canEscalate'] == true,
  );

  final bool signedIn, isReporter, hasMeToo, isFollowing;
  final bool canMeToo, canLinkCcrs, canEscalate;
}

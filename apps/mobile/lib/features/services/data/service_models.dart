/// AMC services directory models (TASK-12 §5.3). Content comes from the API
/// in both languages; `pick` chooses by the app language.
library;

String _s(Object? v) => v == null ? '' : '$v';

/// `en`/`gu` pair picked by language code.
String pick(String lang, String en, String gu) =>
    lang == 'gu' && gu.isNotEmpty ? gu : en;

const serviceCategories = <String>[
  'tax',
  'certificates',
  'building',
  'health',
  'education',
  'transport',
  'leisure',
  'information',
  'business',
];

class ServiceSummary {
  const ServiceSummary({
    required this.slug,
    required this.category,
    required this.nameEn,
    required this.nameGu,
    required this.summaryEn,
    required this.summaryGu,
    required this.online,
    required this.visitWardOffice,
    this.linkOk,
  });

  final String slug;
  final String category;
  final String nameEn;
  final String nameGu;
  final String summaryEn;
  final String summaryGu;
  final bool online;
  final bool visitWardOffice;
  final bool? linkOk;

  String name(String lang) => pick(lang, nameEn, nameGu);
  String summary(String lang) => pick(lang, summaryEn, summaryGu);

  factory ServiceSummary.fromJson(Map<String, dynamic> j) => ServiceSummary(
    slug: _s(j['slug']),
    category: _s(j['category']),
    nameEn: _s(j['nameEn']),
    nameGu: _s(j['nameGu']),
    summaryEn: _s(j['summaryEn']),
    summaryGu: _s(j['summaryGu']),
    online: j['online'] == true,
    visitWardOffice: j['visitWardOffice'] == true,
    linkOk: j['linkOk'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'category': category,
    'nameEn': nameEn,
    'nameGu': nameGu,
    'summaryEn': summaryEn,
    'summaryGu': summaryGu,
    'online': online,
    'visitWardOffice': visitWardOffice,
    'linkOk': linkOk,
  };
}

class WardOffice {
  const WardOffice({
    required this.wardId,
    required this.number,
    required this.nameEn,
    required this.nameGu,
    this.addressEn,
    this.addressGu,
    this.phone,
  });

  final String wardId;
  final int number;
  final String nameEn;
  final String nameGu;
  final String? addressEn;
  final String? addressGu;
  final String? phone;

  String name(String lang) => pick(lang, nameEn, nameGu);
  String? address(String lang) {
    final a = pick(lang, addressEn ?? '', addressGu ?? '');
    return a.isEmpty ? null : a;
  }

  static WardOffice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    return WardOffice(
      wardId: _s(j['wardId']),
      number: (j['number'] as num?)?.toInt() ?? 0,
      nameEn: _s(j['nameEn']),
      nameGu: _s(j['nameGu']),
      addressEn: j['officeAddress'] as String?,
      addressGu: j['officeAddressGu'] as String?,
      phone: j['officePhone'] as String?,
    );
  }
}

class ServiceDetail {
  const ServiceDetail({
    required this.summary,
    required this.department,
    required this.departmentGu,
    required this.howToEn,
    required this.howToGu,
    required this.url,
    this.lastCheckedAt,
    this.verifiedAt,
    this.wardOffice,
  });

  final ServiceSummary summary;
  final String department;
  final String departmentGu;
  final String howToEn;
  final String howToGu;
  final String url;
  final DateTime? lastCheckedAt;
  final DateTime? verifiedAt;
  final WardOffice? wardOffice;

  String departmentName(String lang) => pick(lang, department, departmentGu);

  /// Numbered steps without their "N. " prefix.
  List<String> steps(String lang) => parseSteps(pick(lang, howToEn, howToGu));

  String get host => Uri.tryParse(url)?.host ?? url;

  factory ServiceDetail.fromJson(Map<String, dynamic> j) => ServiceDetail(
    summary: ServiceSummary.fromJson(j),
    department: _s(j['department']),
    departmentGu: _s(j['departmentGu']),
    howToEn: _s(j['howToEn']),
    howToGu: _s(j['howToGu']),
    url: _s(j['url']),
    lastCheckedAt: DateTime.tryParse(_s(j['lastCheckedAt']))?.toLocal(),
    verifiedAt: DateTime.tryParse(_s(j['verifiedAt']))?.toLocal(),
    wardOffice: WardOffice.fromJson(j['wardOffice']),
  );
}

/// "1. Open…\n2. Enter…" → ["Open…", "Enter…"].
List<String> parseSteps(String markdown) => markdown
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .map((l) => l.replaceFirst(RegExp(r'^\d{1,2}\.\s*'), ''))
    .toList();

class ServiceTip {
  const ServiceTip({
    required this.id,
    required this.titleEn,
    required this.titleGu,
    required this.bodyEn,
    required this.bodyGu,
    this.serviceSlug,
  });

  final String id;
  final String titleEn;
  final String titleGu;
  final String bodyEn;
  final String bodyGu;
  final String? serviceSlug;

  String title(String lang) => pick(lang, titleEn, titleGu);
  String body(String lang) => pick(lang, bodyEn, bodyGu);

  factory ServiceTip.fromJson(Map<String, dynamic> j) => ServiceTip(
    id: _s(j['id']),
    titleEn: _s(j['titleEn']),
    titleGu: _s(j['titleGu']),
    bodyEn: _s(j['bodyEn']),
    bodyGu: _s(j['bodyGu']),
    serviceSlug: j['serviceSlug'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleEn': titleEn,
    'titleGu': titleGu,
    'bodyEn': bodyEn,
    'bodyGu': bodyGu,
    'serviceSlug': serviceSlug,
  };
}

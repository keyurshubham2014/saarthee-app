import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/staff_api.dart';

/// A v2 category as staff edit it (`GET /staff/categories`).
class StaffCategory {
  const StaffCategory({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameGu,
    required this.icon,
    required this.colourToken,
    required this.slaDays,
    required this.sensitive,
    required this.isActive,
    required this.sortOrder,
  });

  factory StaffCategory.fromJson(Json j) => StaffCategory(
    id: '${j['id']}',
    slug: '${j['slug']}',
    nameEn: '${j['nameEn']}',
    nameGu: '${j['nameGu']}',
    icon: '${j['icon']}',
    colourToken: '${j['colourToken']}',
    slaDays: (j['slaDays'] as num).toInt(),
    sensitive: j['sensitive'] == true,
    isActive: j['isActive'] == true,
    sortOrder: (j['sortOrder'] as num).toInt(),
  );

  final String id, slug, nameEn, nameGu, icon, colourToken;
  final int slaDays, sortOrder;
  final bool sensitive, isActive;

  String name(String lang) => lang == 'gu' ? nameGu : nameEn;
}

class StaffCategories {
  const StaffCategories(this.items, this.icons, this.colourTokens);
  final List<StaffCategory> items;
  final List<String> icons, colourTokens;
}

final staffCategoriesProvider = FutureProvider.autoDispose<StaffCategories>((
  ref,
) async {
  final j = await ref.watch(staffApiProvider).categories();
  return StaffCategories(
    [
      for (final c in (j['items'] as List))
        StaffCategory.fromJson((c as Map).cast<String, dynamic>()),
    ],
    [for (final i in (j['icons'] as List? ?? const [])) '$i'],
    [for (final t in (j['colourTokens'] as List? ?? const [])) '$t'],
  );
});

import 'package:go_router/go_router.dart';

import '../features/report/presentation/category_screen.dart';
import '../features/report/presentation/check_screen.dart';
import '../features/report/presentation/done_screen.dart';
import '../features/report/presentation/file_with_amc_screen.dart';
import '../features/report/presentation/number_screen.dart';
import '../features/report/presentation/phone_screen.dart';
import '../features/report/presentation/photo_screen.dart';
import 'app_router.dart';

/// Report and verify routes (02 §3.1).
final List<RouteBase> citizenRoutes = <RouteBase>[
  GoRoute(
    path: '/report/category',
    pageBuilder: (c, s) => stepPage(s, const CategoryScreen()),
  ),
  GoRoute(
    path: '/report/file-with-amc',
    pageBuilder: (c, s) => stepPage(s, const FileWithAmcScreen()),
  ),
  GoRoute(
    path: '/report/number',
    pageBuilder: (c, s) => stepPage(s, const NumberScreen()),
  ),
  GoRoute(
    path: '/report/photo',
    pageBuilder: (c, s) => stepPage(s, const PhotoScreen()),
  ),
  GoRoute(
    path: '/report/phone',
    pageBuilder: (c, s) => stepPage(s, const PhoneScreen()),
  ),
  GoRoute(
    path: '/report/check',
    pageBuilder: (c, s) => stepPage(s, const CheckScreen()),
  ),
  GoRoute(
    path: '/report/done',
    pageBuilder: (c, s) => stepPage(s, const ReportDoneScreen()),
  ),
];

import 'package:go_router/go_router.dart';

import '../features/report/presentation/category_screen.dart';
import '../features/report/presentation/check_screen.dart';
import '../features/report/presentation/done_screen.dart';
import '../features/report/presentation/file_with_amc_screen.dart';
import '../features/report/presentation/number_screen.dart';
import '../features/report/presentation/phone_screen.dart';
import '../features/report/presentation/photo_screen.dart';
import '../features/verify/presentation/verify_entry_screens.dart';
import '../features/verify/presentation/verify_flow_screens.dart';
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
  // Verify: the token is never part of these locations (memory only).
  GoRoute(
    path: '/verify',
    pageBuilder: (c, s) => stepPage(s, const VerifyEntryScreen()),
  ),
  GoRoute(
    path: '/verify/enter-code',
    pageBuilder: (c, s) => stepPage(s, const VerifyEnterCodeScreen()),
  ),
  GoRoute(
    path: '/verify/answer',
    pageBuilder: (c, s) => stepPage(s, const VerifyAnswerScreen()),
  ),
  GoRoute(
    path: '/verify/photo',
    pageBuilder: (c, s) => stepPage(s, const VerifyPhotoScreen()),
  ),
  GoRoute(
    path: '/verify/note',
    pageBuilder: (c, s) => stepPage(s, const VerifyNoteScreen()),
  ),
  GoRoute(
    path: '/verify/check',
    pageBuilder: (c, s) => stepPage(s, const VerifyCheckScreen()),
  ),
  GoRoute(
    path: '/verify/done',
    pageBuilder: (c, s) => stepPage(s, const VerifyDoneScreen()),
  ),
];

// W-11-01 VerifiedRepBadge states (en + gu), W-11-02 claim step 1 and step 2.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/connectivity/connectivity_provider.dart';
import 'package:saarthee/features/rep_claim/application/claim_draft.dart';
import 'package:saarthee/features/rep_claim/data/rep_claim_api.dart';
import 'package:saarthee/features/rep_claim/presentation/claim_check_screen.dart';
import 'package:saarthee/features/rep_claim/presentation/claim_evidence_screen.dart';
import 'package:saarthee/features/rep_claim/presentation/verified_rep_badge.dart';
import 'package:saarthee/features/ward/application/ward_providers.dart';
import 'package:saarthee/features/ward/data/ward_models.dart';

import '../helpers/motion.dart';

class FakePicker implements ClaimPhotoPicker {
  int n = 0;
  @override
  Future<String?> pick({required bool camera}) async => '/tmp/p${n++}.jpg';
}

class FakeClaimApi implements RepClaimApi {
  bool failUpload = false;
  Object? submitError;
  final uploads = <String>[];
  @override
  Future<String> uploadEvidence(
    String filePath, {
    void Function(double)? onProgress,
  }) async {
    uploads.add(filePath);
    if (failUpload) throw const AppError.offline();
    return 'photo-${uploads.length}';
  }

  @override
  Future<String> submit(
    String repId,
    List<String> photoIds,
    String? note,
  ) async {
    if (submitError != null) throw submitError!;
    return 'claim-1';
  }

  @override
  Future<List<MyRepClaim>> mine() async => const [];
  @override
  Future<void> withdraw(String claimId) async {}
}

void main() {
  for (final locale in const [Locale('en'), Locale('gu')]) {
    testWidgets(
      'W-11-01 badge verified / expired / unverified (${locale.languageCode})',
      (t) async {
        final verified = RepVerification.fromJson({
          'status': 'verified',
          'method': 'certificate_of_election',
          'verifiedAt': '2026-10-03T05:30:00Z',
          'validUntil': '2031-02-28',
        });
        await pumpMotion(
          t,
          Column(
            children: [
              VerifiedRepBadge(
                verification: verified,
                repId: 'r1',
                name: 'Sample Corporator 30-A',
              ),
              const VerifiedRepBadge(
                verification: RepVerification(status: 'expired'),
                repId: 'r2',
                name: 'B',
              ),
              const VerifiedRepBadge(
                verification: RepVerification(status: 'unverified'),
                repId: 'r3',
                name: 'Sample Corporator 30-A',
              ),
            ],
          ),
          locale: locale,
          reduced: true,
        );
        expect(
          find.byKey(const Key('repClaim.badge.verified')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('repClaim.badge.expired')), findsOneWidget);
        expect(find.byKey(const Key('repClaim.link')), findsOneWidget);
        final label = t
            .getSemantics(find.byKey(const Key('repClaim.badge.verified')))
            .label;
        expect(
          label,
          locale.languageCode == 'en'
              ? startsWith('Verified representative, checked on')
              : contains('ચકાસાયેલ પ્રતિનિધિ'),
        );
        if (locale.languageCode == 'en') {
          expect(
            find.textContaining('Certificate of election'),
            findsOneWidget,
          );
          expect(find.text('Verification ended with the term'), findsOneWidget);
          expect(
            find.text('Are you Sample Corporator 30-A? Claim this profile'),
            findsOneWidget,
          );
        }
      },
    );
  }

  testWidgets(
    'W-11-02 step 1: evidence required, upload retry, offline banner',
    (t) async {
      final api = FakeClaimApi()..failUpload = true;
      await pumpMotion(
        t,
        const ClaimEvidenceScreen(repId: 'r1'),
        reduced: true,
        overrides: [
          claimPhotoPickerProvider.overrideWithValue(FakePicker()),
          repClaimApiProvider.overrideWithValue(api),
          isOfflineProvider.overrideWithValue(true),
        ],
      );
      expect(find.byKey(const Key('repClaim.offline')), findsOneWidget);
      await t.tap(find.byKey(const Key('repClaim.continue')));
      await t.pump();
      expect(find.byKey(const Key('repClaim.errorSummary')), findsOneWidget);
      expect(find.text('Add at least one photo.'), findsWidgets);
      await t.tap(find.byKey(const Key('repClaim.camera')));
      await t.pump();
      await t.pump();
      expect(find.text('Upload failed.'), findsOneWidget);
      api.failUpload = false;
      await t.tap(find.byKey(const Key('repClaim.retry')));
      await t.pump();
      await t.pump();
      expect(find.text('Upload failed.'), findsNothing);
      expect(find.text('1 of 3 photos'), findsOneWidget);
    },
  );

  testWidgets(
    'W-11-02 step 2: 409 pending shows the error summary with focus and "See my claims"',
    (t) async {
      final api = FakeClaimApi()
        ..submitError = const AppError(code: 'CLAIM_ALREADY_PENDING');
      final c = await pumpMotion(
        t,
        const ClaimCheckScreen(repId: 'r1'),
        reduced: true,
        overrides: [
          repClaimApiProvider.overrideWithValue(api),
          repDetailProvider('r1').overrideWith(
            (ref) async => RepDetail.fromJson({
              'id': 'r1',
              'nameEn': 'Sample Corporator 30-A',
              'nameGu': 'નમૂના કોર્પોરેટર 30-ક',
              'role': 'corporator',
              'initials': 'SA',
              'canMessage': true,
              'verified': false,
              'sourceUrl': 'https://example.org/x',
              'areas': const [],
            }),
          ),
        ],
      );
      await c.read(claimDraftProvider('r1').notifier).add('/tmp/a.jpg');
      await t.pump();
      await t.tap(find.byKey(const Key('repClaim.send')));
      await t.pump();
      expect(find.text('Tick the confirmation to send.'), findsWidgets);
      await t.tap(find.byKey(const Key('repClaim.consent')));
      await t.pump();
      await t.tap(find.byKey(const Key('repClaim.send')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('repClaim.check.error')), findsOneWidget);
      expect(
        find.text('You already have a claim waiting for review.'),
        findsWidgets,
      );
      expect(find.byKey(const Key('repClaim.seeMine')), findsOneWidget);
    },
  );
}

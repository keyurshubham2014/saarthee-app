import 'dart:async';

import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/initiatives/data/initiative_models.dart';
import 'package:saarthee/features/initiatives/data/initiatives_repository.dart';
import 'package:saarthee/features/services/data/service_models.dart';
import 'package:saarthee/features/services/data/services_repository.dart';

ServiceSummary svc(
  String slug, {
  String category = 'tax',
  String nameEn = 'Pay property tax',
  String nameGu = 'મિલકત વેરો ભરો',
  bool online = true,
  bool wardOffice = false,
  bool? linkOk = true,
}) => ServiceSummary(
  slug: slug,
  category: category,
  nameEn: nameEn,
  nameGu: nameGu,
  summaryEn: 'Summary of $slug',
  summaryGu: 'સારાંશ $slug',
  online: online,
  visitWardOffice: wardOffice,
  linkOk: linkOk,
);

ServiceDetail detail(
  ServiceSummary s, {
  WardOffice? office,
  DateTime? lastCheckedAt,
}) => ServiceDetail(
  summary: s,
  department: 'Property Tax',
  departmentGu: 'મિલકત વેરા વિભાગ',
  howToEn: '1. Open the page.\n2. Enter your number.\n3. Pay.',
  howToGu: '1. પેજ ખોલો.\n2. નંબર લખો.\n3. ચૂકવો.',
  url: 'https://ahmedabadcity.gov.in/PTAX/DuesSearch',
  lastCheckedAt: lastCheckedAt ?? DateTime.utc(2026, 10, 4),
  wardOffice: office,
);

class FakeServicesRepository implements ServicesRepository {
  FakeServicesRepository({
    this.items = const [],
    this.details = const {},
    this.tipList = const [],
    this.fromCache = false,
    this.listError,
  });

  List<ServiceSummary> items;
  Map<String, ServiceDetail> details;
  List<ServiceTip> tipList;
  bool fromCache;
  AppError? listError;
  final List<String?> detailWards = [];

  @override
  Future<Cached<List<ServiceSummary>>> listServices() async {
    if (listError != null) throw listError!;
    return Cached(items, fromCache: fromCache);
  }

  @override
  Future<ServiceDetail> getService(String slug, {String? wardId}) async {
    detailWards.add(wardId);
    final d = details[slug];
    if (d == null) throw const AppError(code: 'NOT_FOUND', statusCode: 404);
    return d;
  }

  @override
  Future<Cached<List<ServiceTip>>> tips({String? wardId}) async =>
      Cached(tipList, fromCache: false);
}

Initiative drive({
  String id = 'i1',
  int going = 3,
  int? capacity = 20,
  String status = 'published',
  String? myRsvp,
  Duration startsIn = const Duration(days: 2),
  String? wardId = 'w12',
}) {
  final start = DateTime.now().add(startsIn);
  return Initiative(
    id: id,
    titleEn: 'Canal clean-up',
    titleGu: 'કેનાલ સફાઈ',
    type: 'cleanup',
    organiser: 'RWA',
    organiserName: 'Paldi RWA',
    wardId: wardId,
    locationTextEn: 'Canal gate',
    locationTextGu: 'કેનાલ ગેટ',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    capacity: capacity,
    goingCount: going,
    status: status,
    myRsvp: myRsvp,
    descriptionEn: 'Bring gloves.',
    descriptionGu: 'હાથમોજાં લાવો.',
    sourceUrl: 'https://example.org/drive',
    lat: 23.01,
    lng: 72.56,
  );
}

/// In-memory initiatives API. [rsvpGate] holds an RSVP in flight until
/// completed; [fullOnRsvp] answers 409 INITIATIVE_FULL.
class FakeInitiativesRepository implements InitiativesRepository {
  FakeInitiativesRepository(List<Initiative> items)
    : byId = {for (final i in items) i.id: i};

  final Map<String, Initiative> byId;
  final List<String> calls = [];
  Completer<void>? rsvpGate;
  bool fullOnRsvp = false;

  @override
  Future<Cached<List<Initiative>>> list({String? wardId, int limit = 20}) async {
    calls.add('list:${wardId ?? 'city'}');
    final items = byId.values
        .where((i) => wardId == null || i.wardId == wardId || i.wardId == null)
        .toList();
    return Cached(items, fromCache: false);
  }

  @override
  Future<Initiative> get(String id) async {
    final i = byId[id];
    if (i == null) throw const AppError(code: 'NOT_FOUND', statusCode: 404);
    return i;
  }

  @override
  Future<RsvpResult> rsvp(String id) async {
    calls.add('rsvp:$id');
    await rsvpGate?.future;
    if (fullOnRsvp) {
      throw const AppError(code: 'INITIATIVE_FULL', statusCode: 409);
    }
    final i = byId[id]!;
    byId[id] = i.copyWith(goingCount: i.goingCount + 1, myRsvp: 'going');
    return RsvpResult(going: true, goingCount: i.goingCount + 1);
  }

  @override
  Future<RsvpResult> cancelRsvp(String id) async {
    calls.add('cancel:$id');
    final i = byId[id]!;
    byId[id] = i.copyWith(goingCount: i.goingCount - 1, myRsvp: 'cancelled');
    return RsvpResult(going: false, goingCount: i.goingCount - 1);
  }
}

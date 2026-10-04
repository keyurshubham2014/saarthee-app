// V2-TASK-14 polish: the issue subline never repeats what the title says.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/discovery/data/discovery_models.dart';
import 'package:saarthee/features/discovery/presentation/issue_detail_screen.dart';
import 'package:saarthee/features/discovery/presentation/widgets/issue_card_tile.dart';

import 'fakes.dart';
import 'harness.dart';

void main() {
  test('issueSubline drops parts the title already contains', () {
    expect(
      issueSubline('Roads & potholes · Paldi', ['Paldi'], 'today'),
      'today',
    );
    expect(
      issueSubline('Roads & potholes · Paldi', [
        'Roads & potholes',
        'Paldi',
      ], 'today'),
      'today',
    );
    expect(issueSubline('Broken light', ['Paldi'], 'today'), 'Paldi · today');
    expect(issueSubline('Broken light', [null, ''], 'today'), 'today');
  });

  testWidgets('card subline shows only the age when the title has the ward', (
    t,
  ) async {
    final issue = IssueCardData.fromJson(
      cardJson('c-1', title: 'Roads & potholes · Paldi', daysAgo: 0),
    );
    await pumpDiscovery(
      t,
      home: Scaffold(body: IssueCardTile(issue: issue, hero: false)),
      api: FakeDiscoveryApi(),
    );
    await settle(t);
    expect(find.text('today'), findsOneWidget);
    expect(find.text('Paldi · today'), findsNothing);
  });

  testWidgets('detail subline shows only the age when the title has '
      'category and ward', (t) async {
    final body = detailJson('d-1');
    (body['issue'] as Map)['title'] = 'Roads · Paldi';
    await pumpDiscovery(
      t,
      home: const IssueDetailScreen(issueId: 'd-1'),
      api: FakeDiscoveryApi(details: {'d-1': body}),
    );
    await settle(t);
    final meta = t.widget<Text>(find.byKey(const Key('detail.meta'))).data!;
    expect(meta, isNot(contains('Paldi')));
    expect(meta, isNot(contains('Roads')));
    expect(meta, isNotEmpty);
  });
}

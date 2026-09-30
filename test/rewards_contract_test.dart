import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/reward_tab.dart';

void main() {
  testWidgets('failed rewards do not manufacture balances, bands or promises',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewardTab(
                onBookTap: () {},
                loadRewards: ({bool forceRefresh = false}) async =>
                    throw Exception('offline')))));
    await tester.pumpAndSettle();
    expect(find.text('Available service credits'), findsNothing);
    expect(find.text('How credits work'), findsNothing);
    expect(find.textContaining('% on new spend'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('legacy calendar totals are never presented as rolling totals',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewardTab(
                onBookTap: () {},
                loadRewards: ({bool forceRefresh = false}) async => {
                      'balance': 0,
                      'earnedThisYear': 12345,
                      'ytdSpend': 54321,
                      'rate': 7,
                      'ledger': [],
                    }))));
    await tester.pumpAndSettle();
    expect(find.textContaining('12,345'), findsNothing);
    expect(find.textContaining('54,321'), findsNothing);
    expect(find.textContaining('7%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('current platform anniversary fields render without calendar totals',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewardTab(
                onBookTap: () {},
                loadRewards: ({bool forceRefresh = false}) async => {
                      'balance': 12.5,
                      'earnedThisPeriod': 24,
                      'programPeriodEnd': '2027-03-01',
                      'ytdSpend': 99999,
                      'ledger': [
                        {
                          'type': 'band_earn',
                          'amount': 5,
                          'creditStatus': 'available',
                          'createdAt': '2026-09-20'
                        }
                      ],
                    }))));
    await tester.pumpAndSettle();
    expect(find.textContaining('24.00 earned since your year started'),
        findsOneWidget);
    expect(find.text('Earned'), findsOneWidget);
    expect(find.textContaining('99,999'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('zero paid receipt entries are suppressed on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewardTab(
                onBookTap: () {},
                loadRewards: ({bool forceRefresh = false}) async => {
                      'balance': 0,
                      'earnedInWindow': 0,
                      'qualifyingSpend': 0,
                      'pendingReceipts': [
                        {
                          'workOrderId': 1,
                          'amount': 0,
                          'service': 'Fully credited job'
                        }
                      ],
                      'ledger': [
                        {
                          'type': 'earns_nothing',
                          'paidAmount': 0,
                          'amount': 0,
                          'workOrderId': 1,
                          'occurredAt': '2026-09-26'
                        }
                      ],
                    }))));
    await tester.pumpAndSettle();
    expect(find.text('Fully credited job'), findsNothing);
    expect(find.text('Upload paid receipt'), findsNothing);
    expect(find.text('Fully covered by credits · No credits earned'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/reward_tab.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/main_bottom_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Future.wait([
      (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
      (FontLoader('Outfit')
            ..addFont(rootBundle.load('assets/fonts/Outfit-SemiBold.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Outfit-Bold.ttf')))
          .load(),
    ]);
  });

  testWidgets('Rewards follows F01 with the shared homeowner seed',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2640);
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: RewardTab(
          onBookTap: () {},
          loadRewards: ({bool forceRefresh = false}) async => _seed,
        ),
        bottomNavigationBar: MainBottomNavigation(
          currentIndex: 3,
          onTap: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Rewards'), findsNWidgets(2)); // Page title and tab label.
    expect(find.text('Available service credits'), findsOneWidget);
    expect(find.text('Upload your paid receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/rewards-f01.png'),
    );

    for (final (size, scale) in [
      (const Size(320, 640), 1.3),
      (const Size(390, 844), 1.3),
      (const Size(768, 1024), 1.3),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: RewardTab(
            key: ValueKey(size.width),
            onBookTap: () {},
            loadRewards: ({bool forceRefresh = false}) async => _seed,
          ),
          bottomNavigationBar: MainBottomNavigation(
            currentIndex: 3,
            onTap: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available service credits'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Rewards at ${size.width} wide and $scale text scale');
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/rewards-${size.width.toInt()}-large.png'),
      );
      await tester.ensureVisible(find.text('Browse services'));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'Rewards scrolled at ${size.width} wide');
    }
  });
}

final _seed = <String, dynamic>{
  'balance': 64.20,
  'earliestExpiry': {'amount': 59.73, 'expiresAt': '2028-05-18'},
  'pendingReceipts': [
    {
      'workOrderId': 24120,
      'woNumber': 'WO-24120',
      'serviceName': 'Outlet repair',
      'proName': 'Brightline Electric',
      'paidAmount': 149,
      'completedAt': '2026-10-05',
    },
  ],
  'periodSpend': 2140,
  'earnedInWindow': 64.20,
  'programPeriodStart': '2026-03-02',
  'programPeriodEnd': '2027-03-02', // Exclusive anniversary boundary.
  'resetDate': '2027-03-02',
  'milestoneExpiryDays': 90,
  'bands': [
    {'floor': 0, 'ceiling': 2500, 'rate': 3, 'earnedInBand': 64.20},
    {'floor': 2500, 'ceiling': 6000, 'rate': 4},
    {'floor': 6000, 'ceiling': 10000, 'rate': 5},
    {'floor': 10000, 'ceiling': 15000, 'rate': 6},
    {'floor': 15000, 'ceiling': 30000, 'rate': 8},
  ],
  'milestones': [
    {'threshold': 2500, 'amount': 50},
    {'threshold': 6000, 'amount': 100},
    {'threshold': 10000, 'amount': 150},
    {'threshold': 15000, 'amount': 200},
    {'threshold': 30000, 'amount': 250},
  ],
  'ledger': [
    {
      'type': 'applied',
      'amount': -50,
      'workOrderId': 24144,
      'woNumber': 'WO-24144',
      'serviceName': 'HVAC tune-up',
      'proName': 'Hutchins Plumbing Co.',
      'occurredAt': '2026-10-13',
    },
    {
      'type': 'earned',
      'amount': 4.47,
      'paidAmount': 149,
      'rate': 3,
      'workOrderId': 24044,
      'woNumber': 'WO-24044',
      'serviceName': 'Drain clearing',
      'proName': 'Bay Plumbing Co.',
      'occurredAt': '2026-08-21',
      'expiresAt': '2028-08-21',
    },
    {
      'type': 'earned',
      'amount': 59.73,
      'paidAmount': 1991,
      'rate': 3,
      'workOrderId': 23871,
      'woNumber': 'WO-23871',
      'serviceName': 'Water heater replacement',
      'proName': 'Bay Plumbing Co.',
      'occurredAt': '2026-05-18',
      'expiresAt': '2028-05-18',
    },
    {
      'type': 'grant',
      'amount': 50,
      'note': 'Signup credit',
      'occurredAt': '2026-03-02',
    },
  ],
};

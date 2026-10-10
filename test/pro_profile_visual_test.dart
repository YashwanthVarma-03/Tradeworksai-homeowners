import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/pro_profile.dart';
import 'package:homeowners_app/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('Hutchins pro profile follows B02b at phone width',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2380);
    addTearDown(tester.view.reset);

    final profile = <String, dynamic>{
      'business_name': 'Hutchins Plumbing Co.',
      'categories': [
        'Plumbing',
        'AC / HVAC',
        'Electrical',
        'Roofing',
        'Cleaning'
      ],
      'about':
          'Family-run plumbing, HVAC and electrical company serving Tampa Bay. Most repairs finish in a single visit, and we carry common parts on the van.',
      'completedWorkOrders': 127,
      'similarJobsNearby': '4 similar jobs done in 33578',
      'verificationSummary': 'Licensed · Insured · Background checked',
      'employees': 3,
      'yearsInBusiness': 11,
      'business_hours': [
        for (final day in ['mon', 'tue', 'wed', 'thu', 'fri'])
          {'day': day, 'open': '07:00', 'close': '18:00'},
        {'day': 'sat', 'open': '08:00', 'close': '14:00'},
        {'day': 'sun', 'hours': 'Emergency only'},
      ],
      'timeZone': 'Eastern time',
      'emergency': {
        'urgent_available': true,
        'urgent_fee': 35,
        'available': true,
        'emergency_fee': 90,
      },
      'payment_methods': ['card', 'check', 'cash'],
      'services': [
        {
          'category': 'AC / HVAC',
          'name': 'AC repair',
          'work_order_type': 'nte',
          'rate_amount': 89
        },
        {
          'category': 'AC / HVAC',
          'name': 'HVAC tune-up',
          'work_order_type': 'rate_card',
          'rate_amount': 129
        },
        {
          'category': 'AC / HVAC',
          'name': 'Compressor replacement',
          'work_order_type': 'nte',
          'rate_amount': 89
        },
        {
          'category': 'AC / HVAC',
          'name': 'Ductwork repair',
          'work_order_type': 'quote_request'
        },
        {
          'category': 'Plumbing',
          'name': 'Leak repair',
          'work_order_type': 'rate_card',
          'rate_amount': 189
        },
        {
          'category': 'Plumbing',
          'name': 'Drain clearing',
          'work_order_type': 'rate_card',
          'rate_amount': 149
        },
        {
          'category': 'Plumbing',
          'name': 'Water heater flush',
          'work_order_type': 'rate_card',
          'rate_amount': 229
        },
        {
          'category': 'Electrical',
          'name': 'Outlet repair',
          'work_order_type': 'rate_card',
          'rate_amount': 149
        },
        {
          'category': 'Electrical',
          'name': 'Panel inspection',
          'work_order_type': 'rate_card',
          'rate_amount': 175
        },
        {
          'category': 'Appliance Repair',
          'name': 'Dishwasher repair',
          'work_order_type': 'rate_card',
          'rate_amount': 119
        },
        {
          'category': 'Appliance Repair',
          'name': 'Washer repair',
          'work_order_type': 'rate_card',
          'rate_amount': 119
        },
        {
          'category': 'Gutter Cleaning',
          'name': 'Gutter cleaning',
          'work_order_type': 'quote_request'
        },
        {
          'category': 'Plumbing',
          'name': 'Water heater replacement',
          'work_order_type': 'quote_request',
          'enabled': false
        },
        {
          'category': 'Roof Inspection',
          'name': 'Roof inspection',
          'work_order_type': 'rate_card',
          'rate_amount': 150,
          'status': 'pending_approval'
        },
      ],
      'reviews': {
        'verified_aggregate': {
          'avg_rating': 4.8,
          'count': 32,
          'breakdown': {'5': 27, '4': 4, '3': 1, '2': 0, '1': 0},
        },
        'items': [
          {
            'name': 'Owen P.',
            'rating': 5,
            'text': 'The repair was clear and on time.',
            'completed': true,
            'daysAgo': 'Oct 2026'
          },
        ],
      },
      'media': [
        {'url': 'https://example.com/recent-work-1.png'},
        {'url': 'https://example.com/recent-work-2.png'},
      ],
    };

    final client = MockClient((_) async =>
        http.Response(jsonEncode({'success': true, 'profile': profile}), 200));
    const pro = <String, dynamic>{
      'slug': 'hutchins-b02b-visual',
      'businessName': 'Hutchins Plumbing Co.',
      'category': 'AC / HVAC',
      'selectedService': 'AC repair',
      'requestZip': '33578',
      'workOrderType': 'nte',
      'fromPrice': 89,
      'nextAvailable': 'Tomorrow',
      'rating': 4.8,
      'reviewCount': 32,
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProProfileScreen(pro: pro),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hutchins Plumbing Co.'), findsWidgets);
      expect(find.text('AC repair · 33578'), findsOneWidget);
      expect(find.text('Team of 3 · 11 years in business'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(Scaffold).first,
          matchesGoldenFile('goldens/pro-profile-b02b.png'));
      for (final (size, scale) in <(Size, double)>[
        (const Size(320, 700), 1),
        (const Size(390, 844), 1),
        (const Size(768, 1024), 1),
        (const Size(390, 844), 1.8),
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
          home: ProProfileScreen(key: ValueKey('$size/$scale'), pro: pro),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size at $scale×');
        for (var page = 0; page < 5; page++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -550));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$size page $page at $scale×');
        }
      }
    }, () => client);
  });
}

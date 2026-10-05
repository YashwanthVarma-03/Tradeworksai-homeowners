import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/service_location.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/main_bottom_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final outfit = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Outfit-Bold.ttf'));
    await Future.wait([
      materialIcons.load(),
      inter.load(),
      outfit.load(),
    ]);
  });

  testWidgets(
      'Browse lazily renders and reveals a large category while deferring others',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocation.save(zip: '90210', locationName: 'Test area');
    var searchCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('zip-coverage')) {
        return http.Response(
            jsonEncode({
              'success': true,
              'zip': '90210',
              'categories': [
                {'categoryName': 'Plumbing', 'proCount': 100},
                {'categoryName': 'Electrical', 'proCount': 100},
              ]
            }),
            200);
      }
      searchCalls++;
      return http.Response(
          jsonEncode({
            'success': true,
            'covered': true,
            'count': 100,
            'results': List.generate(
                100,
                (i) => {
                      'contractorId': 'pro-$i',
                      'slug': 'pro-$i',
                      'businessName': 'Test Pro $i',
                      'verifiedRating': 4.8,
                      'verifiedCount': 32,
                      'fromPrice': 89,
                      'fromUnit': 'diagnostic · You approve the cap',
                      'workOrderType': 'nte',
                      'completedWorkOrders': 127,
                      'nextAvailable': 'Tomorrow',
                      'tagline':
                          'Family-run home service company with experienced local professionals.',
                    })
          }),
          200);
    });
    await http.runWithClient(() async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SearchTab(onBookPro: (_) {}),
            bottomNavigationBar: MainBottomNavigation(
              currentIndex: 1,
              onTap: (_) {},
            ),
          )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(searchCalls, 0);
      expect(find.text('Popular services'), findsOneWidget);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.text('Popular services'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isFalse,
      );
      expect(find.text('Popular services'), findsOneWidget);

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/guest-search.png'),
      );

      await tester.tap(find.text('AC repair'));
      await tester.pumpAndSettle();
      expect(searchCalls, 1);
      expect(find.text('100 pros'), findsWidgets);
      expect(find.text('12+ pros'), findsNothing);
      // Only cards near the viewport exist, even though the API returned 100.
      expect(find.textContaining('Test Pro').evaluate().length, lessThan(12));

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Within 5 miles'), findsOneWidget);
      expect(find.text('4.8+ stars'), findsOneWidget);
      await tester.tap(find.text('Quote request'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(searchCalls, 1);
      expect(find.text('0 pros'), findsOneWidget);
      expect(find.textContaining('Test Pro'), findsNothing);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('100 pros'), findsWidgets);
      final scroll = find.byType(CustomScrollView);
      for (var i = 0; i < 12; i++) {
        await tester.drag(scroll, const Offset(0, -650));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(searchCalls, 1);
      // Scroll back to read the counter without loading another category.
      final scrollable = tester.state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first);
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.textContaining('pros'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await ServiceLocation.clear();
    }, () => client);
  });
}

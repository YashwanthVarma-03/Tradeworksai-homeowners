import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/browse_search_history.dart';
import 'package:homeowners_app/services/service_location.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/main_bottom_navigation.dart';
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

  testWidgets('Browse matches the populated B01 screen at 390 wide',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final history = BrowseSearchHistory();
    await history.save('Drain clearing');
    await history.save('Outlet repair');
    await history.save('HVAC tune-up');
    await ServiceLocation.save(zip: '33578', locationName: 'Riverview');
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'success': true,
            'zip': '33578',
            'categories': <Object>[],
          }),
          200,
        ));

    await http.runWithClient(() async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
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
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('Riverview · 33578'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
          find.byType(Scaffold), matchesGoldenFile('goldens/browse-b01.png'));

      for (final (size, scale) in [
        (const Size(320, 640), 1.3),
        (const Size(390, 844), 1.3),
        (const Size(768, 1024), 1.3),
      ]) {
        tester.view.devicePixelRatio = 1;
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
            body: SearchTab(key: ValueKey(size.width), onBookPro: (_) {}),
            bottomNavigationBar: MainBottomNavigation(
              currentIndex: 1,
              onTap: (_) {},
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Recent searches'), findsOneWidget,
            reason: 'Browse at ${size.width} wide, $scale text scale');
        expect(tester.takeException(), isNull,
            reason: 'Browse at ${size.width} wide, $scale text scale');
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
              'goldens/browse-b01-${size.width.toInt()}-large.png'),
        );
      }
    }, () => client);
    await tester.pumpWidget(const SizedBox());
    await ServiceLocation.clear();
  });
}

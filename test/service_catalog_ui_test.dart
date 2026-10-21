import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:homeowners_app/screens/home_tab.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/service_catalog.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/custom_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/catalog_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCatalogFixture();
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
            ..addFont(rootBundle.load('assets/fonts/Outfit-SemiBold.ttf')))
          .load(),
    ]);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Home and All services show the same backend service count',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: HomeTab(
          isGuest: true,
          onBookTap: () {},
          onJobTap: (_) {},
          onInboxTap: () {},
          onHelpTap: () {},
          onSearchQuery: (_) {},
          onCategorySelected: (_) {},
          onGuidesTap: () {},
          onManageHomeTap: () {},
        ))));
    await tester.pumpAndSettle();
    expect(ServiceCatalog.mainServices, hasLength(31));
    expect(find.text('All 31'), findsOneWidget);
    expect(find.text('See all 31'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(7));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SearchTab(
          initialCategory: 'All',
          initialAllShowsCategories: true,
          onBookPro: (_) {},
        ))));
    await tester.pumpAndSettle();
    expect(find.text('31 services'), findsOneWidget);
    expect(find.text('AC Repair or Maintenance'), findsNothing);
    expect(find.text('Plumbing'), findsWidgets);
    expect(find.text('HVAC'), findsWidgets);
    expect(find.byType(SvgPicture), findsNWidgets(31));
    expect(find.byType(ServiceCategoryTile), findsNWidgets(31));
    final tiles = find.byType(ServiceCategoryTile);
    final firstRowY = tester.getTopLeft(tiles.at(0)).dy;
    for (var i = 1; i < 4; i++) {
      expect(tester.getTopLeft(tiles.at(i)).dy, firstRowY);
    }
    expect(tester.getTopLeft(tiles.at(4)).dy, greaterThan(firstRowY));
    expect(
        tester
            .widgetList<ServiceCategoryIcon>(find.byType(ServiceCategoryIcon))
            .every((icon) => icon.category.isNotEmpty),
        isTrue);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/browse-service-icons-390.png'));
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/browse-service-icons-320.png'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Home service count fits narrow screens with large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: Scaffold(
            body: HomeTab(
          isGuest: true,
          onBookTap: () {},
          onJobTap: (_) {},
          onInboxTap: () {},
          onHelpTap: () {},
          onSearchQuery: (_) {},
          onCategorySelected: (_) {},
          onGuidesTap: () {},
          onManageHomeTap: () {},
        ))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

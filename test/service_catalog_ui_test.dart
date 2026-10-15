import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/home_tab.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/service_catalog.dart';
import 'package:homeowners_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/catalog_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCatalogFixture);
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
    expect(find.text('All 164'), findsOneWidget);
    expect(find.text('See all 164'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SearchTab(
          initialCategory: 'All',
          initialAllShowsCategories: true,
          onBookPro: (_) {},
        ))));
    await tester.pumpAndSettle();
    expect(find.text('164 services'), findsOneWidget);
    for (final service in ServiceCatalog.items) {
      expect(find.text(service.name), findsWidgets, reason: service.name);
    }
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

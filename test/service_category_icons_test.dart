import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:homeowners_app/services/service_catalog.dart';
import 'package:homeowners_app/widgets/custom_widgets.dart';
import 'support/catalog_fixture.dart';

void main() {
  setUpAll(loadCatalogFixture);
  testWidgets(
      'catalogue icons load as accessible vectors with unknown fallback',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(children: [
          for (final service in ServiceCatalog.mainServices)
            ServiceCategoryIcon(
              category: service.name,
              size: 32,
              fallbackIcon: Icons.home_repair_service_outlined,
              fallbackColor: Colors.blue,
            ),
          const ServiceCategoryIcon(
            category: 'Future service',
            size: 32,
            fallbackIcon: Icons.home_repair_service_outlined,
            fallbackColor: Colors.blue,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNWidgets(31));
    // Only the unknown category may fall back, including after SVG decoding.
    expect(find.byIcon(Icons.home_repair_service_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('HVAC service icon'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

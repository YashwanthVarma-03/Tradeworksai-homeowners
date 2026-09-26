import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/widgets/custom_widgets.dart';

void main() {
  testWidgets('browse retains its accessible Material service icons',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
        home: ServiceCategoryIcon(
      category: 'HVAC',
      size: 32,
      fallbackIcon: Icons.ac_unit,
      fallbackColor: Colors.blue,
    )));
    expect(find.byIcon(Icons.ac_unit), findsOneWidget);
    expect(find.bySemanticsLabel('HVAC service icon'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeowners_app/main.dart';

void main() {
  testWidgets('app boots into a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('TradeWorksAI'), findsWidgets);
  });
}

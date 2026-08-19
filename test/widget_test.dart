// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeowners_app/main.dart';
import 'package:homeowners_app/widgets/custom_widgets.dart';

void main() {
  testWidgets('app boots into a material shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('sunrise background renders its child',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SunriseBackground(
          child: Text('hello tradeworks'),
        ),
      ),
    );

    expect(find.text('hello tradeworks'), findsOneWidget);
  });
}

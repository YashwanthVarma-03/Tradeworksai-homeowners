import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/widgets/loading_skeleton.dart';

void main() {
  for (final layout in SkeletonLayout.values) {
    testWidgets('$layout fits narrow screens and exposes one loading label',
        (tester) async {
      tester.view.physicalSize = const Size(280, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: const MediaQueryData(
            disableAnimations: true, textScaler: TextScaler.linear(2)),
        child: Scaffold(
            body: SkeletonPage(layout: layout, label: 'Loading test data')),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Loading test data'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

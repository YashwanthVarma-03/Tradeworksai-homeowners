import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/work_orders/work_order_detail.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/credit_apply_card.dart';

void main() {
  testWidgets('Batch 29 money states fit phone and tablet at 1.3x text',
      (tester) async {
    addTearDown(tester.view.reset);

    for (final size in const [
      Size(320, 700),
      Size(390, 844),
      Size(768, 1024),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      Widget app(Widget child) => MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, built) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: built!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
          );

      await tester.pumpWidget(app(CreditApplyCard(
        total: 460,
        balance: 64.20,
        estimate: false,
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.text('Apply credit to this repair'), findsOneWidget);
      expect(find.text('You pay the pro up to'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Credit approval at ${size.width}px');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, built) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: built!,
        ),
        home: const WorkOrderDetailScreen(job: {
          'id': 24144,
          'status': 'cancelled',
          'cancelledBy': 'contractor',
          'proName': 'Hutchins Plumbing Company',
          'serviceName': 'HVAC tune-up',
          'workOrderType': 'rate_card',
          'upfrontPrice': 129,
          'creditsApplied': 50,
        }),
      ));
      await tester.pump();
      expect(find.text('Cancelled by Hutchins Plumbing Company'),
          findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Cancelled work order at ${size.width}px');
    }
  });
}

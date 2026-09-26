import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/work_orders/cap_approval.dart';
import 'package:homeowners_app/screens/work_orders/work_order_detail.dart';

void main() {
  Future<void> showCap(WidgetTester tester, Map<String, dynamic> job) async {
    await tester.pumpWidget(
        MaterialApp(home: CapApprovalScreen(key: UniqueKey(), job: job)));
    await tester.pumpAndSettle();
  }

  for (final invalid in [
    null,
    '',
    'not available',
    '-420',
    -420,
    double.nan,
    double.infinity,
    '420-500'
  ]) {
    testWidgets('missing or invalid cap ($invalid) cannot be approved',
        (tester) async {
      await showCap(tester, {'id': 12, 'quoteAmount': invalid});
      expect(find.text("This cap isn't ready yet"), findsOneWidget);
      expect(find.text('Approve cap'), findsNothing);
      expect(find.text(r'$420'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'renders real line items and safely handles business name spacing',
      (tester) async {
    await showCap(tester, {
      'id': 12,
      'quoteAmount': r'$1,250.50',
      'proName': 'Test  Plumbing',
      'quote': {
        'diagnosis': 'Leaking fitting',
        'items': [
          {'label': 'Replace fitting', 'amount': 1250.50},
          {'name': 'Inspection'},
          {'amount': 999},
        ]
      },
    });
    expect(find.text(r'$1,250.50'), findsNothing);
    expect(find.text(r'$1250.50'), findsNWidgets(3));
    expect(find.text('Replace fitting'), findsOneWidget);
    expect(find.text('Inspection'), findsOneWidget);
    expect(find.text('TP'), findsOneWidget);
    expect(find.textContaining('Anode'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('malformed nested payloads do not crash or invent a breakdown',
      (tester) async {
    await showCap(tester,
        {'id': 12, 'quoteAmount': 200, 'quote': 'pending', 'pro': 'unknown'});
    expect(find.text(r'$200'), findsOneWidget);
    expect(find.text('BREAKDOWN'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('decline requires confirmation and can be canceled',
      (tester) async {
    await showCap(tester, {'id': 12, 'quoteAmount': 200});
    await tester.tap(find.text('Decline this cap'));
    await tester.pumpAndSettle();
    expect(find.text('Decline this cap?'), findsOneWidget);
    expect(find.textContaining('cancels this booking'), findsOneWidget);
    await tester.tap(find.text('Keep reviewing'));
    await tester.pumpAndSettle();
    expect(find.text('Approve cap'), findsOneWidget);
    expect(find.text('Decline this cap?'), findsNothing);
  });
  testWidgets('work-order details opens the shared cap screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: WorkOrderDetailScreen(job: {
      'id': 12,
      'status': 'quote_provided',
      'quoteAmount': 200,
      'serviceCategory': 'Plumbing',
      'proName': 'Test Plumbing',
    })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review the cap'));
    await tester.tap(find.text('Review the cap'));
    await tester.pumpAndSettle();
    expect(find.byType(CapApprovalScreen), findsOneWidget);
  });
}

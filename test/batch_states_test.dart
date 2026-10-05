import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/utils/work_order_status.dart';
import 'package:homeowners_app/utils/arrival_check_state.dart';
import 'package:homeowners_app/utils/session_pro_order.dart';
import 'package:homeowners_app/screens/work_orders/leave_review.dart';

void main() {
  test('legacy statuses map to the four manual states', () {
    expect(WorkOrderStatus.from('scheduled').state, WorkOrderState.booked);
    expect(WorkOrderStatus.from('arrived').state, WorkOrderState.enRoute);
    expect(
        WorkOrderStatus.from('wrapping_up').state, WorkOrderState.inProgress);
    expect(WorkOrderStatus.from('complete').state, WorkOrderState.completed);
    expect(WorkOrderStatus.from('unknown').state, WorkOrderState.booked);
  });
  test('waiting is an overlay and cancellation does not invent an actor', () {
    final waiting = WorkOrderStatus.fromJob(
        {'status': 'in_progress', 'waitingOnYou': true});
    expect(waiting.state, WorkOrderState.inProgress);
    expect(waiting.waitingOnYou, isTrue);
    expect(WorkOrderStatus.from('cancelled').label, 'Cancelled');
    expect(
        WorkOrderStatus.fromJob(
            {'status': 'cancelled', 'cancelledBy': 'platform'}).label,
        'Cancelled');
    expect(
        WorkOrderStatus.fromJob(
            {'status': 'cancelled', 'cancelledBy': 'homeowner'}).label,
        'You cancelled');
    expect(WorkOrderStatus.from('customer_no_show').isTerminalWithoutProgress,
        isTrue);
  });
  test('server arrival flags override the provisional grace fallback', () {
    final now = DateTime.utc(2026, 9, 26, 12);
    final job = <String, dynamic>{
      'status': 'accepted',
      'scheduledEnd': '2026-09-26T08:00:00Z'
    };
    expect(ArrivalCheckState.pending(job, now: now), isTrue);
    expect(
        ArrivalCheckState.pending({...job, 'pendingArrivalCheck': false},
            now: now),
        isFalse);
    expect(
        ArrivalCheckState.pending({...job, 'arrivalCheckAnswer': 'rescheduled'},
            now: now),
        isFalse);
    expect(
        ArrivalCheckState.pending(
            {...job, 'scheduledEnd': '2026-09-26T11:00:00Z'},
            now: now),
        isFalse);
  });
  test(
      'silence never clears a check, completed and cancelled jobs never prompt',
      () {
    final job = {'status': 'booked', 'scheduledEnd': '2025-01-01T00:00:00Z'};
    expect(ArrivalCheckState.pending(job, now: DateTime.utc(2026, 9)), isTrue);
    expect(
        ArrivalCheckState.pending(
            {...job, 'status': 'completed', 'pendingArrivalCheck': true}),
        isFalse);
    expect(
        ArrivalCheckState.pending(
            {...job, 'status': 'cancelled', 'pendingArrivalCheck': true}),
        isFalse);
    expect(
        ArrivalCheckState.pending(
            {'status': 'booked', 'scheduledEnd': 'not-a-date'}),
        isFalse);
  });
  test('rescheduling creates a different once-only arrival identity', () {
    expect(
        ArrivalCheckState.identity({'id': 1, 'scheduledEnd': '2026-01-01'}),
        isNot(ArrivalCheckState.identity(
            {'id': 1, 'scheduledEnd': '2026-01-02'})));
  });
  test('random order survives rebuilds, filtering and new results', () {
    final order = SessionProOrder(seed: 17);
    final all = List.generate(100, (i) => '$i');
    final first = order.arrange(all, (s) => s);
    expect(first.toSet(), all.toSet());
    expect(first, isNot(all));
    expect(order.arrange(all.reversed, (s) => s), first);
    final subset = all.where((s) => int.parse(s).isEven);
    expect(
        order.arrange(subset, (s) => s), first.where(subset.contains).toList());
    final expanded = order.arrange([...all, 'new'], (s) => s);
    expect(expanded.where((s) => s != 'new').toList(), first);
  });
  testWidgets('new review only offers the cap tag for cap-approval jobs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LeaveReviewScreen(job: {'status': 'completed'}, jobId: 17)));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('Great service'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Price stayed within the cap'),
        findsNothing);

    await tester.pumpWidget(const MaterialApp(
        home: LeaveReviewScreen(
            job: {'status': 'completed', 'workOrderType': 'nte'}, jobId: 18)));
    final capChip =
        find.widgetWithText(FilterChip, 'Price stayed within the cap');
    expect(capChip, findsOneWidget);
    expect(tester.widget<FilterChip>(capChip).onSelected, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('review edit is identified and preserves existing rating',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LeaveReviewScreen(
            job: {'status': 'completed', 'invoiceAmount': 0},
            jobId: 18,
            hasExistingReview: true,
            initialRating: 3,
            initialReviewText: 'A factual review',
            initialTags: ['On time'])));
    expect(find.text('Edit your review'), findsOneWidget);
    expect(find.text('A factual review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

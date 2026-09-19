import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/book_flow.dart';
import 'package:homeowners_app/screens/booking_success_screen.dart';
import 'package:homeowners_app/utils/transaction_id.dart';
import 'package:homeowners_app/widgets/main_bottom_navigation.dart';
import 'package:homeowners_app/widgets/transaction_guard.dart';

void main() {
  test('transaction IDs are unique and namespaced', () {
    final first = TransactionId.create('booking');
    final second = TransactionId.create('booking');

    expect(first, startsWith('booking-'));
    expect(second, startsWith('booking-'));
    expect(second, isNot(first));
  });

  testWidgets('back from booking success ends the flow at Browse',
      (tester) async {
    AppTabNavigation.requestedTab.value = null;
    addTearDown(() => AppTabNavigation.requestedTab.value = null);

    await tester.pumpWidget(const MaterialApp(home: _BookingRouteHarness()));
    await tester.tap(find.text('Start booking'));
    await tester.pumpAndSettle();

    expect(find.text('Booking confirmed!'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to browse'));
    await tester.pumpAndSettle();

    expect(find.text('Start booking'), findsOneWidget);
    expect(find.text('Booking confirmed!'), findsNothing);
    expect(AppTabNavigation.requestedTab.value, 1);
  });

  testWidgets('an in-flight transaction cannot be dismissed with Back',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: _TransactionGuardHarness()));
    await tester.tap(find.text('Start protected request'));
    await tester.pumpAndSettle();

    expect(find.text('Saving transaction'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Saving transaction'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('guests cannot enter booking flow pages', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _GuestBookingHarness()));

    await tester.tap(find.text('Try booking as guest'));
    await tester.pumpAndSettle();

    expect(find.text('Try booking as guest'), findsOneWidget);
    expect(find.textContaining('Step '), findsNothing);
  });
}

class _GuestBookingHarness extends StatelessWidget {
  const _GuestBookingHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const BookFlowScreen(
                pro: <String, dynamic>{
                  'name': 'Test Contractor',
                  'contractorId': 'contractor-1',
                },
              ),
            ),
          ),
          child: const Text('Try booking as guest'),
        ),
      ),
    );
  }
}

class _TransactionGuardHarness extends StatelessWidget {
  const _TransactionGuardHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const TransactionGuard(
                isProcessing: true,
                child: Scaffold(
                  body: Center(child: Text('Saving transaction')),
                ),
              ),
            ),
          ),
          child: const Text('Start protected request'),
        ),
      ),
    );
  }
}

class _BookingRouteHarness extends StatelessWidget {
  const _BookingRouteHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const BookingSuccessScreen(
                woNumber: 'TW-1001',
                contractorName: 'Test Contractor',
                service: 'Plumbing repair',
                price: r'$125',
              ),
            ),
          ),
          child: const Text('Start booking'),
        ),
      ),
    );
  }
}

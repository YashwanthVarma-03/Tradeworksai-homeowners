import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/utils/credit_rules.dart';

void main() {
  group('booking credit limits', () {
    test('upfront can use the full price but not more than balance', () {
      expect(
          CreditRules.bookingLimit(
              workOrderType: 'rate_card', price: 129, balance: 200),
          129);
      expect(
          CreditRules.bookingLimit(
              workOrderType: 'rate_card', price: 129, balance: 64.20),
          64.20);
    });

    test('cap approval booking is limited to the diagnostic', () {
      expect(
          CreditRules.bookingLimit(
              workOrderType: 'nte', price: 89, balance: 120),
          89);
    });

    test('free estimate cannot use credit at booking', () {
      expect(
          CreditRules.bookingLimit(
              workOrderType: 'quote_request', price: 0, balance: 64.20),
          0);
    });
  });

  test('typed credit is clamped while over-limit input remains detectable', () {
    expect(CreditRules.clampTyped('500', 64.20), 64.20);
    expect(CreditRules.overLimit('500', 64.20), isTrue);
    expect(CreditRules.clampTyped(r'$12.345', 64.20), 12.35);
  });

  test('approval credit uses the lesser of balance and total', () {
    expect(CreditRules.approvalLimit(total: 460, balance: 64.20), 64.20);
    expect(CreditRules.approvalLimit(total: 40, balance: 64.20), 40);
  });

  test('cancelled jobs return explicit credit or all applied credit', () {
    expect(
        CreditRules.returnedOnCancel({
          'status': 'cancelled',
          'creditsApplied': 50,
          'creditReturned': 20,
        }),
        20);
    expect(
        CreditRules.returnedOnCancel({
          'status': 'pro_no_show',
          'creditsApplied': 50,
        }),
        50);
    expect(
        CreditRules.returnedOnCancel({
          'status': 'completed',
          'creditsApplied': 50,
        }),
        0);
  });

  test('available balance follows the rewards contract key', () {
    expect(CreditRules.availableBalance({'availableBalance': '64.20'}), 64.20);
    expect(
        CreditRules.availableBalance({
          'data': {'service_credits': 11}
        }),
        11);
  });
}

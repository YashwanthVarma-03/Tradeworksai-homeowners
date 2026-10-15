import 'display_format.dart';
import 'work_order_status.dart';

/// How much credit a homeowner may apply, and where (decisions §7, settled
/// Oct 12). The homeowner chooses the amount and it takes effect at once —
/// there is no team step. Never more than the available balance.
class CreditRules {
  CreditRules._();

  static double _cents(double value) => (value * 100).roundToDouble() / 100;

  static double _min(double a, double b) => a < b ? a : b;

  static double _positive(double value) => value < 0 ? 0 : value;

  static double bookingLimit({
    required String workOrderType,
    required num? price,
    required double balance,
  }) {
    if (workOrderType == 'quote_request' || price == null || price <= 0) {
      return 0;
    }
    return _cents(_min(price.toDouble(), _positive(balance)));
  }

  static String bookingHelper({
    required String workOrderType,
    required num? price,
    required double balance,
  }) {
    if (workOrderType == 'quote_request') {
      return 'Free visit — you can apply credit when you accept the estimate.';
    }
    final limit = bookingLimit(
        workOrderType: workOrderType, price: price, balance: balance);
    final byBalance = price != null && balance < price;
    if (workOrderType == 'nte') {
      final why = byBalance ? 'your available balance' : 'the diagnostic fee';
      return 'Up to ${formatUsd(limit)} — $why. On a Cap Approval job, credit '
          'covers the diagnostic now. You can apply more when you approve '
          'the cap.';
    }
    final why = byBalance ? 'your available balance' : 'the full price';
    return 'Up to ${formatUsd(limit)} — $why.';
  }

  static double approvalLimit({
    required double total,
    required double balance,
  }) =>
      _cents(_min(_positive(total), _positive(balance)));

  static String approvalHelper({
    required double total,
    required double balance,
    required bool estimate,
  }) {
    final limit = approvalLimit(total: total, balance: balance);
    final why = balance < total
        ? 'your available balance'
        : estimate
            ? 'the estimate'
            : 'the cap';
    return 'Up to ${formatUsd(limit)} — $why.';
  }

  static double? _typed(String text) {
    final value =
        double.tryParse(text.trim().replaceAll(RegExp(r'[\$,\s]'), ''));
    return value == null || !value.isFinite ? null : value;
  }

  static double clampTyped(String text, double limit) {
    final typed = _typed(text);
    if (typed == null || typed <= 0 || limit <= 0) return 0;
    return _cents(_min(typed, limit));
  }

  static bool overLimit(String text, double limit) {
    final typed = _typed(text);
    return typed != null && _cents(typed) > limit;
  }

  static double? availableBalance(dynamic rewards) {
    if (rewards is! Map) return null;
    for (final key in const [
      'availableBalance',
      'available_balance',
      'balance',
      'availableCredits',
      'availableServiceCredits',
      'serviceCredits',
      'service_credits',
    ]) {
      final value = readAmount(rewards[key]);
      if (value != null && value >= 0) return value;
    }
    for (final key in const ['data', 'rewards', 'result']) {
      final nested = availableBalance(rewards[key]);
      if (nested != null) return nested;
    }
    return null;
  }

  static double _first(Map<String, dynamic> job, List<String> keys) {
    for (final key in keys) {
      final value = readAmount(job[key]);
      if (value != null) return value;
    }
    return 0;
  }

  static double creditsApplied(Map<String, dynamic> job) => _first(job, const [
        'creditsApplied',
        'credits_applied',
        'serviceCreditsApplied',
        'service_credits_applied',
      ]);

  static double creditReturned(Map<String, dynamic> job) => _first(job, const [
        'creditReturned',
        'credit_returned',
        'creditsReturned',
        'credits_returned',
      ]);

  static double returnedOnCancel(Map<String, dynamic> job) {
    if (!WorkOrderStatus.fromJob(job).isTerminalWithoutProgress) return 0;
    final returned = creditReturned(job);
    return returned > 0 ? returned : creditsApplied(job);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/utils/booking_timing.dart';
import 'package:homeowners_app/utils/transaction_id.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 10);
  Map<String, dynamic> slot(int hours, {int duration = 2}) => {
        'start': now.add(Duration(hours: hours)).toIso8601String(),
        'end': now.add(Duration(hours: hours + duration)).toIso8601String(),
      };
  test('standard preserves returned windows beyond 48 hours', () {
    final result = BookingTiming.eligible(
        [slot(72), slot(1, duration: 1), slot(-1)], 'standard',
        now: now);
    expect(result, [slot(1, duration: 1), slot(72)]);
  });
  test('urgent and emergency enforce their own deadline and sort real slots',
      () {
    final slots = [slot(25), slot(4), slot(3), slot(5), slot(-1)];
    expect(BookingTiming.eligible(slots, 'emergency', now: now),
        [slot(3), slot(4)]);
    expect(BookingTiming.eligible(slots, 'urgent', now: now),
        [slot(3), slot(4), slot(5)]);
  });
  test('malformed and zero-length windows cannot be reserved', () {
    expect(
        BookingTiming.eligible([
          {'start': 'bad'},
          slot(2, duration: 0)
        ], 'standard', now: now),
        isEmpty);
  });
  test('credit request identifiers satisfy the backend UUID contract', () {
    final values = List.generate(100, (_) => TransactionId.uuid());
    expect(values.toSet(), hasLength(100));
    for (final value in values) {
      expect(
          value,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    }
  });
}

import 'package:intl/intl.dart';

/// One wording for money and visit windows on the booking, bookings and
/// work-order screens (Batch 21). Prices always show cents.
final NumberFormat _usd =
    NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);

/// "$129.00", "$1,991.00".
String formatUsd(num amount) => _usd.format(amount);

/// Reads a money value sent as a number or a string ("129", "129.00",
/// "$129.00"). Null when there is no number in it.
double? readAmount(dynamic value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '') ?? '';
  if (text.isEmpty || text == '-' || text == '.') return null;
  return double.tryParse(text);
}

/// "8:00–10:00 AM" when both ends share AM/PM, otherwise
/// "10:00 AM–12:00 PM".
String formatWindow(DateTime start, DateTime? end) {
  String clock(DateTime t) => DateFormat('h:mm').format(t);
  String period(DateTime t) => t.hour >= 12 ? 'PM' : 'AM';
  if (end == null) return '${clock(start)} ${period(start)}';
  if (period(start) == period(end)) {
    return '${clock(start)}–${clock(end)} ${period(end)}';
  }
  return '${clock(start)} ${period(start)}–${clock(end)} ${period(end)}';
}

/// "Wed, Oct 14 · 8:00–10:00 AM".
String formatVisit(DateTime start, DateTime? end) =>
    '${DateFormat('EEE, MMM d').format(start)} · ${formatWindow(start, end)}';

import 'package:intl/intl.dart';

abstract final class BookingTiming {
  /// Preserve the wall clock supplied with the backend's timezone offset.
  static DateTime? wallClock(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}(?::\d{2})?)')
        .firstMatch(raw);
    return match == null ? null : DateTime.tryParse('${match[1]}T${match[2]}');
  }

  static String? label(String? startRaw, [String? endRaw]) {
    final start = wallClock(startRaw);
    if (start == null) return null;
    final end = wallClock(endRaw);
    final startTime = DateFormat('h:mm a').format(start);
    final range = end == null
        ? startTime
        : '$startTime – ${DateFormat('h:mm a').format(end)}';
    return '${DateFormat('EEE, MMM d').format(start)}, $range';
  }

  static int? hours(String tier) => switch (tier.toLowerCase()) {
        'urgent' => 24,
        'emergency' => 4,
        _ => null,
      };

  static DateTime? start(Map slot) => DateTime.tryParse(
      '${slot['start'] ?? slot['startsAt'] ?? slot['starts_at'] ?? ''}');
  static DateTime? end(Map slot) => DateTime.tryParse(
      '${slot['end'] ?? slot['endsAt'] ?? slot['ends_at'] ?? ''}');

  static List<Map<String, dynamic>> eligible(List<dynamic> slots, String tier,
      {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final limit = hours(tier);
    return slots
        .whereType<Map>()
        .where((slot) {
          final from = start(slot), to = end(slot);
          if (from == null ||
              to == null ||
              !from.isAfter(clock) ||
              !to.isAfter(from)) return false;
          if (limit != null)
            return !from.isAfter(clock.add(Duration(hours: limit)));
          return true; // The shared backend owns arrival-window duration.
        })
        .map((slot) => Map<String, dynamic>.from(slot))
        .toList()
      ..sort((a, b) => start(a)!.compareTo(start(b)!));
  }
}

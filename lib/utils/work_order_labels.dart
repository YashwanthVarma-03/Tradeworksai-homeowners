import 'package:intl/intl.dart';

import 'display_format.dart';

/// How Home, Inbox and Chat name a work order, its service, its pro and its
/// visit (Batch 21 Part A), so the three surfaces word a job the same way.

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

/// "WO-24152" — the only work-order ID format shown anywhere (decisions,
/// Part 2). Prefers the work-order number; empty when there is no id at all.
String workOrderLabel(Map<String, dynamic> job) {
  for (final key in const [
    'woNumber',
    'wo_number',
    'workOrderNumber',
    'work_order_number',
    'workOrderId',
    'work_order_id',
    'id',
  ]) {
    final raw = _text(job[key]).toUpperCase();
    if (raw.isEmpty) continue;
    if (raw.startsWith('WO-')) return raw;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) return 'WO-$digits';
  }
  return '';
}

/// The database id the work-order actions take.
int? workOrderDbId(Map<String, dynamic> job) => int.tryParse(
    _text(job['workOrderId'] ?? job['work_order_id'] ?? job['id']));

/// The service the homeowner booked ("AC repair"), falling back to its
/// category.
String jobServiceName(Map<String, dynamic> job) {
  for (final key in const [
    'serviceName',
    'service_name',
    'serviceCategory',
    'service_category',
    'title',
  ]) {
    final value = _text(job[key]);
    if (value.isNotEmpty) return value;
  }
  return 'Work order';
}

/// The pro's business name ("Alvarez Air & Heat").
String jobProName(Map<String, dynamic> job, [String fallback = 'Your pro']) {
  for (final node in [job['pro'], job['contractor']]) {
    if (node is Map) {
      for (final key in const ['businessName', 'business_name', 'name']) {
        final value = _text(node[key]);
        if (value.isNotEmpty) return value;
      }
    }
  }
  for (final key in const ['businessName', 'business_name', 'proName']) {
    final value = _text(job[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

DateTime? jobVisitStart(Map<String, dynamic> job) =>
    DateTime.tryParse(_text(job['scheduledStart'] ?? job['scheduled_start']));

DateTime? jobVisitEnd(Map<String, dynamic> job) =>
    DateTime.tryParse(_text(job['scheduledEnd'] ?? job['scheduled_end']));

/// "Wed, Oct 14, 1:00–3:00 PM". With [relativeDay], today and tomorrow read
/// "Today, 8:00–10:00 AM" / "Tomorrow, 8:00–10:00 AM".
String visitPhrase(DateTime start, DateTime? end,
    {bool relativeDay = false, DateTime? now}) {
  final s = start.toLocal();
  final e = end?.toLocal();
  final today = now ?? DateTime.now();
  final days = DateTime(s.year, s.month, s.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  final day = relativeDay && days == 0
      ? 'Today'
      : relativeDay && days == 1
          ? 'Tomorrow'
          : DateFormat('EEE, MMM d').format(s);
  return '$day, ${formatWindow(s, e)}';
}

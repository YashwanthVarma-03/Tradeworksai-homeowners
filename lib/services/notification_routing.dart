import 'package:flutter/foundation.dart';

enum NotificationDestination {
  capApproval,
  leaveReview,
  noShowReply,
  rescheduleProposal,
  jobMoney,
  rewards,
  chat,
  home,
  activity,
  workOrder,
}

/// Shared interpretation for feed rows and push payloads during alias rollout.
String notificationType(Map<String, dynamic> data) {
  final raw =
      '${data['type'] ?? data['notification_type'] ?? ''}'.toLowerCase();
  return switch (raw) {
    'cap_sent' => 'cap',
    'estimate_sent' => 'estimate',
    'booking_confirmed' ||
    'en_route' ||
    'in_progress' ||
    'rebooked' =>
      'status',
    'job_completed' => 'completed',
    'quote_ready' =>
      '${data['work_order_type'] ?? data['workOrderType'] ?? (data['work_order'] is Map ? data['work_order']['type'] : '')}'
              .toLowerCase()
              .contains(RegExp('estimate|quote'))
          ? 'estimate'
          : 'cap',
    'reschedule_proposed' ||
    'reschedule_responded' ||
    'reschedule_accepted' =>
      'reschedule',
    'expiring_soon' || 'credits_earned' || 'credits_applied' => 'credit',
    'upload_receipt' || 'receipt_required' => 'receipt',
    'leave_review' || 'review_requested' => 'review',
    'no_show_reported' || 'no_show_report' || 'noshow' => 'no_show',
    'new_message' => 'message',
    'status' ||
    'booking_cancelled' ||
    'reminder' ||
    'cap' ||
    'estimate' ||
    'reschedule' ||
    'receipt' ||
    'credit' ||
    'completed' ||
    'message' ||
    'review' ||
    'no_show' =>
      raw,
    _ => 'status',
  };
}

bool notificationWaiting(Map<String, dynamic> data) =>
    const ['true', '1'].contains(
        '${data['waiting_on_you'] ?? data['waitingOnYou']}'.toLowerCase());

bool notificationIsAction(Map<String, dynamic> data) {
  final raw =
      '${data['type'] ?? data['notification_type'] ?? ''}'.toLowerCase();
  if (const [
    'reschedule_responded',
    'reschedule_accepted',
    'credits_earned',
    'credits_applied'
  ].contains(raw)) return false;
  final type = notificationType(data);
  if (type == 'receipt') {
    return notificationWaiting(data) ||
        '${data['title'] ?? ''}'.toLowerCase().contains('upload') ||
        const ['upload_receipt', 'receipt_required'].contains(raw) ||
        const ['upload_receipt', 'receipt_upload'].contains(data['action']);
  }
  return const ['cap', 'estimate', 'reschedule', 'review', 'no_show', 'message']
      .contains(type);
}

@immutable
class NotificationRouteData {
  const NotificationRouteData({
    required this.type,
    required this.id,
    required this.destination,
    this.contractorName,
  });

  final String type;
  final String id;
  final NotificationDestination destination;
  final String? contractorName;

  int? get workOrderId => int.tryParse(id);

  factory NotificationRouteData.fromData(Map<String, dynamic> data,
      {bool fromActivity = false}) {
    String text(dynamic value) {
      final result = value?.toString().trim() ?? '';
      return result.toLowerCase() == 'null' ? '' : result;
    }

    final type = notificationType(data);
    final action = notificationIsAction(data);
    final waiting = notificationWaiting(data);
    final resolved =
        data.containsKey('waiting_on_you') || data.containsKey('waitingOnYou');
    final candidate = !action || (resolved && !waiting && type != 'message')
        ? (fromActivity && action
            ? NotificationDestination.workOrder
            : NotificationDestination.activity)
        : switch (type) {
            'cap' || 'estimate' => NotificationDestination.capApproval,
            'reschedule' => NotificationDestination.rescheduleProposal,
            'receipt' => NotificationDestination.jobMoney,
            'review' => NotificationDestination.leaveReview,
            'no_show' => NotificationDestination.noShowReply,
            'message' => NotificationDestination.chat,
            _ => NotificationDestination.activity,
          };
    final id = candidate == NotificationDestination.chat
        ? text(data['channel_id'] ?? data['channelId'])
        : text(data['work_order_id'] ?? data['workOrderId']);
    final needsChannel = candidate == NotificationDestination.chat;
    final needsWorkOrder = candidate != NotificationDestination.chat &&
        candidate != NotificationDestination.rewards &&
        candidate != NotificationDestination.home;
    // `id` on an Activity row identifies the notification, not its work order.
    final invalidChannel = id.isEmpty ||
        (id.contains(':') && (id.startsWith(':') || id.endsWith(':')));
    final destination = (needsChannel && invalidChannel) ||
            (needsWorkOrder && (int.tryParse(id) ?? 0) <= 0)
        ? NotificationDestination.activity
        : candidate;
    final name = text(data['contractor_name'] ?? data['contractorName']);
    return NotificationRouteData(
      type: type,
      id: id,
      destination: destination,
      contractorName: name.isEmpty ? null : name,
    );
  }
}

class NotificationNavigation {
  NotificationNavigation._();

  static final ValueNotifier<NotificationRouteData?> requestedRoute =
      ValueNotifier<NotificationRouteData?>(null);

  static void request(Map<String, dynamic> data) {
    requestedRoute.value = NotificationRouteData.fromData(data);
  }
}

/// Prevents old feed rows from producing alerts when a session first opens.
/// Only server rows with durable IDs can be treated as newly arrived.
class ActivityArrivalTracker {
  Set<String>? _seenIds;

  List<Map<String, dynamic>> takeNew(List<Map<String, dynamic>> rows) {
    final ids = rows
        .map((row) => row['id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final seen = _seenIds;
    _seenIds = {...?seen, ...ids};
    if (seen == null) return const [];
    return rows.where((row) {
      final id = row['id']?.toString().trim() ?? '';
      return id.isNotEmpty && !seen.contains(id);
    }).toList();
  }

  void reset() => _seenIds = null;
}

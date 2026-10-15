import 'package:flutter/foundation.dart';

enum NotificationDestination {
  capApproval,
  rescheduleProposal,
  jobMoney,
  rewards,
  chat,
  home,
  activity,
  workOrder,
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

  factory NotificationRouteData.fromData(Map<String, dynamic> data) {
    String text(dynamic value) {
      final result = value?.toString().trim() ?? '';
      return result.toLowerCase() == 'null' ? '' : result;
    }

    final type = text(data['type'] ?? data['notification_type']).toLowerCase();
    final candidate = switch (type) {
      'cap' => NotificationDestination.capApproval,
      'reschedule' => NotificationDestination.rescheduleProposal,
      'receipt' || 'expiring_soon' => NotificationDestination.rewards,
      'message' => NotificationDestination.chat,
      'promo' || 'promotion' => NotificationDestination.home,
      _ => NotificationDestination.workOrder,
    };
    final id = candidate == NotificationDestination.chat
        ? text(data['channel_id'] ?? data['channelId'] ?? data['id'])
        : text(data['work_order_id'] ?? data['workOrderId'] ?? data['id']);
    final needsChannel = candidate == NotificationDestination.chat;
    final needsWorkOrder = candidate != NotificationDestination.chat &&
        candidate != NotificationDestination.rewards &&
        candidate != NotificationDestination.home;
    final destination = (needsChannel && id.isEmpty) ||
            (needsWorkOrder && int.tryParse(id) == null)
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

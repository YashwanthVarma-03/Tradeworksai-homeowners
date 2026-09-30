import 'work_order_status.dart';

class ArrivalCheckState {
  static const fallbackGrace = Duration(hours: 2);
  static bool pending(Map<String, dynamic> job, {DateTime? now}) {
    final status = WorkOrderStatus.fromJob(job);
    if (status.state == WorkOrderState.completed ||
        status.isTerminalWithoutProgress) return false;
    if (job['pendingArrivalCheck'] is bool)
      return job['pendingArrivalCheck'] as bool;
    if (job['arrivalCheckResolvedAt'] != null ||
        job['arrivalCheckAnswer'] != null) return false;
    final end =
        DateTime.tryParse('${job['scheduledEnd'] ?? job['scheduled_end']}');
    return end != null &&
        (now ?? DateTime.now()).isAfter(end.add(fallbackGrace));
  }

  static String identity(Map<String, dynamic> job) =>
      '${job['workOrderId'] ?? job['id']}:${job['arrivalCheckId'] ?? job['scheduledEnd'] ?? job['scheduled_end'] ?? ''}';
}

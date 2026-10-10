import 'work_order_status.dart';

class ArrivalCheckState {
  /// Starts at the end of the booked window (Oct 1). Any grace period is
  /// still open gap G-05; change it here only.
  static const fallbackGrace = Duration.zero;

  /// A no-show can only be reported while the job is still Booked — the pro
  /// has not tapped En route or In progress (Oct 1).
  static bool pending(Map<String, dynamic> job, {DateTime? now}) {
    final status = WorkOrderStatus.fromJob(job);
    if (status.state != WorkOrderState.booked) return false;
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

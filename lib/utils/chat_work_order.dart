import '../services/stream_service.dart';
import 'work_order_labels.dart';

/// Match explicit contractor user IDs only. Business names are not identities.
bool isWorkOrderWithPro(Map<String, dynamic> job, String contractorUserId) {
  if (contractorUserId.trim().isEmpty) return false;
  for (final node in [job['pro'], job['contractor']]) {
    if (node is Map &&
        StreamService.instance.resolveMessagingUserId(
              Map<String, dynamic>.from(node),
            ) ==
            contractorUserId) {
      return true;
    }
  }
  return const [
    'chatUserId',
    'chat_user_id',
    'streamUserId',
    'stream_user_id',
    'contractorUserId',
    'contractor_user_id',
    'assignedContractorUserId',
    'assigned_contractor_user_id',
  ].any((key) => '${job[key] ?? ''}' == contractorUserId);
}

List<Map<String, dynamic>> chatWorkOrders(
    Map<String, dynamic> data, String contractorUserId) {
  final jobs = <Map<String, dynamic>>[];
  final seen = <int>{};
  final tabs = data['tabs'];
  if (tabs is! Map) return jobs;
  for (final rows in tabs.values.whereType<List>()) {
    for (final row in rows.whereType<Map>()) {
      final job = Map<String, dynamic>.from(row);
      final id = workOrderDbId(job);
      if (id != null &&
          id > 0 &&
          isWorkOrderWithPro(job, contractorUserId) &&
          seen.add(id)) {
        jobs.add(job);
      }
    }
  }
  return jobs;
}

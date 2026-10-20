import '../screens/work_orders/no_show_reply.dart';
import 'work_order_status.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/work_orders/cap_approval.dart';
import '../screens/work_orders/reschedule_proposal.dart';
import '../screens/work_orders/work_order_detail.dart';
import '../services/homeowner_service.dart';
import '../services/notification_routing.dart';
import 'waiting_on_you.dart';

Future<bool> openNotificationRoute(
  BuildContext context,
  NotificationRouteData route,
) async {
  if (route.destination == NotificationDestination.rewards ||
      route.destination == NotificationDestination.home ||
      route.destination == NotificationDestination.activity) {
    return false;
  }

  if (route.destination == NotificationDestination.chat) {
    if (route.id.isEmpty) return false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen.forChannel(
          channelId: route.id,
          contractorName: route.contractorName ?? 'Messages',
        ),
      ),
    );
    return true;
  }

  final workOrderId = route.workOrderId;
  if (workOrderId == null) return false;
  final job = await HomeownerService.instance
      .findWorkOrder(workOrderId, forceRefresh: true);
  if (!context.mounted) return false;

  Widget screen;
  switch (route.destination) {
    case NotificationDestination.capApproval:
      screen = WorkOrderStatus.capPending(job)
          ? CapApprovalScreen(job: job)
          : WorkOrderDetailScreen(job: job);
    case NotificationDestination.rescheduleProposal:
      final proposal = WaitingOnYou.rescheduleProposal(job);
      screen = proposal == null
          ? WorkOrderDetailScreen(job: job)
          : RescheduleProposalScreen(job: job, proposal: proposal);
    case NotificationDestination.jobMoney:
      screen = WorkOrderDetailScreen(job: job, focusMoney: true);
    case NotificationDestination.leaveReview:
      screen = WorkOrderDetailScreen(job: job, openReview: true);
    case NotificationDestination.noShowReply:
      screen = NoShowReplyScreen(job: job);
    case NotificationDestination.workOrder:
      screen = WorkOrderDetailScreen(job: job);
    case NotificationDestination.rewards:
    case NotificationDestination.chat:
    case NotificationDestination.home:
    case NotificationDestination.activity:
      return false;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );
  return true;
}

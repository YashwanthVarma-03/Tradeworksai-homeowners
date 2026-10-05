import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/display_format.dart';
import '../../utils/pro_messaging.dart';
import '../../utils/waiting_on_you.dart';
import '../../utils/work_order_labels.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';
import 'reschedule_work_order.dart' show jobUrgencyLevel;

/// A pro asked to move a Booked visit (E02; Sep 30). The homeowner accepts or
/// declines in the app. Until then the original window stands and the
/// proposed one is held; a decline (or no answer) keeps the original time.
/// Needs backend G-28: `reschedule_proposal` on the work order and the
/// `respond_reschedule` action.
class RescheduleProposalScreen extends StatefulWidget {
  const RescheduleProposalScreen({
    super.key,
    required this.job,
    required this.proposal,
  });

  final Map<String, dynamic> job;
  final RescheduleProposal proposal;

  @override
  State<RescheduleProposalScreen> createState() =>
      _RescheduleProposalScreenState();
}

class _RescheduleProposalScreenState extends State<RescheduleProposalScreen> {
  bool _responding = false;

  Future<void> _respond({required bool accept}) async {
    final id = workOrderDbId(widget.job);
    if (id == null || _responding) return;
    setState(() => _responding = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: id,
        action: 'respond_reschedule',
        extra: {
          'response': accept ? 'accept' : 'decline',
          if (widget.proposal.id != null) 'proposalId': widget.proposal.id,
        },
      );
      if (!mounted) return;
      AppNotification.showSuccess(
        context,
        accept
            ? 'Your visit has moved to the new time.'
            : 'Your original time stands.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _responding = false);
      AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t send your answer. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final pro = jobProName(job);
    final bookedStart = jobVisitStart(job)?.toLocal();
    final bookedEnd = jobVisitEnd(job)?.toLocal();
    final proposedStart = widget.proposal.start.toLocal();
    final proposedEnd = widget.proposal.end?.toLocal();
    final title = [jobServiceName(job), workOrderLabel(job)]
        .where((part) => part.isNotEmpty)
        .join(' · ');

    return TransactionGuard(
      isProcessing: _responding,
      blockedMessage: 'Please wait while your answer is being sent.',
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppTheme.navy,
          title: Text(
            'Reschedule booking',
            style: AppTheme.headingStyle
                .copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppTheme.cardBorder),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const WaitingOnYouMark(),
                  Text(
                    jobUrgencyLevel(job),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ProTile(name: pro),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '$pro asked to move your visit to '
                      '${visitPhrase(proposedStart, proposedEnd)}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(height: 27 / 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    if (bookedStart != null) ...[
                      _timeRow(
                        icon: Icons.calendar_today_outlined,
                        well: AppTheme.subtle,
                        iconColor: AppTheme.navy,
                        label: 'Your booked time',
                        value: formatVisit(bookedStart, bookedEnd),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppTheme.cardBorder),
                      const SizedBox(height: 14),
                    ],
                    _timeRow(
                      icon: Icons.event_available_outlined,
                      well: AppTheme.blueTint,
                      iconColor: AppTheme.blue,
                      label: 'Proposed time',
                      value: formatVisit(proposedStart, proposedEnd),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                bookedStart == null
                    ? 'Your original time stands until you accept.'
                    : 'Your original time stands until you accept. If you '
                        'decline, you keep ${visitPhrase(bookedStart, bookedEnd)}.',
                style: const TextStyle(
                  color: AppTheme.body,
                  fontSize: 15,
                  height: 23 / 15,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _responding
                      ? null
                      : () => openProThread(context, job, proName: pro),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text('Message $pro'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.cardBorder)),
            boxShadow: AppTheme.floatShadow,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed:
                        _responding ? null : () => _respond(accept: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _responding ? null : () => _respond(accept: true),
                      child: _responding
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: AppTheme.onOrange, strokeWidth: 2),
                            )
                          : const Text('Accept new time'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeRow({
    required IconData icon,
    required Color well,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: well, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pro initials on a navy tile, 12px radius (design standard rule 10).
class _ProTile extends StatelessWidget {
  const _ProTile({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) =>
            part.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(part[0]))
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        initials.isEmpty ? 'P' : initials,
        style: AppTheme.headingStyle.copyWith(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

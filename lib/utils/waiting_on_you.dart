import 'display_format.dart';
import 'work_order_labels.dart';
import 'work_order_status.dart';

/// What the homeowner owes, in the order Home shows it (A03 puts a pro's
/// reschedule proposal first; A01 the cap, then the receipt).
enum WaitingKind { reschedule, cap, estimate, receipt }

class WaitingItem {
  const WaitingItem({
    required this.kind,
    required this.job,
    required this.title,
    required this.activityTitle,
    required this.detail,
    required this.action,
    this.amount,
    this.since,
    this.proposalId,
  });

  final WaitingKind kind;
  final Map<String, dynamic> job;

  /// Home's bold line: "Alvarez Air & Heat sent a cap for AC repair".
  final String title;

  /// Inbox › Activity's line: "Alvarez Air & Heat sent a cap of $460.00 for
  /// AC repair" (A08b).
  final String activityTitle;

  /// Home's one sentence: "$460.00 not-to-exceed · WO-24152".
  final String detail;

  /// Blue text action on Home: "Review the cap", "Review the estimate",
  /// "Upload receipt". A reschedule shows Accept / Decline instead.
  final String action;

  /// Cap or estimate amount, or the credits the receipt earns.
  final double? amount;

  /// When it started waiting — orders Inbox › Activity.
  final DateTime? since;

  /// The pro's proposal id, sent back with Accept / Decline.
  final String? proposalId;
}

/// A pro's proposed new window (Sep 30). Needs backend G-28.
class RescheduleProposal {
  const RescheduleProposal(
      {this.id, required this.start, this.end, this.createdAt});
  final String? id;
  final DateTime start;
  final DateTime? end;
  final DateTime? createdAt;
}

class WaitingOnYou {
  WaitingOnYou._();

  static String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  static DateTime? _date(dynamic value) => DateTime.tryParse(_text(value));

  /// Every waiting item across [jobs], one per work order, ordered by kind.
  static List<WaitingItem> itemsFrom(Iterable<dynamic> jobs) {
    final items = <WaitingItem>[];
    final seen = <String>{};
    for (final raw in jobs) {
      if (raw is! Map) continue;
      final job = Map<String, dynamic>.from(raw);
      final key = workOrderLabel(job);
      if (key.isNotEmpty && !seen.add(key)) continue;
      final item = itemFor(job);
      if (item != null) items.add(item);
    }
    items.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return items;
  }

  /// A pending proposal from the pro, or null. Only Booked jobs can be moved
  /// (Sep 30), and only the pro's own proposals wait on the homeowner.
  static RescheduleProposal? rescheduleProposal(Map<String, dynamic> job) {
    final raw = job['rescheduleProposal'] ?? job['reschedule_proposal'];
    if (raw is! Map) return null;
    final by = _text(raw['proposedBy'] ?? raw['proposed_by']).toLowerCase();
    final state = _text(raw['status'], 'pending').toLowerCase();
    final start = _date(raw['proposedStart'] ?? raw['proposed_start']);
    if ((by != 'pro' && by != 'contractor') ||
        state != 'pending' ||
        start == null) {
      return null;
    }
    final id = _text(raw['id']);
    return RescheduleProposal(
      id: id.isEmpty ? null : id,
      start: start,
      end: _date(raw['proposedEnd'] ?? raw['proposed_end']),
      createdAt: _date(raw['createdAt'] ?? raw['created_at']),
    );
  }

  /// The submitted cap (or estimate) amount, when the payload carries one.
  static double? capAmount(Map<String, dynamic> job) {
    final quote = job['quote'] is Map
        ? Map<String, dynamic>.from(job['quote'] as Map)
        : const <String, dynamic>{};
    final amount = readAmount(job['capAmount'] ??
        job['cap_amount'] ??
        job['quoteCap'] ??
        job['quote_cap'] ??
        job['quoteAmount'] ??
        job['quote_amount'] ??
        job['nteAmount'] ??
        job['nte_amount'] ??
        quote['total'] ??
        quote['totalNTE'] ??
        job['estimateAmount'] ??
        job['estimate_amount']);
    return amount == null || amount <= 0 ? null : amount;
  }

  static WaitingItem? itemFor(Map<String, dynamic> job) {
    final status = WorkOrderStatus.fromJob(job);
    if (status.isTerminalWithoutProgress) return null;
    final wo = workOrderLabel(job);
    final service = jobServiceName(job);
    final pro = jobProName(job);
    String joined(List<String> parts) =>
        parts.where((p) => p.isNotEmpty).join(' · ');

    // 1. The pro asked to move a Booked visit (Sep 30). Needs backend G-28;
    //    nothing renders until `reschedule_proposal` is on the payload.
    final proposal = rescheduleProposal(job);
    if (proposal != null && status.state == WorkOrderState.booked) {
      final current = jobVisitStart(job);
      final stands = current == null
          ? ''
          : ' Your current time, ${visitPhrase(current, jobVisitEnd(job))}, stands until you accept.';
      final title =
          '$pro asked to move your visit to ${visitPhrase(proposal.start, proposal.end)}';
      return WaitingItem(
        kind: WaitingKind.reschedule,
        job: job,
        title: title,
        activityTitle: title,
        detail: '${joined([service, wo])}.$stands',
        action: 'Accept',
        since: proposal.createdAt,
        proposalId: proposal.id,
      );
    }

    // 2. A cap to review (Cap Approval) or an estimate to accept (Free
    //    estimate) — at any non-terminal state, In progress included (B2).
    if (WorkOrderStatus.capPending(job)) {
      final amount = capAmount(job);
      final since = _date(job['capSubmittedAt'] ??
          job['cap_submitted_at'] ??
          job['quoteSentAt'] ??
          job['quote_sent_at'] ??
          (job['timeline'] is Map
              ? (job['timeline'] as Map)['quoteSentAt']
              : null) ??
          job['updatedAt'] ??
          job['updated_at']);
      final type =
          _text(job['workOrderType'] ?? job['work_order_type']).toLowerCase();
      if (type == 'quote_request') {
        return WaitingItem(
          kind: WaitingKind.estimate,
          job: job,
          title: '$pro sent an estimate for $service',
          activityTitle: amount == null
              ? '$pro sent an estimate for $service'
              : '$pro sent an estimate of ${formatUsd(amount)} for $service',
          detail:
              joined([if (amount != null) '${formatUsd(amount)} estimate', wo]),
          action: 'Review the estimate',
          amount: amount,
          since: since,
        );
      }
      return WaitingItem(
        kind: WaitingKind.cap,
        job: job,
        title: '$pro sent a cap for $service',
        activityTitle: amount == null
            ? '$pro sent a cap for $service'
            : '$pro sent a cap of ${formatUsd(amount)} for $service',
        detail: joined(
            [if (amount != null) '${formatUsd(amount)} not-to-exceed', wo]),
        action: 'Review the cap',
        amount: amount,
        since: since,
      );
    }

    // 3. The paid receipt on a completed job (Oct 1, G-46). Not owed when
    //    credits covered the whole job (B2).
    if (WorkOrderStatus.receiptPending(job)) {
      final earns = readAmount(
          job['receiptRewardAmount'] ?? job['receipt_reward_amount']);
      final title = earns != null && earns > 0
          ? 'Upload your receipt for $service to earn ${formatUsd(earns)}'
          : 'Upload your receipt for $service';
      return WaitingItem(
        kind: WaitingKind.receipt,
        job: job,
        title: title,
        activityTitle: title,
        detail: joined([pro, wo]),
        action: 'Upload receipt',
        amount: earns,
        since: _date((job['timeline'] is Map
                ? (job['timeline'] as Map)['completedAt']
                : null) ??
            job['completedAt'] ??
            job['completed_at']),
      );
    }
    return null;
  }
}

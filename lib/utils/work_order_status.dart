import 'package:flutter/material.dart';

import '../theme.dart';

/// The only place in the app that decides what a work order's status is called
/// and what colour it renders in.
///
/// There are **four** states. All four are manual contractor taps and all four
/// are skippable — a pro may go straight from Booked to Completed, and the app
/// must render that without complaint.
///
///   Booked → En route → In progress → Completed
///
/// `Arrived`, `Wrapping up`, `Dispatched` and `Scheduled` are NOT states.
/// They arrive from the backend's older vocabulary and are mapped onto the four.
///
/// "Waiting on you" is an **overlay flag**, not a fifth state — a job can be
/// Booked *and* waiting on the homeowner to approve a cap. It is carried
/// separately on [WorkOrderStatus.waitingOnYou].
enum WorkOrderState {
  booked,
  enRoute,
  inProgress,
  completed,

  /// Cancelled or a no-show. Always labelled with whose, never bare.
  cancelledByYou,
  cancelledByPro,
  cancelled,
  noShowPro,
  noShowCustomer,
}

/// The shape drawn in front of a status word (v3.3 §4 Status).
enum StatusMarkKind {
  /// 8px solid dot: Waiting on you (amber), Cancelled / No-show (grey).
  dot,

  /// 8px blue dot with a 3px blue-tint halo: En route, In progress.
  ringedDot,

  /// 8px hollow ring, 1.5px #98A2B3: Booked (usually not shown).
  hollowDot,

  /// 14px check in greenMark: Completed.
  check,

  /// 14px clock: Urgent / Emergency (red), Standard (grey).
  clock,
}

/// How one status renders. v3.3 (Batch 20 Part B): a mark and the word,
/// 13/600, with no background and no border. One status per card or row.
class StatusChipStyle {
  /// The colour of the word.
  final Color foreground;

  /// Retained so older callers compile. Not drawn in v3.3.
  final Color background;

  /// Retained so older callers compile. Not drawn in v3.3.
  final Color border;

  /// Retained so older callers compile. v3.3 has no filled chip.
  final bool filled;

  /// The mark in front of the word.
  final StatusMarkKind kind;

  /// The mark's colour when it differs from the word's.
  final Color? mark;

  const StatusChipStyle({
    required this.foreground,
    required this.background,
    required this.border,
    this.filled = false,
    this.kind = StatusMarkKind.dot,
    this.mark,
  });

  Color get markColor => mark ?? foreground;
}

class WorkOrderStatus {
  final WorkOrderState state;

  /// True when the homeowner has something to do — approve a cap, answer an
  /// arrival prompt. Renders as its own amber chip beside the state chip.
  final bool waitingOnYou;

  const WorkOrderStatus(this.state, {this.waitingOnYou = false});

  /// The contractor's recorded on-site event. It is displayed separately
  /// from the four homeowner progress states.
  static bool proOnSite(Map<String, dynamic> job) {
    final raw = job['status']?.toString().trim().toLowerCase();
    return raw == 'arrived' || raw == 'on_site' || raw == 'on site';
  }

  /// Reads a raw backend status onto the four states.
  ///
  /// Unknown values fall back to [WorkOrderState.booked] rather than being
  /// shouted back at the homeowner as raw text.
  static WorkOrderStatus from(Object? rawStatus,
      {Object? rawFlags, Object? cancelledBy}) {
    final status = rawStatus?.toString().toLowerCase().trim() ?? '';

    final waiting = status.contains('quote') ||
        status.contains('review') ||
        status.contains('waiting') ||
        (rawFlags is Map &&
            (rawFlags['waitingOnYou'] == true ||
                rawFlags['pendingArrivalCheck'] == true)) ||
        (rawFlags is String && rawFlags.toLowerCase().contains('waiting'));

    if (status.contains('pro_no_show') || status.contains('provider_no_show')) {
      return const WorkOrderStatus(WorkOrderState.noShowPro);
    }
    if (status.contains('customer_no_show')) {
      return const WorkOrderStatus(WorkOrderState.noShowCustomer);
    }
    if (status.contains('cancel') || status.contains('declined')) {
      final actor = cancelledBy?.toString().toLowerCase();
      return WorkOrderStatus(switch (actor) {
        'homeowner' || 'customer' => WorkOrderState.cancelledByYou,
        'pro' || 'contractor' || 'provider' => WorkOrderState.cancelledByPro,
        _ => WorkOrderState.cancelled,
      });
    }
    if (status == 'completed' || status == 'complete') {
      return const WorkOrderStatus(WorkOrderState.completed);
    }
    // 'wrapping_up' was never a state. A pro wrapping up is still working.
    if (status == 'in_progress' || status == 'wrapping_up') {
      return WorkOrderStatus(WorkOrderState.inProgress, waitingOnYou: waiting);
    }
    // 'arrived' was never a state either. A pro who has arrived is en route
    // until they tap In progress.
    if (status == 'en_route' || status == 'arrived') {
      return WorkOrderStatus(WorkOrderState.enRoute, waitingOnYou: waiting);
    }
    // 'scheduled' is the backend's word for Booked.
    return WorkOrderStatus(WorkOrderState.booked, waitingOnYou: waiting);
  }

  /// The job's state plus what the homeowner owes. A submitted cap that is
  /// not yet approved is Waiting on you whatever state the pro has set, and
  /// so is the paid receipt on a completed job (Oct 1, G-46).
  static WorkOrderStatus fromJob(Map<String, dynamic> job) {
    final base = from(
      job['status'],
      rawFlags: job,
      cancelledBy:
          job['cancelledBy'] ?? job['cancelled_by'] ?? job['canceled_by'],
    );
    if (base.waitingOnYou || base.isTerminalWithoutProgress) return base;
    if (capPending(job) || receiptPending(job)) {
      return WorkOrderStatus(base.state, waitingOnYou: true);
    }
    return base;
  }

  static bool _present(dynamic value) {
    if (value == null) return false;
    if (value is Map) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    final text = value.toString().trim().toLowerCase();
    return text.isNotEmpty && text != 'null' && text != 'false';
  }

  /// True while the pro has sent a not-to-exceed cap that the homeowner has
  /// not approved or declined. Keyed on the cap, never on the job state: the
  /// pro may already have tapped In progress for the diagnostic (Oct 1).
  static bool capPending(Map<String, dynamic> job) {
    final status = '${job['status'] ?? ''}'.toLowerCase();
    if (status.contains('complete') ||
        status.contains('cancel') ||
        status.contains('no_show') ||
        status.contains('declined')) {
      return false;
    }
    final capStatus =
        '${job['capStatus'] ?? job['cap_status'] ?? job['quoteStatus'] ?? job['quote_status'] ?? ''}'
            .toLowerCase();
    if (capStatus.contains('approved') ||
        capStatus.contains('accepted') ||
        capStatus.contains('declined') ||
        capStatus.contains('rejected')) {
      return false;
    }
    final timeline = job['timeline'];
    if (_present(job['capApprovedAt']) ||
        _present(job['cap_approved_at']) ||
        (timeline is Map && _present(timeline['capApprovedAt']))) {
      return false;
    }
    return status == 'quote_sent' ||
        status == 'quote_provided' ||
        status == 'cap_review' ||
        status.contains('cap_pending') ||
        capStatus.contains('pending') ||
        capStatus.contains('sent') ||
        capStatus.contains('submitted') ||
        job['requiresCapApproval'] == true ||
        job['requires_cap_approval'] == true ||
        job['needsQuoteApproval'] == true ||
        job['needs_quote_approval'] == true;
  }

  /// A completed job whose paid receipt has not been uploaded. Not owed when
  /// credits covered the whole job — nothing was paid (Oct 1, G-46).
  static bool receiptPending(Map<String, dynamic> job) {
    final status = '${job['status'] ?? ''}'.toLowerCase();
    if (status != 'completed' && status != 'complete') return false;
    if (_present(job['receiptDocumentId']) ||
        _present(job['receipt_document_id']) ||
        _present(job['paidReceiptUrl']) ||
        _present(job['paid_receipt_url']) ||
        job['receiptUploaded'] == true ||
        job['receipt_uploaded'] == true) {
      return false;
    }
    final paid = job['paidAmount'] ?? job['paid_amount'];
    final paidNumber = paid is num ? paid : num.tryParse('${paid ?? ''}');
    return paidNumber != 0;
  }

  String get label {
    switch (state) {
      case WorkOrderState.booked:
        return 'Booked';
      case WorkOrderState.enRoute:
        return 'En route';
      case WorkOrderState.inProgress:
        return 'In progress';
      case WorkOrderState.completed:
        return 'Completed';
      case WorkOrderState.cancelledByYou:
        return 'You cancelled';
      case WorkOrderState.cancelledByPro:
        return 'Pro cancelled';
      case WorkOrderState.cancelled:
        return 'Cancelled';
      case WorkOrderState.noShowPro:
        return 'Pro didn\'t arrive';
      case WorkOrderState.noShowCustomer:
        return 'Reported as no-show';
    }
  }

  StatusChipStyle get chip {
    switch (state) {
      case WorkOrderState.booked:
        return const StatusChipStyle(
          foreground: AppTheme.textSecondary,
          background: AppTheme.white,
          border: AppTheme.textTertiary,
          kind: StatusMarkKind.hollowDot,
          mark: AppTheme.textTertiary,
        );
      case WorkOrderState.enRoute:
        return const StatusChipStyle(
          foreground: AppTheme.blue,
          background: AppTheme.blueTint,
          border: AppTheme.blue,
          kind: StatusMarkKind.ringedDot,
        );
      case WorkOrderState.inProgress:
        return const StatusChipStyle(
          foreground: AppTheme.blue,
          background: AppTheme.blueTint,
          border: AppTheme.blue,
          kind: StatusMarkKind.ringedDot,
        );
      case WorkOrderState.completed:
        return const StatusChipStyle(
          foreground: AppTheme.green,
          background: AppTheme.greenTint,
          border: AppTheme.green,
          kind: StatusMarkKind.check,
          mark: AppTheme.greenMark,
        );
      case WorkOrderState.cancelledByYou:
      case WorkOrderState.cancelledByPro:
      case WorkOrderState.cancelled:
      case WorkOrderState.noShowPro:
      case WorkOrderState.noShowCustomer:
        return const StatusChipStyle(
          foreground: AppTheme.textSecondary,
          background: AppTheme.white,
          border: AppTheme.textTertiary,
          kind: StatusMarkKind.dot,
          mark: AppTheme.textTertiary,
        );
    }
  }

  /// The amber "Waiting on you" mark. Always carries the words — never
  /// colour alone.
  static const StatusChipStyle waitingChip = StatusChipStyle(
    foreground: AppTheme.amber,
    background: AppTheme.amberTint,
    border: AppTheme.amber,
    kind: StatusMarkKind.dot,
  );

  /// Urgent / Emergency response: red clock + red word.
  static const StatusChipStyle urgentChip = StatusChipStyle(
    foreground: AppTheme.red,
    background: AppTheme.white,
    border: AppTheme.red,
    kind: StatusMarkKind.clock,
  );

  /// Standard response: grey clock + grey word.
  static const StatusChipStyle standardChip = StatusChipStyle(
    foreground: AppTheme.textSecondary,
    background: AppTheme.white,
    border: AppTheme.textTertiary,
    kind: StatusMarkKind.clock,
  );

  static const String waitingLabel = 'Waiting on you';

  /// The four states in order, for the detail screen's progression.
  /// This list is used nowhere else — a list row gets one chip, not a tracker.
  static const List<WorkOrderState> progression = [
    WorkOrderState.booked,
    WorkOrderState.enRoute,
    WorkOrderState.inProgress,
    WorkOrderState.completed,
  ];

  /// How far along the progression this job is, for the detail screen.
  /// Returns -1 for a cancelled or no-show job, which has no progression.
  int get progressionIndex => progression.indexOf(state);

  bool get isTerminalWithoutProgress => progressionIndex < 0;
}

/// One status. Use this everywhere a status is shown. v3.3: draws a mark
/// and the word (see [StatusMark]); the name is kept so callers don't change.
class WorkOrderStatusChip extends StatelessWidget {
  final WorkOrderStatus status;

  const WorkOrderStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return _chip(status.label, status.chip);
  }

  static Widget _chip(String label, StatusChipStyle style) {
    return StatusMark(label: label, style: style);
  }
}

/// The amber "Waiting on you" mark, rendered beside the state when the
/// homeowner has something to do.
class WaitingOnYouChip extends StatelessWidget {
  const WaitingOnYouChip({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkOrderStatusChip._chip(
      WorkOrderStatus.waitingLabel,
      WorkOrderStatus.waitingChip,
    );
  }
}

/// v3.3 status display (Batch 20 Part B): an 8px dot (or a 14px icon) and
/// the word, 13/600, no background, no border.
///
///   Waiting on you — amber dot
///   En route / In progress — blue dot with a 3px blue-tint halo
///   Booked — hollow grey ring (usually not shown)
///   Completed — green check + green word
///   Cancelled / No-show — grey dot
///   Urgent / Emergency — red clock + red word · Standard — grey clock
class StatusMark extends StatelessWidget {
  const StatusMark({
    super.key,
    required this.label,
    required this.style,
    this.fontSize = 13,
  });

  /// The mark for a work order's state.
  factory StatusMark.of(WorkOrderStatus status, {Key? key}) =>
      StatusMark(key: key, label: status.label, style: status.chip);

  /// The amber "Waiting on you" mark.
  const StatusMark.waiting({super.key, this.fontSize = 13})
      : label = WorkOrderStatus.waitingLabel,
        style = WorkOrderStatus.waitingChip;

  /// Response level: red clock for Urgent / Emergency, grey for Standard.
  factory StatusMark.urgency({
    Key? key,
    required bool urgent,
    String? label,
  }) =>
      StatusMark(
        key: key,
        label: label ?? (urgent ? 'Urgent' : 'Standard'),
        style:
            urgent ? WorkOrderStatus.urgentChip : WorkOrderStatus.standardChip,
      );

  final String label;
  final StatusChipStyle style;

  /// 13 in rows and cards; 14 where the mockup sets it larger.
  final double fontSize;

  Widget _mark() {
    final color = style.markColor;
    switch (style.kind) {
      case StatusMarkKind.check:
        return Icon(Icons.check_rounded, size: 14, color: color);
      case StatusMarkKind.clock:
        return Icon(Icons.schedule_rounded, size: 14, color: color);
      case StatusMarkKind.hollowDot:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        );
      case StatusMarkKind.ringedDot:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: AppTheme.blueTint, spreadRadius: 3),
            ],
          ),
        );
      case StatusMarkKind.dot:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mark(),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontInter,
                color: style.foreground,
                fontSize: fontSize,
                height: 18 / 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

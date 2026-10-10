import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/display_format.dart';
import '../../utils/waiting_on_you.dart';
import '../../utils/work_order_labels.dart';
import '../../utils/work_order_status.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/transaction_guard.dart';
import '../../ui/tw.dart';
import 'reschedule_proposal.dart';

/// The job's response level as the homeowner booked it: "Standard",
/// "Urgent" or "Emergency" (decisions §5).
String jobUrgencyLevel(Map<String, dynamic> job) {
  final raw =
      '${job['priority'] ?? job['urgency'] ?? job['urgencyLevel'] ?? job['urgency_level'] ?? job['serviceLevel'] ?? job['service_level'] ?? ''}'
          .toLowerCase();
  if (raw.contains('emergency')) return 'Emergency';
  if (raw.contains('urgent')) return 'Urgent';
  return 'Standard';
}

/// Opens rescheduling for a work order — the one entry point every booking
/// surface uses. Only Standard work orders, and only while Booked (Sep 30):
/// Urgent and Emergency are a 24-hour / 4-hour commitment. A pending proposal
/// from the pro opens for an answer (E02); otherwise the homeowner proposes a
/// new 2-hour window (E03).
Future<bool> openRescheduleWorkOrder(
    BuildContext context, Map<String, dynamic> job) async {
  final workOrderId = _workOrderId(job);
  if (workOrderId == 0) {
    AppNotification.showInfo(context, 'This booking cannot be rescheduled.');
    return false;
  }
  if (jobUrgencyLevel(job) != 'Standard') {
    AppNotification.showInfo(
      context,
      'Urgent and Emergency bookings can\'t be rescheduled — they\'re a '
      '24-hour or 4-hour commitment.',
    );
    return false;
  }
  if (WorkOrderStatus.fromJob(job).state != WorkOrderState.booked) {
    AppNotification.showInfo(
        context, 'Only a booked visit can be rescheduled.');
    return false;
  }

  final proposal = WaitingOnYou.rescheduleProposal(job);
  if (proposal != null) {
    return (await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                RescheduleProposalScreen(job: job, proposal: proposal),
          ),
        )) ??
        false;
  }

  var contractorId = _contractorId(job);
  contractorId ??= await HomeownerService.instance
      .resolveContractorIdForWorkOrder(workOrderId);
  if (!context.mounted) return false;
  if (contractorId == null) {
    AppNotification.showInfo(
      context,
      'Rescheduling is not available for this booking yet.',
    );
    return false;
  }

  return (await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RescheduleWorkOrderScreen(
            job: job,
            workOrderId: workOrderId,
            contractorId: contractorId!,
          ),
        ),
      )) ??
      false;
}

int _workOrderId(Map<String, dynamic> job) {
  for (final key in const ['workOrderId', 'id']) {
    final id = int.tryParse(job[key]?.toString() ?? '');
    if (id != null && id > 0) return id;
  }
  return 0;
}

String? _contractorId(Map<String, dynamic> job) {
  String? text(dynamic value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty || result.toLowerCase() == 'null'
        ? null
        : result;
  }

  final pro = job['pro'];
  final contractor = job['contractor'];
  for (final value in [
    job['contractorId'],
    job['contractor_id'],
    job['assignedContractorId'],
    job['assigned_contractor_id'],
    job['proId'],
    job['pro_id'],
    pro is Map ? pro['contractorId'] : null,
    pro is Map ? pro['contractor_id'] : null,
    pro is Map ? pro['id'] : null,
    contractor is Map ? contractor['id'] : null,
    contractor is Map ? contractor['contractorId'] : null,
    contractor is Map ? contractor['contractor_id'] : null,
  ]) {
    final id = text(value);
    if (id != null) return id;
  }
  return null;
}

class RescheduleWorkOrderScreen extends StatefulWidget {
  const RescheduleWorkOrderScreen({
    super.key,
    required this.job,
    required this.workOrderId,
    required this.contractorId,
    this.selectSlotOnly = false,
    this.capAmount,
  });

  final Map<String, dynamic> job;
  final int workOrderId;
  final String contractorId;

  /// Cap approval (E01b): pick the repair window and hand it back. Nothing is
  /// sent from here — the cap screen sends it with the approval (Oct 1, G-49).
  final bool selectSlotOnly;

  /// The cap being approved, for E01b's summary card. Null hides the line.
  final double? capAmount;

  @override
  State<RescheduleWorkOrderScreen> createState() =>
      _RescheduleWorkOrderScreenState();
}

class _RescheduleWorkOrderScreenState extends State<RescheduleWorkOrderScreen> {
  /// Up to four 2-hour options per day (decisions §5).
  static const int _windowsPerDay = 4;

  final TextEditingController _reasonController = TextEditingController();
  final Map<String, List<Map<String, dynamic>>> _slotsByDate = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _selectedDate;
  Map<String, dynamic>? _selectedSlot;

  Map<String, dynamic> get _job => widget.job;
  String get _pro => jobProName(_job);

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final availability =
          await HomeownerService.instance.getContractorAvailability(
        contractorId: widget.contractorId,
        fromDate: _dateKey(now),
        toDate: _dateKey(now.add(const Duration(days: 7))),
      );
      final booked = jobVisitStart(_job);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final rawSlot in availability['slots'] as List? ?? const []) {
        if (rawSlot is! Map) continue;
        final slot = Map<String, dynamic>.from(rawSlot);
        final start = DateTime.tryParse('${slot['start'] ?? ''}');
        final end = DateTime.tryParse('${slot['end'] ?? ''}');
        // A window is a real reservation on the pro's calendar: both ends,
        // in the future. The booked window itself is not an option.
        if (start == null ||
            end == null ||
            !end.isAfter(start) ||
            !start.isAfter(now)) {
          continue;
        }
        if (!widget.selectSlotOnly &&
            booked != null &&
            start.isAtSameMomentAs(booked)) {
          continue;
        }
        grouped.putIfAbsent(_dateKey(start.toLocal()), () => []).add(slot);
      }
      for (final day in grouped.values) {
        day.sort((a, b) => '${a['start']}'.compareTo('${b['start']}'));
        if (day.length > _windowsPerDay) {
          day.removeRange(_windowsPerDay, day.length);
        }
      }
      if (!mounted) return;
      final dates = grouped.keys.toList()..sort();
      setState(() {
        _slotsByDate
          ..clear()
          ..addAll(grouped);
        _selectedDate = dates.isEmpty ? null : dates.first;
        _selectedSlot = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We couldn\'t load $_pro\'s open times. Please try again.';
      });
    }
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    if (slot == null || _isSubmitting) return;
    if (widget.selectSlotOnly) {
      Navigator.pop(context, <String, String>{
        'start': slot['start'].toString(),
        'end': slot['end'].toString(),
      });
      return;
    }
    setState(() => _isSubmitting = true);
    final reason = _reasonController.text.trim();
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: widget.workOrderId,
        action: 'propose_reschedule',
        extra: {
          'proposedStart': slot['start']?.toString() ?? '',
          'proposedEnd': slot['end']?.toString() ?? '',
          // Optional (E03): sent only when the homeowner wrote one.
          if (reason.isNotEmpty) 'reason': reason,
          'contractorId': widget.contractorId,
          'requester_user_id': AuthService.instance.userId,
        },
      );
      if (!mounted) return;
      AppNotification.showSuccess(
        context,
        'Proposal sent. Your booked time stands until $_pro accepts.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppNotification.showError(
        context,
        error,
        fallback: 'We couldn\'t send your proposal. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _slotsByDate.keys.toList()..sort();
    final slots = _selectedDate == null
        ? const <Map<String, dynamic>>[]
        : _slotsByDate[_selectedDate] ?? const <Map<String, dynamic>>[];
    final ready = !_isLoading && _error == null && dates.isNotEmpty;
    return TransactionGuard(
      isProcessing: _isSubmitting,
      blockedMessage: 'Please wait while your proposal is being sent.',
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: TwAppBar(
          title:
              widget.selectSlotOnly ? 'Choose a time' : 'Reschedule booking',
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const SkeletonPage(layout: SkeletonLayout.cards)
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _loadAvailability)
                  : dates.isEmpty
                      ? _ErrorState(
                          message:
                              'No open times in the next 7 days. Message $_pro to find another time.',
                          onRetry: _loadAvailability,
                        )
                      : SingleChildScrollView(
                          child: TwPage(
                            top: TwSpace.s20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: widget.selectSlotOnly
                                  ? _repairWindowContent(dates, slots)
                                  : _proposalContent(dates, slots),
                            ),
                          ),
                        ),
        ),
        bottomNavigationBar: ready ? _actionBar() : null,
      ),
    );
  }

  /// E03: propose a new window for a Standard, Booked visit.
  List<Widget> _proposalContent(
      List<String> dates, List<Map<String, dynamic>> slots) {
    final bookedStart = jobVisitStart(_job)?.toLocal();
    final bookedEnd = jobVisitEnd(_job)?.toLocal();
    final title = [jobServiceName(_job), workOrderLabel(_job)]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    return [
      Text(title, style: _titleStyle),
      const SizedBox(height: TwSpace.s4),
      Text(
        'Choose a new 2-hour window from $_pro’s open time, then send your proposal.',
        style: _metaStyle,
      ),
      if (bookedStart != null) ...[
        const SizedBox(height: TwSpace.s16),
        TwFactPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your booked time',
                style: TwType.caption(color: AppTheme.body)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: TwSpace.s4),
              Text(formatVisit(bookedStart, bookedEnd), style: _titleStyle),
              const SizedBox(height: TwSpace.s4),
              Text(
                'It stands until $_pro accepts your new time.',
                style: TwType.meta(color: AppTheme.body),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: TwSpace.s28),
      Text('Select date', style: TwType.h2()),
      const SizedBox(height: TwSpace.s12),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: TwSpace.s8),
          itemBuilder: (_, index) {
            final date = dates[index];
            return TwPill(
              label: _dateLabel(date),
              selected: date == _selectedDate,
              onTap: () {
                if (!_isSubmitting) _selectDate(date);
              },
            );
          },
        ),
      ),
      const SizedBox(height: TwSpace.s28),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text('Select time', style: TwType.h2())),
          Text('2-hour windows', style: TwType.caption()),
        ],
      ),
      const SizedBox(height: TwSpace.s12),
      _windowGrid(slots),
      const SizedBox(height: TwSpace.s12),
      Text(
        'Times come from $_pro’s calendar. Pick another day to see more.',
        style: TwType.caption(),
      ),
      const SizedBox(height: TwSpace.s28),
      const TwFieldLabel('Reason for rescheduling (optional)'),
      TextField(
        controller: _reasonController,
        minLines: 3,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        style: TwType.body(color: AppTheme.navy),
        decoration: TwInputs.decoration(
          hint: 'Tell the pro why you need another time',
        ),
      ),
    ];
  }

  /// E01b: approving the cap books the repair window in the same step
  /// (Oct 1, G-49).
  List<Widget> _repairWindowContent(
      List<String> dates, List<Map<String, dynamic>> slots) {
    final cap = widget.capAmount;
    final service = jobServiceName(_job);
    final meta = [
      workOrderLabel(_job),
      if (cap != null) 'Cap ${formatUsd(cap)} not-to-exceed',
    ].where((part) => part.isNotEmpty).join(' · ');
    return [
      TwCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TwAvatar(name: _pro, size: 48),
                const SizedBox(width: TwSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$service · $_pro', style: _titleStyle),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(meta, style: _metaStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (cap != null) ...[
              const SizedBox(height: TwSpace.s12),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: TwSpace.s12),
              Text(
                'You’re approving a cap of ${formatUsd(cap)}',
                style: TwType.label(),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: TwSpace.s20),
      Text(
        'Pick a 2-hour window for the repair. It’s booked on $_pro’s calendar.',
        style: TwType.bodySm(),
      ),
      const SizedBox(height: TwSpace.s20),
      Text('Day', style: _labelStyle),
      const SizedBox(height: TwSpace.s8),
      SizedBox(
        height: TwDayTile.heightOf(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: TwSpace.s8),
          itemBuilder: (_, index) {
            final date = dates[index];
            final day = DateTime.parse(date);
            return TwDayTile(
              top: DateFormat('EEE').format(day),
              bottom: DateFormat('MMM d').format(day),
              selected: date == _selectedDate,
              onTap: () {
                if (!_isSubmitting) _selectDate(date);
              },
            );
          },
        ),
      ),
      const SizedBox(height: TwSpace.s20),
      if (_selectedDate != null) ...[
        Text('Window · ${_dateLabel(_selectedDate!)}', style: _labelStyle),
        const SizedBox(height: TwSpace.s8),
      ],
      _windowGrid(slots),
    ];
  }

  void _selectDate(String date) => setState(() {
        _selectedDate = date;
        _selectedSlot = null;
      });

  /// Two columns of "8:00–10:00 AM" windows; nothing preselected.
  Widget _windowGrid(List<Map<String, dynamic>> slots) {
    if (slots.isEmpty) {
      return Text('No open windows on this day.', style: _metaStyle);
    }
    // SPEC §1.4: two columns; one on Compact or at large text sizes.
    final perRow = TwLayout.stackRows(context) ? 1 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < slots.length; i += perRow) {
      rows.add(Padding(
        padding: EdgeInsets.only(
            bottom: i + perRow < slots.length ? TwSpace.s8 : 0),
        child: Row(
          children: [
            Expanded(child: _windowTile(slots[i])),
            if (perRow == 2) ...[
              const SizedBox(width: TwSpace.s8),
              Expanded(
                child: i + 1 < slots.length
                    ? _windowTile(slots[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _windowTile(Map<String, dynamic> slot) {
    final start = DateTime.parse('${slot['start']}').toLocal();
    final end = DateTime.parse('${slot['end']}').toLocal();
    final selected = slot['start'] == _selectedSlot?['start'];
    return SizedBox(
      width: double.infinity,
      child: TwPill(
        label: formatWindow(start, end),
        selected: selected,
        square: true,
        height: 48,
        onTap: () {
          if (!_isSubmitting) setState(() => _selectedSlot = slot);
        },
      ),
    );
  }

  Widget _actionBar() {
    return TwStickyBar(
      children: [
        TwPrimaryButton(
          label: widget.selectSlotOnly
              ? 'Approve cap and book'
              : 'Send proposal',
          onPressed: _selectedSlot == null || _isSubmitting ? null : _submit,
          loading: _isSubmitting,
        ),
      ],
    );
  }
}

TextStyle get _labelStyle => TwType.label();

TextStyle get _titleStyle => TwType.title();

TextStyle get _metaStyle => TwType.meta();

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: TwPage(
            top: TwSpace.s28,
            child: TwEmptyState(
              icon: Icons.event_busy_outlined,
              title: message,
              action: TwSecondaryButton(
                label: 'Try again',
                onPressed: onRetry,
                expand: false,
              ),
            ),
          ),
        ),
      );
}

/// "2026-10-14", in the phone's local time.
String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// "Wed, Oct 14".
String _dateLabel(String key) {
  final date = DateTime.tryParse(key);
  return date == null ? key : DateFormat('EEE, MMM d').format(date);
}

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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppTheme.navy,
          title: Text(
            widget.selectSlotOnly ? 'Choose a time' : 'Reschedule booking',
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
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          children: widget.selectSlotOnly
                              ? _repairWindowContent(dates, slots)
                              : _proposalContent(dates, slots),
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
      const SizedBox(height: 4),
      Text(
        'Choose a new 2-hour window from $_pro’s open time, then send your proposal.',
        style: _metaStyle,
      ),
      if (bookedStart != null) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.subtle,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your booked time',
                style: TextStyle(
                  color: AppTheme.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(formatVisit(bookedStart, bookedEnd), style: _titleStyle),
              const SizedBox(height: 4),
              Text(
                'It stands until $_pro accepts your new time.',
                style: const TextStyle(
                  color: AppTheme.body,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 28),
      Text('Select date', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final date = dates[index];
            return _choice(
              selected: date == _selectedDate,
              height: 44,
              radius: 22,
              onTap: () => _selectDate(date),
              child: Text(_dateLabel(date),
                  style: _choiceStyle(date == _selectedDate)),
            );
          },
        ),
      ),
      const SizedBox(height: 28),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text('Select time',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          const Text(
            '2-hour windows',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _windowGrid(slots),
      const SizedBox(height: 12),
      Text(
        'Times come from $_pro’s calendar. Pick another day to see more.',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 19 / 13,
        ),
      ),
      const SizedBox(height: 28),
      const Text('Reason for rescheduling (optional)', style: _labelStyle),
      const SizedBox(height: 8),
      TextField(
        controller: _reasonController,
        minLines: 3,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Tell the pro why you need another time',
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
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ProTile(name: _pro),
                const SizedBox(width: 12),
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
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 12),
              Text(
                'You’re approving a cap of ${formatUsd(cap)}',
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Pick a 2-hour window for the repair. It’s booked on $_pro’s calendar.',
        style: const TextStyle(color: AppTheme.body, fontSize: 16, height: 1.5),
      ),
      const SizedBox(height: 20),
      const Text('Day', style: _labelStyle),
      const SizedBox(height: 10),
      SizedBox(
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final date = dates[index];
            final day = DateTime.parse(date);
            final selected = date == _selectedDate;
            return _choice(
              selected: selected,
              width: 92,
              height: 60,
              onTap: () => _selectDate(date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('EEE').format(day),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(DateFormat('MMM d').format(day),
                      style: _choiceStyle(selected)),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      if (_selectedDate != null)
        Text('Window · ${_dateLabel(_selectedDate!)}', style: _labelStyle),
      const SizedBox(height: 10),
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
      return const Text('No open windows on this day.', style: _metaStyle);
    }
    final rows = <Widget>[];
    for (var i = 0; i < slots.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < slots.length ? 10 : 0),
        child: Row(
          children: [
            Expanded(child: _windowTile(slots[i])),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < slots.length
                  ? _windowTile(slots[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _windowTile(Map<String, dynamic> slot) {
    final start = DateTime.parse('${slot['start']}').toLocal();
    final end = DateTime.parse('${slot['end']}').toLocal();
    final selected = slot['start'] == _selectedSlot?['start'];
    return _choice(
      selected: selected,
      onTap: () => setState(() => _selectedSlot = slot),
      child: Text(formatWindow(start, end), style: _choiceStyle(selected)),
    );
  }

  /// v3.3 selection: blue border and tint when selected, grey border
  /// otherwise (design standard rule 4).
  Widget _choice({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    double height = 48,
    double? width,
    double radius = 12,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppTheme.blueTint : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? AppTheme.blue : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  TextStyle _choiceStyle(bool selected) => TextStyle(
        color: AppTheme.navy,
        fontSize: 15,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      );

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: AppTheme.floatShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedSlot == null || _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: AppTheme.onOrange, strokeWidth: 2),
                  )
                : Text(widget.selectSlotOnly
                    ? 'Approve cap and book'
                    : 'Send proposal'),
          ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  color: AppTheme.navy,
  fontWeight: FontWeight.w600,
  fontSize: 14,
);

const _titleStyle = TextStyle(
  color: AppTheme.navy,
  fontWeight: FontWeight.w600,
  fontSize: 16,
);

const _metaStyle = TextStyle(
  color: AppTheme.textSecondary,
  fontSize: 14,
  height: 20 / 14,
);

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_busy_outlined,
                size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
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

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';

/// Opens the one rescheduling experience used by every booking surface.
///
/// The caller only supplies the work-order payload; contractor resolution,
/// availability, and submitting the proposal live here so entry points cannot
/// drift into different rescheduling behavior or UI.
Future<bool> openRescheduleWorkOrder(
    BuildContext context, Map<String, dynamic> job) async {
  final workOrderId = _workOrderId(job);
  if (workOrderId == 0) {
    AppNotification.showInfo(context, 'This booking cannot be rescheduled.');
    return false;
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
  });

  final Map<String, dynamic> job;
  final int workOrderId;
  final String contractorId;

  /// Reuse availability selection for cap approval without sending a reschedule.
  final bool selectSlotOnly;

  @override
  State<RescheduleWorkOrderScreen> createState() =>
      _RescheduleWorkOrderScreenState();
}

class _RescheduleWorkOrderScreenState extends State<RescheduleWorkOrderScreen> {
  final TextEditingController _reasonController =
      TextEditingController(text: 'Homeowner requested reschedule');
  final Map<String, List<Map<String, dynamic>>> _slotsByDate = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _selectedDate;
  Map<String, dynamic>? _selectedSlot;

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
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final rawSlot in availability['slots'] as List? ?? const []) {
        if (rawSlot is! Map) continue;
        final slot = Map<String, dynamic>.from(rawSlot);
        final start = slot['start']?.toString() ?? '';
        if (widget.selectSlotOnly) {
          final startTime = DateTime.tryParse(start);
          final endTime = DateTime.tryParse(slot['end']?.toString() ?? '');
          if (startTime == null ||
              endTime == null ||
              !endTime.isAfter(startTime) ||
              !startTime.isAfter(now)) continue;
        }
        final date = start.split('T').first;
        if (DateTime.tryParse(date) == null) continue;
        grouped.putIfAbsent(date, () => []).add(slot);
      }
      if (!mounted) return;
      final dates = grouped.keys.toList()..sort();
      setState(() {
        _slotsByDate
          ..clear()
          ..addAll(grouped);
        _selectedDate = dates.isEmpty ? null : dates.first;
        _selectedSlot = dates.isEmpty ? null : grouped[dates.first]!.first;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We couldn\'t load alternate times. Please try again.';
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
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: widget.workOrderId,
        action: 'propose_reschedule',
        extra: {
          'proposedStart': slot['start']?.toString() ?? '',
          'proposedEnd': slot['end']?.toString() ?? '',
          'reason': _reasonController.text.trim().isEmpty
              ? 'Homeowner requested reschedule'
              : _reasonController.text.trim(),
          'contractorId': widget.contractorId,
          'requester_user_id': AuthService.instance.userId,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppNotification.showError(
        context,
        error,
        fallback: 'We couldn\'t send the reschedule request. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _slotsByDate.keys.toList()..sort();
    final slots = _selectedDate == null
        ? const <Map<String, dynamic>>[]
        : _slotsByDate[_selectedDate] ?? const <Map<String, dynamic>>[];
    return TransactionGuard(
      isProcessing: _isSubmitting,
      blockedMessage:
          'Please wait while your reschedule request is being sent.',
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppTheme.navy700,
          title: Text(
              widget.selectSlotOnly ? 'Choose a time' : 'Reschedule booking',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.orange500))
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _loadAvailability)
                  : dates.isEmpty
                      ? _ErrorState(
                          message:
                              'No alternate times are available in the next 7 days.',
                          onRetry: _loadAvailability,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          children: [
                            Text(
                              _serviceName(widget.job),
                              style: const TextStyle(
                                color: AppTheme.navy700,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                widget.selectSlotOnly
                                    ? 'Choose a time to include with your cap approval.'
                                    : 'Choose a new time, then send your request.',
                                style: const TextStyle(
                                    color: AppTheme.gray, fontSize: 13)),
                            const SizedBox(height: 24),
                            const Text('Select date', style: _labelStyle),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: dates.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, index) {
                                  final date = dates[index];
                                  final selected = date == _selectedDate;
                                  return ChoiceChip(
                                    label: Text(_dateLabel(date)),
                                    selected: selected,
                                    selectedColor: AppTheme.orange500,
                                    backgroundColor: AppTheme.pageAlt,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.navy700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    onSelected: (_) => setState(() {
                                      _selectedDate = date;
                                      _selectedSlot = _slotsByDate[date]!.first;
                                    }),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('Select time', style: _labelStyle),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: slots.map((slot) {
                                final selected = identical(
                                        slot, _selectedSlot) ||
                                    (slot['start'] == _selectedSlot?['start']);
                                return ChoiceChip(
                                  label: Text(_timeLabel(
                                      slot['start']?.toString() ?? '')),
                                  selected: selected,
                                  selectedColor: AppTheme.orange500,
                                  backgroundColor: AppTheme.pageAlt,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.navy700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _selectedSlot = slot),
                                );
                              }).toList(),
                            ),
                            if (!widget.selectSlotOnly) ...[
                              const SizedBox(height: 24),
                              const Text('Reason for rescheduling',
                                  style: _labelStyle),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _reasonController,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText:
                                      'Tell the pro why you need another time',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    _selectedSlot == null || _isSubmitting
                                        ? null
                                        : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.orange500,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : Text(
                                        widget.selectSlotOnly
                                            ? 'Use this time'
                                            : 'Send reschedule request',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  color: AppTheme.navy700,
  fontWeight: FontWeight.w800,
  fontSize: 14,
);

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
                size: 40, color: AppTheme.gray),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.navy700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ),
      );
}

String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

String _dateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _timeLabel(String value) {
  final time = DateTime.tryParse(value);
  if (time == null) return value;
  final hour =
      time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
}

String _serviceName(Map<String, dynamic> job) => (job['serviceCategory'] ??
        job['service_category'] ??
        job['serviceName'] ??
        job['service_name'] ??
        'Your service')
    .toString();

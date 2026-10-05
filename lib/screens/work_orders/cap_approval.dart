import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import 'package:intl/intl.dart';

import '../../utils/display_format.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/transaction_guard.dart';
import 'reschedule_work_order.dart';

/// The homeowner approves the pro's not-to-exceed cap.
///
/// The homeowner booked a diagnostic at an upfront price. The pro attended,
/// diagnosed the problem, and submitted a cap. Work cannot start until the
/// homeowner approves it here. The final price may be lower than the cap.
/// It can never be higher.
///
/// This screen shows only what the backend sent. It invents nothing. If the
/// cap amount is missing, it says so rather than displaying a number the
/// homeowner might approve.
class CapApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const CapApprovalScreen({super.key, required this.job});

  @override
  State<CapApprovalScreen> createState() => _CapApprovalScreenState();
}

class _CapApprovalScreenState extends State<CapApprovalScreen> {
  bool _isProcessing = false;
  bool _isChoosingSlot = false;
  Map<String, dynamic> get _quote => _asMap(widget.job['quote']);
  Map<String, dynamic> get _pro => _asMap(widget.job['pro']);

  Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.fromEntries(value.entries
          .where((entry) => entry.key is String)
          .map((entry) => MapEntry(entry.key as String, entry.value)))
      : const {};

  /// The cap amount, or null when the backend has not sent one.
  double? get _capAmount => _amountOrNull(
        widget.job['approvedCap'] ??
            widget.job['approved_cap'] ??
            widget.job['capAmount'] ??
            widget.job['cap_amount'] ??
            widget.job['quoteCap'] ??
            widget.job['quote_cap'] ??
            widget.job['quoteAmount'] ??
            widget.job['quote_amount'] ??
            _quote['total'] ??
            _quote['totalNTE'],
      );

  String? get _proName =>
      _readString(_pro['businessName']) ??
      _readString(_pro['business_name']) ??
      _readString(widget.job['proName']) ??
      _readString(widget.job['businessName']);

  String? get _serviceName =>
      _readString(widget.job['serviceName']) ??
      _readString(widget.job['service_name']) ??
      _readString(widget.job['serviceCategory']) ??
      _readString(widget.job['service_category']);

  /// "WO-24152" — the work-order number, never the database id.
  String? get _woNumber {
    final value = _readString(widget.job['woNumber']) ??
        _readString(widget.job['wo_number']) ??
        _readString(widget.job['workOrderNumber']) ??
        _readString(widget.job['work_order_number']);
    if (value == null) return null;
    return value.startsWith('#') ? value.substring(1) : value;
  }

  /// The diagnostic fee the homeowner booked, or null when not sent.
  double? get _diagnosticFee => _amountOrNull(
        widget.job['diagnosticFee'] ??
            widget.job['diagnostic_fee'] ??
            widget.job['diagnosticPrice'] ??
            widget.job['diagnostic_price'],
      );

  /// "Mon, Oct 12, 2:00–4:00 PM". Until the cap is approved, the job's
  /// scheduled window is the diagnostic visit.
  String? get _diagnosticVisit {
    final start = DateTime.tryParse(_readString(widget.job['diagnosticStart'] ??
            widget.job['diagnostic_start'] ??
            widget.job['scheduledStart'] ??
            widget.job['scheduled_start']) ??
        '');
    if (start == null) return null;
    final end = DateTime.tryParse(_readString(widget.job['diagnosticEnd'] ??
            widget.job['diagnostic_end'] ??
            widget.job['scheduledEnd'] ??
            widget.job['scheduled_end']) ??
        '');
    final local = start.toLocal();
    return '${DateFormat('EEE, MMM d').format(local)}, '
        '${formatWindow(local, end?.toLocal())}';
  }

  String? get _diagnosis =>
      _readString(widget.job['quoteScope']) ??
      _readString(widget.job['quote_scope']) ??
      _readString(_quote['diagnosis']) ??
      _readString(widget.job['diagnosis']);

  /// Line items as the pro entered them. Never synthesised.
  List<Map<String, dynamic>> get _lineItems {
    final raw = _quote['items'] ?? widget.job['capItems'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(_asMap)
        .where((item) => _readString(item['label'] ?? item['name']) != null)
        .toList();
  }

  Future<void> _approve() async {
    if (_isProcessing || _isChoosingSlot || _capAmount == null) return;
    if (_workOrderId() <= 0) {
      AppNotification.showInfo(context,
          'This work order is unavailable. Please reopen it from Bookings.');
      return;
    }
    setState(() => _isChoosingSlot = true);
    try {
      var contractorId = _readString(widget.job['contractorId']) ??
          _readString(widget.job['contractor_id']) ??
          _readString(_pro['contractorId']);
      contractorId ??= await HomeownerService.instance
          .resolveContractorIdForWorkOrder(_workOrderId());
      if (!mounted) return;
      if (contractorId == null) {
        throw Exception(
            'The pro is unavailable. Please reopen this work order.');
      }
      // Approving the cap books the repair in the same step (Oct 1, G-49).
      // The job's scheduled window is the diagnostic visit, never the
      // repair, so the homeowner always picks the repair window here.
      final slot = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
            builder: (_) => RescheduleWorkOrderScreen(
                  job: widget.job,
                  workOrderId: _workOrderId(),
                  contractorId: contractorId!,
                  selectSlotOnly: true,
                  capAmount: _capAmount,
                )),
      );
      if (!mounted || slot == null) return;
      final startsAt = slot['start'];
      final endsAt = slot['end'];
      if (!mounted) return;
      setState(() => _isProcessing = true);
      await HomeownerService.instance.respondToCap(
        workOrderId: _workOrderId(),
        accept: true,
        reason: 'homeowner_approved_cap',
        contractorId: contractorId,
        startsAt: startsAt,
        endsAt: endsAt,
      );

      if (mounted) {
        final repairStart = DateTime.tryParse(startsAt ?? '')?.toLocal();
        final repairEnd = DateTime.tryParse(endsAt ?? '')?.toLocal();
        AppNotification.showInfo(
          context,
          repairStart == null
              ? 'Cap approved. Your repair is booked.'
              : 'Cap approved. Your repair is booked for '
                  '${formatVisit(repairStart, repairEnd)}.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppNotification.showError(
          context,
          e,
          fallback: 'We couldn\'t approve this cap. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isChoosingSlot = false);
    }
  }

  Future<void> _decline() async {
    if (_isProcessing || _isChoosingSlot) return;
    final confirmed = await _confirmDecline();
    if (confirmed != true || !mounted || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      await HomeownerService.instance.respondToCap(
        workOrderId: _workOrderId(),
        accept: false,
        reason: 'homeowner_declined_cap',
      );
      if (mounted) {
        AppNotification.showInfo(context, 'Cap declined.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppNotification.showError(
          context,
          e,
          fallback: 'We couldn\'t decline this cap. Please try again.',
        );
      }
    }
  }

  Future<bool?> _confirmDecline() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.pageBackground,
        title: const Text(
          'Decline this cap?',
          style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Declining cancels this booking. You can message your pro if you want to '
          'discuss the price first.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep reviewing',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Decline',
              style: TextStyle(color: AppTheme.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cap = _capAmount;

    return TransactionGuard(
      isProcessing: _isProcessing,
      blockedMessage: 'Please wait while your response is being saved.',
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        body: Column(
          children: [
            _screenHeader('Approve the cap'),
            Expanded(
              child: SafeArea(
                top: false,
                child: cap == null
                    ? _missingCapState()
                    : Column(
                        children: [
                          Expanded(child: _capContent(cap)),
                          _actionBar(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when the backend has not sent a cap amount. There is nothing to
  /// approve, so no approve button is offered.
  Widget _missingCapState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This cap isn\'t ready yet',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your pro hasn\'t submitted a price for this job yet. You\'ll be '
            'notified as soon as they do.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _outlineButton(
            'Back',
            color: AppTheme.navy,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _capContent(double cap) {
    final items = _lineItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBanner(),
          const SizedBox(height: 22),
          if (_diagnosis != null || _proName != null) ...[
            _sectionLabel('What your pro found'),
            const SizedBox(height: 10),
            _diagnosisCard(),
            const SizedBox(height: 16),
          ],
          _capCard(cap),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionLabel('Breakdown'),
            const SizedBox(height: 14),
            for (final item in items) ...[
              _lineItem(
                _readString(item['label'] ?? item['name'])!,
                _amountOrNull(item['amount'] ?? item['total']),
              ),
              const SizedBox(height: 14),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1, color: AppTheme.cardBorder),
            ),
            const SizedBox(height: 14),
            _lineItem('Not to exceed', cap, isTotal: true),
          ],
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      decoration: const BoxDecoration(
        color: AppTheme.pageBackground,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: AppTheme.floatShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _primaryButton('Approve cap', _approve),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _isProcessing || _isChoosingSlot ? null : _decline,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.red,
                minimumSize: const Size(44, 44),
              ),
              child: const Text(
                'Decline this cap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _workOrderId() {
    for (final key in ['workOrderId', 'id']) {
      final id = int.tryParse(widget.job[key]?.toString() ?? '');
      if (id != null && id > 0) return id;
    }
    return 0;
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  /// Returns null rather than a made-up fallback.
  double? _amountOrNull(dynamic value) {
    double? amount;
    if (value is num) amount = value.toDouble();
    if (value is String) {
      final text = value.trim();
      if (!RegExp(r'^\$?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$')
          .hasMatch(text)) return null;
      amount = double.tryParse(text.replaceAll(RegExp(r'[\$,]'), ''));
    }
    return amount != null && amount.isFinite && amount >= 0 ? amount : null;
  }

  /// "$460.00" — cents always (Part B1).
  String _money(num amount) => formatUsd(amount);

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    return parts.map((part) => part[0]).take(2).join().toUpperCase();
  }

  Widget _screenHeader(String title) {
    return Container(
      width: double.infinity,
      height: 50 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppTheme.pageBackground,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.navy, size: 24),
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// v3.3 alert row: tinted icon circle, bold line, one sentence (E01).
  Widget _infoBanner() {
    return const AlertRow(
      icon: Icons.info_outline_rounded,
      tint: AppTheme.blueTint,
      iconColor: AppTheme.blue,
      title: 'You approve a not-to-exceed cap before work begins.',
      body: 'The final price may be lower — never higher.',
    );
  }

  /// Section heading: Outfit 20, sentence case — never all-caps (v3.3).
  Widget _sectionLabel(String text) {
    return Text(text, style: Theme.of(context).textTheme.headlineMedium);
  }

  /// Who sent the cap, for which job, what they found, and the diagnostic
  /// visit it follows (E01).
  Widget _diagnosisCard() {
    final proName = _proName;
    final diagnosis = _diagnosis;
    final meta = [_serviceName, _woNumber].whereType<String>().join(' · ');
    final visit = _diagnosticVisit;
    final fee = _diagnosticFee;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (proName != null)
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Text(
                    _initials(proName),
                    style: AppTheme.headingStyle.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (diagnosis != null) ...[
            if (proName != null) const SizedBox(height: 14),
            Text(
              diagnosis,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 15,
                height: 1.53,
              ),
            ),
          ],
          if (visit != null || fee != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit == null
                        ? 'Diagnostic visit'
                        : 'Diagnostic visit · $visit',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (fee != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _money(fee),
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _capCard(double cap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Not to exceed',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _money(cap),
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItem(String title, double? amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: isTotal ? 14.5 : 13,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
        if (amount != null)
          Text(
            _money(amount),
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing || _isChoosingSlot ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        child: _isProcessing || _isChoosingSlot
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }

  Widget _outlineButton(
    String label, {
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isProcessing ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }
}

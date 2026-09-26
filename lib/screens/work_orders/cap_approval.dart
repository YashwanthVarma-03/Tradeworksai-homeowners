import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
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
      var startsAt = _readString(
          widget.job['proposedStart'] ?? widget.job['scheduledStart']);
      var endsAt =
          _readString(widget.job['proposedEnd'] ?? widget.job['scheduledEnd']);
      final start = DateTime.tryParse(startsAt ?? '');
      final end = DateTime.tryParse(endsAt ?? '');
      // The current backend still books a slot on quote_accept. Ask for a
      // real available time when the work order has none; never invent one.
      if (start == null ||
          end == null ||
          !end.isAfter(start) ||
          !start.isAfter(DateTime.now())) {
        final slot = await Navigator.push<Map<String, String>>(
          context,
          MaterialPageRoute(
              builder: (_) => RescheduleWorkOrderScreen(
                    job: widget.job,
                    workOrderId: _workOrderId(),
                    contractorId: contractorId!,
                    selectSlotOnly: true,
                  )),
        );
        if (!mounted || slot == null) return;
        startsAt = slot['start'];
        endsAt = slot['end'];
      }
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
        AppNotification.showInfo(
          context,
          'Cap approved.',
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
                child: cap == null ? _missingCapState() : _capContent(cap),
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
          if (_diagnosis != null) ...[
            _sectionLabel('WHAT YOUR PRO FOUND'),
            const SizedBox(height: 10),
            _diagnosisCard(),
            const SizedBox(height: 16),
          ],
          _capCard(cap),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionLabel('BREAKDOWN'),
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
          const SizedBox(height: 24),
          _primaryButton('Approve cap', _approve),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _isProcessing || _isChoosingSlot ? null : _decline,
              child: const Text(
                'Decline this cap',
                style: TextStyle(
                  color: AppTheme.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
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

  String _money(num amount) =>
      '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

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

  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.blueTint,
        border: Border(left: BorderSide(color: AppTheme.blue, width: 4)),
      ),
      child: const Text(
        'Work can\'t start until you approve this cap. The final price may be '
        'lower than the cap. It can never be higher.',
        style: TextStyle(
          color: AppTheme.navy,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _diagnosisCard() {
    final proName = _proName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (proName != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: AppTheme.navy,
                  child: Text(
                    _initials(proName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    proName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Text(
            _diagnosis!,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
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
            'NOT TO EXCEED',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
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

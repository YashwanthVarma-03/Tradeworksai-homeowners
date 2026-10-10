import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import 'package:intl/intl.dart';

import '../../utils/display_format.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/transaction_guard.dart';
import '../../ui/tw.dart';
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
        title: Text('Decline this cap?', style: TwType.h3()),
        content: Text(
          'Declining cancels this booking. You can message your pro if you want to '
          'discuss the price first.',
          style: TwType.bodySm(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(
              'Keep reviewing',
              style: TwType.button(color: AppTheme.navy),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(
              'Decline',
              style: TwType.button(color: AppTheme.red),
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
        appBar: TwAppBar(
          title: 'Approve the cap',
          onBack: () {
            if (!_isProcessing) Navigator.pop(context);
          },
        ),
        body: cap == null
            ? SafeArea(top: false, child: _missingCapState())
            : Column(
                children: [
                  Expanded(child: _capContent(cap)),
                  _actionBar(),
                ],
              ),
      ),
    );
  }

  /// Shown when the backend has not sent a cap amount. There is nothing to
  /// approve, so no approve button is offered.
  Widget _missingCapState() {
    return SingleChildScrollView(
      child: TwPage(
        top: TwSpace.s40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This cap isn\'t ready yet', style: TwType.h2()),
            const SizedBox(height: TwSpace.s8),
            Text(
              'Your pro hasn\'t submitted a price for this job yet. You\'ll be '
              'notified as soon as they do.',
              style: TwType.bodySm(),
            ),
            const SizedBox(height: TwSpace.s20),
            TwSecondaryButton(
              label: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capContent(double cap) {
    final items = _lineItems;

    return SingleChildScrollView(
      child: TwPage(top: TwSpace.s20, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBanner(),
          const SizedBox(height: TwSpace.s28),
          if (_diagnosis != null || _proName != null) ...[
            _sectionLabel('What your pro found'),
            const SizedBox(height: TwSpace.s12),
            _diagnosisCard(),
            const SizedBox(height: TwSpace.s16),
          ],
          _capCard(cap),
          if (items.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s28),
            _sectionLabel('Breakdown'),
            const SizedBox(height: TwSpace.s4),
            for (final item in items)
              _lineItem(
                _readString(item['label'] ?? item['name'])!,
                _amountOrNull(item['amount'] ?? item['total']),
              ),
          ],
        ],
      )),
    );
  }

  Widget _actionBar() {
    final busy = _isProcessing || _isChoosingSlot;
    return TwStickyBar(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TwPrimaryButton(
              label: 'Approve cap',
              onPressed: busy ? null : _approve,
              loading: busy,
            ),
            const SizedBox(height: TwSpace.s4),
            Center(
              child: TwTextAction(
                label: 'Decline this cap',
                onPressed: busy ? null : _decline,
                destructive: true,
              ),
            ),
          ],
        ),
      ],
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
    return Text(text, style: TwType.h2());
  }

  /// Who sent the cap, for which job, what they found, and the diagnostic
  /// visit it follows (E01).
  Widget _diagnosisCard() {
    final proName = _proName;
    final diagnosis = _diagnosis;
    final meta = [_serviceName, _woNumber].whereType<String>().join(' · ');
    final visit = _diagnosticVisit;
    final fee = _diagnosticFee;
    final visitText =
        visit == null ? 'Diagnostic visit' : 'Diagnostic visit · $visit';
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (proName != null)
            Row(
              children: [
                TwAvatar(name: proName, size: 48),
                const SizedBox(width: TwSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TwType.title(),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(meta, style: TwType.meta()),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (diagnosis != null) ...[
            if (proName != null) const SizedBox(height: TwSpace.s12),
            Text(diagnosis, style: TwType.bodySm(color: AppTheme.navy)),
          ],
          if (visit != null || fee != null) ...[
            const SizedBox(height: TwSpace.s12),
            const Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: TwSpace.s12),
            if (TwLayout.stackRows(context))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visitText, style: TwType.meta()),
                  if (fee != null) ...[
                    const SizedBox(height: TwSpace.s4),
                    Text(_money(fee), style: TwType.label()),
                  ],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(visitText, style: TwType.meta())),
                  if (fee != null) ...[
                    const SizedBox(width: TwSpace.s12),
                    Text(_money(fee), style: TwType.label()),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _capCard(double cap) {
    return TwCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: TwSpace.s20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Text(
              'Not to exceed',
              textAlign: TextAlign.center,
              style: TwType.label(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _money(cap),
                maxLines: 1,
                style: TwType.number(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineItem(String title, double? amount, {bool isTotal = false}) {
    final titleStyle =
        isTotal ? TwType.title() : TwType.bodySm(color: AppTheme.navy);
    final amountStyle = isTotal ? TwType.title() : TwType.label();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: isTotal
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(title, style: titleStyle)),
          if (amount != null) ...[
            const SizedBox(width: TwSpace.s12),
            Text(_money(amount), style: amountStyle),
          ],
        ],
      ),
    );
  }
}

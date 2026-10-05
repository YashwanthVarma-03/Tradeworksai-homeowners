import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../utils/display_format.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_bottom_navigation.dart';
import 'chat_screen.dart';
import 'work_orders/work_order_detail.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String? woNumber;
  final String? scheduledStart;
  final String? scheduledEnd;
  final String? contractorName;
  final String? trade;
  final String? service;
  final String? address;
  final String? price;
  final String? contractorId;
  final Map<String, dynamic>? workOrder;

  const BookingSuccessScreen({
    super.key,
    this.woNumber,
    this.scheduledStart,
    this.scheduledEnd,
    this.contractorName,
    this.trade,
    this.service,
    this.address,
    this.price,
    this.contractorId,
    this.workOrder,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  bool _isOpeningWorkOrder = false;
  bool _exitRequested = false;

  String get _proName {
    final supplied = widget.contractorName?.trim() ?? '';
    if (supplied.isNotEmpty) return supplied;
    final pro =
        _asMap(widget.workOrder?['pro'] ?? widget.workOrder?['contractor']);
    return _text(
      pro['businessName'],
      _text(pro['business_name'], _text(widget.workOrder?['businessName'])),
    );
  }

  String get _contractorId {
    final supplied = widget.contractorId?.trim() ?? '';
    if (supplied.isNotEmpty) return supplied;
    return StreamService.instance.resolveMessagingUserId(widget.workOrder) ??
        '';
  }

  String get _serviceName => _text(
        widget.service,
        _text(
          widget.workOrder?['serviceCategory'],
          _text(widget.workOrder?['service_category']),
        ),
      );

  String get _address => _text(
        widget.address,
        _addressText(_asMap(widget.workOrder?['address'])),
      );

  String get _price {
    final raw = _text(widget.price, _workOrderPrice(widget.workOrder));
    final amount = readAmount(raw);
    return amount == null ? raw : formatUsd(amount);
  }

  double? get _creditsApplied => readAmount(
        widget.workOrder?['creditsApplied'] ??
            widget.workOrder?['credits_applied'] ??
            widget.workOrder?['serviceCreditsApplied'] ??
            widget.workOrder?['service_credits_applied'],
      );

  /// Only an Upfront-price booking knows its total when it's booked.
  double? get _youPay {
    final type = _text(widget.workOrder?['work_order_type'],
        _text(widget.workOrder?['workOrderType'], 'rate_card'));
    if (type != 'rate_card') return null;
    final amount = readAmount(_price);
    if (amount == null) return null;
    final due = amount - (_creditsApplied ?? 0);
    return due < 0 ? 0 : due;
  }

  /// The job's real level (Oct 1): Standard, Urgent or Emergency.
  String get _urgencyLabel {
    final p =
        '${widget.workOrder?['priority'] ?? widget.workOrder?['urgency'] ?? ''}'
            .toLowerCase();
    if (p.contains('emergency')) return 'Emergency';
    if (p.contains('urgent')) return 'Urgent';
    return 'Standard';
  }

  String get _woNumber {
    final value = widget.woNumber?.trim() ?? '';
    return value.startsWith('#') ? value.substring(1) : value;
  }

  String get _start => _text(
        widget.scheduledStart,
        _text(widget.workOrder?['scheduledStart'],
            _text(widget.workOrder?['scheduled_start'])),
      );

  String get _end => _text(
        widget.scheduledEnd,
        _text(widget.workOrder?['scheduledEnd'],
            _text(widget.workOrder?['scheduled_end'])),
      );

  Future<void> _openWorkOrder() async {
    if (_isOpeningWorkOrder) return;
    setState(() => _isOpeningWorkOrder = true);

    var didExitAfterCancellation = false;
    try {
      final id = _workOrderId(widget.workOrder);
      Map<String, dynamic>? resolved = widget.workOrder == null
          ? null
          : Map<String, dynamic>.from(widget.workOrder!);

      if (id.isNotEmpty) {
        final response = await HomeownerService.instance.fetchWorkOrders();
        final match = _findWorkOrder(response, id);
        if (match != null) resolved = match;
      }

      if (!mounted) return;
      if (resolved == null || _workOrderId(resolved).isEmpty) {
        AppNotification.showInfo(
          context,
          'Your booking is still being prepared. Try again in a moment.',
        );
        return;
      }
      final wasCancelled = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => WorkOrderDetailScreen(job: resolved!)),
      );
      if (wasCancelled == true && mounted) {
        didExitAfterCancellation = true;
        _finishToTab(2);
      }
    } catch (_) {
      if (mounted) {
        AppNotification.showInfo(
          context,
          'We could not open this work order right now. Please try again.',
        );
      }
    } finally {
      if (mounted && !didExitAfterCancellation) {
        setState(() => _isOpeningWorkOrder = false);
      }
    }
  }

  void _openMessage() {
    final contractorId = _contractorId;
    if (contractorId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contractorId: contractorId,
          contractorName: _proName,
          jobReference: _workOrderId(widget.workOrder).isEmpty
              ? null
              : '$_serviceName · ${widget.workOrder?['woNumber'] ?? _workOrderId(widget.workOrder)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = _price;
    final trade = widget.trade?.trim() ?? '';

    return PopScope(
      canPop: _exitRequested,
      onPopInvoked: (didPop) {
        if (!didPop) _finishToBrowse();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back to search',
            onPressed: _finishToBrowse,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        bottomNavigationBar: MainBottomNavigation(
          currentIndex: 2,
          onTap: _navigateToAppTab,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Booking confirmed',
                        textAlign: TextAlign.center,
                        style: AppTheme.headingStyle.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _woNumber.isNotEmpty
                            ? 'Your work order $_woNumber has been created.'
                            : 'Your work order has been created.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          height: 1.47,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.pageBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTheme.navy,
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radius),
                                  ),
                                  child: Text(
                                    _proName
                                        .split(RegExp(r'\s+'))
                                        .where((part) => part.isNotEmpty)
                                        .take(2)
                                        .map((part) => part[0].toUpperCase())
                                        .join(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _proName,
                                        style: AppTheme.headingStyle.copyWith(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (trade.isNotEmpty)
                                        Text(
                                          trade,
                                          style: const TextStyle(
                                            color: AppTheme.body,
                                            fontSize: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                                height: 29, color: AppTheme.cardBorder),
                            _detailBlock('Service', _serviceName),
                            const SizedBox(height: 14),
                            _detailBlock(
                              'Scheduled',
                              _formatSchedule(_start, _end),
                              meta: _urgencyLabel,
                            ),
                            if (_address.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _detailBlock('Location', _address),
                            ],
                            const Divider(
                                height: 25, color: AppTheme.cardBorder),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Upfront price',
                                    style: TextStyle(
                                      color: AppTheme.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  price,
                                  style: const TextStyle(
                                    color: AppTheme.navy700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            if ((_creditsApplied ?? 0) > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Credits applied',
                                      style: TextStyle(
                                        color: AppTheme.purple,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '−${formatUsd(_creditsApplied!)}',
                                    style: const TextStyle(
                                      color: AppTheme.purple,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_youPay != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'You pay $_proName',
                                      style: const TextStyle(
                                        color: AppTheme.navy,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatUsd(_youPay!),
                                    style: AppTheme.headingStyle
                                        .copyWith(fontSize: 22),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (_creditsApplied ?? 0) > 0
                                    ? 'You pay your pro directly. TradeWorks funds the ${formatUsd(_creditsApplied!)} credit.'
                                    : 'You pay your pro directly. TradeWorks adds no markup and takes no fee.',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed:
                              _isOpeningWorkOrder ? null : _openWorkOrder,
                          child: _isOpeningWorkOrder
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.onOrange,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'View work order',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed:
                              _contractorId.isEmpty ? null : _openMessage,
                          child: Text(
                            'Message $_proName',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finishToBrowse() => _finishToTab(1);

  void _finishToTab(int index) {
    if (_exitRequested) return;
    AppTabNavigation.request(index);
    setState(() => _exitRequested = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _navigateToAppTab(int index) {
    _finishToTab(index);
  }

  Widget _detailBlock(String label, String value, {String? meta}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 16,
            height: 1.44,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (meta != null && meta.isNotEmpty)
          Text(
            meta,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  String _formatSchedule(String startRaw, String endRaw) {
    final tier = '${widget.workOrder?['priority'] ?? ''}'.toLowerCase();
    final deadline =
        DateTime.tryParse('${widget.workOrder?['slaArrivalTarget'] ?? ''}');
    if ((tier == 'urgent' || tier == 'emergency') && deadline != null) {
      return 'By ${DateFormat('EEE d MMM, h:mm a').format(deadline.toLocal())}';
    }
    final start = DateTime.tryParse(startRaw)?.toLocal();
    final end = DateTime.tryParse(endRaw)?.toLocal();
    if (start == null) return startRaw.isEmpty ? 'To be scheduled' : startRaw;

    return formatVisit(start, end);
  }

  Map<String, dynamic>? _findWorkOrder(
      Map<String, dynamic> response, String id) {
    final candidates = <dynamic>[];
    final tabs = _asMap(response['tabs']);
    for (final key in const ['active', 'scheduled', 'history', 'requested']) {
      candidates.addAll(_asList(tabs[key]));
    }
    for (final key in const ['workOrders', 'work_orders', 'items', 'results']) {
      candidates.addAll(_asList(response[key]));
    }

    for (final candidate in candidates) {
      final workOrder = _asMap(candidate);
      if (_workOrderId(workOrder) == id) return workOrder;
    }
    return null;
  }

  String _workOrderId(Map<String, dynamic>? workOrder) {
    if (workOrder == null) return '';
    return _text(
      workOrder['workOrderId'],
      _text(workOrder['work_order_id'], _text(workOrder['id'])),
    );
  }

  String _workOrderPrice(Map<String, dynamic>? workOrder) {
    if (workOrder == null) return '';
    final raw = _findPrice(workOrder);
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    if (text.startsWith(r'$') || text.toLowerCase().contains('estimate')) {
      return text;
    }
    return '\$$text';
  }

  dynamic _findPrice(dynamic value) {
    if (value is! Map) return null;
    for (final key in const [
      'upfrontPrice',
      'upfront_price',
      'total',
      'totalAmount',
      'total_amount',
      'price',
      'amount',
      'approvedCap',
      'approved_cap',
    ]) {
      final price = value[key];
      if (price != null && price.toString().trim().isNotEmpty) return price;
    }
    for (final child in value.values) {
      if (child is Map) {
        final price = _findPrice(child);
        if (price != null) return price;
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) => value is List ? value : const [];

  String _addressText(Map<String, dynamic> address) {
    return [
      _text(address['street']),
      _text(address['city']),
      _text(address['state']),
      _text(address['zip']),
    ].where((part) => part.isNotEmpty).join(', ');
  }

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../utils/display_format.dart';
import '../widgets/app_notification.dart';
import '../widgets/main_bottom_navigation.dart';
import '../ui/tw.dart';
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

  String get _workOrderType => _text(widget.workOrder?['work_order_type'],
      _text(widget.workOrder?['workOrderType'], 'rate_card'));

  /// The price row's label, by work-order type (TW-SHARED-DECISIONS §2).
  String get _priceTypeLabel => switch (_workOrderType) {
        'nte' => 'Diagnostic · you approve the cap next',
        'quote_request' => 'Free visit · estimate to follow',
        _ => 'Upfront price',
      };

  /// A free visit costs nothing at booking; never "From $…" or a blank.
  String get _priceValue =>
      _workOrderType == 'quote_request' ? formatUsd(0) : _price;

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
    final trade = widget.trade?.trim() ?? '';
    final rowLabel = TwType.bodySm(color: AppTheme.body);
    final rowValue =
        TwType.bodySm(color: AppTheme.navy).copyWith(fontWeight: FontWeight.w600);

    return PopScope(
      canPop: _exitRequested,
      onPopInvoked: (didPop) {
        if (!didPop) _finishToBrowse();
      },
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        appBar: TwAppBar(title: '', onBack: _finishToBrowse),
        bottomNavigationBar: MainBottomNavigation(
          currentIndex: 2,
          onTap: _navigateToAppTab,
        ),
        body: SingleChildScrollView(
          child: TwPage(
            top: TwSpace.s28,
            bottom: TwSpace.s28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.greenMark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: TwSpace.s16),
                Text(
                  'Booking confirmed',
                  textAlign: TextAlign.center,
                  style: TwType.h1(context),
                ),
                const SizedBox(height: TwSpace.s8),
                Text(
                  _woNumber.isNotEmpty
                      ? 'Your work order $_woNumber has been created.'
                      : 'Your work order has been created.',
                  textAlign: TextAlign.center,
                  style: TwType.bodySm(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                TwFactPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TwAvatar(name: _proName, size: 48),
                          const SizedBox(width: TwSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_proName, style: TwType.h3()),
                                if (trade.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    trade,
                                    style: TwType.meta(color: AppTheme.body),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 29, color: AppTheme.cardBorder),
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
                      const Divider(height: 29, color: AppTheme.cardBorder),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(_priceTypeLabel, style: rowLabel),
                          ),
                          const SizedBox(width: TwSpace.s12),
                          Text(_priceValue, style: rowValue),
                        ],
                      ),
                      if ((_creditsApplied ?? 0) > 0) ...[
                        const SizedBox(height: TwSpace.s8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Credits applied',
                                style: TwType.bodySm(color: AppTheme.purple),
                              ),
                            ),
                            const SizedBox(width: TwSpace.s12),
                            Text(
                              '−${formatUsd(_creditsApplied!)}',
                              style: rowValue.copyWith(color: AppTheme.purple),
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
                              child: Text('You pay $_proName', style: rowValue),
                            ),
                            const SizedBox(width: TwSpace.s12),
                            Text(
                              formatUsd(_youPay!),
                              style: TwType.price().copyWith(
                                fontSize: 22,
                                height: 28 / 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: TwSpace.s4),
                        Text(
                          (_creditsApplied ?? 0) > 0
                              ? 'You pay your pro directly. TradeWorks funds the ${formatUsd(_creditsApplied!)} credit.'
                              : 'You pay your pro directly. TradeWorks adds no markup and takes no fee.',
                          style: TwType.caption(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: TwSpace.s20),
                // _openWorkOrder ignores taps while it is already opening.
                TwPrimaryButton(
                  label: 'View work order',
                  loading: _isOpeningWorkOrder,
                  onPressed: _openWorkOrder,
                ),
                const SizedBox(height: TwSpace.s12),
                // _openMessage does nothing when there is no messaging id.
                TwSecondaryButton(
                  label: 'Message $_proName',
                  icon: Icons.chat_bubble_outline_rounded,
                  height: 50,
                  onPressed: _openMessage,
                ),
              ],
            ),
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
        Text(label, style: TwType.caption()),
        const SizedBox(height: 2),
        Text(value, style: TwType.title()),
        if (meta != null && meta.isNotEmpty)
          Text(
            meta,
            style: TwType.caption().copyWith(fontWeight: FontWeight.w500),
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

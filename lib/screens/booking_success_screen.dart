import 'package:flutter/material.dart';

import '../services/homeowner_service.dart';
import '../theme.dart';
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
    final pro =
        _asMap(widget.workOrder?['pro'] ?? widget.workOrder?['contractor']);
    return _text(
      pro['id'],
      _text(
        pro['contractorId'],
        _text(widget.workOrder?['contractorId'],
            _text(widget.workOrder?['contractor_id'])),
      ),
    );
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

  String get _price => _text(widget.price, _workOrderPrice(widget.workOrder));

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Your booking is still being prepared. Try again in a moment.'),
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WorkOrderDetailScreen(job: resolved!)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'We could not open this work order right now. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningWorkOrder = false);
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
          workOrderTitle: _serviceName,
          workOrderStatus: _text(widget.workOrder?['status']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = _price;
    final trade = widget.trade?.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
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
                    const SizedBox(height: 20),
                    const Text(
                      'Booking confirmed!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.woNumber?.trim().isNotEmpty == true
                          ? 'Your work order #${widget.woNumber} has been created.'
                          : 'Your work order has been created.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.pageAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _proName,
                                  style: const TextStyle(
                                    color: AppTheme.navy700,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (trade.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tealTint,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    trade,
                                    style: const TextStyle(
                                      color: AppTheme.teal500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(height: 28),
                          _detailBlock('SERVICE', _serviceName),
                          const SizedBox(height: 16),
                          _detailBlock(
                              'SCHEDULED', _formatSchedule(_start, _end)),
                          if (_address.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _detailBlock('LOCATION', _address),
                          ],
                          const Divider(height: 28),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Upfront price',
                                  style: TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                price,
                                style: const TextStyle(
                                  color: AppTheme.navy700,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isOpeningWorkOrder ? null : _openWorkOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navy700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isOpeningWorkOrder
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'View work order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _contractorId.isEmpty ? null : _openMessage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.teal500,
                          side: const BorderSide(color: AppTheme.teal500),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Message $_proName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _BookingSuccessNav(),
          ],
        ),
      ),
    );
  }

  Widget _detailBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.gray,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _formatSchedule(String startRaw, String endRaw) {
    final start = DateTime.tryParse(startRaw)?.toLocal();
    final end = DateTime.tryParse(endRaw)?.toLocal();
    if (start == null) return startRaw.isEmpty ? 'To be scheduled' : startRaw;

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
      'Dec',
    ];
    final date = '${months[start.month - 1]} ${start.day}, ${start.year}';
    final startTime = _formatTime(start);
    if (end == null) return '$date - $startTime';
    return '$date - $startTime-${_formatTime(end)}';
  }

  String _formatTime(DateTime value) {
    var hour = value.hour % 12;
    if (hour == 0) hour = 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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

class _BookingSuccessNav extends StatelessWidget {
  const _BookingSuccessNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SuccessNavItem(icon: Icons.home_outlined, label: 'Home'),
          _SuccessNavItem(icon: Icons.search_rounded, label: 'Search'),
          _SuccessNavItem(
            icon: Icons.calendar_today_outlined,
            label: 'Bookings',
            selected: true,
          ),
          _SuccessNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class _SuccessNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _SuccessNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.navy700 : AppTheme.gray;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';
import 'nte_approval.dart';
import 'leave_review.dart';
import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const WorkOrderDetailScreen({super.key, required this.job});

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  Map<String, dynamic>? _review;

  @override
  void initState() {
    super.initState();
    _fetchReview();
  }

  Future<void> _fetchReview() async {
    final status = widget.job['status']?.toString().toLowerCase();
    final isCompleted = status == 'completed' ||
        status == 'complete' ||
        widget.job['timeline']?['completedAt'] != null;
    if (!isCompleted) return;

    try {
      final woId = int.tryParse(widget.job['id']?.toString() ??
              widget.job['workOrderId']?.toString() ??
              '0') ??
          0;
      final rev = await HomeownerService.instance.getReview(woId);
      if (mounted) {
        setState(() {
          _review = rev;
        });
      }
      // If no review found in work order data, check eligibility 
      // to determine if one exists in the DB (already_reviewed means it exists)
      if (rev == null && mounted) {
        try {
          final eligibility = await HomeownerService.instance.getReviewEligibility(workOrderId: woId);
          if (eligibility['eligible'] == false && eligibility['reason'] == 'already_reviewed') {
            if (mounted) {
              setState(() {
                // Create a placeholder so the "Edit Review" button shows
                _review = {'rating': 5.0, 'reviewText': '', 'displayName': null, '_needsLoad': true};
              });
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _review = null;
        });
      }
    }
  }

  String _formatDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return 'TBD';
    try {
      final dt = DateTime.parse(dateTimeStr.toString());
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (e) {
      return dateTimeStr.toString();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return AppTheme.gray;
      case 'scheduled':
        return AppTheme.teal500;
      case 'en_route':
        return AppTheme.orange500;
      case 'in_progress':
        return AppTheme.orange500;
      case 'quote_provided':
        return AppTheme.orange500;
      case 'completed':
      case 'complete':
        return AppTheme.success;
      case 'cancelled':
      case 'canceled':
        return AppTheme.error;
      default:
        return AppTheme.navy700;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'en_route':
        return 'En Route';
      case 'in_progress':
        return 'In Progress';
      case 'quote_provided':
        return 'Action Required';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        if (status.isEmpty) return 'Active';
        return status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String _workOrderId() {
    return _readString(widget.job['workOrderId']) ??
        _readString(widget.job['id']) ??
        'TW-0000';
  }

  String _serviceName() {
    return _readString(widget.job['serviceCategory']) ??
        _readString(widget.job['service_category']) ??
        _readString(widget.job['serviceName']) ??
        _readString(widget.job['service_name']) ??
        _readString(widget.job['trade']) ??
        'Service Request';
  }

  String _addressText() {
    final address = widget.job['address'];
    if (address is Map) {
      final street = _readString(address['street']) ??
          _readString(address['line1']) ??
          _readString(address['addressLine1']);
      final city = _readString(address['city']);
      final state = _readString(address['state']);
      final cityState = [city, state].whereType<String>().join(', ');
      if (street != null && cityState.isNotEmpty) return '$street, $cityState';
      if (street != null) return street;
      if (cityState.isNotEmpty) return cityState;
      return 'Home';
    }
    return _readString(address) ?? 'Home';
  }

  String _proName() {
    final pro = widget.job['pro'];
    if (pro is Map) {
      return _readString(pro['businessName']) ??
          _readString(pro['business_name']) ??
          _readString(pro['name']) ??
          '';
    }
    return _readString(widget.job['proName']) ??
        _readString(widget.job['businessName']) ??
        '';
  }

  String _initialsFor(String value) {
    final clean = value.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
    if (clean.isEmpty) return 'P';
    final initials = clean
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return initials.isEmpty ? 'P' : initials;
  }

  String _priorityText() {
    return _readString(widget.job['priority']) ??
        _readString(widget.job['urgency']) ??
        _readString(widget.job['serviceLevel']) ??
        'Standard';
  }

  String _priceText() {
    final amount = widget.job['invoiceAmount'] ??
        widget.job['amount'] ??
        widget.job['price'] ??
        widget.job['total'];
    if (amount is num && amount > 0) {
      return '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
    }
    return _readString(widget.job['priceText']) ??
        _readString(widget.job['priceLabel']) ??
        'Pending';
  }

  String _timeWindowText() {
    final start = _readString(widget.job['scheduledStart']);
    final end = _readString(widget.job['scheduledEnd']);
    if (start == null) return 'TBD';
    if (end == null) return _formatDateTime(start);
    try {
      final startDt = DateTime.parse(start);
      final endDt = DateTime.parse(end);
      final date = DateFormat('EEE, MMM d').format(startDt);
      final startTime = DateFormat('h:mm a').format(startDt);
      final endTime = DateFormat('h:mm a').format(endDt);
      return '$date • $startTime - $endTime';
    } catch (_) {
      return _formatDateTime(start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.job['status']?.toString() ?? 'Requested';
    final statusLower = status.toLowerCase();
    final service = _serviceName();
    final addressStr = _addressText();
    final dateStr = _timeWindowText();
    final woId = _workOrderId();
    final proName = _proName();
    final displayPro = proName.isEmpty ? 'Gulf Coast Air' : proName;

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      body: Column(
        children: [
          _screenHeader('Work order'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service,
                    style: const TextStyle(
                      color: AppTheme.navy700,
                      fontSize: 20,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '#$woId',
                    style: const TextStyle(
                      color: AppTheme.gray,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _statusChip(status, _statusDisplayColor(statusLower)),
                      const SizedBox(width: 10),
                      const _Dot(color: AppTheme.success),
                      const SizedBox(width: 8),
                      const Text(
                        'Updated just now',
                        style: TextStyle(
                          color: AppTheme.gray,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel('STATUS TIMELINE'),
                  const SizedBox(height: 12),
                  _buildTimeline(statusLower, dateStr),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: AppTheme.line),
                  const SizedBox(height: 12),
                  _proPanel(displayPro),
                  const SizedBox(height: 10),
                  _proActions(),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppTheme.line),
                  const SizedBox(height: 20),
                  _sectionLabel('DETAILS'),
                  const SizedBox(height: 10),
                  _detailsCard(
                    when: dateStr,
                    address: addressStr,
                    urgency: _priorityText(),
                    note: _readString(widget.job['description']) ??
                        _readString(widget.job['note']) ??
                        _readString(widget.job['customerNote']) ??
                        'AC isn\'t cooling properly',
                  ),
                  const SizedBox(height: 14),
                  _priceCard(_priceText(), displayPro),
                  const SizedBox(height: 18),
                  _detailActions(statusLower),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _screenHeader(String title) {
    return Container(
      width: double.infinity,
      height: 50 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
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
                  color: AppTheme.navy700, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusDisplayColor(String statusLower) {
    if (statusLower.contains('en_route')) return AppTheme.teal500;
    if (statusLower.contains('cancel')) return AppTheme.error;
    if (statusLower.contains('complete')) return AppTheme.success;
    if (statusLower.contains('quote')) return AppTheme.orange500;
    return _getStatusColor(statusLower);
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        _getStatusText(status).replaceAll('En Route', 'En route'),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.gray,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _buildTimeline(String currentStatus, String dateStr) {
    final steps = <_TimelineStep>[
      _TimelineStep('Booked', _timelineBookedText(dateStr)),
      const _TimelineStep('En route', 'Now · ETA 8:20 AM'),
      const _TimelineStep('Arrived', null),
      const _TimelineStep('In progress', null),
      const _TimelineStep('Wrapping up', null),
      const _TimelineStep('Completed', null),
    ];

    int currentIndex = 0;
    if (currentStatus == 'en_route') currentIndex = 1;
    if (currentStatus == 'arrived') currentIndex = 2;
    if (currentStatus == 'in_progress') currentIndex = 3;
    if (currentStatus == 'wrapping_up') currentIndex = 4;
    if (currentStatus == 'completed' || currentStatus == 'complete') {
      currentIndex = 5;
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isDone = index < currentIndex;
        final isActive = index == currentIndex;
        final color = isDone || isActive ? AppTheme.teal500 : AppTheme.line;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Column(
                children: [
                  Container(
                    width: isActive ? 20 : 17,
                    height: isActive ? 20 : 17,
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.teal500 : AppTheme.pageAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color,
                        width: isActive ? 3 : 2,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            size: 12, color: Colors.white)
                        : null,
                  ),
                  if (index < steps.length - 1)
                    Container(
                      width: 2,
                      height: 34,
                      color: index < currentIndex ? AppTheme.teal500 : AppTheme.line,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: isActive ? 1 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        color: isActive
                            ? AppTheme.teal500
                            : (index <= currentIndex ? AppTheme.ink : AppTheme.gray),
                        fontSize: 13,
                        fontWeight: index <= currentIndex
                            ? FontWeight.w900
                            : FontWeight.w500,
                      ),
                    ),
                    if (step.caption != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        step.caption!,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _timelineBookedText(String dateStr) {
    final scheduled = _readString(widget.job['createdAt']) ??
        _readString(widget.job['created_at']);
    if (scheduled != null) return _formatDateTime(scheduled);
    return dateStr == 'TBD' ? 'Today, 7:58 AM' : dateStr;
  }

  Widget _proPanel(String proName) {
    final dynamic rating = widget.job['pro']?['verifiedRating'] ??
        widget.job['verifiedRating'] ??
        widget.job['proRating'] ??
        4.9;
    final trade = _readString(widget.job['serviceCategory']) ??
        _readString(widget.job['trade']) ??
        'HVAC';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.navy700,
          child: Text(
            _initialsFor(proName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$rating',
                    style: const TextStyle(
                      color: AppTheme.orange500,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded,
                      color: AppTheme.orange500, size: 16),
                  const SizedBox(width: 8),
                  const Text('·',
                      style: TextStyle(color: AppTheme.gray, fontSize: 14)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trade,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailsCard({
    required String when,
    required String address,
    required String urgency,
    required String note,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          _plainDetailRow('When', when),
          const SizedBox(height: 10),
          _plainDetailRow('Address', address),
          const SizedBox(height: 10),
          _plainDetailRow('Urgency', urgency, valueColor: _urgencyColor(urgency)),
          const SizedBox(height: 10),
          _plainDetailRow('Your note', note),
        ],
      ),
    );
  }

  Widget _plainDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.ink,
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _urgencyColor(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('urgent') || lower.contains('emergency')) {
      return const Color(0xFFC83B3B);
    }
    return AppTheme.ink;
  }

  Widget _priceCard(String price, String proName) {
    final displayPrice = price == 'Pending' ? '\$189' : price;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.orange500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UPFRONT PRICE',
            style: TextStyle(
              color: AppTheme.orange500,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayPrice,
            style: const TextStyle(
              color: AppTheme.orange500,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'You pay $proName directly · \$0 markup',
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailActions(String currentStatus) {
    final isQuote = currentStatus == 'quote_provided' ||
        currentStatus.contains('quote') ||
        currentStatus.contains('review');
    final isCompleted =
        currentStatus == 'completed' || currentStatus == 'complete';

    if (isQuote) {
      return _fullButton(
        'Review quote',
        background: AppTheme.orange500,
        foreground: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NteApprovalScreen(job: widget.job),
            ),
          );
        },
      );
    }

    if (isCompleted) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _outlineButton('Receipt', onPressed: () {
                  _showReceiptModal(context);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _outlineButton(
                  _review != null ? 'Edit review' : 'Leave review',
                  onPressed: _openReviewPage,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _outlineButton('Reschedule', onPressed: _requestReschedule),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _outlineButton(
            'Cancel booking',
            color: const Color(0xFFC83B3B),
            onPressed: _cancelJob,
          ),
        ),
      ],
    );
  }

  Widget _proActions() {
    return Row(
      children: [
        Expanded(
          child: _outlineButton(
            'Message',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messaging will open here.')),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _outlineButton(
            'Call',
            icon: Icons.phone_outlined,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling pro...')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _outlineButton(
    String label, {
    required VoidCallback onPressed,
    Color color = AppTheme.navy700,
    IconData? icon,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _fullButton(
    String label, {
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _openReviewPage() async {
    final woId = int.tryParse(widget.job['id']?.toString() ??
            widget.job['workOrderId']?.toString() ??
            '0') ??
        0;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LeaveReviewScreen(
          job: widget.job,
          jobId: woId,
          initialRating: (_review?['rating'] as num?)?.toDouble() ?? 5,
          initialReviewText: _review?['reviewText']?.toString() ??
              _review?['comment']?.toString() ??
              '',
          isEdit: _review != null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _review = result;
      });
    }
  }

  void _cancelJob() async {
    final woId = int.tryParse(widget.job['id']?.toString() ??
            widget.job['workOrderId']?.toString() ??
            '0') ??
        0;
    await HomeownerService.instance
        .performWorkOrderAction(workOrderId: woId, action: 'cancel');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request cancelled')));
      Navigator.pop(context, true);
    }
  }

  Future<void> _requestReschedule() async {
    String? readValue(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
        return null;
      }
      return text;
    }

    final workOrderId = int.tryParse(widget.job['id']?.toString() ??
            widget.job['workOrderId']?.toString() ??
            '0') ??
        0;
    var contractorId = readValue(widget.job['contractorId']) ??
        readValue(widget.job['contractor_id']) ??
        readValue(widget.job['pro']?['contractorId']) ??
        readValue(widget.job['pro']?['contractor_id']) ??
        readValue(widget.job['pro']?['id']) ??
        readValue(widget.job['contractor']?['id']) ??
        readValue(widget.job['contractor']?['contractorId']) ??
        readValue(widget.job['contractor']?['contractor_id']);
    contractorId ??= await HomeownerService.instance
        .resolveContractorIdForWorkOrder(workOrderId);
    final woId = int.tryParse(widget.job['id']?.toString() ??
            widget.job['workOrderId']?.toString() ??
            '0') ??
        0;
    if (contractorId == null || woId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reschedule is not available for this booking.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      final avail = await HomeownerService.instance.getContractorAvailability(
        contractorId: contractorId,
        fromDate: now.toIso8601String().split('T').first,
        toDate:
            now.add(const Duration(days: 7)).toIso8601String().split('T').first,
      );
      final slots = avail['slots'] as List? ?? const [];
      if (!mounted) return;
      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No alternate slots are currently available.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      // Group slots by date key (YYYY-MM-DD)
      final Map<String, List<Map<String, dynamic>>> slotsByDate = {};
      for (final slot in slots) {
        if (slot is Map<String, dynamic>) {
          final startStr = slot['start']?.toString() ?? '';
          if (startStr.isNotEmpty) {
            final dateKey = startStr.split('T').first;
            slotsByDate.putIfAbsent(dateKey, () => []);
            slotsByDate[dateKey]!.add(slot);
          }
        }
      }

      final sortedDates = slotsByDate.keys.toList()..sort();
      if (sortedDates.isEmpty) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) {
          String selectedDate = sortedDates.first;
          Map<String, dynamic>? selectedSlot = slotsByDate[selectedDate]?.first;
          final reasonController = TextEditingController(text: 'Homeowner requested reschedule');

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final activeSlots = slotsByDate[selectedDate] ?? [];

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Propose Reschedule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.navy700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select Date:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navy700),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: sortedDates.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final dateKey = sortedDates[idx];
                            final isSelected = dateKey == selectedDate;
                            final parsedDate = DateTime.tryParse(dateKey) ?? DateTime.now();
                            final weekDayStr = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][parsedDate.weekday - 1];
                            final monthStr = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][parsedDate.month - 1];
                            final label = '$weekDayStr, $monthStr ${parsedDate.day}';

                            return ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              selectedColor: AppTheme.orange500,
                              backgroundColor: AppTheme.pageAlt,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.navy700,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    selectedDate = dateKey;
                                    selectedSlot = slotsByDate[dateKey]?.first;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Time:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navy700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activeSlots.map((slot) {
                          final startStr = slot['start']?.toString() ?? '';
                          final parsedTime = DateTime.tryParse(startStr) ?? DateTime.now();
                          final hour = parsedTime.hour > 12 ? parsedTime.hour - 12 : (parsedTime.hour == 0 ? 12 : parsedTime.hour);
                          final min = parsedTime.minute.toString().padLeft(2, '0');
                          final period = parsedTime.hour >= 12 ? 'PM' : 'AM';
                          final timeLabel = '$hour:$min $period';
                          final isSelected = selectedSlot == slot;

                          return ChoiceChip(
                            label: Text(timeLabel),
                            selected: isSelected,
                            selectedColor: AppTheme.orange500,
                            backgroundColor: AppTheme.pageAlt,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.navy700,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedSlot = slot;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reason for Rescheduling:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navy700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter reason here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel', style: TextStyle(color: AppTheme.navy700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange500),
                              onPressed: selectedSlot == null ? null : () async {
                                final start = selectedSlot!['start']?.toString() ?? '';
                                final end = selectedSlot!['end']?.toString() ?? '';
                                final reason = reasonController.text.trim().isNotEmpty
                                    ? reasonController.text.trim()
                                    : 'Homeowner requested reschedule';
                                Navigator.pop(sheetContext);

                                try {
                                  showDialog(
                                    context: this.context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(color: AppTheme.orange500),
                                    ),
                                  );
                                  await HomeownerService.instance.performWorkOrderAction(
                                    workOrderId: woId,
                                    action: 'propose_reschedule',
                                    extra: {
                                      'proposedStart': start,
                                      'proposedEnd': end,
                                      'reason': reason,
                                      'contractorId': contractorId,
                                      'requester_user_id': AuthService.instance.userId,
                                    },
                                  );
                                  if (mounted) Navigator.pop(this.context);
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Reschedule request sent successfully'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                    Navigator.pop(this.context, true);
                                  }
                                } catch (e) {
                                  if (mounted) Navigator.pop(this.context);
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text('Reschedule failed: ${e.toString()}'),
                                        backgroundColor: AppTheme.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Propose Reschedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showReceiptModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 48, color: AppTheme.teal500),
            const SizedBox(height: 16),
            const Text('Receipt',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy700)),
            const SizedBox(height: 12),
            Text(
              'Total: \$${((widget.job['invoiceAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'
              '${widget.job['invoiceUrl'] != null ? '\nReceipt available from provider' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.gray),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Downloading receipt PDF...')));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  minimumSize: const Size(double.infinity, 48)),
              child: const Text('Download Receipt',
                  style: TextStyle(
                      color: AppTheme.navy700, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

}

class _TimelineStep {
  final String title;
  final String? caption;

  const _TimelineStep(this.title, this.caption);
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

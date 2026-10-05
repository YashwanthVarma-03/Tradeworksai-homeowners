import '../../widgets/loading_skeleton.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/document_upload.dart';
import '../../utils/arrival_check_state.dart';
import 'arrival_check.dart';
import 'no_show_reply.dart';
import 'package:flutter/material.dart';
import '../../utils/display_format.dart';
import '../../utils/work_order_status.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';
import 'cap_approval.dart';
import 'leave_review.dart';
import 'reschedule_work_order.dart';
import '../../services/homeowner_service.dart';
import '../../services/stream_service.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';
import '../chat_screen.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool focusMoney;

  const WorkOrderDetailScreen(
      {super.key, required this.job, this.focusMoney = false});

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  Map<String, dynamic>? _review;
  bool _isReviewLoading = true;
  bool _isCancelling = false;
  bool _uploadingReceipt = false;
  int? _receiptDocumentId;
  final _moneyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchReview();
    if (widget.focusMoney) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _moneyKey.currentContext != null) {
          Scrollable.ensureVisible(_moneyKey.currentContext!,
              duration: const Duration(milliseconds: 250));
        }
      });
    }
  }

  Future<void> _fetchReview() async {
    final status = widget.job['status']?.toString().toLowerCase();
    final isCompleted = status == 'completed' ||
        status == 'complete' ||
        widget.job['timeline']?['completedAt'] != null;
    if (!isCompleted) {
      if (mounted) setState(() => _isReviewLoading = false);
      return;
    }

    try {
      final woId = int.tryParse(widget.job['id']?.toString() ??
              widget.job['workOrderId']?.toString() ??
              '0') ??
          0;
      var review = await HomeownerService.instance.getReview(woId);
      if (review == null && woId > 0) {
        try {
          final eligibility = await HomeownerService.instance
              .getReviewEligibility(workOrderId: woId);
          if (eligibility['eligible'] == false &&
              eligibility['reason'] == 'already_reviewed') {
            HomeownerService.instance.rememberReviewedWorkOrder(woId);
            review = HomeownerService.instance.cachedReviewForWorkOrder(woId);
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _review = review);
    } catch (_) {
      // Keep the work-order details available when review history is offline.
    } finally {
      if (mounted) setState(() => _isReviewLoading = false);
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
        '';
  }

  /// "WO-24144" — the work-order number, never the database id with a "#".
  String _woNumber() {
    final value = _readString(widget.job['woNumber']) ??
        _readString(widget.job['wo_number']) ??
        _readString(widget.job['workOrderNumber']) ??
        _readString(widget.job['work_order_number']) ??
        _workOrderId();
    return value.startsWith('#') ? value.substring(1) : value;
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

  /// The roster technician on the job ("Dale H."). Hidden until assigned.
  String? _technicianName() {
    final tech = widget.job['technician'];
    return (tech is Map
            ? _readString(tech['displayName'] ?? tech['name'])
            : _readString(tech)) ??
        _readString(widget.job['technicianName']) ??
        _readString(widget.job['technician_name']);
  }

  /// The gate / access code the homeowner gave at booking (Oct 1, G-53).
  String? _accessCode() =>
      _readString(widget.job['accessCode']) ??
      _readString(widget.job['access_code']);

  String _timeWindowText() {
    final priority = _priorityText().toLowerCase();
    final deadline = _readString(
        widget.job['slaArrivalTarget'] ?? widget.job['sla_arrival_target']);
    if ((priority == 'urgent' || priority == 'emergency') && deadline != null) {
      return 'By ${_formatDateTime(deadline)}';
    }
    final start = _readString(widget.job['scheduledStart']);
    final end = _readString(widget.job['scheduledEnd']);
    if (start == null) return 'TBD';
    if (end == null) return _formatDateTime(start);
    try {
      final startDt = DateTime.parse(start);
      final endDt = DateTime.parse(end);
      return formatVisit(startDt, endDt);
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
    final woId = _woNumber();
    final proName = _proName();
    final displayPro = proName.isEmpty ? 'Pro details pending' : proName;

    return TransactionGuard(
      isProcessing: _isCancelling,
      blockedMessage: 'Please wait while this booking is being cancelled.',
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
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
                      woId,
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _statusChip(),
                      ],
                    ),
                    if (ArrivalCheckState.pending(widget.job))
                      Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Did your pro arrive?'),
                            onPressed: () async {
                              if (await openArrivalCheck(context, widget.job) &&
                                  mounted) Navigator.pop(context, true);
                            },
                          )),
                    if (WorkOrderStatus.fromJob(widget.job).state ==
                        WorkOrderState.noShowCustomer)
                      const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: Text(
                              'Your pro reported that they could not reach you at the booked time. This is private. Contact support if this is incorrect.')),
                    const SizedBox(height: 22),
                    if (!WorkOrderStatus.fromJob(widget.job)
                        .isTerminalWithoutProgress)
                      _sectionLabel('Status timeline'),
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
                    _sectionLabel('Details'),
                    const SizedBox(height: 10),
                    _detailsCard(
                      when: dateStr,
                      address: addressStr,
                      urgency: _priorityText(),
                      note: _readString(widget.job['description']) ??
                          _readString(widget.job['note']) ??
                          _readString(widget.job['customerNote']) ??
                          _readString(widget.job['serviceDescription']) ??
                          'No additional description',
                    ),
                    const SizedBox(height: 14),
                    KeyedSubtree(key: _moneyKey, child: _moneyCard()),
                    const SizedBox(height: 18),
                    _actions(),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Widget _statusChip() {
    final resolved = WorkOrderStatus.fromJob(widget.job);
    // Booked is the default and is not shown (design standard v3.3).
    return Wrap(spacing: 12, runSpacing: 6, children: [
      if (resolved.state != WorkOrderState.booked)
        WorkOrderStatusChip(resolved),
      if (resolved.waitingOnYou) const WaitingOnYouChip(),
    ]);
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTheme.headingStyle.copyWith(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTimeline(String currentStatus, String dateStr) {
    final resolved = WorkOrderStatus.fromJob(widget.job);
    if (resolved.isTerminalWithoutProgress) return const SizedBox.shrink();
    final steps = <_TimelineStep>[
      _TimelineStep('Booked', _timelineBookedText(dateStr)),
      const _TimelineStep('En route', null),
      const _TimelineStep('In progress', null),
      const _TimelineStep('Completed', null),
    ];

    final currentIndex = resolved.progressionIndex;

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final timeline = widget.job['timeline'];
        final recorded = timeline is Map &&
            timeline[const [
                  'acceptedAt',
                  'enRouteAt',
                  'inProgressAt',
                  'completedAt'
                ][index]] !=
                null;
        final isDone = index < currentIndex && (index == 0 || recorded);
        final isActive = index == currentIndex;
        final color = isDone || isActive ? AppTheme.blue : AppTheme.line;

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
                      color: isDone ? AppTheme.blue : AppTheme.pageBackground,
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
                      color:
                          index < currentIndex ? AppTheme.blue : AppTheme.line,
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
                            ? AppTheme.blue
                            : (index <= currentIndex
                                ? AppTheme.ink
                                : AppTheme.gray),
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
    return dateStr == 'TBD' ? 'Not recorded' : dateStr;
  }

  Widget _proPanel(String proName) {
    final dynamic rating = widget.job['pro']?['verifiedRating'] ??
        widget.job['verifiedRating'] ??
        widget.job['proRating'];
    final proMap = widget.job['pro'] is Map
        ? widget.job['pro'] as Map
        : const <String, dynamic>{};
    final trade = _readString(proMap['category']) ??
        _readString(proMap['trade']) ??
        _readString(widget.job['trade']) ??
        _readString(widget.job['serviceCategory']) ??
        'Service professional';
    final reviewCount = proMap['verifiedReviewCount'] ??
        proMap['reviewCount'] ??
        widget.job['proReviewCount'];

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
                  if (rating != null) ...[
                    const Icon(Icons.star_rounded,
                        color: AppTheme.gold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$rating',
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reviewCount != null)
                      Text(
                        ' ($reviewCount reviews)',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    const Text(
                      ' · ',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
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
          if (_technicianName() != null) ...[
            const SizedBox(height: 10),
            _plainDetailRow('Technician', _technicianName()!),
          ],
          const SizedBox(height: 10),
          _plainDetailRow('Address', address),
          if (_accessCode() != null)
            Padding(
              padding: const EdgeInsets.only(left: 78, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.key_outlined,
                      size: 16, color: AppTheme.navy),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Gate code ${_accessCode()} · shared with your pro',
                      style: const TextStyle(
                        color: AppTheme.body,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _plainDetailRow('Urgency', urgency,
              valueColor: _urgencyColor(urgency)),
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
      return AppTheme.red;
    }
    return AppTheme.ink;
  }

  String _jobType() =>
      _readString(widget.job['work_order_type']) ??
      _readString(widget.job['workOrderType']) ??
      'rate_card';

  double? _firstAmount(List<String> keys) {
    for (final key in keys) {
      final value = readAmount(widget.job[key]);
      if (value != null) return value;
    }
    return null;
  }

  bool get _receiptUploaded =>
      _receiptDocumentId != null ||
      widget.job['receiptDocumentId'] != null ||
      _readString(widget.job['paidReceiptUrl']) != null;

  bool get _receiptOwed =>
      !_receiptUploaded && WorkOrderStatus.receiptPending(widget.job);

  Widget _amberWell(IconData icon) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppTheme.amberTint,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppTheme.amber),
      );

  Widget _moneyRow(String label, String value,
      {Color? valueColor, bool strong = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.body, fontSize: 15),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.navy,
            fontSize: 15,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// D04: the cap waiting for approval, inside Job money.
  Widget _capBlock() {
    final quote = widget.job['quote'] is Map
        ? widget.job['quote'] as Map
        : const <String, dynamic>{};
    final cap = readAmount(widget.job['capAmount'] ??
        widget.job['cap_amount'] ??
        widget.job['quoteCap'] ??
        widget.job['quote_cap'] ??
        widget.job['quoteAmount'] ??
        widget.job['quote_amount'] ??
        quote['total'] ??
        quote['totalNTE'] ??
        widget.job['approvedCap'] ??
        widget.job['approved_cap']);
    final sentRaw = _readString(widget.job['capSubmittedAt'] ??
        widget.job['cap_submitted_at'] ??
        widget.job['quoteSentAt'] ??
        widget.job['quote_sent_at'] ??
        quote['createdAt']);
    final sent = sentRaw == null ? null : DateTime.tryParse(sentRaw)?.toLocal();
    final scope = _readString(widget.job['quoteScope'] ??
        widget.job['quote_scope'] ??
        quote['diagnosis'] ??
        widget.job['diagnosis']);
    final title = cap == null
        ? 'Your pro sent a cap'
        : 'Cap sent${sent == null ? '' : ' ${DateFormat('MMM d').format(sent)}'}: ${formatUsd(cap)} not-to-exceed';
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _amberWell(Icons.description_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (scope != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    scope,
                    style: const TextStyle(
                        color: AppTheme.body, fontSize: 14, height: 1.43),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'You approve a not-to-exceed cap before work begins. The final price may be lower — never higher.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.43,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// D05: the paid receipt is owed — the primary action on a completed job
  /// (Oct 1, G-46).
  Widget _receiptBlock() {
    final earn = readAmount(widget.job['receiptRewardAmount'] ??
        widget.job['receipt_reward_amount']);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _amberWell(Icons.upload_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload your receipt',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: AppTheme.body,
                          fontSize: 14,
                          height: 1.43,
                        ),
                        children: [
                          const TextSpan(
                              text:
                                  'Attach your paid receipt to keep it with this job and earn '),
                          if (earn != null && earn > 0) ...[
                            TextSpan(
                              text: formatUsd(earn),
                              style: const TextStyle(
                                color: AppTheme.purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' in credits.'),
                          ] else
                            const TextSpan(text: 'credits.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _uploadingReceipt ? null : _uploadReceipt,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(
                  _uploadingReceipt ? 'Uploading…' : 'Upload your receipt'),
            ),
          ),
        ],
      ),
    );
  }

  /// Job money (D03–D05): the booked price by type, credits applied, what
  /// the homeowner pays the pro, the waiting cap, the owed receipt and the
  /// homeowner money claim.
  Widget _moneyCard() {
    final type = _jobType();
    final completed =
        WorkOrderStatus.fromJob(widget.job).state == WorkOrderState.completed;
    final price = _firstAmount(const [
      'upfrontPrice',
      'upfront_price',
      'diagnosticFee',
      'diagnostic_fee',
      'amount',
      'price',
    ]);
    final credits = _firstAmount(const [
      'creditsApplied',
      'credits_applied',
      'serviceCreditsApplied',
      'service_credits_applied',
    ]);
    final paid = _firstAmount(const ['paidAmount', 'paid_amount']);
    final headline = type == 'quote_request'
        ? 'Free visit'
        : price == null
            ? 'Pending'
            : formatUsd(price);
    final headlineLabel = switch (type) {
      'nte' => 'diagnostic',
      'quote_request' => '',
      _ => 'Upfront price',
    };
    final hasCredits = credits != null && credits > 0;
    const meta = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 14,
      height: 1.43,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Job money'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    headline,
                    style: AppTheme.headingStyle.copyWith(fontSize: 32),
                  ),
                  if (headlineLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      headlineLabel,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (type == 'nte') ...[
                const SizedBox(height: 4),
                Text(
                  '${_serviceName()} · You approve the cap',
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (type == 'quote_request') ...[
                const SizedBox(height: 4),
                const Text('The pro sends you an estimate', style: meta),
              ],
              if (hasCredits) ...[
                const SizedBox(height: 14),
                _moneyRow('Credits applied', '−${formatUsd(credits)}',
                    valueColor: AppTheme.purple),
              ],
              if (completed && paid != null) ...[
                if (hasCredits) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppTheme.cardBorder),
                ],
                const SizedBox(height: 10),
                _moneyRow('You paid the pro', formatUsd(paid), strong: true),
              ] else if (!completed &&
                  type == 'rate_card' &&
                  price != null) ...[
                if (hasCredits) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppTheme.cardBorder),
                ],
                const SizedBox(height: 10),
                _moneyRow(
                  'You pay the pro',
                  formatUsd((price - (credits ?? 0)).clamp(0, price)),
                  strong: true,
                ),
              ],
              if (paid == 0) ...[
                const SizedBox(height: 10),
                const Text(
                    'No customer-paid portion. This job earns no credits.',
                    style: meta),
              ],
              if (WorkOrderStatus.capPending(widget.job)) _capBlock(),
              if (completed && _receiptOwed) _receiptBlock(),
              if (completed && paid != 0 && _receiptUploaded) ...[
                const SizedBox(height: 10),
                const Text('Paid receipt uploaded.', style: meta),
              ],
              const SizedBox(height: 14),
              const Text(
                'You pay your pro directly. TradeWorks adds no markup and takes no fee — we only fund the credits you apply.',
                style: meta,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openCapReview() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CapApprovalScreen(job: widget.job),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  Widget _reviewButton({required bool primary}) {
    if (_isReviewLoading) return _reviewAction();
    final reviewed = _review != null;
    final label = reviewed ? 'Edit your review' : 'Leave a review';
    if (primary && !reviewed) {
      return SizedBox(
        height: 50,
        child: ElevatedButton(onPressed: _openReviewPage, child: Text(label)),
      );
    }
    return SizedBox(
      height: 50,
      child: OutlinedButton(onPressed: _openReviewPage, child: Text(label)),
    );
  }

  /// Bottom actions (D03–D05), keyed on what the homeowner owes (Oct 1).
  Widget _actions() {
    final resolved = WorkOrderStatus.fromJob(widget.job);
    if (WorkOrderStatus.capPending(widget.job)) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _openCapReview,
          child: const Text('Review the cap'),
        ),
      );
    }
    if (resolved.state == WorkOrderState.completed) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showReceiptModal(context),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Job documents'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _reviewButton(primary: !_receiptOwed)),
        ],
      );
    }
    if (resolved.state == WorkOrderState.noShowCustomer) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () async {
            final sent = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => NoShowReplyScreen(job: widget.job)));
            if (sent == true && mounted) Navigator.pop(context, true);
          },
          child: const Text('Tell us what happened'),
        ),
      );
    }
    if (resolved.state != WorkOrderState.booked) {
      return const SizedBox.shrink();
    }
    // Reschedule only Standard bookings while Booked (Sep 30).
    final level = _priorityText().toLowerCase();
    final canReschedule =
        !level.contains('urgent') && !level.contains('emergency');
    return Row(
      children: [
        if (canReschedule)
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _requestReschedule,
                child: const Text('Reschedule'),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),
        TextButton(
          onPressed: _isCancelling ? null : _cancelJob,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.red,
            minimumSize: const Size(44, 44),
          ),
          child: const Text(
            'Cancel booking',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _reviewAction() {
    if (_isReviewLoading) {
      return Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.pageBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Semantics(
            label: 'Loading review',
            liveRegion: true,
            child: const SkeletonBlock(width: 160, height: 20)),
      );
    }

    if (_review != null)
      return _outlineButton('Edit your review', onPressed: _openReviewPage);

    return _outlineButton('Leave review', onPressed: _openReviewPage);
  }

  Widget _proActions() {
    return Row(
      children: [
        Expanded(
          child: _outlineButton(
            'Message',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: _openMessage,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _outlineButton(
            'Call',
            icon: Icons.phone_outlined,
            onPressed: _callPro,
          ),
        ),
      ],
    );
  }

  Future<void> _callPro() async {
    try {
      final pro = widget.job['pro'] is Map
          ? Map<String, dynamic>.from(widget.job['pro'])
          : <String, dynamic>{};
      var phone = _readString(
          pro['phone'] ?? pro['business_phone'] ?? widget.job['proPhone']);
      final slug = _readString(pro['slug']);
      if (phone == null && slug != null) {
        final response =
            await HomeownerService.instance.getContractorProfile(slug);
        final profile =
            response['profile'] is Map ? response['profile'] as Map : response;
        phone = _readString(profile['phone'] ?? profile['business_phone']);
      }
      if (phone == null)
        throw Exception(
            'This pro has not shared a phone number. You can message them instead.');
      final dial = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (dial.isEmpty || !await launchUrl(Uri(scheme: 'tel', path: dial)))
        throw Exception('Calling is not available on this device.');
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    }
  }

  Future<void> _openMessage() async {
    final pro = widget.job['pro'];
    final contractor = widget.job['contractor'];
    final proData = pro is Map
        ? Map<String, dynamic>.from(pro)
        : contractor is Map
            ? Map<String, dynamic>.from(contractor)
            : const <String, dynamic>{};
    String? messagingUserId =
        StreamService.instance.resolveMessagingUserId(proData) ??
            _readString(widget.job['chatUserId']) ??
            _readString(widget.job['chat_user_id']) ??
            _readString(widget.job['streamUserId']) ??
            _readString(widget.job['stream_user_id']) ??
            _readString(widget.job['contractorUserId']) ??
            _readString(widget.job['contractor_user_id']);

    if (messagingUserId == null) {
      final slug = _readString(widget.job['proSlug']) ??
          _readString(widget.job['pro_slug']) ??
          _readString(widget.job['contractorSlug']) ??
          _readString(widget.job['contractor_slug']) ??
          _readString(proData['slug']) ??
          _readString(proData['profileSlug']) ??
          _readString(proData['profile_slug']) ??
          _readString(proData['businessSlug']) ??
          _readString(proData['business_slug']) ??
          _readString(proData['contractorSlug']) ??
          _readString(proData['contractor_slug']);
      if (slug != null) {
        try {
          final profile =
              await HomeownerService.instance.getContractorProfile(slug);
          messagingUserId =
              StreamService.instance.resolveMessagingUserId(profile);
        } catch (_) {
          // The explicit user ID in the work order remains the preferred path.
        }
      }
    }

    if (!mounted) return;
    if (messagingUserId == null || messagingUserId.isEmpty) {
      AppNotification.showInfo(
        context,
        'Messaging is not available for this contractor yet.',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contractorId: messagingUserId!,
          contractorName: _proName().isEmpty ? 'Contractor' : _proName(),
          jobReference:
              '${_serviceName()} · ${widget.job['woNumber'] ?? _workOrderId()}',
        ),
      ),
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

  Future<void> _openReviewPage() async {
    if (_isReviewLoading) return;
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
          initialRating: (_review?['rating'] as num?)?.toDouble() ?? 0,
          hasExistingReview: _review != null,
          initialTags: (_review?['tags'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          initialReviewText: _review?['reviewText']?.toString() ??
              _review?['comment']?.toString() ??
              '',
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _review = result['deleted'] == true ? null : result;
      });
    } else if (mounted) {
      final cached = HomeownerService.instance.cachedReviewForWorkOrder(woId);
      if (cached != null) setState(() => _review = cached);
    }
  }

  Future<void> _cancelJob() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    final woId = int.tryParse(widget.job['id']?.toString() ??
            widget.job['workOrderId']?.toString() ??
            '0') ??
        0;

    var didCancel = false;
    try {
      await HomeownerService.instance
          .performWorkOrderAction(workOrderId: woId, action: 'cancel');
      if (!mounted) return;

      AppNotification.showSuccess(context, 'Booking cancelled.');
      didCancel = true;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        AppNotification.showError(
          context,
          error,
          fallback: 'We couldn\'t cancel this booking. Please try again.',
        );
      }
    } finally {
      if (mounted && !didCancel) setState(() => _isCancelling = false);
    }
  }

  Future<void> _requestReschedule() async {
    final changed = await openRescheduleWorkOrder(context, widget.job);
    if (!changed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reschedule request sent successfully.'),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _uploadReceipt() async {
    if (_uploadingReceipt) return;
    setState(() => _uploadingReceipt = true);
    try {
      final file = await DocumentUpload.pick();
      if (file == null) return;
      final document = await HomeownerService.instance.uploadWorkOrderReceipt(
          workOrderId: int.parse(_workOrderId()), file: file);
      final documentId = int.tryParse('${document['id']}');
      if (documentId == null) {
        throw Exception('The uploaded receipt was not confirmed.');
      }
      if (!mounted) return;
      setState(() {
        _receiptDocumentId = documentId;
        widget.job['receiptDocumentId'] = documentId;
        widget.job['receiptUploadedAt'] =
            document['updatedAt'] ?? document['updated_at'];
      });
      AppNotification.showSuccess(context, 'Receipt uploaded successfully.');
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  void _showReceiptModal(BuildContext context) {
    final invoice = _readString(widget.job['invoiceUrl']);
    final receipt = _readString(widget.job['paidReceiptUrl']);
    final documentId = _receiptDocumentId ??
        int.tryParse('${widget.job['receiptDocumentId']}');
    showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
                child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Job documents',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (invoice == null && receipt == null && documentId == null)
                  const Text('No invoice or paid receipt has been uploaded.'),
                if (invoice != null)
                  TextButton(
                      onPressed: () => _openReceiptUrl(invoice),
                      child: const Text('Open pro invoice')),
                if (receipt != null || documentId != null)
                  TextButton(
                      onPressed: () async {
                        try {
                          final url = documentId == null
                              ? receipt!
                              : await HomeownerService.instance
                                  .homeDocumentDownloadUrl(documentId);
                          await _openReceiptUrl(url);
                        } catch (e) {
                          if (mounted)
                            AppNotification.showError(this.context, e);
                        }
                      },
                      child: const Text('Open paid receipt')),
              ]),
            )));
  }

  Future<void> _openReceiptUrl(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('This document could not be opened.');
      }
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    }
  }
}

class _TimelineStep {
  final String title;
  final String? caption;

  const _TimelineStep(this.title, this.caption);
}

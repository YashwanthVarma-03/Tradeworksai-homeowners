import '../../widgets/loading_skeleton.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../ui/tw.dart';
import '../../widgets/capsules.dart';
import '../../widgets/alert_row.dart';
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
  late Map<String, dynamic> _job;
  bool _refreshingJob = false;
  Map<String, dynamic>? _review;
  bool _isReviewLoading = true;
  bool _isCancelling = false;
  bool _uploadingReceipt = false;
  int? _receiptDocumentId;
  final _moneyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
    HomeownerService.instance.syncVersion.addListener(_refreshFromSharedSync);
    unawaited(_refreshJob(forceRefresh: true));
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

  @override
  void dispose() {
    HomeownerService.instance.syncVersion
        .removeListener(_refreshFromSharedSync);
    super.dispose();
  }

  void _refreshFromSharedSync() => unawaited(_refreshJob());

  Future<void> _refreshJob({bool forceRefresh = false}) async {
    if (_refreshingJob) return;
    final id = int.tryParse('${_job['workOrderId'] ?? _job['id']}');
    if (id == null || id <= 0) return;
    _refreshingJob = true;
    try {
      final latest = await HomeownerService.instance
          .findWorkOrder(id, forceRefresh: forceRefresh);
      if (!mounted) return;
      final wasCompleted =
          WorkOrderStatus.fromJob(_job).state == WorkOrderState.completed;
      setState(() => _job = latest);
      if (!wasCompleted &&
          WorkOrderStatus.fromJob(latest).state == WorkOrderState.completed) {
        unawaited(_fetchReview());
      }
    } catch (_) {
      // Keep the last visible work order when a refresh is unavailable.
    } finally {
      _refreshingJob = false;
    }
  }

  Future<void> _fetchReview() async {
    final status = _job['status']?.toString().toLowerCase();
    final isCompleted = status == 'completed' ||
        status == 'complete' ||
        _job['timeline']?['completedAt'] != null;
    if (!isCompleted) {
      if (mounted) setState(() => _isReviewLoading = false);
      return;
    }

    try {
      final woId = int.tryParse(_job['id']?.toString() ??
              _job['workOrderId']?.toString() ??
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
    return _readString(_job['workOrderId']) ?? _readString(_job['id']) ?? '';
  }

  /// "WO-24144" — the work-order number, never the database id with a "#".
  String _woNumber() {
    final value = _readString(_job['woNumber']) ??
        _readString(_job['wo_number']) ??
        _readString(_job['workOrderNumber']) ??
        _readString(_job['work_order_number']) ??
        _workOrderId();
    return value.startsWith('#') ? value.substring(1) : value;
  }

  String _serviceName() {
    return _readString(_job['serviceCategory']) ??
        _readString(_job['service_category']) ??
        _readString(_job['serviceName']) ??
        _readString(_job['service_name']) ??
        _readString(_job['trade']) ??
        'Service Request';
  }

  String _addressText() {
    final address = _job['address'];
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
    final pro = _job['pro'];
    if (pro is Map) {
      return _readString(pro['businessName']) ??
          _readString(pro['business_name']) ??
          _readString(pro['name']) ??
          '';
    }
    return _readString(_job['proName']) ??
        _readString(_job['businessName']) ??
        '';
  }

  String _priorityText() {
    return _readString(_job['priority']) ??
        _readString(_job['urgency']) ??
        _readString(_job['serviceLevel']) ??
        'Standard';
  }

  /// The roster technician on the job ("Dale H."). Hidden until assigned.
  String? _technicianName() {
    final tech = _job['technician'];
    return (tech is Map
            ? _readString(tech['displayName'] ?? tech['name'])
            : _readString(tech)) ??
        _readString(_job['technicianName']) ??
        _readString(_job['technician_name']);
  }

  /// The gate / access code the homeowner gave at booking (Oct 1, G-53).
  String? _accessCode() =>
      _readString(_job['accessCode']) ?? _readString(_job['access_code']);

  String _timeWindowText() {
    final priority = _priorityText().toLowerCase();
    final deadline =
        _readString(_job['slaArrivalTarget'] ?? _job['sla_arrival_target']);
    if ((priority == 'urgent' || priority == 'emergency') && deadline != null) {
      return 'By ${_formatDateTime(deadline)}';
    }
    final start = _readString(_job['scheduledStart']);
    final end = _readString(_job['scheduledEnd']);
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
    final status = _job['status']?.toString() ?? 'Requested';
    final statusLower = status.toLowerCase();
    final service = _serviceName();
    final addressStr = _addressText();
    final dateStr = _timeWindowText();
    final woId = _woNumber();
    final proName = _proName();
    final displayPro = proName.isEmpty ? 'Pro details pending' : proName;
    final capPending = WorkOrderStatus.capPending(_job);
    final resolved = WorkOrderStatus.fromJob(_job);

    return TransactionGuard(
      isProcessing: _isCancelling,
      blockedMessage: 'Please wait while this booking is being cancelled.',
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        appBar: TwAppBar(
          title: 'Work order',
          onBack: () => Navigator.pop(context),
        ),
        // D04: the cap is the one thing the homeowner owes, so its button is
        // pinned above the home indicator instead of sitting at the end of
        // the scroll (SPEC §1.6).
        bottomNavigationBar: capPending
            ? TwStickyBar(
                children: [
                  TwPrimaryButton(
                    label: 'Review the cap',
                    onPressed: _openCapReview,
                  ),
                ],
              )
            : null,
        body: SingleChildScrollView(
          child: TwPage(
            top: TwSpace.s20,
            bottom: TwSpace.s40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: _woTitleStyle(context)),
                const SizedBox(height: TwSpace.s4),
                Text(woId, style: TwType.meta()),
                const SizedBox(height: 10),
                _statusChip(),
                if (WorkOrderStatus.proOnSite(_job))
                  Padding(
                    padding: const EdgeInsets.only(top: TwSpace.s12),
                    child: AlertRow(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppTheme.blue,
                      tint: AppTheme.blueTint,
                      title: '$displayPro has arrived',
                      body:
                          'Your pro marked their arrival for this work order.',
                    ),
                  ),
                // No-show (Oct 1): only while still Booked after the visit
                // window (ArrivalCheckState.pending); opens the report directly.
                if (ArrivalCheckState.pending(_job))
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: AlertRow(
                      icon: Icons.schedule_rounded,
                      title: 'Your visit window has passed',
                      body: 'Not started by your pro.',
                      footer: Align(
                        alignment: Alignment.centerLeft,
                        child: TwTextAction(
                          label: 'Report a no-show',
                          onPressed: () async {
                            if (await openArrivalCheck(context, _job) &&
                                mounted) Navigator.pop(context, true);
                          },
                        ),
                      ),
                    ),
                  ),
                if (resolved.state == WorkOrderState.noShowCustomer)
                  Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                          'Your pro reported that they could not reach you at the booked time. This is private. Contact support if this is incorrect.',
                          style: TwType.bodySm())),
                const SizedBox(height: TwSpace.s28),
                if (!resolved.isTerminalWithoutProgress) ...[
                  _sectionLabel('Status timeline'),
                  const SizedBox(height: TwSpace.s12),
                ],
                _buildTimeline(statusLower, dateStr),
                const SizedBox(height: TwSpace.s12),
                _proSection(displayPro),
                const SizedBox(height: TwSpace.s28),
                _sectionLabel('Details'),
                const SizedBox(height: TwSpace.s12),
                _detailsCard(
                  when: dateStr,
                  address: addressStr,
                  urgency: _priorityText(),
                  note: _readString(_job['description']) ??
                      _readString(_job['note']) ??
                      _readString(_job['customerNote']) ??
                      _readString(_job['serviceDescription']) ??
                      _noNote,
                ),
                const SizedBox(height: TwSpace.s28),
                KeyedSubtree(key: _moneyKey, child: _moneyCard()),
                if (!capPending) ...[
                  const SizedBox(height: TwSpace.s28),
                  _actions(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const String _noNote = 'No additional description';

  /// The work-order title: Outfit 26/32 (24/30 on Compact) — SPEC §2 h1.
  TextStyle _woTitleStyle(BuildContext context) => TwType.h1Mid(context);

  /// D03–D05: the pro, then one full-width Message button, between two
  /// hairlines. There is no Call button — homeowners reach the pro through
  /// TradeWorks messaging only (Batch 19 A1).
  Widget _proSection(String displayPro) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: TwSpace.s20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder),
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _proPanel(displayPro),
          const SizedBox(height: TwSpace.s16),
          TwSecondaryButton(
            label: 'Message',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: _openMessage,
            height: 50,
          ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final resolved = WorkOrderStatus.fromJob(_job);
    // Booked is the default and is not shown (design standard v3.3).
    return Wrap(spacing: 12, runSpacing: 6, children: [
      if (resolved.state != WorkOrderState.booked)
        WorkOrderStatusChip(resolved),
      if (resolved.waitingOnYou) const WaitingOnYouChip(),
    ]);
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: TwType.h2());
  }

  Widget _buildTimeline(String currentStatus, String dateStr) {
    final resolved = WorkOrderStatus.fromJob(_job);
    if (resolved.isTerminalWithoutProgress) return const SizedBox.shrink();
    final timeline = _job['timeline'];
    final arrivedAt = timeline is Map
        ? _readString(timeline['arrivedAt'] ?? timeline['arrived_at'])
        : null;
    final steps = <_TimelineStep>[
      _TimelineStep('Booked', _timelineBookedText(dateStr)),
      _TimelineStep(
          'En route',
          arrivedAt == null
              ? null
              : 'Arrived on site · ${_formatDateTime(arrivedAt)}'),
      const _TimelineStep('In progress', null),
      const _TimelineStep('Completed', null),
    ];

    final currentIndex = resolved.progressionIndex;
    final jobCompleted = resolved.state == WorkOrderState.completed;

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final timeline = _job['timeline'];
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
        // D05: the Completed step of a completed job is a green check.
        final isFinished = isActive && jobCompleted;
        final isLast = index == steps.length - 1;

        final Widget mark;
        if (isDone || isFinished) {
          mark = Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFinished ? AppTheme.greenMark : AppTheme.blue,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check_rounded, size: 12, color: Colors.white),
          );
        } else if (isActive) {
          mark = Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.blue, width: 6),
              boxShadow: const [
                BoxShadow(color: AppTheme.blueTint, spreadRadius: 3),
              ],
            ),
          );
        } else {
          mark = Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: 2),
            ),
          );
        }

        final Color labelColor = isFinished
            ? AppTheme.green
            : isActive
                ? AppTheme.blue
                : (index <= currentIndex
                    ? AppTheme.ink
                    : AppTheme.textSecondary);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    mark,
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: index < currentIndex
                              ? AppTheme.blue
                              : AppTheme.cardBorder,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: ConstrainedBox(
                    // Keeps a 22pt connector between steps without a caption.
                    constraints: BoxConstraints(minHeight: isLast ? 0 : 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TwType.title(color: labelColor).copyWith(
                            fontSize: 15,
                            height: 20 / 15,
                            fontWeight: index <= currentIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        if (step.caption != null) ...[
                          const SizedBox(height: 2),
                          Text(step.caption!, style: TwType.caption()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _timelineBookedText(String dateStr) {
    final scheduled =
        _readString(_job['createdAt']) ?? _readString(_job['created_at']);
    if (scheduled != null) return _formatDateTime(scheduled);
    return 'Not recorded';
  }

  Widget _proPanel(String proName) {
    final dynamic rating = _job['pro']?['verifiedRating'] ??
        _job['verifiedRating'] ??
        _job['proRating'];
    final proMap =
        _job['pro'] is Map ? _job['pro'] as Map : const <String, dynamic>{};
    final trade = _readString(proMap['category']) ??
        _readString(proMap['trade']) ??
        _readString(_job['trade']) ??
        _readString(_job['serviceCategory']) ??
        'Service professional';
    final reviewCount = proMap['verifiedReviewCount'] ??
        proMap['reviewCount'] ??
        _job['proReviewCount'];
    final num? ratingValue =
        rating is num ? rating : num.tryParse(rating?.toString() ?? '');
    final int? countValue = reviewCount is num
        ? reviewCount.toInt()
        : int.tryParse(reviewCount?.toString() ?? '');
    final logo = _readString(proMap['logoUrl'] ??
        proMap['logo_url'] ??
        proMap['avatarUrl'] ??
        proMap['avatar_url']);

    return Row(
      children: [
        TwAvatar(name: proName, imageUrl: logo, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TwType.h3(),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (ratingValue != null)
                    RatingCapsule(
                      rating: ratingValue,
                      count: countValue,
                      compact: TwLayout.size(context) == TwSize.compact,
                    ),
                  Text(trade, style: TwType.meta()),
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
    final valueStyle = TwType.bodySm(color: AppTheme.ink)
        .copyWith(fontWeight: FontWeight.w600);
    final technician = _technicianName();
    final accessCode = _accessCode();
    final urgent = _urgencyColor(urgency) == AppTheme.red;
    return SizedBox(
      width: double.infinity,
      child: TwFactPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TwDetailRow(label: 'When', value: when),
            if (technician != null) ...[
              const SizedBox(height: 14),
              TwDetailRow(label: 'Technician', value: technician),
            ],
            const SizedBox(height: 14),
            TwDetailRow(
              label: 'Address',
              value: address,
              valueWidget: accessCode == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address, style: valueStyle),
                        const SizedBox(height: TwSpace.s4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.key_outlined,
                                  size: 16, color: AppTheme.navy),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Gate code $accessCode · shared with your pro',
                                style: TwType.meta(color: AppTheme.body)
                                    .copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            TwDetailRow(
              label: 'Urgency',
              value: urgency,
              valueWidget: urgent
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 14, color: AppTheme.red),
                        const SizedBox(width: TwSpace.s4),
                        Flexible(
                          child: Text(
                            urgency,
                            style: TwType.bodySm(color: AppTheme.red)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      urgency,
                      style: TwType.bodySm(color: AppTheme.textSecondary)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
            ),
            const SizedBox(height: 14),
            TwDetailRow(
              label: 'Your note',
              value: note,
              valueWidget: note == _noNote
                  ? Text(note,
                      style: TwType.bodySm(color: AppTheme.textSecondary))
                  : null,
            ),
          ],
        ),
      ),
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
      _readString(_job['work_order_type']) ??
      _readString(_job['workOrderType']) ??
      'rate_card';

  double? _firstAmount(List<String> keys) {
    for (final key in keys) {
      final value = readAmount(_job[key]);
      if (value != null) return value;
    }
    return null;
  }

  bool get _receiptUploaded =>
      _receiptDocumentId != null ||
      _job['receiptDocumentId'] != null ||
      _readString(_job['paidReceiptUrl']) != null;

  bool get _receiptOwed =>
      !_receiptUploaded && WorkOrderStatus.receiptPending(_job);

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TwType.bodySm(color: AppTheme.body)),
        ),
        const SizedBox(width: TwSpace.s12),
        Text(
          value,
          style: TwType.bodySm(color: valueColor ?? AppTheme.navy).copyWith(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// D04: the cap waiting for approval, inside Job money.
  Widget _capBlock() {
    final quote =
        _job['quote'] is Map ? _job['quote'] as Map : const <String, dynamic>{};
    final cap = readAmount(_job['capAmount'] ??
        _job['cap_amount'] ??
        _job['quoteCap'] ??
        _job['quote_cap'] ??
        _job['quoteAmount'] ??
        _job['quote_amount'] ??
        quote['total'] ??
        quote['totalNTE'] ??
        _job['approvedCap'] ??
        _job['approved_cap']);
    final sentRaw = _readString(_job['capSubmittedAt'] ??
        _job['cap_submitted_at'] ??
        _job['quoteSentAt'] ??
        _job['quote_sent_at'] ??
        quote['createdAt']);
    final sent = sentRaw == null ? null : DateTime.tryParse(sentRaw)?.toLocal();
    final scope = _readString(_job['quoteScope'] ??
        _job['quote_scope'] ??
        quote['diagnosis'] ??
        _job['diagnosis']);
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
    final earn = readAmount(
        _job['receiptRewardAmount'] ?? _job['receipt_reward_amount']);
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
        WorkOrderStatus.fromJob(_job).state == WorkOrderState.completed;
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
    final meta = TwType.meta();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Job money'),
        const SizedBox(height: TwSpace.s12),
        SizedBox(
          width: double.infinity,
          child: TwCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: TwSpace.s8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(headline, style: TwType.display(context)),
                    if (headlineLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          headlineLabel,
                          style: TwType.bodySm(color: AppTheme.navy)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                if (type == 'nte') ...[
                  const SizedBox(height: TwSpace.s4),
                  Text(
                    '${_serviceName()} · You approve the cap',
                    style: TwType.label(),
                  ),
                ],
                if (type == 'quote_request') ...[
                  const SizedBox(height: TwSpace.s4),
                  Text('The pro sends you an estimate', style: meta),
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
                  Text('No customer-paid portion. This job earns no credits.',
                      style: meta),
                ],
                if (WorkOrderStatus.capPending(_job)) _capBlock(),
                if (completed && _receiptOwed) _receiptBlock(),
                if (completed && paid != 0 && _receiptUploaded) ...[
                  const SizedBox(height: 10),
                  Text('Paid receipt uploaded.', style: meta),
                ],
                const SizedBox(height: 14),
                Text(
                  'You pay your pro directly. TradeWorks adds no markup and takes no fee — we only fund the credits you apply.',
                  style: meta,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCapReview() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CapApprovalScreen(job: _job),
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
    final resolved = WorkOrderStatus.fromJob(_job);
    if (WorkOrderStatus.capPending(_job)) {
      // D04: "Review the cap" lives in the sticky bar (build()).
      return const SizedBox.shrink();
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
                    builder: (_) => NoShowReplyScreen(job: _job)));
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
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.pageBackground,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.border),
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

  // Batch 19 A1: no Call button and no tel: launcher on the homeowner side.
  // The pro is reached through Message only (see _proSection).
  Future<void> _openMessage() async {
    final pro = _job['pro'];
    final contractor = _job['contractor'];
    final proData = pro is Map
        ? Map<String, dynamic>.from(pro)
        : contractor is Map
            ? Map<String, dynamic>.from(contractor)
            : const <String, dynamic>{};
    String? messagingUserId =
        StreamService.instance.resolveMessagingUserId(proData) ??
            _readString(_job['chatUserId']) ??
            _readString(_job['chat_user_id']) ??
            _readString(_job['streamUserId']) ??
            _readString(_job['stream_user_id']) ??
            _readString(_job['contractorUserId']) ??
            _readString(_job['contractor_user_id']);

    if (messagingUserId == null) {
      final slug = _readString(_job['proSlug']) ??
          _readString(_job['pro_slug']) ??
          _readString(_job['contractorSlug']) ??
          _readString(_job['contractor_slug']) ??
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
              '${_serviceName()} · ${_job['woNumber'] ?? _workOrderId()}',
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
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 50),
      ),
    );
  }

  Future<void> _openReviewPage() async {
    if (_isReviewLoading) return;
    final woId = int.tryParse(
            _job['id']?.toString() ?? _job['workOrderId']?.toString() ?? '0') ??
        0;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LeaveReviewScreen(
          job: _job,
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

    final woId = int.tryParse(
            _job['id']?.toString() ?? _job['workOrderId']?.toString() ?? '0') ??
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
    final changed = await openRescheduleWorkOrder(context, _job);
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
        _job['receiptDocumentId'] = documentId;
        _job['receiptUploadedAt'] =
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
    final invoice = _readString(_job['invoiceUrl']);
    final receipt = _readString(_job['paidReceiptUrl']);
    final documentId =
        _receiptDocumentId ?? int.tryParse('${_job['receiptDocumentId']}');
    TwSheet.show<void>(context,
        scrollControlled: false,
        builder: (context) => SafeArea(
                child: Padding(
              padding: EdgeInsets.fromLTRB(
                  TwLayout.gutter(context), 8, TwLayout.gutter(context), 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Job documents', style: TwType.h3()),
                const SizedBox(height: TwSpace.s16),
                if (invoice == null && receipt == null && documentId == null)
                  Text('No invoice or paid receipt has been uploaded.',
                      style: TwType.bodySm()),
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

import '../widgets/loading_skeleton.dart';
import '../widgets/review_annotations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/display_format.dart';
import '../utils/work_order_status.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../services/homeowner_service.dart';
import '../widgets/app_notification.dart';
import 'work_orders/work_order_detail.dart';
import 'work_orders/cap_approval.dart';
import 'work_orders/leave_review.dart';
import 'work_orders/reschedule_work_order.dart';

class BookingsTab extends StatefulWidget {
  final VoidCallback onBookNowTap;
  final int initialSegment;

  const BookingsTab({
    super.key,
    required this.onBookNowTap,
    this.initialSegment = 0,
  });

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> with WidgetsBindingObserver {
  int _activeSegment = 0; // 0: Upcoming, 1: History

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<dynamic> _activeJobs = [];
  List<dynamic> _scheduledJobs = [];
  List<dynamic> _historyJobs = [];
  final Map<int, Map<String, dynamic>> _localReviews = {};
  final Set<int> _pendingWorkOrderActions = {};

  @override
  void initState() {
    super.initState();
    _activeSegment = _normalizeSegment(widget.initialSegment);
    WidgetsBinding.instance.addObserver(this);
    HomeownerService.instance.syncVersion.addListener(_refreshFromSharedSync);
    HomeownerService.instance.reviewVersion.addListener(_syncCachedReviews);
    _localReviews.addAll(HomeownerService.instance.cachedReviewsByWorkOrder);
    _restoreCachedJobsThenRefresh();
  }

  @override
  void dispose() {
    HomeownerService.instance.syncVersion
        .removeListener(_refreshFromSharedSync);
    HomeownerService.instance.reviewVersion.removeListener(_syncCachedReviews);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncCachedReviews() {
    if (!mounted) return;
    final reviews = HomeownerService.instance.cachedReviewsByWorkOrder;
    setState(() {
      _localReviews
        ..clear()
        ..addAll(reviews);
    });
  }

  void _refreshFromSharedSync() {
    _fetchJobs(showLoading: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchJobs(showLoading: false, forceRefresh: true);
    }
  }

  @override
  void didUpdateWidget(BookingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent passes a new initialSegment, or simply rebuilds, fetch fresh data.
    // Actually, to guarantee refresh, we can just trigger fetch when initialSegment changes.
    if (oldWidget.initialSegment != widget.initialSegment) {
      setState(() {
        _activeSegment = _normalizeSegment(widget.initialSegment);
      });
      _fetchJobs(showLoading: false);
    } else {
      // Also fetch jobs if widget updates without segment change, just to be safe
      // but maybe it's too much fetching. Let's just do it if segment changes,
      // and we will ensure the parent toggles the segment if needed.
    }
  }

  bool get _hasJobs =>
      _activeJobs.isNotEmpty ||
      _scheduledJobs.isNotEmpty ||
      _historyJobs.isNotEmpty;

  Future<void> _restoreCachedJobsThenRefresh() async {
    final cached = await HomeownerService.instance.loadCachedWorkOrders();
    if (!mounted) return;
    if (cached != null) {
      final tabs = cached['tabs'];
      _applyJobs(tabs);
    }
    await _fetchJobs(showLoading: false, forceRefresh: true);
  }

  void _applyJobs(dynamic tabs) {
    final rawActive = tabs is Map
        ? List<dynamic>.from(tabs['active'] ?? const [])
        : <dynamic>[];
    final rawScheduled = tabs is Map
        ? List<dynamic>.from(tabs['scheduled'] ?? const [])
        : <dynamic>[];
    final filteredActive = <dynamic>[];
    final filteredScheduled = [...rawScheduled];
    for (final job in rawActive) {
      if (job is Map && job['status'] == 'reschedule_pending') {
        filteredScheduled.add(job);
      } else {
        filteredActive.add(job);
      }
    }
    filteredScheduled.sort((a, b) {
      final aStart = a is Map ? (a['scheduledStart'] ?? '') : '';
      final bStart = b is Map ? (b['scheduledStart'] ?? '') : '';
      return aStart.compareTo(bStart);
    });
    setState(() {
      _activeJobs = filteredActive;
      _scheduledJobs = filteredScheduled;
      _historyJobs =
          tabs is Map ? List<dynamic>.from(tabs['history'] ?? []) : [];
      _isLoading = false;
      _errorMessage = null;
    });
    unawaited(_hydrateExistingReviews());
  }

  /// Work-order list responses can omit the nested review while eligibility
  /// correctly reports that one already exists. Load those completed reviews
  /// before rendering history so the homeowner sees what they submitted.
  Future<void> _hydrateExistingReviews() async {
    try {
      await HomeownerService.instance.hydrateReviewsFromWorkOrders({
        'tabs': {
          'active': _activeJobs,
          'scheduled': _scheduledJobs,
          'history': _historyJobs,
        },
      });
      _syncCachedReviews();
    } catch (_) {
      // The booking list remains usable if review history is temporarily
      // unavailable; pull-to-refresh or the next session sync retries it.
    }
  }

  Future<void> _fetchJobs({
    required bool showLoading,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showLoading && !_hasJobs) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _errorMessage = null;
    }
    try {
      final woData = await HomeownerService.instance.fetchWorkOrders(
        forceRefresh: forceRefresh,
      );
      final tabs = woData['tabs'];
      if (mounted) {
        _applyJobs(tabs);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              _hasJobs ? null : e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  int _normalizeSegment(int segment) {
    if (segment == 2) return 1;
    if (segment <= 0) return 0;
    return 1;
  }

  List<Map<String, dynamic>> get _upcomingJobs {
    return [
      ..._activeJobs
          .whereType<Map>()
          .map((job) => Map<String, dynamic>.from(job)),
      ..._scheduledJobs
          .whereType<Map>()
          .map((job) => Map<String, dynamic>.from(job)),
    ];
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String _jobProName(Map<String, dynamic> job) {
    final pro = job['pro'];
    if (pro is Map) {
      return _string(pro['businessName']) ??
          _string(pro['business_name']) ??
          _string(pro['name']) ??
          'Assigning Pro...';
    }
    return _string(job['proName']) ??
        _string(job['pro_name']) ??
        _string(job['businessName']) ??
        'Assigning Pro...';
  }

  String _jobService(Map<String, dynamic> job) {
    return _string(job['serviceCategory']) ??
        _string(job['service_category']) ??
        _string(job['serviceName']) ??
        _string(job['service_name']) ??
        _string(job['trade']) ??
        'Service Request';
  }

  String _jobAddress(Map<String, dynamic> job) {
    final address = job['address'];
    if (address is Map) {
      final street = _string(address['street']) ??
          _string(address['line1']) ??
          _string(address['addressLine1']);
      final city = _string(address['city']);
      if (street != null && city != null) return '$street, $city';
      return street ?? city ?? 'Home';
    }
    return _string(job['address']) ?? 'Home';
  }

  /// The job's real level (Oct 1) — read from every field it can arrive in,
  /// the same set `reschedule_work_order.dart` reads.
  String _jobPriority(Map<String, dynamic> job) {
    return _string(job['priority']) ??
        _string(job['urgency']) ??
        _string(job['urgencyLevel']) ??
        _string(job['urgency_level']) ??
        _string(job['serviceLevel']) ??
        _string(job['service_level']) ??
        'Standard';
  }

  int _jobRating(Map<String, dynamic> job) {
    final jobId = _resolveWorkOrderId(job);
    final localReview = _localReviews[jobId];
    final rawRating = localReview?['rating'] ??
        job['rating'] ??
        job['review']?['rating'] ??
        job['homeownerReview']?['rating'] ??
        job['homeowner_review']?['rating'] ??
        job['reviews']?['rating'];
    if (rawRating is num) return rawRating.round().clamp(0, 5);
    return int.tryParse(rawRating?.toString() ?? '')?.clamp(0, 5) ?? 0;
  }

  String _jobReviewText(Map<String, dynamic> job) {
    final jobId = _resolveWorkOrderId(job);
    final localText = _localReviews[jobId]?['reviewText']?.toString().trim();
    if (localText != null && localText != 'Already reviewed') {
      return localText;
    }

    return (job['reviewText'] ??
            job['review']?['text'] ??
            job['review']?['reviewText'] ??
            job['review']?['comment'] ??
            job['homeownerReview']?['text'] ??
            job['homeownerReview']?['reviewText'] ??
            job['homeownerReview']?['comment'] ??
            job['homeowner_review']?['text'] ??
            job['homeowner_review']?['reviewText'] ??
            job['homeowner_review']?['comment'] ??
            job['reviews']?['text'] ??
            job['reviews']?['reviewText'] ??
            job['reviews']?['comment'] ??
            '')
        .toString()
        .trim();
  }

  bool _jobHasReview(Map<String, dynamic> job) {
    final jobId = _resolveWorkOrderId(job);
    final localReview = _localReviews[jobId];
    final reviewText = _jobReviewText(job);
    return job['reviewed'] == true ||
        localReview != null ||
        reviewText.isNotEmpty ||
        _jobRating(job) > 0;
  }

  int _resolveWorkOrderId(Map<String, dynamic> job) {
    for (final key in const ['workOrderId', 'id']) {
      final value = job[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        final parsed = int.tryParse(value);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return 0;
  }

  DateTime? _parseDateTime(String? isoString) {
    if (isoString == null) return null;
    return DateTime.tryParse(isoString);
  }

  void _openCapApproval(Map<String, dynamic> job) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CapApprovalScreen(job: job)),
    );
    if (changed == true && mounted) {
      _fetchJobs(showLoading: false, forceRefresh: true);
    }
  }

  Future<void> _openReschedule(Map<String, dynamic> job) async {
    final changed = await openRescheduleWorkOrder(context, job);
    if (changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reschedule request sent successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
      _fetchJobs(showLoading: false, forceRefresh: true);
    }
  }

  void _cancelDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: Text('Cancel Booking', style: TwType.h3()),
        content: Text(
          'Are you sure you want to cancel this booking? Cancel is free before work begins, with no homeowner fees.',
          style: TwType.bodySm(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final workOrderId = _resolveWorkOrderId(job);
              if (workOrderId == 0 ||
                  !_pendingWorkOrderActions.add(workOrderId)) {
                return;
              }
              try {
                await HomeownerService.instance.performWorkOrderAction(
                  workOrderId: workOrderId,
                  action: 'cancel',
                  extra: {'reason': 'homeowner_cancelled'},
                );
                if (!mounted) return;
                AppNotification.showSuccess(
                  this.context,
                  'Booking cancelled successfully.',
                );
                _fetchJobs(showLoading: false);
              } catch (e) {
                if (!mounted) return;
                AppNotification.showError(
                  this.context,
                  e,
                  fallback:
                      'We couldn\'t cancel this booking. Please try again.',
                );
              } finally {
                _pendingWorkOrderActions.remove(workOrderId);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.red,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );
  }

  void _leaveReviewDialog(Map<String, dynamic> job) async {
    final jobId = _resolveWorkOrderId(job);
    Map<String, dynamic>? localReview = _localReviews[jobId];
    if (_jobHasReview(job)) {
      try {
        localReview = await HomeownerService.instance.getReview(jobId);
        if (localReview == null || localReview['detailsAvailable'] == false)
          throw Exception(
              'Your review could not be loaded. Please try again before editing.');
      } catch (e) {
        if (mounted) AppNotification.showError(context, e);
        return;
      }
      if (!mounted) return;
    }
    // Don't use placeholder text as actual review text
    final localReviewText = localReview?['reviewText']?.toString() ?? '';
    final isPlaceholder = localReviewText == 'Already reviewed';
    final existingReviewText = (localReview != null && !isPlaceholder)
        ? localReviewText
        : (job['reviewText'] ??
            job['review']?['text'] ??
            job['review']?['reviewText'] ??
            job['homeownerReview']?['text'] ??
            job['homeownerReview']?['reviewText'] ??
            job['homeowner_review']?['text'] ??
            job['homeowner_review']?['reviewText'] ??
            job['reviews']?['text'] ??
            '');
    final existingRating = localReview != null
        ? localReview['rating']
        : (job['rating'] ??
            job['review']?['rating'] ??
            job['homeownerReview']?['rating'] ??
            job['homeowner_review']?['rating'] ??
            job['reviews']?['rating'] ??
            0);
    final initialRating = existingRating is num
        ? existingRating.toDouble()
        : double.tryParse(existingRating.toString()) ?? 0.0;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LeaveReviewScreen(
          job: job,
          jobId: jobId,
          initialRating: initialRating,
          hasExistingReview: _jobHasReview(job),
          initialTags: (localReview?['tags'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          initialReviewText: isPlaceholder ? '' : existingReviewText.toString(),
        ),
      ),
    );

    if (result == null || !mounted) return;
    if (result['deleted'] == true) {
      _localReviews.remove(jobId);
      job.remove('review');
      job.remove('reviews');
      job.remove('homeownerReview');
      job.remove('homeowner_review');
      job.remove('rating');
      job.remove('reviewText');
      job['reviewed'] = false;
      await _fetchJobs(showLoading: false, forceRefresh: true);
      return;
    }
    final selectedRating = (result['rating'] as num?)?.toDouble() ?? 0;
    final reviewText = result['reviewText']?.toString() ?? '';
    if (jobId != 0) {
      _localReviews[jobId] = {
        ...result,
        'rating': selectedRating,
        'reviewText': reviewText,
      };
      job['reviewed'] = true;
      job['rating'] = selectedRating;
      job['reviewText'] = reviewText;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review submitted successfully.'),
        backgroundColor: AppTheme.success,
      ),
    );
    _fetchJobs(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBackground,
      child: Column(
        children: [
          _buildBookingsHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchJobs(showLoading: false),
              color: AppTheme.navy,
              child: _buildJobsList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Side padding that keeps the content in the gutter, and in a centred
  /// 560 column on Wide (SPEC §1).
  double _sidePadding(BuildContext context) {
    final gutter = TwLayout.gutter(context);
    final width = MediaQuery.of(context).size.width;
    final centred = (width - TwLayout.maxContent) / 2;
    return centred > gutter ? centred : gutter;
  }

  Widget _buildBookingsHeader() {
    final side = _sidePadding(context);
    final upcoming = _upcomingJobs.length;
    return Container(
      width: double.infinity,
      color: AppTheme.pageBackground,
      padding: EdgeInsets.fromLTRB(side, 14, side, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TwUnderlineTabs(
            labels: const ['Upcoming', 'History'],
            index: _activeSegment,
            onChanged: (index) => setState(() => _activeSegment = index),
            counts:
                _activeSegment == 0 && upcoming > 0 ? {0: upcoming} : const {},
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList() {
    if (_isLoading) {
      return const SkeletonPage(
        layout: SkeletonLayout.bookings,
        label: 'Loading bookings',
      );
    }

    if (_errorMessage != null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildErrorState(),
          ),
        ],
      );
    }

    final jobs = _activeSegment == 0
        ? _upcomingJobs
        : _historyJobs
            .whereType<Map>()
            .map((job) => Map<String, dynamic>.from(job))
            .toList();

    if (jobs.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyBookingsState(),
          ),
        ],
      );
    }

    final side = _sidePadding(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, TwSpace.s20, side, TwSpace.s28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _activeSegment == 0
                  ? _buildUpcomingItems(jobs)
                  : _buildHistoryItems(jobs),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(TwLayout.gutter(context)),
        child: TwEmptyState(
          icon: Icons.error_outline,
          title: _errorMessage!,
          action: TwSecondaryButton(
            label: 'Try again',
            expand: false,
            onPressed: () => _fetchJobs(showLoading: true),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUpcomingItems(List<Map<String, dynamic>> jobs) {
    final items = <Widget>[];
    final firstCap = jobs.indexWhere(WorkOrderStatus.capPending);
    for (var i = 0; i < jobs.length; i++) {
      final job = jobs[i];
      if (i > 0 && _isTomorrow(job) && !_isTomorrow(jobs[i - 1])) {
        items.add(const _BookingSectionLabel('Tomorrow'));
      }
      items.add(_buildUpcomingJobCard(job, primary: i == firstCap));
      if (i != jobs.length - 1) {
        items.add(const SizedBox(height: TwSpace.s12));
      }
    }
    return items;
  }

  /// Cancelled, declined and no-show jobs show "Book again" only.
  bool _historyIsCancelled(Map<String, dynamic> job) {
    final statusLower =
        (job['status']?.toString() ?? 'completed').toLowerCase();
    return statusLower == 'cancelled' ||
        statusLower == 'canceled' ||
        statusLower == 'cancel' ||
        statusLower == 'declined' ||
        statusLower == 'pro_no_show' ||
        statusLower == 'customer_no_show';
  }

  List<Widget> _buildHistoryItems(List<Map<String, dynamic>> jobs) {
    final lastWeek = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];
    for (final job in jobs) {
      (_isLastWeek(job) ? lastWeek : earlier).add(job);
    }

    // One orange per screen: the first card, in display order, that still
    // owes a review gets the primary "Leave a review" (D02).
    Map<String, dynamic>? firstReview;
    for (final job in [...lastWeek, ...earlier]) {
      if (!_historyIsCancelled(job) && !_jobHasReview(job)) {
        firstReview = job;
        break;
      }
    }
    Widget card(Map<String, dynamic> job) =>
        _buildHistoryJobCard(job, primary: identical(job, firstReview));

    // Each job sits in the bucket its own date puts it in — never moved up
    // to fill an empty "Last week".
    return [
      if (lastWeek.isNotEmpty) ...[
        const _BookingSectionLabel('Last week', first: true),
        ..._withSpacing(lastWeek.map(card)),
      ],
      if (earlier.isNotEmpty) ...[
        if (lastWeek.isNotEmpty) const SizedBox(height: TwSpace.s12),
        _BookingSectionLabel('Earlier', first: lastWeek.isEmpty),
        ..._withSpacing(earlier.map(card)),
      ],
    ];
  }

  List<Widget> _withSpacing(Iterable<Widget> cards) {
    final result = <Widget>[];
    final list = cards.toList();
    for (var i = 0; i < list.length; i++) {
      result.add(list[i]);
      if (i != list.length - 1) {
        result.add(const SizedBox(height: TwSpace.s12));
      }
    }
    return result;
  }

  Widget _buildUpcomingJobCard(Map<String, dynamic> job,
      {bool primary = false}) {
    final status = job['status']?.toString() ?? 'Active';
    final statusLower = status.toLowerCase();
    final isAlert = WorkOrderStatus.capPending(job);
    final resolved = WorkOrderStatus.fromJob(job);
    final isLive = resolved.state == WorkOrderState.enRoute ||
        resolved.state == WorkOrderState.inProgress;
    final isCancelled = statusLower == 'cancelled' ||
        statusLower == 'canceled' ||
        statusLower == 'cancel';

    final proName = _jobProName(job);
    final service = _jobService(job);
    final addressStr = _jobAddress(job);
    final tier = _jobPriority(job);

    return TwCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrderDetailScreen(job: job),
          ),
        ).then((_) => _fetchJobs(showLoading: false));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardTitleRow(service, job),
          const SizedBox(height: 14),
          _buildProviderRow(
            job: job,
            proName: proName,
            priority: tier,
          ),
          const SizedBox(height: 14),
          _buildInfoLine(
            icon: isAlert
                ? Icons.description_outlined
                : Icons.calendar_today_outlined,
            label: _formatUpcomingLine(job, isAlert: isAlert),
          ),
          const SizedBox(height: 6),
          _buildInfoLine(
            icon: Icons.location_on_outlined,
            label: addressStr,
          ),
          if (WorkOrderStatus.proOnSite(job)) ...[
            const SizedBox(height: TwSpace.s8),
            _buildInfoLine(
              icon: Icons.check_circle_outline_rounded,
              label: '$proName has arrived',
            ),
          ],
          if (isAlert) ...[
            const SizedBox(height: 14),
            primary
                ? _buildPrimaryAction(
                    label: 'Review the cap',
                    onPressed: () => _openCapApproval(job),
                  )
                : _buildOutlineAction(
                    label: 'Review the cap',
                    onPressed: () => _openCapApproval(job),
                  ),
          ] else if (isLive) ...[
            const SizedBox(height: 14),
            _buildLiveActions(job),
          ] else if (!isCancelled) ...[
            const SizedBox(height: 14),
            _buildScheduledActions(job),
          ],
        ],
      ),
    );
  }

  /// Service name (`h3`, up to 2 lines) with the status mark on the right.
  Widget _buildCardTitleRow(String service, Map<String, dynamic> job) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            service,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TwType.h3(),
          ),
        ),
        const SizedBox(width: TwSpace.s12),
        Flexible(flex: 2, child: _buildStatusBadge(job)),
      ],
    );
  }

  String? _jobProImage(Map<String, dynamic> job) {
    final pro = job['pro'];
    if (pro is! Map) return null;
    return _string(pro['logoUrl'] ??
        pro['logo_url'] ??
        pro['avatarUrl'] ??
        pro['avatar_url']);
  }

  Widget _buildProviderRow({
    required Map<String, dynamic> job,
    required String proName,
    required String priority,
  }) {
    return Row(
      children: [
        TwAvatar(name: proName, imageUrl: _jobProImage(job), size: 40),
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
              const SizedBox(height: 2),
              _urgencyMeta(priority),
            ],
          ),
        ),
      ],
    );
  }

  /// The job's real level under the pro name (Oct 1): Standard in grey,
  /// Urgent / Emergency in red with a clock.
  Widget _urgencyMeta(String priority) {
    final p = priority.toLowerCase();
    final level = p.contains('emergency')
        ? 'Emergency'
        : p.contains('urgent')
            ? 'Urgent'
            : 'Standard';
    if (level == 'Standard') {
      return Text(
        'Standard',
        style: TwType.caption().copyWith(fontWeight: FontWeight.w500),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.red),
        const SizedBox(width: TwSpace.s4),
        Text(
          level,
          style: TwType.caption(color: AppTheme.red)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> job) {
    final resolved = WorkOrderStatus.fromJob(job);
    // Booked is the default and is not shown on rows (design standard v3.3).
    return Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 6,
        children: [
          if (resolved.state != WorkOrderState.booked)
            WorkOrderStatusChip(resolved),
          if (resolved.waitingOnYou) const WaitingOnYouChip(),
        ]);
  }

  Widget _buildInfoLine({required IconData icon, required String label}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: AppTheme.navy, size: 16),
        ),
        const SizedBox(width: TwSpace.s8),
        Expanded(child: Text(label, style: TwType.meta())),
      ]);

  Widget _buildLiveActions(Map<String, dynamic> job) => _buildOutlineAction(
        label: 'View booking',
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkOrderDetailScreen(job: job),
            )).then((_) => _fetchJobs(showLoading: false)),
      );

  Widget _buildScheduledActions(Map<String, dynamic> job) {
    // Only Standard bookings can be rescheduled, and only while Booked
    // (Sep 30). Urgent and Emergency are a 24h / 4h commitment.
    final level = _jobPriority(job).toLowerCase();
    final canReschedule = !level.contains('urgent') &&
        !level.contains('emergency') &&
        WorkOrderStatus.fromJob(job).state == WorkOrderState.booked;
    return Row(
      children: [
        if (canReschedule)
          Expanded(
            child: _buildOutlineAction(
              label: 'Reschedule',
              onPressed: () => _openReschedule(job),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: TwSpace.s16),
        TextButton(
          onPressed: () => _cancelDialog(job),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.red,
            minimumSize: const Size(88, 44),
          ),
          child: Text(
            'Cancel',
            style: TwType.link(color: AppTheme.red),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBookingsState() {
    final history = _activeSegment == 1;
    final title = history ? 'No history yet' : 'No bookings yet';
    final subtitle = history
        ? 'Completed and cancelled work orders will show up here.'
        : 'When you book a service, your work orders will show up here.';

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            TwLayout.gutter(context), 48, TwLayout.gutter(context), 32),
        child: TwEmptyState(
          icon: Icons.calendar_today_outlined,
          title: title,
          message: subtitle,
          action: TwSecondaryButton(
            label: 'Browse services',
            expand: false,
            onPressed: widget.onBookNowTap,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryJobCard(Map<String, dynamic> job,
      {bool primary = false}) {
    final isCancelled = _historyIsCancelled(job);
    final proName = _jobProName(job);
    final service = _jobService(job);
    final address = _jobAddress(job);
    final reviewed = _jobHasReview(job);
    final reviewRating = _jobRating(job);
    final reviewText = _jobReviewText(job);

    return TwCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrderDetailScreen(job: job),
          ),
        ).then((_) => _fetchJobs(showLoading: false));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardTitleRow(service, job),
          const SizedBox(height: 14),
          _buildProviderRow(
            job: job,
            proName: proName,
            priority: _jobPriority(job),
          ),
          const SizedBox(height: 14),
          _buildInfoLine(
            icon: Icons.description_outlined,
            label: _formatHistoryLine(job, isCancelled: isCancelled),
          ),
          const SizedBox(height: 6),
          _buildInfoLine(
            icon: Icons.location_on_outlined,
            label: address,
          ),
          if (WorkOrderStatus.receiptPending(job)) ...[
            const SizedBox(height: 14),
            _buildReceiptRow(job),
          ],
          const SizedBox(height: 14),
          _buildHistoryActions(
            job,
            reviewed: reviewed,
            reviewRating: reviewRating,
            reviewText: reviewText,
            isCancelled: isCancelled,
            primary: primary,
          ),
        ],
      ),
    );
  }

  /// D02: the paid receipt is owed on a completed job — Waiting on you
  /// (Oct 1, G-46). Upload opens the work order at its money section.
  Widget _buildReceiptRow(Map<String, dynamic> job) {
    final earn =
        readAmount(job['receiptRewardAmount'] ?? job['receipt_reward_amount']);
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.amberTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.upload_rounded,
                size: 18, color: AppTheme.amber),
          ),
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
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: AppTheme.body,
                      fontSize: 14,
                      height: 1.43,
                    ),
                    children: [
                      if (earn != null && earn > 0) ...[
                        const TextSpan(text: 'Earn '),
                        TextSpan(
                          text: formatUsd(earn),
                          style: const TextStyle(
                            color: AppTheme.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' in credits on this job.'),
                      ] else
                        const TextSpan(text: 'Earn credits on this job.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    WorkOrderDetailScreen(job: job, focusMoney: true),
              ),
            ).then((_) => _fetchJobs(showLoading: false)),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryActions(
    Map<String, dynamic> job, {
    required bool reviewed,
    required int reviewRating,
    required String reviewText,
    required bool isCancelled,
    bool primary = false,
  }) {
    if (isCancelled) {
      return _buildOutlineAction(
        label: 'Book again',
        onPressed: widget.onBookNowTap,
      );
    }

    if (reviewed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (reviewRating > 0)
                Semantics(
                  label: '$reviewRating out of 5 stars',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (index) => Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
                        child: Icon(
                          index < reviewRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: index < reviewRating
                              ? AppTheme.gold
                              : AppTheme.textTertiary,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.check_rounded,
                  color: AppTheme.greenMark,
                  size: 16,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review submitted',
                  style: TwType.label(color: AppTheme.green),
                ),
              ),
              TwSecondaryButton(
                label: 'Book again',
                expand: false,
                height: 44,
                onPressed: widget.onBookNowTap,
              ),
            ],
          ),
          ReviewAnnotations(
              businessName: _jobProName(job),
              review: _localReviews[_resolveWorkOrderId(job)] ??
                  HomeownerService.instance
                      .cachedReviewForWorkOrder(_resolveWorkOrderId(job)) ??
                  const {}),
          TextButton(
              onPressed: () => _leaveReviewDialog(job),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: Text('Edit your review', style: TwType.link())),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s4),
            Text(
              '“$reviewText”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TwType.meta(color: AppTheme.body),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: primary
              ? _buildPrimaryAction(
                  label: 'Leave a review',
                  onPressed: () => _openReviewWhenEligible(job),
                )
              : _buildOutlineAction(
                  label: 'Leave a review',
                  onPressed: () => _openReviewWhenEligible(job),
                ),
        ),
        const SizedBox(width: TwSpace.s12),
        Expanded(
          child: _buildOutlineAction(
            label: 'Book again',
            onPressed: widget.onBookNowTap,
            height: primary ? 52 : 50,
          ),
        ),
      ],
    );
  }

  /// The orange call to action: navy label on orange, 52 high (SPEC §4).
  Widget _buildPrimaryAction({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TwPrimaryButton(label: label, onPressed: onPressed);
  }

  /// Secondary: white, #D0D5DD border, ink label, 50 high (SPEC §4).
  Widget _buildOutlineAction({
    required String label,
    required VoidCallback onPressed,
    double height = 50,
  }) {
    return TwSecondaryButton(
      label: label,
      onPressed: onPressed,
      height: height,
    );
  }

  Future<void> _openReviewWhenEligible(Map<String, dynamic> job) async {
    var isLoadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: LoadingSkeleton(
            itemCount: 1,
            layout: SkeletonLayout.form,
            label: 'Checking review availability'),
      ),
    );

    try {
      final jobId = _resolveWorkOrderId(job);
      final eligibility = await HomeownerService.instance
          .getReviewEligibility(workOrderId: jobId);
      if (mounted) {
        Navigator.pop(context);
        isLoadingDialogOpen = false;
      }

      if (eligibility['eligible'] == false) {
        final reason = eligibility['reason']?.toString();
        if (!mounted) return;
        if (reason == 'already_reviewed') {
          HomeownerService.instance.rememberReviewedWorkOrder(jobId);
          _syncCachedReviews();
        } else if (reason == 'not_completed') {
          AppNotification.showInfo(
            context,
            'Only completed services can be reviewed.',
          );
        } else {
          AppNotification.showInfo(
            context,
            'This service is not eligible for review yet.',
          );
        }
        return;
      }

      if (mounted) _leaveReviewDialog(job);
    } catch (e) {
      if (mounted) {
        if (isLoadingDialogOpen) Navigator.pop(context);
        AppNotification.showError(
          context,
          e,
          fallback: 'We couldn\'t check review eligibility. Please try again.',
        );
      }
    }
  }

  bool _isTomorrow(Map<String, dynamic> job) {
    final start = _parseDateTime(job['scheduledStart']?.toString());
    if (start == null) return false;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return start.year == tomorrow.year &&
        start.month == tomorrow.month &&
        start.day == tomorrow.day;
  }

  /// Within the last 7 calendar days, by completion date when there is one.
  bool _isLastWeek(Map<String, dynamic> job) {
    final timeline = job['timeline'];
    final raw = (timeline is Map ? timeline['completedAt'] : null) ??
        job['completedAt'] ??
        job['completed_at'] ??
        job['scheduledStart'];
    final date = _parseDateTime(raw?.toString())?.toLocal();
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;
    return days >= 0 && days <= 7;
  }

  String _formatUpcomingLine(
    Map<String, dynamic> job, {
    required bool isAlert,
  }) {
    if (isAlert) return 'Your pro sent a cap · you approve it';

    final start = _parseDateTime(job['scheduledStart']?.toString());
    final end = _parseDateTime(job['scheduledEnd']?.toString());
    if (start == null) return 'Date TBD';
    return '${_relativeDateLabel(start)} · ${_timeRangeLabel(start, end)}';
  }

  String _formatHistoryLine(
    Map<String, dynamic> job, {
    required bool isCancelled,
  }) {
    final start = _parseDateTime(job['scheduledStart']?.toString());
    if (isCancelled) return '${_monthDayLabel(start)} · Cancelled by you';
    final amount = _paidAmount(job);
    return amount == null
        ? '${_monthDayLabel(start)} · Paid'
        : '${_monthDayLabel(start)} · Paid $amount';
  }

  String _relativeDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final days = target.difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return _monthDayLabel(date);
  }

  String _monthDayLabel(DateTime? date) {
    if (date == null) return 'Date TBD';
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
    return '${months[date.month - 1]} ${date.day}';
  }

  String _timeRangeLabel(DateTime start, DateTime? end) {
    if (end == null) return _clockLabel(start);
    final samePeriod = (start.hour >= 12) == (end.hour >= 12);
    if (samePeriod && start.minute == 0 && end.minute == 0) {
      return '${_hourLabel(start)}–${_clockLabel(end)}';
    }
    return '${_clockLabel(start)}–${_clockLabel(end)}';
  }

  String _hourLabel(DateTime date) {
    var hour = date.hour % 12;
    if (hour == 0) hour = 12;
    return hour.toString();
  }

  String _clockLabel(DateTime date) {
    var hour = date.hour % 12;
    if (hour == 0) hour = 12;
    final minute =
        date.minute == 0 ? '' : ':${date.minute.toString().padLeft(2, '0')}';
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour$minute $period';
  }

  String? _paidAmount(Map<String, dynamic> job) {
    for (final key in const [
      'paidAmount',
      'paid_amount',
      'total',
      'totalAmount',
      'finalAmount',
      'amount',
      'price',
    ]) {
      final value = job[key];
      if (value is num) return formatUsd(value);
      final parsed = num.tryParse(value?.toString() ?? '');
      if (parsed != null) return formatUsd(parsed);
    }
    return null;
  }
}

class _BookingSectionLabel extends StatelessWidget {
  final String label;
  final bool first;

  const _BookingSectionLabel(this.label, {this.first = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : TwSpace.s12,
        bottom: TwSpace.s12,
      ),
      child: Text(label, style: TwType.h2()),
    );
  }
}

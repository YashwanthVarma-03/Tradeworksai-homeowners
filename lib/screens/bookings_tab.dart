import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart';
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

  String _jobPriority(Map<String, dynamic> job) {
    return _string(job['priority']) ??
        _string(job['urgency']) ??
        _string(job['serviceLevel']) ??
        'Standard';
  }

  String _jobInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final initials =
        parts.map((part) => part.trim()[0]).take(2).join().toUpperCase();
    return initials.isEmpty ? 'P' : initials;
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
        title: const Text('Cancel Booking',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
        content: const Text(
          'Are you sure you want to cancel this booking? Cancel is free before work begins, with no homeowner fees.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );
  }

  void _leaveReviewDialog(Map<String, dynamic> job) async {
    final jobId = _resolveWorkOrderId(job);
    final localReview = _localReviews[jobId];
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
            5);
    final initialRating = existingRating is num
        ? existingRating.toDouble()
        : double.tryParse(existingRating.toString()) ?? 5.0;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LeaveReviewScreen(
          job: job,
          jobId: jobId,
          initialRating: initialRating,
          initialReviewText: isPlaceholder ? '' : existingReviewText.toString(),
        ),
      ),
    );

    if (result == null || !mounted) return;
    final selectedRating = (result['rating'] as num?)?.toDouble() ?? 5;
    final reviewText = result['reviewText']?.toString() ?? '';
    if (jobId != 0) {
      _localReviews[jobId] = {
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
      color: Colors.white,
      child: Column(
        children: [
          _buildBookingsHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.pageBackground,
                border: Border(
                  top: BorderSide(color: AppTheme.cardBorder, width: 1),
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () => _fetchJobs(showLoading: false),
                color: AppTheme.orange500,
                child: _buildJobsList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: _buildHeaderControls(),
    );
  }

  Widget _buildHeaderControls() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(100),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _activeSegment * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.navy700,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _buildSegmentTap(
                    index: 0,
                    label: 'Upcoming',
                    count: _upcomingJobs.length,
                  ),
                  _buildSegmentTap(
                    index: 1,
                    label: 'History',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentTap({
    required int index,
    required String label,
    int? count,
  }) {
    final selected = _activeSegment == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => setState(() => _activeSegment = index),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1,
                ),
                child: Text(label),
              ),
              if (selected && count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTheme.orange500,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsList() {
    if (_isLoading) {
      return const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.orange500),
            ),
          ),
        ],
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 46, color: AppTheme.error),
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _buildOutlineAction(
            label: 'Try again',
            onPressed: () => _fetchJobs(showLoading: true),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildUpcomingItems(List<Map<String, dynamic>> jobs) {
    final items = <Widget>[];
    for (var i = 0; i < jobs.length; i++) {
      final job = jobs[i];
      if (i > 0 && _isTomorrow(job) && !_isTomorrow(jobs[i - 1])) {
        items.add(const _BookingSectionLabel('TOMORROW'));
      }
      items.add(_buildUpcomingJobCard(job));
      if (i != jobs.length - 1) {
        items.add(const SizedBox(height: 12));
      }
    }
    return items;
  }

  List<Widget> _buildHistoryItems(List<Map<String, dynamic>> jobs) {
    final lastWeek = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];
    for (final job in jobs) {
      (_isLastWeek(job) ? lastWeek : earlier).add(job);
    }

    final visibleLastWeek = lastWeek.isEmpty && earlier.isNotEmpty
        ? earlier.take(2).toList()
        : lastWeek;
    final visibleEarlier = lastWeek.isEmpty && earlier.length > 2
        ? earlier.skip(2).toList()
        : earlier;

    return [
      if (visibleLastWeek.isNotEmpty) ...[
        const _BookingSectionLabel('LAST WEEK'),
        ..._withSpacing(visibleLastWeek.map(_buildHistoryJobCard)),
      ],
      if (visibleEarlier.isNotEmpty) ...[
        const _BookingSectionLabel('EARLIER'),
        ..._withSpacing(visibleEarlier.map(_buildHistoryJobCard)),
      ],
    ];
  }

  List<Widget> _withSpacing(Iterable<Widget> cards) {
    final result = <Widget>[];
    final list = cards.toList();
    for (var i = 0; i < list.length; i++) {
      result.add(list[i]);
      if (i != list.length - 1) {
        result.add(const SizedBox(height: 12));
      }
    }
    return result;
  }

  Widget _buildUpcomingJobCard(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'Active';
    final statusLower = status.toLowerCase();
    final isAlert =
        statusLower.contains('quote') || statusLower.contains('review');
    final isLive = statusLower == 'en_route' ||
        statusLower == 'in_progress' ||
        statusLower == 'arrived';
    final isCancelled = statusLower == 'cancelled' ||
        statusLower == 'canceled' ||
        statusLower == 'cancel';

    final proName = _jobProName(job);
    final service = _jobService(job);
    final addressStr = _jobAddress(job);
    final tier = _jobPriority(job);
    final initials = _jobInitials(proName);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrderDetailScreen(job: job),
          ),
        ).then((_) => _fetchJobs(showLoading: false));
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Stack(
          children: [
            if (isAlert)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 4,
                  child: ColoredBox(color: AppTheme.orange500),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(isAlert ? 20 : 14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildProviderRow(
                    initials: initials,
                    proName: proName,
                    priority: tier,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoLine(
                    icon: Icons.insert_drive_file_outlined,
                    label: _formatUpcomingLine(job, isAlert: isAlert),
                  ),
                  const SizedBox(height: 6),
                  _buildInfoLine(
                    icon: Icons.location_on_outlined,
                    label: addressStr,
                  ),
                  if (isLive) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppTheme.cardBorder),
                    const SizedBox(height: 12),
                    _buildProgressTracker(statusLower),
                  ],
                  const SizedBox(height: 12),
                  if (isAlert)
                    _buildPrimaryAction(
                      label: 'Review the cap',
                      onPressed: () => _openCapApproval(job),
                    )
                  else if (isLive)
                    _buildLiveActions(job)
                  else if (!isCancelled)
                    _buildScheduledActions(job),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderRow({
    required String initials,
    required String proName,
    required String priority,
  }) {
    final avatarColor = _avatarColor(initials);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: avatarColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  proName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildPriorityBadge(priority),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final urgent = priority.toLowerCase().contains('urgent');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: urgent ? AppTheme.blueTint : AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        urgent ? 'URGENT' : 'STANDARD',
        style: TextStyle(
          color: urgent ? AppTheme.teal500 : AppTheme.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final label = _getStatusText(status);
    final lower = status.toLowerCase();
    final isCapPending = lower.contains('quote') || lower.contains('review');
    final isCompleted = lower == 'completed' || lower == 'complete';
    final isCancelled = lower == 'cancelled' ||
        lower == 'canceled' ||
        lower == 'cancel' ||
        lower == 'declined';
    final color = isCapPending
        ? AppTheme.orange500
        : isCompleted
            ? AppTheme.success
            : isCancelled
                ? AppTheme.red
                : AppTheme.teal500;
    final fill = isCapPending
        ? AppTheme.orangeTint
        : isCompleted
            ? AppTheme.greenTint
            : isCancelled
                ? const Color(0xFFFFF1F2)
                : AppTheme.tealTint;
    final icon = isCancelled
        ? Icons.close_rounded
        : lower == 'en_route'
            ? Icons.local_shipping_outlined
            : lower == 'scheduled' || lower == 'booked'
                ? Icons.calendar_today_outlined
                : Icons.insert_drive_file_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine({
    required IconData icon,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTracker(String statusLower) {
    final currentStep = statusLower == 'en_route'
        ? 2
        : statusLower == 'arrived'
            ? 4
            : 1;

    return Column(
      children: [
        Row(
          children: List.generate(9, (index) {
            if (index.isOdd) {
              final lineStep = (index / 2).floor();
              return Expanded(
                child: Container(
                  height: 3,
                  color: lineStep < currentStep
                      ? AppTheme.teal500
                      : AppTheme.cardBorder,
                ),
              );
            }
            final step = index ~/ 2;
            final active = step == currentStep;
            final done = step <= currentStep;
            return Container(
              width: active ? 14 : 12,
              height: active ? 14 : 12,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : done
                        ? AppTheme.teal500
                        : AppTheme.cardBorder,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: AppTheme.teal500, width: 3)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Booked',
              style: TextStyle(
                color: AppTheme.teal500,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'En route',
              style: TextStyle(
                color: AppTheme.teal500,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Arrived',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveActions(Map<String, dynamic> job) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: _buildOutlineAction(
            label: 'Track',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkOrderDetailScreen(job: job),
                ),
              ).then((_) => _fetchJobs(showLoading: false));
            },
          ),
        ),
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Live · updated just now',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledActions(Map<String, dynamic> job) {
    return Row(
      children: [
        Expanded(
          child: _buildOutlineAction(
            label: 'Reschedule',
            onPressed: () => _openReschedule(job),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildOutlineAction(
            label: 'Cancel',
            color: AppTheme.error,
            onPressed: () => _cancelDialog(job),
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
        : 'When you book a service, your work\norders will show up here.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildEmptyIllustration(),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 18,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.28,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            child: _buildPrimaryAction(
              label: 'Browse services',
              onPressed: widget.onBookNowTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyIllustration() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navy900.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.blueTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: AppTheme.navy700,
              size: 28,
            ),
          ),
          Positioned(
            right: 11,
            bottom: 11,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.orange500,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryJobCard(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'completed';
    final statusLower = status.toLowerCase();
    final isCancelled = statusLower == 'cancelled' ||
        statusLower == 'canceled' ||
        statusLower == 'cancel' ||
        statusLower == 'declined' ||
        statusLower == 'pro_no_show' ||
        statusLower == 'customer_no_show';
    final proName = _jobProName(job);
    final service = _jobService(job);
    final address = _jobAddress(job);
    final initials = _jobInitials(proName);
    final reviewed = _jobHasReview(job);
    final reviewRating = _jobRating(job);
    final reviewText = _jobReviewText(job);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          _buildProviderRow(
            initials: initials,
            proName: proName,
            priority: _jobPriority(job),
          ),
          const SizedBox(height: 12),
          _buildInfoLine(
            icon: Icons.insert_drive_file_outlined,
            label: _formatHistoryLine(job, isCancelled: isCancelled),
          ),
          const SizedBox(height: 6),
          _buildInfoLine(
            icon: Icons.location_on_outlined,
            label: address,
          ),
          const SizedBox(height: 12),
          _buildHistoryActions(
            job,
            reviewed: reviewed,
            reviewRating: reviewRating,
            reviewText: reviewText,
            isCancelled: isCancelled,
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
                      (index) => Icon(
                        index < reviewRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: index < reviewRating
                            ? AppTheme.orange500
                            : AppTheme.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 19,
                ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Review submitted',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: _buildOutlineAction(
                  label: 'Book again',
                  onPressed: widget.onBookNowTap,
                ),
              ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“$reviewText”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 12.5,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildPrimaryAction(
            label: 'Leave a review',
            onPressed: () => _openReviewWhenEligible(job),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOutlineAction(
            label: 'Book again',
            onPressed: widget.onBookNowTap,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryAction({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange500,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineAction({
    required String label,
    required VoidCallback onPressed,
    Color color = AppTheme.navy700,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: color == AppTheme.navy700
                ? AppTheme.cardBorder
                : color.withOpacity(0.52),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReviewWhenEligible(Map<String, dynamic> job) async {
    var isLoadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
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

  Color _avatarColor(String initials) {
    if (initials == 'CA') return AppTheme.teal500;
    if (initials == 'SE') return AppTheme.pageBackground;
    return AppTheme.navy700;
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

  bool _isLastWeek(Map<String, dynamic> job) {
    final start = _parseDateTime(job['scheduledStart']?.toString());
    if (start == null) return false;
    final now = DateTime.now();
    final days = now.difference(start).inDays;
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
      return '${_hourLabel(start)}-${_clockLabel(end)}';
    }
    return '${_clockLabel(start)}-${_clockLabel(end)}';
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
      if (value is num) {
        return '\$${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(2)}';
      }
      final parsed = num.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return '\$${parsed % 1 == 0 ? parsed.toInt() : parsed.toStringAsFixed(2)}';
      }
    }
    return null;
  }

  String _getStatusText(String status) {
    status = status.toLowerCase();
    if (status.contains('quote') || status.contains('review')) {
      return 'Waiting on you';
    }
    if (status == 'en_route') return 'En route';
    if (status == 'in_progress') return 'In progress';
    if (status == 'arrived') return 'Arrived';
    if (status == 'completed' || status == 'complete') return 'Completed';
    if (status == 'cancelled' || status == 'cancel') return 'Cancelled';
    if (status == 'scheduled' || status == 'booked') return 'Booked';
    return status.toUpperCase();
  }
}

class _BookingSectionLabel extends StatelessWidget {
  final String label;

  const _BookingSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.2,
        ),
      ),
    );
  }
}

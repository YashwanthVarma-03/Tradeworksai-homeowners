import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../widgets/custom_widgets.dart';
import '../services/homeowner_service.dart';
import '../utils/app_error_utils.dart';
import '../widgets/offline_state.dart';
import 'work_orders/work_order_detail.dart';
import 'work_orders/quote_review.dart';
import 'work_orders/receipt.dart';

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
  int _activeSegment = 0; // 0: Active, 1: Scheduled, 2: History

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<dynamic> _activeJobs = [];
  List<dynamic> _scheduledJobs = [];
  List<dynamic> _historyJobs = [];
  final Map<int, Map<String, dynamic>> _localReviews = {};

  @override
  void initState() {
    super.initState();
    _activeSegment = widget.initialSegment;
    WidgetsBinding.instance.addObserver(this);
    _fetchJobs(showLoading: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchJobs(showLoading: false);
    }
  }

  @override
  void didUpdateWidget(BookingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent passes a new initialSegment, or simply rebuilds, fetch fresh data.
    // Actually, to guarantee refresh, we can just trigger fetch when initialSegment changes.
    if (oldWidget.initialSegment != widget.initialSegment) {
      setState(() {
        _activeSegment = widget.initialSegment;
      });
      _fetchJobs(showLoading: false);
    } else {
      // Also fetch jobs if widget updates without segment change, just to be safe
      // but maybe it's too much fetching. Let's just do it if segment changes,
      // and we will ensure the parent toggles the segment if needed.
    }
  }

  Future<void> _fetchJobs({required bool showLoading}) async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showLoading ||
        (_activeJobs.isEmpty &&
            _scheduledJobs.isEmpty &&
            _historyJobs.isEmpty)) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _errorMessage = null;
    }
    try {
      final woData = await HomeownerService.instance.fetchWorkOrders();
      final tabs = woData['tabs'];
      if (mounted) {
        setState(() {
          final rawActive = tabs != null ? List<dynamic>.from(tabs['active'] ?? []) : [];
          final rawScheduled = tabs != null ? List<dynamic>.from(tabs['scheduled'] ?? []) : [];
          
          final List<dynamic> filteredActive = [];
          final List<dynamic> filteredScheduled = [...rawScheduled];
          
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
          
          _activeJobs = filteredActive;
          _scheduledJobs = filteredScheduled;
          _historyJobs = tabs != null ? (tabs['history'] ?? []) : [];
          _isLoading = false;
        });

        // Background pre-check for review eligibility to toggle "Edit review" / "Leave review" buttons
        for (final job in _historyJobs) {
          if (job is Map) {
            final typedJob = Map<String, dynamic>.from(job);
            final jobId = _resolveWorkOrderId(typedJob);
            if (jobId > 0 && !_localReviews.containsKey(jobId)) {
              HomeownerService.instance.getReviewEligibility(workOrderId: jobId).then((eligibility) {
                if (eligibility['eligible'] == false && eligibility['reason'] == 'already_reviewed') {
                  if (mounted) {
                    setState(() {
                      _localReviews[jobId] = {
                        'rating': 5,
                        'reviewText': 'Already reviewed',
                      };
                    });
                  }
                }
              }).catchError((_) {});
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorUtils.friendlyMessage(e);
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  String? _resolveContractorId(Map<String, dynamic> job) {
    String? readValue(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
        return null;
      }
      return text;
    }

    final topLevel = [
      job['contractorId'],
      job['contractor_id'],
      job['assignedContractorId'],
      job['assigned_contractor_id'],
      job['proId'],
      job['pro_id'],
      job['contractorUserId'],
      job['contractor_user_id'],
    ];
    for (final candidate in topLevel) {
      final value = readValue(candidate);
      if (value != null) return value;
    }

    final nestedMaps = [
      job['pro'],
      job['contractor'],
      job['assignedContractor'],
      job['professional'],
    ];
    for (final nested in nestedMaps) {
      if (nested is! Map) continue;
      final map = Map<String, dynamic>.from(nested);
      for (final key in const [
        'contractorId',
        'contractor_id',
        'id',
        'userId',
        'user_id',
      ]) {
        final value = readValue(map[key]);
        if (value != null) return value;
      }
    }

    return null;
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

  String _formatDateTimeString(String? isoString) {
    if (isoString == null) return 'TBD';
    try {
      final dt = DateTime.parse(isoString);
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
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
        'Dec'
      ];
      final wd = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      final day = dt.day;

      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final min =
          dt.minute == 0 ? '' : ':${dt.minute.toString().padLeft(2, '0')}';

      return '$wd, $month $day · $hour$min $ampm';
    } catch (_) {
      return isoString;
    }
  }

  void _reviewQuoteDialog(Map<String, dynamic> job) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuoteReviewScreen(job: job)),
    );
    if (changed == true) {
      _fetchJobs(showLoading: false);
    }
  }

  void _rescheduleDialog(Map<String, dynamic> job) async {
    final woId = _resolveWorkOrderId(job);
    var contractorId = _resolveContractorId(job);
    if (contractorId == null && woId > 0) {
      contractorId =
          await HomeownerService.instance.resolveContractorIdForWorkOrder(woId);
    }
    if (contractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Contractor info not available for reschedule'),
            backgroundColor: AppTheme.error),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppTheme.orange500)),
    );

    try {
      final now = DateTime.now();
      final fromDate = now.toIso8601String().split('T').first;
      final toDate =
          now.add(const Duration(days: 7)).toIso8601String().split('T').first;

      final avail = await HomeownerService.instance.getContractorAvailability(
        contractorId: contractorId,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (mounted) Navigator.pop(context); // Remove loader

      final slots = avail['slots'] as List? ?? [];

      if (!mounted) return;

      if (slots.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No slots available for this contractor in the next 7 days. Please check again later.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
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

      if (!mounted) return;
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
                                    _fetchJobs(showLoading: false);
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
        Navigator.pop(context); // Remove loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading availability: ${e.toString()}'),
              backgroundColor: AppTheme.error),
        );
      }
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
              try {
                await HomeownerService.instance.performWorkOrderAction(
                  workOrderId: job['workOrderId'] is int
                      ? job['workOrderId']
                      : int.parse(job['workOrderId'].toString()),
                  action: 'cancel',
                  extra: {'reason': 'homeowner_cancelled'},
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking cancelled successfully.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
                _fetchJobs(showLoading: false);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Cancel failed: ${e.toString()}'),
                      backgroundColor: AppTheme.error),
                );
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

  void _leaveReviewDialog(Map<String, dynamic> job) {
    final jobId = _resolveWorkOrderId(job);
    final localReview = _localReviews[jobId];
    final statusLower = (job['status']?.toString() ?? '').toLowerCase();
    final isCompleted = statusLower == 'completed' ||
        statusLower == 'complete' ||
        job['timeline']?['completedAt'] != null;
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
    final bool isEdit = job['reviewed'] == true ||
        localReview != null ||
        existingReviewText.toString().trim().isNotEmpty;

    double selectedRating = (existingRating as num).toDouble();
    final controller = TextEditingController(
      text: isPlaceholder ? '' : existingReviewText.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Review' : 'Leave a Review',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How did ${job['pro']?['businessName'] ?? 'Pro'} do?'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isFilled = index < selectedRating;
                  return IconButton(
                    icon: Icon(
                      isFilled ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setModalState(() {
                        selectedRating = index + 1.0;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your experience with the pro...',
                  hintStyle:
                      const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                  filled: true,
                  fillColor: AppTheme.pageAlt,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final reviewText = controller.text.trim();
                  if (jobId == 0) {
                    throw Exception(
                        'Unable to resolve the booking for review.');
                  }
                  if (!isCompleted) {
                    throw Exception('Only completed services can be reviewed.');
                  }
                  if (reviewText.length < 10) {
                    throw Exception('Please enter at least 10 characters.');
                  }
                  if (!isEdit) {
                    final eligibility =
                        await HomeownerService.instance.getReviewEligibility(
                      workOrderId: jobId,
                    );
                    if (eligibility['eligible'] == false) {
                      throw Exception(
                        eligibility['reason']?.toString() ?? 'not_eligible',
                      );
                    }
                  }
                  await HomeownerService.instance.submitReview(
                    workOrderId: jobId,
                    rating: selectedRating.roundToDouble(),
                    text: reviewText,
                    displayName: AuthService.instance.userName,
                  );
                  if (jobId != 0) {
                    _localReviews[jobId] = {
                      'rating': selectedRating,
                      'reviewText': reviewText,
                    };
                    job['reviewed'] = true;
                    job['rating'] = selectedRating;
                    job['reviewText'] = reviewText;
                  }
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Review updated successfully.'
                          : 'Review submitted successfully.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _fetchJobs(showLoading: false);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Failed to submit review: ${e.toString()}'),
                        backgroundColor: AppTheme.error),
                  );
                }
              },
              child: Text(isEdit ? 'Update Review' : 'Submit Review'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
      );
    }
    if (_errorMessage != null) {
      return OfflineState(
        onRetry: () => _fetchJobs(showLoading: true),
        message: _errorMessage,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetchJobs(showLoading: false),
      color: AppTheme.orange500,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderControls(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildJobsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderControls() {
    int activeCount = _activeJobs.length;
    int scheduledCount = _scheduledJobs.length;

    return SlidingSegmentControl(
      currentIndex: _activeSegment,
      activeColor: const Color(0xFF1B3C6E),
      items: [
        SegmentItem(label: 'Active', count: activeCount),
        SegmentItem(label: 'Scheduled', count: scheduledCount),
        const SegmentItem(label: 'History'),
      ],
      onSegmentChanged: (index) {
        setState(() {
          _activeSegment = index;
        });
      },
    );
  }

  Widget _buildJobsList() {
    List<dynamic> jobs = [];
    if (_activeSegment == 0) jobs = _activeJobs;
    if (_activeSegment == 1) jobs = _scheduledJobs;
    if (_activeSegment == 2) jobs = _historyJobs;

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_toggle_off,
                size: 48, color: AppTheme.gray),
            const SizedBox(height: 12),
            const Text('No bookings here',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Tap below to schedule a vetted pro.',
                style: TextStyle(color: AppTheme.gray, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onBookNowTap,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: Colors.white),
              child: const Text('Book a Service'),
            ),
          ],
        ),
      );
    }

    if (_activeSegment == 1) {
      final groups = <String, List<dynamic>>{};
      for (final job in jobs) {
        final dg = _getDayGroup(job['scheduledStart']);
        groups.putIfAbsent(dg, () => []).add(job);
      }

      return ListView(
        children: groups.entries.expand((entry) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: AppTheme.gray,
                    letterSpacing: 0.04),
              ),
            ),
            ...entry.value.map((job) => _buildJobCard(job)),
          ];
        }).toList(),
      );
    }

    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
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

    final proName = job['pro']?['businessName'] ?? 'Assigning Pro...';
    final service = job['serviceCategory'] ?? 'Service Request';
    final dateStr = _formatDateTimeString(job['scheduledStart']);
    final addressStr = job['address']?['street'] ?? 'Home';
    final tier = job['priority'] ?? 'Standard';

    String initials = 'P';
    if (proName.isNotEmpty) {
      final parts = proName.split(' ');
      initials = parts
          .map((p) => p.isNotEmpty ? p[0] : '')
          .take(2)
          .join()
          .toUpperCase();
      if (initials.isEmpty) initials = 'P';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkOrderDetailScreen(job: job),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAlert ? AppTheme.orange500 : const Color(0xFFE2E8F0),
            width: isAlert ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      service,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: AppTheme.navy700),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.navyTint,
                    child: Text(
                      initials,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    proName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.ink),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: tier == 'Urgent'
                          ? AppTheme.tealTint
                          : const Color(0xFFEDF1F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tier,
                      style: TextStyle(
                        color:
                            tier == 'Urgent' ? AppTheme.teal700 : AppTheme.gray,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.description, size: 13, color: AppTheme.gray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dateStr,
                      style:
                          const TextStyle(fontSize: 12, color: AppTheme.gray),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                        color: AppTheme.line, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on, size: 13, color: AppTheme.gray),
                  const SizedBox(width: 4),
                  Text(
                    addressStr,
                    style: const TextStyle(fontSize: 12, color: AppTheme.gray),
                  ),
                ],
              ),
              if (isLive) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildLiveNode(true),
                    _buildLiveLine(true),
                    _buildLiveNode(
                        statusLower == 'en_route' ||
                            statusLower == 'arrived' ||
                            statusLower == 'in_progress',
                        active: statusLower == 'en_route'),
                    _buildLiveLine(statusLower == 'arrived' ||
                        statusLower == 'in_progress'),
                    _buildLiveNode(
                        statusLower == 'arrived' ||
                            statusLower == 'in_progress',
                        active: statusLower == 'arrived'),
                    _buildLiveLine(statusLower == 'in_progress'),
                    _buildLiveNode(statusLower == 'in_progress',
                        active: statusLower == 'in_progress'),
                    _buildLiveLine(false),
                    _buildLiveNode(false),
                    _buildLiveLine(false),
                    _buildLiveNode(false),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _buildCardActions(job, isAlert, isLive, isCancelled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveNode(bool done, {bool active = false}) {
    return Container(
      width: active ? 11 : 8,
      height: active ? 11 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? Colors.white
            : done
                ? AppTheme.teal500
                : AppTheme.line,
        border: active ? Border.all(color: AppTheme.teal500, width: 3) : null,
      ),
    );
  }

  Widget _buildLiveLine(bool done) {
    return Expanded(
      child: Container(
        height: 2,
        color: done ? AppTheme.teal500 : AppTheme.line,
      ),
    );
  }

  Widget _buildCardActions(
      Map<String, dynamic> job, bool isAlert, bool isLive, bool isCancelled) {
    if (isAlert) {
      return HoverButton(
        text: 'Review & approve',
        height: 40.0,
        onPressed: () => _reviewQuoteDialog(job),
      );
    }

    if (isLive) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => WorkOrderDetailScreen(job: job)),
                ).then((_) {
                  _fetchJobs(showLoading: false);
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Track',
                  style: TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5)),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppTheme.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Live · updated just now',
                  style: TextStyle(color: AppTheme.gray, fontSize: 11)),
            ],
          ),
        ],
      );
    }

    if (_activeSegment == 1) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _rescheduleDialog(job),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Reschedule',
                  style: TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _cancelDialog(job),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5)),
            ),
          ),
        ],
      );
    }

    if (_activeSegment == 2) {
      final statusLower = (job['status']?.toString() ?? '').toLowerCase();
      final isCompleted = statusLower == 'completed' ||
          statusLower == 'complete' ||
          job['timeline']?['completedAt'] != null;
      final isCancelledJob = statusLower == 'cancelled' ||
          statusLower == 'canceled' ||
          statusLower == 'cancel' ||
          statusLower == 'declined' ||
          statusLower == 'pro_no_show' ||
          statusLower == 'customer_no_show';
      if (isCancelled || isCancelledJob) {
        return HoverButton(
          text: 'Book again',
          height: 40.0,
          onPressed: widget.onBookNowTap,
        );
      }

      final jobId = _resolveWorkOrderId(job);
      final reviewed = job['reviewed'] == true ||
          _localReviews.containsKey(jobId) ||
          (job['reviewText']?.toString().isNotEmpty == true) ||
          (job['review']?['text']?.toString().isNotEmpty == true) ||
          (job['review']?['reviewText']?.toString().isNotEmpty == true) ||
          (job['homeownerReview']?['text']?.toString().isNotEmpty == true) ||
          (job['homeownerReview']?['reviewText']?.toString().isNotEmpty ==
              true) ||
          (job['homeowner_review']?['text']?.toString().isNotEmpty == true) ||
          (job['homeowner_review']?['reviewText']?.toString().isNotEmpty ==
              true);

      if (!isCompleted) {
        return HoverButton(
          text: 'Book again',
          height: 40.0,
          onPressed: widget.onBookNowTap,
        );
      }

      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                showDialog(
                  context: this.context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: AppTheme.orange500),
                  ),
                );
                try {
                  final jobId = _resolveWorkOrderId(job);
                  final eligibility = await HomeownerService.instance
                      .getReviewEligibility(workOrderId: jobId);
                  if (mounted) Navigator.pop(this.context); // Dismiss loading
                  
                  if (eligibility['eligible'] == false) {
                    final reason = eligibility['reason']?.toString();
                    if (mounted) {
                      if (reason == 'already_reviewed') {
                        if (reviewed) {
                          _leaveReviewDialog(job);
                          return;
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('You have already submitted a review for this service.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      } else if (reason == 'not_completed') {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Only completed services can be reviewed.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('This service is not eligible for review: ${reason ?? "unknown"}.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                    return;
                  }
                  
                  if (mounted) {
                    _leaveReviewDialog(job);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(this.context); // Dismiss loading
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Error checking eligibility: ${e.toString()}'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.orange500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: Text(
                reviewed ? 'Edit review' : 'Leave review',
                style: const TextStyle(
                  color: AppTheme.orange500,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ReceiptScreen(job: job)),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Receipt',
                  style: TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onBookNowTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Book again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => WorkOrderDetailScreen(job: job)),
              ).then((_) {
                _fetchJobs(showLoading: false);
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.line),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(0, 40),
            ),
            child: const Text('View details',
                style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
        if (isLive) ...[
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Same as view details for now, until Map screen is built
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => WorkOrderDetailScreen(job: job)),
                ).then((_) {
                  _fetchJobs(showLoading: false);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Track',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }

  String _getDayGroup(String? isoString) {
    if (isoString == null) return 'UPCOMING';
    try {
      final dt = DateTime.parse(isoString);
      final weekdays = [
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY',
        'SUNDAY'
      ];
      final months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      final wd = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      return '$wd, $month $day';
    } catch (_) {
      return 'UPCOMING';
    }
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('quote') || status.contains('review'))
      return AppTheme.orange500;
    if (status == 'en_route') return AppTheme.teal500;
    if (status == 'in_progress') return AppTheme.navy700;
    if (status == 'arrived') return AppTheme.teal700;
    if (status == 'completed' || status == 'complete') return AppTheme.success;
    if (status == 'cancelled' || status == 'cancel') return AppTheme.error;
    if (status == 'scheduled' || status == 'booked') return AppTheme.teal500;
    return AppTheme.gray;
  }

  String _getStatusText(String status) {
    status = status.toLowerCase();
    if (status.contains('quote') || status.contains('review'))
      return 'Quote ready';
    if (status == 'en_route') return 'En route';
    if (status == 'in_progress') return 'In progress';
    if (status == 'arrived') return 'Arrived';
    if (status == 'completed' || status == 'complete') return 'Completed';
    if (status == 'cancelled' || status == 'cancel') return 'Cancelled';
    if (status == 'scheduled' || status == 'booked') return 'Booked';
    return status.toUpperCase();
  }
}

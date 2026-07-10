import 'package:flutter/material.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';
import 'nte_approval.dart';
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

  @override
  Widget build(BuildContext context) {
    final status = widget.job['status']?.toString() ?? 'Requested';
    final statusLower = status.toLowerCase();
    final service = widget.job['serviceCategory'] ?? 'Service Request';
    final addressStr = widget.job['address']?['street'] ?? 'Home';
    final dateStr = _formatDateTime(widget.job['scheduledStart']);
    final woId = widget.job['workOrderId']?.toString() ?? 'TW-0000';

    final proName = widget.job['pro']?['businessName'] ?? '';
    final hasPro = proName.isNotEmpty;
    final dynamic proRating = widget.job['pro']?['verifiedRating'] ??
        widget.job['verifiedRating'] ??
        widget.job['proRating'];
    final dynamic proReviewCount = widget.job['pro']?['verifiedCount'] ??
        widget.job['verifiedCount'] ??
        widget.job['reviewCount'];
    String initials = 'P';
    if (hasPro) {
      initials = proName
          .split(' ')
          .map((p) => p.isNotEmpty ? p[0] : '')
          .take(2)
          .join()
          .toUpperCase();
      if (initials.isEmpty) initials = 'P';
    }

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
            onPressed: () => Navigator.pop(context)),
        title: Column(
          children: [
            Text('Work Order #$woId',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.navy700)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(_getStatusText(status),
                  style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            )
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Image (Placeholder)
                  Container(
                    width: double.infinity,
                    height: 160,
                    color: AppTheme.navyTint,
                    child: Center(
                      child: Icon(Icons.home_repair_service,
                          size: 64, color: AppTheme.navy700.withOpacity(0.2)),
                    ),
                  ),

                  // Main Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppTheme.navy700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: AppTheme.gray),
                            const SizedBox(width: 8),
                            Text(addressStr,
                                style: const TextStyle(
                                    color: AppTheme.ink, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppTheme.gray),
                            const SizedBox(width: 8),
                            Text(dateStr,
                                style: const TextStyle(
                                    color: AppTheme.ink, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timeline Progression
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('STATUS',
                            style: TextStyle(
                                color: AppTheme.gray,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 16),
                        _buildTimeline(statusLower),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pro Profile Block
                  if (hasPro)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ASSIGNED PRO',
                              style: TextStyle(
                                  color: AppTheme.gray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.tealTint,
                                child: Text(initials,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.teal700,
                                        fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(proName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppTheme.navy700)),
                                    const SizedBox(height: 4),
                                    if (proRating != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.star,
                                              size: 14,
                                              color: AppTheme.orange500),
                                          const SizedBox(width: 4),
                                          Text(
                                            proReviewCount != null
                                                ? '$proRating ($proReviewCount reviews)'
                                                : '$proRating',
                                            style: const TextStyle(
                                                color: AppTheme.gray,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.line)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: _buildActionBar(statusLower, context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
    final steps = [
      'Requested',
      'Scheduled',
      'En Route',
      'In Progress',
      'Completed'
    ];

    int currentIndex = 0;
    if (currentStatus == 'scheduled') currentIndex = 1;
    if (currentStatus == 'en_route') currentIndex = 2;
    if (currentStatus == 'in_progress') currentIndex = 3;
    if (currentStatus == 'completed') currentIndex = 4;

    return Column(
      children: List.generate(steps.length, (index) {
        final isCompleted = index < currentIndex;
        final isActive = index == currentIndex;
        final isFuture = index > currentIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppTheme.teal500
                        : (isActive ? AppTheme.navy700 : AppTheme.line),
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 32,
                    color: isCompleted ? AppTheme.teal500 : AppTheme.line,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              steps[index],
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isFuture ? AppTheme.gray : AppTheme.navy700,
                fontSize: 14,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildActionBar(String currentStatus, BuildContext context) {
    List<Widget> buttons = [];

    Widget buildBtn(String text, Color bg, Color textCol, VoidCallback onTap) {
      return Expanded(
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(text,
              style: TextStyle(
                  color: textCol, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (currentStatus == 'completed' || currentStatus == 'complete') {
      buttons
          .add(buildBtn('Book Again', AppTheme.orange500, AppTheme.navy700, () {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking flow started for this Pro')));
      }));
      buttons.add(const SizedBox(width: 8));
      buttons.add(buildBtn('Receipt', AppTheme.pageAlt, AppTheme.navy700, () {
        _showReceiptModal(context);
      }));
      buttons.add(const SizedBox(width: 8));
      if (_review != null) {
        buttons.add(
            buildBtn('View/Edit Review', AppTheme.navy700, Colors.white, () {
          _showReviewModal(context, true);
        }));
      } else {
        buttons
            .add(buildBtn('Leave Review', AppTheme.navy700, Colors.white, () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: AppTheme.orange500),
            ),
          );
          try {
            final woId = int.tryParse(widget.job['id']?.toString() ??
                    widget.job['workOrderId']?.toString() ??
                    '0') ??
                0;
            final eligibility = await HomeownerService.instance
                .getReviewEligibility(workOrderId: woId);
            if (mounted) Navigator.pop(context); // Dismiss loading
            
            if (eligibility['eligible'] == false) {
              final reason = eligibility['reason']?.toString();
              if (mounted) {
                if (reason == 'already_reviewed') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You have already submitted a review for this service.'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                } else if (reason == 'not_completed') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only completed services can be reviewed.'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
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
              _showReviewModal(context, false);
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Dismiss loading
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error checking eligibility: ${e.toString()}'),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          }
        }));
      }
    } else if (currentStatus == 'quote_provided') {
      buttons.add(
          buildBtn('Approve NTE', AppTheme.orange500, AppTheme.navy700, () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => NteApprovalScreen(job: widget.job)));
      }));
    } else if (currentStatus == 'scheduled' ||
        currentStatus == 'en_route' ||
        currentStatus == 'in_progress') {
      buttons.add(buildBtn('Track', AppTheme.tealTint, AppTheme.teal700, () {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tracking pro...')));
      }));
      buttons.add(const SizedBox(width: 8));
      buttons
          .add(buildBtn('Reschedule', AppTheme.pageAlt, AppTheme.navy700, () {
        _requestReschedule();
      }));
      buttons.add(const SizedBox(width: 8));
      buttons.add(buildBtn('Cancel', AppTheme.pageAlt, AppTheme.error, () {
        _cancelJob();
      }));
    } else {
      // requested
      buttons
          .add(buildBtn('Cancel Request', AppTheme.pageAlt, AppTheme.error, () {
        _cancelJob();
      }));
    }

    return Row(children: buttons);
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
        readValue(widget.job['pro']?['userId']) ??
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

  void _showReviewModal(BuildContext context, bool isEdit) {
    int rating = (_review?['rating'] as num?)?.toInt() ?? 5;
    final controller = TextEditingController(
      text: _review?['reviewText']?.toString() ??
          _review?['comment']?.toString() ??
          '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? 'Edit Review' : 'Leave a Review',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy700)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36),
                      onPressed: () => setModalState(() => rating = index + 1),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(this.context);
                    final navigator = Navigator.of(context);
                    final reviewText = controller.text.trim();
                    final woId = int.tryParse(widget.job['id']?.toString() ??
                            widget.job['workOrderId']?.toString() ??
                            '0') ??
                        0;
                    if (woId == 0) {
                      messenger.showSnackBar(const SnackBar(
                        content:
                            Text('Unable to resolve the booking for review.'),
                        backgroundColor: AppTheme.error,
                      ));
                      return;
                    }
                    if (reviewText.length < 10) {
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Please enter at least 10 characters.'),
                        backgroundColor: AppTheme.error,
                      ));
                      return;
                    }
                    final statusLower =
                        (widget.job['status']?.toString() ?? '').toLowerCase();
                    final isCompleted = statusLower == 'completed' ||
                        statusLower == 'complete' ||
                        widget.job['timeline']?['completedAt'] != null;
                    if (!isCompleted) {
                      messenger.showSnackBar(const SnackBar(
                        content:
                            Text('Only completed services can be reviewed.'),
                        backgroundColor: AppTheme.error,
                      ));
                      return;
                    }
                    if (!isEdit) {
                      final eligibility = await HomeownerService.instance
                          .getReviewEligibility(workOrderId: woId);
                      if (eligibility['eligible'] == false) {
                        messenger.showSnackBar(SnackBar(
                          content: Text(
                            eligibility['reason']?.toString() ?? 'not_eligible',
                          ),
                          backgroundColor: AppTheme.error,
                        ));
                        return;
                      }
                    }
                    await HomeownerService.instance.submitReview(
                        workOrderId: woId,
                        rating: rating.toDouble(),
                        text: reviewText,
                        displayName: AuthService.instance.userName);
                    if (mounted) {
                      setState(() {
                        _review = {
                          'rating': rating.toDouble(),
                          'reviewText': reviewText,
                        };
                      });
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Review updated successfully.'
                                : 'Review submitted successfully.',
                          ),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy700,
                      minimumSize: const Size(double.infinity, 48)),
                  child: const Text('Submit',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

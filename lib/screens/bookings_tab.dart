import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class BookingsTab extends StatefulWidget {
  final VoidCallback onBookNowTap;

  const BookingsTab({
    super.key,
    required this.onBookNowTap,
  });

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int _activeSegment = 0; // 0: Active, 1: Scheduled, 2: History

  final List<Map<String, dynamic>> _activeJobs = [
    {
      'id': 'TW-4502',
      'service': 'Water heater repair',
      'pro': 'Bay Plumbing Co.',
      'company': 'Bay Plumbing Services',
      'avatarChar': 'BP',
      'tier': 'Standard',
      'tierColor': AppTheme.gray,
      'status': 'Quote ready',
      'statusColor': AppTheme.orange500,
      'date': 'Quoted today · you approve the cap',
      'property': 'Home',
      'isAlert': true,
    },
    {
      'id': 'TW-4471',
      'service': 'AC Tune-Up',
      'pro': 'Cool Air Pros',
      'company': 'Cool Air Professionals',
      'avatarChar': 'CA',
      'tier': 'Urgent',
      'tierColor': AppTheme.teal500,
      'status': 'En route',
      'statusColor': AppTheme.teal500,
      'date': 'Today · 2–4 PM',
      'property': 'Home',
      'isLive': true,
      'timelineStep': 1, // En route
    },
    {
      'id': 'TW-4460',
      'service': 'Panel safety inspection',
      'pro': 'Spark Electric',
      'company': 'Spark Electrical',
      'avatarChar': 'SE',
      'tier': 'Standard',
      'tierColor': AppTheme.gray,
      'status': 'In progress',
      'statusColor': AppTheme.navy700,
      'date': 'Started 1:10 PM',
      'property': 'Rental',
    }
  ];

  final List<Map<String, dynamic>> _scheduledJobs = [
    {
      'id': 'TW-4510',
      'service': 'Gutter cleaning',
      'pro': 'Peak Exteriors',
      'company': 'Peak Exterior Specialists',
      'avatarChar': 'PE',
      'tier': 'Standard',
      'tierColor': AppTheme.gray,
      'status': 'Booked',
      'statusColor': AppTheme.teal500,
      'date': 'Sat, Jun 28 · 9–11 AM',
      'dayGroup': 'SATURDAY, JUN 28',
      'property': 'Home',
    },
    {
      'id': 'TW-4512',
      'service': 'Full Service Lawn Mowing',
      'pro': 'Apex Yard Pros',
      'company': 'Apex Yard Professionals',
      'avatarChar': 'AY',
      'tier': 'Standard',
      'tierColor': AppTheme.gray,
      'status': 'Booked',
      'statusColor': AppTheme.teal500,
      'date': 'Jul 02 · 2:00 PM',
      'dayGroup': 'TUESDAY, JUL 02',
      'property': 'Rental',
    }
  ];

  final List<Map<String, dynamic>> _historyJobs = [
    {
      'id': 'TW-4458',
      'service': 'Lawn Pre-treatment & Fertilizer',
      'pro': 'Apex Yard Pros',
      'company': 'Apex Yard Professionals',
      'avatarChar': 'AY',
      'tier': 'Standard',
      'tierColor': AppTheme.gray,
      'status': 'Completed',
      'statusColor': AppTheme.success,
      'date': 'Mar 12, 2026',
      'property': 'Rental',
      'reviewed': false,
    },
    {
      'id': 'TW-4390',
      'service': 'Ceiling Fan Install & Wiring',
      'pro': 'VoltSpark Handyman',
      'company': 'VoltSpark Home Services',
      'avatarChar': 'VS',
      'tier': 'Standard',
      'tierColor': AppTheme.gray,
      'status': 'Completed',
      'statusColor': AppTheme.success,
      'date': 'Feb 05, 2026',
      'property': 'Home',
      'reviewed': true,
    },
    {
      'id': 'TW-4310',
      'service': 'AC Leak Troubleshooting',
      'pro': 'Miller Cool Air',
      'company': 'Miller Cool Air & Heating',
      'avatarChar': 'MC',
      'tier': 'Urgent',
      'tierColor': AppTheme.teal500,
      'status': 'Cancelled',
      'statusColor': AppTheme.error,
      'date': 'Jan 10, 2026',
      'property': 'Home',
      'reviewed': false,
      'isCancelled': true,
    }
  ];

  void _reviewQuoteDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Quote Cap (${job['id']})', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${job['service']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Provider: ${job['pro']}'),
            const SizedBox(height: 12),
            const Text('Quote Limit: \$180.00'),
            const SizedBox(height: 8),
            const Text(
              'By approving, you authorize the technician to perform diagnostic and minor repair work up to \$180.00 without further approval.',
              style: TextStyle(color: AppTheme.gray, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                job['status'] = 'Booked';
                job['statusColor'] = AppTheme.teal500;
                job['isAlert'] = false;
                _activeJobs.remove(job);
                _scheduledJobs.add({
                  ...job,
                  'dayGroup': 'SATURDAY, JUN 28',
                  'date': 'Sat, Jun 28 · 1:00–3:00 PM',
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Quote approved and booking scheduled!'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Review & Approve'),
          ),
        ],
      ),
    );
  }

  void _rescheduleDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Booking', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proposes a new in-window slot for ${job['service']}.'),
            const SizedBox(height: 12),
            const Text('Available Alternates:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildRescheduleSlot('Mon, Jun 30 · 9:00 AM – 11:00 AM'),
            _buildRescheduleSlot('Mon, Jun 30 · 2:00 PM – 4:00 PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Current Time'),
          ),
        ],
      ),
    );
  }

  Widget _buildRescheduleSlot(String slot) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rescheduled to: $slot'),
            backgroundColor: AppTheme.success,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.pageAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(slot, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navy700)),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.teal500),
          ],
        ),
      ),
    );
  }

  void _cancelDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
        content: const Text(
          'Are you sure you want to cancel this booking? Cancel is free before work begins, with no homeowner fees.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _scheduledJobs.remove(job);
                _historyJobs.insert(0, {
                  ...job,
                  'status': 'Cancelled',
                  'statusColor': AppTheme.error,
                  'isCancelled': true,
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking cancelled successfully.'),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );
  }

  void _leaveReviewDialog(Map<String, dynamic> job) {
    double selectedRating = 5.0;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Leave a Review', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How did ${job['pro']} do?'),
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
                    hintStyle: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                    filled: true,
                    fillColor: AppTheme.pageAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                onPressed: () {
                  setState(() {
                    job['reviewed'] = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Review submitted! Thank you.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
                child: const Text('Submit Review'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }

  Widget _buildHeaderControls() {
    int activeCount = _activeJobs.length;
    int scheduledCount = _scheduledJobs.length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.pageAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentItem(0, 'Active', count: activeCount),
          _buildSegmentItem(1, 'Scheduled', count: scheduledCount),
          _buildSegmentItem(2, 'History'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label, {int? count}) {
    final isSelected = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.navy700 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.navy700.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.gray,
                  fontSize: 12.5,
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.24) : AppTheme.line,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.gray,
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
    List<Map<String, dynamic>> jobs = [];
    if (_activeSegment == 0) jobs = _activeJobs;
    if (_activeSegment == 1) jobs = _scheduledJobs;
    if (_activeSegment == 2) jobs = _historyJobs;

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_toggle_off, size: 48, color: AppTheme.gray),
            const SizedBox(height: 12),
            const Text('No bookings here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Tap below to schedule a vetted pro.', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onBookNowTap,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange500, foregroundColor: Colors.white),
              child: const Text('Book a Service'),
            ),
          ],
        ),
      );
    }

    if (_activeSegment == 1) {
      // Group Scheduled by day group
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final job in jobs) {
        final dg = job['dayGroup'] as String;
        groups.putIfAbsent(dg, () => []).add(job);
      }

      return ListView(
        children: groups.entries.expand((entry) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.gray, letterSpacing: 0.04),
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
    final isAlert = job['isAlert'] == true;
    final isLive = job['isLive'] == true;
    final isCancelled = job['isCancelled'] == true;

    return Container(
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
                    job['service']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.navy700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (job['statusColor'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job['status']!,
                    style: TextStyle(
                      color: job['statusColor'] as Color,
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
                    job['avatarChar']!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.navy700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  job['pro']!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: job['tier'] == 'Urgent' ? AppTheme.tealTint : const Color(0xFFEDF1F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job['tier']!,
                    style: TextStyle(
                      color: job['tier'] == 'Urgent' ? AppTheme.teal700 : AppTheme.gray,
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
                    job['date']!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.gray),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(color: AppTheme.line, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.location_on, size: 13, color: AppTheme.gray),
                const SizedBox(width: 4),
                Text(
                  job['property']!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray),
                ),
              ],
            ),
            if (isLive) ...[
              const SizedBox(height: 12),
              // Timeline Progress Row
              Row(
                children: [
                  _buildLiveNode(true), // Booked
                  _buildLiveLine(true),
                  _buildLiveNode(true, active: true), // En route
                  _buildLiveLine(false),
                  _buildLiveNode(false), // Arrived
                  _buildLiveLine(false),
                  _buildLiveNode(false), // In progress
                  _buildLiveLine(false),
                  _buildLiveNode(false), // Wrapping up
                  _buildLiveLine(false),
                  _buildLiveNode(false), // Completed
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Actions
            _buildCardActions(job, isAlert, isLive, isCancelled),
          ],
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

  Widget _buildCardActions(Map<String, dynamic> job, bool isAlert, bool isLive, bool isCancelled) {
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening live map tracking screen...')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Track', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Live · updated just now', style: TextStyle(color: AppTheme.gray, fontSize: 11)),
            ],
          ),
        ],
      );
    }

    if (_activeSegment == 1) {
      // Scheduled: cancel & reschedule actions
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _rescheduleDialog(job),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Reschedule', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _cancelDialog(job),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ),
        ],
      );
    }

    if (_activeSegment == 2) {
      // History: reviews, book again, view receipt
      if (isCancelled) {
        return HoverButton(
          text: 'Book again',
          height: 40.0,
          onPressed: widget.onBookNowTap,
        );
      }

      final reviewed = job['reviewed'] == true;
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: reviewed ? null : () => _leaveReviewDialog(job),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: reviewed ? AppTheme.line : AppTheme.orange500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: Text(
                reviewed ? 'Reviewed' : 'Leave review',
                style: TextStyle(
                  color: reviewed ? AppTheme.gray : AppTheme.orange500,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading receipt PDF...')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Receipt', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onBookNowTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 40),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Book again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return HoverButton(
      text: 'View details',
      height: 40.0,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening work order detail view...')),
        );
      },
    );
  }
}

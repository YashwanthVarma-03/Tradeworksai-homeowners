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
      'id': 'WO-9421',
      'service': 'Emergency AC System Diagnostic',
      'pro': 'Dave Miller',
      'company': 'Miller Cool Air & Heating',
      'date': 'Today, 9:00 PM',
      'price': '\$89 Capped',
      'status': 'EN ROUTE',
      'statusColor': AppTheme.teal500,
    }
  ];

  final List<Map<String, dynamic>> _scheduledJobs = [
    {
      'id': 'WO-9430',
      'service': 'Lawn Mowing & Trimming',
      'pro': 'Apex Yard Pros',
      'company': 'Apex Yard Professionals',
      'date': 'Jul 02, 2:00 PM',
      'price': '\$55 Fixed',
      'status': 'BOOKED',
      'statusColor': AppTheme.teal700,
    }
  ];

  final List<Map<String, dynamic>> _historyJobs = [
    {
      'id': 'WO-8910',
      'service': 'Lawn Pre-treatment & Fertilizer',
      'pro': 'Apex Yard Pros',
      'company': 'Apex Yard Professionals',
      'date': 'Mar 12, 2026',
      'price': '\$75 Completed',
      'status': 'COMPLETED',
      'statusColor': AppTheme.success,
    },
    {
      'id': 'WO-8724',
      'service': 'Ceiling Fan Install & Wiring',
      'pro': 'VoltSpark Handyman',
      'company': 'VoltSpark Home Services',
      'date': 'Feb 05, 2026',
      'price': '\$120 Completed',
      'status': 'COMPLETED',
      'statusColor': AppTheme.success,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildSegmentedControl(),
          const SizedBox(height: 20),
          Expanded(
            child: _buildJobsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.pageAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentItem(0, 'Active'),
          _buildSegmentItem(1, 'Scheduled'),
          _buildSegmentItem(2, 'History'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final isSelected = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppTheme.navy700 : AppTheme.gray,
              fontSize: 13,
            ),
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

    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                job['id']!,
                style: const TextStyle(color: AppTheme.gray, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (job['statusColor'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  job['status']!,
                  style: TextStyle(
                    color: job['statusColor'] as Color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job['service']!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${job['pro']} • ${job['company']}',
            style: const TextStyle(color: AppTheme.gray, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                job['date']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navy700),
              ),
              Text(
                job['price']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.teal700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

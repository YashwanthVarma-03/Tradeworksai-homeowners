import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onBookTap;
  final Function(Map<String, String>) onJobTap;

  const HomeTab({
    super.key,
    required this.onBookTap,
    required this.onJobTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedEntrance(
            delay: Duration.zero,
            child: _buildHeader(context),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 100),
            child: _buildActiveJobCard(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 200),
            child: _buildRewardsProgressCard(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 300),
            child: _buildMaintenanceChecklist(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 400),
            child: _buildUpcomingList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: AppTheme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
            Text(
              'Yashwanth Varma',
              style: AppTheme.textTheme.headlineLarge?.copyWith(fontSize: 22, color: AppTheme.navy700),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.notifications_active, color: AppTheme.navy700),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI receptionist notifications are up to date.')),
            );
          },
        ),
      ],
    );
  }

  // --- ACTIVE JOB CARD ---
  Widget _buildActiveJobCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tealTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.teal500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'EN ROUTE',
                      style: TextStyle(
                        color: AppTheme.teal700,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Job ID: #WO-9421',
                style: TextStyle(color: AppTheme.gray, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Emergency AC System Diagnostic',
            style: AppTheme.textTheme.titleLarge?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Miller Cool Air & Heating • Dave Miller',
            style: TextStyle(color: AppTheme.gray, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Status Timeline
          Row(
            children: [
              _buildTimelineStep('Booked', true),
              _buildTimelineDivider(true),
              _buildTimelineStep('En Route', true, active: true),
              _buildTimelineDivider(false),
              _buildTimelineStep('Arrived', false),
              _buildTimelineDivider(false),
              _buildTimelineStep('Done', false),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.airport_shuttle, color: AppTheme.teal500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dave is on his way. ETA 9:42 PM (12 mins).',
                  style: AppTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, bool done, {bool active = false}) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppTheme.teal500
                : done
                    ? AppTheme.navy700
                    : AppTheme.line,
            border: active ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.teal500.withOpacity(0.4),
                      blurRadius: 4,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: active || done ? FontWeight.bold : FontWeight.normal,
            color: active
                ? AppTheme.teal700
                : done
                    ? AppTheme.navy700
                    : AppTheme.gray,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDivider(bool done) {
    return Expanded(
      child: Container(
        height: 2,
        color: done ? AppTheme.navy700 : AppTheme.line,
        margin: const EdgeInsets.only(bottom: 12),
      ),
    );
  }

  // --- REWARDS SUMMARY ---
  Widget _buildRewardsProgressCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Homeowner Rewards Ledger',
                style: AppTheme.textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
              const Icon(Icons.stars, color: AppTheme.orange500),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Saved Credits', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
                  Text(
                    '\$214.60',
                    style: AppTheme.textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                      color: AppTheme.teal700,
                    ),
                  ),
                ],
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Annual Platform Spend', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
                  Text(
                    '\$5,820.00',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navy700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Current rewards band: 5% Cash-Back (Marginal Bands Progress)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Marginal Band Progress Bars
          _buildBandProgress('Band 1: 3% back (on first \$5k spend)', 1.0),
          _buildBandProgress('Band 2: 5% back (spend \$5k–\$15k)', 0.08),
          _buildBandProgress('Band 3: 7% back (spend \$15k–\$25k)', 0.0),
        ],
      ),
    );
  }

  Widget _buildBandProgress(String label, double percent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.gray)),
              Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: AppTheme.line.withOpacity(0.3),
              color: percent == 1.0 ? AppTheme.navy700 : AppTheme.orange500,
            ),
          ),
        ],
      ),
    );
  }

  // --- MAINTENANCE CHECKLIST ---
  Widget _buildMaintenanceChecklist() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seasonal Maintenance Checklist',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Keep your home healthy and maintain your rewards eligibility.',
            style: TextStyle(color: AppTheme.gray, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildMaintenanceItem('Summer AC Check-Up', 'Scheduled with Miller Cooling for Jun 24', true, Colors.orange),
          _buildMaintenanceItem('Spring Lawn Pre-treatment', 'Completed on Mar 12', false, Colors.green),
          _buildMaintenanceItem('Fall Gutters Cleaning', 'Overdue - gutters never wait', false, Colors.red, actionLabel: 'Book Now'),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(String title, String desc, bool active, Color labelColor, {String? actionLabel}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: active ? labelColor : AppTheme.line, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: AppTheme.gray, fontSize: 11)),
              ],
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onBookTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.orange500),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(color: AppTheme.orange500, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- UPCOMING BOOKINGS ---
  Widget _buildUpcomingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Appointments',
          style: AppTheme.textTheme.headlineMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildUpcomingItem('Jun 24, 10:00 AM', 'AC System Diagnostic', 'Dave Miller', 'Capped \$89'),
        _buildUpcomingItem('Jul 02, 2:00 PM', 'Full Service Lawn Mowing', 'Apex Yard Pros', '\$55 Fixed'),
      ],
    );
  }

  Widget _buildUpcomingItem(String date, String service, String pro, String price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.line, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.pageAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.calendar_today, color: AppTheme.navy700),
        ),
        title: Text(service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('$pro • $date', style: const TextStyle(color: AppTheme.gray, fontSize: 11)),
        trailing: Text(
          price,
          style: const TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

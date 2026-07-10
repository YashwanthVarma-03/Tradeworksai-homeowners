import 'package:flutter/material.dart';
import '../theme.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String? woNumber;
  final String? scheduledStart;

  const BookingSuccessScreen({
    super.key,
    this.woNumber,
    this.scheduledStart,
  });

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty)
      return 'Your booking details are now available in Scheduled.';
    try {
      final dt = DateTime.parse(isoString).toLocal();
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
      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$minute $ampm';
    } catch (_) {
      return 'Your booking details are now available in Scheduled.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _formatDateTime(scheduledStart);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppTheme.tealTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: AppTheme.success, size: 56),
              ),
              const SizedBox(height: 24),
              const Text(
                'Booking Confirmed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                woNumber == null || woNumber!.isEmpty
                    ? summary
                    : 'Work order $woNumber is scheduled for $summary.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'View Booking',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

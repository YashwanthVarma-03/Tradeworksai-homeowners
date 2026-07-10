import 'package:flutter/material.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const ReceiptScreen({Key? key, required this.job}) : super(key: key);

  String _formatDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return 'TBD';
    try {
      final dt = DateTime.parse(dateTimeStr.toString());
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (e) {
      return dateTimeStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = job['status']?.toString().toLowerCase() ?? '';
    final isPaid = status == 'completed' || status == 'paid';
    
    final woId = job['workOrderId']?.toString() ?? 'TW-0000';
    final service = job['serviceCategory'] ?? 'Service';
    final proName = job['pro']?['businessName'] ?? 'Pro Service';
    final dateStr = _formatDateTime(job['scheduledEnd'] ?? job['scheduledStart']);
    
    // Mock financial data
    final quoteAmount = job['quoteAmount'] ?? 350.0;
    final baseFee = 100.0;
    final labor = quoteAmount - 100.0;
    final materials = 45.00;
    final credits = -20.00;
    final total = baseFee + labor + materials + credits;

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700), onPressed: () => Navigator.pop(context)),
        title: const Text('Receipt', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: AppTheme.navy700),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading PDF...')));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: isPaid ? AppTheme.success.withOpacity(0.1) : AppTheme.orange500.withOpacity(0.1),
                child: Column(
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.pending_actions,
                      color: isPaid ? AppTheme.success : AppTheme.orange500,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPaid ? 'Payment Successful' : 'Awaiting Payment',
                      style: TextStyle(
                        color: isPaid ? AppTheme.success : AppTheme.orange500,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: const TextStyle(color: AppTheme.gray, fontSize: 13)),
                  ],
                ),
              ),
              
              // Receipt Details
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.line),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Work Order #$woId', style: const TextStyle(color: AppTheme.gray, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Total', style: const TextStyle(color: AppTheme.gray, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(service, style: const TextStyle(color: AppTheme.navy700, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.navy700, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Provided by $proName', style: const TextStyle(color: AppTheme.gray, fontSize: 13)),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Divider(height: 1, color: AppTheme.line),
                    ),
                    
                    // Line Items
                    const Text('CHARGES', style: TextStyle(color: AppTheme.gray, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 16),
                    _buildLineItem('Base Fee', baseFee),
                    const SizedBox(height: 12),
                    _buildLineItem('Labor', labor),
                    const SizedBox(height: 12),
                    _buildLineItem('Materials & Parts', materials),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TradeWorks Platform Fee', style: TextStyle(color: AppTheme.ink, fontSize: 14)),
                        const Text('Free', style: TextStyle(color: AppTheme.success, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (credits < 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.stars, color: AppTheme.teal500, size: 16),
                              SizedBox(width: 8),
                              Text('Service Credits Applied', style: TextStyle(color: AppTheme.teal700, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('-\$${(-credits).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.teal700, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Divider(height: 1, color: AppTheme.line),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Charged', style: TextStyle(color: AppTheme.navy700, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.navy700, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Method', style: TextStyle(color: AppTheme.gray, fontSize: 13)),
                        const Text('Visa •••• 4921', style: TextStyle(color: AppTheme.gray, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineItem(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.ink, fontSize: 14)),
        Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.navy700, fontSize: 14)),
      ],
    );
  }
}

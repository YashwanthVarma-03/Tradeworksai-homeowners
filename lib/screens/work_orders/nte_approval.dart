import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/homeowner_service.dart';

class NteApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const NteApprovalScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<NteApprovalScreen> createState() => _NteApprovalScreenState();
}

class _NteApprovalScreenState extends State<NteApprovalScreen> {
  bool _isProcessing = false;

  void _approveNte() async {
    setState(() => _isProcessing = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: widget.job['workOrderId'] is int ? widget.job['workOrderId'] : int.parse(widget.job['workOrderId'].toString()),
        action: 'approve_nte',
        extra: {'approved': true},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NTE Approved'), backgroundColor: AppTheme.success));
        Navigator.pop(context, true); // Return true to indicate change
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _declineNte() async {
    setState(() => _isProcessing = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: widget.job['workOrderId'] is int ? widget.job['workOrderId'] : int.parse(widget.job['workOrderId'].toString()),
        action: 'decline_nte',
        extra: {'approved': false, 'reason': 'Homeowner declined NTE'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NTE Declined and Work Order Cancelled'), backgroundColor: AppTheme.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For demo purposes, we parse/simulate the quote from the job
    final woId = widget.job['workOrderId']?.toString() ?? 'TW-0000';
    final quote = widget.job['quote'] ?? {
      'baseFee': 100.0,
      'estimatedLabor': 150.0,
      'estimatedMaterials': 50.0,
      'totalNTE': 300.0,
    };

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700), onPressed: () => Navigator.pop(context)),
        title: const Text('Review Estimate', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.tealTint,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.teal700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(color: AppTheme.teal700, fontSize: 13, height: 1.4),
                                children: [
                                  TextSpan(text: 'What is an NTE limit? ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: 'NTE stands for "Not-to-Exceed". This is the maximum amount you will be charged for this service without requiring further approval. The pro cannot charge more than this amount.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Work Order #$woId', style: const TextStyle(color: AppTheme.gray, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildLineItem('Base Fee', quote['baseFee']),
                          const SizedBox(height: 12),
                          _buildLineItem('Estimated Labor', quote['estimatedLabor']),
                          const SizedBox(height: 12),
                          _buildLineItem('Estimated Materials', quote['estimatedMaterials']),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(height: 1, color: AppTheme.line),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total NTE Limit', style: TextStyle(color: AppTheme.navy700, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('\$${(quote['totalNTE'] as num).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.orange500, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _approveNte,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isProcessing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navy700))
                          : const Text('Approve NTE', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isProcessing ? null : _declineNte,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.gray,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Decline & Cancel Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(String title, dynamic amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.ink, fontSize: 15)),
        Text('\$${(amount as num).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.navy700, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

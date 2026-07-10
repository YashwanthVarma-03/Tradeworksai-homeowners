import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/homeowner_service.dart';

class QuoteReviewScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const QuoteReviewScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<QuoteReviewScreen> createState() => _QuoteReviewScreenState();
}

class _QuoteReviewScreenState extends State<QuoteReviewScreen> {
  bool _isProcessing = false;
  int _expandedIndex = -1; // To track which quote detail is expanded

  // Mock list of quotes since the API right now only supports a single quote inline
  late List<Map<String, dynamic>> _quotes;

  @override
  void initState() {
    super.initState();
    // Use the actual job data to mock a list of quotes
    final proName = widget.job['pro']?['businessName'] ?? 'Pro Service';
    final quoteAmount = widget.job['quoteAmount'] ?? 350.0;
    
    _quotes = [
      {
        'id': 'q_1',
        'proName': proName,
        'rating': 4.9,
        'reviews': 128,
        'cost': quoteAmount,
        'eta': 'Tomorrow, 9:00 AM',
        'baseFee': 100.0,
        'labor': quoteAmount - 100.0,
        'materials': 0.0,
        'scope': widget.job['quoteScope'] ?? 'Diagnostics & minor repairs',
      },
      {
        'id': 'q_2',
        'proName': 'Elite Home Services',
        'rating': 4.7,
        'reviews': 85,
        'cost': quoteAmount + 45.0,
        'eta': 'Tomorrow, 2:00 PM',
        'baseFee': 80.0,
        'labor': (quoteAmount + 45.0) - 120.0,
        'materials': 40.0,
        'scope': 'Full diagnostic and required parts included',
      }
    ];
  }

  void _acceptQuote(Map<String, dynamic> quote) async {
    setState(() => _isProcessing = true);
    try {
      final startsAt = widget.job['proposedStart'] ?? widget.job['scheduledStart'] ?? DateTime.now().add(const Duration(days: 1)).toIso8601String();
      final endsAt = widget.job['proposedEnd'] ?? widget.job['scheduledEnd'] ?? DateTime.now().add(const Duration(days: 1, hours: 2)).toIso8601String();
      final contractorId = widget.job['contractorId']?.toString() ?? widget.job['pro']?['contractorId']?.toString();

      await HomeownerService.instance.respondToQuote(
        workOrderId: widget.job['workOrderId'] is int ? widget.job['workOrderId'] : int.parse(widget.job['workOrderId'].toString()),
        accept: true,
        reason: 'homeowner_accepted',
        contractorId: contractorId,
        startsAt: startsAt,
        endsAt: endsAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote accepted successfully!'), backgroundColor: AppTheme.success));
        Navigator.pop(context, true); // Returns true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _declineAll() async {
    setState(() => _isProcessing = true);
    try {
      await HomeownerService.instance.respondToQuote(
        workOrderId: widget.job['workOrderId'] is int ? widget.job['workOrderId'] : int.parse(widget.job['workOrderId'].toString()),
        accept: false,
        reason: 'homeowner_declined_all',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotes declined.'), backgroundColor: AppTheme.error));
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
    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700), onPressed: () => Navigator.pop(context)),
        title: const Text('Review Quotes', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.navyTint,
              child: const Text(
                'Select a pro for your service. Payment is processed securely after the job is complete.',
                style: TextStyle(color: AppTheme.navy700, fontSize: 13, height: 1.4),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _quotes.length,
                itemBuilder: (context, index) {
                  return _buildQuoteCard(_quotes[index], index);
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: TextButton(
                onPressed: _isProcessing ? null : _declineAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Decline all quotes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote, int index) {
    final isExpanded = _expandedIndex == index;
    final initials = quote['proName'].toString().substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? AppTheme.teal500 : AppTheme.line, width: isExpanded ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.tealTint,
                    child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.teal700, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quote['proName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navy700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: AppTheme.orange500),
                            const SizedBox(width: 4),
                            Text('${quote['rating']} (${quote['reviews']})', style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${(quote['cost'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.navy700)),
                      const SizedBox(height: 4),
                      Text(quote['eta'], style: const TextStyle(color: AppTheme.teal700, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QUOTE DETAILS', style: TextStyle(color: AppTheme.gray, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _buildLineItem('Base Fee', quote['baseFee']),
                  const SizedBox(height: 8),
                  _buildLineItem('Estimated Labor', quote['labor']),
                  const SizedBox(height: 8),
                  _buildLineItem('Materials & Parts', quote['materials']),
                  const SizedBox(height: 12),
                  Text('Scope: ${quote['scope']}', style: const TextStyle(color: AppTheme.gray, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _acceptQuote(quote),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isProcessing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navy700))
                          : const Text('Accept Quote', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineItem(String title, dynamic amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.ink, fontSize: 14)),
        Text('\$${(amount as num).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.navy700, fontSize: 14)),
      ],
    );
  }
}

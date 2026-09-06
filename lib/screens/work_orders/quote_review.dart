import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';

class QuoteReviewScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const QuoteReviewScreen({super.key, required this.job});

  @override
  State<QuoteReviewScreen> createState() => _QuoteReviewScreenState();
}

class _QuoteReviewScreenState extends State<QuoteReviewScreen> {
  bool _isProcessing = false;
  late final Map<String, dynamic> _quote;

  @override
  void initState() {
    super.initState();
    final proName = _readString(widget.job['pro']?['businessName']) ??
        _readString(widget.job['proName']) ??
        'Bay Plumbing Co.';
    final quoteAmount = _amountFrom(
      widget.job['quoteAmount'] ??
          widget.job['quote']?['total'] ??
          widget.job['quote']?['totalNTE'],
      420,
    );
    _quote = {
      'id': widget.job['quote']?['id'] ?? 'q_1',
      'proName': proName,
      'rating': widget.job['pro']?['verifiedRating'] ??
          widget.job['verifiedRating'] ??
          4.7,
      'cost': quoteAmount,
      'diagnosis': widget.job['quoteScope'] ??
          widget.job['quote']?['diagnosis'] ??
          'Failed anode rod and sediment buildup. Recommended: replace the anode rod and flush the tank.',
      'items': widget.job['quote']?['items'],
      'baseFee': _amountFrom(widget.job['quote']?['baseFee'], 89),
      'labor': _amountFrom(widget.job['quote']?['labor'], 180),
      'materials': _amountFrom(widget.job['quote']?['materials'], 95),
    };
  }

  Future<void> _acceptQuote() async {
    setState(() => _isProcessing = true);
    try {
      final startsAt = widget.job['proposedStart'] ??
          widget.job['scheduledStart'] ??
          DateTime.now().add(const Duration(days: 1)).toIso8601String();
      final endsAt = widget.job['proposedEnd'] ??
          widget.job['scheduledEnd'] ??
          DateTime.now().add(const Duration(days: 1, hours: 2)).toIso8601String();
      final contractorId = widget.job['contractorId']?.toString() ??
          widget.job['pro']?['contractorId']?.toString();

      await HomeownerService.instance.respondToQuote(
        workOrderId: _workOrderId(),
        accept: true,
        reason: 'homeowner_accepted',
        contractorId: contractorId,
        startsAt: startsAt,
        endsAt: endsAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote accepted successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _declineAll() async {
    setState(() => _isProcessing = true);
    try {
      await HomeownerService.instance.respondToQuote(
        workOrderId: _workOrderId(),
        accept: false,
        reason: 'homeowner_declined_all',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotes declined.'),
            backgroundColor: AppTheme.error,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _quote['cost'] as double;
    final labor = _quote['labor'] as double;
    final materials = _quote['materials'] as double;
    final anode = (total - labor - materials).clamp(0, total).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _screenHeader('Review quote'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoBanner(),
                  const SizedBox(height: 22),
                  _sectionLabel('WHAT THE PRO FOUND'),
                  const SizedBox(height: 10),
                  _diagnosisCard(),
                  const SizedBox(height: 16),
                  _capCard(total),
                  const SizedBox(height: 22),
                  _sectionLabel('ESTIMATE BREAKDOWN'),
                  const SizedBox(height: 14),
                  _lineItem('Anode rod replacement', anode),
                  const SizedBox(height: 14),
                  _lineItem('Tank flush & descale', materials),
                  const SizedBox(height: 14),
                  _lineItem('Labor', labor),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: AppTheme.line),
                  ),
                  _lineItem('Total Cap Estimate', total,
                      isTotal: true, valueColor: AppTheme.orange500),
                  const SizedBox(height: 22),
                  _primaryButton('Approve cap', _acceptQuote),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _outlineButton(
                          'Message pro',
                          color: AppTheme.navy700,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Messaging will open here.'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _outlineButton(
                          'Decline',
                          color: const Color(0xFFC83B3B),
                          onPressed: _declineAll,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _workOrderId() {
    final raw = widget.job['workOrderId'] ?? widget.job['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  double _amountFrom(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _money(num amount) =>
      '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'P';
    return parts.map((part) => part[0]).take(2).join().toUpperCase();
  }

  Widget _screenHeader(String title) {
    return Container(
      width: double.infinity,
      height: 50 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.navy700, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFE0F2FC),
        border: Border(left: BorderSide(color: AppTheme.teal500, width: 5)),
      ),
      child: const Text(
        'You approve a not-to-exceed cap before work begins. The final price may be lower, never higher.',
        style: TextStyle(
          color: AppTheme.navy700,
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.gray,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _diagnosisCard() {
    final proName = _quote['proName'].toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppTheme.navy700,
                child: Text(
                  _initials(proName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_quote['rating']} ★',
                      style: const TextStyle(
                        color: AppTheme.orange500,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionLabel('DIAGNOSIS'),
          const SizedBox(height: 8),
          Text(
            _quote['diagnosis'].toString(),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _capCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.orange500),
      ),
      child: Column(
        children: [
          const Text(
            'NOT TO EXCEED',
            style: TextStyle(
              color: AppTheme.orange500,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _money(total),
            style: const TextStyle(
              color: AppTheme.orange500,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${_money(_quote['baseFee'] as double)} diagnostic, waived when you approve',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItem(String title, num amount,
      {bool isTotal = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: isTotal ? 14.5 : 13,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _money(amount),
          style: TextStyle(
            color: valueColor ?? AppTheme.ink,
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }

  Widget _outlineButton(
    String label, {
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: _isProcessing ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
      child: Text(label),
    );
  }
}

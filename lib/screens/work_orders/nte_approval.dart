import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';

class NteApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const NteApprovalScreen({super.key, required this.job});

  @override
  State<NteApprovalScreen> createState() => _NteApprovalScreenState();
}

class _NteApprovalScreenState extends State<NteApprovalScreen> {
  bool _isProcessing = false;

  Future<void> _approveNte() async {
    setState(() => _isProcessing = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: _workOrderId(),
        action: 'approve_nte',
        extra: {'approved': true},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NTE Approved'),
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

  @override
  Widget build(BuildContext context) {
    final service = _serviceName();
    final address = _addressText();
    final firstPro = _proName();
    final firstTotal = _totalEstimate();

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      body: Column(
        children: [
          _screenHeader('Your estimates'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _requestCard(service, address),
                const SizedBox(height: 14),
                _estimateCard(
                  initials: _initials(firstPro),
                  proName: firstPro,
                  rating: _ratingText(),
                  reviewCount: _reviewCountText('212'),
                  amount: firstTotal,
                  bullets: const [
                    '3-ton 16 SEER system',
                    'Install + old-unit haul-away',
                    '10-yr warranty',
                  ],
                  startText: 'Can start next week',
                  startColor: const Color(0xFF2F9445),
                  accent: AppTheme.navy700,
                  onChoose: _approveNte,
                ),
                const SizedBox(height: 14),
                _estimateCard(
                  initials: 'BA',
                  proName: 'Bay Area HVAC',
                  rating: '4.8',
                  reviewCount: '156',
                  amount: (firstTotal * 0.94).clamp(0, firstTotal + 1500),
                  bullets: const [
                    '3-ton 15.2 SEER system',
                    'Install + permit',
                    '10-yr warranty',
                  ],
                  startText: 'Can start in 2 weeks',
                  startColor: AppTheme.gray,
                  accent: AppTheme.teal500,
                  onChoose: _approveNte,
                ),
              ],
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

  double _readAmount(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  double _totalEstimate() {
    final quote = widget.job['quote'];
    return _readAmount(
      widget.job['quoteAmount'] ??
          widget.job['totalNTE'] ??
          widget.job['totalNte'] ??
          widget.job['amount'] ??
          (quote is Map ? quote['totalNTE'] ?? quote['total'] : null),
      8450,
    );
  }

  String _serviceName() {
    return _readString(widget.job['serviceName']) ??
        _readString(widget.job['service']) ??
        _readString(widget.job['title']) ??
        _readString(widget.job['serviceCategory']) ??
        'New AC system';
  }

  String _addressText() {
    final address = widget.job['address'];
    if (address is Map) {
      final street = _readString(address['street']) ??
          _readString(address['line1']) ??
          _readString(address['addressLine1']);
      if (street != null) return street;
    }
    return _readString(address) ?? '124 Skyview Ln';
  }

  String _proName() {
    final pro = widget.job['pro'];
    if (pro is Map) {
      return _readString(pro['businessName']) ??
          _readString(pro['business_name']) ??
          _readString(pro['name']) ??
          'Gulf Coast Air';
    }
    return _readString(widget.job['proName']) ??
        _readString(widget.job['businessName']) ??
        'Gulf Coast Air';
  }

  String _ratingText() {
    final rating = widget.job['pro']?['verifiedRating'] ??
        widget.job['verifiedRating'] ??
        widget.job['proRating'];
    return rating?.toString() ?? '4.9';
  }

  String _reviewCountText(String fallback) {
    final count = widget.job['pro']?['verifiedCount'] ??
        widget.job['verifiedCount'] ??
        widget.job['reviewCount'];
    return count?.toString() ?? fallback;
  }

  String _money(num amount) =>
      '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  String _initials(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
    if (clean.isEmpty) return 'P';
    return clean
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
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

  Widget _requestCard(String service, String address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$address · Quote Request',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _estimateCard({
    required String initials,
    required String proName,
    required String rating,
    required String reviewCount,
    required num amount,
    required List<String> bullets,
    required String startText,
    required Color startColor,
    required Color accent,
    required VoidCallback onChoose,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy900.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent,
                child: Text(
                  initials,
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
                    Text(
                      '$rating ★ ($reviewCount)',
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _smallLabel('TOTAL ESTIMATE'),
          const SizedBox(height: 8),
          Text(
            _money(amount),
            style: const TextStyle(
              color: AppTheme.orange500,
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppTheme.line),
          ),
          ...bullets.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '•  $item',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: startColor, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  startText,
                  style: TextStyle(
                    color: startColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : onChoose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
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
                  : const Text('Choose this pro'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messaging will open here.')),
                );
              },
              child: const Text(
                'Message',
                style: TextStyle(
                  color: AppTheme.teal500,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.gray,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
      ),
    );
  }
}

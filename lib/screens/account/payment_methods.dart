import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/app_error_utils.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

  List<dynamic> _methods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMethods();
  }

  Future<void> _fetchMethods() async {
    setState(() => _isLoading = true);
    try {
      final profile = await HomeownerService.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _methods = profile['paymentMethods'] as List? ??
            profile['profile']?['paymentMethods'] as List? ??
            const [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorUtils.friendlyMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _addCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add card is not available yet.'),
        backgroundColor: AppTheme.gray,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _appBar('Payment methods'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.orange500),
            )
          : RefreshIndicator(
              onRefresh: _fetchMethods,
              color: AppTheme.orange500,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_methods.isEmpty)
                    _emptyState()
                  else
                    ..._methods.map(
                      (dynamic item) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _methodCard(_asMap(item)),
                      ),
                    ),
                  _addCardButton(),
                  const SizedBox(height: 16),
                  _securityCallout(),
                  const SizedBox(height: 18),
                  const Text(
                    'Cards pay the pro directly. TradeWorks adds no markup and no platform fee.',
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _appBar(String title) {
    return AppBar(
      toolbarHeight: 56,
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 54,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 25),
        color: AppTheme.navy700,
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy700,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _lineSoft),
      ),
    );
  }

  Widget _methodCard(Map<String, dynamic> method) {
    final brand = _string(method['brand']) ?? 'Card';
    final last4 = _string(method['last4']);
    final isDefault =
        method['isDefault'] == true || method['isDefault'] == 'true';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: brand.toLowerCase().contains('visa')
                  ? AppTheme.navy700
                  : _inkStrong,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              brand.toLowerCase().contains('master') ? 'MC' : brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last4 == null ? brand : '$brand ending $last4',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _inkStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _expiryLabel(method),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F7F8),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'DEFAULT',
                style: TextStyle(
                  color: AppTheme.teal500,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            const Icon(
              Icons.card_giftcard_rounded,
              color: _mutedText,
              size: 23,
            ),
        ],
      ),
    );
  }

  Widget _addCardButton() {
    return OutlinedButton(
      onPressed: _addCard,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.teal500,
        side: const BorderSide(color: AppTheme.teal500, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        '+ Add card',
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _securityCallout() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.teal500),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_up_rounded, color: AppTheme.teal500, size: 25),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cards are entered in a secure, encrypted field and tokenized.',
              style: TextStyle(
                color: _inkStrong,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineSoft),
      ),
      child: const Text(
        'No saved payment methods yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _mutedText,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _expiryLabel(Map<String, dynamic> method) {
    final expiry = _string(method['expiry']) ??
        _string(method['expires']) ??
        _string(method['exp']);
    if (expiry != null) return 'Expires $expiry';
    final month = _string(method['expMonth']) ?? _string(method['exp_month']);
    final year = _string(method['expYear']) ?? _string(method['exp_year']);
    if (month != null && year != null) return 'Expires $month/$year';
    return 'Payment method';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

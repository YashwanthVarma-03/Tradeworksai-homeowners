import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/pro_messaging.dart';
import '../../widgets/loading_skeleton.dart';

/// What each booked pro accepts (F07). TradeWorks never stores or uses a
/// homeowner card (Oct 1, G-51): the homeowner pays the pro directly, and
/// this screen only shows what each pro published on their public profile.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _pros = [];
  bool _loading = true;
  Object? _error;

  /// Plain words for the sentence "Accepts card, check or cash".
  static const _labels = {
    'cash': 'cash',
    'check': 'check',
    'card': 'card',
    'credit_card': 'card',
    'debit_card': 'card',
    'ach': 'bank transfer',
    'zelle': 'Zelle',
    'venmo': 'Venmo',
    'paypal': 'PayPal',
    'apple_pay': 'Apple Pay',
    'google_pay': 'Google Pay',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await HomeownerService.instance.fetchWorkOrders(forceRefresh: true);
      final tabs = data['tabs'];
      final pros = <String, Map<String, dynamic>>{};
      if (tabs is Map) {
        for (final rows in tabs.values.whereType<List>()) {
          for (final job in rows.whereType<Map>()) {
            if (job['pro'] is! Map) continue;
            final pro = Map<String, dynamic>.from(job['pro']);
            final key = '${pro['slug'] ?? pro['userId'] ?? pro['id'] ?? ''}';
            if (key.isNotEmpty) pros.putIfAbsent(key, () => pro);
          }
        }
      }
      final resolved = await Future.wait(pros.values.map((pro) async {
        final slug = '${pro['slug'] ?? ''}';
        if (slug.isEmpty) return pro;
        try {
          final data =
              await HomeownerService.instance.getContractorProfile(slug);
          final profile =
              data['profile'] ?? data['contractor'] ?? data['pro'] ?? data;
          return {
            ...pro,
            if (profile is Map) ...Map<String, dynamic>.from(profile)
          };
        } catch (_) {
          return {...pro, 'loadFailed': true};
        }
      }));
      if (mounted) {
        setState(() {
          _pros = resolved;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  String _name(Map<String, dynamic> pro) =>
      '${pro['businessName'] ?? pro['business_name'] ?? 'Your pro'}';

  /// "Accepts card, check or cash", or null when the pro published none.
  String? _accepts(Map<String, dynamic> pro) {
    final raw = pro['payment_methods'] ?? pro['paymentMethods'];
    if (raw is! List) return null;
    final methods = <String>[];
    for (final method in raw) {
      final key = '$method'.trim().toLowerCase();
      if (key.isEmpty) continue;
      final label = _labels[key] ?? key.replaceAll('_', ' ');
      if (!methods.contains(label)) methods.add(label);
    }
    if (methods.isEmpty) return null;
    final list = methods.length == 1
        ? methods.first
        : '${methods.sublist(0, methods.length - 1).join(', ')} or ${methods.last}';
    return 'Accepts $list';
  }

  String _initials(String name) {
    final value = name
        .split(RegExp(r'\s+'))
        .where((part) =>
            part.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(part[0]))
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return value.isEmpty ? 'P' : value;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Payment methods'),
          centerTitle: true,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppTheme.cardBorder),
          ),
        ),
        body: _loading
            ? const SkeletonPage(layout: SkeletonLayout.cards)
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Payment methods could not be loaded.'),
                    TextButton(onPressed: _load, child: const Text('Try again'))
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          Text('Pay your pro directly',
                              style: AppTheme.headingStyle
                                  .copyWith(fontSize: 24, height: 30 / 24)),
                          const SizedBox(height: 8),
                          const Text(
                            'You pay your pro directly. TradeWorks adds no markup and takes no fee — we only fund the credits you apply.',
                            style: TextStyle(
                                color: AppTheme.body,
                                fontSize: 15,
                                height: 23 / 15),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Text('Your booked pros',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                              ),
                              const Text('Published by each pro',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_pros.isEmpty)
                            const Text(
                                'After you book a pro, their accepted payment methods will appear here. You can also check their profile before booking.',
                                style: TextStyle(
                                    color: AppTheme.body,
                                    fontSize: 15,
                                    height: 23 / 15)),
                          for (final pro in _pros) ...[
                            _proCard(pro),
                            const SizedBox(height: 12),
                          ],
                        ])),
      );

  Widget _proCard(Map<String, dynamic> pro) {
    final name = _name(pro);
    final accepts = _accepts(pro);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _initials(name),
                  style: AppTheme.headingStyle.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            accepts ??
                (pro['loadFailed'] == true
                    ? 'Payment details could not be loaded. Pull down to retry.'
                    : 'This pro has not published payment methods.'),
            style: const TextStyle(
                color: AppTheme.body, fontSize: 15, height: 22 / 15),
          ),
          TextButton.icon(
            onPressed: () => openProThread(context, pro, proName: name),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Ask your pro'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

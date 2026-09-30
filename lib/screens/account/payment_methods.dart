import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import '../../services/homeowner_service.dart';
import '../../services/stream_service.dart';
import '../../widgets/app_notification.dart';
import '../chat_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _pros = [];
  bool _loading = true;
  Object? _error;
  static const _labels = {
    'cash': 'Cash',
    'check': 'Check',
    'credit_card': 'Credit card',
    'ach': 'Bank transfer (ACH)',
    'zelle': 'Zelle',
    'venmo': 'Venmo',
    'paypal': 'PayPal',
    'apple_pay': 'Apple Pay',
    'google_pay': 'Google Pay'
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
            if (key.isNotEmpty) pros[key] = pro;
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
      if (mounted)
        setState(() {
          _pros = resolved;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e;
          _loading = false;
        });
    }
  }

  Future<void> _message(Map<String, dynamic> pro) async {
    final id = StreamService.instance.resolveMessagingUserId(pro);
    if (id == null) {
      AppNotification.showInfo(
          context, 'Open this booking to contact your pro.');
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(
                contractorId: id,
                contractorName:
                    '${pro['businessName'] ?? pro['business_name'] ?? 'Your pro'}')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment methods')),
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
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text('Pay your pro directly',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          const Text(
                              'These are the payment methods published by your booked pros. Confirm payment details with your pro. TradeWorks does not store or charge your card here.'),
                          const SizedBox(height: 20),
                          if (_pros.isEmpty)
                            const Text(
                                'After you book a pro, their accepted payment methods will appear here. You can also check their profile before booking.'),
                          for (final pro in _pros)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${pro['businessName'] ?? pro['business_name'] ?? 'Your pro'}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          const SizedBox(height: 12),
                                          if ((pro['payment_methods'] ??
                                                      pro['paymentMethods'])
                                                  is List &&
                                              ((pro['payment_methods'] ??
                                                          pro['paymentMethods'])
                                                      as List)
                                                  .isNotEmpty)
                                            Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  for (final method in (pro[
                                                              'payment_methods'] ??
                                                          pro['paymentMethods'])
                                                      as List)
                                                    Chip(
                                                        label: Text(_labels[
                                                                '$method'] ??
                                                            '$method'))
                                                ])
                                          else
                                            Text(pro['loadFailed'] == true
                                                ? 'Payment details could not be loaded. Pull down to retry.'
                                                : 'This pro has not published payment methods.'),
                                          TextButton.icon(
                                              onPressed: () => _message(pro),
                                              icon: const Icon(
                                                  Icons.chat_bubble_outline),
                                              label:
                                                  const Text('Ask your pro')),
                                        ]))),
                        ])),
      );
}

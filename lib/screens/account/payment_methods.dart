import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/homeowner_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
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
      if (mounted) {
        setState(() {
          _methods = profile['paymentMethods'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMethod(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: const Text('Are you sure you want to remove this card?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: AppTheme.gray))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _methods.removeWhere((m) => m['id'] == id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Card removed'), backgroundColor: AppTheme.success));
    }
  }

  Future<void> _setDefault(String id) async {
    setState(() {
      for (var m in _methods) {
        m['isDefault'] = (m['id'] == id);
      }
    });
  }

  void _addCard() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon.'),
        backgroundColor: AppTheme.gray,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        title: const Text('Payment methods',
            style: TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.tealTint,
              child: const Row(
                children: [
                  Icon(Icons.security, color: AppTheme.teal700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cards pay the pro directly. No markup, no platform fee.',
                      style: TextStyle(
                          color: AppTheme.teal700,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.orange500))
                  : _methods.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.white,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Add card',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_outlined,
              size: 64, color: AppTheme.gray.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No payment methods',
              style: TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add a card to book a pro.',
              style: TextStyle(color: AppTheme.gray)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _methods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final m = _methods[index];
        final isDefault = m['isDefault'] == true;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              m['brand'] == 'Visa' ? Icons.payment : Icons.credit_card,
              color: AppTheme.navy700,
              size: 32,
            ),
            title: Row(
              children: [
                Text('${m['brand']} •••• ${m['last4']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.navy700)),
                if (isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppTheme.tealTint,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Default',
                        style: TextStyle(
                            color: AppTheme.teal700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ]
              ],
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: AppTheme.gray),
              itemBuilder: (context) => [
                if (!isDefault)
                  const PopupMenuItem(
                      value: 'default', child: Text('Set as default')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove',
                        style: TextStyle(color: AppTheme.error))),
              ],
              onSelected: (val) {
                if (val == 'default') {
                  _setDefault(m['id']);
                } else if (val == 'delete') {
                  _deleteMethod(m['id']);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class AddCardSheet extends StatefulWidget {
  const AddCardSheet({Key? key}) : super(key: key);

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  bool _isLoading = false;

  void _tokenizeAndSave() async {
    setState(() => _isLoading = true);
    // Simulate SDK tokenization
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context, {
        'id': 'pm_${DateTime.now().millisecondsSinceEpoch}',
        'brand': 'Visa',
        'last4': '4242',
        'isDefault': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 24),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Add payment method',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy700)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          // Mock secure field from SDK
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    const Text('Secure card field (PCI compliant)',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                const TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Card number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: const TextField(
                        decoration: InputDecoration(
                            hintText: 'MM/YY', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const TextField(
                        decoration: InputDecoration(
                            hintText: 'CVC', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _tokenizeAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: AppTheme.navy700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.navy700))
                  : const Text('Save card',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

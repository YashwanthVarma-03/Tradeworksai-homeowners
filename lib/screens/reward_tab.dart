import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class RewardTab extends StatelessWidget {
  final VoidCallback onBookTap;

  const RewardTab({
    super.key,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedEntrance(
            delay: Duration.zero,
            child: _buildHeader(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 100),
            child: _buildBalanceLedgerCard(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 200),
            child: _buildMarginalBandsCard(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 300),
            child: _buildReferralCard(context),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 400),
            child: _buildHistorySection(),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            delay: const Duration(milliseconds: 500),
            child: _buildExplainerCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rewards Program',
          style: TextStyle(color: AppTheme.gray, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'Service Credit Ledger',
          style: AppTheme.headingStyle.copyWith(fontSize: 22, color: AppTheme.navy700),
        ),
      ],
    );
  }

  Widget _buildBalanceLedgerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Credits Balance',
                  style: TextStyle(color: AppTheme.gray, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$214.60',
                  style: AppTheme.headingStyle.copyWith(
                    fontSize: 36,
                    color: AppTheme.teal700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Ready to redeem at checkout',
                      style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA500).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.stars,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginalBandsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Marginal Cashback Progress',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orangeTint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '5% Active Band',
                  style: TextStyle(color: AppTheme.orange500, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your cashback rate grows as you spend. Higher rates apply to spend within each band.',
            style: TextStyle(color: AppTheme.gray, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 16),
          _buildBandProgressBar(
            label: 'Band 1: 3% Cashback (on first \$5k)',
            spentText: '\$5,000 / \$5,000',
            progress: 1.0,
            statusColor: AppTheme.navy700,
            statusText: 'Completed',
          ),
          const SizedBox(height: 12),
          _buildBandProgressBar(
            label: 'Band 2: 5% Cashback (\$5k to \$15k)',
            spentText: '\$820 / \$10,000',
            progress: 0.082,
            statusColor: AppTheme.orange500,
            statusText: 'Active',
          ),
          const SizedBox(height: 12),
          _buildBandProgressBar(
            label: 'Band 3: 7% Cashback (\$15k to \$25k)',
            spentText: '\$0 / \$10,000',
            progress: 0.0,
            statusColor: AppTheme.gray,
            statusText: 'Locked',
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Annual Platform Spend', style: TextStyle(color: AppTheme.gray, fontSize: 10)),
                  Text(
                    '\$5,820.00',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onBookTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Book Service',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBandProgressBar({
    required String label,
    required String spentText,
    required double progress,
    required Color statusColor,
    required String statusText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.navy700)),
            Text(
              statusText,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppTheme.line.withOpacity(0.3),
            color: statusColor,
          ),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            spentText,
            style: const TextStyle(fontSize: 10, color: AppTheme.gray),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.tealTint.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.teal500.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.tealTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people, color: AppTheme.teal700, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Refer a Neighbor, Earn \$25',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.teal700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Share the network. Get \$25 in service credits for every neighbor who completes their first booking. They\'ll get \$25 off too!',
            style: TextStyle(color: AppTheme.navy700, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          HoverButton(
            text: 'Copy Referral Link',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Referral link copied to clipboard!'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'WO-9421 AC System Diagnostic',
        'sub': 'Miller Cool Air & Heating • Jun 24, 2026',
        'spent': '\$89.00',
        'rate': '5% rate',
        'earned': '+\$4.45',
      },
      {
        'title': 'WO-8910 Pipe Leak Fix',
        'sub': 'Jenkins Plumbing Group • Mar 12, 2026',
        'spent': '\$146.00',
        'rate': '5% rate',
        'earned': '+\$7.30',
      },
      {
        'title': 'WO-7811 Spring Lawn Treatment',
        'sub': 'Apex Yard Pros • Mar 12, 2026',
        'spent': '\$55.00',
        'rate': '5% rate',
        'earned': '+\$2.75',
      },
      {
        'title': 'Welcome Promo Credit',
        'sub': 'Account Creation Bonus • Jan 15, 2026',
        'spent': 'N/A',
        'rate': 'Flat bonus',
        'earned': '+\$200.10', // 200.10 + 2.75 + 7.30 + 4.45 = 214.60
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Earnings Ledger History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.line, width: 0.5),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.pageAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_card, color: AppTheme.teal700),
              ),
              title: Text(
                item['title']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy700),
              ),
              subtitle: Text(
                '${item['sub']} (${item['rate']})',
                style: const TextStyle(color: AppTheme.gray, fontSize: 11),
              ),
              trailing: Text(
                item['earned']!,
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExplainerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.navy700, size: 20),
              SizedBox(width: 8),
              Text(
                'How Rewards Work',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.navy700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '• Membership is 100% free and automatic. No fees are ever deducted.\n'
            '• Earn credits on every invoice paid directly to vetted network contractors.\n'
            '• Cashback rate is calculated marginally by annual spend bands (3%, 5%, and 7%).\n'
            '• Service credits are non-cashable and can be applied toward any service category on the TradeWorks menu.\n'
            '• Credits expire 24 months after earning.',
            style: TextStyle(color: AppTheme.gray, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

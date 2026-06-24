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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Balance Hero with Navy -> Teal gradient
          _buildBalanceHero(context),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Band Progress (Marginal Tiers)
                _buildBandProgressSection(),
                const SizedBox(height: 24),

                // 3. How Rewards Work
                _buildHowItWorksSection(),
                const SizedBox(height: 24),

                // 4. Credit History (Ledger)
                _buildActivityLedgerSection(context),
                const SizedBox(height: 24),

                // 5. Redeem (MVP)
                _buildRedeemSection(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHero(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1B3C6E),
            Color(0xFF235C86),
            Color(0xFF2E86AB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rewards',
                style: AppTheme.headingStyle.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showInfoDialog(context);
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Available service credits',
            style: TextStyle(color: Color(0xFFDCEAF4), fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            '\$420',
            style: AppTheme.headingStyle.copyWith(
              fontSize: 42,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Earned this year: \$400',
            style: TextStyle(color: Color(0xFFE3EFF7), fontSize: 13),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, color: Colors.white, size: 13),
                SizedBox(width: 6),
                Text(
                  'Non-cashable · credits expire 24 months after earning',
                  style: TextStyle(color: Colors.white, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Credits Program', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'TradeWorks service credits are earned automatically on completed bookings and can be redeemed for any future home service in our network.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBandProgressSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your 2026 progress',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
              ),
              Text(
                '\$10,000 spent',
                style: TextStyle(color: AppTheme.gray, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Band 1
          _buildBandRow(
            rate: '3%',
            rateColor: AppTheme.tealTint,
            textColor: AppTheme.teal700,
            range: 'First \$5,000',
            progress: 1.0,
            earned: '+\$150',
            spentDetail: '\$5,000 spent',
            muted: false,
          ),
          const SizedBox(height: 12),

          // Band 2
          _buildBandRow(
            rate: '5%',
            rateColor: const Color(0xFFD3EDF7),
            textColor: AppTheme.teal700,
            range: '\$5,000 – \$15,000',
            progress: 0.5,
            earned: '+\$250',
            spentDetail: '\$5,000 spent',
            muted: false,
          ),
          const SizedBox(height: 12),

          // Band 3
          _buildBandRow(
            rate: '7%',
            rateColor: AppTheme.navyTint,
            textColor: AppTheme.navy700,
            range: '\$15,000 – \$25,000',
            progress: 0.0,
            earned: '\$0',
            spentDetail: 'not reached',
            muted: true,
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.bolt, color: AppTheme.orange500, size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Spend \$5,000 more to start earning 7% back',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.navy700, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBandRow({
    required String rate,
    required Color rateColor,
    required Color textColor,
    required String range,
    required double progress,
    required String earned,
    required String spentDetail,
    required bool muted,
  }) {
    return Opacity(
      opacity: muted ? 0.55 : 1.0,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: rateColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(rate, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: textColor, height: 1.0)),
                const Text('BACK', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w500, letterSpacing: 0.04, color: AppTheme.gray)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(range, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEF2F7),
                    color: progress == 1.0 ? AppTheme.teal700 : AppTheme.teal500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                earned,
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.ink),
              ),
              Text(
                spentDetail,
                style: const TextStyle(fontSize: 10.5, color: AppTheme.gray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    final rules = [
      'Earn <b>3% → 5% → 7%</b> back as you spend more in a year — each rate applies <b>only to spend within its band</b> (no retroactive re-crediting).',
      'Credits are <b>service credits</b> — use them toward any booking. They never count as new spend.',
      'Non-cashable and non-transferable; each credit <b>expires 24 months</b> after you earn it.',
      'Bands <b>reset every January 1</b>; above \$25,000 in a year you keep earning <b>5% back</b>.',
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How rewards work',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.teal500, size: 16),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        rules[index]
                            .replaceAll('<b>', '')
                            .replaceAll('</b>', ''), // simple strip for pure flutter
                        style: const TextStyle(fontSize: 12.7, color: Color(0xFF42526A), height: 1.45),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLedgerSection(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'service': 'House cleaning',
        'meta': 'Earned Jun 18, 2026 · expires Jun 2028',
        'amount': '+\$9',
        'warn': false,
      },
      {
        'service': 'AC Tune-Up',
        'meta': 'Earned Jun 12, 2026 · expires Jun 2028',
        'amount': '+\$8',
        'warn': false,
      },
      {
        'service': 'Drain cleaning',
        'meta': 'Earned Aug 2024 · ',
        'amount': '+\$6',
        'warn': true,
        'warnText': 'expires in 2 months',
      },
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent activity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
              ),
              Text(
                'Earned',
                style: TextStyle(color: AppTheme.gray, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final isWarn = item['warn'] == true;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.tealTint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, color: AppTheme.teal500, size: 16),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['service']!,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              item['meta']!,
                              style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                            ),
                            if (isWarn)
                              Text(
                                item['warnText']!,
                                style: const TextStyle(color: AppTheme.orange500, fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item['amount']!,
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.success),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 11),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening full rewards history Ledger...')),
              );
            },
            child: const Center(
              child: Text(
                'See all activity ›',
                style: TextStyle(color: AppTheme.teal500, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.orangeTint,
        border: Border.all(color: const Color(0xFFF3D2B2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use your credits',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Credits apply to your next booking. To redeem, just reach out and we\'ll apply them for you.',
            style: TextStyle(color: Color(0xFF5A4634), fontSize: 12.7, height: 1.5),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connecting to support line at 555-0199...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange500,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 16),
                SizedBox(width: 8),
                Text('Contact support to redeem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 9),
          const Center(
            child: Text(
              'In-app redemption is coming soon',
              style: TextStyle(color: AppTheme.gray, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

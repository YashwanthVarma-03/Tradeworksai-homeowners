import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/homeowner_service.dart';

class RewardTab extends StatefulWidget {
  final VoidCallback onBookTap;

  const RewardTab({
    super.key,
    required this.onBookTap,
  });

  @override
  State<RewardTab> createState() => _RewardTabState();
}

class _RewardTabState extends State<RewardTab> {
  bool _isLoading = true;
  String? _errorMessage;
  double _rewardsBalance = 0.0;
  double _rewardsEarnedThisYear = 0.0;
  double _ytdSpend = 0.0;
  String _rewardsTier = 'bronze';
  double _rewardsRate = 0.03;
  List<dynamic> _ledger = [];

  @override
  void initState() {
    super.initState();
    _fetchRewardsData();
  }

  Future<void> _fetchRewardsData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await HomeownerService.instance.fetchRewards();
      if (mounted) {
        setState(() {
          _rewardsBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          _rewardsEarnedThisYear = (data['earnedThisYear'] as num?)?.toDouble() ?? 0.0;
          _ytdSpend = (data['ytdSpend'] as num?)?.toDouble() ?? 0.0;
          _rewardsTier = (data['tier'] as String?)?.toLowerCase() ?? 'bronze';
          _rewardsRate = (data['rate'] as num?)?.toDouble() ?? 0.03;
          _ledger = data['ledger'] as List? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchRewardsData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRewardsData,
      color: AppTheme.orange500,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceHero(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBandProgressSection(),
                  const SizedBox(height: 24),
                  _buildActivityLedgerSection(context),
                  const SizedBox(height: 24),
                  _buildRedeemSection(context),
                ],
              ),
            ),
          ],
        ),
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
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Available service credits',
            style: TextStyle(color: Color(0xFFDCEAF4), fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${_rewardsBalance.toStringAsFixed(0)}',
            style: AppTheme.headingStyle.copyWith(
              fontSize: 42,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Earned this year: \$${_rewardsEarnedThisYear.toStringAsFixed(0)}',
            style: const TextStyle(color: Color(0xFFE3EFF7), fontSize: 13),
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
    double band1Progress = (_ytdSpend / 5000.0).clamp(0.0, 1.0);
    double band2Progress = ((_ytdSpend - 5000.0) / 10000.0).clamp(0.0, 1.0);
    double band3Progress = ((_ytdSpend - 15000.0) / 10000.0).clamp(0.0, 1.0);

    double band1Earned = _ytdSpend < 5000 ? _ytdSpend * 0.03 : 5000.0 * 0.03;
    double band2Earned = _ytdSpend < 5000 ? 0.0 : (_ytdSpend < 15000 ? (_ytdSpend - 5000.0) * 0.05 : 10000.0 * 0.05);
    double band3Earned = _ytdSpend < 15000 ? 0.0 : (_ytdSpend - 15000.0) * 0.07;

    String nextBandText = '';
    if (_ytdSpend < 5000) {
      nextBandText = 'Spend \$${(5000.0 - _ytdSpend).toStringAsFixed(0)} more to start earning 5% back';
    } else if (_ytdSpend < 15000) {
      nextBandText = 'Spend \$${(15000.0 - _ytdSpend).toStringAsFixed(0)} more to start earning 7% back';
    } else {
      nextBandText = 'You are in the elite 7% band!';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your 2026 progress',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
              ),
              Text(
                '\$${_ytdSpend.toStringAsFixed(0)} spent',
                style: const TextStyle(color: AppTheme.gray, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildBandRow(
            rate: '3%',
            rateColor: AppTheme.tealTint,
            textColor: AppTheme.teal700,
            range: 'First \$5,000',
            progress: band1Progress,
            earned: '+\$${band1Earned.toStringAsFixed(0)}',
            spentDetail: _ytdSpend < 5000 ? '\$${_ytdSpend.toStringAsFixed(0)} spent' : '\$5,000 spent',
            muted: _ytdSpend < 0,
          ),
          const SizedBox(height: 12),

          _buildBandRow(
            rate: '5%',
            rateColor: const Color(0xFFD3EDF7),
            textColor: AppTheme.teal700,
            range: '\$5,000 – \$15,000',
            progress: band2Progress,
            earned: '+\$${band2Earned.toStringAsFixed(0)}',
            spentDetail: _ytdSpend < 5000
                ? 'not reached'
                : (_ytdSpend < 15000
                    ? '\$${(_ytdSpend - 5000.0).toStringAsFixed(0)} spent'
                    : '\$10,000 spent'),
            muted: _ytdSpend < 5000,
          ),
          const SizedBox(height: 12),

          _buildBandRow(
            rate: '7%',
            rateColor: AppTheme.navyTint,
            textColor: AppTheme.navy700,
            range: '\$15,000 – \$25,000',
            progress: band3Progress,
            earned: band3Earned > 0 ? '+\$${band3Earned.toStringAsFixed(0)}' : '\$0',
            spentDetail: _ytdSpend < 15000
                ? 'not reached'
                : '\$${(_ytdSpend - 15000.0).toStringAsFixed(0)} spent',
            muted: _ytdSpend < 15000,
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bolt, color: AppTheme.orange500, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nextBandText,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.navy700, fontWeight: FontWeight.bold),
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

  Widget _buildActivityLedgerSection(BuildContext context) {
    if (_ledger.isEmpty) {
      return GlassCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('No recent activity ledger items found.', style: TextStyle(color: AppTheme.gray, fontSize: 12.5)),
          ),
        ),
      );
    }

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
          ..._ledger.map((item) {
            final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
            final isEarn = amount >= 0;
            final dateStr = _formatDate(item['createdAt']);
            final expDateStr = _formatDate(item['expiresAt']);
            final String desc = item['description'] ?? 'Home service credits';

            final isWarn = item['expired'] == true;

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
                      color: isEarn ? AppTheme.tealTint : const Color(0xFFF7E4E4),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isEarn ? Icons.add : Icons.remove,
                      color: isEarn ? AppTheme.teal500 : const Color(0xFFB23535),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          desc,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.ink),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEarn
                                    ? 'Earned $dateStr · expires $expDateStr'
                                    : 'Redeemed $dateStr',
                                style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isWarn)
                              const Text(
                                'Expired',
                                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isEarn ? '+' : ''}\$${amount.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isEarn ? AppTheme.success : const Color(0xFFB23535),
                    ),
                  ),
                ],
              ),
            );
          }),
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
        ],
      ),
    );
  }
}

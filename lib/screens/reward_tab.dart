import 'package:flutter/material.dart';

import '../services/homeowner_service.dart';
import '../theme.dart';
import '../utils/app_error_utils.dart';
import '../widgets/offline_state.dart';

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
  double? _rewardsBalance;
  double? _rewardsEarnedThisYear;
  double? _ytdSpend;
  double? _rewardsRate;
  List<Map<String, dynamic>> _ledger = const [];
  List<Map<String, dynamic>> _tiers = const [];

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
      if (!mounted) return;
      setState(() {
        _rewardsBalance = _readAmount(data, const [
          'balance',
          'rewardsBalance',
          'availableCredits',
          'availableServiceCredits',
        ]);
        _rewardsEarnedThisYear = _readAmount(data, const [
          'earnedThisYear',
          'earned',
          'yearToDateEarned',
          'creditsEarnedThisYear',
        ]);
        _ytdSpend = _readAmount(data, const [
          'ytdSpend',
          'yearToDateSpend',
          'spentThisYear',
          'annualSpend',
        ]);
        _rewardsRate = _readAmount(data, const ['rate', 'rewardsRate']);
        _ledger = _readMapList(
          data['ledger'] ?? data['activity'] ?? data['recentActivity'],
        );
        _tiers = _readMapList(data['tiers'] ?? data['earningTiers']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
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
      return OfflineState(
        onRetry: _fetchRewardsData,
        message: _errorMessage,
      );
    }

    final balance = _rewardsBalance ?? 0;
    final hasRewards = balance > 0 ||
        (_rewardsEarnedThisYear ?? 0) > 0 ||
        (_ytdSpend ?? 0) > 0 ||
        _ledger.isNotEmpty;

    return Container(
      color: AppTheme.pageAlt,
      child: RefreshIndicator(
        onRefresh: _fetchRewardsData,
        color: AppTheme.orange500,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          children: [
            const Text(
              'Rewards',
              style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Available service credits',
              style: TextStyle(
                color: AppTheme.gray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _balanceCard(balance: balance, hasRewards: hasRewards),
            const SizedBox(height: 18),
            if (hasRewards) ...[
              if (_ytdSpend != null ||
                  _rewardsEarnedThisYear != null ||
                  _rewardsRate != null)
                _progressCard(),
              if (_ledger.isNotEmpty) ...[
                const SizedBox(height: 18),
                _activityCard(),
              ],
              if (_ledger.isEmpty &&
                  _ytdSpend == null &&
                  _rewardsEarnedThisYear == null &&
                  _rewardsRate == null)
                _backendEmptyCard(),
            ] else ...[
              _firstBookingCard(),
              if (_tiers.isNotEmpty) ...[
                const SizedBox(height: 18),
                _tiersCard(),
              ],
              const SizedBox(height: 22),
              _browseButton(),
            ],
          ],
        ),
      ),
    );
  }

  double? _readAmount(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key) || data[key] == null) continue;
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed =
            double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _readMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _money(num amount, {bool cents = false}) {
    final decimals = cents || amount % 1 != 0 ? 2 : 0;
    return '\$${amount.toStringAsFixed(decimals)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    final dt = DateTime.tryParse(text);
    if (dt == null) return text;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Widget _balanceCard({required double balance, required bool hasRewards}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: AppTheme.navy700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _money(balance, cents: true),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 39,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (hasRewards)
                Container(
                  margin: const EdgeInsets.only(top: 4, left: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.teal500,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Auto-applied',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            hasRewards
                ? 'Applied automatically at checkout'
                : 'Book your first service to start earning',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('YOUR ${DateTime.now().year} PROGRESS'),
          if (_ytdSpend != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_money(_ytdSpend!)} spent this year',
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.line),
          if (_rewardsEarnedThisYear != null) ...[
            const SizedBox(height: 12),
            _dataLine(
              'Earned this year',
              _money(_rewardsEarnedThisYear!, cents: true),
              valueColor: AppTheme.success,
            ),
          ],
          if (_rewardsRate != null) ...[
            const SizedBox(height: 12),
            _dataLine(
              'Current rate',
              '${(_rewardsRate! * 100).toStringAsFixed(_rewardsRate! * 100 % 1 == 0 ? 0 : 1)}% back',
              valueColor: AppTheme.teal500,
            ),
          ],
        ],
      ),
    );
  }

  Widget _activityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('RECENT ACTIVITY'),
          const SizedBox(height: 14),
          ...List.generate(_ledger.length.clamp(0, 4), (index) {
            final item = _ledger[index];
            return Column(
              children: [
                _activityRow(item),
                if (index < _ledger.length.clamp(0, 4) - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppTheme.line),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _firstBookingCard() {
    return _card(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppTheme.tealTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppTheme.teal500,
              size: 29,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Earn credits on every booking',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 17,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Credits from completed work orders will appear here after the backend returns rewards activity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.gray,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiersCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('EARNING TIERS'),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.line),
          const SizedBox(height: 12),
          ...List.generate(_tiers.length, (index) {
            final tier = _tiers[index];
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == _tiers.length - 1 ? 0 : 12),
              child: _tierLine(tier),
            );
          }),
        ],
      ),
    );
  }

  Widget _backendEmptyCard() {
    return _card(
      child: const Text(
        'Rewards data is available, but this response did not include progress or activity details.',
        style: TextStyle(
          color: AppTheme.gray,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.navy700,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _dataLine(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _activityRow(Map<String, dynamic> item) {
    final amount = _amount(item['amount'] ?? item['credits'] ?? item['value']);
    final isEarned = amount >= 0;
    final title = item['description']?.toString() ??
        item['serviceName']?.toString() ??
        item['title']?.toString() ??
        'Rewards activity';
    final date = _formatDate(item['createdAt'] ?? item['created_at']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${isEarned ? '+' : '-'}${_money(amount.abs(), cents: true)}',
          style: TextStyle(
            color: isEarned ? AppTheme.success : AppTheme.error,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _tierLine(Map<String, dynamic> tier) {
    final rate = tier['rate']?.toString() ?? '';
    final label = tier['label']?.toString() ??
        tier['range']?.toString() ??
        tier['name']?.toString() ??
        '';
    final earned = tier['earned'] == null ? '' : _money(_amount(tier['earned']));

    return Row(
      children: [
        if (rate.isNotEmpty) ...[
          Text(
            rate,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (earned.isNotEmpty)
          Text(
            earned,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }

  Widget _browseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onBookTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        child: const Text('Browse services'),
      ),
    );
  }
}

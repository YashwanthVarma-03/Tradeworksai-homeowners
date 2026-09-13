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
  static const Color _cardLine = Color(0xFFE6E8EC);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _progressTrack = Color(0xFFE2E8F0);

  bool _isLoading = true;
  bool _isRefreshing = false;
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
    HomeownerService.instance.syncVersion.addListener(_refreshFromSharedSync);
    _fetchRewardsData();
  }

  @override
  void dispose() {
    HomeownerService.instance.syncVersion.removeListener(_refreshFromSharedSync);
    super.dispose();
  }

  bool get _hasRewardsContent =>
      _rewardsBalance != null ||
      _rewardsEarnedThisYear != null ||
      _ytdSpend != null ||
      _ledger.isNotEmpty ||
      _tiers.isNotEmpty;

  void _refreshFromSharedSync() {
    _fetchRewardsData(showLoading: false);
  }

  Future<void> _fetchRewardsData({bool showLoading = true}) async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;
    if (showLoading && !_hasRewardsContent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
        _errorMessage = _hasRewardsContent ? null : AppErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            const Text(
              'Available service credits',
              style: TextStyle(
                color: _mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            _balanceCard(balance: balance, hasRewards: hasRewards),
            const SizedBox(height: 20),
            if (hasRewards) ...[
              if (_ytdSpend != null ||
                  _rewardsEarnedThisYear != null ||
                  _rewardsRate != null)
                _progressCard(),
              if (_ytdSpend != null ||
                  _rewardsEarnedThisYear != null ||
                  _rewardsRate != null)
                const SizedBox(height: 20),
              _howItWorksCard(),
              if (_ledger.isNotEmpty) ...[
                const SizedBox(height: 20),
                _activityCard(),
              ] else if (_ytdSpend == null &&
                  _rewardsEarnedThisYear == null &&
                  _rewardsRate == null) ...[
                const SizedBox(height: 20),
                _backendEmptyCard(),
              ],
            ] else ...[
              _firstBookingCard(),
              const SizedBox(height: 20),
              _tiersCard(),
              const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy700, Color(0xFF2E4E80)],
        ),
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
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (hasRewards)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.teal500,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Auto-applied',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
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
                color: _mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: _cardLine),
          if (_rewardsEarnedThisYear != null) ...[
            const SizedBox(height: 12),
            _progressRow(
              label: 'CREDITS EARNED',
              detail: 'This year',
              value: '+${_money(_rewardsEarnedThisYear!, cents: true)}',
              valueColor: AppTheme.teal500,
              progress: _spendProgress,
              leadingIcon: Icons.check_circle_rounded,
            ),
          ],
          if (_rewardsRate != null) ...[
            const SizedBox(height: 12),
            _progressRow(
              label: 'CURRENT RATE',
              detail: 'On eligible services',
              value:
                  '${(_rewardsRate! * 100).toStringAsFixed(_rewardsRate! * 100 % 1 == 0 ? 0 : 1)}% back',
              valueColor: AppTheme.orange500,
              progress: _spendProgress,
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: _cardLine),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppTheme.teal500),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Credits are applied automatically when you book.',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double get _spendProgress {
    if (_ytdSpend == null || _ytdSpend! <= 0) return 0;
    return (_ytdSpend! / 25000).clamp(0.0, 1.0).toDouble();
  }

  Widget _progressRow({
    required String label,
    required String detail,
    required String value,
    required Color valueColor,
    required double progress,
    IconData? leadingIcon,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: valueColor),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: valueColor,
            backgroundColor: _progressTrack,
          ),
        ),
      ],
    );
  }

  Widget _howItWorksCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('HOW IT WORKS'),
          const SizedBox(height: 16),
          _howItWorksRow(
            icon: Icons.event_available_outlined,
            title: '1. Book a service',
            description: 'Earn credits on every completed work order',
          ),
          const SizedBox(height: 16),
          _howItWorksRow(
            icon: Icons.trending_up_rounded,
            title: '2. Credits accumulate',
            description: 'Higher tiers unlock as you spend more each year',
          ),
          const SizedBox(height: 16),
          _howItWorksRow(
            icon: Icons.shopping_cart_outlined,
            title: '3. Use at checkout',
            description: 'Credits apply automatically when you book.',
          ),
        ],
      ),
    );
  }

  Widget _howItWorksRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: _progressTrack,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppTheme.navy700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: _mutedText,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('RECENT ACTIVITY'),
          const SizedBox(height: 12),
          ...List.generate(_ledger.length.clamp(0, 4), (index) {
            final item = _ledger[index];
            return Column(
              children: [
                _activityRow(item),
                if (index < _ledger.length.clamp(0, 4) - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: _cardLine),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.tealTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_outlined,
              color: AppTheme.teal500,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Earn credits on every booking',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get 3–7% back as service credits on every completed work order. Credits are applied automatically the next time you book — no codes needed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _mutedText,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w400,
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
          const Divider(height: 1, color: _cardLine),
          const SizedBox(height: 12),
          ...List.generate(_tiers.isEmpty ? 3 : _tiers.length, (index) {
            if (_tiers.isEmpty) {
              const rates = ['3% BACK', '5% BACK', '7% BACK'];
              const labels = [
                'First \$5,000',
                '\$5,000–\$15,000',
                '\$15,000–\$25,000',
              ];
              return Padding(
                padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
                child: _staticTierLine(rates[index], labels[index]),
              );
            }
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rewards details are on the way',
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your available credits are shown above. More earning details will appear here when available.',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardLine),
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
        letterSpacing: 0.5,
      ),
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
                    color: _mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${isEarned ? '+' : '−'}${_money(amount.abs(), cents: true)} ${isEarned ? 'earned' : 'applied'}',
          style: TextStyle(
            color: isEarned ? AppTheme.success : AppTheme.navy700,
            fontSize: 13,
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
              color: _mutedText,
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
              color: _mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (earned.isNotEmpty)
          Text(
            earned,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }

  Widget _staticTierLine(String rate, String range) {
    return Row(
      children: [
        Text(
          rate,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            range,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Text(
          '\$0 earned',
          style: TextStyle(
            color: _mutedText,
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

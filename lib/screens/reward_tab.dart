import '../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/homeowner_service.dart';
import '../theme.dart';
import '../widgets/app_notification.dart';
import '../widgets/offline_state.dart';
import 'work_orders/work_order_detail.dart';

class RewardTab extends StatefulWidget {
  final VoidCallback onBookTap;
  final Future<Map<String, dynamic>> Function({bool forceRefresh})? loadRewards;
  const RewardTab({super.key, required this.onBookTap, this.loadRewards});
  @override
  State<RewardTab> createState() => _RewardTabState();
}

class _RewardTabState extends State<RewardTab> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  bool _opening = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    HomeownerService.instance.syncVersion.addListener(_sync);
    _load();
  }

  @override
  void dispose() {
    HomeownerService.instance.syncVersion.removeListener(_sync);
    super.dispose();
  }

  void _sync() => _load();
  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await (widget.loadRewards ??
          HomeownerService.instance.fetchRewards)(forceRefresh: refresh);
      if (mounted)
        setState(() {
          _data = data;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _number(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    return n != null && n.isFinite ? n : null;
  }

  List<Map<String, dynamic>> _rows(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  String _money(dynamic v) => _number(v) == null
      ? '—'
      : NumberFormat.simpleCurrency().format(_number(v));
  String _date(dynamic v) {
    final d = DateTime.tryParse('$v');
    return d == null ? '' : DateFormat.yMMMd().format(d.toLocal());
  }

  Future<void> _open(dynamic rawId) async {
    final id = int.tryParse('$rawId');
    if (id == null || id <= 0 || _opening) return;
    setState(() => _opening = true);
    try {
      final job = await HomeownerService.instance.findWorkOrder(id);
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  WorkOrderDetailScreen(job: job, focusMoney: true)));
      await _load(refresh: true);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(text,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy)));

  @override
  Widget build(BuildContext context) {
    if (_data == null && _loading)
      return const SkeletonPage(layout: SkeletonLayout.cards);
    if (_data == null && _error != null)
      return OfflineState(onRetry: () => _load(refresh: true));
    final d = _data ?? {};
    final bands = _rows(d['bands'] ?? d['earningBands'] ?? d['tiers']);
    final milestones = _rows(d['milestones']);
    final receipts = _rows(d['pendingReceipts'])
        .where((r) => (_number(r['paidAmount'] ?? r['amount']) ?? 0) > 0);
    final ledger = _rows(d['ledger']);
    ledger.sort((a, b) {
      final order = (a['type'] == 'expired' || a['expired'] == true ? 1 : 0)
          .compareTo(b['type'] == 'expired' || b['expired'] == true ? 1 : 0);
      return order != 0
          ? order
          : '${b['occurredAt'] ?? b['createdAt'] ?? ''}'
              .compareTo('${a['occurredAt'] ?? a['createdAt'] ?? ''}');
    });
    final spend = _number(d['periodSpend'] ?? d['qualifyingSpend']);
    final earned = _number(d['earnedInWindow'] ?? d['earnedThisPeriod']);
    final rate = _number(d['currentBandRate']);
    final periodEnds = _date(d['programPeriodEnd'] ??
        d['programPeriodEnds'] ?? d['resetDate']);
    return RefreshIndicator(
        color: AppTheme.navy,
        onRefresh: () => _load(refresh: true),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null)
                const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                        'Could not update credits. Showing saved information.',
                        style: TextStyle(color: AppTheme.amber))),
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: AppTheme.navy,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available service credits',
                            style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(_money(d['balance']),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Tell us how much to apply when you book',
                            style: TextStyle(color: Colors.white)),
                      ])),
              for (final expiry in _rows(d['expiringSoon']))
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                        '${_money(expiry['amount'])} expires ${_date(expiry['expiresAt'])}',
                        style: const TextStyle(color: AppTheme.amber))),
              if (receipts.isNotEmpty) ...[
                _heading('Upload your paid receipt'),
                const Text(
                    'Your customer-paid portion earns credits once the paid receipt is uploaded.'),
                for (final r in receipts)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['service'] ?? 'Completed service'}'),
                      subtitle: Text(
                          '${_money(r['paidAmount'] ?? r['amount'])} paid · Receipt needed'),
                      trailing: const Icon(Icons.upload_file_outlined,
                          color: AppTheme.amber),
                      onTap: _opening ? null : () => _open(r['workOrderId'])),
              ],
              if (spend != null || earned != null || rate != null) ...[
                _heading('Your rewards year'),
                if (spend != null) ...[
                  Text(periodEnds.isEmpty
                      ? '${_money(spend)} spent so far · ${_money(30000)} cap'
                      : '${_money(spend)} spent · resets $periodEnds'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: (spend / 30000).clamp(0, 1),
                      color: AppTheme.blue,
                      backgroundColor: AppTheme.cardBorder,
                      semanticsLabel:
                          'Qualifying spend toward the rewards-year cap'),
                ],
                if (earned != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          '${_money(earned)} earned since your year started',
                          style: const TextStyle(color: AppTheme.green))),
                if (rate != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          'Current band: ${rate.toStringAsFixed(0)}% · ${periodEnds.isEmpty ? 'Your rate on new spend' : 'Your rate on new spend until $periodEnds'}',
                          style: const TextStyle(color: AppTheme.blue))),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Your bands and milestones reset on your anniversary. Credits you\'ve already earned keep their own expiry dates.',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
              if (bands.isNotEmpty) ...[
                _heading('Earning bands'),
                const Text(
                    'Each dollar earns at its band’s rate. Earlier earnings never change.'),
                for (final b in bands)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${b['rate']}% · ${_money(b['floor'])}–${_money(b['ceiling'])}'),
                      subtitle: b['earnedInBand'] == null
                          ? null
                          : Text('${_money(b['earnedInBand'])} earned')),
              ],
              if (milestones.isNotEmpty) ...[
                _heading('Milestones'),
                const Text('Milestone credits expire after 90 days.'),
                for (final m in milestones)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          m['reachedAt'] == null
                              ? Icons.radio_button_unchecked
                              : Icons.check_circle_outline,
                          color: m['reachedAt'] == null
                              ? AppTheme.textSecondary
                              : AppTheme.green),
                      title: Text(
                          '${_money(m['amount'])} at ${_money(m['threshold'])} spent'),
                      subtitle: Text(m['reachedAt'] == null
                          ? 'Not reached'
                          : 'Reached ${_date(m['reachedAt'])} · Expires ${_date(m['expiresAt'])}')),
              ],
              _heading('Service credits ledger'),
              if (ledger.isEmpty) const Text('No credit activity to show yet.'),
              for (final row in ledger) _ledgerRow(row),
              _heading('How credits work'),
              const Text(
                  'Earn up to 8% back — plus a growing bonus at every band you reach, up to \$2,665 a year in service credits. '
                  'Tell us how much to apply when you book; there are no codes and nothing is applied without you asking. '
                  'Credits lower what you pay, so they also lower what this job earns and what it adds toward your band. '
                  'Credits are used soonest-expiring first, with milestones before band credits.'),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: widget.onBookTap,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white),
                  child: const Text('Browse services')),
            ]));
  }

  Widget _ledgerRow(Map<String, dynamic> row) {
    final rawType = '${row['type'] ?? ''}';
    final type = row['expired'] == true
        ? 'expired'
        : row['creditStatus'] == 'locked'
            ? 'locked'
            : switch (rawType) {
                'band_earn' => 'earned',
                'milestone_bonus' => 'milestone',
                'issue' => 'grant',
                'redeem' || 'redemption' => 'applied',
                _ => rawType,
              };
    const labels = {
      'earned': 'Earned',
      'locked': 'Receipt needed',
      'earns_nothing': 'Fully covered by credits · No credits earned',
      'applied': 'Applied',
      'milestone': 'Milestone',
      'grant': 'Grant',
      'expired': 'Expired'
    };
    final color = switch (type) {
      'earned' || 'milestone' || 'grant' => AppTheme.green,
      'locked' => AppTheme.amber,
      'expired' => AppTheme.textSecondary,
      _ => AppTheme.navy,
    };
    final linked =
        const ['earned', 'locked', 'earns_nothing', 'applied'].contains(type) &&
            int.tryParse('${row['workOrderId']}') != null;
    final basis = [
      if (_number(row['paidAmount']) != null)
        '${_money(row['paidAmount'])} paid',
      if (_number(row['rate']) != null) '${row['rate']}%'
    ].join(' · ');
    final amount = _number(row['amount']);
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        title: Text(labels[type] ?? 'Credit activity',
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (basis.isNotEmpty) Text(basis),
          Text(_date(row['occurredAt'] ?? row['createdAt']),
              style: TextStyle(
                  decoration:
                      type == 'expired' ? TextDecoration.lineThrough : null)),
          if (row['expiresAt'] != null && type != 'expired')
            Text('Expires ${_date(row['expiresAt'])}'),
          if (type == 'locked')
            const Text('Upload paid receipt',
                style: TextStyle(color: AppTheme.amber)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
              amount == null
                  ? '—'
                  : '${amount > 0 ? '+' : ''}${_money(amount)}',
              style: TextStyle(color: color)),
          if (linked) const Icon(Icons.chevron_right, size: 18)
        ]),
        onTap: linked && !_opening ? () => _open(row['workOrderId']) : null);
  }
}

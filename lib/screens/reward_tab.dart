import '../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/homeowner_service.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../utils/display_format.dart';
import '../widgets/app_notification.dart';
import '../widgets/offline_state.dart';
import 'work_orders/work_order_detail.dart';

class RewardTab extends StatefulWidget {
  final VoidCallback onBookTap;
  final bool active;
  final Future<Map<String, dynamic>> Function({bool forceRefresh})? loadRewards;
  const RewardTab({
    super.key,
    required this.onBookTap,
    this.active = true,
    this.loadRewards,
  });
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
    if (widget.active) _load(refresh: true);
  }

  @override
  void didUpdateWidget(covariant RewardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load(refresh: true);
  }

  @override
  void dispose() {
    HomeownerService.instance.syncVersion.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (widget.active) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await (widget.loadRewards ??
          HomeownerService.instance.fetchRewards)(forceRefresh: refresh);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Map<String, dynamic>? saved;
      if (_data == null && widget.loadRewards == null) {
        try {
          saved = await HomeownerService.instance.loadCachedRewards();
        } catch (_) {
          // The network failure is the useful error to report.
        }
      }
      if (mounted) {
        setState(() {
          _data ??= saved;
          _error = e;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _number(dynamic v) => readAmount(v);

  String? _text(dynamic v) {
    final text = v?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }

  List<Map<String, dynamic>> _rows(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  String _money(dynamic v) {
    final n = _number(v);
    return n == null ? '—' : formatUsd(n);
  }

  DateTime? _parse(dynamic v) => DateTime.tryParse('${v ?? ''}')?.toLocal();

  /// "May 18, 2028".
  String _date(dynamic v) {
    final d = v is DateTime ? v : _parse(v);
    return d == null ? '' : DateFormat('MMM d, y').format(d);
  }

  /// "Mon, Oct 5".
  String _day(dynamic v) {
    final d = _parse(v);
    return d == null ? '' : DateFormat('EEE, MMM d').format(d);
  }

  /// "WO-24144" from a work-order number; never the database id.
  String? _woLabel(Map<String, dynamic> row) {
    final raw = _text(row['woNumber'] ??
        row['wo_number'] ??
        row['workOrderNumber'] ??
        row['work_order_number']);
    if (raw == null) return null;
    final upper = raw.toUpperCase().replaceFirst('#', '');
    return upper.startsWith('WO-') ? upper : 'WO-$upper';
  }

  String? _service(Map<String, dynamic> row) => _text(row['serviceName'] ??
      row['service_name'] ??
      row['service'] ??
      row['serviceCategory']);

  String? _pro(Map<String, dynamic> row) => _text(row['proName'] ??
      row['pro_name'] ??
      row['businessName'] ??
      row['business_name']);

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

  Widget _heading(String text, {String? meta, double bottom = TwSpace.s12}) {
    final title = Text(text, style: TwType.h2());
    return Padding(
      padding: EdgeInsets.only(top: TwSpace.s28, bottom: bottom),
      child: meta != null && TwLayout.stackRows(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: TwSpace.s4),
                Text(meta, style: TwType.caption()),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: title),
                if (meta != null) Text(meta, style: TwType.caption()),
              ],
            ),
    );
  }

  static TextStyle get _bodyStyle => TwType.bodySm();
  static TextStyle get _metaStyle => TwType.caption();

  Widget _unavailable(String message) => Padding(
        padding: const EdgeInsets.only(top: TwSpace.s12),
        child: Text(message, style: TwType.caption()),
      );

  String _howCreditsWork(
      List<Map<String, dynamic>> bands, List<Map<String, dynamic>> milestones) {
    double bandCredits = 0;
    double milestoneCredits = 0;
    double? topRate;
    double? previousCeiling;
    var completeProgram = bands.isNotEmpty && milestones.isNotEmpty;
    for (final band in bands) {
      final floor = _number(band['floor']);
      final ceiling = _number(band['ceiling']);
      final rate = _number(band['rate']);
      if (floor == null ||
          ceiling == null ||
          rate == null ||
          ceiling <= floor ||
          (previousCeiling == null ? floor != 0 : floor != previousCeiling)) {
        completeProgram = false;
        break;
      }
      final percent = _ratePercent(rate)!;
      bandCredits += (ceiling - floor) * percent / 100;
      topRate = topRate == null || percent > topRate ? percent : topRate;
      previousCeiling = ceiling;
    }
    for (final milestone in milestones) {
      final amount = _number(milestone['amount']);
      if (amount == null) {
        completeProgram = false;
        break;
      }
      milestoneCredits += amount;
    }
    if (milestones.isEmpty ||
        _number(milestones.last['threshold']) != previousCeiling) {
      completeProgram = false;
    }
    final overview = completeProgram && topRate != null
        ? 'Earn up to ${_formatRatePercent(topRate)} back — plus a growing bonus at every band you reach, up to ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(bandCredits + milestoneCredits)} a year in service credits. '
        : 'Earn service credits on qualifying customer-paid spend and at milestones. ';
    return '$overview'
        'There are no codes, and nothing is applied without you asking. '
        'You choose how much credit to apply when you book: up to the full price on an upfront-price job, the diagnostic fee on a job where you approve the cap (and more when you approve it), and nothing on a free estimate visit until you accept the estimate. '
        'Credit left over after the final invoice, or on a cancelled job, goes back to your balance. '
        'Credits lower what you pay, so they also lower what this job earns and what it adds toward your band. '
        'Credits are used soonest-expiring first, with milestones before band credits.';
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _loading) {
      return const SkeletonPage(layout: SkeletonLayout.rewards);
    }
    if (_data == null && _error != null) {
      return OfflineState(onRetry: () => _load(refresh: true));
    }
    final d = _data ?? {};
    final program = d['program'] is Map
        ? Map<String, dynamic>.from(d['program'] as Map)
        : const <String, dynamic>{};
    final bands = _rows(d['bands'] ?? d['earningBands'] ?? program['bands'])
      ..sort((a, b) =>
          (_number(a['floor']) ?? 0).compareTo(_number(b['floor']) ?? 0));
    final milestones = _rows(d['milestones'] ?? program['milestones']);
    final receipts = _rows(d['pendingReceipts']).where((r) {
      final paid =
          _number(r['customerPaidAmount'] ?? r['paidAmount'] ?? r['amount']);
      return paid == null || paid > 0;
    }).toList();
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
    final milestoneExpiryDays =
        _number(d['milestoneExpiryDays'] ?? program['milestoneExpiryDays']);
    final currentBand = _currentBandIndex(bands, spend, d);

    return RefreshIndicator(
        color: AppTheme.navy,
        onRefresh: () => _load(refresh: true),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              TwPage(
                top: 14,
                bottom: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: TwSpace.s8),
                      child: Semantics(
                        header: true,
                        child: Text('Rewards', style: TwType.h1(context)),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                          padding: EdgeInsets.only(bottom: TwSpace.s16),
                          child: Text(
                              'Could not update credits. Showing saved information.',
                              style: TwType.bodySm(color: AppTheme.amber))),
                    _balanceCard(d),
                    if (receipts.isNotEmpty) ...[
                      _heading('Upload your paid receipt'),
                      Text(
                          'Your customer-paid portion earns credits once the paid receipt is uploaded.',
                          style: _bodyStyle),
                      for (final r in receipts) ...[
                        const SizedBox(height: 12),
                        _receiptRow(r),
                      ],
                    ],
                    if (spend != null ||
                        earned != null ||
                        d['programPeriodStart'] != null ||
                        d['programPeriodEnd'] != null ||
                        d['periodStart'] != null ||
                        d['periodEnd'] != null)
                      _yearSection(d, bands, spend, earned),
                    _heading('Earning bands', bottom: 4),
                    Text(
                        'Each dollar earns at its band’s rate. Earlier earnings never change.',
                        style: _bodyStyle),
                    if (bands.isEmpty)
                      _unavailable('Earning bands are unavailable right now.'),
                    for (var i = 0; i < bands.length; i++)
                      _bandRow(bands[i], spend,
                          isCurrent: i == currentBand,
                          last: i == bands.length - 1),
                    _heading('Milestones', bottom: 4),
                    Text(
                      milestoneExpiryDays == null
                          ? 'Each milestone credit has its own expiry date.'
                          : 'Milestone credits expire after ${milestoneExpiryDays.toStringAsFixed(0)} days.',
                      style: _bodyStyle,
                    ),
                    if (milestones.isEmpty)
                      _unavailable('Milestones are unavailable right now.'),
                    for (var i = 0; i < milestones.length; i++)
                      _milestoneRow(milestones[i],
                          last: i == milestones.length - 1),
                    _heading('Service credits ledger', bottom: 0),
                    if (ledger.isEmpty)
                      Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('No credit activity to show yet.',
                              style: _bodyStyle)),
                    for (var i = 0; i < ledger.length; i++)
                      _ledgerRow(ledger[i], last: i == ledger.length - 1),
                    _heading('How credits work'),
                    Text(_howCreditsWork(bands, milestones), style: _bodyStyle),
                    const SizedBox(height: TwSpace.s28),
                    TwPrimaryButton(
                      label: 'Browse services',
                      onPressed: widget.onBookTap,
                    ),
                  ],
                ),
              ),
            ]));
  }

  Widget _balanceCard(Map<String, dynamic> d) {
    // The earliest-expiring credit: the backend's own pick, else the first
    // expiring credit returned by the rewards API.
    Map<String, dynamic>? earliest = d['earliestExpiry'] is Map
        ? Map<String, dynamic>.from(d['earliestExpiry'] as Map)
        : null;
    if (earliest == null) {
      final soon = _rows(d['expiringCredits'] ?? d['expiringSoon'])
        ..sort((a, b) =>
            '${a['expiresAt'] ?? ''}'.compareTo('${b['expiresAt'] ?? ''}'));
      earliest = soon.isEmpty ? null : soon.first;
    }
    final expiryLine = earliest == null ||
            _number(earliest['amount']) == null ||
            _date(earliest['expiresAt']).isEmpty
        ? null
        : 'Earliest expiry: ${_money(earliest['amount'])} on ${_date(earliest['expiresAt'])}';
    final reserved = _number(d['reservedBalance']);
    final locked = _number(d['lockedBalance']);
    final ledgerBalance = _number(d['ledgerBalance']);
    final showBreakdown =
        reserved != null || locked != null || ledgerBalance != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          TwSpace.s20, TwSpace.s20, TwSpace.s20, TwSpace.s12),
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
              Expanded(
                child: Text('Available service credits',
                    style: TwType.title()),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppTheme.purpleTint, shape: BoxShape.circle),
                child: const Icon(Icons.redeem_outlined,
                    size: 18, color: AppTheme.purple),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              _money(d['availableBalance'] ??
                  d['balance'] ??
                  d['availableCredits']),
              style: TwType.display(context).copyWith(color: AppTheme.purple)),
          const SizedBox(height: 6),
          Text('Choose how much credit to apply when you book',
              style: TwType.bodySm()),
          if (showBreakdown) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (ledgerBalance != null)
                  _balanceMetric('Ledger total', ledgerBalance),
                if (reserved != null)
                  _balanceMetric('Reserved', reserved),
                if (locked != null)
                  _balanceMetric('Locked', locked),
              ],
            ),
          ],
          if (expiryLine != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 12),
            Text(expiryLine, style: TwType.meta()),
          ],
        ],
      ),
    );
  }

  Widget _balanceMetric(String label, double amount) => SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TwType.meta()),
            const SizedBox(height: 2),
            Text(formatUsd(amount), style: TwType.value()),
          ],
        ),
      );

  Widget _receiptRow(Map<String, dynamic> r) {
    final title = [_service(r) ?? 'Completed service', _woLabel(r)]
        .whereType<String>()
        .join(' · ');
    final completed = _day(r['completedAt'] ?? r['completed_at']);
    final paid =
        _number(r['customerPaidAmount'] ?? r['paidAmount'] ?? r['amount']);
    final detail = [
      if (paid != null) '${_money(paid)} paid',
      _pro(r),
      if (completed.isNotEmpty) 'Completed $completed',
    ].whereType<String>().join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(
          TwSpace.s16, TwSpace.s16, TwSpace.s16, TwSpace.s8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppTheme.amberTint, shape: BoxShape.circle),
            child: const Icon(Icons.file_upload_outlined,
                size: 18, color: AppTheme.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TwType.title()),
                const SizedBox(height: 2),
                Text(detail, style: TwType.bodySm()),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppTheme.amber, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Receipt needed',
                        style: TwType.caption(color: AppTheme.amber)
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                TextButton(
                  onPressed: _opening ? null : () => _open(r['workOrderId']),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    alignment: Alignment.centerLeft,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Upload receipt', style: TwType.link()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The band whose range holds [spend], else the one at the current rate.
  int _currentBandIndex(
      List<Map<String, dynamic>> bands, double? spend, Map<String, dynamic> d) {
    if (spend != null) {
      for (var i = 0; i < bands.length; i++) {
        final floor = _number(bands[i]['floor']) ?? 0;
        final ceiling = _number(bands[i]['ceiling']);
        if (spend >= floor && (ceiling == null || spend < ceiling)) return i;
      }
    }
    final rate = _ratePercent(
        d['currentMarginalRate'] ?? d['rate'] ?? d['currentBandRate']);
    return bands.indexWhere((b) => _ratePercent(b['rate']) == rate);
  }

  double? _ratePercent(dynamic v) {
    final n = _number(v);
    if (n == null) return null;
    return n.abs() <= 1 ? n * 100 : n;
  }

  String _formatRatePercent(double n) =>
      '${n % 1 == 0 ? n.toStringAsFixed(0) : n.toString()}%';

  String _rate(dynamic v) {
    final n = _ratePercent(v);
    return n == null ? '' : _formatRatePercent(n);
  }

  Widget _yearSection(Map<String, dynamic> d, List<Map<String, dynamic>> bands,
      double? spend, double? earned) {
    // Anniversary year (decisions §7). `resetDate` is the next anniversary;
    // `programPeriodEnd` is the last day of this year.
    final periodEnd = _parse(
        d['periodEnd'] ?? d['programPeriodEnd'] ?? d['programPeriodEnds']);
    final resets =
        _parse(d['resetDate'] ?? d['nextAnniversary']) ?? periodEnd;
    final yearStart = _parse(
        d['periodStart'] ?? d['programPeriodStart'] ?? d['anniversaryDate']);
    // The API's period end is exclusive and is also the reset date.
    final yearEnd = periodEnd?.subtract(const Duration(days: 1)) ??
        resets?.subtract(const Duration(days: 1));
    final current = _currentBandIndex(bands, spend, d);
    final next =
        current >= 0 && current + 1 < bands.length ? bands[current + 1] : null;
    final nextFloor = next == null ? null : _number(next['floor']);
    final progressTarget = nextFloor ??
        (current >= 0
            ? _number(bands[current]['ceiling'])
            : _number(d['annualQualifyingSpendCap']));
    final rate = current >= 0
        ? _rate(bands[current]['rate'])
        : _rate(
            d['currentMarginalRate'] ?? d['rate'] ?? d['currentBandRate']);
    final tier = _text(d['tier']);
    final bandLine = rate.isEmpty
        ? tier
        : tier != null
            ? '$tier · $rate on new spend'
            : current >= 0
                ? 'Band ${current + 1} · $rate on new spend'
                : '$rate on new spend';
    final toNext = spend != null && nextFloor != null && nextFloor > spend
        ? '${formatUsd(nextFloor - spend)} to the ${_rate(next!['rate'])} band'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Your rewards year',
            meta: resets == null ? null : 'Resets ${_date(resets)}'),
        if (spend == null)
          _unavailable(
              'Counted spend and band progress are unavailable right now.'),
        if (spend != null)
          Container(
            padding: const EdgeInsets.fromLTRB(
                TwSpace.s16, TwSpace.s16, TwSpace.s16, TwSpace.s12),
            decoration: BoxDecoration(
              color: AppTheme.subtle,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TwLayout.stackRows(context)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatUsd(spend), style: TwType.h1Sm()),
                          Text('counted this year', style: TwType.meta()),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(formatUsd(spend), style: TwType.h1Sm()),
                          ),
                          Text('counted this year', style: TwType.meta()),
                        ],
                      ),
                if (progressTarget != null && progressTarget > 0) ...[
                  const SizedBox(height: TwSpace.s4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (spend / progressTarget).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      color: AppTheme.purple,
                      backgroundColor: AppTheme.cardBorder,
                      semanticsLabel: next == null
                          ? 'Counted spend toward the annual band cap'
                          : 'Counted spend toward the ${_rate(next['rate'])} band',
                    ),
                  ),
                ],
                if (progressTarget == null)
                  _unavailable('Band progress is unavailable right now.'),
                if (bandLine != null || toNext != null) ...[
                  const SizedBox(height: TwSpace.s8),
                  TwLayout.stackRows(context)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bandLine != null)
                              Text(bandLine, style: TwType.meta()),
                            if (toNext != null)
                              Text(toNext, style: TwType.label()),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(bandLine ?? '', style: TwType.meta()),
                            ),
                            if (toNext != null)
                              Flexible(
                                child: Text(toNext,
                                    textAlign: TextAlign.right,
                                    style: TwType.label()),
                              ),
                          ],
                        ),
                ],
              ],
            ),
          ),
        if (earned != null)
          _factRow('Earned since your year started', _money(earned),
              valueColor: AppTheme.purple, divider: yearStart != null),
        if (yearStart != null && yearEnd != null)
          _factRow('Your year', '${_date(yearStart)} – ${_date(yearEnd)}',
              divider: false),
        Text(
          resets == null
              ? 'Your bands and milestones reset on your anniversary. Credits you’ve already earned keep their own expiry dates.'
              : 'Your bands and milestones reset on your anniversary, ${DateFormat('MMM d').format(resets)}. Credits you’ve already earned keep their own expiry dates.',
          style: TwType.caption(),
        ),
      ],
    );
  }

  Widget _factRow(String label, String value,
      {Color valueColor = AppTheme.navy, bool divider = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppTheme.cardBorder))
            : null,
      ),
      child: TwLayout.stackRows(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TwType.bodySm()),
                const SizedBox(height: TwSpace.s4),
                Text(value, style: TwType.value(color: valueColor)),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(label, style: TwType.bodySm())),
                Text(value, style: TwType.value(color: valueColor)),
              ],
            ),
    );
  }

  Widget _bandRow(Map<String, dynamic> b, double? spend,
      {required bool isCurrent, required bool last}) {
    final floor = _number(b['floor']) ?? 0;
    final earnedInBand = _number(b['earnedInBand']);
    final sub = earnedInBand != null
        ? '${formatUsd(earnedInBand)} earned'
        : spend != null && spend < floor
            ? 'Not reached'
            : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: TwSpace.s12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(_rate(b['rate']),
                style: AppTheme.headingStyle.copyWith(
                    fontSize: 20,
                    color: isCurrent ? AppTheme.purple : AppTheme.navy)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_money(b['floor'])} – ${_money(b['ceiling'])}',
                    style: TwType.body(color: AppTheme.navy)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: _metaStyle),
                ],
              ],
            ),
          ),
          if (isCurrent)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.purple, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Your band',
                    style: TwType.caption(color: AppTheme.purple)
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _milestoneRow(Map<String, dynamic> m, {required bool last}) {
    final reached = m['reachedAt'] != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: TwSpace.s8),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Icon(
              reached
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 22,
              color: reached ? AppTheme.purple : AppTheme.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: _money(m['amount']), style: TwType.label()),
                    TextSpan(text: ' at ${_money(m['threshold'])} counted'),
                  ]),
                  style: TwType.body(color: AppTheme.navy),
                ),
                const SizedBox(height: 2),
                Text(
                    reached
                        ? 'Reached ${_date(m['reachedAt'])} · Expires ${_date(m['expiresAt'])}'
                        : 'Not reached',
                    style: _metaStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerRow(Map<String, dynamic> row, {required bool last}) {
    final rawType = '${row['type'] ?? ''}';
    final creditStatus =
        '${row['creditStatus'] ?? ''}'.trim().toLowerCase();
    final type = row['expired'] == true || creditStatus == 'expired'
        ? 'expired'
        : switch ((rawType, creditStatus)) {
            ('service_credit', 'locked') => 'locked',
            ('service_credit', 'reserved') => 'reserved',
            ('service_credit', _) => 'earned',
            ('band_earn', _) => 'earned',
            ('milestone_bonus', _) => 'milestone',
            ('issue', _) => 'grant',
            ('redeem', _) || ('redemption', _) => 'applied',
            ('returned', _) || ('credit_returned', _) => 'returned',
            _ => rawType,
          };
    const labels = {
      'earned': 'Earned',
      'earns_nothing': 'Fully covered by credits · No credits earned',
      'applied': 'Applied',
      'returned': 'Credit returned',
      'milestone': 'Milestone',
      'grant': 'Grant',
      'locked': 'Locked',
      'reserved': 'Reserved',
      'expired': 'Expired'
    };
    final linked =
        const [
          'earned',
          'earns_nothing',
          'applied',
          'returned',
          'locked',
          'reserved'
        ]
                .contains(type) &&
            int.tryParse('${row['workOrderId']}') != null;
    final when = _date(row['occurredAt'] ?? row['createdAt']);
    // Line 1 names the job: "WO-24144 · HVAC tune-up · Hutchins Plumbing Co."
    final job = [_woLabel(row), _service(row), _pro(row)]
        .whereType<String>()
        .join(' · ');
    final note = _text(row['note'] ?? row['description'] ?? row['reason']);
    final basis = [
      if (type == 'applied') 'Applied to this job',
      if (type == 'returned') 'Back in your balance',
      if (_number(row['customerPaidAmount'] ?? row['paidAmount']) != null)
        '${_money(row['customerPaidAmount'] ?? row['paidAmount'])} paid',
      if (_number(row['rateSnapshot'] ?? row['rate']) != null)
        _rate(row['rateSnapshot'] ?? row['rate']),
      if (job.isEmpty && note != null) note,
      if (when.isNotEmpty) when,
    ].join(' · ');
    final amount = _number(row['amount']);
    final credit =
        const ['earned', 'milestone', 'grant', 'returned'].contains(type);
    final amountText = amount == null
        ? '—'
        : type == 'applied' || amount < 0
            ? '−${formatUsd(amount.abs())}'
            : '+${formatUsd(amount)}';
    final amountColor = type == 'expired'
        ? AppTheme.textSecondary
        : type == 'locked' || type == 'reserved'
            ? AppTheme.amber
            : credit
                ? AppTheme.purple
                : AppTheme.navy;
    return InkWell(
      onTap: linked && !_opening ? () => _open(row['workOrderId']) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TwSpace.s16),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labels[type] ?? 'Credit activity',
                      style: TwType.title()),
                  if (job.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(job, style: TwType.meta()),
                  ],
                  if (basis.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(basis,
                        style: TwType.meta().copyWith(
                            decoration: type == 'expired'
                                ? TextDecoration.lineThrough
                                : null)),
                  ],
                  if (row['expiresAt'] != null && type != 'expired') ...[
                    const SizedBox(height: 2),
                    Text('Expires ${_date(row['expiresAt'])}',
                        style: TwType.meta()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(amountText,
                style: AppTheme.headingStyle.copyWith(
                    color: amountColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            SizedBox(
              width: 24,
              child: linked
                  ? const Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.textTertiary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui/tw.dart';
import '../utils/credit_rules.dart';
import '../utils/display_format.dart';

/// Optional credit selection and payment summary for cap or estimate approval.
class CreditApplyCard extends StatefulWidget {
  const CreditApplyCard({
    super.key,
    required this.total,
    required this.balance,
    required this.estimate,
    required this.onChanged,
    this.enabled = true,
  });

  final double total;
  final double? balance;
  final bool estimate;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  State<CreditApplyCard> createState() => _CreditApplyCardState();
}

class _CreditApplyCardState extends State<CreditApplyCard> {
  final _controller = TextEditingController();
  bool _on = false;

  double get _limit => CreditRules.approvalLimit(
      total: widget.total, balance: widget.balance ?? 0);

  double get _applied =>
      _on ? CreditRules.clampTyped(_controller.text, _limit) : 0;

  @override
  void didUpdateWidget(covariant CreditApplyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.total != widget.total ||
        oldWidget.balance != widget.balance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(_applied);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(bool value) {
    setState(() {
      _on = value;
      if (value && _controller.text.trim().isEmpty) {
        _controller.text = _limit.toStringAsFixed(2);
      }
    });
    widget.onChanged(_applied);
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.balance;
    final applied = _applied;
    final pay = widget.total - applied < 0 ? 0.0 : widget.total - applied;
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (balance != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.estimate
                            ? 'Apply credit'
                            : 'Apply credit to this repair',
                        style: TwType.title(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Available: ${formatUsd(balance)}',
                        style: TwType.label(color: AppTheme.purple),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _on,
                  onChanged: !widget.enabled || _limit <= 0 ? null : _toggle,
                ),
              ],
            ),
            if (_on) ...[
              const SizedBox(height: TwSpace.s12),
              const TwFieldLabel('Amount to apply'),
              TextField(
                controller: _controller,
                enabled: widget.enabled,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  setState(() {});
                  widget.onChanged(_applied);
                },
                style: TwType.body(color: AppTheme.ink),
                decoration: TwInputs.decoration(hint: '0.00')
                    .copyWith(prefixText: '\$ '),
              ),
              const SizedBox(height: 6),
              Text(
                CreditRules.approvalHelper(
                  total: widget.total,
                  balance: balance,
                  estimate: widget.estimate,
                ),
                style: TwType.caption(),
              ),
              if (CreditRules.overLimit(_controller.text, _limit)) ...[
                const SizedBox(height: 2),
                Text(
                  'We’ll apply ${formatUsd(applied)}.',
                  style: TwType.caption(color: AppTheme.purple),
                ),
              ],
            ],
            const Divider(height: 28, color: AppTheme.cardBorder),
          ],
          _row(widget.estimate ? 'Estimate' : 'Cap', formatUsd(widget.total)),
          if (applied > 0) ...[
            const SizedBox(height: TwSpace.s8),
            _row('Credit applied', '−${formatUsd(applied)}',
                color: AppTheme.purple),
          ],
          const SizedBox(height: TwSpace.s8),
          _row('You pay the pro up to', formatUsd(pay), strong: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? color, bool strong = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: strong
                ? TwType.title()
                : TwType.bodySm(color: color ?? AppTheme.body),
          ),
        ),
        const SizedBox(width: TwSpace.s12),
        Text(
          value,
          style: strong
              ? TwType.title()
              : TwType.label(color: color ?? AppTheme.ink),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';

/// The pro reported that nobody was home; the homeowner tells TradeWorks what
/// happened (E05). Up to 2,000 characters, read by support.
class NoShowReplyScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const NoShowReplyScreen({super.key, required this.job});

  @override
  State<NoShowReplyScreen> createState() => _NoShowReplyScreenState();
}

class _NoShowReplyScreenState extends State<NoShowReplyScreen> {
  static const int _maxLength = 2000;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_onChanged);
    _text.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// "1,250" — the counter matches the limit's own formatting.
  String _count(int n) =>
      n < 1000 ? '$n' : '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';

  Future<void> _send() async {
    final value = _text.text.trim();
    final id = int.tryParse('${widget.job['workOrderId'] ?? widget.job['id']}');
    if (id == null || value.isEmpty || value.length > _maxLength) {
      AppNotification.showInfo(
          context, 'Write a reply of up to 2,000 characters.');
      return;
    }
    setState(() => _sending = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
          workOrderId: id, action: 'no_show_reply', extra: {'text': value});
      if (!mounted) return;
      AppNotification.showSuccess(context, 'Your reply was sent for review.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppTheme.navy,
          title: Text(
            'Tell us what happened',
            style: AppTheme.headingStyle
                .copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppTheme.cardBorder),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const Text(
                'Your pro reported that nobody was home for this visit. If '
                'that’s not right, let us know — we read every reply.',
                style: TextStyle(
                  color: AppTheme.body,
                  fontSize: 16,
                  height: 25 / 16,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your reply',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                minLines: 7,
                maxLines: 12,
                maxLength: _maxLength,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What happened?',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_count(_text.text.length)} / 2,000',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.cardBorder)),
            boxShadow: AppTheme.floatShadow,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
                child: Text(_sending ? 'Sending…' : 'Send reply'),
              ),
            ),
          ),
        ),
      );
}

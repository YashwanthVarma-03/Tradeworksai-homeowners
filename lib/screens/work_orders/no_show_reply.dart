import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';

class NoShowReplyScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const NoShowReplyScreen({super.key, required this.job});

  @override
  State<NoShowReplyScreen> createState() => _NoShowReplyScreenState();
}

class _NoShowReplyScreenState extends State<NoShowReplyScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    final id = int.tryParse('${widget.job['workOrderId'] ?? widget.job['id']}');
    if (id == null || value.isEmpty || value.length > 2000) {
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
        appBar: AppBar(title: const Text('Tell us what happened')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${widget.job['proName'] ?? 'Your pro'} reported that nobody was home for this visit. If that\'s not right, let us know — we read every reply.',
                style: const TextStyle(
                    color: AppTheme.textSecondary, height: 1.45)),
            const SizedBox(height: 20),
            Expanded(
                child: TextField(
                    controller: _text,
                    minLines: 5,
                    maxLines: null,
                    maxLength: 2000,
                    enabled: !_sending,
                    decoration:
                        const InputDecoration(hintText: 'What happened?'))),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white),
                  child: Text(_sending ? 'Sending…' : 'Send reply'),
                )),
          ]),
        ),
      );
}

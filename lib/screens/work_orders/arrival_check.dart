import 'package:flutter/material.dart';
import '../../services/homeowner_service.dart';
import '../../services/service_location.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';
import '../dashboard_shell.dart';

Future<bool> openArrivalCheck(
        BuildContext context, Map<String, dynamic> job) async =>
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ArrivalCheckScreen(job: job))) ??
    false;

String _name(Map<String, dynamic> job) {
  final pro = job['pro'];
  final value =
      pro is Map ? pro['businessName'] ?? pro['business_name'] : job['proName'];
  return value?.toString().trim().isNotEmpty == true
      ? value.toString()
      : 'your pro';
}

int _id(Map<String, dynamic> job) =>
    int.tryParse('${job['workOrderId'] ?? job['id']}') ?? 0;

class ArrivalCheckScreen extends StatefulWidget {
  const ArrivalCheckScreen({super.key, required this.job});
  final Map<String, dynamic> job;
  @override
  State<ArrivalCheckScreen> createState() => _ArrivalCheckScreenState();
}

class _ArrivalCheckScreenState extends State<ArrivalCheckScreen> {
  bool _saving = false;
  Future<void> _answer(String action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await HomeownerService.instance
          .performWorkOrderAction(workOrderId: _id(widget.job), action: action);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppNotification.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => TransactionGuard(
      isProcessing: _saving,
      child: Scaffold(
          appBar: AppBar(title: const Text('Arrival check')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Did ${_name(widget.job)} arrive?',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text(
                'Your booked window has ended and the job is not marked complete. Let us know what happened.'),
            const SizedBox(height: 24),
            OutlinedButton(
                onPressed: _saving ? null : () => _answer('confirm_arrival'),
                child: const Text('Yes, they came')),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed:
                    _saving ? null : () => _answer('arrival_rescheduled'),
                child: const Text('We rescheduled')),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final reported = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    NoShowConfirmScreen(job: widget.job)));
                        if (reported == true && context.mounted)
                          Navigator.pop(context, true);
                      },
                child: const Text("No, they didn't")),
            const SizedBox(height: 24),
            const Text(
                'You can close this and answer later. An unanswered check stays open for review; it does not report anyone.'),
            if (_saving)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
          ])));
}

class NoShowConfirmScreen extends StatefulWidget {
  const NoShowConfirmScreen({super.key, required this.job});
  final Map<String, dynamic> job;
  @override
  State<NoShowConfirmScreen> createState() => _NoShowConfirmScreenState();
}

class _NoShowConfirmScreenState extends State<NoShowConfirmScreen> {
  final _note = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _report() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
          workOrderId: _id(widget.job),
          action: 'pro_no_show',
          extra: {if (_note.text.trim().isNotEmpty) 'note': _note.text.trim()});
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => RecoveryScreen(job: widget.job)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppNotification.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => TransactionGuard(
      isProcessing: _saving,
      child: Scaffold(
          appBar: AppBar(title: const Text('Report a no-show')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Text("Report that ${_name(widget.job)} didn't arrive?",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text(
                'TradeWorks reviews the booking. ${_name(widget.job)} gets a chance to tell us their side. '
                'Nothing is published. This never appears on their profile and never becomes a score. '
                'You won’t be charged for a visit that didn’t happen.'),
            const SizedBox(height: 24),
            TextField(
                controller: _note,
                enabled: !_saving,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                    labelText: 'Anything you want to add? (optional)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _saving ? null : _report,
                child: Text(_saving ? 'Reporting…' : 'Report no-show')),
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Go back')),
          ])));
}

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key, required this.job});
  final Map<String, dynamic> job;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reported')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Thanks — we’ve got it',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('We’ll review your report and follow up.'),
        const SizedBox(height: 28),
        Text(
            'Still need ${job['serviceCategory'] ?? job['serviceName'] ?? 'this service'} done?'),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: () async {
              final address = job['address'];
              final zip = address is Map
                  ? address['zip']
                  : job['zip'] ?? job['address_zip'];
              if (zip != null)
                await ServiceLocation.save(zip: '$zip', locationName: '');
              if (!context.mounted) return;
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BrowseScreen(
                          initialCategory:
                              '${job['serviceCategory'] ?? job['serviceName'] ?? 'All'}',
                          showAppBar: true)));
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Find another pro')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Not now')),
      ]));
}

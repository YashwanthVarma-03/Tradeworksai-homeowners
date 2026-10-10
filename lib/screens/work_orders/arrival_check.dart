import 'package:flutter/material.dart';
import '../../services/homeowner_service.dart';
import '../../services/service_location.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';
import '../dashboard_shell.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../ui/tw.dart';
import '../../utils/display_format.dart';
import '../../utils/work_order_labels.dart';
import '../../utils/work_order_status.dart';
import 'reschedule_work_order.dart' show jobUrgencyLevel;

Future<bool> openArrivalCheck(
        BuildContext context, Map<String, dynamic> job) async =>
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => NoShowConfirmScreen(job: job))) ??
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

  /// "1,250" — the counter matches the limit's own formatting (E04).
  String _count(int n) => NumberFormat.decimalPattern('en_US').format(n);

  Widget _nextRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: AppTheme.navy),
          ),
          const SizedBox(width: TwSpace.s12),
          Expanded(
            child: Text(text, style: TwType.bodySm(color: AppTheme.navy)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final pro = _name(job);
    final title = [jobServiceName(job), workOrderLabel(job)]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    final start = jobVisitStart(job)?.toLocal();
    final end = jobVisitEnd(job)?.toLocal();
    final proLine = [
      jobProName(job, ''),
      if (start != null)
        '${DateFormat('EEE, MMM d').format(start)}, ${formatWindow(start, end)}',
    ].where((part) => part.isNotEmpty).join(' · ');
    final notStarted =
        WorkOrderStatus.fromJob(job).state == WorkOrderState.booked;
    return TransactionGuard(
      isProcessing: _saving,
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        appBar: TwAppBar(title: 'Report a no-show'),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: TwPage(
                  top: TwSpace.s20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TwCard(
                        child: Row(
                          children: [
                            TwAvatar(name: jobProName(job), size: 48),
                            const SizedBox(width: TwSpace.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title.isNotEmpty)
                                    Text(title, style: TwType.title()),
                                  if (proLine.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(proLine, style: TwType.meta()),
                                  ],
                                  const SizedBox(height: TwSpace.s4),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: TwSpace.s4,
                                    children: [
                                      if (notStarted)
                                        Text(
                                          'Not started by your pro',
                                          style: TwType.caption(
                                                  color: AppTheme.body)
                                              .copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                      Text(
                                        jobUrgencyLevel(job),
                                        style: TwType.caption().copyWith(
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TwSpace.s28),
                      Text(
                        "Report that $pro didn't arrive?",
                        style: TwType.h1(context),
                      ),
                      const SizedBox(height: TwSpace.s28),
                      Text('What happens next', style: TwType.h2()),
                      const SizedBox(height: TwSpace.s4),
                      _nextRow(Icons.description_outlined,
                          'TradeWorks reviews the booking.'),
                      _nextRow(Icons.chat_bubble_outline_rounded,
                          '$pro gets a chance to tell us their side.'),
                      _nextRow(Icons.shield_outlined,
                          'Nothing is published. This never appears on their profile and never becomes a score.'),
                      _nextRow(Icons.credit_card_outlined,
                          'You won’t be charged for a visit that didn’t happen.'),
                      const SizedBox(height: TwSpace.s28),
                      const TwFieldLabel('Anything you want to add? (optional)'),
                      TextField(
                        controller: _note,
                        enabled: !_saving,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        style: TwType.body(color: AppTheme.navy),
                        decoration: TwInputs.decoration(
                          hint: 'What happened?',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: TwSpace.s8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_count(_note.text.length)} / 2,000',
                          style: TwType.caption(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TwStickyBar(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TwPrimaryButton(
                      label: 'Report no-show',
                      onPressed: _saving ? null : _report,
                      loading: _saving,
                    ),
                    const SizedBox(height: TwSpace.s4),
                    Center(
                      child: TwTextAction(
                        label: 'Go back',
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

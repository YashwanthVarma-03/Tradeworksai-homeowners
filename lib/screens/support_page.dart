import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../ui/tw.dart';
import '../utils/work_order_labels.dart';
import '../widgets/app_notification.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  int _viewIndex = 0; // 0: FAQ, 1: Contact Form, 2: Success
  String _searchQuery = '';

  // Contact form (F09): only real values — the homeowner's own work orders
  // and account email. Nothing is shown as sent unless the server took it.
  static const List<String> _topics = [
    'Booking help',
    'Billing',
    'Service credits',
    'Reschedule/Cancel',
    'Other',
  ];
  String _topic = _topics.first;
  String? _relatedId;
  List<({String id, String label})> _workOrders = const [];
  final TextEditingController _message = TextEditingController();
  bool _sending = false;
  String? _reference;

  @override
  void initState() {
    super.initState();
    _loadWorkOrders();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// "WO-24152 — AC repair" for each of the homeowner's work orders.
  Future<void> _loadWorkOrders() async {
    try {
      final data = await HomeownerService.instance.fetchWorkOrders();
      final tabs = data['tabs'];
      final seen = <String>{};
      final rows = <({String id, String label})>[];
      if (tabs is Map) {
        for (final list in tabs.values.whereType<List>()) {
          for (final raw in list.whereType<Map>()) {
            final job = Map<String, dynamic>.from(raw);
            final id = workOrderDbId(job);
            final wo = workOrderLabel(job);
            if (id == null || wo.isEmpty || !seen.add('$id')) continue;
            rows.add((id: '$id', label: '$wo — ${jobServiceName(job)}'));
          }
        }
      }
      if (mounted) setState(() => _workOrders = rows);
    } catch (_) {
      // Signed out or offline: the form still works without a related job.
    }
  }

  String? get _relatedLabel {
    for (final row in _workOrders) {
      if (row.id == _relatedId) return row.label;
    }
    return null;
  }

  /// What "Message sent" lists — only what was actually sent.
  List<(String, String)> get _summaryRows => [
        if (_reference != null) ('Reference', _reference!),
        ('Topic', _topic),
        if (_relatedLabel != null) ('Related', _relatedLabel!),
      ];

  Future<void> _sendRequest() async {
    final message = _message.text.trim();
    if (_sending) return;
    if (message.isEmpty) {
      AppNotification.showInfo(context, 'Tell us what’s going on first.');
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await HomeownerService.instance.submitSupportRequest(
        topic: _topic,
        message: message,
        workOrderId: _relatedId == null ? null : int.tryParse(_relatedId!),
      );
      if (!mounted) return;
      if (result == null) {
        // The support inbox isn't live in the app yet: hand the same
        // request to the phone's email app rather than pretend it was sent.
        final subject = [_topic, _relatedLabel].whereType<String>().join(' · ');
        await _openSupportLink(
          'mailto:support@tradeworksai.com'
              '?subject=${Uri.encodeComponent(subject)}'
              '&body=${Uri.encodeComponent(message)}',
          'write an email',
        );
        return;
      }
      final reference = '${result['reference'] ?? result['id'] ?? ''}'.trim();
      setState(() {
        _reference =
            reference.isEmpty || reference == 'null' ? null : reference;
        _viewIndex = 2;
      });
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          e,
          fallback:
              'We couldn’t send your request. Email support@tradeworksai.com instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  final List<Map<String, String>> _faqs = [
    {
      'cat': 'Home & search',
      'q': 'How does the TradeWorks One network work?',
      'a':
          'You join for free and book vetted, insured home service professionals who serve your ZIP. Each service shows how it\'s priced: a fixed price you see before you book; a diagnostic fee, after which the pro sends a not-to-exceed cap you approve before any repair starts; or a free visit, after which the pro sends an estimate you accept or decline. You book a 2-hour window on the pro\'s calendar, pay your pro directly, and earn 3–8% back in service credits on what you pay.'
    },
    {
      'cat': 'Home & search',
      'q': 'How are contractors vetted?',
      'a':
          'Every contractor in the network is verified for active state licenses and general liability insurance before taking any job. We verify credentials so you don\'t have to chase proof of coverage.'
    },
    {
      'cat': 'Home & search',
      'q': 'How does TradeWorks choose its pros?',
      'a':
          'We vet every pro on TradeWorks ourselves — licence, insurance and workmanship — and hand-pick who gets listed. It isn\'t a rating and it isn\'t bought.'
    },
    {
      'cat': 'Bookings',
      'q': 'Can I cancel or reschedule a booking?',
      'a':
          'You can cancel any future booked job before the work begins, with no homeowner fees, from the Bookings tab. Standard bookings can be rescheduled while they\'re still booked: propose a new 2-hour window from your pro\'s open time, and your original time stands until your pro accepts. Urgent and Emergency bookings can\'t be rescheduled — they\'re a 24-hour or 4-hour commitment.'
    },
    {
      'cat': 'Rewards',
      'q': 'How do TradeWorks service credits work?',
      'a':
          'Qualifying customer-paid spend earns 3%, 4%, 5%, 6% and 8% across five marginal bands in your rewards year, which resets on your signup anniversary. Upload your paid receipt to unlock earnings. Applied credits do not earn more credits. Band earnings are capped at \$1,915 plus \$750 in milestones per rewards year. Credits have no cash value and cannot be transferred.'
    },
    {
      'cat': 'Rewards',
      'q': 'Do my service credits expire?',
      'a':
          'Band credits expire after 24 months; milestone credits expire after 90 days. Your Rewards ledger shows the expiry date for each credit.'
    },
    {
      'cat': 'Rewards',
      'q': 'How do I use my service credits?',
      'a':
          'Your credits show on your account and on any booking. When you book, our team applies the credits you want to use — there are no codes, and nothing is applied without you asking. Credits come off what you pay your pro.'
    },
    {
      'cat': 'Profile & home profile',
      'q': 'How is my Home Profile information used?',
      'a':
          'Your home profile holds property details, systems and documents for a booked pro. Getting-in notes require a confirmed booking at that address and access ends when the job closes.'
    },
  ];

  Future<void> _openSupportLink(String uri, String label) async {
    try {
      final opened = await launchUrlString(uri);
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    AppNotification.showInfo(
      context,
      'No app is available to $label from this device.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _viewIndex != 1,
      onPopInvoked: (didPop) {
        if (!didPop && _viewIndex == 1) {
          setState(() => _viewIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.white,
        appBar: TwAppBar(
          title: _viewIndex == 0
              ? 'Help & Support'
              : (_viewIndex == 1 ? 'Contact support' : ''),
          onBack: _viewIndex == 1
              ? () {
                  setState(() {
                    _viewIndex = 0;
                  });
                }
              : () => Navigator.pop(context),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: TwPage(
                    top: TwSpace.s20,
                    child: _buildBody(),
                  ),
                ),
              ),
              if (_viewIndex < 2) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewIndex == 0) return _buildFaqView();
    if (_viewIndex == 1) return _buildContactForm();
    return _buildSuccessView();
  }

  /// F09 search: a grey pill, 48 high, search icon at 16.
  Widget _searchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.subtle,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.only(left: TwSpace.s16, right: TwSpace.s16),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.navy, size: 20),
          const SizedBox(width: TwSpace.s8),
          Expanded(
            child: TextField(
              style: TwType.body(color: AppTheme.navy),
              textAlignVertical: TextAlignVertical.center,
              decoration: TwInputs.borderless(hint: 'Search help articles'),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// F09 contact tile: hairline card radius 14, padding 16, a grey round
  /// icon well with a navy icon, title, blue value, optional caption.
  Widget _contactTile({
    required IconData icon,
    required String title,
    required String value,
    String? note,
    required VoidCallback onTap,
  }) {
    return TwCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TwIconWell(icon, size: 36),
          const SizedBox(height: TwSpace.s8),
          Text(title, style: TwType.title()),
          const SizedBox(height: TwSpace.s4),
          Text(value, style: TwType.link(size: 14)),
          if (note != null) ...[
            const SizedBox(height: TwSpace.s4),
            Text(note, style: TwType.caption()),
          ],
          const SizedBox(height: TwSpace.s4),
        ],
      ),
    );
  }

  Widget _contactTiles() {
    final call = _contactTile(
      icon: Icons.phone_outlined,
      title: 'Call us',
      value: '(813) 477-7350',
      note: 'Opens your phone’s dialer',
      onTap: () => _openSupportLink('tel:8134777350', 'make a call'),
    );
    final email = _contactTile(
      icon: Icons.mail_outline_rounded,
      title: 'Email us',
      value: 'support@tradeworksai.com',
      onTap: () => _openSupportLink(
        'mailto:support@tradeworksai.com',
        'write an email',
      ),
    );
    // Compact or large text: one tile per row so the email never squeezes.
    if (TwLayout.stackRows(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [call, const SizedBox(height: TwSpace.s12), email],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: call),
          const SizedBox(width: TwSpace.s12),
          Expanded(child: email),
        ],
      ),
    );
  }

  Widget _buildFaqView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField(),
        const SizedBox(height: TwSpace.s16),
        _contactTiles(),
        const SizedBox(height: TwSpace.s12),
        Text(
          'Calls may be recorded for quality. Florida is a two-party-consent state — you’ll hear a notice at the start of any call.',
          style: TwType.caption(),
        ),
        const SizedBox(height: TwSpace.s28),
        Text('Common questions', style: TwType.h2()),
        ...(() {
          final filtered = _faqs
              .where((faq) =>
                  faq['q']!.toLowerCase().contains(_searchQuery) ||
                  faq['a']!.toLowerCase().contains(_searchQuery))
              .toList();
          final Map<String, List<Map<String, String>>> grouped = {};
          for (var faq in filtered) {
            final cat = faq['cat'] ?? 'General';
            grouped.putIfAbsent(cat, () => []).add(faq);
          }

          final List<Widget> widgets = [];
          for (var cat in grouped.keys) {
            widgets.add(Padding(
              padding:
                  const EdgeInsets.only(top: TwSpace.s20, bottom: TwSpace.s4),
              child: Text(
                cat,
                style: TwType.label(color: AppTheme.textSecondary),
              ),
            ));
            final group = grouped[cat]!;
            for (var i = 0; i < group.length; i++) {
              final faq = group[i];
              final last = i == group.length - 1;
              widgets.add(DecoratedBox(
                decoration: BoxDecoration(
                  border: last
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: ValueKey(faq['q']),
                    initiallyExpanded:
                        faq['q'] == 'How does TradeWorks choose its pros?',
                    tilePadding: EdgeInsets.zero,
                    iconColor: AppTheme.navy,
                    collapsedIconColor: AppTheme.navy,
                    expandedAlignment: Alignment.centerLeft,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(
                      faq['q']!,
                      style: TwType.title(),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: TwSpace.s16),
                        child: Text(
                          faq['a']!,
                          style: TwType.bodySm(),
                        ),
                      ),
                    ],
                  ),
                ),
              ));
            }
          }
          return widgets;
        })(),
      ],
    );
  }

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TwFieldLabel('Topic'),
        DropdownButtonFormField<String>(
          value: _topic,
          isExpanded: true,
          style: TwType.body(color: AppTheme.navy),
          decoration: TwInputs.decoration(),
          items: _topics
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: _sending
              ? null
              : (v) => setState(() => _topic = v ?? _topics.first),
        ),
        const SizedBox(height: TwSpace.s16),
        const TwFieldLabel('Related work order', optional: true),
        DropdownButtonFormField<String?>(
          value: _relatedId,
          isExpanded: true,
          style: TwType.body(color: AppTheme.navy),
          decoration: TwInputs.decoration(),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            for (final row in _workOrders)
              DropdownMenuItem<String?>(
                value: row.id,
                child: Text(row.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _sending ? null : (v) => setState(() => _relatedId = v),
        ),
        const SizedBox(height: TwSpace.s16),
        const TwFieldLabel('Message'),
        TextField(
          controller: _message,
          enabled: !_sending,
          minLines: 5,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          style: TwType.body(color: AppTheme.navy),
          decoration: TwInputs.decoration(hint: 'Tell us what’s going on...'),
        ),
      ],
    );
  }

  /// One reassurance line on "Message sent": grey icon well + sentence.
  Widget _successNote(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TwIconWell(icon, size: 36),
        const SizedBox(width: TwSpace.s12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(text, style: TwType.bodySm()),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.greenTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppTheme.greenMark, size: 32),
          ),
        ),
        const SizedBox(height: TwSpace.s16),
        Text('Message sent',
            textAlign: TextAlign.center, style: TwType.h1(context)),
        const SizedBox(height: TwSpace.s8),
        Text(
          AuthService.instance.userEmail == null
              ? 'We’ll reply by email within 1 business day.'
              : 'We’ll reply to ${AuthService.instance.userEmail} within 1 business day.',
          textAlign: TextAlign.center,
          style: TwType.bodySm(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: TwSpace.s28),
        TwFactPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _summaryRows.length; i++) ...[
                if (i > 0) const SizedBox(height: TwSpace.s8),
                TwDetailRow(
                  label: _summaryRows[i].$1,
                  value: _summaryRows[i].$2,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: TwSpace.s28),
        _successNote(
          Icons.mail_outline_rounded,
          'We’ll email your reply — just reply to that email to keep the thread going.',
        ),
        const SizedBox(height: TwSpace.s16),
        _successNote(
          Icons.confirmation_number_outlined,
          'You choose how much credit to apply when you book. Your pro receives the remaining payment directly.',
        ),
        const SizedBox(height: TwSpace.s28),
        TwSecondaryButton(
          label: 'Done',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: TwSpace.s8),
        Center(
          child: TwTextAction(
            label: 'Back to help',
            onPressed: () {
              setState(() {
                _viewIndex = 0;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return TwStickyBar(
      note: 'We usually reply by email within 1 business day.',
      noteBelow: true,
      children: [
        TwPrimaryButton(
          label: _viewIndex == 0 ? 'Contact support' : 'Send request',
          loading: _viewIndex == 1 && _sending,
          onPressed: () {
            if (_viewIndex == 0) {
              setState(() {
                _viewIndex = 1;
              });
            } else if (_viewIndex == 1 && !_sending) {
              _sendRequest();
            }
          },
        ),
      ],
    );
  }
}

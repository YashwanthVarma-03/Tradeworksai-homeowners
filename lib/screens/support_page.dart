import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../utils/work_order_labels.dart';
import '../widgets/app_notification.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({Key? key}) : super(key: key);

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
      'cat': '🏡 Home & Search Page FAQs',
      'q': 'How does the TradeWorks One network work?',
      'a':
          'You join for free, browse vetted and insured home service professionals across 31 categories, and see upfront pricing before you book. You book directly on their calendar, and you earn 3–8% back in service credits on what you pay.'
    },
    {
      'cat': '🏡 Home & Search Page FAQs',
      'q': 'How are contractors vetted?',
      'a':
          'Every contractor in the network is verified for active state licenses and general liability insurance before taking any job. We verify credentials so you don\'t have to chase proof of coverage.'
    },
    {
      'cat': '🏡 Home & Search Page FAQs',
      'q': 'What does Select-certified mean?',
      'a':
          'We vet every pro on TradeWorks ourselves — licence, insurance and workmanship — and hand-pick who gets listed. It isn\'t a rating and it isn\'t bought.'
    },
    {
      'cat': '🏡 Home & Search Page FAQs',
      'q': 'What is GEO/AEO optimization?',
      'a':
          'Generative Engine Optimization (GEO) and Answer Engine Optimization (AEO) are strategies to optimize your contractor website so it gets cited by AI search tools like ChatGPT, Claude, Perplexity, and Google AI Overviews, ensuring your business stays visible where modern buyers search.'
    },
    {
      'cat': '📅 Bookings Page FAQs',
      'q': 'Can I cancel or reschedule a booking?',
      'a':
          'Yes, you can cancel or reschedule any future booked job before the work begins for free with no homeowner fees. Cancellations or reschedules are handled directly via the Bookings tab.'
    },
    {
      'cat': '🏆 Rewards Page FAQs',
      'q': 'How do TradeWorks service credits work?',
      'a':
          'Qualifying customer-paid spend earns 3%, 4%, 5%, 6% and 8% across five marginal bands in your rewards year, which resets on your signup anniversary. Upload your paid receipt to unlock earnings. Applied credits do not earn more credits. Band earnings are capped at \$1,915 plus \$750 in milestones per rewards year. Credits have no cash value and cannot be transferred.'
    },
    {
      'cat': '🏆 Rewards Page FAQs',
      'q': 'Do my service credits expire?',
      'a':
          'Band credits expire after 24 months; milestone credits expire after 90 days. Your Rewards ledger shows the expiry date for each credit.'
    },
    {
      'cat': '🏆 Rewards Page FAQs',
      'q': 'How do I use my service credits?',
      'a':
          'Your credits show on your account and on any booking. When you book, our team applies the credits you want to use — there are no codes, and nothing is applied without you asking. Credits come off what you pay your pro.'
    },
    {
      'cat': '👤 Profile & Home Profile FAQs',
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
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          elevation: 0,
          leading: _viewIndex > 0 && _viewIndex < 2
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.navy700),
                  onPressed: () {
                    setState(() {
                      _viewIndex = 0;
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.navy700),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text(
            _viewIndex == 0
                ? 'Help & Support'
                : (_viewIndex == 1 ? 'Contact support' : ''),
            style: const TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _buildBody(),
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

  Widget _buildFaqView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box
          Container(
            decoration: BoxDecoration(
              color: AppTheme.pageBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.gray, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search help articles',
                      hintStyle: TextStyle(color: AppTheme.gray, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.toLowerCase();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Contact Tiles
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      _openSupportLink('tel:8134777350', 'make a call'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.tealTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone,
                              color: AppTheme.teal500, size: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text('Call us',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy700,
                                fontSize: 12.5)),
                        const SizedBox(height: 2),
                        const Text('(813) 477-7350',
                            style: TextStyle(
                                color: AppTheme.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        const Text('Opens your phone’s dialer',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 18 / 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _openSupportLink(
                    'mailto:support@tradeworksai.com',
                    'write an email',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.tealTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.mail_outline,
                              color: AppTheme.teal500, size: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text('Email us',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy700,
                                fontSize: 12.5)),
                        const SizedBox(height: 2),
                        const Text('support@tradeworksai.com',
                            style: TextStyle(
                                color: AppTheme.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Calls may be recorded for quality. Florida is a two-party-consent state — you’ll hear a notice at the start of any call.',
            style: TextStyle(color: AppTheme.gray, fontSize: 10.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Common questions',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
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
                    const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                child: Text(
                  cat,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ));
              for (var faq in grouped[cat]!) {
                widgets.add(Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      faq['q']!,
                      style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          faq['a']!,
                          style: const TextStyle(
                              color: AppTheme.body,
                              fontSize: 15,
                              height: 23 / 15),
                        ),
                      ),
                    ],
                  ),
                ));
              }
            }
            return widgets;
          })(),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    const labelStyle = TextStyle(
        fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.navy);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      borderSide: const BorderSide(color: AppTheme.cardBorder),
    );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Topic', style: labelStyle),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _topic,
            isExpanded: true,
            decoration: InputDecoration(
                enabledBorder: border, border: border, isDense: true),
            items: _topics
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: _sending
                ? null
                : (v) => setState(() => _topic = v ?? _topics.first),
          ),
          const SizedBox(height: 16),
          const Text('Related work order (optional)', style: labelStyle),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _relatedId,
            isExpanded: true,
            decoration: InputDecoration(
                enabledBorder: border, border: border, isDense: true),
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
          const SizedBox(height: 16),
          const Text('Message', style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            enabled: !_sending,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Tell us what’s going on...',
              enabledBorder: border,
              border: border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Message sent',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy700)),
          const SizedBox(height: 8),
          Text(
            AuthService.instance.userEmail == null
                ? 'We’ll reply by email within 1 business day.'
                : 'We’ll reply to ${AuthService.instance.userEmail} within 1 business day.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _summaryRows.length; i++) ...[
                  if (i > 0) const Divider(height: 24, color: AppTheme.line),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_summaryRows[i].$1,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14)),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(_summaryRows[i].$2,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.mail_outline,
                    color: AppTheme.teal500, size: 16),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'We’ll email your reply — just reply to that email to keep the thread going.',
                  style: TextStyle(
                      color: AppTheme.ink, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.confirmation_number_outlined,
                    color: AppTheme.teal500, size: 16),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'You choose how much credit to apply when you book. Your pro receives the remaining payment directly.',
                  style: TextStyle(
                      color: AppTheme.ink, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _viewIndex = 0;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Help',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done',
                  style: TextStyle(
                      color: AppTheme.navy700, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_viewIndex == 0) {
                  setState(() {
                    _viewIndex = 1;
                  });
                } else if (_viewIndex == 1 && !_sending) {
                  _sendRequest();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _viewIndex == 0 ? 'Contact support' : 'Send request',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We usually reply by email within 1 business day.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

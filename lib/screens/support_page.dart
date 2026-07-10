import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../theme.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({Key? key}) : super(key: key);

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  int _viewIndex = 0; // 0: FAQ, 1: Contact Form, 2: Success
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    {
      'cat': '🏡 Home & Search Page FAQs',
      'q': 'How does the TradeWorks One network work?',
      'a':
          'You join for free, browse vetted and insured home service professionals across 31 categories, and see upfront pricing before you book. You book directly on their calendar, and you earn 3–7% cash back in service credits on every completed job.'
    },
    {
      'cat': '🏡 Home & Search Page FAQs',
      'q': 'How are contractors vetted?',
      'a':
          'Every contractor in the network is verified for active state licenses and general liability insurance before taking any job. We verify credentials so you don\'t have to chase proof of coverage.'
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
          'Earn 3% → 5% → 7% back as you spend more in a year — each rate applies only to spend within its YTD band (no retroactive re-crediting). Credits are service credits that apply toward any booking (never count as new spend). They are non-cashable and non-transferable, and reset every January 1.'
    },
    {
      'cat': '🏆 Rewards Page FAQs',
      'q': 'Do my service credits expire?',
      'a':
          'Yes, each service credit expires 24 months after you earn it. Check your Rewards Tab ledger to see credit-specific expiry logs.'
    },
    {
      'cat': '🏆 Rewards Page FAQs',
      'q': 'How do I redeem my service credits?',
      'a':
          'Credits apply automatically to your next booking. To redeem, just reach out to support and we\'ll apply them for you. This feature is coming soon.'
    },
    {
      'cat': '👤 Profile & Home Profile FAQs',
      'q': 'How is my Home Profile information used?',
      'a':
          'We use your home profile (square footage, year built, bedrooms, bathrooms, HVAC, water heater, roof ages) to suggest timely maintenance and pre-fill your bookings. It is kept secure and isn\'t shared beyond the specific pro you book.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              color: AppTheme.pageAlt,
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
                  onTap: () {
                    launchUrlString('tel:8134777350');
                  },
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
                            style:
                                TextStyle(color: AppTheme.gray, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    launchUrlString('mailto:support@tradeworksai.com');
                  },
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
                            style:
                                TextStyle(color: AppTheme.gray, fontSize: 11)),
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
          const Text(
            'COMMON QUESTIONS',
            style: TextStyle(
              color: AppTheme.gray,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
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
                    color: AppTheme.navy700,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.04,
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
                          color: AppTheme.navy700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          faq['a']!,
                          style: const TextStyle(
                              color: AppTheme.ink, fontSize: 12.5, height: 1.5),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Topic',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.ink)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: 'Booking help',
                items: [
                  'Booking help',
                  'Billing',
                  'Redeem service credits',
                  'Reschedule/Cancel',
                  'Other'
                ]
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Related work order (optional)',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.ink)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: 'None',
                items: ['None', '#TW-4821 — AC repair']
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Message',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.ink)),
          const SizedBox(height: 6),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Tell us what’s going on...',
              hintStyle: const TextStyle(color: AppTheme.gray, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.pageAlt,
              border:
                  Border.all(color: AppTheme.line, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined,
                    color: AppTheme.navy700, size: 16),
                SizedBox(width: 8),
                Text('Add a photo ',
                    style: TextStyle(
                        color: AppTheme.navy700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5)),
                Text('(optional)',
                    style: TextStyle(color: AppTheme.gray, fontSize: 12.5)),
              ],
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
          const Text(
            'We’ll reply to jordan.avery@email.com within 1 business day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reference',
                        style: TextStyle(color: AppTheme.gray, fontSize: 12.5)),
                    Text('#HS-2048',
                        style: TextStyle(
                            color: AppTheme.navy700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5)),
                  ],
                ),
                Divider(height: 24, color: AppTheme.line),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Topic',
                        style: TextStyle(color: AppTheme.gray, fontSize: 12.5)),
                    Text('Booking help',
                        style: TextStyle(
                            color: AppTheme.navy700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5)),
                  ],
                ),
                Divider(height: 24, color: AppTheme.line),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Related',
                        style: TextStyle(color: AppTheme.gray, fontSize: 12.5)),
                    Text('#TW-4821 · AC repair',
                        style: TextStyle(
                            color: AppTheme.navy700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5)),
                  ],
                ),
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
                  'For credit redemptions, support applies the credit to your booking once confirmed.',
                  style: TextStyle(
                      color: AppTheme.ink, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _viewIndex = 0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: AppTheme.navy700,
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
                } else if (_viewIndex == 1) {
                  // submit form
                  setState(() {
                    _viewIndex = 2;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: AppTheme.navy700,
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
          if (_viewIndex == 1) ...[
            const SizedBox(height: 8),
            const Text(
              'We usually reply by email within 1 business day.',
              style: TextStyle(color: AppTheme.gray, fontSize: 11),
            ),
          ]
        ],
      ),
    );
  }
}

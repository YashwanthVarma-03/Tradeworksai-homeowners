import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import 'book_flow.dart';
import 'chat_screen.dart';

class ProProfileScreen extends StatefulWidget {
  final Map<String, dynamic> pro;

  const ProProfileScreen({super.key, required this.pro});

  @override
  State<ProProfileScreen> createState() => _ProProfileScreenState();
}

class _ProProfileScreenState extends State<ProProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final slug = _text(widget.pro['slug'], _text(widget.pro['id']));
      if (slug.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await HomeownerService.instance.getContractorProfile(slug);
      if (!mounted) return;
      final profile = _asMap(data['profile']);
      setState(() {
        _profile = profile.isEmpty ? null : profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  num? _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse(_text(value));
  }

  Map<String, dynamic> get _displayPro =>
      _profile == null ? _asMap(widget.pro) : {..._asMap(widget.pro), ..._profile!};

  String get _businessName => _text(
        _displayPro['business_name'],
        _text(_displayPro['businessName'], 'Service Pro'),
      );

  String get _tradeLine {
    final category = _text(_displayPro['category'], 'Home service');
    final trade = _text(_displayPro['trade']);
    return trade.isEmpty ? category : '$category · $trade';
  }

  String get _rating {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final aggregate = _asMap(reviewsMap['verified_aggregate']);
    return _text(
      aggregate['avg_rating'],
      _text(_displayPro['verifiedRating'], '4.9'),
    );
  }

  String get _reviewCount {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final aggregate = _asMap(reviewsMap['verified_aggregate']);
    return _text(
      aggregate['count'],
      _text(_displayPro['verifiedCount'], '0'),
    );
  }

  String get _ratingLabel {
    final value = num.tryParse(_rating) ?? 0;
    if (value >= 4.9) return 'Exceptional';
    if (value >= 4.7) return 'Great';
    return 'Good';
  }

  String get _price {
    final fromPrice = _text(_displayPro['fromPrice']);
    if (fromPrice.isNotEmpty) return 'From \$$fromPrice';
    final services = _serviceRows();
    if (services.isNotEmpty) return services.first.price;
    return 'Price shown at booking';
  }

  String get _distance {
    final miles = _text(_displayPro['distanceMiles']);
    return miles.isEmpty ? 'Serves 33578' : '$miles mi away · serves 33578';
  }

  List<_ProfileService> _serviceRows() {
    final services = _asList(_displayPro['services']);
    if (services.isEmpty) {
      return [
        _ProfileService('AC repair (diagnose + fix)', _priceFrom(149), 'Upfront price'),
        _ProfileService('AC tune-up / maintenance', '\$89', 'Upfront price'),
        _ProfileService('Refrigerant leak diagnosis', 'You approve the cap', '\$89 diagnostic'),
      ];
    }

    return services.take(8).map((service) {
      final map = _asMap(service);
      if (map.isEmpty) {
        return _ProfileService(_text(service, 'Service'), _price, 'Upfront price');
      }
      final amount = _text(map['rate_amount'], _text(map['price'], _text(map['fromPrice'])));
      final basis = _text(map['rate_label'], _text(map['pricing_basis'], 'Upfront price'));
      final price = amount.isEmpty
          ? _text(map['rate_description'], 'Price shown at booking')
          : '\$$amount';
      return _ProfileService(
        _text(map['name'], _text(map['category'], 'Service')),
        price,
        basis,
      );
    }).toList();
  }

  String _priceFrom(int fallback) {
    final fromPrice = _text(_displayPro['fromPrice']);
    return fromPrice.isEmpty ? 'From \$$fallback' : 'From \$$fromPrice';
  }

  List<MapEntry<String, String>> _businessHours() {
    final hours = _asMap(_displayPro['business_hours']);
    if (hours.isEmpty) {
      return const [
        MapEntry('Mon-Fri', '7:00 AM - 7:00 PM'),
        MapEntry('Sat', '8:00 AM - 4:00 PM'),
        MapEntry('Sun', 'Emergency only'),
      ];
    }

    return hours.entries.map((entry) {
      final value = _asMap(entry.value);
      final label = entry.key.toUpperCase();
      final time = value['closed'] == true
          ? 'Closed'
          : '${_text(value['open'], '--')} - ${_text(value['close'], '--')}';
      return MapEntry(label, time);
    }).toList();
  }

  List<MapEntry<String, String>> _responseTimes() {
    final tiers = _asList(_displayPro['response_times']);
    if (tiers.isNotEmpty) {
      return tiers.map((tier) {
        final map = _asMap(tier);
        return MapEntry(
          _text(map['label'], 'Standard'),
          _text(map['description'], _text(map['window'], 'Configured by this pro')),
        );
      }).toList();
    }

    return const [
      MapEntry('Standard', 'Within 48 hours · included'),
      MapEntry('Urgent', 'Within 8 hours · additional fee if offered'),
      MapEntry('Emergency', 'Within 2 hours · additional fee if offered'),
    ];
  }

  List<dynamic> _reviews() {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final verified = _asList(reviewsMap['verified']);
    if (verified.isNotEmpty) return verified;
    return const [];
  }

  Future<void> _openMessage(String? messageUserId) async {
    if (!AuthService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to message this contractor.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (messageUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat is coming soon for this contractor.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contractorId: messageUserId,
          contractorName: _businessName,
        ),
      ),
    );
  }

  Future<void> _openBooking() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookFlowScreen(pro: _displayPro)),
    );
    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPro = _displayPro;
    final messageUserId = StreamService.instance.resolveMessagingUserId(displayPro);
    final completed = _text(displayPro['completedWorkOrders'], '212');
    final overview = _text(
      displayPro['overview'],
      _text(
        displayPro['summary'],
        'Family-run team handling repairs, tune-ups, and installs across Tampa Bay. Book directly on this pro calendar with upfront, transparent pricing.',
      ),
    );
    final employees = _text(displayPro['employees'], _text(displayPro['team_size'], '6 employees'));
    final years = _text(displayPro['years_in_business'], '14 years in business');
    final paymentMethods = _asList(displayPro['payment_methods'])
        .map((item) => _text(item))
        .where((item) => item.isNotEmpty)
        .join(', ');

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      body: SafeArea(
        child: Column(
          children: [
            _buildProfileAppBar(),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            if (_errorMessage != null && _profile == null) _buildProfileFallbackNote(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeaderCard(completed),
                  _buildPriceAndProject(),
                  _buildSection(
                    'About this pro',
                    Text(
                      overview,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  _buildOverviewSection(completed, employees, years),
                  _buildKeyValueSection(
                    'Business hours',
                    _businessHours(),
                    footer: 'Times in Eastern Time Zone (property timezone)',
                  ),
                  _buildKeyValueSection(
                    'Response times',
                    _responseTimes(),
                    footer: 'Set by $_businessName. Other pros differ.',
                  ),
                  _buildSection(
                    'Payment methods',
                    Text(
                      paymentMethods.isEmpty
                          ? 'You pay the pro directly. TradeWorks adds no markup and no platform fee.'
                          : '$paymentMethods. You pay the pro directly. TradeWorks adds no markup and no platform fee.',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  _buildCertificationSection(messageUserId),
                  _buildServicesSection(),
                  _buildMediaSection(),
                  _buildReviewsSection(),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyFooter(),
    );
  }

  Widget _buildProfileAppBar() {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.navy700),
          ),
          Expanded(
            child: Text(
              _businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.navy700,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share, color: AppTheme.navy700),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFallbackNote() {
    return Container(
      width: double.infinity,
      color: AppTheme.orangeTint,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Text(
        'Showing saved contractor details while live profile data loads.',
        style: TextStyle(
          color: AppTheme.navy700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String completed) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.tealTint,
                child: Text(
                  _businessName
                      .split(' ')
                      .where((part) => part.isNotEmpty)
                      .take(2)
                      .map((part) => part[0].toUpperCase())
                      .join(),
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tradeLine,
                      style: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '$_ratingLabel $_rating',
                          style: const TextStyle(
                            color: AppTheme.navy700,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: AppTheme.orange500, size: 16),
                        Text(
                          ' ($_reviewCount)',
                          style: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppTheme.gray, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _distance,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge('Select-certified', Icons.verified),
              _badge('$completed completed work orders', Icons.check_circle_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndProject() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _price,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upfront price · selected service',
                  style: TextStyle(color: AppTheme.gray, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'View price details',
                  style: TextStyle(
                    color: AppTheme.teal700,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppTheme.navyTint,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your project',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_text(_displayPro['category'], 'Service')} · 33578 · Standard',
                  style: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: AppTheme.navy700,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Book this pro',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Books directly on $_businessName's calendar",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(String completed, String employees, String years) {
    final similarJobs = _text(_displayPro['similarJobsNearby'], '4 similar jobs done near you');
    return _buildSection(
      'Overview',
      Column(
        children: [
          _overviewRow(Icons.task_alt, '$completed completed work orders'),
          _overviewRow(Icons.location_on_outlined, similarJobs),
          _overviewRow(Icons.shield_outlined, 'Background checked · Insured'),
          _overviewRow(Icons.groups_outlined, employees),
          _overviewRow(Icons.schedule, years),
        ],
      ),
    );
  }

  Widget _buildKeyValueSection(
    String title,
    List<MapEntry<String, String>> rows, {
    String? footer,
  }) {
    return _buildSection(
      title,
      Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: rows
                  .map(
                    (row) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.line, width: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              row.key,
                              style: const TextStyle(
                                color: AppTheme.gray,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              row.value,
                              style: const TextStyle(
                                color: AppTheme.navy700,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                footer,
                style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertificationSection(String? messageUserId) {
    return _buildSection(
      'What Select-certified means',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tealTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Background-checked, insured, and performance-scored. We re-verify credentials annually and monitor completed work orders for quality.',
              style: TextStyle(color: AppTheme.ink, fontSize: 13, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openMessage(messageUserId),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text('Message $_businessName'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.navy700,
                side: const BorderSide(color: AppTheme.line),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Center(
            child: Text(
              'Typically responds in about 20 min',
              style: TextStyle(color: AppTheme.gray, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return _buildSection(
      'Services & upfront pricing',
      Column(
        children: _serviceRows()
            .map(
              (service) => Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service.price,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppTheme.navy700,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            service.basis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppTheme.gray,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMediaSection() {
    final mediaCount = _number(_displayPro['mediaCount'])?.toInt() ??
        _asList(_displayPro['media']).length;
    if (mediaCount == 0) return const SizedBox.shrink();
    return _buildSection(
      'Projects & media',
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: mediaCount > 3 ? 3 : mediaCount,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final isLast = index == 2 && mediaCount > 3;
            return Container(
              width: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index.isEven ? AppTheme.tealTint : AppTheme.navyTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.line),
              ),
              child: Text(
                isLast ? '+${mediaCount - 2}' : (index == 0 ? 'install' : 'service'),
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = _reviews();
    return _buildSection(
      'Reviews',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_ratingLabel $_rating',
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: List.generate(
                        5,
                        (index) => const Icon(
                          Icons.star,
                          size: 13,
                          color: AppTheme.orange500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_reviewCount reviews',
                      style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildReviewBars()),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Reviews come only from completed work orders.',
            style: TextStyle(color: AppTheme.gray, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          _reviewToolRow(),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            _reviewItem(
              'Marcus T.',
              'Upfront about the price and fixed it the same day. Booked the window I wanted and arrived inside it.',
              'Details: Central air · Not cooling · Standard urgency',
            )
          else
            ...reviews.take(2).map((item) {
              final review = _asMap(item);
              return _reviewItem(
                _text(review['author_name'], 'Homeowner'),
                _text(review['text'], 'Completed work order review.'),
                _text(review['details'], _text(review['service'], 'Completed work order')),
              );
            }),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'See all $_reviewCount reviews >',
              style: const TextStyle(
                color: AppTheme.teal700,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBars() {
    const rows = [
      MapEntry('5', 94.0),
      MapEntry('4', 4.0),
      MapEntry('3', 1.0),
      MapEntry('2', 0.0),
      MapEntry('1', 1.0),
    ];
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 12, child: Text(row.key)),
                  const Icon(Icons.star, color: AppTheme.gray, size: 11),
                  const SizedBox(width: 5),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: row.value / 100,
                        minHeight: 6,
                        backgroundColor: AppTheme.line,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.orange500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${row.value.toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _reviewToolRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppTheme.gray, size: 16),
                SizedBox(width: 7),
                Text(
                  'Search reviews',
                  style: TextStyle(color: AppTheme.gray, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'Most relevant',
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewItem(String name, String text, String details) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                '★★★★★',
                style: TextStyle(color: AppTheme.orange500, fontSize: 11),
              ),
              _smallBadge('Completed work order'),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: const TextStyle(color: AppTheme.ink, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 7),
          Text(
            details,
            style: const TextStyle(color: AppTheme.gray, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _overviewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.teal700, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.tealTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.teal700, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.teal700,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.tealTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.teal700,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _price,
                    style: const TextStyle(
                      color: AppTheme.navy700,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Upfront price',
                    style: TextStyle(color: AppTheme.gray, fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 172,
              child: ElevatedButton(
                onPressed: _openBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.navy700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Book this pro',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileService {
  final String name;
  final String price;
  final String basis;

  const _ProfileService(this.name, this.price, this.basis);
}

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/stream_service.dart';
import 'book_flow.dart';
import 'chat_screen.dart';

import '../services/homeowner_service.dart';

class ProProfileScreen extends StatefulWidget {
  final Map<String, dynamic> pro;

  const ProProfileScreen({Key? key, required this.pro}) : super(key: key);

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
      final slug = widget.pro['slug'] ?? widget.pro['id']?.toString();
      if (slug == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final data = await HomeownerService.instance.getContractorProfile(slug);
      if (mounted) {
        setState(() {
          _profile = data['profile'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.pageAlt,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.orange500),
        ),
      );
    }

    if (_errorMessage != null && _profile == null) {
      return Scaffold(
        backgroundColor: AppTheme.pageAlt,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(
                  'Could not load contractor profile',
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.gray),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayPro = _profile ?? widget.pro;
    final messageUserId = StreamService.instance.resolveMessagingUserId(
      Map<String, dynamic>.from(displayPro),
    );

    final businessName = displayPro['business_name'] ??
        displayPro['businessName'] ??
        'Service Pro';

    final reviewsMap = displayPro['reviews'];
    final verifiedAgg =
        reviewsMap != null ? reviewsMap['verified_aggregate'] : null;
    final rating = verifiedAgg != null && verifiedAgg['avg_rating'] != null
        ? verifiedAgg['avg_rating'].toString()
        : (displayPro['verifiedRating'] != null
            ? displayPro['verifiedRating'].toString()
            : '5.0');
    final reviewsCount = verifiedAgg != null && verifiedAgg['count'] != null
        ? verifiedAgg['count'].toString()
        : (displayPro['verifiedCount'] != null
            ? displayPro['verifiedCount'].toString()
            : '0');

    final workOrderType = displayPro['workOrderType'] == 'quote_request'
        ? 'Quote Request'
        : 'Flat/Hourly';
    final isNew = displayPro['isNew'] == true;
    final badgeText = isNew ? 'New Pro' : 'TradeWorks Certified';
    final photoUrl = displayPro['profile_image_url'] ?? displayPro['photoUrl'];
    final hasPhoto = photoUrl != null && photoUrl.toString().isNotEmpty;
    final city = displayPro['city']?.toString();
    final state = displayPro['state']?.toString();
    final tagline = displayPro['tagline']?.toString();
    final overview = displayPro['overview']?.toString();
    final paymentMethods =
        (displayPro['payment_methods'] as List?)?.cast<dynamic>() ?? const [];
    final services =
        (displayPro['services'] as List?)?.cast<dynamic>() ?? const [];
    final businessHours = displayPro['business_hours'] as Map<String, dynamic>?;
    final serviceRadius = displayPro['service_radius']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: const Color(0xFF1B3C6E),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B3C6E),
                      Color(0xFF235C86),
                      Color(0xFF2E86AB),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.handyman,
                      size: 64, color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: AppTheme.tealTint,
                        backgroundImage:
                            hasPhoto ? NetworkImage(photoUrl.toString()) : null,
                        child: hasPhoto
                            ? null
                            : Text(
                                businessName.isNotEmpty
                                    ? businessName[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.teal700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        businessName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: AppTheme.navy700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star,
                              color: AppTheme.orange500, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '$rating ($reviewsCount verified reviews)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.tealTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified,
                                color: AppTheme.teal700, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              badgeText,
                              style: const TextStyle(
                                color: AppTheme.teal700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((tagline ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          tagline!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.gray, fontSize: 13),
                        ),
                      ],
                      if ((city ?? '').isNotEmpty ||
                          (state ?? '').isNotEmpty ||
                          (serviceRadius ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if ((city ?? '').isNotEmpty ||
                                (state ?? '').isNotEmpty)
                              _buildInfoChip(
                                  '${city ?? ''}${city != null && state != null ? ', ' : ''}${state ?? ''}'),
                            if ((serviceRadius ?? '').isNotEmpty)
                              _buildInfoChip('Radius: $serviceRadius mi'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // About Section
                _buildSectionContainer(
                  'ABOUT',
                  Text(
                    (overview != null && overview.isNotEmpty)
                        ? overview
                        : 'No company overview available yet.',
                    style: const TextStyle(
                        color: AppTheme.ink, fontSize: 14, height: 1.5),
                  ),
                ),

                const SizedBox(height: 16),

                // Services & Pricing
                _buildSectionContainer(
                  'SERVICES & PRICING',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLineItem('Pricing Model', workOrderType),
                      if (displayPro['fromPrice'] != null) ...[
                        const SizedBox(height: 8),
                        _buildLineItem('Starting Price',
                            '\$${displayPro['fromPrice']} ${displayPro['fromUnit'] != null ? '/${displayPro['fromUnit']}' : ''}'),
                      ],
                      if (paymentMethods.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildLineItem(
                            'Payment Methods', paymentMethods.join(', ')),
                      ],
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Available Services',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy700)),
                        const SizedBox(height: 10),
                        ...services.take(6).map((service) {
                          final name = service['name'] ??
                              service['category'] ??
                              'Service';
                          final amount = service['rate_amount'];
                          final label = service['rate_label'];
                          final priceText = amount != null
                              ? '\$${amount.toString()}${label != null ? ' $label' : ''}'
                              : (service['rate_description']?.toString() ?? '');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildLineItem(name.toString(), priceText),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                if (businessHours != null && businessHours.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionContainer(
                    'BUSINESS HOURS',
                    Column(
                      children: businessHours.entries.map((entry) {
                        final value =
                            entry.value as Map<String, dynamic>? ?? const {};
                        final isClosed = value['closed'] == true;
                        final hours = isClosed
                            ? 'Closed'
                            : '${value['open'] ?? '--'} - ${value['close'] ?? '--'}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildLineItem(entry.key.toUpperCase(), hours),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Reviews Preview
                if (reviewsMap != null &&
                    reviewsMap['verified'] != null &&
                    (reviewsMap['verified'] as List).isNotEmpty)
                  _buildSectionContainer(
                    'RECENT REVIEWS',
                    Column(
                      children:
                          (reviewsMap['verified'] as List).map<Widget>((r) {
                        return Column(
                          children: [
                            _buildReviewItem(r['author_name'] ?? 'Homeowner',
                                (r['rating'] ?? 5).toInt(), r['text'] ?? ''),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child:
                                    Divider(height: 1, color: AppTheme.line)),
                          ],
                        );
                      }).toList(),
                    ),
                  )
                else
                  _buildSectionContainer(
                    'RECENT REVIEWS',
                    const Text('No reviews yet.',
                        style: TextStyle(color: AppTheme.gray)),
                  ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (!AuthService.instance.isAuthenticated) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please sign in to message this contractor.'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                      return;
                    }

                    if (messageUserId == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Chat is coming soon for this contractor.'),
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
                          contractorName: businessName.toString(),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navy700,
                    side: const BorderSide(color: AppTheme.line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Message',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BookFlowScreen(pro: widget.pro)),
                    );
                    if (result == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Book Pro',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.navy700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.pageAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: AppTheme.navy700, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSectionContainer(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLineItem(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(color: AppTheme.gray, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String name, int rating, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy700,
                    fontSize: 14)),
            Row(
              children: List.generate(
                  5,
                  (index) => Icon(Icons.star,
                      size: 14,
                      color:
                          index < rating ? AppTheme.orange500 : AppTheme.line)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(text,
            style: const TextStyle(
                color: AppTheme.ink, fontSize: 13, height: 1.4)),
      ],
    );
  }
}

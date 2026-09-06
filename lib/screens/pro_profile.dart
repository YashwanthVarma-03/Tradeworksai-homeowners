import 'dart:convert';

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

class _ProfileFact {
  final IconData icon;
  final String label;
  final Color color;

  const _ProfileFact(this.icon, this.label, this.color);
}

class _ProfileService {
  final String category;
  final String name;
  final String price;
  final String rateLabel;
  final String description;
  final String minCharge;
  final String duration;

  const _ProfileService({
    required this.category,
    required this.name,
    required this.price,
    required this.rateLabel,
    required this.description,
    required this.minCharge,
    required this.duration,
  });
}

class _ProfileCredential {
  final IconData icon;
  final String title;
  final String detail;

  const _ProfileCredential({
    required this.icon,
    required this.title,
    required this.detail,
  });
}

enum _ReviewSort { mostRelevant, highestRating, lowestRating }

extension on _ReviewSort {
  String get label {
    switch (this) {
      case _ReviewSort.mostRelevant:
        return 'Most relevant';
      case _ReviewSort.highestRating:
        return 'Highest rating';
      case _ReviewSort.lowestRating:
        return 'Lowest rating';
    }
  }
}

class _FigmaProfileSurface extends StatelessWidget {
  static const Color _ink = Color(0xFF243047);
  static const Color _muted = Color(0xFF63758E);
  static const Color _panelColor = Color(0xFFF4F7FB);
  static const Color _line = Color(0xFFDFE5EE);
  static const Color _blue = Color(0xFF203F73);
  static const Color _teal = Color(0xFF1C87BB);
  static const Color _orange = Color(0xFFF47712);
  static const Color _green = Color(0xFF00A86B);

  final String businessName;
  final String category;
  final String service;
  final String distance;
  final String price;
  final String priceDetail;
  final String nextSlot;
  final String rating;
  final String reviewCount;
  final bool selectCertified;
  final String? profileImageUrl;
  final String tagline;
  final String about;
  final List<String> paymentMethods;
  final List<String> mediaUrls;
  final int mediaCount;
  final int videoCount;
  final List<_ProfileFact> overview;
  final List<MapEntry<String, String>> hours;
  final String timeZone;
  final List<MapEntry<String, String>> responseTimes;
  final List<MapEntry<String, String>> pricing;
  final List<_ProfileService> services;
  final List<_ProfileCredential> credentials;
  final List<String> serviceCities;
  final String serviceAreaNote;
  final String emergencyDetails;
  final String emergencyResponse;
  final Map<int, double> ratingBreakdown;
  final List<Map<String, dynamic>> reviews;
  final String reviewQuery;
  final _ReviewSort reviewSort;
  final String responseSummary;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onBook;
  final VoidCallback onMessage;
  final VoidCallback onSeeAllReviews;
  final ValueChanged<String> onReviewQueryChanged;
  final ValueChanged<_ReviewSort> onReviewSortChanged;

  const _FigmaProfileSurface({
    required this.businessName,
    required this.category,
    required this.service,
    required this.distance,
    required this.price,
    required this.priceDetail,
    required this.nextSlot,
    required this.rating,
    required this.reviewCount,
    required this.selectCertified,
    required this.profileImageUrl,
    required this.tagline,
    required this.about,
    required this.paymentMethods,
    required this.mediaUrls,
    required this.mediaCount,
    required this.videoCount,
    required this.overview,
    required this.hours,
    required this.timeZone,
    required this.responseTimes,
    required this.pricing,
    required this.services,
    required this.credentials,
    required this.serviceCities,
    required this.serviceAreaNote,
    required this.emergencyDetails,
    required this.emergencyResponse,
    required this.ratingBreakdown,
    required this.reviews,
    required this.reviewQuery,
    required this.reviewSort,
    required this.responseSummary,
    required this.loading,
    required this.onBack,
    required this.onBook,
    required this.onMessage,
    required this.onSeeAllReviews,
    required this.onReviewQueryChanged,
    required this.onReviewSortChanged,
  });

  bool get _hasRating =>
      (num.tryParse(rating) ?? 0) > 0 && (num.tryParse(reviewCount) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (loading)
              const LinearProgressIndicator(minHeight: 2, color: _orange),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                children: [
                  _identity(),
                  const SizedBox(height: 20),
                  _priceCard(),
                  const SizedBox(height: 16),
                  _requestCard(),
                  if (_hasAboutContent) ...[
                    const SizedBox(height: 18),
                    _section('About', _about()),
                  ],
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _section('Services & rates', _servicesSection()),
                  ],
                  if (mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _mediaSection(),
                  ],
                  if (_hasRating) ...[
                    const SizedBox(height: 16),
                    _reviewSection(),
                  ],
                  if (credentials.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _section('Credentials', _credentialsSection()),
                  ],
                  if (serviceCities.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _section('Service area', _serviceAreaSection()),
                  ],
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Share contractor',
            onPressed: () {},
            icon: const Icon(Icons.share_outlined, color: _ink, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _identity() {
    return Row(
      children: [
        _logo(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selectCertified) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDEEFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Select-certified',
                        style: TextStyle(
                            color: _teal,
                            fontSize: 7,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (distance.isNotEmpty)
                    Text(distance,
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  if (_hasRating) ...[
                    const Icon(Icons.star_rounded, size: 15, color: _orange),
                    Text('$reviewCount reviews ($rating)',
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 54,
        height: 54,
        child: profileImageUrl == null
            ? Container(
                color: _blue,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.home_repair_service_outlined,
                        color: Colors.white, size: 26),
                    const SizedBox(height: 1),
                    Text(category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              )
            : Image.network(profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _blue)),
      ),
    );
  }

  Widget _priceCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _panelDecoration(radius: 12, border: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(price,
                    style: const TextStyle(
                        color: _blue,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 11),
                Text(priceDetail,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                const Text('View price details',
                    style: TextStyle(
                        color: _teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (nextSlot.isNotEmpty) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Text('Next: $nextSlot',
                  style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _requestCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 13),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line)),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Your Project Request',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800))),
              if (service.isNotEmpty)
                Flexible(
                    child: Text(service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(width: double.infinity, height: 46, child: _bookButton()),
          const SizedBox(height: 12),
          Text("Books directly on $businessName's calendar",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _muted, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: Text('Message $businessName',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                side: const BorderSide(color: _teal),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          if (responseSummary.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(responseSummary,
                style: const TextStyle(
                    color: Color(0xFF9AA8B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {String? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800))),
            if (trailing != null)
              Flexible(
                  child: Text(trailing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500))),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  bool get _hasAboutContent =>
      tagline.isNotEmpty ||
      about.isNotEmpty ||
      paymentMethods.isNotEmpty ||
      hours.isNotEmpty ||
      emergencyDetails.isNotEmpty;

  Widget _about() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tagline.isNotEmpty)
            Text(
              tagline,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (tagline.isNotEmpty && about.isNotEmpty) const SizedBox(height: 9),
          if (about.isNotEmpty)
            Text(
              about,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (paymentMethods.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('PAYMENT METHODS',
                style: TextStyle(
                    color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paymentMethods
                  .map((method) => _outlineChip(method))
                  .toList(),
            ),
          ],
          if (hours.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('BUSINESS HOURS',
                style: TextStyle(
                    color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...hours.map(_keyValue),
          ],
          if (emergencyDetails.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.bolt_outlined, color: _ink, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$emergencyDetails${emergencyResponse.isEmpty ? '' : ' — Avg. response: $emergencyResponse.'}',
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ],
        ],
      );

  Widget _mediaSection() {
    final suffix = [
      if (mediaCount > 0) '$mediaCount photos',
      if (videoCount > 0) '$videoCount videos'
    ].join(' · ');
    return _section(
      'Project photos & videos',
      SizedBox(
        height: 120,
        child: Row(
          children: List.generate(
              mediaUrls.take(3).length,
              (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right:
                              index == mediaUrls.take(3).length - 1 ? 0 : 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(mediaUrls[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: _panelColor)),
                            if (videoCount > 0 && index == 1)
                              const Center(
                                  child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Color(0x99000000),
                                      child: Icon(Icons.play_arrow_rounded,
                                          color: Colors.white, size: 20))),
                          ],
                        ),
                      ),
                    ),
                  )),
        ),
      ),
      trailing: suffix.isEmpty ? null : suffix,
    );
  }

  Widget _factsPanel() => _panel(
        Column(
            children: overview
                .map((fact) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        Icon(fact.icon, color: fact.color, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(fact.label,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)))
                      ]),
                    ))
                .toList()),
      );

  Widget _hoursPanel() => _panel(Column(children: [
        ...hours.map(_keyValue),
        if (timeZone.isNotEmpty)
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Times in $timeZone',
                  style: const TextStyle(
                      color: Color(0xFF9AA8B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500))),
      ]));

  Widget _responsePanel() =>
      _panel(Column(children: responseTimes.map(_keyValue).toList()));

  Widget _keyValue(MapEntry<String, String> item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 122,
              child: Text(item.key,
                  style: const TextStyle(
                      color: _ink, fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(item.value,
                  style: const TextStyle(
                      color: _blue,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _pricingList() => Column(
          children: List.generate(pricing.length, (index) {
        final item = pricing[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
              border: index == pricing.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: _line))),
          child: Row(children: [
            Expanded(
                child: Text(item.key,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w500))),
            const SizedBox(width: 12),
            Text(item.value,
                style: const TextStyle(
                    color: _blue, fontSize: 13, fontWeight: FontWeight.w800))
          ]),
        );
      }));

  Widget _outlineChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _servicesSection() {
    final groups = <String, List<_ProfileService>>{};
    for (final service in services) {
      groups.putIfAbsent(service.category, () => []).add(service);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.expand((entry) {
        return [
          Text(
            entry.key,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          ...entry.value.map(_serviceRateRow),
          const SizedBox(height: 12),
        ];
      }).toList(),
    );
  }

  Widget _serviceRateRow(_ProfileService service) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            service.name,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (service.price.isNotEmpty || service.rateLabel.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              [service.price, service.rateLabel]
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (service.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              service.description,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (service.minCharge.isNotEmpty || service.duration.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              [service.minCharge, service.duration]
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ]),
      );

  Widget _credentialsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...credentials.map(
            (credential) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(credential.icon, color: _ink, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(credential.title,
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        if (credential.detail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(credential.detail,
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Contractors carry their own general liability and workers’ comp, verified at onboarding.',
            style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic),
          ),
        ],
      );

  Widget _serviceAreaSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: serviceCities
                .map((city) => Text(city,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)))
                .toList(),
          ),
          if (serviceAreaNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(serviceAreaNote,
                style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      );

  Widget _reviewSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ratingCard(),
      const SizedBox(height: 16),
      Row(children: [
        SizedBox(
          height: 38,
          width: 200,
          child: TextField(
            onChanged: onReviewQueryChanged,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search reviews',
              hintStyle: const TextStyle(color: _muted, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16, color: _muted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: _panelColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
            ),
          ),
        ),
        const Spacer(),
        PopupMenuButton<_ReviewSort>(
          tooltip: 'Sort reviews',
          initialValue: reviewSort,
          onSelected: onReviewSortChanged,
          itemBuilder: (context) => _ReviewSort.values
              .map(
                (sort) => PopupMenuItem<_ReviewSort>(
                  value: sort,
                  child: Text(sort.label),
                ),
              )
              .toList(),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(reviewSort.label,
                style: const TextStyle(color: _muted, fontSize: 12)),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: _muted, size: 17),
          ]),
        ),
      ]),
      if (reviews.isNotEmpty) ...[
        const SizedBox(height: 10),
        ...reviews.take(2).map(_reviewCard),
        Center(
          child: TextButton(
            onPressed: onSeeAllReviews,
            style: TextButton.styleFrom(
              foregroundColor: _teal,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'See all $reviewCount reviews',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              reviewQuery.trim().isEmpty
                  ? 'No written reviews yet'
                  : 'No reviews match “${reviewQuery.trim()}”',
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _ratingCard() => _panel(Row(children: [
        SizedBox(
            width: 118,
            child: Column(children: [
              Text(rating,
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star_rounded, color: _orange, size: 14),
                Icon(Icons.star_rounded, color: _orange, size: 14),
                Icon(Icons.star_rounded, color: _orange, size: 14),
                Icon(Icons.star_rounded, color: _orange, size: 14),
                Icon(Icons.star_rounded, color: _orange, size: 14)
              ]),
              const SizedBox(height: 4),
              Text('$reviewCount ratings',
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ])),
        Expanded(
            child: Column(
                children: [5, 4, 3, 2, 1].map((star) {
          final percent = ratingBreakdown[star] ?? 0;
          return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Text('$star',
                    style: const TextStyle(color: _muted, fontSize: 10)),
                const Icon(Icons.star_rounded, color: _muted, size: 10),
                const SizedBox(width: 5),
                Expanded(
                    child: LinearProgressIndicator(
                        value: (percent / 100).clamp(0, 1),
                        minHeight: 5,
                        color: _orange,
                        backgroundColor: const Color(0xFFDDE4EE))),
                const SizedBox(width: 7),
                SizedBox(
                    width: 25,
                    child: Text('${percent.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _muted, fontSize: 10)))
              ]));
        }).toList())),
      ]));

  Widget _reviewCard(Map<String, dynamic> review) {
    final name = (review['name'] ?? '').toString();
    final text = (review['text'] ?? '').toString();
    final tags = (review['tags'] ?? '').toString();
    final age = (review['daysAgo'] ?? '').toString();
    final stars = (review['rating'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(name,
              style: const TextStyle(
                  color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
          if (review['completed'] == true) ...[
            const SizedBox(width: 7),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFE1F8EE),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('✓ Completed job',
                    style: TextStyle(
                        color: _green,
                        fontSize: 8,
                        fontWeight: FontWeight.w700)))
          ],
          const Spacer(),
          Text(age, style: const TextStyle(color: _muted, fontSize: 10))
        ]),
        if (stars > 0)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                  children: List.generate(
                      5,
                      (index) => Icon(Icons.star_rounded,
                          size: 13,
                          color: index < stars
                              ? _orange
                              : const Color(0xFFDDE4EE))))),
        if (text.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style: const TextStyle(
                      color: _ink, fontSize: 12, height: 1.35))),
        if (tags.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tags,
                  style: const TextStyle(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _bottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE6EAF0)))),
        child: Row(children: [
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(price,
                    style: const TextStyle(
                        color: _blue,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                const Text('Upfront price estimate',
                    style: TextStyle(color: _muted, fontSize: 11))
              ])),
          const SizedBox(width: 12),
          SizedBox(width: 145, height: 50, child: _bookButton()),
        ]),
      );

  Widget _bookButton() => ElevatedButton(
        onPressed: onBook,
        style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
        child: const Text('Book this pro',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _panel(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(radius: 8),
      child: child);

  BoxDecoration _panelDecoration(
          {required double radius, bool border = false}) =>
      BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(radius),
          border: border ? Border.all(color: _line) : null);
}

class _AllReviewsScreen extends StatelessWidget {
  static const Color _ink = Color(0xFF243047);
  static const Color _muted = Color(0xFF63758E);
  static const Color _line = Color(0xFFDFE5EE);
  static const Color _orange = Color(0xFFF47712);

  final String businessName;
  final String rating;
  final String reviewCount;
  final List<Map<String, dynamic>> reviews;

  const _AllReviewsScreen({
    required this.businessName,
    required this.rating,
    required this.reviewCount,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to contractor profile',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Reviews${businessName.isEmpty ? '' : ' for $businessName'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: _orange, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    rating,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$reviewCount ${reviewCount == '1' ? 'review' : 'reviews'}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: reviews.isEmpty
                  ? const Center(
                      child: Text(
                        'No written reviews yet',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _reviewCard(reviews[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final stars = (review['rating'] as num?)?.round().clamp(0, 5) ?? 0;
    final name = review['name']?.toString().trim() ?? '';
    final age = review['daysAgo']?.toString().trim() ?? '';
    final text = review['text']?.toString().trim() ?? '';
    final tags = review['tags']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Verified customer' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (age.isNotEmpty)
                Text(
                  age,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (stars > 0) ...[
            const SizedBox(height: 5),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star_rounded,
                  color: index < stars ? _orange : const Color(0xFFDDE3EC),
                  size: 15,
                ),
              ),
            ),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tags,
              style: const TextStyle(
                color: Color(0xFF1C87BB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProProfileScreenState extends State<ProProfileScreen> {
  static const Color _softPanel = Color(0xFFF5F7FA);
  static const Color _softLine = Color(0xFFE0E7F0);
  static const Color _success = Color(0xFF00A86B);
  static const double _contentInset = 20;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  String _reviewQuery = '';
  _ReviewSort _reviewSort = _ReviewSort.mostRelevant;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final slug = _profileSlug(widget.pro);
      if (slug.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await HomeownerService.instance.getContractorProfile(slug);
      if (!mounted) return;
      final profile = _extractProfilePayload(data);
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

  Map<String, dynamic> _extractProfilePayload(Map<String, dynamic> data) {
    final candidates = [
      _asMap(data['profile']),
      _asMap(data['contractor']),
      _asMap(data['pro']),
      _asMap(data['data']),
      data,
    ];
    final merged = <String, dynamic>{};
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      merged.addAll(candidate);
      final nestedProfile = _asMap(candidate['profile']);
      if (nestedProfile.isNotEmpty) merged.addAll(nestedProfile);
      final nestedContractor = _asMap(candidate['contractor']);
      if (nestedContractor.isNotEmpty) merged.addAll(nestedContractor);
      for (final key in const [
        'stats',
        'metrics',
        'business',
        'businessInfo',
        'business_info',
        'availability',
      ]) {
        final nested = _asMap(candidate[key]);
        if (nested.isNotEmpty) merged.addAll(nested);
      }
    }
    _storeNestedItems(
      merged,
      data,
      targetKey: 'services',
      aliases: const [
        'services',
        'service_options',
        'serviceOptions',
        'bookable_services',
        'bookableServices',
      ],
    );
    _storeNestedItems(
      merged,
      data,
      targetKey: 'pricing',
      aliases: const [
        'pricing',
        'rate_card',
        'rateCard',
        'upfront_pricing',
        'upfrontPricing',
        'service_prices',
        'servicePrices',
      ],
    );
    _storeNestedItems(
      merged,
      data,
      targetKey: 'response_times',
      aliases: const [
        'response_times',
        'responseTimes',
        'urgency_tiers',
        'urgencyTiers',
        'urgency_options',
        'urgencyOptions',
        'service_levels',
        'serviceLevels',
      ],
    );
    merged.removeWhere((key, value) =>
        key == 'success' ||
        key == 'ok' ||
        value == null ||
        _text(value).isEmpty);
    return merged;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  void _storeNestedItems(
    Map<String, dynamic> target,
    Map<String, dynamic> source, {
    required String targetKey,
    required List<String> aliases,
  }) {
    final items = _nestedItems(source, aliases);
    if (items.isNotEmpty) target[targetKey] = items;
  }

  List<dynamic> _nestedItems(dynamic source, List<String> aliases) {
    final wanted = aliases.map(_normalizedKey).toSet();
    final items = <dynamic>[];

    void visit(dynamic value) {
      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }
      if (value is! Map) return;
      for (final entry in value.entries) {
        if (wanted.contains(_normalizedKey(entry.key.toString()))) {
          items.addAll(_itemsFromValue(entry.value));
        }
        visit(entry.value);
      }
    }

    visit(source);
    return items;
  }

  List<dynamic> _itemsFromValue(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return const [];

    final map = Map<String, dynamic>.from(value);
    const recordKeys = [
      'name',
      'title',
      'label',
      'serviceName',
      'service_name',
      'price',
      'amount',
      'fromPrice',
      'from_price',
      'responseTime',
      'response_time',
      'urgency',
      'tier',
    ];
    if (map.keys.any(recordKeys.contains)) return [map];

    for (final key in const [
      'items',
      'results',
      'data',
      'records',
      'options'
    ]) {
      final wrapped = map[key];
      if (wrapped != null) {
        final items = _itemsFromValue(wrapped);
        if (items.isNotEmpty) return items;
      }
    }

    return map.entries.map((entry) {
      if (entry.value is Map) {
        final item = Map<String, dynamic>.from(entry.value as Map);
        item.putIfAbsent('label', () => entry.key.toString());
        item.putIfAbsent('name', () => entry.key.toString());
        return item;
      }
      return <String, dynamic>{
        'label': entry.key.toString(),
        'name': entry.key.toString(),
        'detail': entry.value,
        'price': entry.value,
      };
    }).toList();
  }

  String _normalizedKey(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  num? _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse(_text(value));
  }

  String _profileSlug(Map<String, dynamic> source) {
    final direct = _text(source['slug'], _text(source['profileSlug']));
    if (direct.isNotEmpty) return direct;

    final businessName = _text(
      source['business_name'],
      _text(source['businessName']),
    );
    if (businessName.isEmpty) return '';

    return businessName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Map<String, dynamic> get _displayPro {
    final base = _asMap(widget.pro);
    final live = _profile;
    return live == null ? base : {...base, ...live};
  }

  String get _businessName => _text(
        _displayPro['business_name'],
        _text(_displayPro['businessName'], ''),
      );

  String get _category => _text(_displayPro['category'], '');

  String get _serviceLabel {
    final direct = _text(
      _displayPro['selectedService'],
      _text(
        _displayPro['serviceName'],
        _text(
          _displayPro['service_name'],
          _text(_displayPro['service']),
        ),
      ),
    );
    if (_isDisplayService(direct)) return direct;

    final services = _asList(_displayPro['services']);
    if (services.isNotEmpty) {
      final first = _asMap(services.first);
      final label =
          first.isEmpty ? _text(services.first) : _text(first['name']);
      if (_isDisplayService(label)) return label;
    }

    return '';
  }

  bool _isDisplayService(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        !const {'rate_card', 'rate card', 'unknown', 'null', 'n/a'}
            .contains(normalized);
  }

  String get _rating {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final reviewSummary = _asMap(
      _displayPro['review_summary'] ?? _displayPro['reviewSummary'],
    );
    final ratings = _asMap(_displayPro['ratings']);
    final aggregate = _asMap(
      reviewsMap['verified_aggregate'] ?? reviewsMap['verifiedAggregate'],
    );
    return _text(
      aggregate['avg_rating'],
      _text(
        aggregate['avgRating'],
        _text(
          _displayPro['verifiedRating'],
          _text(
            reviewSummary['avg_rating'],
            _text(
              reviewSummary['average_rating'],
              _text(
                ratings['average'],
                _text(
                  _displayPro['rating'],
                  _text(_displayPro['averageRating'], '0'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _reviewCount {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final reviewSummary = _asMap(
      _displayPro['review_summary'] ?? _displayPro['reviewSummary'],
    );
    final ratings = _asMap(_displayPro['ratings']);
    final aggregate = _asMap(
      reviewsMap['verified_aggregate'] ?? reviewsMap['verifiedAggregate'],
    );
    return _text(
      aggregate['count'],
      _text(
        _displayPro['verifiedCount'],
        _text(
          reviewSummary['count'],
          _text(
            reviewSummary['review_count'],
            _text(
              ratings['count'],
              _text(
                _displayPro['reviewCount'],
                _text(_displayPro['reviewsCount'], '0'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _price {
    final fromPrice = _text(
      _displayPro['fromPrice'],
      _text(
        _displayPro['from_price'],
        _text(_displayPro['price'], _text(_displayPro['startingPrice'])),
      ),
    );
    if (fromPrice.isEmpty) return '';
    if (fromPrice.startsWith('From')) return fromPrice;
    if (fromPrice.startsWith(r'$')) return 'From $fromPrice';
    return 'From \$$fromPrice';
  }

  String get _priceDetail {
    final service = _serviceLabel.toLowerCase();
    if (service.isEmpty) return 'Upfront price';
    return 'Upfront price - $service (diagnose + fix)';
  }

  String get _nextSlot {
    final raw = _text(_displayPro['nextAvailable']);
    if (raw.isEmpty || raw == 'Availability pending') return '';
    final lower = raw.toLowerCase();
    if (lower.contains('today')) return 'Today';
    if (lower.contains('tomorrow')) return 'Tomorrow';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final local = parsed.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final slotDay = DateTime(local.year, local.month, local.day);
      final daysAway = slotDay.difference(today).inDays;
      if (daysAway == 0) return 'Today';
      if (daysAway == 1) return 'Tomorrow';
      return _weekdayLabel(local.weekday);
    }
    final commaIndex = raw.indexOf(',');
    return commaIndex == -1 ? raw : raw.substring(0, commaIndex);
  }

  String _weekdayLabel(int weekday) {
    const labels = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return labels[weekday] ?? 'Soon';
  }

  String get _distanceLine {
    final miles = _number(_displayPro['distanceMiles']);
    final distance =
        miles == null || miles <= 0 ? '' : '${miles.toStringAsFixed(1)} mi';
    return [_category, if (distance.isNotEmpty) distance]
        .where((part) => part.isNotEmpty)
        .join(' · ');
  }

  bool get _hasRatingSummary =>
      (_number(_rating) ?? 0) > 0 && (_number(_reviewCount) ?? 0) > 0;

  String get _aboutText {
    return _text(
      _displayPro['overview'],
      _text(
        _displayPro['summary'],
        _text(_displayPro['about'], _text(_displayPro['description'])),
      ),
    );
  }

  String get _employeeLine {
    return _text(
      _displayPro['employees'],
      _text(
        _displayPro['team_size'],
        _text(_displayPro['teamSize'], _text(_displayPro['employeeCount'])),
      ),
    );
  }

  String get _yearsLine => _text(
        _displayPro['years_in_business'],
        _text(_displayPro['yearsInBusiness']),
      );

  bool get _isSelectCertified {
    return _boolValue(
          _displayPro['selectedCertified'] ??
              _displayPro['isSelectCertified'] ??
              _displayPro['selectCertified'] ??
              _displayPro['select_certified'],
        ) ==
        true;
  }

  String get _responseSummary => _text(
        _displayPro['responseTime'],
        _text(
          _displayPro['response_time'],
          _text(
            _displayPro['responseSummary'],
            _text(_displayPro['response_summary']),
          ),
        ),
      );

  String get _timeZoneLabel => _text(
        _displayPro['timeZone'],
        _text(
          _displayPro['timezone'],
          _text(_displayPro['time_zone']),
        ),
      );

  bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    final text = _text(value).toLowerCase();
    if (text == 'true' || text == 'yes' || text == '1') return true;
    if (text == 'false' || text == 'no' || text == '0') return false;
    return null;
  }

  String get _backgroundInsuranceLine {
    final parts = <String>[];
    final backgroundChecked = _boolValue(
      _displayPro['backgroundChecked'] ??
          _displayPro['background_checked'] ??
          _displayPro['isBackgroundChecked'],
    );
    final insured = _boolValue(
      _displayPro['insured'] ??
          _displayPro['isInsured'] ??
          _displayPro['insuranceVerified'] ??
          _displayPro['insurance_verified'],
    );
    final license = _text(
      _displayPro['licenseStatus'],
      _text(_displayPro['license_status']),
    );
    final direct = _text(
      _displayPro['verificationSummary'],
      _text(_displayPro['verification_summary']),
    );
    if (direct.isNotEmpty) return direct;

    if (backgroundChecked == true) parts.add('Background checked');
    if (insured == true) parts.add('Insured');
    if (license.isNotEmpty) parts.add(license);
    return parts.join(' · ');
  }

  String? get _profileImageUrl {
    final url = _safeNetworkImageUrl(_text(
      _displayPro['photoUrl'],
      _text(
        _displayPro['profile_image_url'],
        _text(
          _displayPro['profileImageUrl'],
          _text(
            _displayPro['avatarUrl'],
            _text(
              _displayPro['logoUrl'],
              _text(_displayPro['logo_url'], _text(_displayPro['imageUrl'])),
            ),
          ),
        ),
      ),
    ));
    return url;
  }

  List<String> get _mediaUrls {
    final urls = <String>[];
    void addUrl(dynamic value) {
      final url = _safeNetworkImageUrl(_text(value));
      if (url != null && !urls.contains(url)) urls.add(url);
    }

    for (final item in _asList(_displayPro['media'])) {
      final map = _asMap(item);
      if (map.isEmpty) {
        addUrl(item);
        continue;
      }
      addUrl(
        map['url'] ??
            map['imageUrl'] ??
            map['photoUrl'] ??
            map['thumbnailUrl'] ??
            map['src'],
      );
    }
    for (final item in _asList(_displayPro['photos'])) {
      final map = _asMap(item);
      if (map.isEmpty) {
        addUrl(item);
        continue;
      }
      addUrl(
        map['url'] ?? map['imageUrl'] ?? map['photoUrl'] ?? map['thumbnailUrl'],
      );
    }
    for (final item in _asList(
      _displayPro['projectPhotos'] ??
          _displayPro['project_photos'] ??
          _displayPro['gallery'] ??
          _displayPro['portfolio'] ??
          _displayPro['project_media'] ??
          _displayPro['projectMedia'],
    )) {
      final map = _asMap(item);
      if (map.isEmpty) {
        addUrl(item);
        continue;
      }
      addUrl(
        map['url'] ??
            map['imageUrl'] ??
            map['image_url'] ??
            map['photoUrl'] ??
            map['photo_url'] ??
            map['thumbnailUrl'] ??
            map['thumbnail_url'] ??
            map['signedUrl'] ??
            map['signed_url'],
      );
    }
    return urls;
  }

  String? _safeNetworkImageUrl(String rawUrl) {
    if (!rawUrl.startsWith('http')) return null;
    if (!_isExpiredSignedStorageUrl(rawUrl)) return rawUrl;
    return null;
  }

  bool _isExpiredSignedStorageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return true;
    if (!uri.path.contains('/storage/v1/object/sign/')) return false;

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return true;

    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(payload);
      if (json is! Map) return true;
      final exp = _number(json['exp'])?.toInt();
      if (exp == null) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      return expiresAt.isBefore(DateTime.now().toUtc());
    } catch (_) {
      return true;
    }
  }

  int get _mediaCount {
    final explicit = _number(
      _displayPro['mediaCount'] ??
          _displayPro['photoCount'] ??
          _displayPro['photosCount'],
    )?.toInt();
    if (explicit != null && explicit > 0) return explicit;
    final urls = _mediaUrls;
    return urls.length;
  }

  int get _videoCount {
    final explicit = _number(_displayPro['videoCount'])?.toInt() ??
        _number(_displayPro['videosCount'])?.toInt();
    if (explicit != null && explicit > 0) return explicit;
    return _asList(_displayPro['videos']).length;
  }

  List<MapEntry<String, String>> _businessHours() {
    final source =
        _displayPro['business_hours'] ?? _displayPro['businessHours'];
    final hourRows = _asList(source);
    if (hourRows.isNotEmpty) {
      final rows = hourRows.map((row) {
            final map = _asMap(row);
            final label = _text(
              map['day'],
              _text(map['label'], _text(map['name'])),
            );
            if (label.isEmpty) return const MapEntry('', '');
            if (map['closed'] == true)
              return MapEntry(_dayLabel(label), 'Closed');
            final value = _text(
              map['hours'],
              _text(map['time'], _text(map['value'])),
            );
            if (value.isNotEmpty) {
              return MapEntry(_dayLabel(label), _formatBusinessHourRange(value));
            }
            final open = _text(map['open'], _text(map['start']));
            final close = _text(map['close'], _text(map['end']));
            if (open.isEmpty || close.isEmpty) return const MapEntry('', '');
            return MapEntry(
              _dayLabel(label),
              '${_formatBusinessHourTime(open)} – ${_formatBusinessHourTime(close)}',
            );
          }).where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty).toList();
      rows.sort((left, right) => _businessDayIndex(left.key)
          .compareTo(_businessDayIndex(right.key)));
      return rows;
    }

    final hours = _asMap(source);
    if (hours.isEmpty) {
      return const [];
    }

    const orderedDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return orderedDays.map((day) {
      final value = _asMap(hours[day] ?? hours[_dayLabel(day)]);
      final label = _dayLabel(day);
      if (value.isEmpty || value['closed'] == true) {
        return MapEntry(label, value.isEmpty ? '—' : 'Closed');
      }
      final open = _text(value['open'], _text(value['start']));
      final close = _text(value['close'], _text(value['end']));
      if (open.isEmpty || close.isEmpty) return MapEntry(label, '—');
      return MapEntry(
        label,
        '${_formatBusinessHourTime(open)} – ${_formatBusinessHourTime(close)}',
      );
    }).toList();
  }

  int _businessDayIndex(String label) {
    const orderedDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final index = orderedDays.indexOf(label);
    return index == -1 ? orderedDays.length : index;
  }

  String _formatBusinessHourRange(String value) {
    if (value.toLowerCase() == 'closed') return 'Closed';
    final parts = value.split(RegExp(r'\s*(?:-|–|to)\s*'));
    if (parts.length == 2) {
      return '${_formatBusinessHourTime(parts.first)} – ${_formatBusinessHourTime(parts.last)}';
    }
    return value;
  }

  String _formatBusinessHourTime(String value) {
    final source = value.trim();
    if (source.toLowerCase().contains('am') || source.toLowerCase().contains('pm')) {
      return source.toUpperCase();
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(source);
    if (match == null) return source;
    final rawHour = int.tryParse(match.group(1)!) ?? 0;
    final minutes = match.group(2)!;
    final suffix = rawHour >= 12 ? 'PM' : 'AM';
    final hour = rawHour % 12 == 0 ? 12 : rawHour % 12;
    return '$hour:$minutes $suffix';
  }

  String _dayLabel(String raw) {
    final normalized = raw.toLowerCase();
    const labels = {
      'monday': 'Monday',
      'mon': 'Monday',
      'tuesday': 'Tuesday',
      'tue': 'Tuesday',
      'wednesday': 'Wednesday',
      'wed': 'Wednesday',
      'thursday': 'Thursday',
      'thu': 'Thursday',
      'friday': 'Friday',
      'fri': 'Friday',
      'saturday': 'Saturday',
      'sat': 'Saturday',
      'sunday': 'Sunday',
      'sun': 'Sunday',
    };
    return labels[normalized] ?? raw;
  }

  List<MapEntry<String, String>> _responseTimes() {
    final tiers = _itemsFromValue(
      _displayPro['response_times'] ??
          _displayPro['responseTimes'] ??
          _displayPro['urgency_tiers'] ??
          _displayPro['urgencyTiers'] ??
          _displayPro['service_levels'] ??
          _displayPro['serviceLevels'],
    );
    if (tiers.isNotEmpty) {
      final seen = <String>{};
      return tiers.map((tier) {
        final map = _asMap(tier);
        final response = _text(
          map['description'],
          _text(
            map['window'],
            _text(
              map['detail'],
              _text(
                map['response_time'],
                _text(
                  map['responseTime'],
                  _text(map['response_window'], _text(map['responseWindow'])),
                ),
              ),
            ),
          ),
        );
        final fee = _text(
          map['feeLabel'],
          _text(
            map['fee_label'],
            _text(
              map['fee'],
              _text(map['surcharge'], _text(map['additional_fee'])),
            ),
          ),
        );
        final detail =
            fee.isEmpty || response.toLowerCase().contains(fee.toLowerCase())
                ? response
                : '$response - ${_formatPrice(fee)}';
        return MapEntry(
          _text(
            map['label'],
            _text(map['name'], _text(map['title'], _text(map['tier']))),
          ),
          detail,
        );
      }).where((entry) {
        final key = entry.key.toLowerCase();
        return entry.key.isNotEmpty && entry.value.isNotEmpty && seen.add(key);
      }).toList();
    }

    final responseText = _text(
      _displayPro['responseTime'],
      _text(_displayPro['response_time']),
    );
    if (responseText.isNotEmpty) {
      return [MapEntry('Standard', responseText)];
    }

    return const [];
  }

  List<MapEntry<String, String>> _pricingItems() {
    final result = <MapEntry<String, String>>[];
    final seen = <String>{};
    final sources = [
      _displayPro['pricing'],
      _displayPro['rateCard'],
      _displayPro['upfrontPricing'],
      _displayPro['upfront_pricing'],
      _displayPro['pricingItems'],
      _displayPro['rate_card'],
      _displayPro['rateCards'],
      _displayPro['servicePrices'],
      _displayPro['service_prices'],
      _displayPro['services'],
      _displayPro['service_options'],
      _displayPro['serviceOptions'],
    ];

    for (final source in sources) {
      for (final item in _itemsFromValue(source)) {
        final map = _asMap(item);
        final name = _text(
          map['name'],
          _text(
            map['title'],
            _text(
              map['label'],
              _text(map['serviceName'], _text(map['service_name'])),
            ),
          ),
        );
        final priceRaw = _text(
          map['priceLabel'],
          _text(
            map['price_label'],
            _text(
              map['price'],
              _text(
                map['amount'],
                _text(
                  map['rate_amount'],
                  _text(
                    map['fromPrice'],
                    _text(
                      map['from_price'],
                      _text(
                        map['startingPrice'],
                        _text(map['starting_price'], _text(map['base_price'])),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final price = _formatPrice(priceRaw);
        final key = '${name.toLowerCase()}|${price.toLowerCase()}';
        if (name.isNotEmpty && price.isNotEmpty && seen.add(key)) {
          result.add(MapEntry(name, price));
        }
      }
    }
    if (result.isNotEmpty) return result;

    if (_price.isNotEmpty) {
      return [
        MapEntry(
            _serviceLabel.isEmpty ? 'Starting price' : _serviceLabel, _price),
      ];
    }

    return const [];
  }

  String get _tagline => _text(_displayPro['tagline']);

  List<String> get _paymentMethods {
    const labels = {
      'cash': 'Cash',
      'check': 'Check',
      'credit_card': 'Credit card',
      'debit_card': 'Debit card',
      'zelle': 'Zelle',
      'venmo': 'Venmo',
      'paypal': 'PayPal',
      'apple_pay': 'Apple Pay',
      'google_pay': 'Google Pay',
      'ach': 'ACH',
      'financing': 'Financing',
    };
    return _asList(
      _displayPro['payment_methods'] ?? _displayPro['paymentMethods'],
    ).map((method) {
      final raw = _text(method).toLowerCase();
      return labels[raw] ??
          raw
              .split('_')
              .where((part) => part.isNotEmpty)
              .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
              .join(' ');
    }).where((method) => method.isNotEmpty).toSet().toList();
  }

  List<_ProfileService> get _services {
    final seen = <String>{};
    final services = <_ProfileService>[];
    for (final item in _asList(_displayPro['services'])) {
      final service = _asMap(item);
      final category = _text(service['category'], _category);
      final name = _text(
        service['name'],
        _text(service['service_name'], _text(service['rate_description'])),
      );
      final price = _formatWebsiteMoney(
        service['rate_amount'] ?? service['price'] ?? service['amount'],
      );
      final key = '$category|$name|$price'.toLowerCase();
      if (name.isEmpty || !seen.add(key)) continue;
      final minCharge = _formatWebsiteMoney(service['min_charge']);
      final durationMinutes = _number(service['duration_minutes'] ??
          service['durationMinutes']);
      services.add(_ProfileService(
        category: category.isEmpty ? 'Services' : category,
        name: name,
        price: price,
        rateLabel: _text(service['rate_label'], _text(service['rateLabel'])),
        description: _text(
          service['rate_description'],
          _text(service['description']),
        ),
        minCharge: minCharge.isEmpty ? '' : 'Min charge $minCharge',
        duration: durationMinutes == null
            ? ''
            : 'Approx. ${_formatDuration(durationMinutes.toInt())}',
      ));
    }
    return services;
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours > 0 && remainder > 0) return '${hours}h ${remainder}m';
    if (hours > 0) return '${hours}h';
    return '$remainder min';
  }

  String _formatWebsiteMoney(dynamic value) {
    final amount = _number(value);
    if (amount != null) {
      return '\$${amount == amount.roundToDouble() ? amount.toInt() : amount.toStringAsFixed(2)}';
    }
    return _formatPrice(_text(value));
  }

  List<_ProfileCredential> get _credentials {
    final credential = _asMap(_displayPro['credentials']);
    if (credential.isEmpty) return const [];
    final result = <_ProfileCredential>[];
    final license = _asMap(credential['license']);
    final licenseParts = [
      _text(license['type']),
      if (_text(license['number']).isNotEmpty) '#${_text(license['number'])}',
      _text(license['body']),
    ].where((part) => part.isNotEmpty).join(' · ');
    if (licenseParts.isNotEmpty) {
      result.add(_ProfileCredential(
        icon: Icons.workspace_premium_outlined,
        title: 'Licensed',
        detail: licenseParts,
      ));
    }
    if (_boolValue(credential['insured']) == true) {
      final carrier = _text(credential['gl_carrier']);
      result.add(_ProfileCredential(
        icon: Icons.shield_outlined,
        title: 'Insured',
        detail: carrier.isEmpty ? 'Verified at onboarding' : '$carrier · verified at onboarding',
      ));
    }
    if (_boolValue(credential['background_checked']) == true) {
      result.add(const _ProfileCredential(
        icon: Icons.person_outline,
        title: 'Background checked',
        detail: '',
      ));
    }
    return result;
  }

  List<String> get _serviceCities => _asList(
        _displayPro['service_cities'] ?? _displayPro['serviceCities'],
      ).map(_text).where((city) => city.isNotEmpty).toSet().toList();

  String get _serviceAreaNote {
    final radius = _number(
      _displayPro['service_radius'] ?? _displayPro['serviceRadius'],
    );
    if (radius == null || radius <= 0 || _serviceCities.isEmpty) return '';
    final origin = _text(_displayPro['city'], _serviceCities.first);
    return 'Typically travels up to ${radius.toStringAsFixed(radius == radius.roundToDouble() ? 0 : 1)} miles from $origin.';
  }

  Map<String, dynamic> get _emergency => _asMap(_displayPro['emergency']);

  String get _emergencyDetails => _boolValue(_emergency['available']) == true
      ? _text(_emergency['details'])
      : '';

  String get _emergencyResponse => _text(
        _emergency['avg_urgent_response'],
        _text(_emergency['avgUrgentResponse']),
      );

  String _formatPrice(String raw) {
    final price = raw.trim();
    if (price.isEmpty) return '';
    final lower = price.toLowerCase();
    if (price.startsWith(r'$') ||
        lower.startsWith('from ') ||
        lower.contains('free') ||
        lower.contains('estimate')) {
      return price;
    }
    return '\$$price';
  }

  Map<int, double> _ratingBreakdown() {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final reviewSummary = _asMap(
      _displayPro['review_summary'] ?? _displayPro['reviewSummary'],
    );
    final aggregate = _asMap(
      reviewsMap['verified_aggregate'] ??
          reviewsMap['verifiedAggregate'] ??
          _displayPro['verified_aggregate'] ??
          _displayPro['verifiedAggregate'],
    );
    final values = <int, double>{};

    for (final source in [
      aggregate,
      reviewSummary,
      _asMap(_displayPro['ratings']),
      reviewsMap,
      _displayPro,
    ]) {
      if (values.isNotEmpty) break;
      for (final candidate in _ratingDistributionCandidates(source)) {
        _readRatingDistribution(candidate, values);
        if (values.isNotEmpty) break;
      }
    }

    if (values.isEmpty) {
      for (final review in _reviewsList()) {
        final stars = (_number(review['rating']) ?? 0).round();
        if (stars >= 1 && stars <= 5) {
          values[stars] = (values[stars] ?? 0) + 1;
        }
      }
    }

    if (values.isEmpty) {
      return const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }

    final total = values.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }

    final highest = values.values.reduce((a, b) => a > b ? a : b);
    final isFraction = highest <= 1 && total <= 1.01;
    final isPercentage = total >= 99 && total <= 101;

    return {
      for (var star = 5; star >= 1; star--)
        star: (isFraction
                ? (values[star] ?? 0) * 100
                : isPercentage
                    ? (values[star] ?? 0)
                    : ((values[star] ?? 0) / total) * 100)
            .clamp(0, 100)
            .toDouble(),
    };
  }

  List<dynamic> _ratingDistributionCandidates(Map<String, dynamic> source) {
    const keys = [
      'breakdown',
      'distribution',
      'ratingBreakdown',
      'rating_breakdown',
      'ratingDistribution',
      'rating_distribution',
      'starDistribution',
      'star_distribution',
      'ratingCounts',
      'rating_counts',
      'starCounts',
      'star_counts',
      'byRating',
      'by_rating',
      'byStar',
      'by_star',
      'counts',
      'histogram',
    ];
    return [
      ...keys.map((key) => source[key]),
      source,
    ].where((candidate) => candidate != null).toList();
  }

  void _readRatingDistribution(
    dynamic candidate,
    Map<int, double> output,
  ) {
    if (candidate is List) {
      for (final item in candidate) {
        final bucket = _asMap(item);
        final stars = _number(
          bucket['rating'] ?? bucket['stars'] ?? bucket['star'] ?? bucket['key'],
        )
            ?.round();
        final value = _ratingDistributionValue(bucket);
        if (stars != null && stars >= 1 && stars <= 5 && value != null) {
          output[stars] = value;
        }
      }
      return;
    }

    if (candidate is! Map) return;
    for (final entry in candidate.entries) {
      final stars = _starsFromDistributionKey(entry.key.toString());
      final value = _ratingDistributionValue(entry.value);
      if (stars != null && value != null) {
        output[stars] = value;
      }
    }
  }

  int? _starsFromDistributionKey(String key) {
    final normalized = _normalizedKey(key);
    for (var star = 1; star <= 5; star++) {
      if (normalized == '$star' ||
          normalized == 'star$star' ||
          normalized == 'rating$star' ||
          normalized == '${star}star' ||
          normalized == '${star}stars') {
        return star;
      }
    }

    const words = ['one', 'two', 'three', 'four', 'five'];
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      if (normalized == word ||
          normalized == '${word}star' ||
          normalized == '${word}stars') {
        return index + 1;
      }
    }
    return null;
  }

  double? _ratingDistributionValue(dynamic value) {
    final direct = _number(value);
    if (direct != null) return direct.toDouble();
    if (value is String) {
      final percent = num.tryParse(value.trim().replaceAll('%', ''));
      if (percent != null) return percent.toDouble();
    }

    final bucket = _asMap(value);
    for (final key in const [
      'percentage',
      'percent',
      'pct',
      'count',
      'value',
      'total',
    ]) {
      final number = _number(bucket[key]);
      if (number != null) return number.toDouble();
    }
    return null;
  }

  List<Map<String, dynamic>> _reviewsList() {
    final reviewsMap = _asMap(_displayPro['reviews']);
    final items = _asList(
      reviewsMap['items'] ??
          reviewsMap['list'] ??
          reviewsMap['results'] ??
          reviewsMap['data'] ??
          reviewsMap['records'] ??
          reviewsMap['reviews'] ??
          reviewsMap['verified'] ??
          reviewsMap['verifiedReviews'] ??
          _displayPro['reviewItems'] ??
          _displayPro['review_items'] ??
          _displayPro['reviewList'] ??
          _displayPro['review_list'] ??
          _displayPro['verifiedReviews'] ??
          _displayPro['verified_reviews'] ??
          _displayPro['reviews'],
    );
    if (items.isNotEmpty) {
      return items.map((item) {
        final review = _asMap(item);
        final author = _asMap(review['author'] ?? review['reviewer']);
        return <String, dynamic>{
          ...review,
          'name': _text(
            review['name'],
            _text(
              review['reviewerName'],
              _text(
                review['reviewer_name'],
                _text(author['name'], _text(author['displayName'])),
              ),
            ),
          ),
          'rating': _number(
            review['rating'] ??
                review['stars'] ??
                review['starRating'] ??
                review['star_rating'],
          ),
          'text': _text(
            review['text'],
            _text(
              review['review_text'],
              _text(
                review['comment'],
                _text(review['body'], _text(review['review'])),
              ),
            ),
          ),
          'daysAgo': _text(
            review['daysAgo'],
            _text(
              review['createdAtLabel'],
              _text(
                review['created_at_label'],
                _text(
                  review['dateLabel'],
                  _text(review['month_year'], _text(review['monthYear'])),
                ),
              ),
            ),
          ),
          'tags': _text(
            review['tags'],
            _text(
              review['jobLabel'],
              _text(
                review['job_label'],
                _text(
                  review['service_performed'],
                  _text(review['servicePerformed']),
                ),
              ),
            ),
          ),
          'completed': _boolValue(
                review['completed'] ??
                    review['completedJob'] ??
                    review['completed_job'] ??
                    review['verified'],
              ) ==
              true,
        };
      }).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _visibleReviews() {
    final query = _reviewQuery.trim().toLowerCase();
    final reviews = _reviewsList().where((review) {
      if (query.isEmpty) return true;
      final searchable = [
        review['name'],
        review['text'],
        review['tags'],
      ].map(_text).join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    switch (_reviewSort) {
      case _ReviewSort.mostRelevant:
        return reviews;
      case _ReviewSort.highestRating:
        reviews.sort(
          (a, b) => (_number(b['rating']) ?? 0)
              .compareTo(_number(a['rating']) ?? 0),
        );
        return reviews;
      case _ReviewSort.lowestRating:
        reviews.sort(
          (a, b) => (_number(a['rating']) ?? 0)
              .compareTo(_number(b['rating']) ?? 0),
        );
        return reviews;
    }
  }

  void _openAllReviews() {
    final reviews = _reviewsList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AllReviewsScreen(
          businessName: _businessName,
          rating: _rating,
          reviewCount: _reviewCount,
          reviews: reviews,
        ),
      ),
    );
  }

  Future<void> _openBooking() async {
    final navigator = Navigator.of(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookFlowScreen(pro: _displayPro)),
    );
    if (result == true && mounted) {
      navigator.pop(true);
    }
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

  @override
  Widget build(BuildContext context) {
    final displayPro = _displayPro;
    final completed = _text(
      displayPro['completedWorkOrders'],
      _text(
        displayPro['completed_work_orders'],
        _text(
          displayPro['completedJobs'],
          _text(
            displayPro['completed_jobs'],
            _text(
              displayPro['jobsCompleted'],
              _text(displayPro['jobs_completed'], _text(displayPro['orders'])),
            ),
          ),
        ),
      ),
    );
    final similarJobs = _text(
      displayPro['similarJobsNearby'],
      _text(
        displayPro['similar_jobs_nearby'],
        _text(displayPro['nearbyJobs'], _text(displayPro['nearby_jobs'])),
      ),
    );
    final overview = <_ProfileFact>[
      if ((int.tryParse(completed) ?? 0) > 0)
        _ProfileFact(Icons.check_circle_outline,
            '$completed completed work orders', _success),
      if (similarJobs.isNotEmpty)
        _ProfileFact(Icons.map_outlined, similarJobs, AppTheme.teal700),
      if (_backgroundInsuranceLine.isNotEmpty)
        _ProfileFact(Icons.verified_user_outlined, _backgroundInsuranceLine,
            AppTheme.teal700),
      if (_employeeLine.isNotEmpty || _yearsLine.isNotEmpty)
        _ProfileFact(
          Icons.groups_2_outlined,
          [_employeeLine, _yearsLine]
              .where((item) => item.isNotEmpty)
              .join(' · '),
          AppTheme.teal700,
        ),
    ];

    return _FigmaProfileSurface(
      businessName: _businessName,
      category: _category,
      service: _serviceLabel,
      distance: _distanceLine,
      price: _price,
      priceDetail: _priceDetail,
      nextSlot: _nextSlot,
      rating: _rating,
      reviewCount: _reviewCount,
      selectCertified: _isSelectCertified,
      profileImageUrl: _profileImageUrl,
      tagline: _tagline,
      about: _aboutText,
      paymentMethods: _paymentMethods,
      mediaUrls: _mediaUrls,
      mediaCount: _mediaCount,
      videoCount: _videoCount,
      overview: overview,
      hours: _businessHours(),
      timeZone: _timeZoneLabel,
      responseTimes: _responseTimes(),
      pricing: _pricingItems(),
      services: _services,
      credentials: _credentials,
      serviceCities: _serviceCities,
      serviceAreaNote: _serviceAreaNote,
      emergencyDetails: _emergencyDetails,
      emergencyResponse: _emergencyResponse,
      ratingBreakdown: _ratingBreakdown(),
      reviews: _visibleReviews(),
      reviewQuery: _reviewQuery,
      reviewSort: _reviewSort,
      responseSummary: _responseSummary,
      loading: _isLoading,
      onBack: () => Navigator.pop(context),
      onBook: _openBooking,
      onMessage: () => _openMessage(
        StreamService.instance.resolveMessagingUserId(displayPro),
      ),
      onSeeAllReviews: _openAllReviews,
      onReviewQueryChanged: (query) {
        setState(() => _reviewQuery = query);
      },
      onReviewSortChanged: (sort) {
        setState(() => _reviewSort = sort);
      },
    );
  }

  Widget _buildLegacyProfile(BuildContext context) {
    final displayPro = _displayPro;
    final messageUserId =
        StreamService.instance.resolveMessagingUserId(displayPro);
    final completed = _text(
      displayPro['completedWorkOrders'],
      _text(displayPro['completed_work_orders'], _text(displayPro['orders'])),
    );
    final similarJobs = _text(
      displayPro['similarJobsNearby'],
      _text(displayPro['similar_jobs_nearby']),
    );
    final hasRenderableProfile = _businessName.isNotEmpty || _price.isNotEmpty;
    final hasOverviewData = _hasOverviewData(completed, similarJobs);
    final responseTimes = _responseTimes();
    final pricingItems = _pricingItems();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _centeredFrame(
                child: Column(
                  children: [
                    _buildProfileAppBar(),
                    if (_isLoading)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.orange500,
                      ),
                    if (_errorMessage != null && _profile == null)
                      _buildProfileFallbackNote(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          _contentInset,
                          0,
                          _contentInset,
                          22,
                        ),
                        children: [
                          if (!hasRenderableProfile)
                            const Padding(
                              padding: EdgeInsets.only(top: 120),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.orange500,
                                ),
                              ),
                            )
                          else ...[
                            _buildHeader(),
                            const SizedBox(height: 20),
                            _buildPriceCard(),
                            const SizedBox(height: 16),
                            _buildProjectRequestCard(messageUserId),
                          ],
                          if (_aboutText.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _buildAboutSection(),
                          ],
                          if (_mediaUrls.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildMediaSection(),
                          ],
                          if (hasOverviewData) ...[
                            const SizedBox(height: 16),
                            _buildOverviewSection(completed, similarJobs),
                          ],
                          if (_businessHours().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildBusinessHoursSection(),
                          ],
                          if (responseTimes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildResponseTimesSection(),
                          ],
                          if (pricingItems.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildPricingSection(),
                          ],
                          if (_hasReviewData) ...[
                            const SizedBox(height: 16),
                            _buildReviewsSection(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildStickyFooterBar(),
          ],
        ),
      ),
    );
  }

  Widget _centeredFrame({
    required Widget child,
  }) {
    return SizedBox(width: double.infinity, child: child);
  }

  bool _hasOverviewData(String completed, String similarJobs) {
    final completedCount = int.tryParse(completed) ?? 0;
    return completedCount > 0 ||
        similarJobs.isNotEmpty ||
        _backgroundInsuranceLine.isNotEmpty ||
        _employeeLine.isNotEmpty ||
        _yearsLine.isNotEmpty;
  }

  bool get _hasReviewData {
    final reviewCount = int.tryParse(_reviewCount) ?? 0;
    return reviewCount > 0 || _reviewsList().isNotEmpty;
  }

  Widget _buildProfileAppBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.navy700,
              size: 22,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Share contractor',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            onPressed: () {},
            icon: const Icon(
              Icons.share_outlined,
              color: AppTheme.navy700,
              size: 21,
            ),
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
        'Showing available contractor details while live profile data loads.',
        style: TextStyle(
          color: AppTheme.navy700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLogo(),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_isSelectCertified) _miniChip('Select-certified'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _distanceLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_hasRatingSummary) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.star_rounded,
                      color: AppTheme.orange500,
                      size: 14,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '$_reviewCount reviews ($_rating)',
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    final imageUrl = _profileImageUrl;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.navy700,
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _logoFallback();
              },
              errorBuilder: (_, __, ___) => _logoFallback(),
            )
          : _logoFallback(),
    );
  }

  Widget _logoFallback() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 30),
        Positioned(
          bottom: 4,
          child: Text(
            _category.toUpperCase().split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 113),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _softPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _softLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _price,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _priceDetail,
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
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
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              _nextSlot.isEmpty ? '' : 'Next: $_nextSlot',
              style: const TextStyle(
                color: _success,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectRequestCard(String? messageUserId) {
    final responseText = _responseSummary;
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.fromLTRB(13, 16, 13, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _softLine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Project Request',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _serviceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _openBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Book this pro',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            "Books directly on $_businessName's calendar",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _openMessage(messageUserId),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 12),
              label: Text('Message $_businessName'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.teal700,
                side: const BorderSide(color: AppTheme.teal500),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (responseText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              responseText,
              style: const TextStyle(
                color: Color(0xFF9AA8B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return _section(
      title: 'About this pro',
      child: Text(
        _aboutText,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    final urls = _mediaUrls;
    final count = _mediaCount;
    final videoCount = _videoCount;
    final trailingParts = <String>[
      if (count > 0) '$count photos',
      if (videoCount > 0) '$videoCount videos',
    ];
    return _section(
      title: 'Project photos & videos',
      trailing: trailingParts.isEmpty ? null : trailingParts.join(' · '),
      child: SizedBox(
        height: 120,
        child: Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 10),
                child: _mediaTile(
                  index: index,
                  url: index < urls.length ? urls[index] : null,
                  showPlay: videoCount > 0 && index == 1,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _mediaTile({
    required int index,
    required String? url,
    required bool showPlay,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _mediaPlaceholder(index);
              },
              errorBuilder: (_, __, ___) => _mediaPlaceholder(index),
            )
          else
            _mediaPlaceholder(index),
          if (showPlay)
            Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediaPlaceholder(int index) {
    const fills = [
      Color(0xFFDCEAF6),
      Color(0xFFE9E0D3),
      Color(0xFFD9E9DE),
    ];
    const icons = [
      Icons.roofing_rounded,
      Icons.home_repair_service_rounded,
      Icons.construction_rounded,
    ];
    return Container(
      color: fills[index % fills.length],
      child: Icon(
        icons[index % icons.length],
        color: AppTheme.navy700,
        size: 28,
      ),
    );
  }

  Widget _buildOverviewSection(String completed, String similarJobs) {
    final employeeAndYears = [
      if (_employeeLine.isNotEmpty) _employeeLine,
      if (_yearsLine.isNotEmpty) _yearsLine,
    ].join(' · ');
    return _section(
      title: 'Overview',
      boxed: true,
      child: Column(
        children: [
          if ((int.tryParse(completed) ?? 0) > 0)
            _overviewRow(
              Icons.check_circle_outline,
              '$completed completed work orders',
              color: _success,
            ),
          if (similarJobs.isNotEmpty)
            _overviewRow(
              Icons.location_on_outlined,
              similarJobs,
              color: AppTheme.teal700,
            ),
          if (_backgroundInsuranceLine.isNotEmpty)
            _overviewRow(
              Icons.shield_outlined,
              _backgroundInsuranceLine,
              color: AppTheme.teal700,
            ),
          if (employeeAndYears.isNotEmpty)
            _overviewRow(
              Icons.groups_outlined,
              employeeAndYears,
              color: AppTheme.teal700,
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursSection() {
    return _section(
      title: 'Business Hours',
      boxed: true,
      child: Column(
        children: [
          ..._businessHours().map(_twoColumnRow),
          if (_timeZoneLabel.isNotEmpty) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Times in $_timeZoneLabel',
                style: const TextStyle(
                  color: Color(0xFF9AA8B8),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseTimesSection() {
    return _section(
      title: 'Response Times',
      trailing: 'Set by $_businessName',
      boxed: true,
      child: Column(
        children: _responseTimes().map(_twoColumnRow).toList(),
      ),
    );
  }

  Widget _buildPricingSection() {
    final items = _pricingItems();
    return _section(
      title: 'Upfront Pricing',
      child: Column(
        children: List.generate(items.length, (index) {
          final entry = items[index];
          final isLast = index == items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: Color(0xFFE1E7EF), width: 1),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.value,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRatingSummaryCard() {
    final breakdown = _ratingBreakdown();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 18, 18, 18),
      decoration: BoxDecoration(
        color: _softPanel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _rating,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (_) => const Icon(
                    Icons.star_rounded,
                    color: AppTheme.orange500,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$_reviewCount ratings',
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [5, 4, 3, 2, 1].map((star) {
                final pct = breakdown[star] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFF65758C),
                        size: 9,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: const Color(0xFFDDE3EC),
                            valueColor: const AlwaysStoppedAnimation(
                              AppTheme.orange500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${pct.toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppTheme.gray,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = _reviewsList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRatingSummaryCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 199,
              child: Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: _softPanel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _softLine),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.gray, size: 13),
                    SizedBox(width: 6),
                    Text(
                      'Search reviews',
                      style: TextStyle(
                        color: AppTheme.gray,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Most relevant',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.navy700,
                  size: 15,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                'No written reviews yet',
                style: TextStyle(
                  color: AppTheme.gray,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else ...[
          ...reviews.map(_buildReviewCard),
          const SizedBox(height: 4),
          Center(
            child: InkWell(
              onTap: _openAllReviews,
              child: Text(
                'See all $_reviewCount reviews',
                style: const TextStyle(
                  color: AppTheme.teal700,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (_number(review['rating']) ?? 0).toInt().clamp(0, 5);
    final tags = _text(review['tags']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _text(review['name']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (review['completed'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF5E7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Color(0xFF17A868), size: 9),
                      SizedBox(width: 2),
                      Text(
                        'Completed job',
                        style: TextStyle(
                          color: Color(0xFF17A868),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                _text(review['daysAgo']),
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (rating > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  Icons.star_rounded,
                  color:
                      i < rating ? AppTheme.orange500 : const Color(0xFFDDE3EC),
                  size: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _text(review['text']),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tags,
              style: const TextStyle(
                color: AppTheme.teal700,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStickyFooterBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEFF2), width: 1)),
      ),
      child: _centeredFrame(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(_contentInset, 10, _contentInset, 10),
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
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Upfront price estimate',
                      style: TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 146,
                height: 50,
                child: ElevatedButton(
                  onPressed: _openBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Book this pro',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    String? trailing,
    bool boxed = false,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        boxed
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: _softPanel,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: child,
              )
            : child,
      ],
    );
  }

  Widget _overviewRow(
    IconData icon,
    String text, {
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _twoColumnRow(MapEntry<String, String> row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              row.key,
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(
                color: AppTheme.navy700,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppTheme.tealTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.teal700,
          fontSize: 6.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

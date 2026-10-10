import '../widgets/loading_skeleton.dart';
import '../widgets/review_annotations.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../widgets/app_notification.dart';
import '../widgets/capsules.dart';
import '../ui/tw.dart';
import '../utils/display_format.dart';
import 'book_flow.dart';
import 'chat_screen.dart';
import 'login_page.dart';

String _shortBusinessName(String name) =>
    name.replaceFirst(RegExp(r' Co\.?$'), '');

class ProProfileScreen extends StatefulWidget {
  final Map<String, dynamic> pro;
  final String? initialDescription;

  const ProProfileScreen({
    super.key,
    required this.pro,
    this.initialDescription,
  });

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

  /// The amount with cents ("$89.00"). Empty for a Free visit.
  final String price;

  /// 'rate_card' = Upfront price · 'nte' = Cap Approval ·
  /// 'quote_request' = Free estimate.
  final String workOrderType;

  const _ProfileService({
    required this.category,
    required this.name,
    required this.price,
    this.workOrderType = 'rate_card',
  });

  /// The big part of the price: "$129.00", "$89.00", "Free visit".
  String get amount => switch (workOrderType) {
        'quote_request' => 'Free visit',
        'nte' => price.isEmpty ? 'Diagnostic' : price,
        _ => price,
      };

  /// The word after the amount: "diagnostic" for Cap Approval, else none.
  String get amountSuffix =>
      workOrderType == 'nte' && price.isNotEmpty ? 'diagnostic' : '';

  /// The only place a service's price is worded (TW-SHARED-DECISIONS §2):
  /// "$129.00", "$89.00 diagnostic", "Free visit". Never "From $…".
  String get headline =>
      amountSuffix.isEmpty ? amount : '$amount $amountSuffix';

  String get typeLabel => switch (workOrderType) {
        'nte' => 'You approve the cap',
        'quote_request' => 'The pro sends you an estimate',
        _ => 'Upfront price',
      };
}

class _FigmaProfileSurface extends StatelessWidget {
  // Values taken from the supplied ProProfile_Top Figma frame.
  static const Color _ink = AppTheme.navy;
  static const Color _muted = AppTheme.textSecondary;
  static const Color _line = AppTheme.cardBorder;
  static const Color _green = AppTheme.green;

  final String businessName;
  final String category;
  final String service;
  final String requestZip;

  /// Identity meta: the pro's categories ("Plumbing · AC / HVAC ·
  /// Electrical · +2 more"). No distance, no "Serves {ZIP}" (settled Oct 1).
  final String categoryLine;

  /// Price-card amount ("$89.00", "$129.00", "Free visit") and the word after
  /// it ("diagnostic" for Cap Approval, else empty). Never "From".
  final String price;
  final String priceSuffix;

  /// "AC repair · You approve the cap"
  final String priceDetail;

  /// What happens next, for Cap Approval and Free estimate only.
  final String priceNote;

  /// Bottom-bar caption: "Upfront price" / "You approve the cap" /
  /// "The pro sends you an estimate".
  final String priceTypeLabel;
  final String nextSlot;
  final String rating;
  final String reviewCount;
  final String? profileImageUrl;
  final String tagline;
  final String about;
  final List<String> mediaUrls;
  final int mediaCount;
  final VoidCallback onSeeAllPhotos;
  final List<_ProfileFact> overview;
  final List<MapEntry<String, String>> hours;
  final String timeZone;
  final List<MapEntry<String, String>> responseTimes;
  final List<_ProfileService> services;

  /// The searched service's category; the list opens on it.
  final String searchedCategory;
  final bool showAllServices;
  final VoidCallback onShowAllServices;

  /// "card", "check", "cash" … from Public profile › How customers can pay
  /// you. Empty hides How you pay.
  final List<String> paymentMethods;
  final Map<int, double> ratingBreakdown;
  final List<Map<String, dynamic>> reviews;
  final bool loading;
  final bool bookActionLoading;
  final String bookActionLabel;
  final VoidCallback onBack;
  final VoidCallback onBook;
  final VoidCallback onMessage;
  final VoidCallback onSeeAllReviews;
  final ScrollController scrollController;

  const _FigmaProfileSurface({
    required this.businessName,
    required this.category,
    required this.service,
    required this.requestZip,
    required this.categoryLine,
    required this.price,
    required this.priceSuffix,
    required this.priceDetail,
    required this.priceNote,
    required this.priceTypeLabel,
    required this.nextSlot,
    required this.rating,
    required this.reviewCount,
    required this.profileImageUrl,
    required this.tagline,
    required this.about,
    required this.mediaUrls,
    required this.mediaCount,
    required this.onSeeAllPhotos,
    required this.overview,
    required this.hours,
    required this.timeZone,
    required this.responseTimes,
    required this.services,
    required this.searchedCategory,
    required this.showAllServices,
    required this.onShowAllServices,
    required this.paymentMethods,
    required this.ratingBreakdown,
    required this.reviews,
    required this.loading,
    required this.bookActionLoading,
    required this.bookActionLabel,
    required this.onBack,
    required this.onBook,
    required this.onMessage,
    required this.onSeeAllReviews,
    required this.scrollController,
  });

  /// "32 reviews" / "1 review".
  String get _reviewsLabel =>
      '$reviewCount ${reviewCount == '1' ? 'review' : 'reviews'}';

  bool get _hasPriceCard => price.isNotEmpty || nextSlot.isNotEmpty;

  /// The searched service's category first; the rest sit behind
  /// "See all N services" (B02b).
  List<_ProfileService> get _visibleServices {
    if (showAllServices || searchedCategory.isEmpty) return services;
    final inCategory =
        services.where((s) => s.category == searchedCategory).toList();
    return inCategory.isEmpty ? services : inCategory;
  }

  bool get _servicesTrimmed => _visibleServices.length < services.length;

  bool get _hasRating =>
      (num.tryParse(rating) ?? 0) > 0 && (num.tryParse(reviewCount) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: loading
                  ? const SafeArea(
                      top: false,
                      child: SkeletonPage(
                          layout: SkeletonLayout.profile,
                          label: 'Loading pro profile'),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        TwPage(
                          top: TwSpace.s4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _identity(context),
                              const SizedBox(height: TwSpace.s20),
                              if (_hasPriceCard) ...[
                                _priceCard(context),
                                const SizedBox(height: TwSpace.s12),
                              ],
                              _requestCard(),
                              if (_hasAboutContent) ...[
                                const SizedBox(height: TwSpace.s28),
                                _section('About this pro', _about()),
                              ],
                              if (mediaUrls.isNotEmpty) ...[
                                const SizedBox(height: TwSpace.s28),
                                _mediaSection(),
                              ],
                              if (overview.isNotEmpty) ...[
                                const SizedBox(height: TwSpace.s28),
                                _section('Overview', _factsPanel()),
                              ],
                              if (hours.isNotEmpty) ...[
                                const SizedBox(height: TwSpace.s28),
                                _section('Business hours', _hoursPanel()),
                              ],
                              if (responseTimes.isNotEmpty) ...[
                                const SizedBox(height: TwSpace.s28),
                                _section('Response times', _responsePanel(),
                                    trailing:
                                        'Set by ${_shortBusinessName(businessName)}'),
                              ],
                              if (services.isNotEmpty) ...[
                                const SizedBox(height: TwSpace.s28),
                                _section(
                                  'Services & prices',
                                  _servicesSection(),
                                  trailing: _servicesTrimmed
                                      ? searchedCategory
                                      : null,
                                ),
                              ],
                              if (paymentMethods.isNotEmpty) ...[
                                const SizedBox(height: TwSpace.s28),
                                _section('How you pay', _howYouPay()),
                              ],
                              if (_hasRating) ...[
                                const SizedBox(height: TwSpace.s28),
                                _reviewSection(context),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            if (!loading) _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(TwSpace.s12, TwSpace.s12, TwSpace.s12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
        ),
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final compact = TwLayout.size(context) == TwSize.compact;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TwAvatar(
          name: businessName,
          imageUrl: profileImageUrl,
          size: compact ? 56 : 64,
        ),
        const SizedBox(width: TwSpace.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // B02b: Outfit 24/30 700 — the h1 face at the mockup's size.
              Text(
                businessName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TwType.h1Sm(),
              ),
              if (categoryLine.isNotEmpty) ...[
                const SizedBox(height: TwSpace.s4),
                Text(categoryLine, style: TwType.meta()),
              ],
              if (_hasRating) ...[
                const SizedBox(height: TwSpace.s8),
                RatingCapsule(
                  rating: num.parse(rating),
                  count: num.parse(reviewCount).toInt(),
                  compact: compact,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceCard(BuildContext context) {
    final stack = TwLayout.stackRows(context);
    final Widget? capsule = nextSlot.isEmpty
        ? null
        : Container(
            width: 112,
            padding: const EdgeInsets.symmetric(
                horizontal: TwSpace.s8, vertical: TwSpace.s4),
            decoration: BoxDecoration(
              color: AppTheme.greenTint,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppTheme.green),
              const SizedBox(width: TwSpace.s4),
              Expanded(
                child: Text('Next:\n$nextSlot',
                    style: TwType.caption(color: AppTheme.green)
                        .copyWith(fontWeight: FontWeight.w600, height: 1.05)),
              ),
            ]),
          );
    // B02b: "$89.00" in display type, "diagnostic" after it in value type.
    final Widget amount = price.isEmpty
        ? const SizedBox.shrink()
        : Text.rich(
            TextSpan(
              text: price,
              style: TwType.display(context),
              children: [
                if (priceSuffix.isNotEmpty)
                  TextSpan(text: '  $priceSuffix', style: TwType.value()),
              ],
            ),
          );
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: amount),
              if (capsule != null && !stack) ...[
                const SizedBox(width: TwSpace.s12),
                Padding(
                  padding: const EdgeInsets.only(top: TwSpace.s4),
                  child: capsule,
                ),
              ],
            ],
          ),
          if (capsule != null && stack) ...[
            const SizedBox(height: TwSpace.s8),
            capsule,
          ],
          if (priceDetail.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s8),
            Text(priceDetail, style: TwType.label()),
          ],
          if (priceNote.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s4),
            Text(priceNote, style: TwType.meta()),
          ],
        ],
      ),
    );
  }

  Widget _requestCard() {
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: TwSpace.s12,
            runSpacing: TwSpace.s4,
            children: [
              Text('Your project request', style: TwType.h3()),
              if (service.isNotEmpty)
                Text(
                    [service, requestZip]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: TwType.meta()),
            ],
          ),
          const SizedBox(height: TwSpace.s12),
          _bookButton(),
          const SizedBox(height: TwSpace.s12),
          Text(
              "Books directly on ${_shortBusinessName(businessName)}'s calendar",
              textAlign: TextAlign.center,
              style: TwType.caption()),
          const SizedBox(height: TwSpace.s12),
          TwSecondaryButton(
            label: 'Message',
            onPressed: onMessage,
            icon: Icons.chat_bubble_outline_rounded,
            height: 52,
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {String? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: TwType.h2())),
            if (trailing != null) ...[
              const SizedBox(width: TwSpace.s12),
              Flexible(
                  child: Text(trailing,
                      textAlign: TextAlign.right, style: TwType.caption())),
            ],
          ],
        ),
        const SizedBox(height: TwSpace.s12),
        child,
      ],
    );
  }

  bool get _hasAboutContent => tagline.isNotEmpty || about.isNotEmpty;

  Widget _about() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tagline.isNotEmpty) Text(tagline, style: TwType.h3()),
          if (tagline.isNotEmpty && about.isNotEmpty)
            const SizedBox(height: TwSpace.s8),
          if (about.isNotEmpty) Text(about, style: TwType.body()),
        ],
      );

  Widget _mediaSection() {
    // Photos only: the completion gate collects photos, not video.
    final previewCount = mediaUrls.length < 2 ? mediaUrls.length : 2;
    return _section(
      'Recent work',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final tile = (constraints.maxWidth - 2 * gap) / 3;
            return SizedBox(
              height: tile,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                itemCount: previewCount + 1,
                separatorBuilder: (_, __) => const SizedBox(width: gap),
                itemBuilder: (context, index) => SizedBox(
                  width: tile,
                  height: tile,
                  child: index == previewCount
                      ? Material(
                          color: AppTheme.subtle,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius),
                            onTap: onSeeAllPhotos,
                            child: Center(
                                child: Text('See all',
                                    style: TwType.label(color: AppTheme.blue))),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: Image.network(
                            mediaUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: AppTheme.subtle),
                          ),
                        ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: TwSpace.s8),
        Text('Photos from this pro’s recent work', style: TwType.caption()),
      ]),
    );
  }

  Widget _factsPanel() => TwFactPanel(
        child: Column(
            children: List.generate(overview.length, (index) {
          final fact = overview[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == overview.length - 1 ? 0 : 14),
            child: Row(children: [
              Icon(fact.icon, color: fact.color, size: 20),
              const SizedBox(width: TwSpace.s12),
              Expanded(
                  child: Text(fact.label, style: TwType.bodySm(color: _ink)))
            ]),
          );
        })),
      );

  Widget _hoursPanel() => TwFactPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...hours.map(_keyValue),
            if (timeZone.isNotEmpty) Text(timeZone, style: TwType.caption()),
          ],
        ),
      );

  Widget _responsePanel() => TwFactPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...responseTimes.map(_keyValue),
            Text('You choose one when you book. The fee goes to the pro.',
                style: TwType.caption()),
          ],
        ),
      );

  Widget _keyValue(MapEntry<String, String> item) => Padding(
        padding: const EdgeInsets.only(bottom: TwSpace.s8),
        child: TwDetailRow(label: item.key, value: item.value),
      );

  /// One list, one place. Opens on the searched service's category; the rest
  /// sit behind "See all N services".
  Widget _servicesSection() {
    final visible = _visibleServices;
    final hasCap = visible.any((s) => s.workOrderType == 'nte');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++)
          _serviceRateRow(visible[i], last: i == visible.length - 1),
        if (hasCap) ...[
          const SizedBox(height: TwSpace.s8),
          Text('With a cap, the final price may be lower — never higher.',
              style: TwType.caption()),
        ],
        if (_servicesTrimmed) ...[
          const SizedBox(height: TwSpace.s4),
          TwTextAction(
            label: 'See all ${services.length} services',
            onPressed: onShowAllServices,
          ),
        ],
      ],
    );
  }

  Widget _serviceRateRow(_ProfileService s, {required bool last}) => Container(
        padding: const EdgeInsets.symmetric(vertical: TwSpace.s12),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: _line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(s.name, style: TwType.bodySm(color: _ink))),
          const SizedBox(width: TwSpace.s12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (s.amount.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      text: s.amount,
                      style: TwType.value(),
                      children: [
                        if (s.amountSuffix.isNotEmpty)
                          TextSpan(
                            text: ' ${s.amountSuffix}',
                            style: TwType.bodySm(color: _ink),
                          ),
                      ],
                    ),
                    textAlign: TextAlign.right,
                  ),
                Text(s.typeLabel,
                    textAlign: TextAlign.right, style: TwType.caption()),
              ],
            ),
          ),
        ]),
      );

  Widget _howYouPay() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TwIconWell(Icons.credit_card_outlined, size: 40),
          const SizedBox(width: TwSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${businessName.isEmpty ? 'This pro' : _shortBusinessName(businessName)} accepts ${_joinMethods(paymentMethods)}',
                  style: TwType.value(),
                ),
                const SizedBox(height: TwSpace.s4),
                Text(
                  'You pay your pro directly. TradeWorks adds no markup and takes no fee — we only fund the credits you apply.',
                  style: TwType.meta(),
                ),
              ],
            ),
          ),
        ],
      );

  /// "card, check or cash"
  static String _joinMethods(List<String> m) => m.length < 2
      ? m.join()
      : '${m.sublist(0, m.length - 1).join(', ')} or ${m.last}';

  Widget _reviewSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ratingCard(context),
      if (reviews.isNotEmpty) ...[
        const SizedBox(height: TwSpace.s16),
        ...reviews.take(2).map(_reviewCard),
        Center(
          child: TextButton(
            onPressed: onSeeAllReviews,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.blue,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: TwSpace.s12),
            ),
            child: Text('See all $_reviewsLabel', style: TwType.link()),
          ),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TwSpace.s20),
          child: Center(
            child: Text(
              'No written reviews yet',
              textAlign: TextAlign.center,
              style: TwType.bodySm(color: _muted),
            ),
          ),
        ),
    ]);
  }

  Widget _ratingCard(BuildContext context) {
    final compact = TwLayout.size(context) == TwSize.compact;
    return TwFactPanel(
      child: Row(children: [
        SizedBox(
            width: compact ? 96 : 118,
            child: Column(children: [
              Text(rating, style: TwType.number(context)),
              const SizedBox(height: TwSpace.s4),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star_rounded, color: AppTheme.gold, size: 16),
                Icon(Icons.star_rounded, color: AppTheme.gold, size: 16),
                Icon(Icons.star_rounded, color: AppTheme.gold, size: 16),
                Icon(Icons.star_rounded, color: AppTheme.gold, size: 16),
                Icon(Icons.star_rounded, color: AppTheme.gold, size: 16)
              ]),
              const SizedBox(height: TwSpace.s4),
              Text(_reviewsLabel,
                  textAlign: TextAlign.center, style: TwType.caption()),
            ])),
        const SizedBox(width: TwSpace.s12),
        Expanded(
            child: Column(
                children: [5, 4, 3, 2, 1].map((star) {
          final percent = ratingBreakdown[star] ?? 0;
          return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                SizedBox(
                    width: 12, child: Text('$star', style: TwType.caption())),
                const SizedBox(width: TwSpace.s8),
                Expanded(
                    child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                      value: (percent / 100).clamp(0, 1),
                      minHeight: 6,
                      color: AppTheme.gold,
                      backgroundColor: AppTheme.cardBorder),
                )),
                const SizedBox(width: TwSpace.s8),
                SizedBox(
                    width: 40,
                    child: Text('${percent.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right, style: TwType.caption()))
              ]));
        }).toList())),
      ]),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final name = (review['name'] ?? '').toString();
    final text = (review['text'] ?? '').toString();
    final tags = (review['tags'] ?? '').toString();
    final age = (review['daysAgo'] ?? '').toString();
    final stars = (review['rating'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: TwSpace.s12),
      padding: const EdgeInsets.all(TwSpace.s16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(
              spacing: TwSpace.s8,
              runSpacing: TwSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name, style: TwType.title()),
                if (review['completed'] == true)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 15, color: AppTheme.greenMark),
                      const SizedBox(width: TwSpace.s4),
                      Text('Verified job',
                          style: TwType.caption(color: _green)
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),
          if (age.isNotEmpty) ...[
            const SizedBox(width: TwSpace.s8),
            Text(age, style: TwType.caption()),
          ],
        ]),
        if (stars > 0)
          Padding(
              padding: const EdgeInsets.only(top: TwSpace.s8),
              child: Row(
                  children: List.generate(
                      5,
                      (index) => Icon(Icons.star_rounded,
                          size: 14,
                          color: index < stars
                              ? AppTheme.gold
                              : AppTheme.cardBorder)))),
        if (text.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: TwSpace.s8),
              child: Text(text, style: TwType.bodySm(color: _ink))),
        if (tags.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: TwSpace.s8),
              child: Text(tags,
                  style: TwType.caption(color: AppTheme.body)
                      .copyWith(fontWeight: FontWeight.w600))),
        ReviewAnnotations(review: review, businessName: businessName),
      ]),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final gutter = TwLayout.gutter(context);
    final inset = MediaQuery.of(context).padding.bottom;
    final stack = TwLayout.stackRows(context);
    final barPrice = priceSuffix.isEmpty ? price : '$price $priceSuffix';
    final priceBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (barPrice.isNotEmpty)
          Text.rich(
            TextSpan(text: price, style: TwType.price(), children: [
              if (priceSuffix.isNotEmpty)
                TextSpan(text: ' $priceSuffix', style: TwType.label()),
            ]),
          ),
        if (priceTypeLabel.isNotEmpty)
          Text(priceTypeLabel, style: TwType.caption()),
      ],
    );
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(gutter, TwSpace.s12, gutter, TwSpace.s12 + inset),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.floatShadow,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TwLayout.maxContent),
          child: stack
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    priceBlock,
                    const SizedBox(height: TwSpace.s12),
                    _bookButton(),
                  ],
                )
              : Row(children: [
                  Expanded(child: priceBlock),
                  const SizedBox(width: TwSpace.s12),
                  _bookButton(expand: false),
                ]),
        ),
      ),
    );
  }

  Widget _bookButton({bool expand = true}) => TwPrimaryButton(
        label: bookActionLabel,
        onPressed: onBook,
        loading: bookActionLoading,
        expand: expand,
      );
}

class _AllReviewsScreen extends StatelessWidget {
  static const Color _ink = AppTheme.navy;
  static const Color _muted = AppTheme.textSecondary;
  static const Color _line = AppTheme.cardBorder;

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
    final gutter = TwLayout.gutter(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TwAppBar(
        title: 'Reviews${businessName.isEmpty ? '' : ' for $businessName'}',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: TwLayout.maxContent + 2 * gutter),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      gutter, TwSpace.s16, gutter, TwSpace.s16),
                  child: TwFactPanel(
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppTheme.gold, size: 20),
                        const SizedBox(width: TwSpace.s8),
                        Text(rating, style: TwType.price()),
                        const SizedBox(width: TwSpace.s12),
                        Expanded(
                          child: Text(
                            '$reviewCount ${reviewCount == '1' ? 'review' : 'reviews'}',
                            style: TwType.meta(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: reviews.isEmpty
                      ? Center(
                          child: Text(
                            'No written reviews yet',
                            style: TwType.bodySm(color: _muted),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                              gutter, 0, gutter, TwSpace.s28),
                          itemCount: reviews.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: TwSpace.s12),
                          itemBuilder: (context, index) =>
                              _reviewCard(reviews[index]),
                        ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.all(TwSpace.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Verified customer' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TwType.title(),
                ),
              ),
              if (age.isNotEmpty) ...[
                const SizedBox(width: TwSpace.s8),
                Text(age, style: TwType.caption()),
              ],
            ],
          ),
          if (stars > 0) ...[
            const SizedBox(height: TwSpace.s8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star_rounded,
                  color: index < stars ? AppTheme.gold : AppTheme.cardBorder,
                  size: 14,
                ),
              ),
            ),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s8),
            Text(text, style: TwType.bodySm(color: _ink)),
          ],
          ReviewAnnotations(review: review, businessName: businessName),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s8),
            Text(
              tags,
              style: TwType.caption(color: AppTheme.body)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProProfileScreenState extends State<ProProfileScreen> {
  static const Color _success = AppTheme.green;

  bool _isLoading = true;
  bool _isStartingBooking = false;
  bool _showAllServices = false;
  Map<String, dynamic>? _profile;
  final ScrollController _profileScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_handleAuthChanged);
    _fetchProfile();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthChanged);
    _profileScrollController.dispose();
    super.dispose();
  }

  void _handleAuthChanged() {
    if (mounted) setState(() {});
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
      widget.pro['selectedService'],
      _text(
        _displayPro['selectedService'],
        _text(
          _displayPro['serviceName'],
          _text(
            _displayPro['service_name'],
            _text(_displayPro['service']),
          ),
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

  /// 'rate_card' · 'nte' · 'quote_request', or '' when not sent. Accepts the
  /// contractor-side names too ("Cap Approval", "Free estimate").
  String _workOrderType(dynamic raw) {
    final value = _text(raw).toLowerCase();
    if (value.isEmpty) return '';
    if (value == 'nte' || value.contains('cap')) return 'nte';
    if (value.contains('quote') ||
        value.contains('estimate') ||
        value.contains('free')) {
      return 'quote_request';
    }
    return 'rate_card';
  }

  /// The searched service as the search result described it — used when the
  /// profile's own list doesn't carry that service.
  _ProfileService? get _searchResultService {
    final name = _serviceLabel;
    final type = _workOrderType(
        widget.pro['workOrderType'] ?? widget.pro['work_order_type']);
    final price = _money2(widget.pro['fromPrice'] ??
        widget.pro['from_price'] ??
        widget.pro['price']);
    if (name.isEmpty || (price.isEmpty && type != 'quote_request')) {
      return null;
    }
    return _ProfileService(
      category: _category.isEmpty ? 'Services' : _category,
      name: name,
      price: type == 'quote_request' ? '' : price,
      workOrderType: type.isEmpty ? 'rate_card' : type,
    );
  }

  /// The service the homeowner searched for, else the first listed service.
  _ProfileService? get _searchedService {
    final services = _services;
    final wanted = _serviceLabel.toLowerCase();
    for (final s in services) {
      if (s.name.toLowerCase() == wanted) return s;
    }
    return _searchResultService ?? (services.isEmpty ? null : services.first);
  }

  /// Price-card amount: "$129.00", "$89.00", "Free visit".
  String get _price => _searchedService?.amount ?? '';

  /// "diagnostic" for Cap Approval, else empty.
  String get _priceSuffix => _searchedService?.amountSuffix ?? '';

  /// "AC repair · You approve the cap"
  String get _priceDetail {
    final s = _searchedService;
    return s == null ? '' : '${s.name} · ${s.typeLabel}';
  }

  /// Bottom-bar caption: "Upfront price" / "You approve the cap" /
  /// "The pro sends you an estimate".
  String get _priceTypeLabel => _searchedService?.typeLabel ?? '';

  /// What happens next, for the two types that are not a fixed price
  /// (B02b; decisions §2).
  String get _priceNote {
    final who =
        _businessName.isEmpty ? 'The pro' : _shortBusinessName(_businessName);
    return switch (_searchedService?.workOrderType) {
      'nte' =>
        '$who diagnoses the problem, then sends you a not-to-exceed cap to approve before any repair starts.',
      'quote_request' =>
        '$who visits for free, then sends you an estimate to accept or decline.',
      _ => '',
    };
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

  /// "Plumbing · AC / HVAC · Electrical · +2 more". No distance (the
  /// platform never measures it) and no "Serves {ZIP}" (settled Oct 1).
  String get _categoryLine {
    final categories = <String>[];
    void add(dynamic value) {
      final map = _asMap(value);
      final name =
          map.isEmpty ? _text(value) : _text(map['name'], _text(map['label']));
      if (name.isNotEmpty && !categories.contains(name)) categories.add(name);
    }

    for (final item in _asList(_displayPro['categories'])) {
      add(item);
    }
    if (categories.isEmpty) {
      for (final service in _services) {
        if (service.category != 'Services') add(service.category);
      }
    }
    if (categories.isEmpty) add(_category);
    if (categories.length <= 3) return categories.join(' · ');
    return '${categories.take(3).join(' · ')} · +${categories.length - 3} more';
  }

  static const _paymentLabels = {
    'cash': 'cash',
    'check': 'check',
    'card': 'card',
    'credit_card': 'card',
    'debit_card': 'card',
    'ach': 'bank transfer',
    'zelle': 'Zelle',
    'venmo': 'Venmo',
    'paypal': 'PayPal',
    'apple_pay': 'Apple Pay',
    'google_pay': 'Google Pay',
  };

  /// What the pro accepts, from Business › Public profile ("How customers
  /// can pay you"; TW-SHARED-DECISIONS §4). Same labels as Account ›
  /// Payment methods.
  List<String> get _paymentMethods {
    final methods = <String>[];
    for (final method in _asList(
        _displayPro['payment_methods'] ?? _displayPro['paymentMethods'])) {
      final key = _text(method).toLowerCase();
      if (key.isEmpty) continue;
      final label = _paymentLabels[key] ?? key.replaceAll('_', ' ');
      if (!methods.contains(label)) methods.add(label);
    }
    return methods;
  }

  String get _aboutText {
    return _text(
      _displayPro['about'],
      _text(
        _displayPro['description'],
        _text(_displayPro['overview'], _text(_displayPro['summary'])),
      ),
    );
  }

  String get _requestZip => _text(widget.pro['requestZip']);

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

    if (license.isNotEmpty) parts.add(license);
    if (insured == true) parts.add('Insured');
    if (backgroundChecked == true) parts.add('Background checked');
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

  List<MapEntry<String, String>> _businessHours() {
    final source =
        _displayPro['business_hours'] ?? _displayPro['businessHours'];
    final hourRows = _asList(source);
    if (hourRows.isNotEmpty) {
      final rows = hourRows
          .map((row) {
            final map = _asMap(row);
            final label = _text(
              map['day'],
              _text(map['label'], _text(map['name'])),
            );
            if (label.isEmpty) return const MapEntry('', '');
            if (map['closed'] == true) {
              return MapEntry(_dayLabel(label), 'Closed');
            }
            final value = _text(
              map['hours'],
              _text(map['time'], _text(map['value'])),
            );
            if (value.isNotEmpty) {
              return MapEntry(
                  _dayLabel(label), _formatBusinessHourRange(value));
            }
            final open = _text(map['open'], _text(map['start']));
            final close = _text(map['close'], _text(map['end']));
            if (open.isEmpty || close.isEmpty) return const MapEntry('', '');
            return MapEntry(
              _dayLabel(label),
              '${_formatBusinessHourTime(open)} – ${_formatBusinessHourTime(close)}',
            );
          })
          .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
          .toList();
      rows.sort((left, right) =>
          _businessDayIndex(left.key).compareTo(_businessDayIndex(right.key)));
      return _groupBusinessHours(rows);
    }

    final hours = _asMap(source);
    if (hours.isEmpty) {
      return const [];
    }

    const orderedDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return _groupBusinessHours(orderedDays.map((day) {
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
    }).toList());
  }

  List<MapEntry<String, String>> _groupBusinessHours(
      List<MapEntry<String, String>> rows) {
    if (rows.length != 7) return rows;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    if (List.generate(7, (index) => rows[index].key == days[index])
        .contains(false)) return rows;
    final grouped = <MapEntry<String, String>>[];
    for (var start = 0; start < rows.length;) {
      var end = start;
      while (
          end + 1 < rows.length && rows[end + 1].value == rows[start].value) {
        end++;
      }
      grouped.add(MapEntry(
        end == start
            ? rows[start].key
            : '${start == 0 ? 'Mon' : rows[start].key}–${end == 4 ? 'Fri' : rows[end].key}',
        rows[start].value,
      ));
      start = end + 1;
    }
    return grouped;
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
    if (source.toLowerCase().contains('am') ||
        source.toLowerCase().contains('pm')) {
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

  /// Response times by level (TW-SHARED-DECISIONS §5): Standard within 48
  /// hours; Urgent within 24 hours and Emergency within 4 hours, each only
  /// when the pro offers it with a fee above $0 — otherwise "Not offered".
  /// Empty when the profile carries no urgency settings (section hides).
  List<MapEntry<String, String>> _responseTimes() {
    final fees = <String, double?>{};
    final offered = <String, bool>{};
    var found = false;

    for (final tier in _itemsFromValue(
      _displayPro['response_times'] ??
          _displayPro['responseTimes'] ??
          _displayPro['urgency_tiers'] ??
          _displayPro['urgencyTiers'] ??
          _displayPro['service_levels'] ??
          _displayPro['serviceLevels'],
    )) {
      final map = _asMap(tier);
      final label = _text(
        map['urgency'],
        _text(
          map['tier'],
          _text(map['label'], _text(map['name'], _text(map['title']))),
        ),
      ).toLowerCase();
      final level = label.contains('emerg')
          ? 'emergency'
          : label.contains('urgent')
              ? 'urgent'
              : label.contains('standard')
                  ? 'standard'
                  : '';
      if (level.isEmpty) continue;
      found = true;
      fees[level] = readAmount(map['fee'] ??
          map['fee_amount'] ??
          map['feeAmount'] ??
          map['surcharge'] ??
          map['additional_fee'] ??
          map['feeLabel'] ??
          map['fee_label']);
      offered[level] =
          _boolValue(map['available'] ?? map['enabled'] ?? map['offered']) !=
              false;
    }

    // Same source the Compare screen reads.
    final em = _asMap(_displayPro['emergency']);
    if (em.isNotEmpty) {
      found = true;
      fees.putIfAbsent('urgent', () => readAmount(em['urgent_fee']));
      offered.putIfAbsent('urgent', () => em['urgent_available'] != false);
      fees.putIfAbsent('emergency', () => readAmount(em['emergency_fee']));
      offered.putIfAbsent('emergency', () => em['available'] != false);
    }
    if (!found) return const [];

    String line(String level, String window) {
      final fee = fees[level];
      if (offered[level] == false || fee == null || fee <= 0) {
        return 'Not offered';
      }
      return '$window · +${_feeText(fee)}';
    }

    return [
      const MapEntry('Standard', 'Within 48 hours'),
      MapEntry('Urgent', line('urgent', 'Within 24 hours')),
      MapEntry('Emergency', line('emergency', 'Within 4 hours')),
    ];
  }

  /// "$35" in a fee line, as on B02b; cents only when there are some.
  String _feeText(double fee) =>
      fee == fee.roundToDouble() ? '\$${fee.toInt()}' : formatUsd(fee);

  String get _tagline => _text(_displayPro['tagline']);

  /// The pro's one price list (Services & Rates), each service with its
  /// work-order type. Prices show cents ("$89.00"), as in the shared seed.
  List<_ProfileService> get _services {
    final seen = <String>{};
    final services = <_ProfileService>[];
    final searched = _serviceLabel.toLowerCase();
    final searchType = _workOrderType(
        widget.pro['workOrderType'] ?? widget.pro['work_order_type']);
    for (final item in _asList(_displayPro['services'])) {
      final service = _asMap(item);
      final status = _text(service['status']).toLowerCase();
      if ([
            service['enabled'],
            service['active'],
            service['is_active'],
            service['isActive']
          ].any((value) => _boolValue(value) == false) ||
          const {'off', 'inactive', 'pending', 'pending_approval'}
              .contains(status)) {
        continue;
      }
      final category = _text(service['category'], _category);
      final name = _text(
        service['name'],
        _text(service['service_name'], _text(service['rate_description'])),
      );
      if (name.isEmpty) continue;
      var type = _workOrderType(
          service['work_order_type'] ?? service['workOrderType']);
      if (type.isEmpty) {
        // Until the profile carries the type, the search result's type holds
        // for the searched service; everything else reads as Upfront price.
        type = name.toLowerCase() == searched && searchType.isNotEmpty
            ? searchType
            : 'rate_card';
      }
      final price = type == 'quote_request'
          ? ''
          : _money2(
              service['rate_amount'] ?? service['price'] ?? service['amount'],
            );
      if (type == 'rate_card' && price.isEmpty) continue;
      final key = '$category|$name'.toLowerCase();
      if (!seen.add(key)) continue;
      services.add(_ProfileService(
        category: category.isEmpty ? 'Services' : category,
        name: name,
        price: price,
        workOrderType: type,
      ));
    }
    return services;
  }

  /// "$89.00", or '' when there is no amount above $0.
  String _money2(dynamic value) {
    final amount = readAmount(value);
    return amount == null || amount <= 0 ? '' : formatUsd(amount);
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
          bucket['rating'] ??
              bucket['stars'] ??
              bucket['star'] ??
              bucket['key'],
        )?.round();
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
          'dateSort': review['created_at'] ??
              review['createdAt'] ??
              review['review_date'] ??
              review['date'],
          'editedAt': review['editedAt'] ?? review['edited_at'],
          'proResponse': review['proResponse'] ?? review['pro_response'],
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
            review['tags'] is List
                ? (review['tags'] as List).join(' · ')
                : review['tags'],
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
    final reviews = List<Map<String, dynamic>>.of(_reviewsList());
    reviews.sort((a, b) => (DateTime.tryParse('${b['dateSort']}') ??
            DateTime(1900))
        .compareTo(DateTime.tryParse('${a['dateSort']}') ?? DateTime(1900)));
    return reviews;
  }

  void _openAllReviews() {
    final reviews = _visibleReviews();
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
    if (_isStartingBooking) return;
    setState(() => _isStartingBooking = true);
    try {
      if (!AuthService.instance.isAuthenticated) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginPage(returnToPreviousPage: true),
          ),
        );
        if (!mounted ||
            loggedIn != true ||
            !AuthService.instance.isAuthenticated) {
          return;
        }
        unawaited(HomeownerService.instance.primeAuthenticatedCache());
      }

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final result = await navigator.push(
        BookFlowScreen.route<Object?>(
          initialDescription: widget.initialDescription,
          pro: _displayPro,
        ),
      );
      if (result == BookFlowExit.changeContractor && mounted) {
        navigator.pop(BookFlowExit.changeContractor);
        return;
      }
      if (result == true && mounted) {
        navigator.pop(true);
      }
    } finally {
      if (mounted) setState(() => _isStartingBooking = false);
    }
  }

  void _openAllPhotos() {
    final urls = _mediaUrls;
    if (urls.isEmpty) return;
    Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Recent work')),
            body: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: TwLayout.maxContent),
                child: GridView.builder(
                  padding: EdgeInsets.all(TwLayout.gutter(context)),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: TwSpace.s12,
                    mainAxisSpacing: TwSpace.s12,
                  ),
                  itemCount: urls.length,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Image.network(urls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppTheme.subtle)),
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  Future<void> _openMessage(String? messageUserId) async {
    if (!AuthService.instance.isAuthenticated) {
      AppNotification.showInfo(
        context,
        'Please sign in to message this contractor.',
      );
      return;
    }
    if (messageUserId == null) {
      AppNotification.showInfo(
        context,
        'Chat is coming soon for this contractor.',
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
    final similarJobsRaw = _text(
      displayPro['similarJobsNearby'],
      _text(
        displayPro['similar_jobs_nearby'],
        _text(displayPro['nearbyJobs'], _text(displayPro['nearby_jobs'])),
      ),
    );
    final similarJobsCount = int.tryParse(similarJobsRaw);
    final similarJobs = similarJobsCount == null
        ? similarJobsRaw
        : '$similarJobsCount similar ${similarJobsCount == 1 ? 'job' : 'jobs'} ${_requestZip.isEmpty ? 'nearby' : 'done in $_requestZip'}';
    final overview = <_ProfileFact>[
      if ((int.tryParse(completed) ?? 0) > 0)
        _ProfileFact(Icons.check_circle_outline,
            '$completed jobs completed on TradeWorks', _success),
      if (similarJobs.isNotEmpty)
        _ProfileFact(Icons.map_outlined, similarJobs, AppTheme.navy),
      if (_backgroundInsuranceLine.isNotEmpty)
        _ProfileFact(Icons.verified_user_outlined, _backgroundInsuranceLine,
            AppTheme.navy),
      if (_employeeLine.isNotEmpty || _yearsLine.isNotEmpty)
        _ProfileFact(
          Icons.groups_2_outlined,
          [
            if (_employeeLine.isNotEmpty) 'Team of $_employeeLine',
            if (_yearsLine.isNotEmpty) '$_yearsLine years in business',
          ].where((item) => item.isNotEmpty).join(' · '),
          AppTheme.navy,
        ),
    ];

    return _FigmaProfileSurface(
      businessName: _businessName,
      category: _category,
      service: _serviceLabel,
      requestZip: _requestZip,
      categoryLine: _categoryLine,
      price: _price,
      priceSuffix: _priceSuffix,
      priceDetail: _priceDetail,
      priceNote: _priceNote,
      priceTypeLabel: _priceTypeLabel,
      nextSlot: _nextSlot,
      rating: _rating,
      reviewCount: _reviewCount,
      profileImageUrl: _profileImageUrl,
      tagline: _tagline,
      about: _aboutText,
      mediaUrls: _mediaUrls,
      mediaCount: _mediaCount,
      onSeeAllPhotos: _openAllPhotos,
      overview: overview,
      hours: _businessHours(),
      timeZone: _timeZoneLabel,
      responseTimes: _responseTimes(),
      services: _services,
      searchedCategory: _searchedService?.category ?? '',
      showAllServices: _showAllServices,
      onShowAllServices: () => setState(() => _showAllServices = true),
      paymentMethods: _paymentMethods,
      ratingBreakdown: _ratingBreakdown(),
      reviews: _visibleReviews(),
      loading: _isLoading,
      bookActionLoading: _isStartingBooking,
      bookActionLabel: 'Book appointment',
      onBack: () => Navigator.pop(context),
      onBook: _openBooking,
      onMessage: () => _openMessage(
        StreamService.instance.resolveMessagingUserId(displayPro),
      ),
      onSeeAllReviews: _openAllReviews,
      scrollController: _profileScrollController,
    );
  }
}

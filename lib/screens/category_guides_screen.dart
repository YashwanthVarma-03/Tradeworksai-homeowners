import '../widgets/loading_skeleton.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../theme.dart';
import '../ui/tw.dart';

const _supportPhoneUri = 'tel:8134777350';

class CategoryGuidesScreen extends StatefulWidget {
  final Future<void> Function(String category)? onBrowseCategory;

  const CategoryGuidesScreen({
    super.key,
    this.onBrowseCategory,
  });

  @override
  State<CategoryGuidesScreen> createState() => _CategoryGuidesScreenState();
}

class _CategoryGuidesScreenState extends State<CategoryGuidesScreen> {
  late final Future<List<CategoryGuideArticle>> _articlesFuture;
  String _activeKind = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _articlesFuture = CategoryGuideRepository.loadArticles();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: TwAppBar(title: 'Homeowner Guides'),
      body: FutureBuilder<List<CategoryGuideArticle>>(
        future: _articlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SkeletonPage(layout: SkeletonLayout.cards);
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(TwLayout.gutter(context)),
                child: Text(
                  'Unable to load category guides.',
                  style: TwType.bodySm(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final articles = snapshot.data!;
          final filteredArticles = articles.where((article) {
            final matchesKind =
                _activeKind == 'all' || article.kind == _activeKind;
            final query = _query.trim().toLowerCase();
            final matchesQuery = query.isEmpty ||
                article.title.toLowerCase().contains(query) ||
                article.subtitle.toLowerCase().contains(query) ||
                article.primaryKeyword.toLowerCase().contains(query);
            return matchesKind && matchesQuery;
          }).toList();
          final generalCount =
              articles.where((article) => article.kind == 'general').length;
          final categoryCount =
              articles.where((article) => article.kind == 'category').length;
          return SingleChildScrollView(
            child: TwPage(
              top: TwSpace.s20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GuidesHeroCard(
                    count: articles.length,
                    generalCount: generalCount,
                    categoryCount: categoryCount,
                  ),
                  const SizedBox(height: TwSpace.s20),
                  _GuideSearchAndTabs(
                    activeKind: _activeKind,
                    generalCount: generalCount,
                    categoryCount: categoryCount,
                    onKindChanged: (kind) {
                      setState(() {
                        _activeKind = kind;
                      });
                    },
                    onQueryChanged: (query) {
                      setState(() {
                        _query = query;
                      });
                    },
                  ),
                  const SizedBox(height: TwSpace.s20),
                  ...filteredArticles.map(
                    (article) => Padding(
                      padding: const EdgeInsets.only(bottom: TwSpace.s12),
                      child: _GuideListCard(
                        article: article,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryGuideDetailScreen(
                                article: article,
                                onBrowseCategory: widget.onBrowseCategory,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryGuideDetailScreen extends StatelessWidget {
  final CategoryGuideArticle article;
  final Future<void> Function(String category)? onBrowseCategory;

  const CategoryGuideDetailScreen({
    super.key,
    required this.article,
    this.onBrowseCategory,
  });

  @override
  Widget build(BuildContext context) {
    final serviceCategory = article.serviceCategory;
    Future<void> browse() async {
      if (onBrowseCategory != null) {
        await onBrowseCategory!(serviceCategory);
      }
    }

    // B04: flat page under a centred app bar (was a floating shadowed card
    // with a left-aligned 15pt title). TwPage gives the gutter and caps the
    // article at 560 on Wide.
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: TwAppBar(title: serviceCategory),
      bottomNavigationBar: TwStickyBar(
        children: [
          TwSecondaryButton(
            label: 'Call support',
            height: 52,
            onPressed: () => launchUrlString(_supportPhoneUri),
          ),
          TwPrimaryButton(
            label: 'Browse $serviceCategory',
            onPressed: browse,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: TwPage(
          top: TwSpace.s20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ArticleTopBar(article: article),
              _ArticleHeader(article: article),
              const SizedBox(height: TwSpace.s20),
              _TocCard(article: article),
              for (int i = 0; i < article.sections.length; i++)
                _ArticleSectionCard(
                  section: article.sections[i],
                  index: i,
                ),
              _FaqCard(article: article),
              const SizedBox(height: TwSpace.s28),
              _ArticleCtaCard(
                article: article,
                onBrowseTap: browse,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryGuideRepository {
  static Future<List<CategoryGuideArticle>> loadArticles() async {
    final raw =
        await rootBundle.loadString('assets/data/homeowner_guides.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final articles = (decoded['articles'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CategoryGuideArticle.fromJson)
        .toList();
    return articles;
  }
}

class CategoryGuideArticle {
  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String slug;
  final String primaryKeyword;
  final String metaDescription;
  final String wordTarget;
  final String ctaTitle;
  final String ctaBody;
  final List<CategoryGuideSection> sections;
  final List<CategoryGuideFaq> faqs;
  final List<CategoryGuideImageSpec> imageSpecs;

  const CategoryGuideArticle({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.slug,
    required this.primaryKeyword,
    required this.metaDescription,
    required this.wordTarget,
    required this.ctaTitle,
    required this.ctaBody,
    required this.sections,
    required this.faqs,
    required this.imageSpecs,
  });

  factory CategoryGuideArticle.fromJson(Map<String, dynamic> json) {
    return CategoryGuideArticle(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'category',
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      slug: json['slug'] as String,
      primaryKeyword: json['primaryKeyword'] as String? ?? '',
      metaDescription: json['metaDescription'] as String,
      wordTarget: json['wordTarget'] as String,
      ctaTitle: json['ctaTitle'] as String? ?? '',
      ctaBody: json['ctaBody'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CategoryGuideSection.fromJson)
          .toList(),
      faqs: (json['faqs'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CategoryGuideFaq.fromJson)
          .toList(),
      imageSpecs: (json['imageSpecs'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(CategoryGuideImageSpec.fromJson)
          .toList(),
    );
  }

  String get serviceCategory {
    if (isGeneral) {
      return 'Home Services';
    }
    final normalized = title
        .replaceAll(": A Homeowner's Guide", '')
        .replaceAll(' Services', '')
        .replaceAll(
            'The Year-Round Home Maintenance Checklist', 'Home Services')
        .replaceAll('How Home Service Pricing Works', 'Home Services')
        .trim();
    const aliases = {
      'Handyman': 'Handyman',
      'HVAC': 'HVAC',
      'Air Duct & Vent': 'HVAC',
      'Pool & Spa': 'Pool & Spa',
      'Landscaping & Lawn Care': 'Landscaping',
      'Tree Service': 'Tree Service',
      'Pressure Washing & Exterior Cleaning': 'Cleaning',
      'Drywall & Plaster': 'Drywall & Plaster',
      'Windows & Doors': 'Windows & Doors',
      'Screen Repair & Enclosures': 'Screen Repair',
      'Moving & Hauling': 'Moving',
      'Fencing & Decks': 'Fencing & Decks',
      'Concrete & Masonry': 'Concrete & Masonry',
      'Remodeling & Construction': 'Remodeling',
      'Home Security & Smart Home': 'Home Security',
      'Insulation & Weatherization': 'Insulation',
      'Water Treatment': 'Water Treatment',
      'Fireplace & Chimney': 'Fireplace & Chimney',
    };
    return aliases[normalized] ?? normalized;
  }

  String get kindLabel =>
      kind == 'general' ? 'General guide' : 'Category guide';

  bool get isGeneral => kind == 'general';

  List<CategoryGuideSection> get tocSections => sections
      .where((section) => section.heading.trim().isNotEmpty)
      .take(10)
      .toList();
}

class CategoryGuideSection {
  final String heading;
  final List<String> paragraphs;

  const CategoryGuideSection({
    required this.heading,
    required this.paragraphs,
  });

  factory CategoryGuideSection.fromJson(Map<String, dynamic> json) {
    return CategoryGuideSection(
      heading: json['heading'] as String? ?? '',
      paragraphs: (json['paragraphs'] as List<dynamic>).cast<String>(),
    );
  }
}

class CategoryGuideFaq {
  final String question;
  final String answer;

  const CategoryGuideFaq({
    required this.question,
    required this.answer,
  });

  factory CategoryGuideFaq.fromJson(Map<String, dynamic> json) {
    return CategoryGuideFaq(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }
}

class CategoryGuideImageSpec {
  final String slot;
  final String subject;
  final String dimensions;
  final String format;
  final String alt;

  const CategoryGuideImageSpec({
    required this.slot,
    required this.subject,
    required this.dimensions,
    required this.format,
    required this.alt,
  });

  factory CategoryGuideImageSpec.fromJson(Map<String, dynamic> json) {
    return CategoryGuideImageSpec(
      slot: json['slot'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      dimensions: json['dimensions'] as String? ?? '',
      format: json['format'] as String? ?? '',
      alt: json['alt'] as String? ?? '',
    );
  }
}

class _GuidesHeroCard extends StatelessWidget {
  final int count;
  final int generalCount;
  final int categoryCount;

  const _GuidesHeroCard({
    required this.count,
    required this.generalCount,
    required this.categoryCount,
  });

  // Flat page header, same pattern as the B04 article header (eyebrow,
  // Outfit h1, reading text) — no card, no blue eyebrow.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TradeWorks Homeowner Guides', style: TwType.caption()),
        const SizedBox(height: 10),
        Text(
          'Helpful guides for every home project',
          style: TwType.h1(context),
        ),
        const SizedBox(height: TwSpace.s8),
        Text(
          'Browse $generalCount homeowner guides and $categoryCount service category guides with practical advice, FAQs, pricing context, safety notes, and quick ways to book vetted pros.',
          style: TwType.bodySm(),
        ),
      ],
    );
  }
}

class _GuideSearchAndTabs extends StatelessWidget {
  final String activeKind;
  final int generalCount;
  final int categoryCount;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onQueryChanged;

  const _GuideSearchAndTabs({
    required this.activeKind,
    required this.generalCount,
    required this.categoryCount,
    required this.onKindChanged,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onQueryChanged,
          style: TwType.body(color: AppTheme.navy),
          decoration: TwInputs.decoration(
            hint: 'Search guides',
            prefix: const Icon(Icons.search, size: 20, color: AppTheme.navy),
          ),
        ),
        const SizedBox(height: TwSpace.s12),
        // Pills (blue tint when selected) replace the navy-filled tabs with
        // white labels; they wrap on Compact instead of squeezing.
        Wrap(
          spacing: TwSpace.s8,
          runSpacing: TwSpace.s8,
          children: [
            TwPill(
              label: 'All (${generalCount + categoryCount})',
              selected: activeKind == 'all',
              onTap: () => onKindChanged('all'),
            ),
            TwPill(
              label: 'General ($generalCount)',
              selected: activeKind == 'general',
              onTap: () => onKindChanged('general'),
            ),
            TwPill(
              label: 'Category ($categoryCount)',
              selected: activeKind == 'category',
              onTap: () => onKindChanged('category'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideListCard extends StatelessWidget {
  final CategoryGuideArticle article;
  final VoidCallback onTap;

  const _GuideListCard({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TwCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Was a navy-to-blue gradient tile with a white number.
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(TwSpace.s4),
            decoration: BoxDecoration(
              color: AppTheme.subtle,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                article.id.replaceAll('CAT-', '').replaceAll('GEN-', ''),
                style: TwType.h3(),
              ),
            ),
          ),
          const SizedBox(width: TwSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title, style: TwType.h3()),
                const SizedBox(height: TwSpace.s4),
                Text(
                  '${article.kindLabel} · ${article.subtitle}',
                  style: TwType.meta(),
                ),
                const SizedBox(height: TwSpace.s8),
                Text(
                  article.metaDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TwType.bodySm(),
                ),
              ],
            ),
          ),
          const SizedBox(width: TwSpace.s8),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _ArticleTopBar extends StatelessWidget {
  final CategoryGuideArticle article;

  const _ArticleTopBar({required this.article});

  @override
  Widget build(BuildContext context) {
    return Text(
      'TradeWorks Homeowner Guide · ${article.kindLabel}',
      style: TwType.caption(),
    );
  }
}

class _ArticleHeader extends StatelessWidget {
  final CategoryGuideArticle article;

  const _ArticleHeader({required this.article});

  @override
  Widget build(BuildContext context) {
    final overview =
        article.sections.isNotEmpty ? article.sections.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(article.title, style: TwType.h1(context)),
        const SizedBox(height: 10),
        // B04: body grey 16/600 (was blue).
        Text(
          article.subtitle,
          style: TwType.body().copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        const _ImagePlaceholder(),
        if (overview != null && overview.paragraphs.isNotEmpty) ...[
          const SizedBox(height: TwSpace.s16),
          // B04: "Quick answer" is a navy 14/600 label on a grey panel (was
          // a tracked blue eyebrow on a blue gradient).
          TwFactPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick answer', style: TwType.label()),
                const SizedBox(height: 6),
                Text(
                  overview.paragraphs.first,
                  style: TwType.body(color: AppTheme.navy),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TocCard extends StatelessWidget {
  final CategoryGuideArticle article;

  const _TocCard({required this.article});

  // B04: grey panel, "Contents" 14/600, navy 14/500 outline chips (was a
  // 12pt tracked label and blue 12.5 chips). Chips wrap their text on
  // Compact rather than clipping.
  @override
  Widget build(BuildContext context) {
    return TwFactPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contents', style: TwType.label()),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: TwSpace.s8,
            spacing: TwSpace.s8,
            children: [
              for (int i = 0; i < article.tocSections.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: TwSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    '${i + 1}. ${article.tocSections[i].heading}',
                    style: TwType.meta(color: AppTheme.navy)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArticleSectionCard extends StatelessWidget {
  final CategoryGuideSection section;
  final int index;

  const _ArticleSectionCard({
    required this.section,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isOverview = index == 0;
    final paragraphs =
        (isOverview ? section.paragraphs.skip(1) : section.paragraphs).toList();
    // B04: sections are 28 apart (20 after Contents for the rest of the
    // overview), heading h2 20/26, 12 between every block.
    final blocks = <Widget>[
      if (!isOverview) Text(section.heading, style: TwType.h2()),
      for (final paragraph in paragraphs)
        if (_isBulletLike(paragraph))
          _BulletRow(text: paragraph)
        else if (_isAlertLike(paragraph))
          _AlertCallout(text: paragraph)
        else
          Text(paragraph, style: TwType.body()),
      ..._moduleForSection(section),
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: isOverview ? TwSpace.s20 : TwSpace.s28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: TwSpace.s12),
            blocks[i],
          ],
        ],
      ),
    );
  }

  List<Widget> _moduleForSection(CategoryGuideSection section) {
    final heading = section.heading.toLowerCase();
    if (heading.contains('spring') ||
        heading.contains('summer') ||
        heading.contains('fall') ||
        heading.contains('winter')) {
      return [_SeasonModule(heading: section.heading)];
    }
    if (heading.contains('frequency') || heading.contains('at a glance')) {
      return const [_FrequencyModule()];
    }
    if (heading.contains('diy') || heading.contains('call a pro')) {
      return const [_DiyVsProModule()];
    }
    if (heading.contains('tradeworks') ||
        heading.contains('helps') ||
        heading.contains('keep track')) {
      return const [_AiExperienceModule()];
    }
    if (heading.contains('cost') ||
        heading.contains('pricing') ||
        heading.contains('quote')) {
      return const [_PricingModule()];
    }
    return const [];
  }

  bool _isBulletLike(String text) {
    const prefixes = [
      'A breaker',
      'A dead',
      'A warm',
      'Any ',
      'Breakers',
      'Outlets',
      'Flickering',
      'Licensed',
      'Pulls',
      'Well-reviewed',
      'Transparent',
      'Kitchen.',
      'Bathrooms.',
      'Living areas.',
      'Bedrooms.',
      'Exterior.',
      'Entry.',
      'Garage.',
      'Laundry.',
      'Patio.',
      'Pool area.',
      'Watch for',
      'Know your',
      'Keep up',
      'Protect',
      'Test your',
    ];
    return prefixes.any(text.startsWith) && text.length < 220;
  }

  bool _isAlertLike(String text) {
    final lowered = text.toLowerCase();
    return lowered.contains('emergency') ||
        lowered.contains('urgent') ||
        lowered.contains('never diy') ||
        lowered.startsWith('a quick');
  }
}

class _BulletRow extends StatelessWidget {
  final String text;

  const _BulletRow({required this.text});

  // Spacing between rows now comes from the parent list.
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: AppTheme.subtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 12,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TwType.bodySm()),
        ),
      ],
    );
  }
}

class _AlertCallout extends StatelessWidget {
  final String text;

  const _AlertCallout({required this.text});

  // B04 + Batch 21 R9: white hairline card, amber icon in an amber-tint
  // well, navy title, body-colour text (was a gold icon and amber text on an
  // amber gradient).
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TwIconWell(
            Icons.warning_amber_rounded,
            background: AppTheme.amberTint,
            color: AppTheme.amber,
          ),
          const SizedBox(width: TwSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safety note', style: TwType.title()),
                const SizedBox(height: TwSpace.s4),
                Text(text, style: TwType.meta(color: AppTheme.body)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonModule extends StatelessWidget {
  final String heading;

  const _SeasonModule({required this.heading});

  @override
  Widget build(BuildContext context) {
    final lower = heading.toLowerCase();
    final seasons = lower.contains('fall') || lower.contains('winter')
        ? const [
            _SeasonData(
              title: 'Fall',
              color: AppTheme.amber,
              tasks: [
                'Service the heating system before cold weather',
                'Clean gutters again after leaf-fall',
                'Winterize outdoor faucets and sprinklers',
                'Inspect chimney, insulation, and weatherstripping',
              ],
              proLine:
                  'Book a pro for furnace service, gutters, chimney, or insulation',
            ),
            _SeasonData(
              title: 'Winter',
              color: AppTheme.blue,
              tasks: [
                'Protect exposed pipes from freezing',
                'Watch gutters and rooflines after storms',
                'Change HVAC filters and monitor humidity',
                'Test sump pumps before heavy rain',
              ],
              proLine:
                  'Book a pro for plumbing, heating, roofing, or insulation',
            ),
          ]
        : const [
            _SeasonData(
              title: 'Spring',
              color: AppTheme.green,
              tasks: [
                'Inspect roof, flashing, siding, and exterior paint',
                'Clean gutters and downspouts',
                'Service the AC before the first heat wave',
                'Check faucets, sprinklers, deck, and detectors',
              ],
              proLine: 'Book a pro for AC tune-up, roof inspection, or gutters',
            ),
            _SeasonData(
              title: 'Summer',
              color: AppTheme.gold,
              tasks: [
                'Replace HVAC filters during heavy-use months',
                'Pressure wash walkways, driveway, and siding',
                'Trim trees and shrubs back from the home',
                'Check leaks, GFCI outlets, pests, and seals',
              ],
              proLine:
                  'Book a pro for pressure washing, trees, or pest control',
            ),
          ];
    return _ResponsiveModuleGrid(
      children: seasons.map((season) => _SeasonCard(data: season)).toList(),
    );
  }
}

class _SeasonData {
  final String title;
  final Color color;
  final List<String> tasks;
  final String proLine;

  const _SeasonData({
    required this.title,
    required this.color,
    required this.tasks,
    required this.proLine,
  });
}

class _SeasonCard extends StatelessWidget {
  final _SeasonData data;

  const _SeasonCard({required this.data});

  // Hairline card with an h3 title (was a coloured header band with a white
  // label). Colour is kept for status only, so data.color is no longer drawn.
  @override
  Widget build(BuildContext context) {
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, style: TwType.h3()),
          const SizedBox(height: TwSpace.s12),
          for (final task in data.tasks) ...[
            _BulletRow(text: task),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          Text(data.proLine, style: TwType.meta()),
        ],
      ),
    );
  }
}

class _FrequencyModule extends StatelessWidget {
  const _FrequencyModule();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Monthly', 'HVAC filter, detector test, range hood, leak scan'),
      ('Quarterly', 'GFCI outlets, unused drains, caulk, water heater area'),
      (
        'Twice a year',
        'AC and heat service, gutter cleaning, detector batteries'
      ),
      (
        'Annually',
        'Roof inspection, chimney sweep, dryer vent, pressure washing'
      ),
      ('After a storm', 'Extra roof, exterior, tree, and drainage check'),
    ];
    return const _GuideTable(
      title: 'How often to do it',
      rows: rows,
    );
  }
}

class _PricingModule extends StatelessWidget {
  const _PricingModule();

  @override
  Widget build(BuildContext context) {
    return const _ResponsiveModuleGrid(
      children: [
        _PricingCard(
          title: 'Upfront price',
          label: 'Upfront price',
          text: 'Routine, predictable jobs show a clear price before booking.',
        ),
        _PricingCard(
          title: 'You approve the cap',
          label: 'Cap Approval',
          text:
              'You approve a not-to-exceed cap before work begins. The final price may be lower — never higher.',
        ),
        _PricingCard(
          title: 'Free visit',
          label: 'Free estimate',
          text:
              'The pro visits, then sends you an estimate to accept or decline.',
        ),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String label;
  final String text;

  const _PricingCard({
    required this.title,
    required this.label,
    required this.text,
  });

  // B04: hairline card — Outfit 17/600 title, 13 meta type name, 15/22
  // description (was a coloured header band with a white 12.5 label).
  @override
  Widget build(BuildContext context) {
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TwType.h3()),
          const SizedBox(height: TwSpace.s4),
          Text(label, style: TwType.caption()),
          const SizedBox(height: TwSpace.s8),
          Text(text, style: TwType.bodySm()),
        ],
      ),
    );
  }
}

class _DiyVsProModule extends StatelessWidget {
  const _DiyVsProModule();

  @override
  Widget build(BuildContext context) {
    return const _ResponsiveModuleGrid(
      children: [
        _ChecklistPanel(
          title: 'Safe to DIY',
          icon: Icons.build_outlined,
          items: [
            'Changing filters and testing detectors',
            'Basic caulking, sealing, and weatherproofing',
            'Routine yard care and simple cleaning',
            'Small visual checks around the home',
          ],
        ),
        _ChecklistPanel(
          title: 'Call a vetted pro',
          icon: Icons.shield_outlined,
          items: [
            'HVAC, furnace, roof, chimney, and tree work',
            'Electrical, gas, and permit-regulated work',
            'Major plumbing, water, or structural issues',
            'Anything involving height, shock, or life safety',
          ],
        ),
      ],
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _ChecklistPanel({
    required this.title,
    required this.icon,
    required this.items,
  });

  // B04: hairline card, outline icon 20 + Outfit 17/600 title (was a
  // coloured header band with a white label).
  @override
  Widget build(BuildContext context) {
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.navy),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TwType.h3())),
            ],
          ),
          const SizedBox(height: TwSpace.s12),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _BulletRow(text: items[i]),
          ],
        ],
      ),
    );
  }
}

class _AiExperienceModule extends StatelessWidget {
  const _AiExperienceModule();

  // B04: light hairline card (was a navy header with white text).
  @override
  Widget build(BuildContext context) {
    return TwCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Describe it. We'll handle the rest.",
            style: TwType.h2(),
          ),
          const SizedBox(height: 14),
          Text(
            'The assistant points you to the right service, then you browse, choose and book. You see each step as your pro marks it.',
            style: TwType.bodySm(),
          ),
          const SizedBox(height: 14),
          const _AiStepRow(
            step: '1',
            title: 'Describe the task',
            text: 'Use plain language, photos, or the problem you noticed.',
          ),
          const SizedBox(height: 14),
          const _AiStepRow(
            step: '2',
            title: 'See the right service',
            text:
                'AI-assisted routing turns the issue into a clear service path.',
          ),
          const SizedBox(height: 14),
          const _AiStepRow(
            step: '3',
            title: 'Browse and choose',
            text: 'Compare vetted pros, pricing, ratings, and availability.',
          ),
          const SizedBox(height: 14),
          const _AiStepRow(
            step: '4',
            title: 'Book and follow along',
            text:
                'Book in the app and see each status your pro sets, through to Completed.',
          ),
        ],
      ),
    );
  }
}

class _AiStepRow extends StatelessWidget {
  final String step;
  final String title;
  final String text;

  const _AiStepRow({
    required this.step,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.blueTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(step, style: TwType.h3(color: AppTheme.blue)),
        ),
        const SizedBox(width: TwSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TwType.title()),
              const SizedBox(height: 2),
              Text(text, style: TwType.meta()),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideTable extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _GuideTable({
    required this.title,
    required this.rows,
  });

  // Hairline card with an h3 title (was a navy header with a white label).
  // Rows stack (label above value) on Compact or at large text sizes.
  @override
  Widget build(BuildContext context) {
    final stack = TwLayout.stackRows(context);
    return TwCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title, style: TwType.h3()),
          ),
          for (int i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: i == rows.length - 1
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
              child: stack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$1, style: TwType.label()),
                        const SizedBox(height: TwSpace.s4),
                        Text(rows[i].$2, style: TwType.bodySm()),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 112,
                          child: Text(rows[i].$1, style: TwType.label()),
                        ),
                        const SizedBox(width: TwSpace.s12),
                        Expanded(
                          child: Text(rows[i].$2, style: TwType.bodySm()),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _ResponsiveModuleGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveModuleGrid({required this.children});

  // B04 stacks module cards at every size. The old fixed-aspect GridView
  // clipped text at large text sizes, and the article column is now capped
  // at 560, so a multi-column grid never had room anyway.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: TwSpace.s12),
          children[i],
        ],
      ],
    );
  }
}

class _FaqCard extends StatelessWidget {
  final CategoryGuideArticle article;

  const _FaqCard({required this.article});

  // B04: h2 heading, then flat rows split by hairlines with a 16/600
  // question and a grey chevron (was bordered cards, 14.2 questions, 22
  // heading).
  @override
  Widget build(BuildContext context) {
    if (article.faqs.isEmpty) {
      return const SizedBox.shrink();
    }
    const divider = Border(bottom: BorderSide(color: AppTheme.cardBorder));
    return Padding(
      padding: const EdgeInsets.only(top: TwSpace.s28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Frequently asked questions', style: TwType.h2()),
          const SizedBox(height: TwSpace.s4),
          ...article.faqs.map(
            (faq) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: TwSpace.s16),
              expandedAlignment: Alignment.centerLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              collapsedIconColor: AppTheme.textSecondary,
              iconColor: AppTheme.textSecondary,
              shape: divider,
              collapsedShape: divider,
              title: Text(faq.question, style: TwType.title()),
              children: [
                Text(faq.answer, style: TwType.body()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCtaCard extends StatelessWidget {
  final CategoryGuideArticle article;
  final Future<void> Function() onBrowseTap;

  const _ArticleCtaCard({
    required this.article,
    required this.onBrowseTap,
  });

  // B04: light hairline card, orange primary with a navy label, neutral
  // outline secondary, both full width (was a navy card with white text and
  // a white label on orange — Batch 20 Part C).
  @override
  Widget build(BuildContext context) {
    return TwCard(
      padding: const EdgeInsets.all(TwSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            article.ctaTitle.isNotEmpty ? article.ctaTitle : 'Need help?',
            style: TwType.h2(),
          ),
          const SizedBox(height: TwSpace.s12),
          Text(article.ctaBody, style: TwType.bodySm()),
          const SizedBox(height: TwSpace.s12),
          TwPrimaryButton(
            label: 'Browse vetted ${article.serviceCategory} pros',
            onPressed: onBrowseTap,
          ),
          const SizedBox(height: TwSpace.s12),
          TwSecondaryButton(
            label: 'Call (813) 477-7350',
            height: 52,
            onPressed: () => launchUrlString(_supportPhoneUri),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  // B04: plain grey box with an outline image icon (was a blue box with a
  // tracked ALL-CAPS "SERVICE GUIDE" label and a white icon on blue).
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.subtle,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 32,
        color: AppTheme.navy,
      ),
    );
  }
}

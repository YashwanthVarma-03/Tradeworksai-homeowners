import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../theme.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDCE3EE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.navy700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Homeowner Guides',
          style: AppTheme.headingStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<List<CategoryGuideArticle>>(
        future: _articlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.orange500),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load category guides.',
                  style: AppTheme.bodyStyle.copyWith(fontSize: 14),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _GuidesHeroCard(
                count: articles.length,
                generalCount: generalCount,
                categoryCount: categoryCount,
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 18),
              ...filteredArticles.map(
                (article) => _GuideListCard(
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
            ],
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
    return Scaffold(
      backgroundColor: const Color(0xFFDCE3EE),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => launchUrlString('tel:8134777350'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.navy700, width: 1.4),
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Call',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (onBrowseCategory != null) {
                      await onBrowseCategory!(serviceCategory);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Browse $serviceCategory',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.navy700),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    article.serviceCategory,
                    style: AppTheme.headingStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEEF2F8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B3C6E).withOpacity(0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ArticleTopBar(article: article),
                      _ArticleHeader(article: article),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TocCard(article: article),
                            const SizedBox(height: 20),
                            for (int i = 0; i < article.sections.length; i++)
                              _ArticleSectionCard(
                                section: article.sections[i],
                                index: i,
                              ),
                            const SizedBox(height: 10),
                            _FaqCard(article: article),
                            const SizedBox(height: 20),
                            _ArticleCtaCard(
                              article: article,
                              onBrowseTap: () async {
                                if (onBrowseCategory != null) {
                                  await onBrowseCategory!(serviceCategory);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryGuideRepository {
  static Future<List<CategoryGuideArticle>> loadArticles() async {
    final raw = await rootBundle.loadString('assets/data/homeowner_guides.json');
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
  final String tier;
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
    required this.tier,
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
      tier: json['tier'] as String? ?? '',
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
        .replaceAll('The Year-Round Home Maintenance Checklist', 'Home Services')
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

  String get kindLabel => kind == 'general' ? 'General Guide' : 'Category Guide';

  bool get isGeneral => kind == 'general';

  List<CategoryGuideSection> get tocSections =>
      sections.where((section) => section.heading.trim().isNotEmpty).take(10).toList();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B3C6E),
            Color(0xFF235C86),
            Color(0xFF2E86AB),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'TradeWorks Homeowner Guides',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Helpful guides for every home project',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse $generalCount homeowner guides and $categoryCount service category guides with practical advice, FAQs, pricing context, safety notes, and quick ways to book vetted pros.',
            style: GoogleFonts.inter(
              color: const Color(0xFFDCEAF4),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
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
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              icon: Icon(Icons.search, color: AppTheme.gray),
              border: InputBorder.none,
              hintText: 'Search guides',
              hintStyle: TextStyle(color: AppTheme.gray, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _GuideTab(
              label: 'All',
              count: generalCount + categoryCount,
              selected: activeKind == 'all',
              onTap: () => onKindChanged('all'),
            ),
            const SizedBox(width: 8),
            _GuideTab(
              label: 'General',
              count: generalCount,
              selected: activeKind == 'general',
              onTap: () => onKindChanged('general'),
            ),
            const SizedBox(width: 8),
            _GuideTab(
              label: 'Category',
              count: categoryCount,
              selected: activeKind == 'category',
              onTap: () => onKindChanged('category'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _GuideTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppTheme.navy700 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.navy700 : AppTheme.line,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$label ($count)',
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.navy700,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.navy700, AppTheme.teal500],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    article.id.replaceAll('CAT-', '').replaceAll('GEN-', ''),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: AppTheme.headingStyle.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${article.kindLabel} · ${article.subtitle}',
                        style: TextStyle(
                          color: article.isGeneral
                              ? AppTheme.orange700
                              : AppTheme.teal700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.metaDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.gray,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, color: AppTheme.gray, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleTopBar extends StatelessWidget {
  final CategoryGuideArticle article;

  const _ArticleTopBar({required this.article});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'TradeWorks Homeowner Guide',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          _TagPill(label: article.kindLabel),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;

  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF17436F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2E86AB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFBFE2F0),
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ArticleHeader extends StatelessWidget {
  final CategoryGuideArticle article;

  const _ArticleHeader({required this.article});

  @override
  Widget build(BuildContext context) {
    final overview = article.sections.isNotEmpty ? article.sections.first : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.kindLabel.toUpperCase(),
            style: GoogleFonts.poppins(
              color: AppTheme.teal700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.title,
            style: GoogleFonts.poppins(
              color: AppTheme.navy700,
              fontSize: 29,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            article.subtitle,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.teal700,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: 'Guide type', value: article.kindLabel),
              _InfoChip(label: 'Topic', value: article.serviceCategory),
              const _InfoChip(label: 'Availability', value: 'Free guide'),
            ],
          ),
          const SizedBox(height: 18),
          _ImagePlaceholder(
            title: article.serviceCategory,
            subtitle: article.isGeneral ? 'Homeowner guide' : 'Service guide',
            icon: Icons.auto_awesome,
          ),
          if (overview != null && overview.paragraphs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4F1F7)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE4F1F7), Colors.white],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUICK ANSWER',
                    style: GoogleFonts.poppins(
                      color: AppTheme.teal700,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overview.paragraphs.first,
                    style: AppTheme.bodyStyle.copyWith(
                      fontSize: 15,
                      height: 1.55,
                      color: const Color(0xFF1D2B3D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              color: AppTheme.gray,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppTheme.navy700,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TocCard extends StatelessWidget {
  final CategoryGuideArticle article;

  const _TocCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TABLE OF CONTENTS',
            style: GoogleFonts.poppins(
              color: AppTheme.navy700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 10,
            spacing: 10,
            children: [
              for (int i = 0; i < article.tocSections.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Text(
                    '${i + 1}. ${article.tocSections[i].heading}',
                    style: AppTheme.bodyStyle.copyWith(
                      fontSize: 12.5,
                      color: AppTheme.teal700,
                      fontWeight: FontWeight.w600,
                    ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOverview)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                section.heading,
                style: GoogleFonts.poppins(
                  color: AppTheme.navy700,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...section.paragraphs.asMap().entries.map((entry) {
            final paragraph = entry.value;
            final isBulletLike = _isBulletLike(paragraph);
            final isAlert = _isAlertLike(paragraph);
            if (isBulletLike) {
              return _BulletRow(text: paragraph);
            }
            if (isAlert) {
              return _AlertCallout(text: paragraph);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                paragraph,
                style: AppTheme.bodyStyle.copyWith(
                  fontSize: 15.3,
                  height: 1.62,
                  color: const Color(0xFF233246),
                ),
              ),
            );
          }),
          ..._moduleForSection(section),
        ],
      ),
    );
  }

  List<Widget> _moduleForSection(CategoryGuideSection section) {
    final heading = section.heading.toLowerCase();
    if (heading.contains('spring') || heading.contains('summer') ||
        heading.contains('fall') || heading.contains('winter')) {
      return [_SeasonModule(heading: section.heading)];
    }
    if (heading.contains('frequency') || heading.contains('at a glance')) {
      return const [_FrequencyModule()];
    }
    if (heading.contains('diy') || heading.contains('call a pro')) {
      return const [_DiyVsProModule()];
    }
    if (heading.contains('tradeworks') || heading.contains('helps') ||
        heading.contains('keep track')) {
      return const [_AiExperienceModule()];
    }
    if (heading.contains('cost') || heading.contains('pricing') ||
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: Color(0xFFE7EDF6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 13,
              color: AppTheme.navy700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyStyle.copyWith(
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCallout extends StatelessWidget {
  final String text;

  const _AlertCallout({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7D3A6)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7ECD6), Colors.white],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB7791F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyStyle.copyWith(
                fontSize: 14.2,
                color: const Color(0xFF5C471F),
                height: 1.55,
              ),
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
              color: Color(0xFFD2622B),
              tasks: [
                'Service the heating system before cold weather',
                'Clean gutters again after leaf-fall',
                'Winterize outdoor faucets and sprinklers',
                'Inspect chimney, insulation, and weatherstripping',
              ],
              proLine: 'Book a pro for furnace service, gutters, chimney, or insulation',
            ),
            _SeasonData(
              title: 'Winter',
              color: Color(0xFF3E7CA4),
              tasks: [
                'Protect exposed pipes from freezing',
                'Watch gutters and rooflines after storms',
                'Change HVAC filters and monitor humidity',
                'Test sump pumps before heavy rain',
              ],
              proLine: 'Book a pro for plumbing, heating, roofing, or insulation',
            ),
          ]
        : const [
            _SeasonData(
              title: 'Spring',
              color: Color(0xFF3EA46B),
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
              color: Color(0xFFE8A21A),
              tasks: [
                'Replace HVAC filters during heavy-use months',
                'Pressure wash walkways, driveway, and siding',
                'Trim trees and shrubs back from the home',
                'Check leaks, GFCI outlets, pests, and seals',
              ],
              proLine: 'Book a pro for pressure washing, trees, or pest control',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              data.title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...data.tasks.map((task) => _BulletRow(text: task)),
                Text(
                  data.proLine,
                  style: GoogleFonts.poppins(
                    color: AppTheme.teal700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
      ('Twice a year', 'AC and heat service, gutter cleaning, detector batteries'),
      ('Annually', 'Roof inspection, chimney sweep, dryer vent, pressure washing'),
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
          label: 'Rate Card',
          text: 'Routine, predictable jobs show a clear price before booking.',
          color: Color(0xFF2F8F46),
        ),
        _PricingCard(
          title: 'You approve the cap',
          label: 'Not-to-Exceed',
          text: 'Repairs needing diagnosis use a cap you approve before work begins.',
          color: Color(0xFF2E86AB),
        ),
        _PricingCard(
          title: 'Free estimate',
          label: 'Quote Request',
          text: 'Bigger projects get an itemized estimate before you decide.',
          color: Color(0xFF1B3C6E),
        ),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String label;
  final String text;
  final Color color;

  const _PricingCard({
    required this.title,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: AppTheme.navy700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: AppTheme.bodyStyle.copyWith(
                    color: const Color(0xFF2B3A4D),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
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
          color: AppTheme.teal700,
          items: [
            'Changing filters and testing detectors',
            'Basic caulking, sealing, and weatherproofing',
            'Routine yard care and simple cleaning',
            'Small visual checks around the home',
          ],
        ),
        _ChecklistPanel(
          title: 'Call a vetted pro',
          color: AppTheme.navy700,
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
  final Color color;
  final List<String> items;

  const _ChecklistPanel({
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.map((item) => _BulletRow(text: item)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiExperienceModule extends StatelessWidget {
  const _AiExperienceModule();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EDF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppTheme.navy700,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Describe it. We'll handle the rest.",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The assistant points you to the right service, then you browse, choose, book, and track.',
                  style: AppTheme.bodyStyle.copyWith(
                    color: const Color(0xFFC9D7EA),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _AiStepRow(
                  step: '1',
                  title: 'Describe the task',
                  text: 'Use plain language, photos, or the problem you noticed.',
                ),
                _AiStepRow(
                  step: '2',
                  title: 'See the right service',
                  text: 'AI-assisted routing turns the issue into a clear service path.',
                ),
                _AiStepRow(
                  step: '3',
                  title: 'Browse and choose',
                  text: 'Compare vetted pros, pricing, ratings, and availability.',
                ),
                _AiStepRow(
                  step: '4',
                  title: 'Book and track',
                  text: 'Use the existing booking flow and follow status to completion.',
                ),
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F1F7),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppTheme.teal700),
            ),
            child: Text(
              step,
              style: GoogleFonts.poppins(
                color: AppTheme.teal700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppTheme.navy700,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  text,
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.gray,
                    fontSize: 12.2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.navy700,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...rows.map(
            (row) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      row.$1,
                      style: GoogleFonts.poppins(
                        color: AppTheme.navy700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: AppTheme.bodyStyle.copyWith(
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 620;
        return GridView.count(
          crossAxisCount: isWide ? children.length.clamp(2, 3) : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 1.35 : 1.85,
          children: children,
        );
      },
    );
  }
}

class _FaqCard extends StatelessWidget {
  final CategoryGuideArticle article;

  const _FaqCard({required this.article});

  @override
  Widget build(BuildContext context) {
    if (article.faqs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently asked questions',
          style: GoogleFonts.poppins(
            color: AppTheme.navy700,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...article.faqs.map(
          (faq) => Container(
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              collapsedIconColor: AppTheme.teal700,
              iconColor: AppTheme.teal700,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              title: Text(
                faq.question,
                style: GoogleFonts.poppins(
                  color: AppTheme.navy700,
                  fontSize: 14.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Text(
                  faq.answer,
                  style: AppTheme.bodyStyle.copyWith(
                    fontSize: 13.8,
                    height: 1.58,
                    color: const Color(0xFF33465E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.navy700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.ctaTitle.isNotEmpty ? article.ctaTitle : 'Need help?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.ctaBody,
            style: AppTheme.bodyStyle.copyWith(
              color: const Color(0xFFC9D7EA),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: onBrowseTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.navy700,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Browse vetted ${article.serviceCategory.toLowerCase()} pros',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton(
                onPressed: () => launchUrlString('tel:8134777350'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.45)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Call (813) 477-7350',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ImagePlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.teal500, width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F8FB), Color(0xFFE9F3F8)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.teal500,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle.toUpperCase(),
            style: GoogleFonts.poppins(
              color: AppTheme.teal700,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppTheme.navy700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

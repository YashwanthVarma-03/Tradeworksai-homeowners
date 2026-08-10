import 'package:flutter/material.dart';

import '../theme.dart';
import 'pro_profile.dart';

enum _BrowseView {
  browse,
  allCategories,
  searchFocused,
  typeAhead,
  results,
  noCoverage,
}

class SearchTab extends StatefulWidget {
  final Function(Map<String, String>) onBookPro;
  final String? initialSearchQuery;
  final String? initialCategory;
  final bool showSectionBackButton;

  const SearchTab({
    super.key,
    required this.onBookPro,
    this.initialSearchQuery,
    this.initialCategory,
    this.showSectionBackButton = true,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final TextEditingController _locationController =
      TextEditingController(text: 'Home · 33578');

  _BrowseView _view = _BrowseView.browse;
  String _selectedCategory = 'All';
  String? _committedQuery;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_handleFocusChange);

    if (widget.initialCategory != null && widget.initialCategory != 'All') {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialCategory == 'All') {
      _view = _BrowseView.allCategories;
    }
    if (_searchController.text.trim().isNotEmpty) {
      _committedQuery = _searchController.text.trim();
      _view = _resolveSearchView(_committedQuery!);
    }
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      _searchController.text = widget.initialSearchQuery ?? '';
      _committedQuery = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();
      if (_committedQuery != null) {
        _view = _resolveSearchView(_committedQuery!);
      } else if (_searchFocusNode.hasFocus) {
        _view = _BrowseView.searchFocused;
      } else {
        _view = _selectedCategory == 'All'
            ? _BrowseView.browse
            : _BrowseView.results;
      }
      setState(() {});
    }

    if (widget.initialCategory != oldWidget.initialCategory) {
      if (widget.initialCategory == 'All') {
        _selectedCategory = 'All';
        _view = _BrowseView.allCategories;
      } else if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
        _view = _BrowseView.browse;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      if (_searchFocusNode.hasFocus) {
        if (_searchController.text.trim().isEmpty) {
          _view = _BrowseView.searchFocused;
        } else if (_committedQuery == _searchController.text.trim()) {
          _view = _resolveSearchView(_searchController.text.trim());
        } else {
          _view = _BrowseView.typeAhead;
        }
      } else if (_committedQuery != null) {
        _view = _resolveSearchView(_committedQuery!);
      } else if (_selectedCategory == 'All') {
        _view = _BrowseView.browse;
      } else {
        _view = _BrowseView.browse;
      }
    });
  }

  void _setFocusSearch() {
    setState(() => _view = _BrowseView.searchFocused);
    _searchFocusNode.requestFocus();
  }

  void _clearSearch() {
    _searchController.clear();
    _committedQuery = null;
    _searchFocusNode.requestFocus();
    setState(() => _view = _BrowseView.searchFocused);
  }

  void _submitSearch([String? rawQuery]) {
    final query = (rawQuery ?? _searchController.text).trim();
    _committedQuery = query.isEmpty ? null : query;
    setState(() {
      _view = _committedQuery == null
          ? (_selectedCategory == 'All'
              ? _BrowseView.browse
              : _BrowseView.results)
          : _resolveSearchView(_committedQuery!);
    });
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  void _openAllCategories() {
    setState(() {
      _selectedCategory = 'All';
      _committedQuery = null;
      _searchController.clear();
      _view = _BrowseView.allCategories;
    });
    _searchFocusNode.unfocus();
  }

  void _selectCategory(String category) {
    if (category == 'All') {
      _openAllCategories();
      return;
    }
    setState(() {
      _selectedCategory = category;
      _committedQuery = null;
      _view = _BrowseView.browse;
    });
    _searchFocusNode.unfocus();
  }

  _BrowseView _resolveSearchView(String query) {
    final matches = _matchesQuery(query);
    if (matches.isEmpty) {
      return _BrowseView.noCoverage;
    }
    return _BrowseView.results;
  }

  List<_BrowseCategory> get _allCategories => const [
        _BrowseCategory(
          name: 'Moving',
          icon: Icons.local_shipping,
          serviceCount: 4,
          prosCount: 2,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Appliance Repair',
          icon: Icons.kitchen,
          serviceCount: 9,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Concrete',
          icon: Icons.construction,
          serviceCount: 5,
          prosCount: 0,
          color: AppTheme.teal700,
          covered: false,
        ),
        _BrowseCategory(
          name: 'Garage Doors',
          icon: Icons.garage,
          serviceCount: 3,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Flooring',
          icon: Icons.layers,
          serviceCount: 6,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Plumbing',
          icon: Icons.plumbing,
          serviceCount: 12,
          prosCount: 3,
          color: AppTheme.teal700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'HVAC',
          icon: Icons.ac_unit,
          serviceCount: 9,
          prosCount: 2,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Electrical',
          icon: Icons.flash_on,
          serviceCount: 7,
          prosCount: 2,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Cleaning',
          icon: Icons.cleaning_services,
          serviceCount: 8,
          prosCount: 1,
          color: AppTheme.teal700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Landscaping',
          icon: Icons.nature_people,
          serviceCount: 10,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Painting',
          icon: Icons.format_paint,
          serviceCount: 5,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Water Treatment',
          icon: Icons.water_drop,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.teal700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Roofing',
          icon: Icons.roofing,
          serviceCount: 6,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Windows & Doors',
          icon: Icons.window,
          serviceCount: 6,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Smart Home',
          icon: Icons.settings_remote,
          serviceCount: 3,
          prosCount: 0,
          color: AppTheme.teal700,
          covered: false,
        ),
        _BrowseCategory(
          name: 'Solar Energy',
          icon: Icons.solar_power,
          serviceCount: 4,
          prosCount: 0,
          color: AppTheme.navy700,
          covered: false,
        ),
        _BrowseCategory(
          name: 'Tree Service',
          icon: Icons.park,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Pest Control',
          icon: Icons.bug_report,
          serviceCount: 6,
          prosCount: 1,
          color: AppTheme.teal700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Home Security',
          icon: Icons.security,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Insulation',
          icon: Icons.wb_shade,
          serviceCount: 2,
          prosCount: 0,
          color: AppTheme.orange500,
          covered: false,
        ),
        _BrowseCategory(
          name: 'Locksmith',
          icon: Icons.lock,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Junk Removal',
          icon: Icons.delete_outline,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Remodeling',
          icon: Icons.construction,
          serviceCount: 8,
          prosCount: 1,
          color: AppTheme.teal700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Fencing & Decks',
          icon: Icons.fence,
          serviceCount: 5,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Drywall & Plaster',
          icon: Icons.texture,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Gutters',
          icon: Icons.waves,
          serviceCount: 3,
          prosCount: 1,
          color: AppTheme.teal700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Screen Repair',
          icon: Icons.grid_on,
          serviceCount: 2,
          prosCount: 1,
          color: AppTheme.navy700,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Pool & Spa',
          icon: Icons.pool,
          serviceCount: 4,
          prosCount: 1,
          color: AppTheme.orange500,
          covered: true,
        ),
        _BrowseCategory(
          name: 'Fireplace & Chimney',
          icon: Icons.fireplace,
          serviceCount: 3,
          prosCount: 0,
          color: AppTheme.teal700,
          covered: false,
        ),
        _BrowseCategory(
          name: 'Siding',
          icon: Icons.home_work,
          serviceCount: 3,
          prosCount: 0,
          color: AppTheme.navy700,
          covered: false,
        ),
        _BrowseCategory(
          name: 'Concrete & Masonry',
          icon: Icons.foundation,
          serviceCount: 4,
          prosCount: 0,
          color: AppTheme.orange500,
          covered: false,
        ),
      ];

  List<_BrowseService> get _popularServices => const [
        _BrowseService('AC repair', 'HVAC'),
        _BrowseService('Drain cleaning', 'Plumbing'),
        _BrowseService('Water heater replacement', 'Plumbing'),
        _BrowseService('Ceiling fan install', 'Electrical'),
        _BrowseService('Fence repair', 'Fencing & Decks'),
        _BrowseService('Interior painting', 'Painting'),
        _BrowseService('Lawn maintenance', 'Landscaping'),
        _BrowseService('Smart thermostat install', 'HVAC'),
      ];

  List<String> get _recentSearches => const [
        'AC repair',
        'Leak under sink',
        'Ceiling fan install',
      ];

  List<_BrowsePro> get _pros => const [
        _BrowsePro(
          name: 'Gulf Coast Air',
          initials: 'GC',
          category: 'HVAC',
          trade: 'Heating & Cooling',
          ratingLabel: 'Exceptional',
          rating: 4.9,
          reviews: 212,
          distanceMiles: 2.1,
          completedWorkOrders: 212,
          nextAvailable: 'Tomorrow, 8-10 AM',
          price: 149,
          priceLabel: 'Upfront price',
          summary: 'AC repair diagnose and fix',
          selectedCertified: true,
          services: ['AC repair', 'AC tune-up', 'Refrigerant leak diagnosis'],
          mediaCount: 6,
          responseTime: 'Typically responds in about 20 min',
        ),
        _BrowsePro(
          name: 'Jenkins Plumbing',
          initials: 'JP',
          category: 'Plumbing',
          trade: 'Repair & Install',
          ratingLabel: 'Great',
          rating: 4.8,
          reviews: 92,
          distanceMiles: 1.8,
          completedWorkOrders: 92,
          nextAvailable: 'Today, 2-4 PM',
          price: 119,
          priceLabel: 'Upfront price',
          summary: 'Drain repair and leak fixes',
          selectedCertified: true,
          services: ['Leak repair', 'Drain cleaning', 'Toilet repair'],
          mediaCount: 4,
          responseTime: 'Typically responds in about 18 min',
        ),
        _BrowsePro(
          name: 'Spark Electric',
          initials: 'SE',
          category: 'Electrical',
          trade: 'Service',
          ratingLabel: 'Great',
          rating: 4.7,
          reviews: 64,
          distanceMiles: 3.2,
          completedWorkOrders: 64,
          nextAvailable: 'Thu, 8-10 AM',
          price: 99,
          priceLabel: 'Upfront price',
          summary: 'Electrical service and fixture work',
          selectedCertified: true,
          services: ['Outlet install', 'Ceiling fan install', 'Panel service'],
          mediaCount: 5,
          responseTime: 'Typically responds in about 24 min',
        ),
        _BrowsePro(
          name: 'Bay Area HVAC',
          initials: 'BA',
          category: 'HVAC',
          trade: 'Repair & Install',
          ratingLabel: 'Great',
          rating: 4.8,
          reviews: 156,
          distanceMiles: 3.4,
          completedWorkOrders: 156,
          nextAvailable: 'Thu, 8-10 AM',
          price: 159,
          priceLabel: 'Upfront price',
          summary: 'Heat pump and AC repair',
          selectedCertified: true,
          services: ['Heat pump repair', 'AC repair', 'Maintenance'],
          mediaCount: 3,
          responseTime: 'Typically responds in about 22 min',
        ),
        _BrowsePro(
          name: 'Reliable Climate',
          initials: 'RC',
          category: 'HVAC',
          trade: 'Service',
          ratingLabel: 'Great',
          rating: 4.7,
          reviews: 98,
          distanceMiles: 4.0,
          completedWorkOrders: 98,
          nextAvailable: 'Fri, 1-3 PM',
          price: 139,
          priceLabel: 'Upfront price',
          summary: 'Cooling and thermostat help',
          selectedCertified: true,
          services: ['Thermostat install', 'Cooling tune-up', 'Maintenance'],
          mediaCount: 2,
          responseTime: 'Typically responds in about 30 min',
        ),
        _BrowsePro(
          name: 'Prime Plumb Co.',
          initials: 'PP',
          category: 'Plumbing',
          trade: 'Install & Repair',
          ratingLabel: 'Excellent',
          rating: 4.9,
          reviews: 173,
          distanceMiles: 2.9,
          completedWorkOrders: 173,
          nextAvailable: 'Today, 5-7 PM',
          price: 109,
          priceLabel: 'Upfront price',
          summary: 'Kitchen and bath plumbing',
          selectedCertified: true,
          services: ['Sink repair', 'Garbage disposal', 'Water heater'],
          mediaCount: 4,
          responseTime: 'Typically responds in about 16 min',
        ),
        _BrowsePro(
          name: 'Northshore Handyman',
          initials: 'NH',
          category: 'Handyman',
          trade: 'Home Repairs',
          ratingLabel: 'Great',
          rating: 4.8,
          reviews: 87,
          distanceMiles: 2.4,
          completedWorkOrders: 87,
          nextAvailable: 'Today, 4-6 PM',
          price: 89,
          priceLabel: 'Upfront price',
          summary: 'Assembly, mounting, small fixes',
          selectedCertified: true,
          services: ['TV mounting', 'Furniture assembly', 'Door repair'],
          mediaCount: 2,
          responseTime: 'Typically responds in about 28 min',
        ),
        _BrowsePro(
          name: 'EverGreen Lawn',
          initials: 'EG',
          category: 'Landscaping',
          trade: 'Lawn Care',
          ratingLabel: 'Great',
          rating: 4.7,
          reviews: 121,
          distanceMiles: 4.8,
          completedWorkOrders: 121,
          nextAvailable: 'Sat, 7-9 AM',
          price: 79,
          priceLabel: 'Upfront price',
          summary: 'Mowing, cleanup, and edging',
          selectedCertified: true,
          services: ['Mowing', 'Edging', 'Cleanup'],
          mediaCount: 5,
          responseTime: 'Typically responds in about 35 min',
        ),
        _BrowsePro(
          name: 'BrightFix Appliance',
          initials: 'BF',
          category: 'Appliance Repair',
          trade: 'Repair',
          ratingLabel: 'Great',
          rating: 4.6,
          reviews: 58,
          distanceMiles: 3.6,
          completedWorkOrders: 58,
          nextAvailable: 'Tomorrow, 10-12 PM',
          price: 129,
          priceLabel: 'Upfront price',
          summary: 'Fridge, oven, washer, dryer',
          selectedCertified: true,
          services: ['Fridge repair', 'Oven repair', 'Washer service'],
          mediaCount: 3,
          responseTime: 'Typically responds in about 40 min',
        ),
        _BrowsePro(
          name: 'AquaPure Water',
          initials: 'AP',
          category: 'Water Treatment',
          trade: 'Water Quality',
          ratingLabel: 'Great',
          rating: 4.8,
          reviews: 66,
          distanceMiles: 5.1,
          completedWorkOrders: 66,
          nextAvailable: 'Mon, 9-11 AM',
          price: 149,
          priceLabel: 'Upfront price',
          summary: 'Filtration and softeners',
          selectedCertified: true,
          services: ['Water softener', 'RO system', 'Water testing'],
          mediaCount: 2,
          responseTime: 'Typically responds in about 32 min',
        ),
        _BrowsePro(
          name: 'Summit Roofing',
          initials: 'SR',
          category: 'Roofing',
          trade: 'Roof Repair',
          ratingLabel: 'Great',
          rating: 4.7,
          reviews: 74,
          distanceMiles: 6.0,
          completedWorkOrders: 74,
          nextAvailable: 'Tue, 8-10 AM',
          price: 189,
          priceLabel: 'Upfront price',
          summary: 'Leak repair and roof maintenance',
          selectedCertified: true,
          services: ['Leak repair', 'Maintenance', 'Inspection'],
          mediaCount: 4,
          responseTime: 'Typically responds in about 27 min',
        ),
        _BrowsePro(
          name: 'ClearView Windows',
          initials: 'CV',
          category: 'Windows & Doors',
          trade: 'Install & Repair',
          ratingLabel: 'Great',
          rating: 4.8,
          reviews: 84,
          distanceMiles: 2.7,
          completedWorkOrders: 84,
          nextAvailable: 'Wed, 11-1 PM',
          price: 139,
          priceLabel: 'Upfront price',
          summary: 'Windows, doors, screen repair',
          selectedCertified: true,
          services: ['Window repair', 'Door install', 'Screen repair'],
          mediaCount: 3,
          responseTime: 'Typically responds in about 21 min',
        ),
        _BrowsePro(
          name: 'SecureGate Locksmith',
          initials: 'SG',
          category: 'Locksmith',
          trade: 'Lock & Key',
          ratingLabel: 'Great',
          rating: 4.9,
          reviews: 51,
          distanceMiles: 1.3,
          completedWorkOrders: 51,
          nextAvailable: 'Today, 6-7 PM',
          price: 89,
          priceLabel: 'Upfront price',
          summary: 'Rekey, deadbolt, lockout help',
          selectedCertified: true,
          services: ['Rekey', 'Deadbolt install', 'Lockout'],
          mediaCount: 2,
          responseTime: 'Typically responds in about 12 min',
        ),
        _BrowsePro(
          name: 'StoneCraft Masonry',
          initials: 'SM',
          category: 'Concrete & Masonry',
          trade: 'Masonry',
          ratingLabel: 'Great',
          rating: 4.7,
          reviews: 43,
          distanceMiles: 6.8,
          completedWorkOrders: 43,
          nextAvailable: 'Fri, 8-11 AM',
          price: 169,
          priceLabel: 'Upfront price',
          summary: 'Patios, walkways, brickwork',
          selectedCertified: true,
          services: ['Patio repair', 'Brick work', 'Sidewalk patch'],
          mediaCount: 1,
          responseTime: 'Typically responds in about 45 min',
        ),
      ];

  List<_BrowsePro> _matchesQuery(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return const [];
    final matches = _pros.where((pro) {
      final haystacks = <String>[
        pro.name,
        pro.category,
        pro.trade,
        pro.summary,
        ...pro.services,
      ];
      return haystacks.any((value) => value.toLowerCase().contains(lower));
    }).toList();

    if (matches.isNotEmpty) return matches;

    final categoryMatches = _allCategories
        .where((cat) =>
            cat.name.toLowerCase().contains(lower) ||
            cat.name.toLowerCase().replaceAll(' & ', ' ').contains(lower))
        .map((cat) => _pros.firstWhere(
              (pro) => pro.category == cat.name,
              orElse: () => _pros.first,
            ))
        .toList();
    return categoryMatches;
  }

  Map<String, dynamic> _toProMap(_BrowsePro pro) {
    return {
      'slug': pro.slug,
      'id': pro.slug,
      'businessName': pro.name,
      'business_name': pro.name,
      'verifiedRating': pro.rating,
      'verifiedCount': pro.reviews,
      'workOrderType': 'rate_card',
      'fromPrice': pro.price,
      'selectedCertified': pro.selectedCertified,
      'category': pro.category,
      'trade': pro.trade,
      'distanceMiles': pro.distanceMiles,
      'completedWorkOrders': pro.completedWorkOrders,
      'nextAvailable': pro.nextAvailable,
      'summary': pro.summary,
      'services': pro.services,
      'media': List.generate(pro.mediaCount, (index) => {'id': index}),
    };
  }

  void _openProProfile(_BrowsePro pro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProProfileScreen(pro: _toProMap(pro)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePros = _selectedCategory == 'All'
        ? _pros
        : _pros.where((pro) => pro.category == _selectedCategory).toList();
    final searchQuery = _searchController.text.trim();
    final activeTypeAhead = _matchesQuery(searchQuery);

    Widget body;
    switch (_view) {
      case _BrowseView.allCategories:
        body = _buildAllCategories();
        break;
      case _BrowseView.searchFocused:
        body = _buildSearchFocused();
        break;
      case _BrowseView.typeAhead:
        body = _buildTypeAhead(activeTypeAhead);
        break;
      case _BrowseView.results:
        body = _buildResults(activeTypeAhead.isEmpty
            ? _matchesQuery(_committedQuery ?? searchQuery)
            : activeTypeAhead);
        break;
      case _BrowseView.noCoverage:
        body = _buildNoCoverage();
        break;
      case _BrowseView.browse:
      default:
        body = visiblePros.isEmpty ? _buildNoCoverage() : _buildBrowseDefault(visiblePros);
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          FocusScope.of(context).unfocus();
        }
      },
      child: body,
    );
  }

  Widget _buildBrowseDefault(List<_BrowsePro> visiblePros) {
    final filteredCategories = _allCategories
        .where((cat) => cat.covered)
        .take(9)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        _buildWireframePills(
          focused: false,
          placeholder: 'Search a service or pro',
          onSearchTap: _setFocusSearch,
        ),
        const SizedBox(height: 14),
        _buildRail(filteredCategories),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              '15 vetted pros',
              style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Sort: Highest rated',
              style: TextStyle(
                color: AppTheme.gray,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...visiblePros.map((pro) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBrowseCard(pro),
            )),
      ],
    );
  }

  Widget _buildAllCategories() {
    return Column(
      children: [
        if (widget.showSectionBackButton)
          _buildTopBar(
            title: 'All categories',
            onBack: () => setState(() => _view = _BrowseView.browse),
          )
        else
          const SizedBox(height: 14),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Serving 33578',
                      style: TextStyle(
                        color: AppTheme.gray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '31 categories · 164 services',
                    style: TextStyle(
                      color: AppTheme.gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                itemCount: _allCategories.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final category = _allCategories[index];
                  return _CategoryGridTile(
                    category: category,
                    onTap: () {
                      if (!category.covered) {
                        setState(() => _view = _BrowseView.noCoverage);
                        return;
                      }
                      _selectCategory(category.name);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchFocused() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        _buildWireframePills(
          focused: true,
          placeholder: 'What service do you need?',
          onSearchTap: _setFocusSearch,
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('Recent searches'),
        const SizedBox(height: 10),
        ..._recentSearches.map((term) => _buildListChipRow(
              title: term,
              trailing: 'Recent',
              onTap: () {
                _searchController.text = term;
                _searchController.selection = TextSelection.collapsed(
                  offset: term.length,
                );
                _submitSearch(term);
              },
            )),
        const SizedBox(height: 18),
        _buildSectionHeader('Popular services'),
        const SizedBox(height: 10),
        ..._popularServices.map((service) => _buildListChipRow(
              title: service.name,
              trailing: service.category,
              onTap: () {
                _searchController.text = service.name;
                _searchController.selection = TextSelection.collapsed(
                  offset: service.name.length,
                );
                _submitSearch(service.name);
              },
            )),
        const SizedBox(height: 18),
        InkWell(
          onTap: _openAllCategories,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.pageAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Browse all 31 categories',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.gray),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeAhead(List<_BrowsePro> matches) {
    return Column(
      children: [
        _buildTopSearchBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              _buildSearchInputPill(),
              const SizedBox(height: 14),
              _buildSectionHeader('Services'),
              const SizedBox(height: 10),
              ..._serviceMatches().take(4).map(
                    (service) => _buildListChipRow(
                      title: service.name,
                      trailing: service.category,
                      onTap: () {
                        _searchController.text = service.name;
                        _submitSearch(service.name);
                      },
                    ),
                  ),
              const SizedBox(height: 14),
              _buildSectionHeader('Categories'),
              const SizedBox(height: 10),
              ..._categoryMatches().take(4).map(
                    (category) => _buildListChipRow(
                      title: category.name,
                      trailing: '${category.serviceCount} services',
                      onTap: () => _selectCategory(category.name),
                    ),
                  ),
              const SizedBox(height: 14),
              _buildSectionHeader('Pros near you'),
              const SizedBox(height: 10),
              ...matches.take(3).map(_buildMiniProRow),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(List<_BrowsePro> matches) {
    final filtered = matches.isEmpty ? _pros.take(3).toList() : matches;
    return Column(
      children: [
        _buildTopSearchBar(collapsed: true),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              ...filtered.map((pro) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildEnrichedCard(pro),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoCoverage() {
    return Column(
      children: [
        _buildTopSearchBar(collapsed: true),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_outlined,
                        size: 48, color: AppTheme.orange500),
                    const SizedBox(height: 14),
                    const Text(
                      'No coverage in this ZIP',
                      style: TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We do not have vetted pros for this service in 33578 yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.gray, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _openAllCategories,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        foregroundColor: AppTheme.navy700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Browse all categories'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar({
    required String title,
    required VoidCallback onBack,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.navy700,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar({bool collapsed = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Column(
        children: [
          _buildSearchInputPill(collapsed: collapsed),
          const SizedBox(height: 9),
          _buildLocationPill(),
        ],
      ),
    );
  }

  Widget _buildWireframePills({
    required bool focused,
    required String placeholder,
    required VoidCallback onSearchTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onSearchTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: focused ? AppTheme.orangeTint : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: focused ? AppTheme.orange500 : AppTheme.line,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.gray, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    placeholder,
                    style: TextStyle(
                      color: focused ? AppTheme.navy700 : AppTheme.gray,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildLocationPill(),
      ],
    );
  }

  Widget _buildSearchInputPill({bool collapsed = false}) {
    return GestureDetector(
      onTap: _setFocusSearch,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: collapsed ? 12 : 14),
        decoration: BoxDecoration(
          color: _searchFocusNode.hasFocus
              ? AppTheme.orangeTint
              : AppTheme.pageAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _searchFocusNode.hasFocus ? AppTheme.orange500 : AppTheme.line,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.gray, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: _searchFocusNode.hasFocus
                  ? TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) {
                        setState(() {
                          if (value.trim().isEmpty) {
                            _committedQuery = null;
                            _view = _BrowseView.searchFocused;
                          } else {
                            _view = _BrowseView.typeAhead;
                          }
                        });
                      },
                      onSubmitted: _submitSearch,
                      cursorColor: AppTheme.orange500,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'What service do you need?',
                        hintStyle: const TextStyle(color: AppTheme.gray),
                      ),
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      _searchController.text.isEmpty
                          ? 'Search a service or pro'
                          : _searchController.text,
                      style: TextStyle(
                        color: _searchController.text.isEmpty
                            ? AppTheme.gray
                            : AppTheme.navy700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            if (_searchController.text.isNotEmpty)
              InkWell(
                onTap: _clearSearch,
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close, color: AppTheme.gray, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPill() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            final controller = TextEditingController(text: _locationController.text);
            return AlertDialog(
              title: const Text('Change location'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'City, State or ZIP',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _locationController.text = controller.text.trim().isEmpty
                          ? 'Home · 33578'
                          : controller.text.trim();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppTheme.gray, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _locationController.text,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'Change',
              style: TextStyle(
                color: AppTheme.teal700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(List<_BrowseCategory> categories) {
    final chips = <Widget>[
      _RailChip(
        label: 'All',
        meta: '15 pros',
        selected: _selectedCategory == 'All',
        onTap: _openAllCategories,
      ),
      ...categories.map(
        (category) => _RailChip(
          label: category.name,
          meta: '${category.prosCount} pros',
          selected: _selectedCategory == category.name,
          onTap: () => _selectCategory(category.name),
        ),
      ),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => chips[index],
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: chips.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.navy700,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildListChipRow({
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProRow(_BrowsePro pro) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openProProfile(pro),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: pro.category == 'Plumbing'
                    ? AppTheme.orangeTint
                    : pro.category == 'Electrical'
                        ? AppTheme.tealTint
                        : AppTheme.navyTint,
                child: Text(
                  pro.initials,
                  style: TextStyle(
                    color: pro.category == 'Plumbing'
                        ? AppTheme.orange700
                        : pro.category == 'Electrical'
                            ? AppTheme.teal700
                            : AppTheme.navy700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pro.name,
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pro.category} · ${pro.distanceMiles.toStringAsFixed(1)} mi',
                      style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseCard(_BrowsePro pro) {
    return InkWell(
      onTap: () => _openProProfile(pro),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _avatarColorForCategory(pro.category),
              child: Text(
                pro.initials,
                style: TextStyle(
                  color: _avatarTextColorForCategory(pro.category),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pro.name,
                          style: const TextStyle(
                            color: AppTheme.navy700,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (pro.selectedCertified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.tealTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Select-certified',
                            style: TextStyle(
                              color: AppTheme.teal700,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${pro.ratingLabel} ${pro.rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: AppTheme.navy700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: AppTheme.orange500, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '(${pro.reviews})',
                        style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${pro.category} · ${pro.trade}',
                    style: const TextStyle(
                      color: AppTheme.gray,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pro.distanceMiles.toStringAsFixed(1)} mi away · ${pro.completedWorkOrders} completed work orders',
                    style: const TextStyle(
                      color: AppTheme.gray,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next available: ${pro.nextAvailable}',
                    style: const TextStyle(
                      color: AppTheme.gray,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'From \$${pro.price}',
                        style: const TextStyle(
                          color: AppTheme.navy700,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pro.priceLabel,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 11.5,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'View profile',
                        style: TextStyle(
                          color: AppTheme.teal700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrichedCard(_BrowsePro pro) {
    return InkWell(
      onTap: () => _openProProfile(pro),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _avatarColorForCategory(pro.category),
                  child: Text(
                    pro.initials,
                    style: TextStyle(
                      color: _avatarTextColorForCategory(pro.category),
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
                        pro.name,
                        style: const TextStyle(
                          color: AppTheme.navy700,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${pro.category} · ${pro.trade}',
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.gray),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: AppTheme.orange500, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${pro.ratingLabel} ${pro.rating.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${pro.reviews})',
                  style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                ),
                const Spacer(),
                if (pro.selectedCertified)
                  const Text(
                    'Select-certified',
                    style: TextStyle(
                      color: AppTheme.teal700,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${pro.distanceMiles.toStringAsFixed(1)} mi away · ${pro.completedWorkOrders} completed work orders',
              style: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
            ),
            const SizedBox(height: 2),
            Text(
              'Next available: ${pro.nextAvailable}',
              style: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.orangeTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    'From \$${pro.price}',
                    style: const TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pro.priceLabel,
                    style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                  ),
                  const Spacer(),
                  const Text(
                    'View profile',
                    style: TextStyle(
                      color: AppTheme.teal700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_BrowseService> _serviceMatches() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _popularServices;
    return _popularServices
        .where((service) =>
            service.name.toLowerCase().contains(query) ||
            service.category.toLowerCase().contains(query))
        .toList();
  }

  List<_BrowseCategory> _categoryMatches() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allCategories.where((c) => c.covered).toList();
    return _allCategories
        .where((category) =>
            category.covered &&
            category.name.toLowerCase().contains(query))
        .toList();
  }

  Color _avatarColorForCategory(String category) {
    switch (category) {
      case 'Plumbing':
      case 'Appliance Repair':
        return AppTheme.orangeTint;
      case 'Electrical':
      case 'Water Treatment':
        return AppTheme.tealTint;
      default:
        return AppTheme.navyTint;
    }
  }

  Color _avatarTextColorForCategory(String category) {
    switch (category) {
      case 'Plumbing':
      case 'Appliance Repair':
        return AppTheme.orange700;
      case 'Electrical':
      case 'Water Treatment':
        return AppTheme.teal700;
      default:
        return AppTheme.navy700;
    }
  }
}

class _BrowseCategory {
  final String name;
  final IconData icon;
  final int serviceCount;
  final int prosCount;
  final Color color;
  final bool covered;

  const _BrowseCategory({
    required this.name,
    required this.icon,
    required this.serviceCount,
    required this.prosCount,
    required this.color,
    required this.covered,
  });
}

class _BrowseService {
  final String name;
  final String category;

  const _BrowseService(this.name, this.category);
}

class _BrowsePro {
  final String name;
  final String initials;
  final String category;
  final String trade;
  final String ratingLabel;
  final double rating;
  final int reviews;
  final double distanceMiles;
  final int completedWorkOrders;
  final String nextAvailable;
  final int price;
  final String priceLabel;
  final String summary;
  final bool selectedCertified;
  final List<String> services;
  final int mediaCount;
  final String responseTime;

  const _BrowsePro({
    required this.name,
    required this.initials,
    required this.category,
    required this.trade,
    required this.ratingLabel,
    required this.rating,
    required this.reviews,
    required this.distanceMiles,
    required this.completedWorkOrders,
    required this.nextAvailable,
    required this.price,
    required this.priceLabel,
    required this.summary,
    required this.selectedCertified,
    required this.services,
    required this.mediaCount,
    required this.responseTime,
  });

  String get slug => name.toLowerCase().replaceAll(' ', '-');
}

class _RailChip extends StatelessWidget {
  final String label;
  final String meta;
  final bool selected;
  final VoidCallback onTap;

  const _RailChip({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.navy700 : AppTheme.pageAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : AppTheme.line,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.category : Icons.category_outlined,
              color: selected ? Colors.white : AppTheme.navy700,
              size: 20,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.navy700,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              meta,
              style: TextStyle(
                color: selected ? Colors.white70 : AppTheme.gray,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGridTile extends StatelessWidget {
  final _BrowseCategory category;
  final VoidCallback onTap;

  const _CategoryGridTile({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !category.covered;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: dimmed ? 0.42 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: category.color == AppTheme.navy700
                    ? AppTheme.navyTint
                    : category.color == AppTheme.orange500
                        ? AppTheme.orangeTint
                        : AppTheme.tealTint,
                child: Icon(category.icon, color: category.color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dimmed ? 'None near you' : '${category.serviceCount} services',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

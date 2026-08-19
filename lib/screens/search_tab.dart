import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/homeowner_service.dart';
import '../services/intake_service.dart';
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
  final Function(Map<String, dynamic>) onBookPro;
  final String? initialSearchQuery;
  final String? initialCategory;
  final bool initialAllShowsCategories;
  final bool showSectionBackButton;

  const SearchTab({
    super.key,
    required this.onBookPro,
    this.initialSearchQuery,
    this.initialCategory,
    this.initialAllShowsCategories = false,
    this.showSectionBackButton = true,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  static const String _recentSearchesKey = 'browse_recent_searches';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _railController;
  final TextEditingController _locationController =
      TextEditingController(text: 'Home · 33578');
  final List<String> _recentSearches = [];
  final List<_BrowsePro> _livePros = [];
  final Map<String, int> _categoryCounts = {};
  final Map<String, bool> _categoryCoverage = {};

  _BrowseView _view = _BrowseView.browse;
  String _selectedCategory = 'HVAC';
  String _selectedZip = '33578';
  String? _committedQuery;
  bool _isLoadingResults = false;
  bool _isLoadingCoverage = false;
  String? _resultsError;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    _searchFocusNode = FocusNode();
    _railController = ScrollController();
    _searchFocusNode.addListener(_handleFocusChange);
    _applyLocationLabel('Home', _selectedZip);
    _loadRecentSearches();

    if (widget.initialCategory != null && widget.initialCategory != 'All') {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialCategory == 'All') {
      _selectedCategory = 'All';
      _view = widget.initialAllShowsCategories
          ? _BrowseView.allCategories
          : _BrowseView.browse;
    }
    if (_searchController.text.trim().isNotEmpty) {
      _committedQuery = _searchController.text.trim();
      _view = _resolveSearchView(_committedQuery!);
    }

    _loadLocationAndResults();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSelectedRailVisible();
    });
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
        _runQuerySearch(_committedQuery!);
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
        if (widget.initialAllShowsCategories) {
          _searchFocusNode.unfocus();
          setState(() {
            _committedQuery = null;
            _searchController.clear();
            _view = _BrowseView.allCategories;
          });
        } else {
          _runAllServicesSearch();
        }
      } else if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
        _runCategorySearch(widget.initialCategory!);
      }
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedRailVisible();
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    _railController.dispose();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(stored);
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentSearches.removeWhere(
      (item) => item.toLowerCase() == trimmed.toLowerCase(),
    );
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 6) {
      _recentSearches.removeRange(6, _recentSearches.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
    if (mounted) {
      setState(() {});
    }
  }

  void _applyLocationLabel(String city, String zip) {
    final normalizedCity = city.trim().isEmpty ? 'Home' : city.trim();
    final separator = String.fromCharCode(183);
    _locationController.text = '$normalizedCity $separator $zip';
  }

  String _normalizeLocationText(String value) {
    final separator = String.fromCharCode(183);
    return value
        .replaceAll('Ã‚Â·', separator)
        .replaceAll('Â·', separator)
        .replaceAll('  ', ' ')
        .trim();
  }

  Future<void> _loadLocationAndResults() async {
    await _loadLocationFromProfile();
    await _refreshZipCoverage();
    _locationController.text = _normalizeLocationText(_locationController.text);
    if (!mounted) return;

    if (_committedQuery != null && _committedQuery!.isNotEmpty) {
      await _runQuerySearch(_committedQuery!);
      return;
    }

    if (widget.initialCategory != null && widget.initialCategory != 'All') {
      await _runCategorySearch(widget.initialCategory!);
      return;
    }

    if (_selectedCategory == 'All' && !widget.initialAllShowsCategories) {
      await _runAllServicesSearch();
      return;
    }

    if (_selectedCategory == 'All') {
      return;
    }

    await _runCategorySearch(_selectedCategory);
  }

  Future<void> _loadLocationFromProfile() async {
    try {
      final profileResp = await HomeownerService.instance.fetchProfile();
      final profile = profileResp['profile'];
      final addresses = (profileResp['addresses'] as List?) ??
          (profile is Map ? profile['addresses'] as List? : null) ??
          const [];
      if (addresses.isEmpty) return;

      final defaultAddr = addresses.firstWhere(
        (a) => a is Map && (a['isDefault'] == true || a['isDefault'] == 'true'),
        orElse: () => addresses.first,
      );
      if (defaultAddr is! Map) return;

      final city = _readText(defaultAddr['city']) ?? 'Home';
      final zip = _extractZip(defaultAddr['zip']) ?? _selectedZip;
      if (!mounted) {
        _selectedZip = zip;
        _applyLocationLabel(city, zip);
        return;
      }

      setState(() {
        _selectedZip = zip;
        _applyLocationLabel(city, zip);
      });
    } catch (_) {
      // Keep fallback ZIP if profile lookup fails.
    }
  }

  List<_BrowseCategory> get _visibleRailCategories =>
      _allCategories
          .where((cat) => _categorySlugForName(cat.name) != null)
          .take(9)
          .toList();

  List<_BrowseCategory> get _railCategoriesForCurrentSelection {
    final visible = [..._visibleRailCategories];
    if (_selectedCategory == 'All' ||
        visible.any((category) => category.name == _selectedCategory)) {
      return visible;
    }
    final missingIndex = _allCategories.indexWhere(
      (category) => category.name == _selectedCategory,
    );
    if (missingIndex == -1) {
      return visible;
    }
    return [...visible, _allCategories[missingIndex]];
  }

  void _ensureSelectedRailVisible() {
    if (!_railController.hasClients) return;
    final visible = _railCategoriesForCurrentSelection;
    final categoryIndex =
        visible.indexWhere((cat) => cat.name == _selectedCategory);
    if (_selectedCategory != 'All' && categoryIndex == -1) return;
    final selectedIndex =
        _selectedCategory == 'All' ? 0 : categoryIndex + 1;
    if (selectedIndex < 0) return;
    final targetOffset = (selectedIndex * 102.0 - 10).clamp(
      0.0,
      _railController.position.maxScrollExtent,
    );
    _railController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _queueSelectedRailVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureSelectedRailVisible();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) {
          _ensureSelectedRailVisible();
        }
      });
    });
  }

  Future<void> _refreshZipCoverage() async {
    final zip = _selectedZip.trim();
    if (zip.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() => _isLoadingCoverage = true);
    }

    try {
      final coverage = await HomeownerService.instance.getZipCoverage(zip: zip);
      final categories = (coverage['categories'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final nextCounts = <String, int>{};
      final nextCoverage = <String, bool>{};

      for (final category in _allCategories) {
        nextCounts[category.name] = 0;
        nextCoverage[category.name] = false;
      }

      for (final item in categories) {
        final slug = _readText(item['categorySlug']);
        final rawName = _readText(item['categoryName']);
        final appName = slug == null
            ? _normalizeCoverageCategoryName(rawName)
            : _categoryNameForSlug(slug);
        if (appName == null) {
          continue;
        }
        final count = item['proCount'] is num
            ? (item['proCount'] as num).toInt()
            : int.tryParse(item['proCount']?.toString() ?? '') ?? 0;
        nextCounts[appName] = count;
        nextCoverage[appName] = item['available'] == true || count > 0;
        if (appName == 'Home Security') {
          nextCounts['Smart Home'] = count;
          nextCoverage['Smart Home'] = item['available'] == true || count > 0;
        }
        if (appName == 'Concrete & Masonry') {
          nextCounts['Concrete'] = count;
          nextCoverage['Concrete'] = item['available'] == true || count > 0;
        }
      }

      final city = _readText(coverage['city']) ?? 'Home';
      final returnedZip = _readText(coverage['zip']) ?? zip;

      if (!mounted) {
        _categoryCounts
          ..clear()
          ..addAll(nextCounts);
        _categoryCoverage
          ..clear()
          ..addAll(nextCoverage);
        _selectedZip = returnedZip;
        _applyLocationLabel(city, returnedZip);
        return;
      }

      setState(() {
        _categoryCounts
          ..clear()
          ..addAll(nextCounts);
        _categoryCoverage
          ..clear()
          ..addAll(nextCoverage);
        _selectedZip = returnedZip;
        _applyLocationLabel(city, returnedZip);
        _isLoadingCoverage = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCoverage = false);
    }
  }

  String? _normalizeCoverageCategoryName(String? rawName) {
    if (rawName == null) {
      return null;
    }
    switch (rawName) {
      case 'Handyman & General Repairs':
        return 'Handyman';
      case 'Landscaping & Lawn Care':
        return 'Landscaping';
      case 'Junk Removal & Hauling':
        return 'Junk Removal';
      case 'Moving & Hauling':
        return 'Moving';
      case 'Remodeling & Construction':
        return 'Remodeling';
      case 'Screen Repair & Enclosures':
        return 'Screen Repair';
      case 'Home Security & Smart Home':
        return 'Home Security';
      case 'Insulation & Weatherization':
        return 'Insulation';
      default:
        return rawName;
    }
  }

  int _proCountForCategory(_BrowseCategory category) {
    return _categoryCounts[category.name] ?? 0;
  }

  bool _isCategoryCovered(_BrowseCategory category) {
    return _categoryCoverage[category.name] ?? false;
  }

  int get _allProsCount {
    if (_categoryCounts.isEmpty) {
      return 0;
    }
    return _categoryCounts.values.fold<int>(0, (sum, value) => sum + value);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      if (_searchFocusNode.hasFocus) {
        if (_searchController.text.trim().isEmpty) {
          _view = _BrowseView.searchFocused;
        } else if (_committedQuery == _searchController.text.trim()) {
          _view = _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
        } else {
          _view = _BrowseView.typeAhead;
        }
      } else if (_committedQuery != null) {
        _view = _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
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

  Future<void> _applyLocationInput(String raw) async {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final nextZip = _extractZip(normalized) ?? _selectedZip;
    final cityLabel = normalized.isEmpty
        ? 'Home'
        : RegExp(r'^\d{5}$').hasMatch(normalized)
            ? 'Home'
            : normalized
                .replaceAll(RegExp(r'\b\d{5}\b'), '')
                .replaceAll(RegExp(r'\s+·\s+'), ' ')
                .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
                .trim();

    if (!mounted) {
      _selectedZip = nextZip;
      _applyLocationLabel(cityLabel, nextZip);
      return;
    }

    setState(() {
      _selectedZip = nextZip;
      _applyLocationLabel(cityLabel, nextZip);
    });
    await _refreshZipCoverage();

    if (_committedQuery != null && _committedQuery!.isNotEmpty) {
      await _runQuerySearch(_committedQuery!);
    } else if (_selectedCategory != 'All') {
      await _runCategorySearch(_selectedCategory);
    }
  }

  Future<void> _submitSearch([String? rawQuery]) async {
    final query = (rawQuery ?? _searchController.text).trim();
    _committedQuery = query.isEmpty ? null : query;
    if (_committedQuery != null) {
      await _saveRecentSearch(_committedQuery!);
    }
    setState(() {
      _view = _committedQuery == null
          ? (_selectedCategory == 'All'
              ? _BrowseView.browse
              : _BrowseView.results)
          : _BrowseView.results;
    });
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    if (_committedQuery == null) {
      if (_selectedCategory == 'All') {
        await _runAllServicesSearch();
      } else {
        await _runCategorySearch(_selectedCategory);
      }
      return;
    }

    await _runQuerySearch(_committedQuery!);
  }

  void _openAllCategories() {
    setState(() {
      _selectedCategory = 'All';
      _committedQuery = null;
      _searchController.clear();
      _view = _BrowseView.allCategories;
    });
    _searchFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSelectedRailVisible();
    });
  }

  void _selectCategory(String category) {
    if (category == 'All') {
      _runAllServicesSearch();
      return;
    }
    setState(() {
      _selectedCategory = category;
      _committedQuery = null;
      _view = _BrowseView.browse;
    });
    _searchFocusNode.unfocus();
    _runCategorySearch(category);
    _queueSelectedRailVisibility();
  }

  List<_BrowseCategory> get _categoriesWithLivePros {
    final live = _allCategories
        .where((category) =>
            _categorySlugForName(category.name) != null &&
            _proCountForCategory(category) > 0)
        .toList();
    if (live.isNotEmpty) {
      return live;
    }
    return _visibleRailCategories;
  }

  Future<void> _runAllServicesSearch() async {
    final categories = _categoriesWithLivePros;
    if (!mounted) return;
    setState(() {
      _selectedCategory = 'All';
      _committedQuery = null;
      _searchController.clear();
      _isLoadingResults = true;
      _resultsError = null;
      _view = _BrowseView.browse;
    });
    _searchFocusNode.unfocus();

    final mergedPros = <_BrowsePro>[];
    final seen = <String>{};
    String? firstError;

    for (final category in categories) {
      final slug = _categorySlugForName(category.name);
      if (slug == null) continue;
      try {
        final response = await HomeownerService.instance.searchPros(
          zip: _selectedZip,
          categorySlug: slug,
        );
        final results = (response['results'] as List? ?? const [])
            .whereType<Map>()
            .map((result) => _BrowsePro.fromApi(
                  Map<String, dynamic>.from(result),
                  category: category.name,
                ));
        for (final pro in results) {
          final key = [
            pro.contractorId,
            pro.slug,
            pro.category,
            pro.name,
          ].where((part) => part.trim().isNotEmpty).join('|').toLowerCase();
          if (seen.add(key)) {
            mergedPros.add(pro);
          }
        }
      } catch (e) {
        firstError ??= e.toString().replaceAll('Exception: ', '');
      }
    }

    if (!mounted) return;
    setState(() {
      _livePros
        ..clear()
        ..addAll(mergedPros);
      _isLoadingResults = false;
      _resultsError = mergedPros.isEmpty ? firstError : null;
      _view = mergedPros.isEmpty ? _BrowseView.noCoverage : _BrowseView.browse;
    });
    _queueSelectedRailVisibility();
  }

  _BrowseView _resolveSearchView(String query) {
    if (query.trim().isEmpty) {
      return _BrowseView.searchFocused;
    }
    return _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
  }

  Future<void> _runQuerySearch(String query) async {
    try {
      final intakeData = await IntakeService.instance.assist(
        text: query,
        zip: _selectedZip,
      );
      final resolution = IntakeResolution.fromApi(intakeData);

      if (resolution.outcome == 'life_safety') {
        if (!mounted) return;
        setState(() {
          _livePros.clear();
          _resultsError =
              'This issue may be life-safety related. Contact local emergency services first.';
          _view = _BrowseView.noCoverage;
          _isLoadingResults = false;
        });
        return;
      }

      if (resolution.outcome == 'clarify') {
        if (!mounted) return;
        setState(() {
          _livePros.clear();
          _resultsError = resolution.clarifyingQuestion ??
              'Please describe the issue a little more clearly.';
          _view = _BrowseView.noCoverage;
          _isLoadingResults = false;
        });
        return;
      }

      final resolvedCategory = resolution.categorySlug != null
          ? _categoryNameForSlug(resolution.categorySlug!)
          : _resolveSearchCategory(query);
      if (resolvedCategory == null) {
        throw Exception('AI intake could not resolve this request to a supported category.');
      }

      await _runCategorySearch(
        resolvedCategory,
        overrideQuery: resolution.scopedDescription ?? query,
        urgency: resolution.suggestedUrgency,
        forcedSlug: resolution.categorySlug,
      );
    } catch (e) {
      final resolvedCategory = _resolveSearchCategory(query);
      if (resolvedCategory == null) {
        if (!mounted) return;
        setState(() {
          _livePros.clear();
          _resultsError = e.toString().replaceAll('Exception: ', '');
          _view = _BrowseView.noCoverage;
          _isLoadingResults = false;
        });
        return;
      }

      await _runCategorySearch(
        resolvedCategory,
        overrideQuery: query,
      );
    }
  }

  Future<void> _runCategorySearch(
    String category, {
    String? overrideQuery,
    String urgency = 'standard',
    String? forcedSlug,
  }) async {
    final slug = forcedSlug ?? _categorySlugForName(category);
    if (slug == null) {
      if (!mounted) return;
      setState(() {
        _livePros.clear();
        _resultsError = 'This category is not connected to live search yet.';
        _view = _BrowseView.noCoverage;
        _isLoadingResults = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      _isLoadingResults = true;
      _resultsError = null;
      _view = overrideQuery == null ? _BrowseView.browse : _BrowseView.results;
    });

    try {
      final response = await HomeownerService.instance.searchPros(
        zip: _selectedZip,
        categorySlug: slug,
        urgency: urgency,
      );
      final results = (response['results'] as List? ?? const [])
          .whereType<Map>()
          .map((result) => _BrowsePro.fromApi(
                Map<String, dynamic>.from(result),
                category: category,
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _livePros
          ..clear()
          ..addAll(results);
        _categoryCounts[category] =
            response['count'] is num
                ? (response['count'] as num).toInt()
                : results.length;
        _categoryCoverage[category] =
            response['covered'] == true || results.isNotEmpty;
        _isLoadingResults = false;
        _resultsError = null;
        _view = results.isEmpty ? _BrowseView.noCoverage : _view;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _livePros.clear();
        _isLoadingResults = false;
        _resultsError = e.toString().replaceAll('Exception: ', '');
        _view = _BrowseView.noCoverage;
      });
    }
  }

  String? _resolveSearchCategory(String query) {
    final normalized = _normalizeSearchText(query);
    if (normalized.isEmpty) {
      return _selectedCategory == 'All' ? 'HVAC' : _selectedCategory;
    }

    for (final service in _serviceCatalog) {
      final serviceName = _normalizeSearchText(service.name);
      if (serviceName.contains(normalized) || normalized.contains(serviceName)) {
        return service.category;
      }
    }

    for (final category in _allCategories) {
      final categoryName = _normalizeSearchText(category.name);
      if (categoryName.contains(normalized) || normalized.contains(categoryName)) {
        return category.name;
      }
    }

    final keywordMap = <String, String>{
      'ac': 'HVAC',
      'air': 'HVAC',
      'cooling': 'HVAC',
      'heating': 'HVAC',
      'furnace': 'HVAC',
      'thermostat': 'HVAC',
      'plumb': 'Plumbing',
      'drain': 'Plumbing',
      'toilet': 'Plumbing',
      'pipe': 'Plumbing',
      'water heater': 'Plumbing',
      'outlet': 'Electrical',
      'breaker': 'Electrical',
      'panel': 'Electrical',
      'fan': 'Electrical',
      'switch': 'Electrical',
      'appliance': 'Appliance Repair',
      'washer': 'Appliance Repair',
      'dryer': 'Appliance Repair',
      'fridge': 'Appliance Repair',
      'garage': 'Garage Doors',
      'door': 'Windows & Doors',
      'window': 'Windows & Doors',
      'roof': 'Roofing',
      'fence': 'Fencing & Decks',
      'deck': 'Fencing & Decks',
      'lock': 'Locksmith',
      'clean': 'Cleaning',
      'lawn': 'Landscaping',
      'landscap': 'Landscaping',
      'handyman': 'Handyman',
      'tree': 'Tree Service',
      'water softener': 'Water Treatment',
      'filtration': 'Water Treatment',
      'moving': 'Moving',
      'junk': 'Junk Removal',
    };

    for (final entry in keywordMap.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll('&', ' ').replaceAll('-', ' ').trim();
  }

  String? _categorySlugForName(String category) {
    switch (category) {
      case 'Handyman':
        return 'handyman-general-repairs';
      case 'HVAC':
        return 'hvac';
      case 'Air Duct & Vent':
        return 'air-duct-vent-services';
      case 'Plumbing':
        return 'plumbing';
      case 'Electrical':
        return 'electrical';
      case 'Pool & Spa':
        return 'pool-spa';
      case 'Cleaning':
        return 'cleaning';
      case 'Landscaping':
        return 'landscaping-lawn-care';
      case 'Tree Service':
        return 'tree-service';
      case 'Pest Control':
        return 'pest-control';
      case 'Pressure Washing':
        return 'pressure-washing-exterior-cleaning';
      case 'Flooring':
        return 'flooring';
      case 'Painting':
        return 'painting';
      case 'Drywall & Plaster':
        return 'drywall-plaster';
      case 'Roofing':
        return 'roofing';
      case 'Gutters':
        return 'gutters';
      case 'Siding':
        return 'siding';
      case 'Water Treatment':
        return 'water-treatment';
      case 'Garage Doors':
        return 'garage-doors';
      case 'Moving':
        return 'moving-hauling';
      case 'Appliance Repair':
        return 'appliance-repair';
      case 'Locksmith':
        return 'locksmith';
      case 'Windows & Doors':
        return 'windows-doors';
      case 'Screen Repair':
        return 'screen-repair-enclosures';
      case 'Fencing & Decks':
        return 'fencing-decks';
      case 'Concrete':
      case 'Concrete & Masonry':
        return 'concrete-masonry';
      case 'Remodeling':
        return 'remodeling-construction';
      case 'Home Security':
      case 'Smart Home':
        return 'home-security-smart-home';
      case 'Insulation':
        return 'insulation-weatherization';
      case 'Junk Removal':
        return 'junk-removal-hauling';
      case 'Fireplace & Chimney':
        return 'fireplace-chimney';
      default:
        return null;
    }
  }

  String? _categoryNameForSlug(String slug) {
    switch (slug) {
      case 'handyman-general-repairs':
        return 'Handyman';
      case 'hvac':
        return 'HVAC';
      case 'air-duct-vent-services':
        return 'Air Duct & Vent';
      case 'plumbing':
        return 'Plumbing';
      case 'electrical':
        return 'Electrical';
      case 'pool-spa':
        return 'Pool & Spa';
      case 'cleaning':
        return 'Cleaning';
      case 'landscaping-lawn-care':
        return 'Landscaping';
      case 'tree-service':
        return 'Tree Service';
      case 'pest-control':
        return 'Pest Control';
      case 'pressure-washing-exterior-cleaning':
        return 'Pressure Washing';
      case 'flooring':
        return 'Flooring';
      case 'painting':
        return 'Painting';
      case 'drywall-plaster':
        return 'Drywall & Plaster';
      case 'roofing':
        return 'Roofing';
      case 'gutters':
        return 'Gutters';
      case 'siding':
        return 'Siding';
      case 'water-treatment':
        return 'Water Treatment';
      case 'garage-doors':
        return 'Garage Doors';
      case 'moving-hauling':
        return 'Moving';
      case 'appliance-repair':
        return 'Appliance Repair';
      case 'locksmith':
        return 'Locksmith';
      case 'windows-doors':
        return 'Windows & Doors';
      case 'screen-repair-enclosures':
        return 'Screen Repair';
      case 'fencing-decks':
        return 'Fencing & Decks';
      case 'concrete-masonry':
        return 'Concrete & Masonry';
      case 'remodeling-construction':
        return 'Remodeling';
      case 'home-security-smart-home':
        return 'Home Security';
      case 'insulation-weatherization':
        return 'Insulation';
      case 'junk-removal-hauling':
        return 'Junk Removal';
      case 'fireplace-chimney':
        return 'Fireplace & Chimney';
      default:
        return null;
    }
  }

  String? _readText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String? _extractZip(dynamic value) {
    final text = _readText(value);
    if (text == null) return null;
    final match = RegExp(r'\b(\d{5})\b').firstMatch(text);
    return match?.group(1);
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

  List<_BrowseService> get _serviceCatalog {
    final ordered = <_BrowseService>[];
    final seen = <String>{};

    void addService(_BrowseService service) {
      final key = service.name.toLowerCase();
      if (seen.add(key)) {
        ordered.add(service);
      }
    }

    for (final service in _popularServices) {
      addService(service);
    }
    return ordered;
  }

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
    final matches = _livePros.where((pro) {
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
    return const [];
  }

  Map<String, dynamic> _toProMap(_BrowsePro pro) {
    return {
      'slug': pro.slug,
      'profileSlug': pro.slug,
      'contractorId': pro.contractorId,
      'contractor_id': pro.contractorId,
      'userId': pro.userId,
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
      'photoUrl': pro.photoUrl,
      'profile_image_url': pro.photoUrl,
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
    final visiblePros = _livePros;
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
        body = _buildResults(_livePros);
        break;
      case _BrowseView.noCoverage:
        body = _buildNoCoverage();
        break;
      case _BrowseView.browse:
      default:
        body = (visiblePros.isEmpty &&
                !_isLoadingResults &&
                _resultsError == null)
            ? _buildNoCoverage()
            : _buildBrowseDefault(visiblePros);
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        _buildWireframePills(
          focused: false,
          placeholder: 'Search a service or pro',
          onSearchTap: _setFocusSearch,
        ),
        const SizedBox(height: 14),
        _buildRail(_railCategoriesForCurrentSelection),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${visiblePros.length} vetted pros',
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
        if (_isLoadingResults)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.orange500),
            ),
          )
        else if (_resultsError != null)
          _buildInlineState(_resultsError!)
        else if (visiblePros.isEmpty)
          _buildInlineState('No live contractors were returned for $_selectedZip.')
        else
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
            title: 'All services',
            onBack: () => setState(() => _view = _BrowseView.browse),
          )
        else
          const SizedBox(height: 14),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Serving $_selectedZip',
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${_allProsCount} live pros · 31 categories',
                    style: TextStyle(
                      color: AppTheme.gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ..._allCategories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AllServicesRow(
                    category: category,
                    services: _servicesForCategory(category.name),
                    onTap: () {
                      if (!_isCategoryCovered(category)) {
                        setState(() {
                          _selectedCategory = category.name;
                          _view = _BrowseView.noCoverage;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _ensureSelectedRailVisible();
                        });
                        return;
                      }
                      _selectCategory(category.name);
                    },
                  ),
                ),
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
        _buildTopSearchBar(),
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
        ..._serviceCatalog.take(8).map((service) => _buildListChipRow(
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
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildSectionHeader('Pros near you'),
                const SizedBox(height: 10),
                ...matches.take(3).map(_buildMiniProRow),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(List<_BrowsePro> matches) {
    return Column(
      children: [
        _buildTopSearchBar(collapsed: true),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              if (_isLoadingResults)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.orange500),
                  ),
                )
              else if (_resultsError != null)
                _buildInlineState(_resultsError!)
              else if (matches.isEmpty)
                _buildInlineState('No live contractors matched this search.')
              else
                ...matches.map((pro) => Padding(
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildRail(_railCategoriesForCurrentSelection),
              const SizedBox(height: 24),
              Container(
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
                    Text(
                      _selectedCategory == 'All'
                          ? 'We do not have vetted pros for this service in $_selectedZip yet.'
                          : 'We do not have vetted pros for $_selectedCategory in $_selectedZip yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.gray, fontSize: 13),
                    ),
                    if (_resultsError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _resultsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
            ],
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
        _buildSearchInputPill(collapsed: !focused),
        const SizedBox(height: 10),
        _buildLocationPill(),
      ],
    );
  }

  Widget _buildSearchInputPill({bool collapsed = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: collapsed ? 12 : 14),
      decoration: BoxDecoration(
        color: _searchFocusNode.hasFocus ? AppTheme.orangeTint : AppTheme.pageAlt,
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
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onTap: _setFocusSearch,
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
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search a service or pro',
                hintStyle: TextStyle(color: AppTheme.gray),
              ),
              style: const TextStyle(
                color: AppTheme.navy700,
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
                  onPressed: () async {
                    final raw = controller.text.trim();
                    Navigator.pop(context);
                    await _applyLocationInput(raw);
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
        meta: _isLoadingCoverage ? '...' : '${_allProsCount} pros',
        icon: Icons.apps_rounded,
        accent: AppTheme.orange500,
        selected: _selectedCategory == 'All',
        onTap: _runAllServicesSearch,
      ),
      ...categories.map(
        (category) => _RailChip(
          label: category.name,
          meta: _isLoadingCoverage
              ? '...'
              : '${_proCountForCategory(category)} pros',
          icon: category.icon,
          accent: category.color,
          selected: _selectedCategory == category.name,
          onTap: () => _selectCategory(category.name),
        ),
      ),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        controller: _railController,
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

  Widget _buildInlineState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.gray,
          fontSize: 13,
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
    if (query.isEmpty) return _serviceCatalog;
    return _serviceCatalog
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

  List<String> _servicesForCategory(String categoryName) {
    return _serviceCatalog
        .where((service) => service.category == categoryName)
        .map((service) => service.name)
        .take(3)
        .toList();
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
  final String contractorId;
  final String userId;
  final String apiSlug;
  final String name;
  final String? photoUrl;
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
    this.contractorId = '',
    this.userId = '',
    this.apiSlug = '',
    required this.name,
    this.photoUrl,
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

  factory _BrowsePro.fromApi(
    Map<String, dynamic> map, {
    required String category,
  }) {
    String read(dynamic value, [String fallback = '']) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
    }

    double readDouble(dynamic value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(read(value)) ?? fallback;
    }

    int readInt(dynamic value, [int fallback = 0]) {
      if (value is num) return value.toInt();
      return int.tryParse(read(value)) ?? fallback;
    }

    final businessName = read(map['businessName'], 'Service Pro');
    final initials = businessName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final rating = readDouble(map['verifiedRating'], 0);
    final reviews = readInt(map['verifiedCount'], 0);
    final distance = readDouble(map['distanceMiles'], 0);
    final price = readDouble(map['fromPrice'], 0).round();
    final completedWorkOrders = readInt(map['completedWorkOrders'], reviews);
    final nextAvailableRaw = read(map['nextAvailable']);
    String defaultTradeForCategory(String categoryName) {
      switch (categoryName.toLowerCase()) {
        case 'hvac':
          return 'Heating & Cooling';
        case 'plumbing':
          return 'Repair & Install';
        case 'electrical':
          return 'Repair & Install';
        case 'cleaning':
          return 'Home Cleaning';
        case 'roofing':
          return 'Roof Repair';
        case 'lawn':
        case 'landscaping':
          return 'Lawn Care';
        case 'handyman':
          return 'Home Repairs';
        case 'appliances':
        case 'appliance repair':
          return 'Repair';
        default:
          return 'Service';
      }
    }

    String titleCase(String value) {
      if (value.trim().isEmpty) return value;
      return value
          .split(RegExp(r'\s+'))
          .map((word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
          .join(' ');
    }

    final trade = read(
      map['trade'],
      read(map['specialty'], defaultTradeForCategory(category)),
    );
    final priceLabel = titleCase(read(map['fromUnit'], 'Upfront price'));
    final selectedCertified =
        map['selectedCertified'] == true || map['isSelectCertified'] == true;

    final ratingLabel = rating >= 4.9
        ? 'Exceptional'
        : rating >= 4.7
            ? 'Great'
            : rating > 0
                ? 'Good'
                : 'New';

    return _BrowsePro(
      contractorId: read(map['contractorId'], read(map['id'])),
      userId: read(map['userId']),
      apiSlug: read(map['slug']),
      name: businessName,
      photoUrl: read(map['photoUrl']).isEmpty ? null : read(map['photoUrl']),
      initials: initials.isEmpty ? 'SP' : initials,
      category: category,
      trade: trade,
      ratingLabel: ratingLabel,
      rating: rating == 0 ? 5.0 : rating,
      reviews: reviews,
      distanceMiles: distance,
      completedWorkOrders: completedWorkOrders,
      nextAvailable: nextAvailableRaw.isEmpty ? 'Availability pending' : nextAvailableRaw,
      price: price,
      priceLabel: priceLabel,
      summary: read(map['tagline'], read(map['summary'], 'Vetted local pro')),
      selectedCertified: selectedCertified,
      services: const [],
      mediaCount: 0,
      responseTime: 'Availability synced from backend',
    );
  }

  String get slug =>
      apiSlug.isNotEmpty ? apiSlug : name.toLowerCase().replaceAll(' ', '-');
}

class _RailChip extends StatelessWidget {
  final String label;
  final String meta;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _RailChip({
    required this.label,
    required this.meta,
    required this.icon,
    required this.accent,
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
          color: selected
              ? accent
              : accent == AppTheme.navy700
                  ? AppTheme.navyTint
                  : accent == AppTheme.orange500
                      ? AppTheme.orangeTint
                      : AppTheme.tealTint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : accent.withOpacity(0.25),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? icon : icon,
              color: selected ? Colors.white : accent,
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
                color: selected ? Colors.white.withOpacity(0.82) : AppTheme.gray,
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

class _AllServicesRow extends StatelessWidget {
  final _BrowseCategory category;
  final List<String> services;
  final VoidCallback onTap;

  const _AllServicesRow({
    required this.category,
    required this.services,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = category.color == AppTheme.navy700
        ? AppTheme.navyTint
        : category.color == AppTheme.orange500
            ? AppTheme.orangeTint
            : AppTheme.tealTint;
    final dimmed = !category.covered;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, color: category.color, size: 24),
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
                            category.name,
                            style: const TextStyle(
                              color: AppTheme.navy700,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          dimmed ? 'No pros' : '${category.prosCount} pros',
                          style: TextStyle(
                            color: dimmed ? AppTheme.gray : category.color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.serviceCount} services',
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      services.isEmpty
                          ? 'Browse this category'
                          : services.join(' · '),
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.gray),
            ],
          ),
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

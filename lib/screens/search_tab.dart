import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/homeowner_service.dart';
import '../services/auth_service.dart';
import '../services/intake_service.dart';
import '../services/browse_search_history.dart';
import '../services/service_catalog.dart';
import '../services/service_location.dart';
import '../theme.dart';
import '../utils/app_error_utils.dart';
import '../utils/service_search_matcher.dart';
import '../widgets/ai_intake_sheet.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/service_zip_entry_dialog.dart';
import '../widgets/service_search_bar.dart';
import 'pro_profile.dart';

enum _BrowseView {
  browse,
  allCategories,
  searchFocused,
  typeAhead,
  results,
  noCoverage,
}

enum _BrowseSort { highestRated, nearest, lowestPrice }

extension on _BrowseSort {
  String get label {
    switch (this) {
      case _BrowseSort.highestRated:
        return 'Highest rated';
      case _BrowseSort.nearest:
        return 'Nearest';
      case _BrowseSort.lowestPrice:
        return 'Lowest price';
    }
  }
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
  static const Map<String, Color> _homeCategoryBackgrounds = {
    'HVAC': Color(0xFFE3F2FD),
    'Plumbing': Color(0xFFE0F7FA),
    'Electrical': Color(0xFFFFF8E1),
    'Cleaning': Color(0xFFE8F5E9),
    'Roofing': Color(0xFFFFEBEE),
    'Lawn': Color(0xFFF1F8E9),
    'Landscaping': Color(0xFFF1F8E9),
    'Handyman': Color(0xFFF3E5F5),
  };
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _railController;
  final TextEditingController _locationController = TextEditingController();
  final List<String> _recentSearches = [];
  final BrowseSearchHistory _searchHistory = BrowseSearchHistory();
  final List<_BrowsePro> _livePros = [];
  final Map<String, int> _categoryCounts = {};
  final Map<String, bool> _categoryCoverage = {};
  final Map<String, String> _liveNextSlotLabels = {};

  _BrowseView _view = _BrowseView.browse;
  _BrowseSort _browseSort = _BrowseSort.highestRated;
  String _selectedCategory = 'All';
  String _selectedZip = '';
  String? _committedQuery;
  bool _isLoadingResults = false;
  bool _isLoadingCoverage = false;
  String? _resultsError;
  int _availabilityHydrationToken = 0;
  int _prosRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    _searchFocusNode = FocusNode();
    _railController = ScrollController();
    _searchFocusNode.addListener(_handleFocusChange);
    BrowseSearchHistory.revision.addListener(_loadRecentSearches);
    ServiceLocation.selected.addListener(_handleSharedLocationChanged);
    HomeownerService.instance.contractorCatalogVersion
        .addListener(_refreshContractorCatalog);
    _applyLocationLabel('Enter ZIP code', _selectedZip);
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
    BrowseSearchHistory.revision.removeListener(_loadRecentSearches);
    ServiceLocation.selected.removeListener(_handleSharedLocationChanged);
    HomeownerService.instance.contractorCatalogVersion
        .removeListener(_refreshContractorCatalog);
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    _railController.dispose();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _refreshContractorCatalog() {
    if (!mounted || _isLoadingResults) return;

    // A submitted review invalidates the shared catalog cache. Reload the
    // exact browse context that is already visible, so its rating/count and
    // sort order change without requiring a manual pull-to-refresh.
    final query = _committedQuery?.trim();
    if (query != null && query.isNotEmpty) {
      unawaited(_runQuerySearch(query));
      return;
    }
    if (_selectedCategory == 'All') {
      if (widget.initialAllShowsCategories && _livePros.isEmpty) return;
      unawaited(_runAllServicesSearch());
      return;
    }
    unawaited(_runCategorySearch(_selectedCategory));
  }

  Future<void> _loadRecentSearches() async {
    final stored = await _searchHistory.load();
    if (!mounted) return;
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(stored);
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final saved = await _searchHistory.save(query);
    if (mounted) {
      setState(() {
        _recentSearches
          ..clear()
          ..addAll(saved);
      });
    }
  }

  void _applyLocationLabel(String city, String zip) {
    final normalizedCity = city.trim().isEmpty ? 'Home' : city.trim();
    if (zip.trim().isEmpty) {
      _locationController.text = normalizedCity;
      return;
    }
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
    await _loadSharedLocationOverride();
    if (await _requestGuestZipIfNeeded()) {
      return;
    }
    await _loadLocationFromProfile();
    if (_selectedZip.isEmpty) {
      return;
    }
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
    final sharedZip = await _getSharedZipOverride();
    if (sharedZip != null) {
      return;
    }
    // Browse is public. Guest location comes from the shared ZIP/fallback,
    // while account addresses are only consulted after authentication.
    if (!AuthService.instance.isAuthenticated) {
      return;
    }
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

  Future<String?> _getSharedZipOverride() async {
    return (await ServiceLocation.load())?.zip;
  }

  Future<void> _loadSharedLocationOverride() async {
    final location = await ServiceLocation.load();
    if (location == null) {
      return;
    }
    final resolvedLocation =
        location.locationName.isEmpty ? 'Home' : location.locationName;
    if (!mounted) {
      _selectedZip = location.zip;
      _applyLocationLabel(resolvedLocation, location.zip);
      return;
    }
    setState(() {
      _selectedZip = location.zip;
      _applyLocationLabel(resolvedLocation, location.zip);
    });
  }

  Future<void> _saveSharedLocationOverride(
      String zip, String locationName) async {
    await ServiceLocation.save(zip: zip, locationName: locationName);
  }

  Future<bool> _requestGuestZipIfNeeded() async {
    if (AuthService.instance.isAuthenticated) {
      return false;
    }
    final sharedZip = await _getSharedZipOverride();
    if (!mounted || sharedZip != null) {
      return false;
    }

    final zip = await showServiceZipEntryDialog(
      context,
      initialZip: '',
    );
    if (zip == null || !mounted) {
      return false;
    }
    await _applyLocationInput(zip);
    return true;
  }

  void _handleSharedLocationChanged() {
    final location = ServiceLocation.selected.value;
    if (location == null || !mounted || location.zip == _selectedZip) {
      return;
    }
    unawaited(_applyLocationInput(location.zip));
  }

  List<_BrowseCategory> get _visibleRailCategories => _allCategories
      .where((cat) => _categorySlugForName(cat.name) != null)
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
    final selectedIndex = _selectedCategory == 'All' ? 0 : categoryIndex + 1;
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

      final city = _readText(coverage['city']) ??
          _readText(coverage['areaName']) ??
          _readText(coverage['area_name']) ??
          'Home';
      final state = _readText(coverage['state']);
      final resolvedLocation = [city, state]
          .where((part) => part != null && part.trim().isNotEmpty)
          .join(', ');
      final returnedZip = _readText(coverage['zip']) ?? zip;
      await _saveSharedLocationOverride(returnedZip, resolvedLocation);

      if (!mounted) {
        _categoryCounts
          ..clear()
          ..addAll(nextCounts);
        _categoryCoverage
          ..clear()
          ..addAll(nextCoverage);
        _selectedZip = returnedZip;
        _applyLocationLabel(resolvedLocation, returnedZip);
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
        _applyLocationLabel(resolvedLocation, returnedZip);
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

  int get _allProsCount {
    if (_categoryCounts.isEmpty) {
      return 0;
    }
    return _categoryCounts.values.fold<int>(0, (sum, value) => sum + value);
  }

  String get _locationChipLabel {
    final normalized = _normalizeLocationText(_locationController.text);
    final parts = normalized
        .split(String.fromCharCode(183))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return _selectedZip;
    }
    if (parts.length == 1) {
      return parts.first;
    }
    return '${parts.first}, ${parts.last}';
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      if (_searchFocusNode.hasFocus) {
        if (_searchController.text.trim().isEmpty) {
          _view = _BrowseView.searchFocused;
        } else if (_committedQuery == _searchController.text.trim()) {
          _view =
              _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
        } else {
          _view = _BrowseView.typeAhead;
        }
      } else if (_committedQuery != null) {
        _view =
            _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
      } else if (_selectedCategory == 'All') {
        _view = _BrowseView.browse;
      } else {
        _view = _BrowseView.browse;
      }
    });
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
      await _saveSharedLocationOverride(nextZip, cityLabel);
      return;
    }

    setState(() {
      _selectedZip = nextZip;
      _applyLocationLabel(cityLabel, nextZip);
      _livePros.clear();
      _liveNextSlotLabels.clear();
      _isLoadingResults = true;
      _resultsError = null;
      _prosRequestToken++;
    });
    await _saveSharedLocationOverride(nextZip, cityLabel);
    await _refreshZipCoverage();

    if (_committedQuery != null && _committedQuery!.isNotEmpty) {
      await _runQuerySearch(_committedQuery!);
    } else if (_selectedCategory == 'All') {
      await _runAllServicesSearch();
    } else {
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

  Future<void> _openAiLayer(String mode) async {
    final result = await showModalBottomSheet<AiIntakeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AiIntakeSheet(
        initialMode: mode,
        initialZip: _selectedZip,
      ),
    );

    if (result == null || !mounted) {
      return;
    }
    _searchController.text = result.query;
    _searchController.selection = TextSelection.collapsed(
      offset: result.query.length,
    );
    await _submitSearch(result.query);
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

  Future<void> _returnToBrowsePage() async {
    _searchFocusNode.unfocus();
    if (!mounted) return;
    setState(() {
      _selectedCategory = 'All';
      _committedQuery = null;
      _resultsError = null;
      _searchController.clear();
      _livePros.clear();
      _view = _BrowseView.browse;
    });
    await _runAllServicesSearch();
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
    final requestToken = ++_prosRequestToken;
    final requestedZip = _selectedZip;
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
          zip: requestedZip,
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
        final message = e.toString().replaceAll('Exception: ', '');
        firstError ??= message;
        if (AppErrorUtils.isNetworkError(e) ||
            message == AppErrorUtils.webFetchMessage ||
            message == AppErrorUtils.noInternetMessage) {
          break;
        }
      }
    }

    if (!mounted ||
        requestToken != _prosRequestToken ||
        requestedZip != _selectedZip) {
      return;
    }
    setState(() {
      final discoveredCounts = <String, int>{
        for (final category in _allCategories) category.name: 0,
      };
      final discoveredCoverage = <String, bool>{
        for (final category in _allCategories) category.name: false,
      };
      for (final pro in mergedPros) {
        final categoryName = _categoryNameForLivePro(pro.category);
        if (categoryName == null) continue;
        discoveredCounts[categoryName] =
            (discoveredCounts[categoryName] ?? 0) + 1;
        discoveredCoverage[categoryName] = true;
      }
      _livePros
        ..clear()
        ..addAll(mergedPros);
      _liveNextSlotLabels.clear();
      _categoryCounts.addAll(discoveredCounts);
      _categoryCoverage.addAll(discoveredCoverage);
      _isLoadingResults = false;
      _resultsError = mergedPros.isEmpty ? firstError : null;
      _view = mergedPros.isEmpty ? _BrowseView.noCoverage : _BrowseView.browse;
    });
    unawaited(_hydrateNextAvailability(mergedPros));
    _queueSelectedRailVisibility();
  }

  String? _categoryNameForLivePro(String rawCategory) {
    final normalized =
        _normalizeCoverageCategoryName(rawCategory) ?? rawCategory;
    for (final category in _allCategories) {
      if (category.name.toLowerCase() == normalized.toLowerCase()) {
        return category.name;
      }
    }
    return null;
  }

  _BrowseView _resolveSearchView(String query) {
    if (query.trim().isEmpty) {
      return _BrowseView.searchFocused;
    }
    return _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
  }

  Future<void> _runQuerySearch(String query) async {
    // A high-confidence local match is kept as a safety net for typo-only
    // requests. The AI intake can still enrich normal language queries.
    final localCategory = _resolveSearchCategory(query);
    if (localCategory != null) {
      await _runCategorySearch(localCategory, overrideQuery: query);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoadingResults = true;
      _resultsError = null;
      _view = _BrowseView.results;
    });
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

      // Locally corrected service terms are more reliable than a remote
      // category guess for a short misspelling or acronym permutation.
      final resolvedCategory = localCategory ??
          (resolution.categorySlug != null
              ? _categoryNameForSlug(resolution.categorySlug!)
              : null);
      if (resolvedCategory == null) {
        throw Exception(
            'AI intake could not resolve this request to a supported category.');
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
    final requestToken = ++_prosRequestToken;
    final requestedZip = _selectedZip;
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
        zip: requestedZip,
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

      if (!mounted ||
          requestToken != _prosRequestToken ||
          requestedZip != _selectedZip) {
        return;
      }
      setState(() {
        _livePros
          ..clear()
          ..addAll(results);
        _liveNextSlotLabels.clear();
        _categoryCounts[category] = response['count'] is num
            ? (response['count'] as num).toInt()
            : results.length;
        _categoryCoverage[category] =
            response['covered'] == true || results.isNotEmpty;
        _isLoadingResults = false;
        _resultsError = null;
        _view = results.isEmpty ? _BrowseView.noCoverage : _view;
      });
      unawaited(_hydrateNextAvailability(results));
    } catch (e) {
      if (!mounted ||
          requestToken != _prosRequestToken ||
          requestedZip != _selectedZip) {
        return;
      }
      setState(() {
        _livePros.clear();
        _isLoadingResults = false;
        _resultsError = e.toString().replaceAll('Exception: ', '');
        _view = _BrowseView.noCoverage;
      });
    }
  }

  Future<void> _hydrateNextAvailability(List<_BrowsePro> pros) async {
    // Public search already returns `nextAvailable`. Avoid a second wave of
    // per-pro availability requests for guests; those endpoints are optional
    // enrichment and must never make public browsing noisy or fragile.
    if (!AuthService.instance.isAuthenticated) {
      return;
    }
    final token = ++_availabilityHydrationToken;
    final now = DateTime.now();
    final fromDate = DateFormat('yyyy-MM-dd').format(now);
    final toDate =
        DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 14)));
    final nextLabels = <String, String>{};

    Future<void> loadForPro(_BrowsePro pro) async {
      if (pro.contractorId.trim().isEmpty) {
        return;
      }
      try {
        final availability =
            await HomeownerService.instance.getContractorAvailability(
          contractorId: pro.contractorId,
          urgency: 'standard',
          fromDate: fromDate,
          toDate: toDate,
        );
        final slots = (availability['slots'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (slots.isEmpty) {
          return;
        }
        final label = _formatSlotLabel(
          _readText(slots.first['start']),
          _readText(slots.first['end']),
        );
        if (label == null || label.isEmpty) {
          return;
        }
        nextLabels[_proAvailabilityKey(pro)] = label;
      } catch (_) {
        // Keep the search response label if availability enrichment fails.
      }
    }

    await Future.wait(pros.take(12).map(loadForPro));
    if (!mounted ||
        token != _availabilityHydrationToken ||
        nextLabels.isEmpty) {
      return;
    }
    setState(() {
      _liveNextSlotLabels.addAll(nextLabels);
    });
  }

  String _proAvailabilityKey(_BrowsePro pro) {
    if (pro.contractorId.trim().isNotEmpty) {
      return 'id:${pro.contractorId.trim().toLowerCase()}';
    }
    if (pro.slug.trim().isNotEmpty) {
      return 'slug:${pro.slug.trim().toLowerCase()}';
    }
    return 'name:${pro.name.trim().toLowerCase()}';
  }

  String _nextAvailableLabelFor(_BrowsePro pro) {
    return _liveNextSlotLabels[_proAvailabilityKey(pro)] ??
        _formatLooseAvailabilityLabel(pro.nextAvailable);
  }

  String _formatLooseAvailabilityLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Availability pending';
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      return _formatSlotLabel(trimmed, null) ?? trimmed;
    }
    return trimmed;
  }

  String? _formatSlotLabel(String? startRaw, String? endRaw) {
    if (startRaw == null || startRaw.trim().isEmpty) {
      return null;
    }
    final start = DateTime.tryParse(startRaw)?.toLocal();
    if (start == null) {
      return null;
    }
    final end = DateTime.tryParse(endRaw ?? '')?.toLocal();
    final now = DateTime.now();
    final startDate = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysDiff = startDate.difference(today).inDays;

    final String dayLabel;
    if (daysDiff == 0) {
      dayLabel = 'Today';
    } else if (daysDiff == 1) {
      dayLabel = 'Tomorrow';
    } else {
      dayLabel = DateFormat('EEE').format(start);
    }

    final startHour = DateFormat('h').format(start);
    final startMeridiem = DateFormat('a').format(start);
    String timeLabel = '$startHour $startMeridiem';
    if (end != null) {
      final endHour = DateFormat('h').format(end);
      final endMeridiem = DateFormat('a').format(end);
      timeLabel = startMeridiem == endMeridiem
          ? '$startHour-$endHour $endMeridiem'
          : '$startHour $startMeridiem-$endHour $endMeridiem';
    }

    return '$dayLabel, $timeLabel';
  }

  String? _resolveSearchCategory(String query) {
    final normalized = _normalizeSearchText(query);
    if (normalized.isEmpty) {
      return _selectedCategory == 'All' ? 'HVAC' : _selectedCategory;
    }

    final exactCategory = _exactServiceCategory(normalized);
    if (exactCategory != null) {
      return exactCategory;
    }

    for (final service in _serviceCatalog) {
      final serviceName = _normalizeSearchText(service.name);
      if (serviceName.contains(normalized) ||
          normalized.contains(serviceName)) {
        return service.category;
      }
    }

    for (final category in _allCategories) {
      final categoryName = _normalizeSearchText(category.name);
      if (categoryName.contains(normalized) ||
          normalized.contains(categoryName)) {
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

    return ServiceSearchMatcher.bestCategory(
      query: normalized,
      termsByCategory: _searchTermsByCategory(keywordMap),
    );
  }

  String _normalizeSearchText(String value) {
    return ServiceSearchMatcher.normalize(value);
  }

  Map<String, List<String>> _searchTermsByCategory(
    Map<String, String> keywordMap,
  ) {
    final terms = <String, List<String>>{
      for (final category in _allCategories) category.name: [category.name],
    };
    for (final service in _serviceCatalog) {
      terms
          .putIfAbsent(service.category, () => [service.category])
          .add(service.name);
    }
    for (final entry in keywordMap.entries) {
      terms.putIfAbsent(entry.value, () => [entry.value]).add(entry.key);
    }
    terms['HVAC']!.addAll(const [
      'hvac repair',
      'heating ventilation air conditioning',
      'air conditioner',
    ]);
    return terms;
  }

  String? _exactServiceCategory(String query) {
    const serviceAliases = <String, String>{
      'ac repair': 'HVAC',
      'ac tune up': 'HVAC',
      'air conditioning repair': 'HVAC',
      'furnace repair': 'HVAC',
      'heating repair': 'HVAC',
      'smart thermostat install': 'HVAC',
      'drain cleaning': 'Plumbing',
      'leak repair': 'Plumbing',
      'toilet repair': 'Plumbing',
      'water heater repair': 'Plumbing',
      'water heater replacement': 'Plumbing',
      'ceiling fan install': 'Electrical',
      'outlet install': 'Electrical',
      'breaker repair': 'Electrical',
      'interior painting': 'Painting',
      'fence repair': 'Fencing & Decks',
      'lawn maintenance': 'Landscaping',
      'pool cleaning': 'Pool & Spa',
      'pool service': 'Pool & Spa',
      'garage door repair': 'Garage Doors',
      'window repair': 'Windows & Doors',
      'door repair': 'Windows & Doors',
      'appliance repair': 'Appliance Repair',
      'handyman': 'Handyman',
      'plumbing': 'Plumbing',
      'electrical': 'Electrical',
      'cleaning': 'Cleaning',
      'roofing': 'Roofing',
      'pool spa': 'Pool & Spa',
      'tree service': 'Tree Service',
      'pest control': 'Pest Control',
      'flooring': 'Flooring',
      'drywall plaster': 'Drywall & Plaster',
      'windows doors': 'Windows & Doors',
      'garage doors': 'Garage Doors',
    };
    return serviceAliases[query];
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

  List<_BrowseService> get _serviceCatalog => ServiceCatalog.items
      .map((service) => _BrowseService(service.name, service.category))
      .toList(growable: false);

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
      'media': const [],
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
        body =
            (visiblePros.isEmpty && !_isLoadingResults && _resultsError == null)
                ? _buildNoCoverage()
                : _buildBrowseDefault(visiblePros);
        break;
    }

    return body;
  }

  Widget _buildBrowseDefault(List<_BrowsePro> visiblePros) {
    final sortedPros = _sortedBrowsePros(visiblePros);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        _buildSearchInputPill(),
        const SizedBox(height: 8),
        _buildCompactLocationChip(),
        const SizedBox(height: 12),
        _buildRail(_allCategories),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${visiblePros.length} Select-certified pros',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            PopupMenuButton<_BrowseSort>(
              tooltip: 'Sort contractors',
              initialValue: _browseSort,
              onSelected: (sort) => setState(() => _browseSort = sort),
              itemBuilder: (context) => _BrowseSort.values
                  .map(
                    (sort) => PopupMenuItem<_BrowseSort>(
                      value: sort,
                      child: Text(sort.label),
                    ),
                  )
                  .toList(),
              child: Row(
                children: [
                  Text(
                    _browseSort.label,
                    style: const TextStyle(
                      color: AppTheme.teal500,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.teal500,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
          _buildInlineState(
              'No live contractors were returned for $_selectedZip.')
        else
          ...sortedPros.map((pro) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBrowseCard(pro),
              )),
      ],
    );
  }

  Widget _buildCompactLocationChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () async {
          final nextZip = await showServiceZipEntryDialog(
            context,
            initialZip: _selectedZip,
          );
          if (nextZip != null) await _applyLocationInput(nextZip);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5FD),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                color: AppTheme.teal500,
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                _locationChipLabel,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.teal500,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllCategories() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All services',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_serviceCatalog.length} services',
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Choose a service to see available pros near you.',
          style: TextStyle(color: AppTheme.gray, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ..._serviceCatalog.map(
          (service) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AllServiceListRow(
              service: service,
              onTap: () {
                _searchController.text = service.name;
                _searchController.selection = TextSelection.collapsed(
                  offset: service.name.length,
                );
                unawaited(_submitSearch(service.name));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchFocused() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        _buildSearchInputPill(),
        const SizedBox(height: 8),
        _buildCompactLocationChip(),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Browse all ${_allCategories.length} categories',
                  style: const TextStyle(
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
    );
  }

  Widget _buildResults(List<_BrowsePro> matches) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        _buildSearchInputPill(),
        const SizedBox(height: 12),
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
                child: _buildBrowseCard(pro),
              )),
      ],
    );
  }

  Widget _buildNoCoverage() {
    final subtitle = _selectedCategory == 'All' ||
            _selectedCategory.trim().isEmpty
        ? 'TradeWorks is zip-gated to guarantee response times and quality. We have not expanded into cleaning to Cape Coral $_selectedZip yet.'
        : 'TradeWorks is zip-gated to guarantee response times and quality. We have not expanded ${_selectedCategory.toLowerCase()} service in $_selectedZip yet.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 30, 10, 28),
      children: [
        _buildSearchInputPill(),
        const SizedBox(height: 8),
        _buildCompactLocationChip(),
        const SizedBox(height: 12),
        // Keep the same service rail available in the no-results state so a
        // homeowner can switch categories without backing out of their search.
        _buildRail(_railCategoriesForCurrentSelection),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 36,
                  color: AppTheme.navy700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No vetted pros for this yet in\n$_selectedZip',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    await _returnToBrowsePage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Browse other categories',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    final typed = _searchController.text.trim();

    void focusSearchField() {
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      if (_view != _BrowseView.searchFocused &&
          _view != _BrowseView.typeAhead) {
        setState(() {
          _view =
              typed.isEmpty ? _BrowseView.searchFocused : _BrowseView.typeAhead;
        });
      }
    }

    return ServiceSearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hint: 'Search a service or pro',
      borderColor: _searchFocusNode.hasFocus
          ? AppTheme.orange500
          : const Color(0xFFD9E2EC),
      onTap: focusSearchField,
      // Keep the focused suggestions mounted long enough for their rows to
      // receive the gesture. Unfocusing on pointer-down replaces this view
      // before Recent and Popular rows can receive pointer-up.
      onTapOutside: (_) {
        if (_view != _BrowseView.searchFocused &&
            _view != _BrowseView.typeAhead) {
          _searchFocusNode.unfocus();
        }
      },
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
      onSubmit: () => _submitSearch(),
      onPhotoTap: () => _openAiLayer('camera'),
      onVoiceTap: () => _openAiLayer('voice'),
    );
  }

  List<_BrowsePro> _sortedBrowsePros(List<_BrowsePro> pros) {
    final sorted = [...pros];
    switch (_browseSort) {
      case _BrowseSort.highestRated:
        sorted.sort((a, b) {
          final rating = b.rating.compareTo(a.rating);
          if (rating != 0) return rating;
          final reviews = b.reviews.compareTo(a.reviews);
          if (reviews != 0) return reviews;
          return a.distanceMiles.compareTo(b.distanceMiles);
        });
      case _BrowseSort.nearest:
        sorted.sort((a, b) {
          final distance = a.distanceMiles.compareTo(b.distanceMiles);
          if (distance != 0) return distance;
          return b.rating.compareTo(a.rating);
        });
      case _BrowseSort.lowestPrice:
        sorted.sort((a, b) {
          final price = a.price.compareTo(b.price);
          if (price != 0) return price;
          return b.rating.compareTo(a.rating);
        });
    }
    return sorted;
  }

  Widget _buildLocationPill() {
    return GestureDetector(
      onTap: () async {
        final nextZip = await showServiceZipEntryDialog(
          context,
          initialZip: _selectedZip,
        );
        if (nextZip != null) await _applyLocationInput(nextZip);
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
            const Icon(Icons.location_on, color: AppTheme.gray, size: 20),
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
    Color homeBackgroundFor(String name) {
      if (name == 'All') {
        return AppTheme.orangeTint;
      }
      return _homeCategoryBackgrounds[name] ??
          TradeWorksCategoryTokens.forName(name).tint;
    }

    final chips = <Widget>[
      _RailChip(
        label: 'All',
        meta: _isLoadingCoverage ? '...' : '${_allProsCount} pros',
        category: 'All',
        fallbackIcon: Icons.grid_view_rounded,
        accent: AppTheme.orange500,
        tint: homeBackgroundFor('All'),
        selected: _selectedCategory == 'All',
        enabled: !_isLoadingCoverage && _allProsCount > 0,
        onTap: _runAllServicesSearch,
      ),
      ...categories.map(
        (category) {
          final token = TradeWorksCategoryTokens.forName(category.name);
          return _RailChip(
            label: category.name,
            meta: _isLoadingCoverage
                ? '...'
                : '${_proCountForCategory(category)} pros',
            category: category.name,
            fallbackIcon: token.icon,
            accent: token.color,
            tint: homeBackgroundFor(category.name),
            selected: _selectedCategory == category.name,
            enabled: !_isLoadingCoverage && _proCountForCategory(category) > 0,
            onTap: () => _selectCategory(category.name),
          );
        },
      ),
    ];

    return SizedBox(
      height: 80,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView.separated(
          controller: _railController,
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) => chips[index],
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: chips.length,
        ),
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
                      style:
                          const TextStyle(color: AppTheme.gray, fontSize: 12),
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
    final nextAvailable = _nextAvailableLabelFor(pro);
    return InkWell(
      onTap: () => _openProProfile(pro),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E8EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrowseProfileImage(pro),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pro.name,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pro.category} · ${pro.distanceMiles.toStringAsFixed(1)} mi · ${pro.completedWorkOrders} orders',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'From \$${pro.price}',
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pro.priceLabel,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppTheme.orange500,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pro.reviews} reviews (${pro.rating.toStringAsFixed(1)})',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    nextAvailable,
                    style: const TextStyle(
                      color: Color(0xFF15A86B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE6E8EC),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    pro.footerText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View profile',
                    style: TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseProfileImage(_BrowsePro pro) {
    final borderRadius = BorderRadius.circular(8);
    final imageUrl = _safeNetworkImageUrl(pro.photoUrl);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _avatarColorForCategory(pro.category),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _buildBrowseProfileFallback(pro);
                },
                errorBuilder: (_, __, ___) => _buildBrowseProfileFallback(pro),
              )
            : _buildBrowseProfileFallback(pro),
      ),
    );
  }

  Widget _buildBrowseProfileFallback(_BrowsePro pro) {
    return Center(
      child: Text(
        pro.initials,
        style: TextStyle(
          color: _avatarTextColorForCategory(pro.category),
          fontWeight: FontWeight.w700,
          fontSize: 12,
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
                    style:
                        const TextStyle(color: AppTheme.gray, fontSize: 11.5),
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
    final directMatches = _serviceCatalog
        .where((service) =>
            service.name.toLowerCase().contains(query) ||
            service.category.toLowerCase().contains(query))
        .toList();
    if (directMatches.isNotEmpty) return directMatches;

    final category = _resolveSearchCategory(query);
    return category == null
        ? const []
        : _serviceCatalog
            .where((service) => service.category == category)
            .toList();
  }

  List<_BrowseCategory> _categoryMatches() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allCategories.where((c) => c.covered).toList();
    final directMatches = _allCategories
        .where((category) =>
            category.covered && category.name.toLowerCase().contains(query))
        .toList();
    if (directMatches.isNotEmpty) return directMatches;

    final category = _resolveSearchCategory(query);
    return category == null
        ? const []
        : _allCategories.where((item) => item.name == category).toList();
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

  String? _safeNetworkImageUrl(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (!url.startsWith('http')) return null;
    if (url.contains('/storage/v1/object/sign/')) return null;
    return url;
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

    String? safeNetworkImageUrl(String rawUrl) {
      final url = rawUrl.trim();
      if (!url.startsWith('http')) return null;
      if (url.contains('/storage/v1/object/sign/')) return null;
      return url;
    }

    final businessName = read(
      map['businessName'],
      read(
        map['business_name'],
        read(
          map['name'],
          read(
            map['companyName'],
            read(
              map['displayName'],
              read(map['contractorName'], read(map['providerName'])),
            ),
          ),
        ),
      ),
    );
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
      read(map['specialty'], read(map['category'], category)),
    );
    final priceLabel =
        titleCase(read(map['fromUnit'], read(map['priceLabel'])));
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
      photoUrl: () {
        final direct = read(
          map['photoUrl'],
          read(
            map['profile_image_url'],
            read(
              map['profileImageUrl'],
              read(map['avatarUrl'], read(map['logoUrl'])),
            ),
          ),
        );
        return safeNetworkImageUrl(direct);
      }(),
      initials: initials.isEmpty ? 'SP' : initials,
      category: category,
      trade: trade,
      ratingLabel: ratingLabel,
      rating: rating,
      reviews: reviews,
      distanceMiles: distance,
      completedWorkOrders: completedWorkOrders,
      nextAvailable: nextAvailableRaw,
      price: price,
      priceLabel: priceLabel,
      summary: read(
        map['tagline'],
        read(
          map['summary'],
          read(
            map['overview'],
            read(
              map['about'],
              read(
                map['description'],
                read(map['headline'], read(map['bio'])),
              ),
            ),
          ),
        ),
      ),
      selectedCertified: selectedCertified,
      services: const [],
      mediaCount: 0,
      responseTime: read(map['responseTime'], read(map['response_time'])),
    );
  }

  String get slug =>
      apiSlug.isNotEmpty ? apiSlug : name.toLowerCase().replaceAll(' ', '-');

  String get footerText {
    final summaryText = summary.trim();
    if (summaryText.isNotEmpty) return summaryText;
    if (selectedCertified) return 'Select-certified pro';

    final tradeText = trade.trim();
    final categoryText = category.trim();
    if (tradeText.isNotEmpty && tradeText != categoryText) return tradeText;
    if (categoryText.isNotEmpty) return '$categoryText pro';
    return 'View contractor details';
  }
}

class _RailChip extends StatelessWidget {
  final String label;
  final String meta;
  final String category;
  final IconData fallbackIcon;
  final Color accent;
  final Color tint;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RailChip({
    required this.label,
    required this.meta,
    required this.category,
    required this.fallbackIcon,
    required this.accent,
    required this.tint,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    final foreground = active
        ? Colors.white
        : enabled
            ? AppTheme.navy700
            : AppTheme.gray;
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '$label, $meta${enabled ? '' : ', unavailable'}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? accent
                : enabled
                    ? tint
                    : AppTheme.pageAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : enabled
                      ? accent.withOpacity(0.25)
                      : AppTheme.line,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withOpacity(active ? 0.26 : 0.16),
                      blurRadius: active ? 14 : 10,
                      spreadRadius: active ? 1 : 0,
                      offset: Offset(0, active ? 6 : 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ServiceCategoryIcon(
                category: category,
                size: 28,
                fallbackIcon: fallbackIcon,
                fallbackColor: active
                    ? Colors.white
                    : enabled
                        ? accent
                        : AppTheme.gray,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                style: TextStyle(
                  color:
                      active ? Colors.white.withOpacity(0.82) : AppTheme.gray,
                  fontSize: 9.5,
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

class _AllServiceListRow extends StatelessWidget {
  final _BrowseService service;
  final VoidCallback onTap;

  const _AllServiceListRow({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final token = TradeWorksCategoryTokens.forName(service.category);
    return Semantics(
      button: true,
      label: 'Browse ${service.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: token.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ServiceCategoryIcon(
                  category: service.category,
                  size: 24,
                  fallbackIcon: token.icon,
                  fallbackColor: token.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.category,
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.gray,
              ),
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
                child: ServiceCategoryIcon(
                  category: category.name,
                  size: 26,
                  fallbackIcon: category.icon,
                  fallbackColor: category.color,
                ),
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

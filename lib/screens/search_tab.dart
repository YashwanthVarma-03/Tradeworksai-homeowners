import '../utils/lazy_results.dart';
import '../widgets/loading_skeleton.dart';
import '../utils/session_pro_order.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/homeowner_service.dart';
import '../services/auth_service.dart';
import '../services/intake_service.dart';
import '../services/browse_search_history.dart';
import '../services/service_catalog.dart';
import '../services/service_location.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../utils/app_error_utils.dart';
import '../utils/service_search_matcher.dart';
import '../utils/display_format.dart';
import '../widgets/ai_intake_sheet.dart';
import '../widgets/app_notification.dart';
import '../widgets/capsules.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/service_zip_entry_dialog.dart';
import '../widgets/service_search_bar.dart';
import '../ui/tw.dart';
import 'compare_pros.dart';
import 'chat_screen.dart';
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
  static const double _railTileWidth = 96;
  static const double _railTileGap = 8;

  static const Map<String, Color> _homeCategoryBackgrounds = {
    'HVAC': AppTheme.blueTint,
    'Plumbing': AppTheme.blueTint,
    'Electrical': AppTheme.amberTint,
    'Cleaning': AppTheme.greenTint,
    'Roofing': AppTheme.categoryRoofing,
    'Lawn': AppTheme.greenTint,
    'Landscaping': AppTheme.greenTint,
    'Handyman': AppTheme.categoryHandyman,
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
  final List<String> _compareIds = [];

  _BrowseView _view = _BrowseView.searchFocused;
  String? _bookingDescription;
  String? _descriptionCategory;
  String _selectedCategory = 'All';
  String _selectedZip = '';
  String? _committedQuery;
  bool _isInitializing = true;
  bool _isLoadingResults = false;
  bool _isLoadingCoverage = false;
  bool _suppressLocationReset = false;
  String? _resultsError;
  int _availabilityHydrationToken = 0;
  int _prosRequestToken = 0;
  LazyResults<_BrowsePro>? _proPages;
  bool _isLoadingMore = false;
  String? _loadMoreError;
  bool _preserveSearchViewOnUnfocus = false;
  // No distance filter: the homeowner searched by ZIP and the platform never
  // measures distance (decisions §11, Oct 1).
  double? _minRatingFilter;
  String? _priceTypeFilter;

  bool get _hasActiveFilters =>
      _minRatingFilter != null || _priceTypeFilter != null;

  int get _activeFilterCount => [
        _minRatingFilter,
        _priceTypeFilter,
      ].where((value) => value != null).length;

  List<_BrowsePro> get _filteredLivePros {
    if (!_hasActiveFilters) return _livePros;
    return _livePros.where((pro) {
      final minRating = _minRatingFilter;
      if (minRating != null && pro.rating < minRating) return false;
      final priceType = _priceTypeFilter;
      if (priceType != null && pro.workOrderType != priceType) return false;
      return true;
    }).toList(growable: false);
  }

  int get _availableProsCount {
    if (_hasActiveFilters) return _filteredLivePros.length;
    if (_selectedCategory == 'All') {
      return _allProsCount > 0 ? _allProsCount : _livePros.length;
    }
    return _categoryCounts[_selectedCategory] ?? _livePros.length;
  }

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
    if (AuthService.instance.isAuthenticated) {
      unawaited(ServiceLocation.clear());
    }
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
    try {
      await _loadSharedLocationOverride();
      await _loadLocationFromProfile();
      if (_selectedZip.isEmpty) {
        final hasPendingSearch = (_committedQuery != null &&
                _committedQuery!.isNotEmpty) ||
            (widget.initialCategory != null && widget.initialCategory != 'All');
        if (!hasPendingSearch || !await _requestZipIfNeeded()) return;
      }
      await _refreshZipCoverage();
      _locationController.text =
          _normalizeLocationText(_locationController.text);
      if (!mounted) return;

      if (_committedQuery != null && _committedQuery!.isNotEmpty) {
        await _runQuerySearch(_committedQuery!);
        return;
      }

      if (widget.initialCategory != null && widget.initialCategory != 'All') {
        await _runCategorySearch(widget.initialCategory!);
        return;
      }

      if (_selectedCategory == 'All') {
        return;
      }

      await _runCategorySearch(_selectedCategory);
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _loadLocationFromProfile({
    bool ignoreSharedOverride = false,
  }) async {
    final sharedZip = await _getSharedZipOverride();
    if (!ignoreSharedOverride && sharedZip != null) {
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
        (a) =>
            a is Map &&
            (a['isDefault'] == true ||
                a['isDefault'] == 'true' ||
                a['is_default'] == true ||
                a['is_default'] == 'true' ||
                a['isPrimary'] == true ||
                a['isPrimary'] == 'true' ||
                a['is_primary'] == true ||
                a['is_primary'] == 'true'),
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

  Future<bool> _requestZipIfNeeded() async {
    if (!mounted || _selectedZip.isNotEmpty) return true;

    final zip = await showServiceZipEntryDialog(
      context,
      initialZip: '',
    );
    if (zip == null || !mounted) {
      return false;
    }
    await _applyLocationInput(zip, refreshResults: false);
    return true;
  }

  void _handleSharedLocationChanged() {
    final location = ServiceLocation.selected.value;
    if (!mounted) {
      return;
    }
    if (location == null) {
      if (_suppressLocationReset) return;
      if (AuthService.instance.isAuthenticated) {
        unawaited(_restorePrimaryLocation());
      } else if (_selectedZip.isNotEmpty) {
        setState(() {
          _prosRequestToken++;
          _availabilityHydrationToken++;
          _proPages = null;
          _selectedZip = '';
          _applyLocationLabel('Enter ZIP code', '');
          _livePros.clear();
          _liveNextSlotLabels.clear();
          _categoryCounts.clear();
          _categoryCoverage.clear();
          _isLoadingResults = false;
          _isLoadingCoverage = false;
        });
      }
      return;
    }
    if (location.zip == _selectedZip) return;
    unawaited(_applyLocationInput(location.zip));
  }

  Future<void> _restorePrimaryLocation() async {
    if (!AuthService.instance.isAuthenticated) return;

    if (mounted) {
      setState(() {
        _prosRequestToken++;
        _availabilityHydrationToken++;
        _proPages = null;
        _selectedZip = '';
        _applyLocationLabel('Enter ZIP code', '');
        _livePros.clear();
        _liveNextSlotLabels.clear();
        _categoryCounts.clear();
        _categoryCoverage.clear();
        _resultsError = null;
      });
    }

    await _loadLocationFromProfile(ignoreSharedOverride: true);
    if (_selectedZip.isEmpty) return;
    await _refreshZipCoverage();
    if (!mounted) return;

    final query = _committedQuery?.trim();
    if (query != null && query.isNotEmpty) {
      await _runQuerySearch(query);
    } else if (_selectedCategory == 'All') {
      await _runAllServicesSearch();
    } else {
      await _runCategorySearch(_selectedCategory);
    }
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
    // A tile plus its separator is its complete horizontal footprint. This
    // keeps an active category aligned with the page's left content edge,
    // exactly like the initial All tile.
    final targetOffset = (selectedIndex * (_railTileWidth + _railTileGap))
        .clamp(
          0.0,
          _railController.position.maxScrollExtent,
        )
        .toDouble();
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
      if (!mounted || zip != _selectedZip) return;
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

      final currentLocation = _normalizeLocationText(_locationController.text)
          .split(String.fromCharCode(183))
          .first
          .trim();
      final city = _readText(coverage['city']) ??
          _readText(coverage['areaName']) ??
          _readText(coverage['area_name']) ??
          (currentLocation.isEmpty || currentLocation == 'Enter ZIP code'
              ? 'Home'
              : currentLocation);
      final state = _readText(coverage['state']);
      final resolvedLocation = [city, state]
          .where((part) => part != null && part.trim().isNotEmpty)
          .join(', ');
      final returnedZip = _readText(coverage['zip']) ?? zip;

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
      if (!mounted || zip != _selectedZip) {
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
    final city = parts.first.replaceFirst(RegExp(r'(?:,\s*[A-Z]{2})+$'), '');
    return '$city ${String.fromCharCode(183)} ${parts.last}';
  }

  void _handleFocusChange() {
    if (!mounted) return;
    if (!_searchFocusNode.hasFocus && _preserveSearchViewOnUnfocus) {
      _preserveSearchViewOnUnfocus = false;
      setState(() {});
      return;
    }
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

  void _dismissSearchKeyboard() {
    if (!_searchFocusNode.hasFocus) return;
    _preserveSearchViewOnUnfocus = true;
    _searchFocusNode.unfocus();
  }

  Future<void> _applyLocationInput(
    String raw, {
    bool refreshResults = true,
  }) async {
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
      _availabilityHydrationToken++;
      _proPages = null;
      _isLoadingMore = false;
      _loadMoreError = null;
    });
    await _saveSharedLocationOverride(nextZip, cityLabel);
    await _refreshZipCoverage();

    if (!mounted || nextZip != _selectedZip || !refreshResults) return;

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
      constraints: BoxConstraints(
        maxWidth: TwLayout.maxContent,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
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
    if (AuthService.instance.isAuthenticated) {
      _suppressLocationReset = true;
      await ServiceLocation.clear();
      _suppressLocationReset = false;
      await _restorePrimaryLocation();
      return;
    }
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
    _bookingDescription = null;
    _descriptionCategory = null;
    if (_selectedZip.isEmpty && !await _requestZipIfNeeded()) return;
    // Keep the catalogue visible while nearby-pro data refreshes. Previously,
    // the async completion replaced this route with the default Browse view.
    final keepAllServicesListVisible = _view == _BrowseView.allCategories;
    final categories = SessionProOrder.instance.arrange(
        _categoriesWithLivePros, (category) => 'category:${category.name}');
    final requestToken = ++_prosRequestToken;
    final requestedZip = _selectedZip;
    if (!mounted) return;
    setState(() {
      _selectedCategory = 'All';
      _committedQuery = null;
      _searchController.clear();
      _isLoadingResults = true;
      _resultsError = null;
      _view = keepAllServicesListVisible
          ? _BrowseView.allCategories
          : _BrowseView.browse;
    });
    _searchFocusNode.unfocus();

    _startProPages([
      for (final category in categories)
        if (_categorySlugForName(category.name) != null)
          () => _fetchProCategory(category.name,
              _categorySlugForName(category.name)!, requestedZip, requestToken),
    ]);
    await _loadProPage(requestToken,
        initial: true, keepCatalogue: keepAllServicesListVisible);
    if (_hasActiveFilters) await _loadAllProsForFilters();
    _queueSelectedRailVisibility();
  }

  _BrowseView _resolveSearchView(String query) {
    if (query.trim().isEmpty) {
      return _BrowseView.searchFocused;
    }
    return _livePros.isEmpty ? _BrowseView.noCoverage : _BrowseView.results;
  }

  Future<void> _runQuerySearch(String query) async {
    if (_selectedZip.isEmpty && !await _requestZipIfNeeded()) return;
    // A high-confidence local match is kept as a safety net for typo-only
    // requests. The AI intake can still enrich normal language queries.
    final localCategory = _resolveSearchCategory(query);
    if (localCategory != null) {
      await _runCategorySearch(localCategory, overrideQuery: query);
      return;
    }
    if (!mounted) return;
    final token = ++_prosRequestToken;
    _availabilityHydrationToken++;
    _proPages = null;
    _isLoadingMore = false;
    _loadMoreError = null;
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
      if (!mounted || token != _prosRequestToken) return;
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
      if (!mounted || token != _prosRequestToken) return;
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
    if (overrideQuery != null) {
      _bookingDescription = overrideQuery.trim();
      _descriptionCategory = category;
    } else if (category != _descriptionCategory) {
      _bookingDescription = null;
      _descriptionCategory = null;
    }
    if (_selectedZip.isEmpty && !await _requestZipIfNeeded()) return;
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

    _startProPages([
      () => _fetchProCategory(category, slug, requestedZip, requestToken,
          urgency: urgency),
    ]);
    await _loadProPage(requestToken, initial: true);
    if (_hasActiveFilters) await _loadAllProsForFilters();
  }

  Future<List<_BrowsePro>> _fetchProCategory(
      String category, String slug, String zip, int token,
      {String urgency = 'standard'}) async {
    if (!mounted || token != _prosRequestToken) return [];
    final response = await HomeownerService.instance
        .searchPros(zip: zip, categorySlug: slug, urgency: urgency);
    if (!mounted || token != _prosRequestToken) return [];
    final results = (response['results'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _BrowsePro.fromApi(Map<String, dynamic>.from(item),
            category: category))
        .toList();
    _categoryCounts[category] = response['count'] is num
        ? (response['count'] as num).toInt()
        : results.length;
    _categoryCoverage[category] =
        response['covered'] == true || results.isNotEmpty;
    return _shuffledBrowsePros(results);
  }

  void _startProPages(List<Future<List<_BrowsePro>> Function()> sources) {
    _availabilityHydrationToken++;
    _proPages = LazyResults(
        sources: sources,
        keyOf: (pro) => '${_proAvailabilityKey(pro)}|${pro.category}');
    _livePros.clear();
    _liveNextSlotLabels.clear();
    _isLoadingMore = false;
    _loadMoreError = null;
  }

  Future<void> _loadProPage(int token,
      {bool initial = false, bool keepCatalogue = false}) async {
    final pages = _proPages;
    if (pages == null || _isLoadingMore || token != _prosRequestToken) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final pros = await pages.nextPage();
      if (!mounted || token != _prosRequestToken || pages != _proPages) return;
      setState(() {
        _livePros.addAll(pros);
        _isLoadingResults = false;
        _isLoadingMore = false;
        if (initial && !keepCatalogue && _livePros.isEmpty) {
          _view = _BrowseView.noCoverage;
        }
      });
      unawaited(_hydrateNextAvailability(pros));
    } catch (e) {
      if (!mounted || token != _prosRequestToken || pages != _proPages) return;
      setState(() {
        _isLoadingResults = false;
        _isLoadingMore = false;
        _loadMoreError = AppErrorUtils.friendlyMessage(e,
            fallback: 'Unable to load more pros. Please try again.');
      });
    }
  }

  Widget _proList(
      {required List<Widget> header,
      required List<_BrowsePro> pros,
      required String emptyMessage}) {
    final hasMore = _proPages?.hasMore ?? false;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical &&
            notification.metrics.extentAfter < 400 &&
            hasMore &&
            !_isLoadingResults &&
            !_isLoadingMore &&
            _loadMoreError == null) {
          unawaited(_loadProPage(_prosRequestToken));
        }
        return false;
      },
      // Gutter by width class; on Wide the column is centred and capped at
      // 560 (SPEC §1.1). Slivers can't sit inside TwPage, so the same numbers
      // are applied as sliver padding.
      child: LayoutBuilder(builder: (context, constraints) {
        final side = math.max(TwLayout.gutter(context),
            (constraints.maxWidth - TwLayout.maxContent) / 2);
        return CustomScrollView(
          key: ValueKey('pros-$_prosRequestToken'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, TwSpace.s16, side, 0),
              sliver: SliverToBoxAdapter(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: header)),
            ),
            if (_isLoadingResults)
              const SliverToBoxAdapter(
                  child: LoadingSkeleton(
                layout: SkeletonLayout.results,
                label: 'Loading pros',
              ))
            else if (_resultsError != null)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverToBoxAdapter(
                    child: _buildInlineState(_resultsError!)),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                            key: ValueKey(
                                '${_proAvailabilityKey(pros[index])}|${pros[index].category}'),
                            padding: const EdgeInsets.only(bottom: TwSpace.s12),
                            child: _buildBrowseCard(pros[index])),
                        childCount: pros.length)),
              ),
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                    child: LoadingSkeleton(
                  layout: SkeletonLayout.results,
                  itemCount: 1,
                  label: 'Loading more pros',
                ))
              else if (_loadMoreError != null || hasMore)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: side, vertical: TwSpace.s16),
                        child: Column(children: [
                          if (_loadMoreError != null)
                            Text(
                              _loadMoreError!,
                              textAlign: TextAlign.center,
                              style: TwType.bodySm(),
                            ),
                          TextButton(
                              onPressed: () => _loadProPage(_prosRequestToken),
                              child: Text(_loadMoreError == null
                                  ? 'Load more pros'
                                  : 'Retry loading pros')),
                        ]))),
              if (pros.isEmpty && !hasMore && _loadMoreError == null)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: SliverToBoxAdapter(
                      child: _buildInlineState(emptyMessage)),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: TwSpace.s28)),
          ],
        );
      }),
    );
  }

  Future<void> _hydrateNextAvailability(List<_BrowsePro> pros) async {
    // Public search already returns `nextAvailable`. Avoid a second wave of
    // per-pro availability requests for guests; those endpoints are optional
    // enrichment and must never make public browsing noisy or fragile.
    if (!AuthService.instance.isAuthenticated) {
      return;
    }
    final token = _availabilityHydrationToken;
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

  /// "Tomorrow", "Wed, Oct 14"… or null when the pro has no open slot
  /// (B02: no capsule then — Batch 21 Amendment 1 R3).
  String? _nextAvailableLabelFor(_BrowsePro pro) {
    return _liveNextSlotLabels[_proAvailabilityKey(pro)] ??
        _formatLooseAvailabilityLabel(pro.nextAvailable);
  }

  String? _formatLooseAvailabilityLabel(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
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
          color: AppTheme.navy700,
          covered: false,
        ),
      ];

  List<_BrowseService> get _serviceCatalog => ServiceCatalog.items
      .map((service) => _BrowseService(service.name, service.category))
      .toList(growable: false);

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
      'workOrderType':
          pro.workOrderType.isEmpty ? 'rate_card' : pro.workOrderType,
      'fromPrice': pro.price,
      'selectedCertified': pro.selectedCertified,
      'category': pro.category,
      'trade': pro.trade,
      'distanceMiles': pro.distanceMiles,
      'completedWorkOrders': pro.completedWorkOrders,
      'nextAvailable': pro.nextAvailable,
      'selectedService': (_committedQuery?.trim().isNotEmpty ?? false)
          ? _committedQuery!.trim()
          : null,
      'requestZip': _selectedZip,
      'summary': pro.summary,
      'services': pro.services,
      'photoUrl': pro.photoUrl,
      'profile_image_url': pro.photoUrl,
      'media': const [],
    };
  }

  Future<void> _openProProfile(_BrowsePro pro) async {
    await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProProfileScreen(
            pro: _toProMap(pro), initialDescription: _bookingDescription),
      ),
    );
  }

  // The public profile contract resolves a profile by slug. Selection order is
  // still the homeowner's order; this is only the stable fetch key.
  String _compareId(_BrowsePro pro) => pro.slug;

  void _toggleCompare(_BrowsePro pro) {
    final id = _compareId(pro);
    setState(() {
      if (_compareIds.contains(id)) {
        _compareIds.remove(id);
      } else if (_compareIds.length < 3) {
        _compareIds.add(id);
      }
    });
  }

  Future<void> _openCompare() async {
    if (_compareIds.length < 2) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CompareProsScreen(
          contractorIds: List<String>.from(_compareIds),
          // The service the homeowner searched ("AC repair"), so Compare's
          // context line and Price row use it (Oct 1 G-48).
          serviceLabel: (_committedQuery?.trim().isNotEmpty ?? false)
              ? _committedQuery!.trim()
              : (_selectedCategory == 'All' ? null : _selectedCategory),
          zip: _selectedZip,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final profile = result['profile'];
    if (profile is! Map) return;
    final pro = Map<String, dynamic>.from(profile);
    switch (result['action']) {
      case 'book':
        widget.onBookPro(pro);
      case 'message':
        await _openCompareMessage(pro);
      case 'profile':
        await Navigator.push<Object?>(
            context,
            MaterialPageRoute(
                builder: (_) => ProProfileScreen(pro: {
                      ...pro,
                      'requestZip': _selectedZip,
                      if ((_committedQuery?.trim().isNotEmpty ?? false))
                        'selectedService': _committedQuery!.trim()
                    }, initialDescription: _bookingDescription)));
    }
  }

  Future<void> _openCompareMessage(Map<String, dynamic> pro) async {
    if (!AuthService.instance.isAuthenticated) {
      AppNotification.showInfo(
          context, 'Please sign in to message this contractor.');
      return;
    }
    final recipientId = StreamService.instance.resolveMessagingUserId(pro);
    if (recipientId == null) {
      AppNotification.showInfo(
          context, 'Chat is not available for this contractor yet.');
      return;
    }
    final name = (pro['business_name'] ?? pro['businessName'] ?? 'Contractor')
        .toString()
        .trim();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contractorId: recipientId,
          contractorName: name.isEmpty ? 'Contractor' : name,
        ),
      ),
    );
  }

  Widget _compareTray() {
    if (_compareIds.isEmpty) return const SizedBox.shrink();
    final ready = _compareIds.length >= 2;
    return Container(
      margin: const EdgeInsets.only(bottom: TwSpace.s12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
            child: Text(
                '${_compareIds.length} of 3 selected${ready ? '' : ' · Add at least two pros to compare'}',
                style: TwType.title())),
        const SizedBox(width: TwSpace.s12),
        // Theme ElevatedButton: orange fill, navy label, 52 high, radius 12.
        ElevatedButton(
          onPressed: ready ? _openCompare : null,
          child: const Text('Compare'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const SkeletonPage(
        layout: SkeletonLayout.browse,
        label: 'Loading nearby services',
      );
    }

    if (_selectedZip.isEmpty) {
      return _buildZipRequired();
    }

    final visiblePros = _filteredLivePros;
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
        body = _buildResults(visiblePros);
        break;
      case _BrowseView.noCoverage:
        body = _buildNoCoverage();
        break;
      case _BrowseView.browse:
      default:
        body = (!_hasActiveFilters &&
                visiblePros.isEmpty &&
                !_isLoadingResults &&
                _resultsError == null &&
                _loadMoreError == null &&
                !(_proPages?.hasMore ?? false))
            ? _buildNoCoverage()
            : _buildBrowseDefault(visiblePros);
        break;
    }

    return body;
  }

  Widget _buildZipRequired() {
    return SingleChildScrollView(
      child: TwPage(
        top: TwSpace.s16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchInputPill(),
            const SizedBox(height: TwSpace.s8),
            _buildCompactLocationChip(),
            const SizedBox(height: TwSpace.s40),
            // The one page-level action, so it stays the orange primary —
            // now with the navy label (no white on orange).
            TwEmptyState(
              icon: Icons.location_on_outlined,
              title: 'Enter your ZIP code',
              message:
                  'We use it to show services and trusted pros available near you.',
              action: TwPrimaryButton(
                label: 'Enter ZIP code',
                expand: false,
                onPressed: () async {
                  final zip = await showServiceZipEntryDialog(
                    context,
                    initialZip: '',
                  );
                  if (zip != null) await _applyLocationInput(zip);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseDefault(List<_BrowsePro> visiblePros) {
    return _proList(
      pros: visiblePros,
      emptyMessage: 'No live contractors were returned for $_selectedZip.',
      header: [
        _buildSearchInputPill(),
        const SizedBox(height: 8),
        _buildCompactLocationChip(),
        const SizedBox(height: 12),
        _buildRail(_allCategories),
        const SizedBox(height: 16),
        ..._resultsHeader(_availableProsCount),
        _buildFilterBar(),
        const SizedBox(height: 12),
        _compareTray(),
      ],
    );
  }

  Widget _buildCompactLocationChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppTheme.white,
        shape: const StadiumBorder(side: BorderSide(color: AppTheme.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final nextZip = await showServiceZipEntryDialog(
              context,
              initialZip: _selectedZip,
            );
            if (nextZip != null) await _applyLocationInput(nextZip);
          },
          child: Padding(
            // 12 + 20 (label line) + 12 = 44 tap height (SPEC §1.3).
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.navy,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _locationChipLabel,
                    style: TwType.label(),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.navy,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllCategories() {
    return SingleChildScrollView(
      child: TwPage(
        top: TwSpace.s16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text('All services', style: TwType.h2()),
                ),
                const SizedBox(width: TwSpace.s12),
                Text(
                  '${_serviceCatalog.length} services',
                  style: TwType.caption(),
                ),
              ],
            ),
            const SizedBox(height: TwSpace.s8),
            Text(
              'Choose a service to see available pros near you.',
              style: TwType.bodySm(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: TwSpace.s16),
            ..._serviceCatalog.map(
              (service) => Padding(
                padding: const EdgeInsets.only(bottom: TwSpace.s8),
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
        ),
      ),
    );
  }

  Widget _buildSearchFocused() {
    return SingleChildScrollView(
      child: TwPage(
        top: TwSpace.s16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchInputPill(),
            const SizedBox(height: TwSpace.s8),
            _buildCompactLocationChip(),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: TwSpace.s28),
              _buildSectionHeader('Recent searches'),
              const SizedBox(height: TwSpace.s8),
              ..._recentSearches.take(3).map((term) => _buildListChipRow(
                    title: term,
                    trailing: '',
                    // A plain clock (B01), not the clock-with-arrow.
                    leading: Icons.schedule_outlined,
                    showChevron: true,
                    onTap: () {
                      _searchController.text = term;
                      _searchController.selection = TextSelection.collapsed(
                        offset: term.length,
                      );
                      _submitSearch(term);
                    },
                  )),
            ],
            const SizedBox(height: TwSpace.s28),
            _buildSectionHeader('Popular services'),
            const SizedBox(height: TwSpace.s8),
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
            const SizedBox(height: TwSpace.s20),
            TwCard(
              onTap: _openAllCategories,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const TwIconWell(Icons.grid_view_outlined, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Browse all ${_allCategories.length} categories',
                      style: TwType.title(),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeAhead(List<_BrowsePro> matches) {
    return SingleChildScrollView(
      child: TwPage(
        top: TwSpace.s16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchInputPill(),
            const SizedBox(height: TwSpace.s20),
            _buildSectionHeader('Services'),
            const SizedBox(height: TwSpace.s8),
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
            const SizedBox(height: TwSpace.s28),
            _buildSectionHeader('Categories'),
            const SizedBox(height: TwSpace.s8),
            ..._categoryMatches().take(4).map(
                  (category) => _buildListChipRow(
                    title: category.name,
                    trailing: '${category.serviceCount} services',
                    onTap: () => _selectCategory(category.name),
                  ),
                ),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: TwSpace.s28),
              _buildSectionHeader('Pros near you'),
              const SizedBox(height: TwSpace.s12),
              ...matches.take(3).map(_buildMiniProRow),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<_BrowsePro> matches) {
    return _proList(
      pros: matches,
      emptyMessage: 'No live contractors matched this search.',
      header: [
        _buildSearchInputPill(),
        const SizedBox(height: TwSpace.s20),
        if (!_isLoadingResults &&
            _resultsError == null &&
            (_livePros.isNotEmpty || _hasActiveFilters)) ...[
          ..._resultsHeader(_availableProsCount),
          _buildFilterBar(),
          const SizedBox(height: TwSpace.s12),
          _compareTray(),
        ],
      ],
    );
  }

  List<Widget> _resultsHeader(int count) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'pro' : 'pros'}',
              style: TwType.h2(),
            ),
          ),
          const SizedBox(width: TwSpace.s12),
          Text(
            'ZIP $_selectedZip',
            style: TwType.caption(),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Pros appear in a random order. TradeWorks does not rank them.',
        style: TwType.caption(),
      ),
      const SizedBox(height: TwSpace.s12),
    ];
  }

  Widget _buildFilterBar() {
    final filterCount = _activeFilterCount;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _showFiltersBottomSheet,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(filterCount == 0 ? 'Filters' : 'Filters ($filterCount)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: filterCount == 0 ? AppTheme.navy : AppTheme.blue,
            backgroundColor:
                filterCount == 0 ? Colors.white : AppTheme.blueTint,
            side: BorderSide(
              color: filterCount == 0 ? AppTheme.border : AppTheme.blue,
              width: filterCount == 0 ? 1 : 1.5,
            ),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
        if (filterCount > 0) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() {
              _minRatingFilter = null;
              _priceTypeFilter = null;
            }),
            child: const Text('Clear'),
          ),
        ],
        const Spacer(),
        if (_isLoadingMore && filterCount > 0)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Future<void> _showFiltersBottomSheet() async {
    final selected = await TwSheet.show<Map<String, dynamic>>(
      context,
      builder: (sheetContext) {
        double? rating = _minRatingFilter;
        String? priceType = _priceTypeFilter;
        final gutter = TwLayout.gutter(sheetContext);

        return StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Content scrolls; the action bar stays pinned (SPEC §1.5).
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, TwSpace.s16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Filter pros', style: TwType.h3()),
                          ),
                          TextButton(
                            onPressed: () => setSheetState(() {
                              rating = null;
                              priceType = null;
                            }),
                            child: const Text('Reset all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: TwSpace.s16),
                      _filterSection(
                        title: 'Minimum rating',
                        children: [
                          _filterChoice(
                            label: 'All ratings',
                            selected: rating == null,
                            onSelected: () =>
                                setSheetState(() => rating = null),
                          ),
                          for (final minimum in const [4.5, 4.8])
                            _filterChoice(
                              label: '$minimum+ stars',
                              selected: rating == minimum,
                              onSelected: () =>
                                  setSheetState(() => rating = minimum),
                            ),
                        ],
                      ),
                      const SizedBox(height: TwSpace.s28),
                      _filterSection(
                        title: 'Pricing type',
                        children: [
                          _filterChoice(
                            label: 'All pricing',
                            selected: priceType == null,
                            onSelected: () =>
                                setSheetState(() => priceType = null),
                          ),
                          // Labels use the settled type names; the filter
                          // values are unchanged.
                          _filterChoice(
                            label: 'Upfront price',
                            selected: priceType == 'rate_card',
                            onSelected: () =>
                                setSheetState(() => priceType = 'rate_card'),
                          ),
                          _filterChoice(
                            label: 'You approve the cap',
                            selected: priceType == 'nte',
                            onSelected: () =>
                                setSheetState(() => priceType = 'nte'),
                          ),
                          _filterChoice(
                            label: 'Free visit',
                            selected: priceType == 'quote_request',
                            onSelected: () => setSheetState(
                                () => priceType = 'quote_request'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TwStickyBar(
                children: [
                  TwPrimaryButton(
                    label: 'Apply filters',
                    onPressed: () => Navigator.pop(sheetContext, {
                      'rating': rating,
                      'priceType': priceType,
                    }),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _minRatingFilter = selected['rating'] as double?;
      _priceTypeFilter = selected['priceType'] as String?;
    });
    if (_hasActiveFilters) await _loadAllProsForFilters();
  }

  Widget _filterSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TwType.title()),
        const SizedBox(height: TwSpace.s12),
        Wrap(spacing: TwSpace.s8, runSpacing: TwSpace.s8, children: children),
      ],
    );
  }

  Widget _filterChoice({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return TwPill(
      label: label,
      selected: selected,
      onTap: onSelected,
    );
  }

  Future<void> _loadAllProsForFilters() async {
    final pages = _proPages;
    if (pages == null) return;
    while (mounted && identical(pages, _proPages) && pages.hasMore) {
      if (_isLoadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        continue;
      }
      await _loadProPage(_prosRequestToken);
      if (_loadMoreError != null) break;
    }
  }

  Widget _buildNoCoverage() {
    final subtitle = _selectedCategory == 'All' ||
            _selectedCategory.trim().isEmpty
        ? 'No pros currently list coverage for $_selectedZip.'
        : 'No pros currently list ${_selectedCategory.toLowerCase()} coverage for $_selectedZip.';

    return SingleChildScrollView(
      child: TwPage(
        top: TwSpace.s16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchInputPill(),
            const SizedBox(height: TwSpace.s8),
            _buildCompactLocationChip(),
            const SizedBox(height: TwSpace.s12),
            // Keep the same service rail available in the no-results state so
            // a homeowner can switch categories without backing out of their
            // search.
            _buildRail(_railCategoriesForCurrentSelection),
            const SizedBox(height: TwSpace.s40),
            TwEmptyState(
              icon: Icons.location_on_outlined,
              title: 'No vetted pros for this yet in $_selectedZip',
              message: subtitle,
              action: TwSecondaryButton(
                label: 'Browse other categories',
                expand: false,
                onPressed: () async {
                  await _returnToBrowsePage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInputPill() {
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
      borderColor: AppTheme.border,
      onTap: focusSearchField,
      // Keep suggestions mounted while dismissing the keyboard so the same
      // pointer gesture can still activate a Recent, Popular, or type-ahead
      // row on pointer-up.
      onTapOutside: (_) => _dismissSearchKeyboard(),
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

  List<_BrowsePro> _shuffledBrowsePros(List<_BrowsePro> pros) =>
      SessionProOrder.instance.arrange(
          pros,
          (pro) => pro.contractorId.isNotEmpty
              ? pro.contractorId
              : pro.apiSlug.isNotEmpty
                  ? pro.apiSlug
                  : pro.name);

  Widget _buildRail(List<_BrowseCategory> categories) {
    Color homeBackgroundFor(String name) {
      if (name == 'All') {
        return AppTheme.navyTint;
      }
      return _homeCategoryBackgrounds[name] ??
          TradeWorksCategoryTokens.forName(name).tint;
    }

    final chips = <Widget>[
      _RailChip(
        label: 'All',
        meta: _isLoadingCoverage ? '...' : '$_allProsCount pros',
        category: 'All',
        fallbackIcon: Icons.grid_view_rounded,
        accent: AppTheme.navy700,
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
      // Padding 16 + icon 28 + gap 4 (+2 spare) fixed; two caption lines
      // (13/18) grow with the text scale.
      height: 50 + MediaQuery.textScalerOf(context).scale(36),
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
          separatorBuilder: (_, __) => const SizedBox(width: _railTileGap),
          itemCount: chips.length,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return TwSectionHeader(title);
  }

  Widget _buildListChipRow({
    required String title,
    required String trailing,
    required VoidCallback onTap,
    IconData? leading,
    bool showChevron = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.only(top: 13, bottom: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, color: AppTheme.textSecondary, size: 18),
              const SizedBox(width: TwSpace.s12),
            ],
            Expanded(
              child: Text(
                title,
                style: TwType.body(color: AppTheme.navy),
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: TwSpace.s12),
              Text(trailing, style: TwType.meta()),
            ],
            if (showChevron) ...[
              const SizedBox(width: TwSpace.s12),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TwSpace.s16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TwType.bodySm(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildMiniProRow(_BrowsePro pro) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpace.s8),
      child: TwCard(
        onTap: () => _openProProfile(pro),
        padding: const EdgeInsets.all(TwSpace.s12),
        child: Row(
          children: [
            TwAvatar(
              name: pro.name,
              imageUrl: _safeNetworkImageUrl(pro.photoUrl),
              size: 40,
            ),
            const SizedBox(width: TwSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pro.name, style: TwType.title()),
                  const SizedBox(height: 2),
                  Text(pro.category, style: TwType.meta()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseCard(_BrowsePro pro) {
    // B02 shows no availability capsule for a pro with no open slot.
    final slot = _nextAvailableLabelFor(pro);
    final selected = _compareIds.contains(_compareId(pro));
    final canToggle = selected || _compareIds.length < 3;
    // Compact or large text: the price moves under the name instead of
    // squeezing the name into a narrow column (SPEC §1.2).
    final stackPrice = TwLayout.stackRows(context);
    final price = Column(
      crossAxisAlignment:
          stackPrice ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          pro.priceHeadline,
          textAlign: stackPrice ? TextAlign.start : TextAlign.end,
          style: TwType.price(),
        ),
        const SizedBox(height: 2),
        Text(
          pro.priceNote,
          textAlign: stackPrice ? TextAlign.start : TextAlign.end,
          style: TwType.caption(),
        ),
      ],
    );
    return TwCard(
      onTap: () => _openProProfile(pro),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TwAvatar(
                name: pro.name,
                imageUrl: _safeNetworkImageUrl(pro.photoUrl),
                size: 48,
              ),
              const SizedBox(width: TwSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pro.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwType.h3(),
                    ),
                    const SizedBox(height: TwSpace.s4),
                    Text(
                      '${pro.category} · ${pro.completedWorkOrders} jobs completed',
                      style: TwType.meta(),
                    ),
                    if (stackPrice) ...[
                      const SizedBox(height: TwSpace.s8),
                      price,
                    ],
                  ],
                ),
              ),
              if (!stackPrice) ...[
                const SizedBox(width: TwSpace.s12),
                SizedBox(width: 112, child: price),
              ],
            ],
          ),
          const SizedBox(height: TwSpace.s12),
          Wrap(
            spacing: TwSpace.s8,
            runSpacing: TwSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (pro.reviews > 0)
                RatingCapsule(rating: pro.rating, count: pro.reviews)
              else
                Text('No reviews yet', style: TwType.meta()),
              if (slot != null) AvailabilityCapsule(label: 'Next: $slot'),
            ],
          ),
          const SizedBox(height: TwSpace.s12),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.cardBorder,
          ),
          const SizedBox(height: 10),
          Text(
            pro.footerText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TwType.meta(color: AppTheme.body),
          ),
          const SizedBox(height: TwSpace.s4),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: canToggle ? () => _toggleCompare(pro) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.blue : AppTheme.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? AppTheme.blue : AppTheme.border,
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  size: 15, color: AppTheme.white)
                              : null,
                        ),
                        const SizedBox(width: TwSpace.s8),
                        Flexible(
                          child: Text(
                            selected ? 'Added to compare' : 'Compare',
                            style: TwType.link(
                              color: selected
                                  ? AppTheme.blue
                                  : canToggle
                                      ? AppTheme.navy
                                      : AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openProProfile(pro),
                child: const Text('View profile'),
              ),
            ],
          ),
        ],
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
  final double rating;
  final int reviews;
  final double distanceMiles;
  final int completedWorkOrders;

  /// Raw next-slot value from search; null when the pro has none.
  final String? nextAvailable;
  final double price;
  final String priceLabel;
  final String workOrderType;
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
    required this.rating,
    required this.reviews,
    required this.distanceMiles,
    required this.completedWorkOrders,
    required this.nextAvailable,
    required this.price,
    required this.priceLabel,
    this.workOrderType = '',
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
    final price = readDouble(map['fromPrice'], 0);
    final workOrderType =
        read(map['workOrderType'], read(map['work_order_type']));
    final completedWorkOrders = readInt(map['completedWorkOrders'], reviews);
    final nextAvailableText = read(map['nextAvailable']);
    final String? nextAvailableRaw =
        nextAvailableText.isEmpty ? null : nextAvailableText;
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
      rating: rating,
      reviews: reviews,
      distanceMiles: distance,
      completedWorkOrders: completedWorkOrders,
      nextAvailable: nextAvailableRaw,
      price: price,
      priceLabel: priceLabel,
      workOrderType: workOrderType,
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

  String get priceHeadline {
    if (workOrderType == 'quote_request') return 'Free visit';
    return price > 0 ? formatUsd(price) : '';
  }

  String get priceNote => switch (workOrderType) {
        'nte' => 'diagnostic · You approve the cap',
        'quote_request' => 'The pro sends you an estimate',
        'rate_card' => 'Upfront price',
        _ => priceLabel,
      };

  String get slug =>
      apiSlug.isNotEmpty ? apiSlug : name.toLowerCase().replaceAll(' ', '-');

  String get footerText {
    final summaryText = summary.trim();
    if (summaryText.isNotEmpty) return summaryText;

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
    final foreground = enabled ? AppTheme.navy : AppTheme.textTertiary;
    return Semantics(
      button: enabled,
      enabled: enabled,
      selected: active,
      label: '$label, $meta${enabled ? '' : ', unavailable'}',
      child: Material(
        color: active ? AppTheme.blueTint : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(
            color: active ? AppTheme.blue : AppTheme.cardBorder,
            width: active ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            width: _SearchTabState._railTileWidth,
            padding: const EdgeInsets.all(TwSpace.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ServiceCategoryIcon(
                  category: category,
                  size: 28,
                  fallbackIcon: fallbackIcon,
                  fallbackColor:
                      enabled ? AppTheme.navy : AppTheme.textTertiary,
                ),
                const SizedBox(height: TwSpace.s4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwType.caption(color: foreground)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwType.caption(),
                ),
              ],
            ),
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
      child: TwCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.subtle,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: ServiceCategoryIcon(
                category: service.category,
                size: 24,
                fallbackIcon: token.icon,
                fallbackColor: AppTheme.navy,
              ),
            ),
            const SizedBox(width: TwSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: TwType.title()),
                  const SizedBox(height: 2),
                  Text(service.category, style: TwType.meta()),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

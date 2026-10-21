import '../utils/lazy_results.dart';
import '../widgets/loading_skeleton.dart';
import '../utils/session_pro_order.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/homeowner_service.dart';
import '../services/auth_service.dart';
import '../services/intake_service.dart';
import '../services/browse_search_history.dart';
import '../services/service_catalog.dart';
import '../utils/booking_timing.dart';
import '../utils/booking_identity.dart';
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
  final bool active;

  const SearchTab({
    super.key,
    required this.onBookPro,
    this.initialSearchQuery,
    this.initialCategory,
    this.initialAllShowsCategories = false,
    this.showSectionBackButton = true,
    this.active = true,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final TextEditingController _locationController = TextEditingController();
  final List<String> _recentSearches = [];
  final BrowseSearchHistory _searchHistory = BrowseSearchHistory();
  final List<_BrowsePro> _livePros = [];
  final Map<String, int> _categoryCounts = {};
  final Map<String, bool> _categoryCoverage = {};
  final List<String> _compareIds = [];

  _BrowseView _view = _BrowseView.searchFocused;
  String? _bookingDescription;
  String? _descriptionCategory;
  String _selectedCategory = 'All';
  String _selectedZip = '';
  String? _committedQuery;
  bool _isInitializing = true;
  bool _isLoadingResults = false;
  bool _suppressLocationReset = false;
  String? _resultsError;
  int _prosRequestToken = 0;
  LazyResults<_BrowsePro>? _proPages;
  bool _isLoadingMore = false;
  String? _loadMoreError;
  bool _preserveSearchViewOnUnfocus = false;
  int get _availableProsCount {
    if (_selectedCategory == 'All') {
      return _allProsCount > 0 ? _allProsCount : _livePros.length;
    }
    return _categoryCounts[_selectedCategory] ?? _livePros.length;
  }

  @override
  void initState() {
    super.initState();
    ServiceCatalog.revision.addListener(_refreshServiceCatalog);
    unawaited(ServiceCatalog.load());
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_handleFocusChange);
    BrowseSearchHistory.revision.addListener(_loadRecentSearches);
    ServiceLocation.selected.addListener(_handleSharedLocationChanged);
    HomeownerService.instance.contractorCatalogVersion
        .addListener(_refreshContractorCatalog);
    _applyLocationLabel('Enter ZIP code', _selectedZip);
    _loadRecentSearches();

    if (widget.initialCategory != null && widget.initialCategory != 'All') {
      _selectedCategory = widget.initialCategory!;
      _view = _BrowseView.results;
    }
    if (widget.initialCategory == 'All') {
      _selectedCategory = 'All';
      _view = _BrowseView.allCategories;
    }
    if (_searchController.text.trim().isNotEmpty) {
      _committedQuery = _searchController.text.trim();
      _view = _BrowseView.results;
    }

    _loadLocationAndResults();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.active &&
          widget.initialCategory == null &&
          _view == _BrowseView.searchFocused) _searchFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _selectedCategory = 'All';
        _committedQuery = null;
        _searchController.clear();
        _view = _BrowseView.searchFocused;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.active) _searchFocusNode.requestFocus();
        });
      } else {
        _dismissSearchKeyboard();
      }
    }
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
            ? _BrowseView.searchFocused
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
    }
  }

  @override
  void dispose() {
    ServiceCatalog.revision.removeListener(_refreshServiceCatalog);
    BrowseSearchHistory.revision.removeListener(_loadRecentSearches);
    ServiceLocation.selected.removeListener(_handleSharedLocationChanged);
    HomeownerService.instance.contractorCatalogVersion
        .removeListener(_refreshContractorCatalog);
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
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
    _locationController.text = '$normalizedCity · $zip';
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
            _selectedCategory != 'All';
        if (!hasPendingSearch || !await _requestZipIfNeeded()) return;
      }
      // Coverage enriches the location label; it must not block results.
      unawaited(_refreshZipCoverage());
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

      final city = [
        _readText(defaultAddr['city']) ?? 'Home',
        _readText(defaultAddr['state'])
      ].whereType<String>().join(', ');
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
    if (_isInitializing) return;
    if (location == null) {
      if (_suppressLocationReset) return;
      if (AuthService.instance.isAuthenticated) {
        unawaited(_restorePrimaryLocation());
      } else if (_selectedZip.isNotEmpty) {
        setState(() {
          _prosRequestToken++;
          _proPages = null;
          _selectedZip = '';
          _applyLocationLabel('Enter ZIP code', '');
          _livePros.clear();
          _categoryCounts.clear();
          _categoryCoverage.clear();
          _isLoadingResults = false;
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
        _proPages = null;
        _selectedZip = '';
        _applyLocationLabel('Enter ZIP code', '');
        _livePros.clear();
        _categoryCounts.clear();
        _categoryCoverage.clear();
        _resultsError = null;
      });
    }

    await _loadLocationFromProfile(ignoreSharedOverride: true);
    if (_selectedZip.isEmpty) return;
    unawaited(_refreshZipCoverage());
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

  Future<void> _refreshZipCoverage() async {
    final zip = _selectedZip.trim();
    if (zip.isEmpty) {
      return;
    }

    if (mounted) {}

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
        // A late coverage response must not replace the selected search's
        // authoritative result count with an older catalogue estimate.
        if (_view == _BrowseView.results &&
            _categoryCounts.containsKey(_selectedCategory)) {
          nextCounts[_selectedCategory] = _categoryCounts[_selectedCategory]!;
        }
        _categoryCounts
          ..clear()
          ..addAll(nextCounts);
        _categoryCoverage
          ..clear()
          ..addAll(nextCoverage);
        _selectedZip = returnedZip;
        _applyLocationLabel(resolvedLocation, returnedZip);
      });
    } catch (_) {
      if (!mounted || zip != _selectedZip) {
        return;
      }
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

  int get _allProsCount {
    if (_categoryCounts.isEmpty) {
      return 0;
    }
    return _categoryCounts.values.fold<int>(0, (sum, value) => sum + value);
  }

  String get _locationChipLabel =>
      _locationController.text.replaceAll(' · ', ' ').trim();

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
        if (_view != _BrowseView.allCategories)
          _view = _BrowseView.searchFocused;
      } else {
        _view = _BrowseView.results;
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
      _isLoadingResults = true;
      _resultsError = null;
      _prosRequestToken++;
      _proPages = null;
      _isLoadingMore = false;
      _loadMoreError = null;
    });
    await _saveSharedLocationOverride(nextZip, cityLabel);
    unawaited(_refreshZipCoverage());

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
              ? _BrowseView.searchFocused
              : _BrowseView.results)
          : _BrowseView.results;
    });
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    // The initial location load will execute this pending query. Do not open a
    // ZIP prompt while an authenticated account's default address is loading.
    if (_isInitializing) return;

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
    _preserveSearchViewOnUnfocus = true;
    _searchFocusNode.unfocus();
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
      _view = _BrowseView.searchFocused;
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
      _view = _BrowseView.results;
    });
    _searchFocusNode.unfocus();
    if (_isInitializing) return;
    _runCategorySearch(category);
  }

  Future<void> _runAllServicesSearch() async => _openAllCategories();

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
      _view = overrideQuery == null ? _BrowseView.results : _BrowseView.results;
    });

    _startProPages([
      () => _fetchProCategory(category, slug, requestedZip, requestToken,
          urgency: urgency),
    ]);
    await _loadProPage(requestToken, initial: true);
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
            category: category, urgency: urgency))
        .toList();
    _categoryCounts[category] = response['count'] is num
        ? (response['count'] as num).toInt()
        : results.length;
    _categoryCoverage[category] =
        response['covered'] == true || results.isNotEmpty;
    return _shuffledBrowsePros(results);
  }

  void _startProPages(List<Future<List<_BrowsePro>> Function()> sources) {
    _proPages = LazyResults(
        sources: sources,
        keyOf: (pro) => '${_proAvailabilityKey(pro)}|${pro.category}');
    _livePros.clear();
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
      // Public search already computes nextAvailable from the cached calendar
      // blocks. Re-fetching every card's slots adds up to 12 competing calls.
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

  String _proAvailabilityKey(_BrowsePro pro) {
    final offering = '${pro.contractorServiceId}:${pro.urgency}:$_selectedZip';
    if (pro.contractorId.trim().isNotEmpty) {
      return 'id:${pro.contractorId.trim().toLowerCase()}:$offering';
    }
    if (pro.slug.trim().isNotEmpty) {
      return 'slug:${pro.slug.trim().toLowerCase()}:$offering';
    }
    return 'name:${pro.name.trim().toLowerCase()}:$offering';
  }

  /// "Tomorrow", "Wed"… or null when the pro has no open slot
  /// (B02: no capsule then — Batch 21 Amendment 1 R3).
  String? _nextAvailableLabelFor(_BrowsePro pro) {
    if (pro.nextAvailable == null) return null;
    final label = _formatLooseAvailabilityLabel(pro.nextAvailable);
    return label == null || label.isEmpty ? null : label;
  }

  String? _formatLooseAvailabilityLabel(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      return _formatSlotLabel(trimmed, null);
    }
    final day = RegExp(r'^(Today|Tomorrow|Mon|Tue|Wed|Thu|Fri|Sat|Sun)',
            caseSensitive: false)
        .firstMatch(trimmed);
    return day?.group(1);
  }

  String? _formatSlotLabel(String? startRaw, String? endRaw) {
    final start = BookingTiming.wallClock(startRaw);
    if (start == null) return null;
    final now = DateTime.now();
    final day = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE').format(start);
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
    for (final service in ServiceCatalog.items) {
      if (service.category == category) return service.categorySlug;
    }
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
      case 'Lawn':
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

  void _refreshServiceCatalog() {
    if (mounted) setState(() {});
  }

  List<_BrowseCategory> get _allCategories {
    const icons = <String, IconData>{
      'Moving': Icons.local_shipping,
      'Appliance Repair': Icons.kitchen,
      'Concrete': Icons.construction,
      'Garage Doors': Icons.garage,
      'Flooring': Icons.layers,
      'Plumbing': Icons.plumbing,
      'HVAC': Icons.ac_unit,
      'Electrical': Icons.flash_on,
      'Cleaning': Icons.cleaning_services,
      'Landscaping': Icons.nature_people,
      'Painting': Icons.format_paint,
      'Water Treatment': Icons.water_drop,
      'Roofing': Icons.roofing,
      'Windows & Doors': Icons.window,
      'Smart Home': Icons.settings_remote,
      'Solar Energy': Icons.solar_power,
      'Tree Service': Icons.park,
      'Pest Control': Icons.bug_report,
      'Home Security': Icons.security,
      'Insulation': Icons.wb_shade,
      'Locksmith': Icons.lock,
      'Junk Removal': Icons.delete_outline,
      'Remodeling': Icons.construction,
      'Fencing & Decks': Icons.fence,
      'Drywall & Plaster': Icons.texture,
      'Gutters': Icons.waves,
      'Screen Repair': Icons.grid_on,
      'Pool & Spa': Icons.pool,
      'Fireplace & Chimney': Icons.fireplace,
      'Siding': Icons.home_work,
      'Concrete & Masonry': Icons.foundation,
    };
    final groups = <String, List<ServiceCatalogItem>>{};
    for (final service in ServiceCatalog.items) {
      groups.putIfAbsent(service.categorySlug, () => []).add(service);
    }
    return groups.entries.map((entry) {
      final name =
          _categoryNameForSlug(entry.key) ?? entry.value.first.category;
      return _BrowseCategory(
        name: name,
        icon: icons[name] ?? Icons.home_repair_service_outlined,
        serviceCount: entry.value.length,
        prosCount: _categoryCounts[name] ?? 0,
        color: AppTheme.navy700,
        covered: true,
      );
    }).toList();
  }

  List<_BrowseService> get _serviceCatalog => ServiceCatalog.items
      .map((service) => _BrowseService(service.name,
          _categoryNameForSlug(service.categorySlug) ?? service.category))
      .toList(growable: false);

  List<_BrowseService> get _mainServiceCatalog => _allCategories
      .map((category) => _BrowseService(category.name, ''))
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
      'contractorServiceId': pro.contractorServiceId,
      'zip': _selectedZip,
      'userId': pro.userId,
      'businessName': pro.name,
      'business_name': pro.name,
      ...pro.reviewFields,
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
                      if ((_committedQuery?.trim().isNotEmpty ?? false))
                        'selectedService': _committedQuery!.trim()
                    }, initialDescription: _bookingDescription)));
    }
  }

  Future<void> _openCompareMessage(Map<String, dynamic> pro) async {
    if (!AuthService.instance.isAuthenticated) {
      AppNotification.showInfo(context, 'Please sign in to message this pro.');
      return;
    }
    final recipientId = StreamService.instance.resolveMessagingUserId(pro);
    final profileId = BookingIdentity.contractor(pro);
    if (recipientId == null && profileId == null) {
      AppNotification.showInfo(
          context, 'Chat is not available for this pro yet.');
      return;
    }
    final name = (pro['business_name'] ?? pro['businessName'] ?? 'Pro')
        .toString()
        .trim();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contractorId: recipientId ?? '',
          contractorProfileId: profileId,
          contractorName: name.isEmpty ? 'Pro' : name,
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
    if (_view == _BrowseView.allCategories) {
      return _buildAllCategories();
    }
    if (_isInitializing && _view != _BrowseView.searchFocused) {
      return const SkeletonPage(
        layout: SkeletonLayout.browse,
        label: 'Loading nearby services',
      );
    }

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
        body = _buildResults(visiblePros);
        break;
      case _BrowseView.noCoverage:
        body = _buildNoCoverage();
        break;
    }

    return body;
  }

  Widget _buildCompactLocationChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppTheme.white,
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
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                  ServiceCatalog.loaded
                      ? '${_mainServiceCatalog.length} services'
                      : 'Loading services…',
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
            if (ServiceCatalog.error != null) ...[
              Text(ServiceCatalog.error!, style: TwType.bodySm()),
              TextButton(
                  onPressed: () => ServiceCatalog.load(forceRefresh: true),
                  child: const Text('Retry')),
            ],
            if (ServiceCatalog.loaded && _mainServiceCatalog.isEmpty)
              Text('No services are available right now.',
                  style: TwType.bodySm()),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisSpacing: TwSpace.s8,
              mainAxisSpacing: TwSpace.s12,
              childAspectRatio: ((MediaQuery.sizeOf(context).width -
                          TwLayout.gutter(context) * 2 -
                          TwSpace.s8 * 3) /
                      4) /
                  (MediaQuery.textScalerOf(context).scale(13) > 15 ? 108 : 96),
              children: [
                for (final service in _mainServiceCatalog)
                  ServiceCategoryTile(
                    label: service.name,
                    onTap: () {
                      _searchController.clear();
                      _selectCategory(service.name);
                    },
                  ),
              ],
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
      emptyMessage: 'No live pros matched this search.',
      header: [
        _buildSearchInputPill(),
        const SizedBox(height: TwSpace.s20),
        if (!_isLoadingResults &&
            _resultsError == null &&
            _livePros.isNotEmpty) ...[
          ..._resultsHeader(_availableProsCount),
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
          Row(children: [
            Flexible(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: pro.reviews > 0
                        ? RatingCapsule(rating: pro.rating, count: pro.reviews)
                        : Text('New to TradeWorks', style: TwType.meta()))),
            const SizedBox(width: TwSpace.s8),
            const Spacer(),
            if (slot != null)
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AvailabilityCapsule(label: 'Next: $slot'))),
          ]),
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
                child: Text('View profile', style: TwType.link()),
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
  final String contractorServiceId;
  final String urgency;
  final String userId;
  final String apiSlug;
  final String name;
  final String? photoUrl;
  final String initials;
  final String category;
  final String trade;
  final Map<String, dynamic> reviewFields;
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
    this.contractorServiceId = '',
    this.urgency = 'standard',
    this.userId = '',
    this.apiSlug = '',
    required this.name,
    this.photoUrl,
    required this.initials,
    required this.category,
    required this.trade,
    this.reviewFields = const {},
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
    String urgency = 'standard',
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
    final combined =
        map['rating_combined'] != null && map['review_count_combined'] != null;
    final rating = readDouble(
        combined ? map['rating_combined'] : map['verifiedRating'], 0);
    final reviews = readInt(
        combined ? map['review_count_combined'] : map['verifiedCount'], 0);
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
      contractorServiceId:
          read(map['contractorServiceId'], read(map['contractor_service_id'])),
      urgency: urgency,
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
      reviewFields: {
        for (final key in [
          'rating_combined',
          'review_count_combined',
          'google_review_count',
          'review_count_google',
          'tradeworks_review_count',
          'review_count_tradeworks'
        ])
          if (map.containsKey(key)) key: map[key]
      },
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
    return 'View pro details';
  }
}

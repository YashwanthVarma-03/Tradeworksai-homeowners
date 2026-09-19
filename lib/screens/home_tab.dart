import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/browse_search_history.dart';
import '../services/homeowner_service.dart';
import '../services/service_catalog.dart';
import '../services/service_location.dart';
import '../theme.dart';
import '../utils/app_error_utils.dart';
import '../widgets/ai_intake_sheet.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/offline_state.dart';
import '../widgets/service_search_bar.dart';
import '../widgets/service_zip_entry_dialog.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onBookTap;
  final Function(Map<String, dynamic>) onJobTap;
  final VoidCallback onInboxTap;
  final VoidCallback onHelpTap;
  final Function(String) onSearchQuery;
  final Function(String) onCategorySelected;
  final VoidCallback onGuidesTap;
  final VoidCallback onManageHomeTap;
  final bool isGuest;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onSignIn;

  const HomeTab({
    super.key,
    required this.onBookTap,
    required this.onJobTap,
    required this.onInboxTap,
    required this.onHelpTap,
    required this.onSearchQuery,
    required this.onCategorySelected,
    required this.onGuidesTap,
    required this.onManageHomeTap,
    this.isGuest = false,
    this.onCreateAccount,
    this.onSignIn,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  static final List<String> _serviceNames = ServiceCatalog.names;

  static const List<String> _homeCategories = [
    'HVAC',
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Roofing',
    'Lawn',
    'Handyman',
  ];

  static const Map<String, Color> _categoryBackgrounds = {
    'HVAC': Color(0xFFE3F2FD),
    'Plumbing': Color(0xFFE0F7FA),
    'Electrical': Color(0xFFFFF8E1),
    'Cleaning': Color(0xFFE8F5E9),
    'Roofing': Color(0xFFFFEBEE),
    'Lawn': Color(0xFFF1F8E9),
    'Handyman': Color(0xFFF3E5F5),
  };

  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE6E8EC);
  static const double _searchPlaceholderFontSize = 14;
  static const double _searchTickerHeight = 18;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final PageController _tickerPageController;
  Timer? _serviceTicker;
  int _serviceTickerIndex = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _manualZipOverride;
  String? _manualLocationName;
  Map<String, dynamic> _profile = const {};
  Map<String, dynamic> _localHomeDetails = const {};
  List<dynamic> _addresses = const [];
  List<dynamic> _activeJobs = const [];
  List<dynamic> _upcomingJobs = const [];
  List<dynamic> _quoteSourceJobs = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_refreshInputs);
    _searchFocusNode.addListener(_refreshInputs);
    ServiceLocation.selected.addListener(_handleSharedLocationChanged);

    // Initialize PageController starting from a high initial page for infinite smooth scrolling
    _tickerPageController =
        PageController(initialPage: 1000 * _serviceNames.length);
    _startServiceTicker();
    _loadSharedLocationOverride();
    if (widget.isGuest) {
      _isLoading = false;
      return;
    }
    HomeownerService.instance.syncVersion.addListener(_refreshFromSharedSync);
    _restoreCachedHomeThenRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isGuest && state == AppLifecycleState.resumed) {
      _fetchHomeData(showLoading: false, forceRefresh: true);
    }
  }

  @override
  void dispose() {
    ServiceLocation.selected.removeListener(_handleSharedLocationChanged);
    if (!widget.isGuest) {
      HomeownerService.instance.syncVersion
          .removeListener(_refreshFromSharedSync);
    }
    _tickerPageController.dispose();
    _serviceTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController
      ..removeListener(_refreshInputs)
      ..dispose();
    _searchFocusNode
      ..removeListener(_refreshInputs)
      ..dispose();
    super.dispose();
  }

  void _refreshFromSharedSync() {
    if (widget.isGuest) return;
    _fetchHomeData(showLoading: false);
  }

  void _refreshInputs() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startServiceTicker() {
    _serviceTicker?.cancel();
    _serviceTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted ||
          !_tickerPageController.hasClients ||
          _searchController.text.trim().isNotEmpty ||
          _searchFocusNode.hasFocus) {
        return;
      }

      _tickerPageController.nextPage(
        duration: const Duration(milliseconds: 750),
        curve: Curves.fastOutSlowIn, // Smoother physics-based curve
      );
    });
  }

  bool get _hasHomeContent =>
      _profile.isNotEmpty || _activeJobs.isNotEmpty || _upcomingJobs.isNotEmpty;

  Future<void> _restoreCachedHomeThenRefresh() async {
    if (widget.isGuest) return;
    final results = await Future.wait([
      HomeownerService.instance.loadCachedWorkOrders(),
      HomeownerService.instance.loadCachedProfile(),
      _loadLocalHomeDetails(),
    ]);
    if (!mounted) return;

    final woData = results[0] as Map<String, dynamic>?;
    final profileData = results[1] as Map<String, dynamic>?;
    final localHomeDetails = results[2] as Map<String, dynamic>;
    if (woData != null || profileData != null) {
      final tabs = woData?['tabs'];
      final profile = profileData?['profile'];
      final addresses = (profileData?['addresses'] as List?) ??
          (profile is Map ? profile['addresses'] as List? : null) ??
          const [];
      setState(() {
        _profile = profile is Map<String, dynamic>
            ? Map<String, dynamic>.from(profile)
            : profile is Map
                ? Map<String, dynamic>.from(profile)
                : const {};
        _localHomeDetails = localHomeDetails;
        _addresses = List<dynamic>.from(addresses);
        if (tabs is Map) {
          _activeJobs = List<dynamic>.from(tabs['active'] ?? const []);
          _upcomingJobs = List<dynamic>.from(tabs['scheduled'] ?? const []);
        }
        _quoteSourceJobs =
            woData == null ? const [] : _workOrderCandidatesFrom(woData);
        _isLoading = false;
        _errorMessage = null;
      });
    }
    await _fetchHomeData(showLoading: false, forceRefresh: true);
  }

  Future<void> _fetchHomeData({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    if (widget.isGuest) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;

    if (showLoading && !_hasHomeContent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        HomeownerService.instance.fetchWorkOrders(forceRefresh: forceRefresh),
        HomeownerService.instance.fetchProfile(forceRefresh: forceRefresh),
        _loadLocalHomeDetails(),
      ]);

      final woData = results[0] as Map<String, dynamic>;
      final profileData = results[1] as Map<String, dynamic>;
      final localHomeDetails = results[2] as Map<String, dynamic>;
      final tabs = woData['tabs'];
      final quoteSourceJobs = _workOrderCandidatesFrom(woData);
      final profile = profileData['profile'];
      final addresses = (profileData['addresses'] as List?) ??
          (profile is Map ? profile['addresses'] as List? : null) ??
          const [];

      if (!mounted) return;
      setState(() {
        _profile = profile is Map<String, dynamic>
            ? Map<String, dynamic>.from(profile)
            : profile is Map
                ? Map<String, dynamic>.from(profile)
                : const {};
        _localHomeDetails = localHomeDetails;
        _addresses = List<dynamic>.from(addresses);
        if (tabs is Map) {
          _activeJobs = List<dynamic>.from(tabs['active'] ?? const []);
          _upcomingJobs = List<dynamic>.from(tabs['scheduled'] ?? const []);
        } else {
          _activeJobs = const [];
          _upcomingJobs = const [];
        }
        _quoteSourceJobs = quoteSourceJobs;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Retain the last known screen instead of replacing it with an error
        // during a transient offline or timeout event.
        _errorMessage =
            _hasHomeContent ? null : AppErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadSharedLocationOverride() async {
    final location = await ServiceLocation.load();
    if (location == null || !mounted) {
      return;
    }
    final zip = location.zip;
    final locationName = location.locationName;
    final needsLocationLookup =
        locationName.isEmpty || locationName.toLowerCase() == 'serving area';
    setState(() {
      _manualZipOverride = zip;
      _manualLocationName = needsLocationLookup ? zip : locationName;
    });
    if (needsLocationLookup) {
      unawaited(_resolveAndSaveLocationName(zip));
    }
  }

  Future<void> _saveSharedLocationOverride(
      String zip, String locationName) async {
    await ServiceLocation.save(zip: zip, locationName: locationName);
  }

  void _handleSharedLocationChanged() {
    final location = ServiceLocation.selected.value;
    if (!mounted) {
      return;
    }
    if (location == null) {
      if (_manualZipOverride == null && _manualLocationName == null) return;
      setState(() {
        _manualZipOverride = null;
        _manualLocationName = null;
      });
      return;
    }
    if (_manualZipOverride == location.zip &&
        _manualLocationName == location.locationName) {
      return;
    }
    setState(() {
      _manualZipOverride = location.zip;
      _manualLocationName =
          location.locationName.isEmpty ? location.zip : location.locationName;
    });
  }

  Map<String, dynamic>? get _defaultAddress {
    if (_addresses.isEmpty) return null;
    final match = _addresses.firstWhere(
      (dynamic item) =>
          item is Map &&
          (item['isDefault'] == true ||
              item['isDefault'] == 'true' ||
              item['is_default'] == true ||
              item['is_default'] == 'true' ||
              item['isPrimary'] == true ||
              item['isPrimary'] == 'true' ||
              item['is_primary'] == true ||
              item['is_primary'] == 'true'),
      orElse: () => _addresses.first,
    );
    if (match is Map<String, dynamic>) {
      return Map<String, dynamic>.from(match);
    }
    if (match is Map) {
      return Map<String, dynamic>.from(match);
    }
    return null;
  }

  String get _locationLabel {
    final manualZip = _manualZipOverride;
    if (manualZip != null && manualZip.isNotEmpty) {
      final locationName = _manualLocationName?.trim() ?? '';
      return locationName.isEmpty ? manualZip : '$locationName, $manualZip';
    }
    final address = _defaultAddress;
    final city = _text(address?['city']);
    final state = _text(address?['state']);
    final zip = _text(address?['zip']);
    final locationName =
        [city, state].where((part) => part.isNotEmpty).join(', ');
    if (zip.isEmpty) {
      return locationName.isEmpty ? 'Enter ZIP code' : locationName;
    }
    return locationName.isEmpty ? zip : '$locationName, $zip';
  }

  String? get _currentZip {
    final manualZip = _manualZipOverride;
    if (manualZip != null && manualZip.length == 5) {
      return manualZip;
    }
    final address = _defaultAddress;
    final digits = _text(address?['zip']).replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 5 ? digits : null;
  }

  Future<Map<String, dynamic>> _loadLocalHomeDetails() async {
    final defaultAddress = _defaultAddress;
    final addressId = defaultAddress?['id']?.toString() ?? '';
    if (addressId.isEmpty) {
      return const {};
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('home_profile_$addressId');
    if (stored == null || stored.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return const {};
  }

  bool get _hasBackendHomeDetails {
    return _containsHomeDetails(_profile) ||
        _containsHomeDetails(_defaultAddress) ||
        _containsHomeDetails(_localHomeDetails);
  }

  bool _containsHomeDetails(dynamic node) {
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      for (final key in const [
        'sqft',
        'squareFootage',
        'square_footage',
        'squareFeet',
        'square_feet',
        'yearBuilt',
        'year_built',
        'bedrooms',
        'bathrooms',
        'hvacAge',
        'hvac_age',
        'waterHeaterAge',
        'water_heater_age',
        'roofAge',
        'roof_age',
      ]) {
        if (_hasMeaningfulValue(map[key])) return true;
      }

      for (final key in const [
        'homeProfile',
        'home_profile',
        'propertyProfile',
        'property_profile',
        'systems',
        'homeSystems',
        'home_systems',
        'hvac',
        'waterHeater',
        'water_heater',
        'roof',
      ]) {
        if (_containsHomeDetails(map[key])) return true;
      }
    }

    if (node is List) {
      return node.any(_containsHomeDetails);
    }

    return false;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is num) return value > 0;
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty && normalized != 'null' && normalized != '-';
    }
    if (value is Map) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  List<dynamic> _workOrderCandidatesFrom(Map<String, dynamic> data) {
    final candidates = <dynamic>[];
    final seen = <String>{};

    void addJob(dynamic value) {
      if (value is! Map) return;
      final job = Map<String, dynamic>.from(value);
      final id = _text(
        job['workOrderId'] ??
            job['work_order_id'] ??
            job['id'] ??
            job['bookingId'] ??
            job['booking_id'],
      );
      final key = id.isEmpty ? job.hashCode.toString() : id;
      if (seen.add(key)) candidates.add(job);
    }

    void addList(dynamic value) {
      if (value is List) {
        for (final item in value) {
          addJob(item);
        }
      }
    }

    final tabs = data['tabs'];
    if (tabs is Map) {
      addList(tabs['active']);
      addList(tabs['scheduled']);
      addList(tabs['history']);
      addList(tabs['quoteReady']);
      addList(tabs['quote_ready']);
    }

    for (final key in const [
      'activeWorkOrders',
      'scheduledWorkOrders',
      'historyWorkOrders',
      'workOrders',
      'work_orders',
      'jobs',
      'results',
      'quoteReady',
      'quoteReadyJobs',
      'quoteReadyWorkOrders',
      'quote_ready',
      'quote_ready_jobs',
      'quote_ready_work_orders',
    ]) {
      addList(data[key]);
    }

    final nested = data['data'];
    if (nested is Map) {
      candidates
          .addAll(_workOrderCandidatesFrom(Map<String, dynamic>.from(nested)));
    } else {
      addList(nested);
    }

    return candidates;
  }

  List<Map<String, dynamic>> get _quoteReadyJobs {
    final jobs = _quoteSourceJobs.isEmpty
        ? <dynamic>[..._activeJobs, ..._upcomingJobs]
        : _quoteSourceJobs;
    final matches = <Map<String, dynamic>>[];

    for (final dynamic item in jobs) {
      if (item is! Map) continue;
      final job = Map<String, dynamic>.from(item);
      final status = _statusOf(job).replaceAll('-', '_').replaceAll(' ', '_');
      final quoteStatus = _text(
        job['quoteStatus'] ??
            job['quote_status'] ??
            job['approvalStatus'] ??
            job['approval_status'],
      ).toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
      final requiredAction = _text(
        job['requiredAction'] ??
            job['required_action'] ??
            job['nextAction'] ??
            job['next_action'] ??
            job['action'],
      ).toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
      final needsQuoteApproval = job['needsQuoteApproval'] == true ||
          job['needs_quote_approval'] == true ||
          job['requiresQuoteApproval'] == true ||
          job['requires_quote_approval'] == true ||
          job['requiresCapApproval'] == true ||
          job['requires_cap_approval'] == true ||
          job['hasQuote'] == true ||
          job['has_quote'] == true ||
          job['quoteReady'] == true ||
          job['quote_ready'] == true ||
          job['estimateReady'] == true ||
          job['estimate_ready'] == true;
      final hasQuoteData = _hasMeaningfulValue(job['quote']) ||
          _hasMeaningfulValue(job['quoteDetails']) ||
          _hasMeaningfulValue(job['quote_details']) ||
          _hasMeaningfulValue(job['quoteAmount']) ||
          _hasMeaningfulValue(job['quote_amount']) ||
          _hasMeaningfulValue(job['nteAmount']) ||
          _hasMeaningfulValue(job['nte_amount']) ||
          _hasMeaningfulValue(job['totalNTE']) ||
          _hasMeaningfulValue(job['total_nte']) ||
          _hasMeaningfulValue(job['capAmount']) ||
          _hasMeaningfulValue(job['cap_amount']) ||
          _hasMeaningfulValue(job['quoteCap']) ||
          _hasMeaningfulValue(job['quote_cap']) ||
          _hasMeaningfulValue(job['notToExceed']) ||
          _hasMeaningfulValue(job['not_to_exceed']) ||
          _hasMeaningfulValue(job['estimate']) ||
          _hasMeaningfulValue(job['estimateAmount']) ||
          _hasMeaningfulValue(job['estimate_amount']);
      final timeline = job['timeline'];
      final hasAcceptedTimeline =
          timeline is Map && _hasMeaningfulValue(timeline['acceptedAt']);
      final isPastOrCommitted = status.contains('complete') ||
          status.contains('cancel') ||
          status.contains('decline') ||
          status == 'en_route' ||
          status == 'arrived' ||
          status == 'in_progress';
      if (isPastOrCommitted) continue;
      if (status.contains('quote') ||
          status.contains('cap_pending') ||
          status.contains('estimate') ||
          status.contains('approval') ||
          status.contains('review') ||
          quoteStatus.contains('pending') ||
          quoteStatus.contains('ready') ||
          quoteStatus.contains('review') ||
          requiredAction.contains('quote') ||
          requiredAction.contains('cap') ||
          requiredAction.contains('approve') ||
          requiredAction.contains('review') ||
          needsQuoteApproval ||
          hasQuoteData ||
          (status == 'active' && hasAcceptedTimeline)) {
        matches.add(job);
      }
    }
    return matches;
  }

  String _statusOf(Map<String, dynamic> job) =>
      _text(job['status']).toLowerCase();

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _formatRelativeTimestamp(dynamic raw) {
    final value = _text(raw);
    if (value.isEmpty) return 'Just now';
    try {
      final date = DateTime.parse(value).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) {
        return diff.inMinutes == 1
            ? '1 minute ago'
            : '${diff.inMinutes} minutes ago';
      }
      if (diff.inHours < 24) {
        return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
      }
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Just now';
    }
  }

  String get _displayedService {
    final typed = _searchController.text.trim();
    return typed.isNotEmpty ? typed : _serviceNames[_serviceTickerIndex];
  }

  int get _serviceCount => _serviceNames.length;

  String get _allServicesLabel => 'All $_serviceCount';

  void _openSearch([String? value]) {
    final query = (value ?? _displayedService).trim();
    if (query.isEmpty) return;
    // Home lives in the shell's IndexedStack. Reset the field before pushing
    // Browse so returning home never restores a focused, stale search state.
    _searchFocusNode.unfocus();
    _searchController.clear();
    // Recent searches are device-level discovery history, not account data.
    // Queue this before navigation so Browse restores the same cache for both
    // visitors and authenticated homeowners.
    unawaited(BrowseSearchHistory().save(query));
    widget.onSearchQuery(query);
  }

  Future<String> _locationNameForZip(String zip) async {
    try {
      final coverage = await HomeownerService.instance.getZipCoverage(zip: zip);
      final city = _text(
        coverage['city'],
        _text(coverage['areaName'], _text(coverage['area_name'])),
      );
      final state = _text(coverage['state']);
      final location =
          [city, state].where((part) => part.isNotEmpty).join(', ');
      return location.isEmpty ? zip : location;
    } catch (_) {
      // Keep the entered ZIP visible if the address lookup is temporarily down.
      return zip;
    }
  }

  Future<void> _resolveAndSaveLocationName(String zip) async {
    final locationName = await _locationNameForZip(zip);
    if (!mounted || _manualZipOverride != zip) return;
    await _saveSharedLocationOverride(zip, locationName);
    if (!mounted || _manualZipOverride != zip) return;
    setState(() => _manualLocationName = locationName);
  }

  Future<void> _openZipEntry() async {
    final nextZip = await showServiceZipEntryDialog(
      context,
      initialZip: _currentZip ?? '',
    );

    if (nextZip == null || !mounted) {
      return;
    }

    final locationName = await _locationNameForZip(nextZip);
    if (!mounted) return;
    await _saveSharedLocationOverride(nextZip, locationName);
    setState(() {
      _manualZipOverride = nextZip;
      _manualLocationName = locationName;
    });
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
        initialZip: _currentZip,
      ),
    );

    if (result == null || !mounted) return;
    _searchController.text = result.query;
    _openSearch(result.query);
  }

  Widget _buildHomeHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFF1B3C6E),
            Color(0xFF2E86AB),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Change service location: $_locationLabel',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openZipEntry,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              _locationLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Help and FAQs',
                onPressed: widget.onHelpTap,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.help,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              if (!widget.isGuest)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Inbox',
                      onPressed: widget.onInboxTap,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.mail,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    Positioned(
                      right: 9,
                      top: 9,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.orange500,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.navy700, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'What do you need done?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildHomeSearchBar(),
        ],
      ),
    );
  }

  Widget _buildHomeSearchBar() {
    void focusSearchField() {
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    return ServiceSearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onTap: focusSearchField,
      onSubmit: _openSearch,
      onPhotoTap: () => _openAiLayer('camera'),
      onVoiceTap: () => _openAiLayer('voice'),
      borderColor: const Color(0xFFDCE5F0),
      showShadow: true,
      emptyOverlay: Row(
        children: [
          Text(
            'Search a service ',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: _searchPlaceholderFontSize,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.1,
              height: 1,
            ),
          ),
          Expanded(
            child: SizedBox(
              height: _searchTickerHeight,
              child: PageView.builder(
                controller: _tickerPageController,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final serviceName =
                      _serviceNames[index % _serviceNames.length];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.navy700,
                        fontSize: _searchPlaceholderFontSize,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        height: 1,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseByCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Browse by category',
                style: TextStyle(
                  color: _inkStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => widget.onCategorySelected('All'),
              child: Text(
                'See all $_serviceCount ›',
                style: const TextStyle(
                  color: AppTheme.teal500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: _homeCategories.length + 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final isAll = index == _homeCategories.length;
            final label = isAll ? _allServicesLabel : _homeCategories[index];
            final token = isAll
                ? TradeWorksCategoryTokens.fallback
                : TradeWorksCategoryTokens.forName(label);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onCategorySelected(isAll ? 'All' : label),
              child: Container(
                decoration: BoxDecoration(
                  color: isAll
                      ? AppTheme.orange500
                      : _categoryBackgrounds[label] ?? AppTheme.navyTint,
                  borderRadius: BorderRadius.circular(12),
                  border: isAll ? null : Border.all(color: _lineSoft),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ServiceCategoryIcon(
                      category: isAll ? 'All' : label,
                      size: 32,
                      fallbackIcon:
                          isAll ? Icons.grid_view_rounded : token.icon,
                      fallbackColor: isAll ? Colors.white : _inkStrong,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isAll ? Colors.white : _inkStrong,
                        fontSize: 11,
                        fontWeight: isAll ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildForYourHomeCard() {
    if (!_hasBackendHomeDetails) {
      return _buildTailoredSuggestionsCard();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested for you',
            style: TextStyle(
              color: _inkStrong,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your AC is about 12 years old. Book a pre-summer tune-up to avoid a mid-July breakdown.',
            style: TextStyle(
              color: _inkStrong,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.43,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: _mutedText,
                fontSize: 11.5,
                height: 1.35,
              ),
              children: [
                TextSpan(text: 'Based on the install date on your AC · '),
                TextSpan(
                  text: 'Not right? Update',
                  style: TextStyle(
                    color: AppTheme.teal500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => widget.onCategorySelected('HVAC'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navy700,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.navy700, width: 1.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
            child: const Text(
              'Book a tune-up',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestSignupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign up',
          style: TextStyle(
            color: _inkStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.orange500),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CREATE YOUR ACCOUNT',
                style: TextStyle(
                  color: AppTheme.orange500,
                  fontSize: 11,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Create an account to book services, save your home details, earn rewards, and get personalized recommendations.',
                style: TextStyle(
                  color: _inkStrong,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'It only takes a minute to get started',
                style: TextStyle(color: _mutedText, fontSize: 11),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onCreateAccount,
                  child: const Text('Create account'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: widget.onSignIn,
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTailoredSuggestionsCard() {
    const cardFill = Color(0xFFF0F5FA);
    const cardBorder = Color(0xFF37537F);
    const eyebrowColor = Color(0xFF1B3C6E);
    const bodyColor = Color(0xFF506A91);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GET TAILORED SUGGESTIONS',
            style: TextStyle(
              color: eyebrowColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us about your home',
            style: TextStyle(
              color: _inkStrong,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Add your systems and their install dates, and we'll flag maintenance before it becomes a breakdown.",
            style: TextStyle(
              color: bodyColor,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onManageHomeTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: eyebrowColor,
                backgroundColor: cardFill,
                side: const BorderSide(color: eyebrowColor, width: 1.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: const Text(
                'Add your home details',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteReadyStrip(Map<String, dynamic> job, int totalCount) {
    final service = _text(
      job['serviceCategory'] ??
          job['service_category'] ??
          job['serviceName'] ??
          job['service_name'] ??
          job['title'],
      'Work order',
    );
    final proName = _text(
      job['pro']?['businessName'] ??
          job['pro']?['business_name'] ??
          job['businessName'] ??
          job['proName'],
      'Your pro',
    );
    final rawId = _text(job['workOrderId'] ?? job['id']);
    final idLabel = rawId.isEmpty
        ? ''
        : rawId.startsWith('TW-')
            ? ' · #$rawId'
            : ' · #TW-$rawId';
    final moreCount = totalCount - 1;

    return Material(
      color: const Color(0xFFFFF7ED),
      child: InkWell(
        onTap: () => widget.onJobTap(job),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.orange500),
              bottom: BorderSide(color: AppTheme.orange500),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppTheme.orange500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUOTE READY - REVIEW NOW',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.orange500,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _inkStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$proName$idLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (moreCount > 0)
                Text(
                  '+$moreCount more ›',
                  style: const TextStyle(
                    color: AppTheme.teal500,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.teal500,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _communityActivityCards {
    final jobs = <Map<String, dynamic>>[];
    for (final dynamic item in [
      ..._activeJobs,
      ..._upcomingJobs,
    ]) {
      if (item is Map) {
        jobs.add(Map<String, dynamic>.from(item));
      }
    }

    if (jobs.isEmpty) return const [];

    final cards = <Map<String, dynamic>>[];
    int neighborIndex = 0;
    for (final job in jobs) {
      final service = _text(job['serviceCategory'], 'Home service');
      final proName = _text(job['pro']?['businessName'], 'TradeWorks pro');
      final status = _statusOf(job);
      final city = _text(_defaultAddress?['city'], 'your area');
      final time = _formatRelativeTimestamp(
        job['timeline']?['enRouteAt'] ??
            job['timeline']?['acceptedAt'] ??
            job['createdAt'] ??
            job['scheduledStart'],
      );

      if (status == 'en_route') {
        cards.add({
          'type': 'trend',
          'primary': proName,
          'secondary': 'completed 4 jobs in your area this week.',
          'meta': 'Local demand is high for $service',
        });
      } else {
        final neighbor = neighborIndex == 0 ? 'Maria' : 'Lisa M.';
        final avatar = neighborIndex == 0 ? '🧑' : 'LM';
        cards.add({
          'type': 'neighbor',
          'neighbor': neighbor,
          'primary': proName,
          'avatar': avatar,
          'meta': '$time · $city',
        });
        neighborIndex += 1;
      }

      if (cards.length >= 3) break;
    }
    return cards;
  }

  Widget _buildCommunityActivitySection() {
    final cards = _communityActivityCards;
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Community Activity',
          style: TextStyle(
            color: _inkStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...cards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCommunityActivityCard(card),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityActivityCard(Map<String, dynamic> card) {
    final type = card['type'] as String? ?? 'neighbor';
    final iconBackground =
        type == 'trend' ? const Color(0xFFEFF6FF) : const Color(0xFFE2E8F0);
    final iconColor = AppTheme.navy700;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: type == 'trend'
                  ? Icon(Icons.trending_up_rounded, color: iconColor, size: 20)
                  : Text(
                      _text(card['avatar'], 'LM'),
                      style: const TextStyle(
                        color: _inkStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: _inkStrong,
                      fontSize: 14,
                      height: 1.43,
                    ),
                    children: _communityTextSpans(card),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  card['meta'] as String,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _communityTextSpans(Map<String, dynamic> card) {
    final type = card['type'] as String? ?? 'neighbor';
    if (type == 'trend') {
      return [
        TextSpan(
          text: _text(card['primary'], 'Gulf Coast Air'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(
            text:
                ' ${_text(card['secondary'], 'completed 4 jobs in your area this week.')}'),
      ];
    }

    return [
      const TextSpan(text: 'Your neighbor '),
      TextSpan(
        text: _text(card['neighbor'], 'Lisa M.'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      TextSpan(text: ' booked '),
      TextSpan(
        text: _text(card['primary'], 'Sunshine Cleaning'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const TextSpan(text: ' — rated '),
      const TextSpan(
        text: '5★',
        style: TextStyle(
          color: AppTheme.orange500,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SunriseBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: AppTheme.orange500),
                SizedBox(height: 12),
                Text(
                  'Loading your home',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SunriseBackground(
        child: SafeArea(
          child: OfflineState(
            onRetry: _fetchHomeData,
            title: AppErrorUtils.genericTitle,
            icon: Icons.cloud_off_rounded,
            message: _errorMessage,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_errorMessage != null) return _buildError();

    final quoteReadyJobs = _quoteReadyJobs;
    final quoteReadyJob = quoteReadyJobs.isEmpty ? null : quoteReadyJobs.first;

    return ColoredBox(
      color: _pageBackground,
      child: RefreshIndicator(
        onRefresh:
            widget.isGuest ? _loadSharedLocationOverride : _fetchHomeData,
        color: AppTheme.orange500,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _buildHomeHero(),
            if (!widget.isGuest && quoteReadyJob != null) ...[
              const SizedBox(height: 14),
              _buildQuoteReadyStrip(quoteReadyJob, quoteReadyJobs.length),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBrowseByCategorySection(),
                  const SizedBox(height: 16),
                  if (widget.isGuest)
                    _buildGuestSignupSection()
                  else ...[
                    const Text(
                      'For your home',
                      style: TextStyle(
                        color: _inkStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildForYourHomeCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

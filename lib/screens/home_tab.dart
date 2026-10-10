import '../widgets/loading_skeleton.dart';
import '../utils/arrival_check_state.dart';
import '../utils/work_order_status.dart';
import 'work_orders/arrival_check.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/stream_service.dart';
import '../ui/tw.dart';

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
import '../utils/waiting_on_you.dart';
import '../utils/work_order_labels.dart';
import '../widgets/alert_row.dart';
import '../widgets/app_notification.dart';
import '../widgets/service_zip_entry_dialog.dart';
import 'work_orders/cap_approval.dart';
import 'work_orders/work_order_detail.dart';

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

  static const Map<String, IconData> _homeCategoryIcons = {
    'HVAC': Icons.ac_unit_rounded,
    'Plumbing': Icons.water_drop_outlined,
    'Electrical': Icons.bolt_outlined,
    'Cleaning': Icons.auto_awesome_outlined,
    'Roofing': Icons.roofing_outlined,
    'Lawn': Icons.grass,
    'Handyman': Icons.build_outlined,
  };

  static const Color _pageBackground = AppTheme.pageBackground;
  static const Color _inkStrong = AppTheme.navy;
  static const Color _lineSoft = AppTheme.cardBorder;

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
  Map<String, dynamic> _serverHomeDetails = const {};
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

    _tickerPageController =
        PageController(initialPage: 1000 * _serviceNames.length);
    _serviceTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted ||
          !_tickerPageController.hasClients ||
          _searchController.text.trim().isNotEmpty ||
          _searchFocusNode.hasFocus) {
        return;
      }
      _tickerPageController.nextPage(
        duration: const Duration(milliseconds: 750),
        curve: Curves.fastOutSlowIn,
      );
    });

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
    _serviceTicker?.cancel();
    _tickerPageController.dispose();
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

  bool get _hasHomeContent =>
      _profile.isNotEmpty || _activeJobs.isNotEmpty || _upcomingJobs.isNotEmpty;

  Future<void> _restoreCachedHomeThenRefresh() async {
    if (widget.isGuest) return;
    final results = await Future.wait([
      HomeownerService.instance.loadCachedWorkOrders(),
      HomeownerService.instance.loadCachedProfile(),
      _loadServerHomeDetails(),
    ]);
    if (!mounted) return;

    final woData = results[0] as Map<String, dynamic>?;
    final profileData = results[1] as Map<String, dynamic>?;
    final serverHomeDetails = results[2] as Map<String, dynamic>;
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
        _serverHomeDetails = serverHomeDetails;
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
        _loadServerHomeDetails(),
      ]);

      final woData = results[0] as Map<String, dynamic>;
      final profileData = results[1] as Map<String, dynamic>;
      final serverHomeDetails = results[2] as Map<String, dynamic>;
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
        _serverHomeDetails = serverHomeDetails;
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

  Future<Map<String, dynamic>> _loadServerHomeDetails() async {
    try {
      final response = await HomeownerService.instance.fetchHomeProfiles();
      final addresses =
          (response['addresses'] as List? ?? []).whereType<Map>().toList();
      final defaults = addresses
          .where((a) => a['isDefault'] == true || a['is_default'] == true);
      final addressId = _defaultAddress?['id']?.toString() ??
          (defaults.isNotEmpty
                  ? defaults.first['id']
                  : addresses.isNotEmpty
                      ? addresses.first['id']
                      : null)
              ?.toString();
      if (addressId == null) return const {};
      for (final profile
          in (response['homeProfiles'] as List? ?? const []).whereType<Map>()) {
        if ('${profile['addressId']}' == addressId)
          return Map<String, dynamic>.from(profile);
      }
    } catch (_) {
      // An unavailable profile does not prevent loading bookings or Home.
    }
    return const {};
  }

  bool get _hasBackendHomeDetails {
    return _containsHomeDetails(_profile) ||
        _containsHomeDetails(_defaultAddress) ||
        _containsHomeDetails(_serverHomeDetails);
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
        'propertyDetails',
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

  bool _respondingToProposal = false;

  /// Everything on Home that is waiting on the homeowner (A01–A03): a pro's
  /// reschedule proposal, a cap or estimate at any non-terminal state, the
  /// receipt on a completed job (Oct 1, G-46). `_quoteSourceJobs` includes
  /// history, which the receipt needs.
  List<WaitingItem> get _waitingItems => WaitingOnYou.itemsFrom(
        _quoteSourceJobs.isEmpty
            ? <dynamic>[..._activeJobs, ..._upcomingJobs]
            : _quoteSourceJobs,
      );

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String get _displayedService {
    final typed = _searchController.text.trim();
    return typed.isNotEmpty ? typed : _serviceNames[_serviceTickerIndex];
  }

  String get _allServicesLabel => 'All 22';

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
      constraints: BoxConstraints(
        maxWidth: TwLayout.maxContent,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
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
    return Padding(
      padding: const EdgeInsets.only(top: TwSpace.s8),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
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
                            fit: FlexFit.loose,
                            child: Text(
                              _locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TwType.title().copyWith(fontSize: 15),
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
              ),
              const SizedBox(width: TwSpace.s4),
              _headerIcon(
                icon: Icons.help_outline_rounded,
                tooltip: 'Help and FAQs',
                onPressed: widget.onHelpTap,
              ),
              if (!widget.isGuest) _buildInboxButton(),
            ],
          ),
          const SizedBox(height: TwSpace.s12),
          Text('What do you need done?', style: TwType.h1(context)),
          const SizedBox(height: TwSpace.s16),
          _buildHomeSearchBar(),
        ],
      ),
    );
  }

  /// Outline icon 22 ink in a 44×44 target (A01 header).
  Widget _headerIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Icon(icon, color: AppTheme.navy, size: 22),
    );
  }

  /// Inbox icon with the A01 unread dot: 8px blue with a 2px white ring.
  /// Reads the chat client's own unread total (no new request); shows no dot
  /// until chat has connected.
  Widget _buildInboxButton() {
    final chatState = StreamService.instance.client?.state;
    return StreamBuilder<int>(
      stream: chatState?.totalUnreadCountStream,
      initialData: chatState?.totalUnreadCount ?? 0,
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? 0) > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _headerIcon(
              icon: Icons.mail_outline_rounded,
              tooltip: unread ? 'Inbox, unread messages' : 'Inbox',
              onPressed: widget.onInboxTap,
            ),
            if (unread)
              Positioned(
                top: 8,
                right: 7,
                child: IgnorePointer(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.white, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
      borderColor: AppTheme.border,
      showShadow: false,
      emptyOverlay: LayoutBuilder(
        builder: (context, constraints) {
          final prefixStyle =
              TwType.bodySm(color: AppTheme.body).copyWith(height: 1);
          bool fits(String label) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: prefixStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final fits = painter.width + 16 <= constraints.maxWidth;
            painter.dispose();
            return fits;
          }

          final prefix = fits('Search a service ')
              ? 'Search a service '
              : fits('Search ')
                  ? 'Search '
                  : '';
          return Row(
            children: [
              if (prefix.isNotEmpty)
                Text(prefix, maxLines: 1, style: prefixStyle),
              Expanded(
                child: SizedBox(
                  height: 20,
                  child: PageView.builder(
                    controller: _tickerPageController,
                    scrollDirection: Axis.vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        _serviceTickerIndex = index % _serviceNames.length,
                    itemBuilder: (context, index) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _serviceNames[index % _serviceNames.length],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TwType.bodySm(color: AppTheme.navy)
                            .copyWith(fontWeight: FontWeight.w500, height: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrowseByCategorySection() {
    final columns = TwLayout.columns(context);
    final tileHeight =
        MediaQuery.textScalerOf(context).scale(13) > 15 ? 88.0 : 76.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Browse by category', style: TwType.h2()),
            ),
            const SizedBox(width: TwSpace.s8),
            TextButton(
              onPressed: () => widget.onCategorySelected('All'),
              style: _linkStyle,
              child: Text('See all 22', style: TwType.link(size: 14)),
            ),
          ],
        ),
        const SizedBox(height: TwSpace.s8),
        GridView.builder(
          itemCount: _homeCategories.length + 1,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: TwSpace.s12,
            crossAxisSpacing: TwSpace.s8,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) {
            final isAll = index == _homeCategories.length;
            final label = isAll ? _allServicesLabel : _homeCategories[index];
            return Material(
              color: isAll ? AppTheme.subtle : AppTheme.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isAll
                    ? BorderSide.none
                    : const BorderSide(color: _lineSoft),
              ),
              child: InkWell(
                onTap: () => widget.onCategorySelected(isAll ? 'All' : label),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TwSpace.s4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAll
                            ? Icons.grid_view_outlined
                            : _homeCategoryIcons[label],
                        size: 24,
                        color: _inkStrong,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TwType.caption(color: _inkStrong).copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildForYourHomeCard() {
    if (!_hasBackendHomeDetails) return _buildTailoredSuggestionsCard();
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your home profile', style: TwType.h3()),
          const SizedBox(height: TwSpace.s8),
          Text(
            'Keep your property details, systems and documents together.',
            style: TwType.bodySm(),
          ),
          const SizedBox(height: TwSpace.s16),
          OutlinedButton(
            onPressed: widget.onManageHomeTap,
            child: const Text('View home profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestSignupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sign up', style: TwType.h2()),
        const SizedBox(height: TwSpace.s12),
        TwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create an account to book services, save your home details, earn rewards, and get personalized recommendations.',
                style: TwType.body(color: _inkStrong),
              ),
              const SizedBox(height: TwSpace.s8),
              Text(
                'It only takes a minute to get started',
                style: TwType.meta(),
              ),
              const SizedBox(height: TwSpace.s16),
              OutlinedButton(
                onPressed: widget.onCreateAccount,
                child: const Text('Create account'),
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
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tell us about your home', style: TwType.h3()),
          const SizedBox(height: TwSpace.s8),
          Text(
            "Keep a record of your systems, installation dates and documents for booked service visits.",
            style: TwType.bodySm(),
          ),
          const SizedBox(height: TwSpace.s16),
          OutlinedButton(
            onPressed: widget.onManageHomeTap,
            child: const Text('Add your home details'),
          ),
        ],
      ),
    );
  }

  /// Blue text action, left-aligned with the sentence above it.
  ButtonStyle get _linkStyle => TextButton.styleFrom(
        foregroundColor: AppTheme.blue,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: TwType.link(),
      );

  IconData _waitingIcon(WaitingKind kind) => switch (kind) {
        WaitingKind.reschedule => Icons.calendar_today_outlined,
        WaitingKind.cap => Icons.description_outlined,
        WaitingKind.estimate => Icons.description_outlined,
        WaitingKind.receipt => Icons.receipt_long_outlined,
      };

  /// One "Waiting on you" alert row for the first item and "+N more" for the
  /// rest (A01, A03). A pro's reschedule proposal is answered in place with
  /// Accept / Decline; until then the original window stands (Sep 30).
  Widget _buildWaitingStrip(List<WaitingItem> items) {
    final item = items.first;
    final more = items.length - 1;
    final moreLink = more > 0
        ? TextButton(
            onPressed: () => _showAllWaiting(items),
            style: _linkStyle,
            child: Text('+$more more'),
          )
        : null;

    final Widget footer;
    if (item.kind == WaitingKind.reschedule) {
      footer = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _respondingToProposal
                      ? null
                      : () => _respondToProposal(item, accept: true),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _respondingToProposal
                      ? null
                      : () => _respondToProposal(item, accept: false),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
          if (moreLink != null)
            Align(alignment: Alignment.centerRight, child: moreLink),
        ],
      );
    } else {
      footer = Row(
        children: [
          TextButton(
            onPressed: () => _openWaitingItem(item),
            style: _linkStyle,
            child: Text(item.action),
          ),
          const Spacer(),
          if (moreLink != null) moreLink,
        ],
      );
    }

    return AlertRow(
      icon: _waitingIcon(item.kind),
      eyebrow: const WaitingOnYouMark(),
      title: item.title,
      body: item.detail,
      footer: footer,
    );
  }

  /// A02: only while the job is still Booked after its window (Batch 19 B1).
  /// No pop-up — this row and the work order's button are the only prompts.
  Widget _buildNoShowRow(Map<String, dynamic> job) {
    final start = jobVisitStart(job);
    final line = [
      '${jobServiceName(job)} with ${jobProName(job, 'your pro')}',
      if (start != null)
        visitPhrase(start, jobVisitEnd(job), relativeDay: true),
      workOrderLabel(job),
    ].where((part) => part.isNotEmpty).join(' · ');
    return AlertRow(
      icon: Icons.schedule_rounded,
      title: 'Your visit window has passed',
      body: '$line. Not started by your pro.',
      footer: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          style: _linkStyle,
          onPressed: () async {
            if (await openArrivalCheck(context, job) && mounted) {
              await _fetchHomeData(showLoading: false, forceRefresh: true);
            }
          },
          child: const Text('Report a no-show'),
        ),
      ),
    );
  }

  Widget _buildProArrivalRow(Map<String, dynamic> job) => AlertRow(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppTheme.blue,
        tint: AppTheme.blueTint,
        title: '${jobProName(job, 'Your pro')} has arrived',
        body: '${jobServiceName(job)} · ${workOrderLabel(job)}',
        footer: TextButton(
          style: _linkStyle,
          onPressed: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => WorkOrderDetailScreen(job: job),
              ),
            );
            if (mounted) {
              await _fetchHomeData(showLoading: false, forceRefresh: true);
            }
          },
          child: const Text('View work order'),
        ),
      );

  /// Each item opens its own work order; a cap opens the cap screen, a
  /// receipt opens the work order at Job money.
  Future<void> _openWaitingItem(WaitingItem item) async {
    await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => item.kind == WaitingKind.cap
            ? CapApprovalScreen(job: item.job)
            : WorkOrderDetailScreen(
                job: item.job,
                focusMoney: item.kind == WaitingKind.receipt,
              ),
      ),
    );
    if (!mounted) return;
    await _fetchHomeData(showLoading: false, forceRefresh: true);
  }

  /// Accept / Decline a pro's proposed window. A decline (or no answer) keeps
  /// the original time (Sep 30). Needs backend G-28: `respond_reschedule`.
  Future<void> _respondToProposal(WaitingItem item,
      {required bool accept}) async {
    final id = workOrderDbId(item.job);
    if (id == null || _respondingToProposal) return;
    setState(() => _respondingToProposal = true);
    try {
      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: id,
        action: 'respond_reschedule',
        extra: {
          'response': accept ? 'accept' : 'decline',
          if (item.proposalId != null) 'proposalId': item.proposalId,
        },
      );
      if (!mounted) return;
      AppNotification.showSuccess(
        context,
        accept
            ? 'Your visit has moved to the new time.'
            : 'Your original time stands.',
      );
      await _fetchHomeData(showLoading: false, forceRefresh: true);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _respondingToProposal = false);
    }
  }

  /// "+N more": every waiting item as a hairline list; a row opens its job.
  Future<void> _showAllWaiting(List<WaitingItem> items) async {
    final picked = await TwSheet.show<WaitingItem>(
      context,
      builder: (sheetContext) {
        final gutter = TwLayout.gutter(sheetContext);
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding:
                EdgeInsets.fromLTRB(gutter, TwSpace.s8, gutter, TwSpace.s20),
            children: [
              Text('Waiting on you', style: TwType.h3()),
              const SizedBox(height: TwSpace.s8),
              for (var i = 0; i < items.length; i++)
                InkWell(
                  onTap: () => Navigator.pop(sheetContext, items[i]),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: i == items.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: _lineSoft)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].title, style: TwType.title()),
                              const SizedBox(height: TwSpace.s4),
                              Text(items[i].detail, style: TwType.meta()),
                            ],
                          ),
                        ),
                        const SizedBox(width: TwSpace.s8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) await _openWaitingItem(picked);
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SunriseBackground(
        child: SafeArea(
          child: const SkeletonPage(
            layout: SkeletonLayout.home,
            label: 'Loading your home',
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

    final waiting = widget.isGuest ? const <WaitingItem>[] : _waitingItems;
    final noShowJobs = widget.isGuest
        ? const <Map<String, dynamic>>[]
        : _quoteSourceJobs
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .where((job) => ArrivalCheckState.pending(job))
            .toList();
    final arrivedJobs = widget.isGuest
        ? const <Map<String, dynamic>>[]
        : _activeJobs
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .where(WorkOrderStatus.proOnSite)
            .toList();

    final alerts = <Widget>[
      for (final job in arrivedJobs) _buildProArrivalRow(job),
      for (final job in noShowJobs) _buildNoShowRow(job),
      if (waiting.isNotEmpty) _buildWaitingStrip(waiting),
    ];

    return ColoredBox(
      color: _pageBackground,
      child: RefreshIndicator(
        onRefresh:
            widget.isGuest ? _loadSharedLocationOverride : _fetchHomeData,
        color: AppTheme.navy,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.zero,
          children: [
            TwPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHomeHero(),
                  for (var i = 0; i < alerts.length; i++) ...[
                    SizedBox(height: i == 0 ? TwSpace.s20 : TwSpace.s12),
                    alerts[i],
                  ],
                  const SizedBox(height: TwSpace.s28),
                  _buildBrowseByCategorySection(),
                  const SizedBox(height: TwSpace.s28),
                  if (widget.isGuest)
                    _buildGuestSignupSection()
                  else ...[
                    Text('For your home', style: TwType.h2()),
                    const SizedBox(height: TwSpace.s12),
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

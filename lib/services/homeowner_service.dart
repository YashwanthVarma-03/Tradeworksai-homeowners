import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_error_utils.dart';
import 'api_config.dart';
import 'auth_service.dart';

class HomeownerService {
  static final HomeownerService instance = HomeownerService._internal();
  HomeownerService._internal();

  static const String _workOrdersListPath = 'homeowner/work-orders-list';
  static const String _legacyWorkOrdersListPath =
      'homeowner-work-orders-list-v2-supabase';
  static const String _workOrdersActionPath = 'homeowner/work-orders-action';
  static const String _legacyWorkOrdersActionPath =
      'homeowner-work-orders-action-v2-supabase';
  static const String _bookingCommitPath = 'homeowner/booking-commit';
  static const String _legacyBookingCommitPath = 'booking-commit-v2-supabase';
  static const String _reviewActionPath = 'homeowner/review-action';
  static const String _legacyReviewActionPath =
      'homeowner-review-action-v2-supabase';
  static const String _profilePath = 'homeowner/profile';
  static const String _legacyProfilePath = 'homeowner-profile-v2-supabase';
  static const String _rewardsPath = 'homeowner/rewards';
  static const String _legacyRewardsPath = 'homeowner-rewards-v2-supabase';
  static const String _verifyPath = 'homeowner/verify';
  static const String _legacyVerifyPath = 'homeowner-verify-v2-supabase';
  static const String _contractorProfilePath = 'public/contractor-profile-get';
  static const String _legacyContractorProfilePath =
      'public-contractor-profile-get-v2-supabase';
  static const String _contractorSearchPath = 'public/contractor-search';
  static const String _legacyContractorSearchPath =
      'public-contractor-search-v2-supabase';
  static const String _zipCoveragePath = 'public/zip-coverage-get';
  static const String _availabilityPath = 'contractor/availability-get';
  static const String _legacyAvailabilityPath =
      'contractor-availability-get-v2-supabase';

  // Live profile and address caches.
  List<dynamic>? _cachedAddresses;
  List<dynamic>? get cachedAddresses => _cachedAddresses;
  Map<String, dynamic>? _cachedProfile;
  DateTime? _cachedProfileAt;
  Future<Map<String, dynamic>>? _profileInFlight;
  Map<String, dynamic>? _cachedRewards;
  DateTime? _cachedRewardsAt;
  Future<Map<String, dynamic>>? _rewardsInFlight;
  Map<String, dynamic>? _cachedWorkOrdersResponse;
  DateTime? _cachedWorkOrdersAt;
  Future<Map<String, dynamic>>? _workOrdersInFlight;

  /// A lightweight app-wide signal emitted after the authenticated cache has
  /// been refreshed. Mounted tabs listen to this instead of independently
  /// polling or replacing their content with a loading state.
  final ValueNotifier<int> syncVersion = ValueNotifier<int>(0);

  /// Emitted whenever public contractor catalog data (ratings, review counts,
  /// availability or profile details) must be reloaded by Browse.
  final ValueNotifier<int> contractorCatalogVersion = ValueNotifier<int>(0);
  Future<void>? _backgroundSyncInFlight;
  String? _activeCacheUserId;
  final Map<int, Map<String, dynamic>> _reviewEligibilityCache = {};
  final Map<int, DateTime> _reviewEligibilityCacheAt = {};
  final Map<int, Future<Map<String, dynamic>>> _reviewEligibilityInFlight = {};
  final Map<int, Map<String, dynamic>> _reviewsByWorkOrder = {};
  Future<void>? _reviewsHydrationInFlight;

  /// Notifies booking surfaces when review history has been hydrated or
  /// changed, including immediately after an authenticated session starts.
  final ValueNotifier<int> reviewVersion = ValueNotifier<int>(0);
  final Map<String, Map<String, dynamic>> _contractorProfileCache = {};
  final Map<String, DateTime> _contractorProfileCacheAt = {};
  final Map<String, Future<Map<String, dynamic>>> _contractorProfileInFlight =
      {};
  final Map<String, Map<String, dynamic>> _searchProsCache = {};
  final Map<String, DateTime> _searchProsCacheAt = {};
  final Map<String, Map<String, dynamic>> _zipCoverageCache = {};
  final Map<String, DateTime> _zipCoverageCacheAt = {};
  final Map<String, Map<String, dynamic>> _availabilityCache = {};
  final Map<String, DateTime> _availabilityCacheAt = {};
  final Map<String, Future<Map<String, dynamic>>> _bookingCommitsInFlight = {};
  final Map<String, Map<String, dynamic>> _completedBookingCommits = {};
  SharedPreferences? _preferences;
  Future<SharedPreferences>? _preferencesInFlight;
  final Map<String, _RecentRequestFailure> _recentRequestFailures = {};
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _recentFailureCooldown = Duration(seconds: 5);
  static const String _persistentCachePrefix = 'homeowner_api_cache_v1_';
  static const Duration _profileCacheTtl = Duration(minutes: 10);
  static const Duration _workOrdersCacheTtl = Duration(minutes: 2);
  static const Duration _rewardsCacheTtl = Duration(minutes: 5);
  static const Duration _searchCacheTtl = Duration(minutes: 5);
  static const Duration _coverageCacheTtl = Duration(hours: 12);
  static const Duration _contractorProfileCacheTtl = Duration(hours: 1);
  static const Duration _availabilityCacheTtl = Duration(minutes: 1);
  static const Duration _offlineFallbackCacheTtl = Duration(days: 7);

  String _normalizeWorkOrderStatus(dynamic rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase() ?? '';
    if (status == 'cancelled') return 'canceled';
    if (status == 'booked') return 'scheduled';
    if (status == 'accepted') return 'active';
    return status;
  }

  Map<String, List<Map<String, dynamic>>> _groupWorkOrdersByTab(
      List<Map<String, dynamic>> jobs) {
    final active = <Map<String, dynamic>>[];
    final scheduled = <Map<String, dynamic>>[];
    final history = <Map<String, dynamic>>[];

    for (final original in jobs) {
      final job = Map<String, dynamic>.from(original);
      final status = _normalizeWorkOrderStatus(job['status']);
      job['status'] = status;

      if (status == 'scheduled') {
        scheduled.add(job);
        continue;
      }

      if (status == 'completed' || status == 'canceled') {
        history.add(job);
        continue;
      }

      active.add(job);
    }

    return {
      'active': active,
      'scheduled': scheduled,
      'history': history,
    };
  }

  Map<String, dynamic> _withNormalizedTabs(Map<String, dynamic> resp) {
    final normalized = Map<String, dynamic>.from(resp);
    final tabs = normalized['tabs'];

    if (tabs is Map<String, dynamic>) {
      normalized['tabs'] = {
        'active': ((tabs['active'] as List?) ?? const [])
            .map((job) => Map<String, dynamic>.from(job as Map))
            .map((job) {
          job['status'] = _normalizeWorkOrderStatus(job['status']);
          return job;
        }).toList(),
        'scheduled': ((tabs['scheduled'] as List?) ?? const [])
            .map((job) => Map<String, dynamic>.from(job as Map))
            .map((job) {
          job['status'] = _normalizeWorkOrderStatus(job['status']);
          return job;
        }).toList(),
        'history': ((tabs['history'] as List?) ?? const [])
            .map((job) => Map<String, dynamic>.from(job as Map))
            .map((job) {
          job['status'] = _normalizeWorkOrderStatus(job['status']);
          return job;
        }).toList(),
      };
    } else {
      final fallbackList = (normalized['workOrders'] as List?) ??
          (normalized['results'] as List?) ??
          (normalized['data'] as List?) ??
          const [];
      final jobs = fallbackList
          .whereType<Map>()
          .map((job) => Map<String, dynamic>.from(job))
          .toList();
      normalized['tabs'] = _groupWorkOrdersByTab(jobs);
    }

    final normalizedTabs = normalized['tabs'] as Map<String, dynamic>;
    normalized['activeWorkOrders'] = normalizedTabs['active'] ?? [];
    normalized['scheduledWorkOrders'] = normalizedTabs['scheduled'] ?? [];
    normalized['historyWorkOrders'] = normalizedTabs['history'] ?? [];
    return normalized;
  }

  String? _readRawString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String? _extractContractorIdFromNode(dynamic node) {
    if (node == null) return null;
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      for (final key in const [
        'contractorId',
        'contractor_id',
        'assignedContractorId',
        'assigned_contractor_id',
        'proId',
        'pro_id',
      ]) {
        final value = _readRawString(map[key]);
        if (value != null) {
          return value;
        }
      }

      for (final key in const [
        'pro',
        'contractor',
        'assignedContractor',
        'professional'
      ]) {
        final nestedNode = map[key];
        if (nestedNode is Map) {
          final nestedMap = Map<String, dynamic>.from(nestedNode);
          for (final nestedKey in const [
            'contractorId',
            'contractor_id',
            'id',
            'proId',
            'pro_id',
          ]) {
            final nestedValue = _readRawString(nestedMap[nestedKey]);
            if (nestedValue != null) {
              return nestedValue;
            }
          }
        }

        final nested = _extractContractorIdFromNode(nestedNode);
        if (nested != null) return nested;
      }

      for (final entry in map.entries) {
        if (const [
          'pro',
          'contractor',
          'assignedContractor',
          'professional',
        ].contains(entry.key)) {
          continue;
        }
        final nested = _extractContractorIdFromNode(entry.value);
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _extractContractorIdFromNode(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  String? _extractWorkOrderId(dynamic node) {
    if (node == null) return null;
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      for (final key in const ['workOrderId', 'id']) {
        final value = _readRawString(map[key]);
        if (value != null && RegExp(r'^\d+$').hasMatch(value)) {
          return value;
        }
      }
      for (final value in map.values) {
        final nested = _extractWorkOrderId(value);
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _extractWorkOrderId(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _extractAvailabilitySlots(
    Map<String, dynamic> data,
  ) {
    List<Map<String, dynamic>> asMaps(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return const [];
    }

    String? readSlotValue(Map<String, dynamic> slot, List<String> keys) {
      for (final key in keys) {
        final value = _readRawString(slot[key]);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    String? joinDateAndTime(String? date, String? time) {
      if (date == null || time == null) {
        return null;
      }
      final cleanedTime = time.contains('T') ? time.split('T').last : time;
      if (cleanedTime.isEmpty) {
        return null;
      }
      return '${date}T$cleanedTime';
    }

    final directSlots = [
      ...asMaps(data['slots']),
      ...asMaps(data['availability']),
      ...asMaps(data['windows']),
      ...asMaps(data['arrivalWindows']),
      ...asMaps(data['arrival_windows']),
      ...asMaps(data['results']),
    ];
    if (directSlots.isNotEmpty) {
      return directSlots
          .map((slot) {
            final date = readSlotValue(
              slot,
              const ['date', 'day', 'dateKey'],
            );
            final start = readSlotValue(slot, const [
                  'start',
                  'startsAt',
                  'starts_at',
                  'start_at',
                  'windowStart',
                  'window_start',
                  'startLocal',
                  'start_local',
                ]) ??
                joinDateAndTime(
                  date,
                  readSlotValue(slot, const ['startTime', 'start_time']),
                );
            final end = readSlotValue(slot, const [
                  'end',
                  'endsAt',
                  'ends_at',
                  'end_at',
                  'windowEnd',
                  'window_end',
                  'endLocal',
                  'end_local',
                ]) ??
                joinDateAndTime(
                  date,
                  readSlotValue(slot, const ['endTime', 'end_time']),
                );
            return {
              ...slot,
              if (start != null) 'start': start,
              if (end != null) 'end': end,
            };
          })
          .where((slot) => _readRawString(slot['start']) != null)
          .toList();
    }

    final dayGroups = [
      ...asMaps(data['days']),
      ...asMaps(data['availabilityDays']),
      ...asMaps(data['calendar']?['days']),
    ];
    if (dayGroups.isEmpty) {
      return const [];
    }

    final flattened = <Map<String, dynamic>>[];
    for (final day in dayGroups) {
      final date = _readRawString(day['date']) ??
          _readRawString(day['day']) ??
          _readRawString(day['dateKey']);
      final windows = [
        ...asMaps(day['slots']),
        ...asMaps(day['windows']),
        ...asMaps(day['availability']),
        ...asMaps(day['arrivalWindows']),
        ...asMaps(day['arrival_windows']),
        ...asMaps(day['timeWindows']),
        ...asMaps(day['time_windows']),
      ];
      for (final window in windows) {
        final start = readSlotValue(window, const [
              'start',
              'startsAt',
              'starts_at',
              'start_at',
              'windowStart',
              'window_start',
              'startLocal',
              'start_local',
            ]) ??
            joinDateAndTime(
              date,
              readSlotValue(window, const ['startTime', 'start_time']),
            );
        final end = readSlotValue(window, const [
              'end',
              'endsAt',
              'ends_at',
              'end_at',
              'windowEnd',
              'window_end',
              'endLocal',
              'end_local',
            ]) ??
            joinDateAndTime(
              date,
              readSlotValue(window, const ['endTime', 'end_time']),
            );
        if (start == null) {
          continue;
        }
        flattened.add({
          ...window,
          'start': start,
          if (end != null) 'end': end,
        });
      }
    }
    return flattened;
  }

  Future<String?> resolveContractorIdForWorkOrder(int workOrderId) async {
    final resp = await fetchWorkOrders();
    final tabs = resp['tabs'] as Map<String, dynamic>? ?? const {};
    final allJobs = <dynamic>[
      ...(tabs['active'] as List? ?? const []),
      ...(tabs['scheduled'] as List? ?? const []),
      ...(tabs['history'] as List? ?? const []),
    ];

    for (final job in allJobs) {
      if (job is Map) {
        final currentId = _extractWorkOrderId(job);
        if (currentId == workOrderId.toString()) {
          final contractorId = _extractContractorIdFromNode(job);
          if (contractorId != null) return contractorId;

          final slug = _readRawString(job['pro']?['slug']) ??
              _readRawString(job['contractor']?['slug']) ??
              _readRawString(job['contractorSlug']) ??
              _readRawString(job['contractor_slug']) ??
              _readRawString(job['proSlug']) ??
              _readRawString(job['pro_slug']) ??
              _readRawString(job['slug']);
          if (slug != null && slug.isNotEmpty) {
            try {
              final profile = await getContractorProfile(slug);
              final profileId = _extractContractorIdFromNode(profile);
              if (profileId != null) return profileId;
            } catch (_) {}

            // Fallback lookup using searchPros API since contractorId is not returned in contractor profile details
            final zip = _readRawString(job['address']?['zip']) ??
                _readRawString(job['address']?['zipCode']) ??
                _readRawString(job['address_zip']) ??
                _readRawString(job['zip']);
            final categoryRaw = _readRawString(job['serviceCategory']) ??
                _readRawString(job['service_category']) ??
                _readRawString(job['category']) ??
                '';
            if (zip != null && zip.isNotEmpty) {
              // Try common categories in priority order based on mapped category
              final categoriesToTry = ['hvac', 'plumbing', 'electrical'];
              final lowerCat = categoryRaw.toLowerCase();
              String primaryCat = lowerCat;
              if (lowerCat.contains('hvac') ||
                  lowerCat.contains('ac') ||
                  lowerCat.contains('air') ||
                  lowerCat.contains('heat') ||
                  lowerCat.contains('cool')) {
                primaryCat = 'hvac';
              } else if (lowerCat.contains('plumb') ||
                  lowerCat.contains('leak') ||
                  lowerCat.contains('water') ||
                  lowerCat.contains('drain') ||
                  lowerCat.contains('pipe')) {
                primaryCat = 'plumbing';
              } else if (lowerCat.contains('electr') ||
                  lowerCat.contains('light') ||
                  lowerCat.contains('wire') ||
                  lowerCat.contains('outlet')) {
                primaryCat = 'electrical';
              }

              if (categoriesToTry.contains(primaryCat)) {
                categoriesToTry.remove(primaryCat);
                categoriesToTry.insert(0, primaryCat);
              }

              for (final catSlug in categoriesToTry) {
                try {
                  final searchResult = await searchPros(
                    zip: zip,
                    categorySlug: catSlug,
                  );
                  final results = searchResult['results'] as List?;
                  if (results != null) {
                    for (final res in results) {
                      if (res is Map) {
                        final resSlug = _readRawString(res['slug']);
                        if (resSlug == slug) {
                          final resolvedId =
                              _readRawString(res['contractorId']) ??
                                  _readRawString(res['contractor_id']) ??
                                  _readRawString(res['id']);
                          if (resolvedId != null) {
                            return resolvedId;
                          }
                        }
                      }
                    }
                  }
                } catch (_) {}
              }
            }
          }
        }
      }
    }
    return null;
  }

  String? get _userId {
    final currentUserId = AuthService.instance.userId;
    if (currentUserId != _activeCacheUserId) {
      _clearAuthenticatedMemory();
      _activeCacheUserId = currentUserId;
    }
    return currentUserId;
  }

  void _clearAuthenticatedMemory() {
    _cachedProfile = null;
    _cachedProfileAt = null;
    _profileInFlight = null;
    _cachedRewards = null;
    _cachedRewardsAt = null;
    _rewardsInFlight = null;
    _cachedWorkOrdersResponse = null;
    _cachedWorkOrdersAt = null;
    _workOrdersInFlight = null;
    _backgroundSyncInFlight = null;
    _cachedAddresses = null;
    _reviewEligibilityCache.clear();
    _reviewEligibilityCacheAt.clear();
    _reviewEligibilityInFlight.clear();
    _reviewsByWorkOrder.clear();
    _reviewsHydrationInFlight = null;
    _bookingCommitsInFlight.clear();
    _completedBookingCommits.clear();
  }

  Future<SharedPreferences> _getPreferences() {
    final existing = _preferences;
    if (existing != null) return Future.value(existing);
    return _preferencesInFlight ??=
        SharedPreferences.getInstance().then((prefs) {
      _preferences = prefs;
      return prefs;
    });
  }

  String _persistentCacheKey(String resource) {
    final userScope = _userId?.trim().isNotEmpty == true ? _userId! : 'public';
    return '$_persistentCachePrefix$userScope:$resource';
  }

  Future<Map<String, dynamic>?> _readPersistentCache(
    String resource,
    Duration maxAge,
  ) async {
    final prefs = await _getPreferences();
    final key = _persistentCacheKey(resource);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = decoded['savedAt'] as int?;
      final data = decoded['data'];
      if (savedAt == null || data is! Map) return null;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (age > maxAge || age.isNegative) {
        await prefs.remove(key);
        return null;
      }
      return Map<String, dynamic>.from(data);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> _writePersistentCache(
    String resource,
    Map<String, dynamic> data,
  ) async {
    final prefs = await _getPreferences();
    await prefs.setString(
      _persistentCacheKey(resource),
      jsonEncode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }),
    );
  }

  /// Restores user-scoped data from disk for immediate launch rendering.
  /// Callers must refresh in the background after using these fallbacks.
  Future<Map<String, dynamic>?> loadCachedWorkOrders() async {
    if (_userId == null) return null;
    final cached = await _readPersistentCache(
      'work-orders',
      _offlineFallbackCacheTtl,
    );
    return cached == null ? null : _withNormalizedTabs(cached);
  }

  Future<Map<String, dynamic>?> loadCachedProfile() async {
    if (_userId == null) return null;
    return _readPersistentCache('profile', _offlineFallbackCacheTtl);
  }

  Future<Map<String, dynamic>?> loadCachedRewards() async {
    if (_userId == null) return null;
    return _readPersistentCache('rewards', _offlineFallbackCacheTtl);
  }

  /// Refreshes the user-scoped cache without making a screen wait for it.
  /// Concurrent callers intentionally share one network pass.
  Future<void> syncInBackground() {
    if (_userId == null) return Future.value();
    final pending = _backgroundSyncInFlight;
    if (pending != null) return pending;

    final refresh = _refreshAuthenticatedCache();
    _backgroundSyncInFlight = refresh;
    return refresh;
  }

  Future<void> _refreshAuthenticatedCache() async {
    try {
      Map<String, dynamic>? workOrders;
      final refreshed = await Future.wait([
        _refreshResource(() => fetchProfile(forceRefresh: true)),
        _refreshResource(() async {
          workOrders = await fetchWorkOrders(forceRefresh: true);
          return workOrders!;
        }),
        _refreshResource(() => fetchRewards(forceRefresh: true)),
      ]);
      if (workOrders != null) {
        await hydrateReviewsFromWorkOrders(workOrders!);
      }
      if (refreshed.any((didRefresh) => didRefresh)) {
        syncVersion.value++;
      }
    } catch (_) {
      // Keep the last successful snapshot visible during an intermittent
      // connection failure. The next lifecycle or scheduled refresh retries.
    } finally {
      _backgroundSyncInFlight = null;
    }
  }

  Future<bool> _refreshResource(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      await request();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Emits a cross-tab update for a local/demo mutation whose state is already
  /// held in memory.
  void notifyLocalDataChanged() {
    syncVersion.value++;
  }

  /// Preloads the authenticated home experience once per shell lifetime.
  /// Request coalescing ensures simultaneous tabs share the same requests.
  Future<void> primeAuthenticatedCache() => syncInBackground();

  Future<void> _removePersistentCache(String resource) async {
    final prefs = await _getPreferences();
    await prefs.remove(_persistentCacheKey(resource));
  }

  Future<void> _removePersistentCacheGroup(String resourcePrefix) async {
    final prefs = await _getPreferences();
    final keyPrefix = _persistentCacheKey(resourcePrefix);
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(keyPrefix))
        .toList(growable: false);
    await Future.wait(keys.map(prefs.remove));
  }

  Future<void> _invalidateProfileCache() async {
    _cachedProfile = null;
    _cachedProfileAt = null;
    await _removePersistentCache('profile');
  }

  Future<void> _invalidateWorkOrderCache() async {
    _cachedWorkOrdersResponse = null;
    _cachedWorkOrdersAt = null;
    await _removePersistentCache('work-orders');
  }

  Future<void> _invalidateRewardsCache() async {
    _cachedRewards = null;
    _cachedRewardsAt = null;
    await _removePersistentCache('rewards');
  }

  Future<void> _invalidateAvailabilityCache() async {
    _availabilityCache.clear();
    _availabilityCacheAt.clear();
    await _removePersistentCacheGroup('availability:');
  }

  Future<void> _invalidateContractorProfileCache() async {
    _contractorProfileCache.clear();
    _contractorProfileCacheAt.clear();
    _contractorProfileInFlight.clear();
    await _removePersistentCacheGroup('contractor-profile:');
  }

  Future<void> _invalidateContractorSearchCache() async {
    _searchProsCache.clear();
    _searchProsCacheAt.clear();

    // Search results can be saved under either the signed-in homeowner or the
    // public visitor scope. A new public review affects both views.
    final prefs = await _getPreferences();
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_persistentCachePrefix) &&
              key.contains(':search:'),
        )
        .toList(growable: false);
    await Future.wait(keys.map(prefs.remove));
  }

  void _notifyContractorCatalogChanged() {
    contractorCatalogVersion.value++;
  }

  void _invalidateReviewEligibilityCache([int? workOrderId]) {
    if (workOrderId != null) {
      _reviewEligibilityCache.remove(workOrderId);
      _reviewEligibilityCacheAt.remove(workOrderId);
      _reviewEligibilityInFlight.remove(workOrderId);
      return;
    }
    _reviewEligibilityCache.clear();
    _reviewEligibilityCacheAt.clear();
    _reviewEligibilityInFlight.clear();
  }

  Future<Map<String, String>> _jsonHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = AuthService.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _postRaw(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = await _jsonHeaders();
    return http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
  }

  void _throwIfRecentFailure(String endpoint) {
    final recent = _recentRequestFailures[endpoint];
    if (recent == null) return;
    if (DateTime.now().difference(recent.at) >= _recentFailureCooldown) {
      _recentRequestFailures.remove(endpoint);
      return;
    }
    throw Exception(recent.message);
  }

  void _cacheRecentFailure(
    String endpoint,
    Object error, {
    String? fallbackMessage,
  }) {
    final raw = error.toString().toLowerCase();
    final shouldCache = AppErrorUtils.isNetworkError(error) ||
        raw.contains('empty response') ||
        raw.contains('returned an empty response') ||
        raw.contains('got an empty response');
    if (!shouldCache) {
      return;
    }
    _recentRequestFailures[endpoint] = _RecentRequestFailure(
      at: DateTime.now(),
      message: AppErrorUtils.friendlyMessage(
        error,
        fallback: fallbackMessage ?? AppErrorUtils.genericMessage,
      ),
    );
  }

  void _clearRecentFailure(String endpoint) {
    _recentRequestFailures.remove(endpoint);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    String? fallbackEndpoint,
  }) async {
    _throwIfRecentFailure(endpoint);
    try {
      http.Response response;
      try {
        response = await _postRaw(endpoint, body);
      } catch (primaryError) {
        if (fallbackEndpoint == null ||
            !AppErrorUtils.isNetworkError(primaryError)) {
          rethrow;
        }
        response = await _postRaw(fallbackEndpoint, body);
      }

      if (fallbackEndpoint != null && _shouldUseFallbackEndpoint(response)) {
        response = await _postRaw(fallbackEndpoint, body);
      }

      if (response.body.isEmpty) {
        throw Exception(ApiConfig.emptyResponseMessage(endpoint));
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format.');
      }

      if (_isAuthenticationFailure(response.statusCode, data)) {
        // Public surfaces may receive an auth response while a visitor has no
        // session. Do not turn that into a Supabase local sign-out or noisy
        // browser log; only invalidate a session that actually exists.
        if (AuthService.instance.isAuthenticated) {
          await AuthService.instance.invalidateSession();
          throw Exception('Your session has expired. Please sign in again.');
        }
        throw Exception('Please sign in to continue.');
      }

      if (response.statusCode >= 400) {
        final error = data['error'] ??
            data['reason'] ??
            data['message'] ??
            'Request failed (${response.statusCode})';
        throw Exception(error);
      }

      final success = (data['success'] != false && data['ok'] != false);

      if (!success) {
        final error = data['error'] ??
            data['reason'] ??
            data['message'] ??
            'Action failed';
        throw Exception(error);
      }

      _clearRecentFailure(endpoint);
      if (fallbackEndpoint != null) {
        _clearRecentFailure(fallbackEndpoint);
      }
      return data;
    } catch (e) {
      _cacheRecentFailure(endpoint, e);
      if (fallbackEndpoint != null) {
        _cacheRecentFailure(fallbackEndpoint, e);
      }
      rethrow;
    }
  }

  /// Some deployed API generations return a successful HTTP status with an
  /// application-level `not_found` or `server_error` payload. Treat those the
  /// same as an HTTP 404/5xx and use the maintained legacy endpoint when one
  /// is available, instead of exposing a transient backend route mismatch.
  bool _shouldUseFallbackEndpoint(http.Response response) {
    if (response.statusCode == 404 || response.statusCode >= 500) {
      return true;
    }
    if (response.body.isEmpty) return false;

    try {
      final data = jsonDecode(response.body);
      if (data is! Map) return false;
      if (data['success'] != false && data['ok'] != false) return false;
      final detail = [data['error'], data['reason'], data['message']]
          .whereType<Object>()
          .join(' ')
          .toLowerCase();
      return detail.contains('not_found') ||
          detail.contains('not found') ||
          detail.contains('server_error') ||
          detail.contains('internal server error');
    } catch (_) {
      return false;
    }
  }

  bool _isAuthenticationFailure(
    int statusCode,
    Map<String, dynamic> response,
  ) {
    if (statusCode == 401) return true;

    final detail = [
      response['error'],
      response['reason'],
      response['message'],
    ].whereType<Object>().join(' ').toLowerCase();
    return detail.contains('unauthenticated') ||
        detail.contains('unauthorized') ||
        detail.contains('invalid jwt') ||
        detail.contains('jwt expired') ||
        detail.contains('expired token');
  }

  // H1: Fetch Work Orders
  Future<Map<String, dynamic>> fetchWorkOrders(
      {bool forceRefresh = false}) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final inFlight = _workOrdersInFlight;
    if (inFlight != null) return inFlight;

    final cached = _cachedWorkOrdersResponse;
    final cachedAt = _cachedWorkOrdersAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _workOrdersCacheTtl) {
      return cached;
    }

    if (!forceRefresh) {
      final persistent = await _readPersistentCache(
        'work-orders',
        _offlineFallbackCacheTtl,
      );
      if (persistent != null) {
        final normalized = _withNormalizedTabs(persistent);
        _cachedWorkOrdersResponse = normalized;
        _cachedWorkOrdersAt = DateTime.now();
        return normalized;
      }
    }

    final future = _post(
      _workOrdersListPath,
      {'userId': uid},
      fallbackEndpoint: _legacyWorkOrdersListPath,
    ).then(_withNormalizedTabs);
    _workOrdersInFlight = future;
    try {
      final resp = await future;
      if (_userId != uid) {
        throw Exception('The signed-in user changed during this request.');
      }
      _cachedWorkOrdersResponse = resp;
      _cachedWorkOrdersAt = DateTime.now();
      await _writePersistentCache('work-orders', resp);
      return resp;
    } finally {
      _workOrdersInFlight = null;
    }
  }

  // H2: Work Order Action
  // Actions: confirm_complete, propose_reschedule, respond_reschedule, raise_dispute, pro_no_show, cancel
  Future<Map<String, dynamic>> performWorkOrderAction({
    required int workOrderId,
    required String action,
    Map<String, dynamic>? extra,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final body = {
      'action': action,
      'workOrderId': workOrderId,
      'requesterUserId': uid,
      'requester_user_id': uid,
      ...?extra,
    };
    final result = await _post(
      _workOrdersActionPath,
      body,
      fallbackEndpoint: _legacyWorkOrdersActionPath,
    );
    await _invalidateWorkOrderCache();
    unawaited(syncInBackground());
    return result;
  }

  // H3: homeowner approves or declines the cap.
  // Keep quote_accept/quote_decline: the backend still expects these wire values.
  Future<Map<String, dynamic>> respondToCap({
    required int workOrderId,
    required bool accept,
    String? startsAt,
    String? endsAt,
    String? contractorId,
    String? reason,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');
    final Map<String, dynamic> body;
    if (accept) {
      body = {
        'action': 'quote_accept',
        'workOrderId': workOrderId,
        'startsAt': startsAt,
        'endsAt': endsAt,
        'requesterUserId': uid,
        'requester_user_id': uid,
        'contractorId': contractorId,
      };
    } else {
      body = {
        'action': 'quote_decline',
        'workOrderId': workOrderId,
        'requesterUserId': uid,
        'requester_user_id': uid,
        'reason': reason,
      };
    }
    final result = await _post(
      _bookingCommitPath,
      body,
      fallbackEndpoint: _legacyBookingCommitPath,
    );
    await _invalidateWorkOrderCache();
    unawaited(syncInBackground());
    return result;
  }

  Future<Map<String, dynamic>> submitReview({
    required int workOrderId,
    required double rating,
    required String text,
    String? displayName,
  }) async {
    if (_userId == null) throw Exception('User is not authenticated');
    final ratingInt = rating.round().clamp(1, 5).toInt();

    final body = {
      'action': 'submit_review',
      'workOrderId': workOrderId,
      'requesterUserId': _userId,
      'requester_user_id': _userId,
      'rating': ratingInt,
      'text': text,
      if (displayName != null) 'displayName': displayName,
    };
    final result = await _post(
      _reviewActionPath,
      body,
      fallbackEndpoint: _legacyReviewActionPath,
    );
    _cacheReview(workOrderId, {
      'rating': ratingInt.toDouble(),
      'reviewText': text,
      'displayName': displayName,
      'reviewed': true,
      'reviewId': result['reviewId'],
      'published': result['published'],
    });
    await _invalidateWorkOrderCache();
    _invalidateReviewEligibilityCache(workOrderId);
    await _invalidateContractorProfileCache();
    await _invalidateContractorSearchCache();
    await _invalidateRewardsCache();
    _notifyContractorCatalogChanged();
    unawaited(syncInBackground());
    return result;
  }

  Map<String, dynamic>? cachedReviewForWorkOrder(int workOrderId) {
    final review = _reviewsByWorkOrder[workOrderId];
    return review == null ? null : Map<String, dynamic>.from(review);
  }

  Map<int, Map<String, dynamic>> get cachedReviewsByWorkOrder => {
        for (final entry in _reviewsByWorkOrder.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      };

  void rememberReviewedWorkOrder(int workOrderId) {
    _cacheReview(workOrderId, const {
      'rating': 0.0,
      'reviewText': '',
      'reviewed': true,
      'detailsAvailable': false,
    });
  }

  void _cacheReview(int workOrderId, Map<String, dynamic> review) {
    if (workOrderId <= 0) return;
    final normalized = Map<String, dynamic>.from(review)..['reviewed'] = true;
    final previous = _reviewsByWorkOrder[workOrderId];
    if (mapEquals(previous, normalized)) return;
    _reviewsByWorkOrder[workOrderId] = normalized;
    reviewVersion.value++;
  }

  /// Hydrates the homeowner's submitted reviews as part of login/session
  /// priming. Embedded work-order reviews are used first, followed by one
  /// authenticated Supabase batch read. Eligibility is the final fallback so
  /// already-reviewed work orders never render an invalid review action.
  Future<void> hydrateReviewsFromWorkOrders(
    Map<String, dynamic> workOrdersResponse,
  ) {
    final pending = _reviewsHydrationInFlight;
    if (pending != null) return pending;

    final hydration = _hydrateReviewsFromWorkOrders(workOrdersResponse);
    _reviewsHydrationInFlight = hydration;
    return hydration.whenComplete(() {
      if (identical(_reviewsHydrationInFlight, hydration)) {
        _reviewsHydrationInFlight = null;
      }
    });
  }

  Future<void> _hydrateReviewsFromWorkOrders(
    Map<String, dynamic> workOrdersResponse,
  ) async {
    if (_userId == null) return;
    final tabs = workOrdersResponse['tabs'];
    if (tabs is! Map) return;

    final completed = <int, Map<String, dynamic>>{};
    for (final section in const ['active', 'scheduled', 'history']) {
      for (final raw in tabs[section] as List? ?? const []) {
        if (raw is! Map) continue;
        final job = Map<String, dynamic>.from(raw);
        final status = _normalizeWorkOrderStatus(job['status']);
        final timeline = job['timeline'];
        final isCompleted = status == 'completed' ||
            status == 'complete' ||
            (timeline is Map && timeline['completedAt'] != null);
        final id = _workOrderId(job);
        if (isCompleted && id > 0) completed[id] = job;
      }
    }
    if (completed.isEmpty) return;

    for (final entry in completed.entries) {
      final embedded = _reviewFromWorkOrder(entry.value);
      if (embedded != null) _cacheReview(entry.key, embedded);
    }

    var unresolved = completed.keys
        .where((id) => !_reviewsByWorkOrder.containsKey(id))
        .toList(growable: false);
    if (unresolved.isEmpty) return;

    try {
      final rows = await Supabase.instance.client
          .from('contractor_reviews')
          .select(
            'id,work_order_id,rating,review_text,reviewer_name,review_date,is_active',
          )
          .inFilter('work_order_id', unresolved);
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final workOrderId =
            int.tryParse(row['work_order_id']?.toString() ?? '');
        if (workOrderId == null) continue;
        _cacheReview(workOrderId, _normalizeReview(row));
      }
    } catch (_) {
      // Some environments intentionally restrict direct review-table reads.
      // Eligibility still gives us a reliable reviewed/not-reviewed state.
    }

    unresolved = completed.keys
        .where((id) => !_reviewsByWorkOrder.containsKey(id))
        .toList(growable: false);
    const batchSize = 6;
    for (var start = 0; start < unresolved.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, unresolved.length).toInt();
      await Future.wait(unresolved.sublist(start, end).map((workOrderId) async {
        try {
          final eligibility =
              await getReviewEligibility(workOrderId: workOrderId);
          if (eligibility['eligible'] == false &&
              eligibility['reason']?.toString() == 'already_reviewed') {
            _cacheReview(workOrderId, const {
              'rating': 0.0,
              'reviewText': '',
              'reviewed': true,
              'detailsAvailable': false,
            });
          }
        } catch (_) {
          // Leave the review action available when status cannot be verified.
        }
      }));
    }
  }

  int _workOrderId(Map<String, dynamic> job) {
    for (final key in const ['workOrderId', 'work_order_id', 'id']) {
      final parsed = int.tryParse(job[key]?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  Map<String, dynamic>? _reviewFromWorkOrder(Map<String, dynamic> job) {
    Map<String, dynamic>? nested(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is List) {
        for (final item in value) {
          if (item is Map) return Map<String, dynamic>.from(item);
        }
      }
      return null;
    }

    final review = nested(job['review']) ??
        nested(job['homeownerReview']) ??
        nested(job['homeowner_review']) ??
        nested(job['reviews']);
    final rating = job['rating'] ?? review?['rating'] ?? review?['score'];
    final text = job['reviewText'] ??
        job['review_text'] ??
        review?['text'] ??
        review?['reviewText'] ??
        review?['review_text'] ??
        review?['comment'] ??
        review?['content'] ??
        review?['message'];
    final reviewed = job['reviewed'] == true || review != null;
    if (!reviewed && rating == null && text == null) return null;

    return _normalizeReview({
      ...?review,
      'rating': rating,
      'review_text': text,
      'reviewed': true,
    });
  }

  Map<String, dynamic> _normalizeReview(Map<String, dynamic> source) {
    final rawRating = source['rating'] ?? source['score'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '') ?? 0.0;
    return {
      'reviewed': true,
      'rating': rating,
      'reviewText': (source['reviewText'] ??
              source['review_text'] ??
              source['text'] ??
              source['comment'] ??
              '')
          .toString(),
      'displayName': source['displayName'] ??
          source['display_name'] ??
          source['reviewer_name'],
      'reviewDate':
          source['reviewDate'] ?? source['review_date'] ?? source['created_at'],
      'reviewId': source['reviewId'] ?? source['review_id'] ?? source['id'],
      if (source.containsKey('is_active'))
        'published': source['is_active'] == true,
      'detailsAvailable': rating > 0 ||
          (source['reviewText'] ??
                  source['review_text'] ??
                  source['text'] ??
                  source['comment'] ??
                  '')
              .toString()
              .trim()
              .isNotEmpty,
    };
  }

  Future<Map<String, dynamic>> getReviewEligibility({
    required int workOrderId,
  }) async {
    if (_userId == null) throw Exception('User is not authenticated');

    final cached = _reviewEligibilityCache[workOrderId];
    final cachedAt = _reviewEligibilityCacheAt[workOrderId];
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 5)) {
      return cached;
    }

    final inFlight = _reviewEligibilityInFlight[workOrderId];
    if (inFlight != null) return inFlight;

    final future = _post(
      _reviewActionPath,
      {
        'action': 'get_review_eligibility',
        'workOrderId': workOrderId,
        'requesterUserId': _userId,
        'requester_user_id': _userId,
      },
      fallbackEndpoint: _legacyReviewActionPath,
    );
    _reviewEligibilityInFlight[workOrderId] = future;
    try {
      final resp = await future;
      _reviewEligibilityCache[workOrderId] = resp;
      _reviewEligibilityCacheAt[workOrderId] = DateTime.now();
      return resp;
    } finally {
      _reviewEligibilityInFlight.remove(workOrderId);
    }
  }

  Future<Map<String, dynamic>> getContractorProfile(String slug) async {
    try {
      final resource = 'contractor-profile:${Uri.encodeComponent(slug)}';
      final cached = _contractorProfileCache[slug];
      final cachedAt = _contractorProfileCacheAt[slug];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _contractorProfileCacheTtl) {
        return cached;
      }

      final inFlight = _contractorProfileInFlight[slug];
      if (inFlight != null) return inFlight;

      final persistent = await _readPersistentCache(
        resource,
        _contractorProfileCacheTtl,
      );
      if (persistent != null) {
        _contractorProfileCache[slug] = persistent;
        _contractorProfileCacheAt[slug] = DateTime.now();
        return persistent;
      }

      final future = () async {
        var response = await _postRaw(_contractorProfilePath, {'slug': slug});
        if (response.statusCode == 404) {
          response =
              await _postRaw(_legacyContractorProfilePath, {'slug': slug});
        }
        if (response.body.isEmpty) throw Exception('Empty response');
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) throw Exception('Invalid response');
        if (data['success'] == false || data['ok'] == false) {
          throw Exception(
            data['error'] ??
                data['reason'] ??
                data['message'] ??
                'Failed to load profile.',
          );
        }
        return data;
      }();
      _contractorProfileInFlight[slug] = future;
      final data = await future;
      _contractorProfileCache[slug] = data;
      _contractorProfileCacheAt[slug] = DateTime.now();
      await _writePersistentCache(resource, data);
      return data;
    } catch (e) {
      throw Exception('Failed to load profile.');
    } finally {
      _contractorProfileInFlight.remove(slug);
    }
  }

  // H4: Contractor availability
  Future<Map<String, dynamic>> getContractorAvailability({
    required String contractorId,
    String? serviceId,
    String urgency = 'standard',
    required String fromDate,
    required String toDate,
    String? propertyZip,
    int? durationMinutes,
    String? serviceName,
    String? serviceCategory,
    String? workOrderType,
  }) async {
    final identity = [
      contractorId,
      serviceId ?? '',
      urgency,
      fromDate,
      toDate,
      propertyZip ?? '',
      durationMinutes?.toString() ?? '',
      serviceName ?? '',
      serviceCategory ?? '',
      workOrderType ?? '',
    ].join('|');
    final resource = 'availability:${Uri.encodeComponent(identity)}';
    final cached = _availabilityCache[identity];
    final cachedAt = _availabilityCacheAt[identity];
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _availabilityCacheTtl) {
      return cached;
    }
    final persistent =
        await _readPersistentCache(resource, _availabilityCacheTtl);
    if (persistent != null) {
      _availabilityCache[identity] = persistent;
      _availabilityCacheAt[identity] = DateTime.now();
      return persistent;
    }

    try {
      final payload = {
        'contractorId': contractorId,
        if (serviceId != null && serviceId.isNotEmpty) 'serviceId': serviceId,
        'urgency': urgency,
        'fromDate': fromDate,
        'toDate': toDate,
        if (propertyZip != null && propertyZip.isNotEmpty)
          'propertyZip': propertyZip,
        if (durationMinutes != null && durationMinutes > 0)
          'durationMinutes': durationMinutes,
        if (serviceName != null && serviceName.isNotEmpty)
          'serviceName': serviceName,
        if (serviceCategory != null && serviceCategory.isNotEmpty)
          'serviceCategory': serviceCategory,
        if (workOrderType != null && workOrderType.isNotEmpty)
          'workOrderType': workOrderType,
      };
      late http.Response response;
      try {
        response = await _postRaw(_availabilityPath, payload);
      } catch (error) {
        // Availability is public and has a maintained legacy route. A
        // temporary failure on the newer route must not block booking.
        if (!AppErrorUtils.isNetworkError(error)) rethrow;
        response = await _postRaw(_legacyAvailabilityPath, payload);
      }
      // The hosted API has two route generations. The newer route can return
      // a transient server/auth failure even though the public legacy function
      // is healthy, so use it as a genuine fallback for public availability.
      if (_shouldUseLegacyAvailability(response)) {
        response = await _postRaw(_legacyAvailabilityPath, payload);
      }
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      if (data['success'] == false || data['ok'] == false) {
        throw Exception(
          data['error'] ??
              data['reason'] ??
              data['message'] ??
              "Couldn't load availability.",
        );
      }
      final result = {
        ...data,
        'slots': _extractAvailabilitySlots(data),
      };
      _availabilityCache[identity] = result;
      _availabilityCacheAt[identity] = DateTime.now();
      await _writePersistentCache(resource, result);
      return result;
    } catch (error) {
      throw Exception(
        AppErrorUtils.friendlyMessage(
          error,
          fallback: 'Unable to load availability right now. Please try again.',
        ),
      );
    }
  }

  bool _shouldUseLegacyAvailability(http.Response response) {
    if (response.statusCode == 404 || response.statusCode >= 500) {
      return true;
    }
    if (!AuthService.instance.isAuthenticated && response.statusCode == 401) {
      return true;
    }
    if (response.body.isEmpty) return false;
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) return false;
      if (data['success'] != false && data['ok'] != false) return false;
      final detail = [data['error'], data['reason'], data['message']]
          .whereType<Object>()
          .join(' ')
          .toLowerCase();
      return detail.contains('server_error') ||
          detail.contains('unauthenticated') ||
          detail.contains('unauthorized');
    } catch (_) {
      return false;
    }
  }

  // H5: Fetch Rewards
  Future<Map<String, dynamic>> fetchRewards({bool forceRefresh = false}) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final inFlight = _rewardsInFlight;
    if (inFlight != null) return inFlight;
    final cached = _cachedRewards;
    final cachedAt = _cachedRewardsAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _rewardsCacheTtl) {
      return cached;
    }
    if (!forceRefresh) {
      final persistent =
          await _readPersistentCache('rewards', _offlineFallbackCacheTtl);
      if (persistent != null) {
        _cachedRewards = persistent;
        _cachedRewardsAt = DateTime.now();
        return persistent;
      }
    }

    final future = _post(
      _rewardsPath,
      {},
      fallbackEndpoint: _legacyRewardsPath,
    );
    _rewardsInFlight = future;
    try {
      final resp = await future;
      if (_userId != uid) {
        throw Exception('The signed-in user changed during this request.');
      }
      _cachedRewards = resp;
      _cachedRewardsAt = DateTime.now();
      await _writePersistentCache('rewards', resp);
      return resp;
    } finally {
      _rewardsInFlight = null;
    }
  }

  Future<Map<String, dynamic>> fetchProfile({bool forceRefresh = false}) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final inFlight = _profileInFlight;
    if (inFlight != null) return inFlight;
    final cached = _cachedProfile;
    final cachedAt = _cachedProfileAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _profileCacheTtl) {
      return cached;
    }

    if (!forceRefresh) {
      final persistent =
          await _readPersistentCache('profile', _offlineFallbackCacheTtl);
      if (persistent != null) {
        _cachedProfile = persistent;
        _cachedProfileAt = DateTime.now();
        _cachedAddresses = persistent['addresses'] ??
            persistent['profile']?['addresses'] ??
            [];
        return persistent;
      }
    }

    final future = _post(
      _profilePath,
      {
        'action': 'get',
        'userId': uid,
      },
      fallbackEndpoint: _legacyProfilePath,
    );
    _profileInFlight = future;
    try {
      final resp = await future;
      if (_userId != uid) {
        throw Exception('The signed-in user changed during this request.');
      }
      _cachedProfile = resp;
      _cachedProfileAt = DateTime.now();
      _cachedAddresses =
          resp['addresses'] ?? resp['profile']?['addresses'] ?? [];
      await _writePersistentCache('profile', resp);
      return resp;
    } finally {
      _profileInFlight = null;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String givenName,
    required String familyName,
    required String phone,
    required String email,
    required String userName,
    required String preferredContact,
    required bool marketingConsent,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');
    final result = await _post(
      _profilePath,
      {
        'action': 'update_profile',
        'userId': uid,
        'givenName': givenName,
        'familyName': familyName,
        'phone': phone,
        'email': email,
        'userName': userName,
        'preferredContact': preferredContact,
        'marketingConsent': marketingConsent,
      },
      fallbackEndpoint: _legacyProfilePath,
    );
    await _invalidateProfileCache();
    unawaited(syncInBackground());
    return result;
  }

  /// Persists the categories a homeowner has explicitly opted into. The
  /// notification worker uses these flags before sending an FCM payload.
  Future<void> updateNotificationSettings(
    Map<String, bool> notificationSettings,
  ) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    await _post(
      _profilePath,
      {
        'action': 'update_notification_settings',
        'userId': uid,
        'notificationSettings': notificationSettings,
        'notification_settings': notificationSettings,
      },
      fallbackEndpoint: _legacyProfilePath,
    );
    await _invalidateProfileCache();
    unawaited(syncInBackground());
  }

  /// Registers the active FCM/Web Push token for the signed-in homeowner.
  /// The API must scope this record to the authenticated user, expire stale
  /// tokens, and never accept a token for a different account.
  Future<void> registerPushDevice({
    required String userId,
    required String token,
    required String platform,
    required Map<String, bool> preferences,
  }) async {
    if (token.trim().isEmpty || _userId == null) return;
    await _post(
      _profilePath,
      {
        'action': 'register_push_device',
        'userId': userId,
        'deviceToken': token,
        'device_token': token,
        'platform': platform,
        'notificationSettings': preferences,
        'notification_settings': preferences,
      },
      fallbackEndpoint: _legacyProfilePath,
    );
  }

  Future<Map<String, dynamic>> addAddress(Map<String, String> address) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final body = {
      'action': 'add_address',
      'userId': uid,
      'street': address['street'] ?? '',
      'city': address['city'] ?? '',
      'state': address['state'] ?? '',
      'zip': address['zip'] ?? '',
      'label': address['label'] ?? 'Address',
      'isDefault': address['isDefault'] == 'true',
      if (address['unit'] != null) 'unit': address['unit'],
    };

    final result =
        await _post(_profilePath, body, fallbackEndpoint: _legacyProfilePath);
    if (result['success'] == true && result['addresses'] != null) {
      _cachedAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    unawaited(syncInBackground());
    return result;
  }

  Future<Map<String, dynamic>> updateAddress({
    required int addressId,
    required Map<String, String> address,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final body = {
      'action': 'update_address',
      'userId': uid,
      'addressId': addressId,
      'street': address['street'] ?? '',
      'city': address['city'] ?? '',
      'state': address['state'] ?? '',
      'zip': address['zip'] ?? '',
      'label': address['label'] ?? 'Address',
      'isDefault': address['isDefault'] == 'true',
      if (address['unit'] != null) 'unit': address['unit'],
    };

    final result =
        await _post(_profilePath, body, fallbackEndpoint: _legacyProfilePath);
    if (result['success'] == true && result['addresses'] != null) {
      _cachedAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    unawaited(syncInBackground());
    return result;
  }

  Future<Map<String, dynamic>> setDefaultAddress(dynamic addressId) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final result = await _post(
      _profilePath,
      {
        'action': 'set_default_address',
        'userId': uid,
        'addressId': addressId,
      },
      fallbackEndpoint: _legacyProfilePath,
    );
    if (result['success'] == true && result['addresses'] != null) {
      _cachedAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    unawaited(syncInBackground());
    return result;
  }

  Future<Map<String, dynamic>> removeAddress(int addressId) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final result = await _post(
      _profilePath,
      {
        'action': 'remove_address',
        'userId': uid,
        'addressId': addressId,
      },
      fallbackEndpoint: _legacyProfilePath,
    );
    if (result['success'] == true && result['addresses'] != null) {
      _cachedAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    unawaited(syncInBackground());
    return result;
  }

  // Booking commits (Wizard usage)
  Future<Map<String, dynamic>> commitBooking({
    required String contractorId,
    required String action, // commit | quote_request
    required String urgency, // standard | urgent | emergency
    required Map<String, dynamic> booking,
    String? startsAt,
    String? endsAt,
    String? transactionId,
  }) {
    if (_userId == null) {
      return Future.error(Exception('User is not authenticated'));
    }
    final key = transactionId?.trim() ?? '';
    if (key.isEmpty) {
      return _commitBooking(
        contractorId: contractorId,
        action: action,
        urgency: urgency,
        booking: booking,
        startsAt: startsAt,
        endsAt: endsAt,
      );
    }

    final completed = _completedBookingCommits[key];
    if (completed != null) {
      return Future.value(Map<String, dynamic>.from(completed));
    }

    final inFlight = _bookingCommitsInFlight[key];
    if (inFlight != null) return inFlight;

    final request = _commitBooking(
      contractorId: contractorId,
      action: action,
      urgency: urgency,
      booking: booking,
      startsAt: startsAt,
      endsAt: endsAt,
      transactionId: key,
    );
    _bookingCommitsInFlight[key] = request;

    return request.then((result) {
      if (_completedBookingCommits.length >= 50) {
        _completedBookingCommits.remove(_completedBookingCommits.keys.first);
      }
      _completedBookingCommits[key] = Map<String, dynamic>.from(result);
      return result;
    }).whenComplete(() => _bookingCommitsInFlight.remove(key));
  }

  Future<Map<String, dynamic>> _commitBooking({
    required String contractorId,
    required String action,
    required String urgency,
    required Map<String, dynamic> booking,
    String? startsAt,
    String? endsAt,
    String? transactionId,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final bookingPayload = Map<String, dynamic>.from(booking);
    bookingPayload['requester_user_id'] = uid;
    if (transactionId != null) {
      bookingPayload['client_request_id'] = transactionId;
    }

    final body = {
      'contractorId': contractorId,
      'action': action,
      'urgency': urgency,
      'booking': bookingPayload,
      if (startsAt != null) 'startsAt': startsAt,
      if (endsAt != null) 'endsAt': endsAt,
      if (transactionId != null) 'idempotencyKey': transactionId,
      if (action == 'commit' && booking['address_zip'] != null)
        'propertyZip': booking['address_zip'],
    };

    try {
      var response = await _postRaw(_bookingCommitPath, body);
      if (response.statusCode == 404) {
        response = await _postRaw(_legacyBookingCommitPath, body);
      }
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>)
        throw Exception('Invalid response format');

      if (response.statusCode >= 400 ||
          data['ok'] == false ||
          data['success'] == false) {
        throw Exception(
            data['reason'] ?? data['error'] ?? 'Booking commit failed');
      }
      if (_userId != uid) {
        throw Exception('The signed-in user changed during this request.');
      }
      await _invalidateWorkOrderCache();
      await _invalidateAvailabilityCache();
      await _invalidateRewardsCache();
      unawaited(syncInBackground());
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Search vetted pros
  Future<Map<String, dynamic>> searchPros({
    required String zip,
    required String categorySlug,
    String urgency = 'standard',
  }) async {
    final identity =
        '${zip.trim().toLowerCase()}|${categorySlug.trim().toLowerCase()}|${urgency.trim().toLowerCase()}';
    final resource = 'search:$identity';
    try {
      final cached = _searchProsCache[identity];
      final cachedAt = _searchProsCacheAt[identity];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _searchCacheTtl) {
        return cached;
      }
      final persistent = await _readPersistentCache(resource, _searchCacheTtl);
      if (persistent != null) {
        _searchProsCache[identity] = persistent;
        _searchProsCacheAt[identity] = DateTime.now();
        return persistent;
      }

      final payload = {
        'zip': zip,
        'categorySlug': categorySlug,
        'urgency': urgency,
      };
      _throwIfRecentFailure(_contractorSearchPath);
      _throwIfRecentFailure(_legacyContractorSearchPath);
      var response = await _postRaw(_contractorSearchPath, payload);
      if (_shouldUseFallbackEndpoint(response)) {
        response = await _postRaw(_legacyContractorSearchPath, payload);
      }
      if (response.body.isEmpty) {
        throw Exception(ApiConfig.emptyResponseMessage(_contractorSearchPath));
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      if (data['success'] == false && data['covered'] != false) {
        throw Exception(
          data['error'] ??
              data['reason'] ??
              data['message'] ??
              'Search failed.',
        );
      }
      _clearRecentFailure(_contractorSearchPath);
      _clearRecentFailure(_legacyContractorSearchPath);
      _searchProsCache[identity] = data;
      _searchProsCacheAt[identity] = DateTime.now();
      await _writePersistentCache(resource, data);
      return data;
    } catch (e) {
      _cacheRecentFailure(_contractorSearchPath, e,
          fallbackMessage: 'Unable to load available pros right now.');
      _cacheRecentFailure(_legacyContractorSearchPath, e,
          fallbackMessage: 'Unable to load available pros right now.');
      throw Exception(
        AppErrorUtils.friendlyMessage(
          e,
          fallback: 'Unable to load available pros right now.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> getZipCoverage({
    required String zip,
  }) async {
    final normalizedZip = zip.trim().toLowerCase();
    final resource = 'coverage:$normalizedZip';
    try {
      final cached = _zipCoverageCache[normalizedZip];
      final cachedAt = _zipCoverageCacheAt[normalizedZip];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _coverageCacheTtl) {
        return cached;
      }
      final persistent =
          await _readPersistentCache(resource, _coverageCacheTtl);
      if (persistent != null) {
        _zipCoverageCache[normalizedZip] = persistent;
        _zipCoverageCacheAt[normalizedZip] = DateTime.now();
        return persistent;
      }

      _throwIfRecentFailure(_zipCoveragePath);
      final response = await _postRaw(_zipCoveragePath, {'zip': zip});
      if (response.body.isEmpty) {
        throw Exception(ApiConfig.emptyResponseMessage(_zipCoveragePath));
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response');
      }
      if (response.statusCode >= 400 || data['success'] == false) {
        throw Exception(
          data['error'] ??
              data['reason'] ??
              data['message'] ??
              'ZIP coverage lookup failed.',
        );
      }
      _clearRecentFailure(_zipCoveragePath);
      _zipCoverageCache[normalizedZip] = data;
      _zipCoverageCacheAt[normalizedZip] = DateTime.now();
      await _writePersistentCache(resource, data);
      return data;
    } catch (e) {
      _cacheRecentFailure(
        _zipCoveragePath,
        e,
        fallbackMessage: 'Unable to verify ZIP coverage right now.',
      );
      throw Exception(
        AppErrorUtils.friendlyMessage(
          e,
          fallback: 'Unable to verify ZIP coverage right now.',
        ),
      );
    }
  }

  // Email verification endpoints
  Future<Map<String, dynamic>> sendVerificationEmail(String email) async {
    return await _post(
      _verifyPath,
      {
        'action': 'send',
        'email': email,
      },
      fallbackEndpoint: _legacyVerifyPath,
    );
  }

  Future<Map<String, dynamic>> confirmVerification(String token) async {
    final uid = _userId;
    return await _post(
      _verifyPath,
      {
        'action': 'confirm',
        if (uid != null) 'userId': uid,
        'token': token,
      },
      fallbackEndpoint: _legacyVerifyPath,
    );
  }

  Future<Map<String, dynamic>> getProfile() => fetchProfile();

  Future<Map<String, dynamic>?> getReview(int workOrderId) async {
    final cached = cachedReviewForWorkOrder(workOrderId);
    if (cached != null) return cached;

    final jobsResp = await fetchWorkOrders();
    await hydrateReviewsFromWorkOrders(jobsResp);
    final hydrated = cachedReviewForWorkOrder(workOrderId);
    if (hydrated != null) return hydrated;
    final tabs = jobsResp['tabs'] as Map<String, dynamic>? ?? const {};
    final allJobs = <dynamic>[
      ...(tabs['active'] as List? ?? const []),
      ...(tabs['scheduled'] as List? ?? const []),
      ...(tabs['history'] as List? ?? const []),
    ];

    Map<String, dynamic>? match;
    for (final rawJob in allJobs) {
      if (rawJob is! Map) continue;
      final job = Map<String, dynamic>.from(rawJob);
      if (job['workOrderId']?.toString() == workOrderId.toString() ||
          job['id']?.toString() == workOrderId.toString()) {
        match = job;
        break;
      }
    }

    if (match == null) {
      return null;
    }

    final review = _reviewFromWorkOrder(match);
    if (review != null) _cacheReview(workOrderId, review);
    return review;
  }

  String bookingErrorMessage(Object error) {
    final raw =
        error.toString().replaceAll('Exception: ', '').trim().toLowerCase();
    if (raw.contains('booking_cap')) {
      return 'You have reached the maximum number of open bookings. Please complete or cancel an existing booking before creating a new one.';
    }
    if (raw.contains('verification_required')) {
      return 'Email verification is required before booking.';
    }
    if (raw.contains('out_of_coverage') || raw.contains('invalid_zip')) {
      return 'This contractor is not currently serving the selected ZIP code.';
    }
    if (raw.contains('slot_unavailable') || raw.contains('conflict')) {
      return 'The selected time slot is no longer available. Please choose another time.';
    }
    if (raw.contains('contractor_unavailable')) {
      return 'The selected contractor is currently unavailable. Please choose another pro or time.';
    }
    return AppErrorUtils.friendlyMessage(
      error,
      fallback: 'Unable to complete your booking right now. Please try again.',
    );
  }
}

class _RecentRequestFailure {
  final DateTime at;
  final String message;

  const _RecentRequestFailure({
    required this.at,
    required this.message,
  });
}

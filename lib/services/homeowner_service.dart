import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  // Mock State
  final List<Map<String, dynamic>> _mockWorkOrders = [];
  final Map<int, Map<String, dynamic>> _mockReviews = {};
  List<dynamic>? _mockAddresses;
  List<dynamic>? get cachedAddresses => _mockAddresses;
  int _mockIdCounter = 102;
  double _mockRewardsBalance = 150.0;
  double _mockRewardsEarned = 25.0;
  Map<String, dynamic>? _cachedProfile;
  DateTime? _cachedProfileAt;
  Future<Map<String, dynamic>>? _profileInFlight;
  Map<String, dynamic>? _cachedRewards;
  DateTime? _cachedRewardsAt;
  Future<Map<String, dynamic>>? _rewardsInFlight;
  Map<String, dynamic>? _cachedWorkOrdersResponse;
  DateTime? _cachedWorkOrdersAt;
  Future<Map<String, dynamic>>? _workOrdersInFlight;
  final Map<int, Map<String, dynamic>> _reviewEligibilityCache = {};
  final Map<int, DateTime> _reviewEligibilityCacheAt = {};
  final Map<int, Future<Map<String, dynamic>>> _reviewEligibilityInFlight = {};
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
    if (_isDemo) {
      for (final workOrder in _mockWorkOrders) {
        final id = _extractWorkOrderId(workOrder);
        if (id == workOrderId.toString()) {
          return _extractContractorIdFromNode(workOrder);
        }
      }
      return null;
    }

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
              if (lowerCat.contains('hvac') || lowerCat.contains('ac') || lowerCat.contains('air') || lowerCat.contains('heat') || lowerCat.contains('cool')) {
                primaryCat = 'hvac';
              } else if (lowerCat.contains('plumb') || lowerCat.contains('leak') || lowerCat.contains('water') || lowerCat.contains('drain') || lowerCat.contains('pipe')) {
                primaryCat = 'plumbing';
              } else if (lowerCat.contains('electr') || lowerCat.contains('light') || lowerCat.contains('wire') || lowerCat.contains('outlet')) {
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
                          final resolvedId = _readRawString(res['contractorId']) ??
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

  String? get _userId => AuthService.instance.userId;
  /// Demo/mock mode is permanently disabled for the commercial build.
  /// It previously auto-enabled on `localhost`/`127.0.0.1`, which meant
  /// every local dev/staging run silently faked contractor availability,
  /// pricing, and booking submission instead of hitting the real backend —
  /// including in any environment that happens to resolve to those hosts.
  /// If a mock mode is ever needed again for offline UI work, it must be
  /// an explicit opt-in (e.g. a build flag), never inferred from hostname.
  bool get _isDemo => false;

  void _ensureDemoState() {
    _mockAddresses ??= [
      {
        'id': 100,
        'label': 'Home',
        'street': '742 Evergreen Terrace',
        'city': 'Riverview',
        'state': 'FL',
        'zip': '33578',
        'isDefault': true,
      },
    ];

    if (_mockWorkOrders.isNotEmpty) return;

    final now = DateTime.now();
    _mockWorkOrders.addAll([
      {
        'workOrderId': 101,
        'status': 'active',
        'serviceCategory': 'Plumbing',
        'priority': 'Urgent',
        'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'scheduledStart': now.add(const Duration(hours: 2)).toIso8601String(),
        'scheduledEnd': now.add(const Duration(hours: 4)).toIso8601String(),
        'address': Map<String, dynamic>.from(_mockAddresses!.first),
        'pro': {
          'id': 'pro-plumbing-1',
          'slug': 'sunrise-plumbing',
          'businessName': 'Sunrise Plumbing Co.',
        },
        'timeline': {
          'acceptedAt':
              now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        'description': 'Kitchen sink leak and water pressure check.',
      },
      {
        'workOrderId': 102,
        'status': 'scheduled',
        'serviceCategory': 'HVAC',
        'priority': 'Standard',
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        'scheduledStart': now.add(const Duration(days: 1, hours: 4))
            .toIso8601String(),
        'scheduledEnd': now.add(const Duration(days: 1, hours: 6))
            .toIso8601String(),
        'address': Map<String, dynamic>.from(_mockAddresses!.first),
        'pro': {
          'id': 'pro-hvac-1',
          'slug': 'gulf-coast-air',
          'businessName': 'Gulf Coast Air',
        },
        'timeline': {
          'acceptedAt':
              now.subtract(const Duration(hours: 20)).toIso8601String(),
        },
        'description': 'Seasonal AC tune-up and airflow inspection.',
      },
    ]);
  }

  Future<SharedPreferences> _getPreferences() {
    final existing = _preferences;
    if (existing != null) return Future.value(existing);
    return _preferencesInFlight ??= SharedPreferences.getInstance().then((prefs) {
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
    final shouldCache =
        AppErrorUtils.isNetworkError(error) ||
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

      if (response.statusCode == 404 && fallbackEndpoint != null) {
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
        await AuthService.instance.invalidateSession();
        throw Exception('Your session has expired. Please sign in again.');
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
      if (kDebugMode) {
        print('HomeownerService POST Error on $endpoint: $e');
      }
      rethrow;
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
  Future<Map<String, dynamic>> fetchWorkOrders() async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 300));
      return _withNormalizedTabs({
        'success': true,
        'tabs': _groupWorkOrdersByTab(
            _mockWorkOrders.map((j) => Map<String, dynamic>.from(j)).toList()),
      });
    }

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final cached = _cachedWorkOrdersResponse;
    final cachedAt = _cachedWorkOrdersAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _workOrdersCacheTtl) {
      return cached;
    }
    final inFlight = _workOrdersInFlight;
    if (inFlight != null) return inFlight;

    final persistent = await _readPersistentCache(
      'work-orders',
      _workOrdersCacheTtl,
    );
    if (persistent != null) {
      final normalized = _withNormalizedTabs(persistent);
      _cachedWorkOrdersResponse = normalized;
      _cachedWorkOrdersAt = DateTime.now();
      return normalized;
    }

    final future = _post(
          _workOrdersListPath,
          {'userId': uid},
          fallbackEndpoint: _legacyWorkOrdersListPath,
        )
            .then(_withNormalizedTabs);
    _workOrdersInFlight = future;
    try {
      final resp = await future;
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
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (var i = 0; i < _mockWorkOrders.length; i++) {
        if (_mockWorkOrders[i]['workOrderId'] == workOrderId) {
          if (action == 'cancel') {
            _mockWorkOrders[i]['status'] = 'canceled';
          } else if (action == 'propose_reschedule') {
            _mockWorkOrders[i]['scheduledStart'] =
                extra?['proposedStart'] ?? _mockWorkOrders[i]['scheduledStart'];
            _mockWorkOrders[i]['scheduledEnd'] =
                extra?['proposedEnd'] ?? _mockWorkOrders[i]['scheduledEnd'];
          } else if (action == 'confirm_complete') {
            _mockWorkOrders[i]['status'] = 'completed';
          }
        }
      }
      return {'success': true, 'ok': true};
    }

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    // Handle mock updates
    for (var i = 0; i < _mockWorkOrders.length; i++) {
      if (_mockWorkOrders[i]['id'] == workOrderId) {
        if (action == 'cancel') {
          _mockWorkOrders[i]['status'] = 'canceled';
        } else if (action == 'propose_reschedule' ||
            action == 'respond_reschedule') {
          // Just mock as updated
        } else if (action == 'confirm_complete') {
          _mockWorkOrders[i]['status'] = 'completed';
        }
      }
    }

    final body = {
      'action': action,
      'workOrderId': workOrderId,
      'requesterUserId': uid,
      'requester_user_id': uid,
      ...?extra,
    };
    final result =
        await _post(
          _workOrdersActionPath,
          body,
          fallbackEndpoint: _legacyWorkOrdersActionPath,
        );
    await _invalidateWorkOrderCache();
    return result;
  }

  // H3: booking-commit-v2-supabase - accept/decline quote
  Future<Map<String, dynamic>> respondToQuote({
    required int workOrderId,
    required bool accept,
    String? startsAt,
    String? endsAt,
    String? contractorId,
    String? reason,
  }) async {
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 200));
      for (var i = 0; i < _mockWorkOrders.length; i++) {
        if (_mockWorkOrders[i]['workOrderId'] == workOrderId) {
          if (accept) {
            _mockWorkOrders[i]['status'] = 'scheduled';
            if (startsAt != null)
              _mockWorkOrders[i]['scheduledStart'] = startsAt;
            if (endsAt != null) _mockWorkOrders[i]['scheduledEnd'] = endsAt;
          } else {
            _mockWorkOrders[i]['status'] = 'canceled';
          }
        }
      }
      return {'success': true, 'ok': true};
    }

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
    return result;
  }

  Future<Map<String, dynamic>> submitReview({
    required int workOrderId,
    required double rating,
    required String text,
    String? displayName,
  }) async {
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 200));
      _mockReviews[workOrderId] = {
        'rating': rating,
        'reviewText': text,
        'displayName': displayName ?? 'Demo Homeowner',
      };
      return {'success': true, 'ok': true};
    }

    if (_userId == null) throw Exception('User is not authenticated');
    final ratingInt = rating.round().clamp(1, 5).toInt();

    final body = {
      'action': 'submit_review',
      'workOrderId': workOrderId,
      'rating': ratingInt,
      'text': text,
      if (displayName != null) 'displayName': displayName,
    };
    final result = await _post(
      _reviewActionPath,
      body,
      fallbackEndpoint: _legacyReviewActionPath,
    );
    await _invalidateWorkOrderCache();
    _invalidateReviewEligibilityCache(workOrderId);
    await _invalidateContractorProfileCache();
    await _invalidateRewardsCache();
    return result;
  }

  Future<Map<String, dynamic>> getReviewEligibility({
    required int workOrderId,
  }) async {
    if (_isDemo) {
      return {
        'success': true,
        'eligible': !_mockReviews.containsKey(workOrderId),
        'reason':
            _mockReviews.containsKey(workOrderId) ? 'already_reviewed' : null,
      };
    }

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
            data['error'] ?? data['reason'] ?? data['message'] ?? 'Failed to load profile.',
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
      if (kDebugMode) {
        print('Error fetching contractor profile: $e');
      }
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
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 100));
      return {'success': true, 'slots': const <Map<String, String>>[]};
    }

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
    final persistent = await _readPersistentCache(resource, _availabilityCacheTtl);
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
      var response = await _postRaw(_availabilityPath, payload);
      if (response.statusCode == 404) {
        response = await _postRaw(_legacyAvailabilityPath, payload);
      }
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      if (data['success'] == false || data['ok'] == false) {
        throw Exception(
          data['error'] ?? data['reason'] ?? data['message'] ?? "Couldn't load availability.",
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
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching contractor availability: $e');
      }
      rethrow;
    }
  }

  // H5: Fetch Rewards
  Future<Map<String, dynamic>> fetchRewards() async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 100));
      return {
        'success': true,
        'balance': _mockRewardsBalance,
        'earned': _mockRewardsEarned,
      };
    }

    if (_userId == null) throw Exception('User is not authenticated');

    final cached = _cachedRewards;
    final cachedAt = _cachedRewardsAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _rewardsCacheTtl) {
      return cached;
    }
    final inFlight = _rewardsInFlight;
    if (inFlight != null) return inFlight;
    final persistent = await _readPersistentCache('rewards', _rewardsCacheTtl);
    if (persistent != null) {
      _cachedRewards = persistent;
      _cachedRewardsAt = DateTime.now();
      return persistent;
    }

    final future = _post(
      _rewardsPath,
      {},
      fallbackEndpoint: _legacyRewardsPath,
    );
    _rewardsInFlight = future;
    try {
      final resp = await future;
      _cachedRewards = resp;
      _cachedRewardsAt = DateTime.now();
      await _writePersistentCache('rewards', resp);
      return resp;
    } finally {
      _rewardsInFlight = null;
    }
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 100));
      return {
        'success': true,
        'profile': {
          'userId': _userId ?? '999',
          'email':
              AuthService.instance.userEmail ?? 'demo.homeowner@gmail.com',
          'name': AuthService.instance.userName ?? 'Demo Homeowner',
          'givenName': AuthService.instance.givenName ?? 'Demo',
          'familyName': AuthService.instance.familyName ?? 'Homeowner',
          'phone': '(813) 555-9999',
          'emailVerified': true,
          'rewardsBalance': _mockRewardsBalance,
          'rewardsTier': 'bronze',
        },
        'addresses': _mockAddresses ?? const [],
      };
    }

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final cached = _cachedProfile;
    final cachedAt = _cachedProfileAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _profileCacheTtl) {
      return cached;
    }
    final inFlight = _profileInFlight;
    if (inFlight != null) return inFlight;

    final persistent = await _readPersistentCache('profile', _profileCacheTtl);
    if (persistent != null) {
      _cachedProfile = persistent;
      _cachedProfileAt = DateTime.now();
      _mockAddresses =
          persistent['addresses'] ?? persistent['profile']?['addresses'] ?? [];
      return persistent;
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
      _cachedProfile = resp;
      _cachedProfileAt = DateTime.now();
      _mockAddresses = resp['addresses'] ?? resp['profile']?['addresses'] ?? [];
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
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 200));
      return {
        'success': true,
        'profile': {
          'userId': _userId ?? '999',
          'email': email,
          'name': userName,
          'userName': userName,
          'givenName': givenName,
          'familyName': familyName,
          'phone': phone,
          'preferredContact': preferredContact,
          'marketingConsent': marketingConsent,
          'emailVerified': true,
        },
        'addresses': _mockAddresses ?? const [],
      };
    }

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
    return result;
  }

  Future<Map<String, dynamic>> addAddress(Map<String, String> address) async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 200));
      _mockIdCounter++;
      final newAddr = {
        'id': _mockIdCounter,
        'label': address['label'] ?? 'Address',
        'street': address['street'] ?? '',
        'unit': address['unit'],
        'city': address['city'] ?? '',
        'state': address['state'] ?? '',
        'zip': address['zip'] ?? '',
        'isDefault':
            address['isDefault'] == 'true' || address['isDefault'] == true,
      };
      if (newAddr['isDefault'] == true) {
        for (var a in _mockAddresses!) {
          a['isDefault'] = false;
        }
      }
      _mockAddresses!.add(newAddr);
      return {'success': true, 'addresses': _mockAddresses};
    }

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
      'isDefault':
          address['isDefault'] == 'true' || address['isDefault'] == true,
      if (address['unit'] != null) 'unit': address['unit'],
    };

    final result =
        await _post(_profilePath, body, fallbackEndpoint: _legacyProfilePath);
    if (result['success'] == true && result['addresses'] != null) {
      _mockAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> updateAddress({
    required int addressId,
    required Map<String, String> address,
  }) async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 200));
      for (var a in _mockAddresses!) {
        if (a['id'] == addressId) {
          a['label'] = address['label'] ?? a['label'];
          a['street'] = address['street'] ?? a['street'];
          a['unit'] = address['unit'];
          a['city'] = address['city'] ?? a['city'];
          a['state'] = address['state'] ?? a['state'];
          a['zip'] = address['zip'] ?? a['zip'];
          a['isDefault'] =
              address['isDefault'] == 'true' || address['isDefault'] == true;
        }
      }
      return {'success': true, 'addresses': _mockAddresses};
    }

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
      'isDefault':
          address['isDefault'] == 'true' || address['isDefault'] == true,
      if (address['unit'] != null) 'unit': address['unit'],
    };

    final result =
        await _post(_profilePath, body, fallbackEndpoint: _legacyProfilePath);
    if (result['success'] == true && result['addresses'] != null) {
      _mockAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> setDefaultAddress(dynamic addressId) async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 200));
      final parsedId =
          addressId is int ? addressId : int.tryParse(addressId.toString());
      for (var a in _mockAddresses!) {
        a['isDefault'] = (a['id'] == parsedId);
      }
      return {'success': true, 'addresses': _mockAddresses};
    }

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
      _mockAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> removeAddress(int addressId) async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 200));
      _mockAddresses!.removeWhere((a) => a['id'] == addressId);
      return {'success': true, 'addresses': _mockAddresses};
    }

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
      _mockAddresses = result['addresses'];
    }
    await _invalidateProfileCache();
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
  }) async {
    if (_isDemo) {
      _ensureDemoState();
      await Future.delayed(const Duration(milliseconds: 300));
      _mockIdCounter++;
      final newWO = {
        'workOrderId': _mockIdCounter,
        'status': action == 'quote_request' ? 'quote_ready' : 'scheduled',
        'serviceCategory': booking['service_category'] ?? 'Home Service',
        'priority': urgency == 'urgent'
            ? 'Urgent'
            : (urgency == 'emergency' ? 'Emergency' : 'Standard'),
        'scheduledStart': startsAt ??
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'scheduledEnd': endsAt ??
            DateTime.now()
                .add(const Duration(days: 1, hours: 2))
                .toIso8601String(),
        'address': {
          'street': booking['address_street'] ?? '',
          'city': booking['address_city'] ?? '',
          'state': booking['address_state'] ?? '',
          'zip': booking['address_zip'] ?? '',
        },
        'pro': {
          'id': contractorId,
          'businessName': 'Mocked Contractor',
        },
        'description':
            booking['service_description'] ?? 'Diagnostic and repair request.',
      };
      _mockWorkOrders.add(newWO);
      return {
        'success': true,
        'ok': true,
        'woNumber': 'WO-$_mockIdCounter',
      };
    }

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final bookingPayload = Map<String, dynamic>.from(booking);
    bookingPayload['requester_user_id'] = uid;

    final body = {
      'contractorId': contractorId,
      'action': action,
      'urgency': urgency,
      'booking': bookingPayload,
      if (startsAt != null) 'startsAt': startsAt,
      if (endsAt != null) 'endsAt': endsAt,
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

      if (response.statusCode >= 400 || data['ok'] == false || data['success'] == false) {
        throw Exception(
            data['reason'] ?? data['error'] ?? 'Booking commit failed');
      }
      await _invalidateWorkOrderCache();
      await _invalidateAvailabilityCache();
      await _invalidateRewardsCache();
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Booking commit error: $e');
      }
      rethrow;
    }
  }

  // Search vetted pros
  Future<Map<String, dynamic>> searchPros({
    required String zip,
    required String categorySlug,
    String urgency = 'standard',
  }) async {
    final identity = '${zip.trim().toLowerCase()}|${categorySlug.trim().toLowerCase()}|${urgency.trim().toLowerCase()}';
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
      if (response.statusCode == 404) {
        response = await _postRaw(_legacyContractorSearchPath, payload);
      }
      if (response.body.isEmpty) {
        throw Exception(ApiConfig.emptyResponseMessage(_contractorSearchPath));
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      if (data['success'] == false && data['covered'] != false) {
        throw Exception(
          data['error'] ?? data['reason'] ?? data['message'] ?? 'Search failed.',
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
      if (kDebugMode) {
        print('Error searching contractors: $e');
      }
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
      final persistent = await _readPersistentCache(resource, _coverageCacheTtl);
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
          data['error'] ?? data['reason'] ?? data['message'] ?? 'ZIP coverage lookup failed.',
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
      if (kDebugMode) {
        print('Error loading ZIP coverage: $e');
      }
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

  // ALIASES for mocked screens
  Future<Map<String, dynamic>> getProfile() => fetchProfile();

  Future<void> createWorkOrder(Map<String, dynamic> reqBody) async {
    throw UnsupportedError(
      'createWorkOrder is not connected to the live backend. Use commitBooking instead.',
    );
  }

  Future<Map<String, dynamic>?> getReview(int workOrderId) async {
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockReviews[workOrderId];
    }

    final jobsResp = await fetchWorkOrders();
    final tabs = jobsResp['tabs'] as Map<String, dynamic>? ?? const {};
    final allJobs = <dynamic>[
      ...(tabs['active'] as List? ?? const []),
      ...(tabs['scheduled'] as List? ?? const []),
      ...(tabs['history'] as List? ?? const []),
    ];

    final match = allJobs.cast<Map<String, dynamic>?>().firstWhere(
          (job) =>
              job != null &&
              (job['workOrderId']?.toString() == workOrderId.toString() ||
                  job['id']?.toString() == workOrderId.toString()),
          orElse: () => null,
        );

    if (match == null) {
      return null;
    }

    final reviewText = match['reviewText'] ??
        match['review']?['text'] ??
        match['review']?['reviewText'] ??
        match['homeownerReview']?['text'] ??
        match['homeowner_review']?['text'] ??
        match['reviews']?['text'];
    final rating = match['rating'] ??
        match['review']?['rating'] ??
        match['homeownerReview']?['rating'] ??
        match['homeowner_review']?['rating'] ??
        match['reviews']?['rating'];
    final displayName = match['displayName'] ??
        match['review']?['displayName'] ??
        match['homeownerReview']?['displayName'] ??
        match['homeowner_review']?['displayName'];

    if (reviewText == null && rating == null) {
      return null;
    }

    return {
      'rating': (rating as num?)?.toDouble() ?? 0,
      'reviewText': reviewText?.toString() ?? '',
      'displayName': displayName?.toString(),
    };
  }

  String bookingErrorMessage(Object error) {
    final raw = error.toString().replaceAll('Exception: ', '').trim().toLowerCase();
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

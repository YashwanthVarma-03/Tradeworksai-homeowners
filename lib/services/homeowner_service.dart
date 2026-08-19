import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  Map<String, dynamic>? _cachedWorkOrdersResponse;
  DateTime? _cachedWorkOrdersAt;
  Future<Map<String, dynamic>>? _workOrdersInFlight;
  final Map<String, Map<String, dynamic>> _contractorProfileCache = {};
  final Map<String, DateTime> _contractorProfileCacheAt = {};
  final Map<String, Future<Map<String, dynamic>>> _contractorProfileInFlight =
      {};

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
  // Demo-mode fallbacks are disabled so homeowner flows only use backend data.
  bool get _isDemo => false;

  void _invalidateProfileCache() {
    _cachedProfile = null;
    _cachedProfileAt = null;
  }

  void _invalidateWorkOrderCache() {
    _cachedWorkOrdersResponse = null;
    _cachedWorkOrdersAt = null;
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
    return http.post(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    String? fallbackEndpoint,
  }) async {
    try {
      var response = await _postRaw(endpoint, body);
      if (response.statusCode == 404 && fallbackEndpoint != null) {
        response = await _postRaw(fallbackEndpoint, body);
      }

      if (response.body.isEmpty) {
        throw Exception('Received empty response from server.');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format.');
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

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('HomeownerService POST Error on $endpoint: $e');
      }
      rethrow;
    }
  }

  // H1: Fetch Work Orders
  Future<Map<String, dynamic>> fetchWorkOrders() async {
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _withNormalizedTabs({
        'success': true,
        'tabs': _groupWorkOrdersByTab(
            _mockWorkOrders.map((j) => Map<String, dynamic>.from(j)).toList()),
      });
    }

    final cached = _cachedWorkOrdersResponse;
    final cachedAt = _cachedWorkOrdersAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 6)) {
      return cached;
    }
    final inFlight = _workOrdersInFlight;
    if (inFlight != null) return inFlight;

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');
    final future =
        _post(
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
    _invalidateWorkOrderCache();
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
    _invalidateWorkOrderCache();
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

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');
    final ratingInt = rating.round().clamp(1, 5).toInt();

    final body = {
      'action': 'submit_review',
      'workOrderId': workOrderId,
      'work_order_id': workOrderId,
      'requesterUserId': uid,
      'requester_user_id': uid,
      'rating': ratingInt,
      'text': text,
      'reviewText': text,
      if (displayName != null) 'displayName': displayName,
    };
    final result = await _post(
      _reviewActionPath,
      body,
      fallbackEndpoint: _legacyReviewActionPath,
    );
    _invalidateWorkOrderCache();
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

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    return await _post(
      _reviewActionPath,
      {
        'action': 'get_review_eligibility',
        'workOrderId': workOrderId,
        'work_order_id': workOrderId,
        'requesterUserId': uid,
        'requester_user_id': uid,
      },
      fallbackEndpoint: _legacyReviewActionPath,
    );
  }

  Future<Map<String, dynamic>> getContractorProfile(String slug) async {
    try {
      final cached = _contractorProfileCache[slug];
      final cachedAt = _contractorProfileCacheAt[slug];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < const Duration(seconds: 30)) {
        return cached;
      }

      final inFlight = _contractorProfileInFlight[slug];
      if (inFlight != null) return inFlight;

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
      final slots = <Map<String, String>>[];
      final startBase = DateTime.now().add(const Duration(days: 1));
      for (int i = 0; i < 5; i++) {
        final date = startBase.add(Duration(days: i));
        final morningStart = DateTime(date.year, date.month, date.day, 10, 0);
        final morningEnd = morningStart.add(const Duration(hours: 2));
        final afternoonStart = DateTime(date.year, date.month, date.day, 14, 0);
        final afternoonEnd = afternoonStart.add(const Duration(hours: 2));

        slots.add({
          'start': morningStart.toIso8601String(),
          'end': morningEnd.toIso8601String(),
        });
        slots.add({
          'start': afternoonStart.toIso8601String(),
          'end': afternoonEnd.toIso8601String(),
        });
      }
      return {'success': true, 'slots': slots};
    }

    try {
      final payload = {
        'contractorId': contractorId,
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
      return {
        ...data,
        'slots': _extractAvailabilitySlots(data),
      };
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
      await Future.delayed(const Duration(milliseconds: 100));
      return {
        'success': true,
        'balance': _mockRewardsBalance,
        'earned': _mockRewardsEarned,
      };
    }

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');

    final resp = await _post(
      _rewardsPath,
      {'userId': uid},
      fallbackEndpoint: _legacyRewardsPath,
    );
    return resp;
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    if (_isDemo) {
      await Future.delayed(const Duration(milliseconds: 100));
      return {
        'success': true,
        'profile': {
          'userId': '999',
          'email': 'demo.homeowner@gmail.com',
          'name': 'Demo Homeowner',
          'givenName': 'Demo',
          'familyName': 'Homeowner',
          'phone': '(813) 555-9999',
          'emailVerified': true,
          'rewardsBalance': _mockRewardsBalance,
          'rewardsTier': 'bronze',
        },
        'addresses': _mockAddresses ?? [],
      };
    }

    final cached = _cachedProfile;
    final cachedAt = _cachedProfileAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 6)) {
      return cached;
    }
    final inFlight = _profileInFlight;
    if (inFlight != null) return inFlight;

    final uid = _userId;
    if (uid == null) throw Exception('User is not authenticated');
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
      await Future.delayed(const Duration(milliseconds: 200));
      return {'success': true};
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
    _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> addAddress(Map<String, String> address) async {
    if (_isDemo) {
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
    _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> updateAddress({
    required int addressId,
    required Map<String, String> address,
  }) async {
    if (_isDemo) {
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
    _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> setDefaultAddress(dynamic addressId) async {
    if (_isDemo) {
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
    _invalidateProfileCache();
    return result;
  }

  Future<Map<String, dynamic>> removeAddress(int addressId) async {
    if (_isDemo) {
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
    _invalidateProfileCache();
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
      _invalidateWorkOrderCache();
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
    try {
      final payload = {
        'zip': zip,
        'categorySlug': categorySlug,
        'urgency': urgency,
      };
      var response = await _postRaw(_contractorSearchPath, payload);
      if (response.statusCode == 404) {
        response = await _postRaw(_legacyContractorSearchPath, payload);
      }
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      if (data['success'] == false && data['covered'] != false) {
        throw Exception(
          data['error'] ?? data['reason'] ?? data['message'] ?? 'Search failed.',
        );
      }
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching contractors: $e');
      }
      throw Exception('Search failed.');
    }
  }

  Future<Map<String, dynamic>> getZipCoverage({
    required String zip,
  }) async {
    try {
      final response = await _postRaw(_zipCoveragePath, {'zip': zip});
      if (response.body.isEmpty) {
        throw Exception('Empty response');
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
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading ZIP coverage: $e');
      }
      throw Exception('ZIP coverage lookup failed.');
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
}

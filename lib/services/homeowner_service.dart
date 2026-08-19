import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../utils/app_error_utils.dart';

class HomeownerService {
  static final HomeownerService instance = HomeownerService._internal();
  HomeownerService._internal();

  static const String baseUrl =
      'https://us-central1-tradeworksai-senthil-dev-env.cloudfunctions.net/';

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

  String bookingErrorMessage(Object error) {
    final message = AppErrorUtils.friendlyMessage(error).trim();
    if (message.contains('booking_cap')) {
      return 'You already have the maximum number of open bookings. Please complete or cancel one before placing another booking.';
    }
    return message.isEmpty ? 'Booking failed. Please try again.' : message;
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
        'contractorUserId',
        'contractor_user_id',
        'proUserId',
        'pro_user_id',
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
            'userId',
            'user_id',
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
                    bool found = false;
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
  bool get _isDemo => AuthService.instance.isTesting;

  void _invalidateProfileCache() {
    _cachedProfile = null;
    _cachedProfileAt = null;
  }

  void _invalidateWorkOrderCache() {
    _cachedWorkOrdersResponse = null;
    _cachedWorkOrdersAt = null;
  }

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.body.isEmpty) {
        throw Exception('Received empty response from server.');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format.');
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
      throw Exception(AppErrorUtils.friendlyMessage(e));
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
        _post('homeowner-work-orders-list-v2-supabase', {'userId': uid})
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
        await _post('homeowner-work-orders-action-v2-supabase', body);
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
    final result = await _post('booking-commit-v2-supabase', body);
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
    final result = await _post('homeowner-review-action-v2-supabase', body);
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

    return await _post('homeowner-review-action-v2-supabase', {
      'action': 'get_review_eligibility',
      'workOrderId': workOrderId,
      'work_order_id': workOrderId,
      'requesterUserId': uid,
      'requester_user_id': uid,
    });
  }

  Future<Map<String, dynamic>> getContractorProfile(String slug) async {
    final url =
        Uri.parse('${baseUrl}public-contractor-profile-get-v2-supabase');
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

      final future = http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'slug': slug}),
      )
          .then((response) {
        if (response.body.isEmpty) throw Exception('Empty response');
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) throw Exception('Invalid response');
        return data;
      });
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

    final url = Uri.parse('${baseUrl}contractor-availability-get-v2-supabase');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contractorId': contractorId,
          'urgency': urgency,
          'fromDate': fromDate,
          'toDate': toDate,
        }),
      );
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching contractor availability: $e');
      }
      throw Exception("Couldn\'t load availability.");
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

    final resp = await _post('homeowner-rewards-v2-supabase', {'userId': uid});
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
    final future = _post('homeowner-profile-v2-supabase', {
      'action': 'get',
      'userId': uid,
    });
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
    final result = await _post('homeowner-profile-v2-supabase', {
      'action': 'update_profile',
      'userId': uid,
      'givenName': givenName,
      'familyName': familyName,
      'phone': phone,
      'email': email,
      'userName': userName,
      'preferredContact': preferredContact,
      'marketingConsent': marketingConsent,
    });
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

    final result = await _post('homeowner-profile-v2-supabase', body);
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

    final result = await _post('homeowner-profile-v2-supabase', body);
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

    final result = await _post('homeowner-profile-v2-supabase', {
      'action': 'set_default_address',
      'userId': uid,
      'addressId': addressId,
    });
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

    final result = await _post('homeowner-profile-v2-supabase', {
      'action': 'remove_address',
      'userId': uid,
      'addressId': addressId,
    });
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
      'propertyZip': booking['address_zip'],
    };

    final url = Uri.parse('${baseUrl}booking-commit-v2-supabase');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>)
        throw Exception('Invalid response format');

      if (data['ok'] != true) {
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
    final url = Uri.parse('${baseUrl}public-contractor-search-v2-supabase');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'zip': zip,
          'categorySlug': categorySlug,
          'urgency': urgency,
        }),
      );
      if (response.body.isEmpty) throw Exception('Empty response');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching contractors: $e');
      }
      throw Exception('Search failed.');
    }
  }

  // Email verification endpoints
  Future<Map<String, dynamic>> sendVerificationEmail(String email) async {
    return await _post('homeowner-verify-v2-supabase', {
      'action': 'send',
      'email': email,
    });
  }

  Future<Map<String, dynamic>> confirmVerification(String token) async {
    final uid = _userId;
    return await _post('homeowner-verify-v2-supabase', {
      'action': 'confirm',
      if (uid != null) 'userId': uid,
      'token': token,
    });
  }

  // ALIASES for mocked screens
  Future<Map<String, dynamic>> getProfile() => fetchProfile();

  Future<void> createWorkOrder(Map<String, dynamic> reqBody) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockIdCounter++;
    _mockWorkOrders.add({
      'id': _mockIdCounter,
      'status': 'active',
      'workOrderType': reqBody['workOrderType'] ?? 'Flat/Hourly',
      'createdAt': DateTime.now().toIso8601String(),
      'startsAt': reqBody['startsAt'] ??
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'description': reqBody['issueDescription'] ?? 'New Service Request',
      'address': reqBody['address'] ?? {},
      'contractor': {
        'id': reqBody['proId'] ?? '1',
        'businessName': 'Mocked Contractor',
        'profilePhotoUrl': null,
      },
    });
    _invalidateWorkOrderCache();
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

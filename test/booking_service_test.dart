import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:homeowners_app/services/homeowner_service.dart';
import 'package:homeowners_app/services/stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <Map<String, dynamic>>[];
  var rejectCap = false;
  final api = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.contains('booking-commit')) {
      requests.add(body);
      if (rejectCap) {
        return http.Response(
            jsonEncode({
              'success': true,
              'ok': false,
              'reason': 'slot_unavailable',
            }),
            200);
      }
    }
    return http.Response(
        jsonEncode({
          'success': true,
          'ok': true,
          'tabs': <String, dynamic>{},
          'profile': <String, dynamic>{},
          'addresses': <dynamic>[],
        }),
        200);
  });

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    final token =
        'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({
                  'exp': exp,
                  'sub': 'test-homeowner'
                }))).replaceAll('=', '')}.test';
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async => http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'test-homeowner',
              'aud': 'authenticated',
              'email': 'homeowner@example.com',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{}
            },
          }),
          200,
          headers: {'content-type': 'application/json'})),
    );
    await AuthService.instance
        .login(email: 'homeowner@example.com', password: 'test-password');
  });
  tearDownAll(() async {
    await AuthService.instance.logout();
    await Supabase.instance.dispose();
  });
  setUp(() {
    requests.clear();
    rejectCap = false;
  });

  test('cap acceptance retains the server action and chosen appointment',
      () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.respondToCap(
          workOrderId: 101,
          accept: true,
          contractorId: 'contractor-7',
          startsAt: '2026-12-01T10:00:00Z',
          endsAt: '2026-12-01T11:00:00Z');
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single, containsPair('action', 'quote_accept'));
    expect(requests.single, containsPair('startsAt', '2026-12-01T10:00:00Z'));
    expect(requests.single, containsPair('requesterUserId', 'test-homeowner'));
    expect(requests.single, containsPair('contractorId', 'contractor-7'));
  });
  test('declining retains the server action and explicit reason', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.respondToCap(
          workOrderId: 102, accept: false, reason: 'homeowner_declined_cap');
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single, containsPair('action', 'quote_decline'));
    expect(requests.single, containsPair('reason', 'homeowner_declined_cap'));
  });
  test('a rejected cap is not treated as successful approval', () async {
    rejectCap = true;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.respondToCap(
              workOrderId: 103,
              accept: true,
              contractorId: 'contractor-7',
              startsAt: '2026-12-01T10:00:00Z',
              endsAt: '2026-12-01T11:00:00Z'),
          throwsException);
    }, () => api);
  });
  test('booking limits retain actionable copy', () {
    final message =
        HomeownerService.instance.bookingErrorMessage(Exception('booking_cap'));
    expect(message, contains('maximum number of open bookings'));
    expect(message, contains('complete or cancel'));
  });
  test('the existing quote-request booking remains supported without a slot',
      () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.commitBooking(
        contractorId: 'contractor-7',
        action: 'quote_request',
        urgency: 'standard',
        booking: {
          'service_category': 'Roofing',
          'work_order_type': 'quote_request'
        },
      );
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single, containsPair('action', 'quote_request'));
    expect(requests.single.containsKey('startsAt'), isFalse);
    expect(requests.single.containsKey('endsAt'), isFalse);
  });
  test('messaging resolves the contractor user ID before the profile ID', () {
    expect(
        StreamService.instance.resolveMessagingUserId({
          'contractorId': 'profile_100',
          'userId': '20',
          'profile': {'user_id': '21'},
        }),
        '20');
  });
}

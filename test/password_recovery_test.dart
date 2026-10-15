import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var rejectPassword = false;
  const user = {
    'id': 'recovery-user',
    'aud': 'authenticated',
    'email': 'recovery@example.com',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{}
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'sub': 'recovery-user',
        })))
        .replaceAll('=', '');
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage()),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/verify'))
          return http.Response(
              jsonEncode({
                'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
                'refresh_token': 'test-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': user,
              }),
              200,
              headers: {'content-type': 'application/json'});
        if (request.url.path.endsWith('/user'))
          return http.Response(
              jsonEncode(rejectPassword
                  ? {'message': 'Password rejected', 'code': 'weak_password'}
                  : user),
              rejectPassword ? 422 : 200,
              headers: {'content-type': 'application/json'});
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    await AuthService.instance.loadSession();
  });
  tearDownAll(() async {
    await AuthService.instance.logout();
    await Supabase.instance.dispose();
  });
  test(
      'reset email uses the registered mobile callback for any entered account',
      () async {
    await AuthService.instance.requestPasswordReset('  recovery@example.com  ');
    final request = requests.lastWhere((r) => r.url.path.endsWith('/recover'));
    expect(jsonDecode(request.body)['email'], 'recovery@example.com');
    expect(request.url.queryParameters['redirect_to'],
        'com.tradeworksai.homeowners://login-callback');
    expect(AuthService.instance.isPasswordRecovery, isFalse);
    expect(AuthService.instance.isAuthenticated, isFalse);
  });
  test('unverified reset cannot update a password', () async {
    final before = requests.length;
    await expectLater(
        AuthService.instance
            .performPasswordReset(token: '', password: 'new-password'),
        throwsA(isA<AuthException>()));
    expect(requests.length, before);
  });
  test('verified recovery opens reset mode, not normal signed-in app',
      () async {
    await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        email: 'recovery@example.com',
        token: '12345678');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(AuthService.instance.isPasswordRecovery, isTrue);
    expect(AuthService.instance.isAuthenticated, isFalse);
  });
  test('recovery stays available if the server rejects the new password',
      () async {
    rejectPassword = true;
    await expectLater(
        AuthService.instance
            .performPasswordReset(token: '', password: 'new-password'),
        throwsA(isA<AuthException>()));
    expect(AuthService.instance.isPasswordRecovery, isTrue);
    rejectPassword = false;
  });
  test(
      'verified link updates without asking for an OTP again and revokes other sessions',
      () async {
    final verifies =
        requests.where((r) => r.url.path.endsWith('/verify')).length;
    await AuthService.instance
        .performPasswordReset(token: '', password: 'new-password');
    expect(
        requests.where((r) => r.url.path.endsWith('/verify')).length, verifies);
    expect(
        requests.any((r) => r.url.path.endsWith('/user') && r.method == 'PUT'),
        isTrue);
    expect(
        requests.any((r) =>
            r.url.path.endsWith('/logout') &&
            r.url.queryParameters['scope'] == 'others'),
        isTrue);
    expect(AuthService.instance.isPasswordRecovery, isFalse);
    expect(AuthService.instance.pendingPasswordResetEmail, isNull);
  });
}

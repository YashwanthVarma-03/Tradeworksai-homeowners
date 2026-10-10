import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/work_orders/work_order_detail.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:homeowners_app/services/homeowner_service.dart';
import 'package:homeowners_app/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    final token =
        'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({
                  'exp': exp,
                  'sub': 'arrival-test-homeowner',
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
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'arrival-test-homeowner',
                'aud': 'authenticated',
                'email': 'arrival@example.com',
                'created_at': '2026-01-01T00:00:00Z',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    await AuthService.instance
        .login(email: 'arrival@example.com', password: 'test-password');
  });

  tearDownAll(() async {
    await AuthService.instance.logout();
    await Supabase.instance.dispose();
  });

  testWidgets('open homeowner work order updates when the pro marks arrival',
      (tester) async {
    String status = 'en_route';
    Map<String, dynamic> job() => {
          'workOrderId': 24163,
          'status': status,
          'serviceCategory': 'AC repair',
          'pro': {'businessName': 'Hutchins Plumbing'},
          'timeline': {
            'enRouteAt': '2026-10-09T10:00:00Z',
            if (status == 'arrived') 'arrivedAt': '2026-10-09T10:30:00Z',
          },
        };

    final client = MockClient((request) async {
      if (request.url.path.contains('work-orders-list')) {
        return http.Response(
            jsonEncode({
              'success': true,
              'tabs': {
                'active': [job()],
                'scheduled': <dynamic>[],
                'history': <dynamic>[],
              },
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'profile': <String, dynamic>{},
            'rewards': <String, dynamic>{},
          }),
          200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: WorkOrderDetailScreen(job: job()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hutchins Plumbing has arrived'), findsNothing);

      status = 'arrived';
      await HomeownerService.instance.syncInBackground();
      await tester.pumpAndSettle();
      expect(find.text('Hutchins Plumbing has arrived'), findsOneWidget);
      expect(find.text('Report a no-show'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}

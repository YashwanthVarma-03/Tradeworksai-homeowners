import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homeowners_app/screens/pro_profile.dart';
import 'package:homeowners_app/widgets/capsules.dart';
import 'package:homeowners_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'profile keeps the search snapshot and does not change after opening',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);
    var calls = 0;
    final profile = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProProfileScreen(pro: {
          'slug': 'stable-profile-regression',
          'contractorId': 700,
          'contractorServiceId': 701,
          'businessName': 'Stable Plumbing',
          'nextAvailable': 'Tomorrow',
          'serviceName': 'Pipe repair',
          'fromPrice': 90,
          'workOrderType': 'rate_card',
        }),
      ));
      await tester.pump();
      profile.complete(http.Response(
          jsonEncode({
            'profile': {
              'businessName': 'Stable Plumbing',
              'about': 'Experienced local plumbing team.',
              'nextAvailable': null,
              'services': [
                {
                  'contractor_service_id': 701,
                  'name': 'Pipe repair',
                  'category': 'Plumbing',
                  'rate_amount': 90,
                  'work_order_type': 'rate_card'
                }
              ],
            }
          }),
          200));
      await tester.pumpAndSettle();
      expect(find.text('Next: Tomorrow'), findsOneWidget);
      final before = tester.getTopLeft(find.byType(AvailabilityCapsule));
      final price = tester.getTopLeft(find.textContaining(r'$90.00').first);
      expect(before.dx, greaterThan(price.dx));
      expect((before.dy - price.dy).abs(), lessThan(12));
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Next: Tomorrow'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(AvailabilityCapsule)), before);
      expect(calls, 1, reason: 'No delayed availability round-trip.');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) {
              calls++;
              expect(request.url.path, '/public/contractor-profile-get');
              return profile.future;
            }));
  });
}

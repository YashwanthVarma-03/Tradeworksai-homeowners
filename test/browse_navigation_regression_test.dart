import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/homeowner_service.dart';
import 'package:homeowners_app/services/service_location.dart';
import 'package:homeowners_app/theme.dart';
import 'support/catalog_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCatalogFixture);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Home category opens results without waiting for ZIP coverage',
      (tester) async {
    await ServiceLocation.save(zip: '33591', locationName: 'Home');
    final coverage = Completer<http.Response>();
    var searches = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SearchTab(
          initialCategory: 'Plumbing',
          onBookPro: (_) {},
        )),
      ));
      await tester.pumpAndSettle();
      expect(searches, 1);
      expect(find.text('Result Plumbing'), findsOneWidget);
      expect(find.text('Popular services'), findsNothing);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode!
              .hasFocus,
          isFalse);
      coverage.complete(http.Response(
          '{"zip":"33591","categories":[{"categoryName":"Plumbing","proCount":0}]}',
          200));
      await tester.pumpAndSettle();
      expect(find.text('Result Plumbing'), findsOneWidget);
      expect(find.text('1 pro'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await ServiceLocation.clear();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('zip-coverage-get')) {
                return coverage.future;
              }
              expect(request.url.path, '/public/contractor-search');
              expect(jsonDecode(request.body)['categorySlug'], 'plumbing');
              searches++;
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'covered': true,
                    'count': 1,
                    'results': [
                      {
                        'contractorId': 500,
                        'businessName': 'Result Plumbing',
                        'workOrderType': 'rate_card',
                        'fromPrice': 90,
                        'nextAvailable': null,
                      }
                    ],
                  }),
                  200);
            }));
  });

  test('concurrent identical searches share one request and reuse its result',
      () async {
    final response = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(() async {
      final first = HomeownerService.instance
          .searchPros(zip: '33592', categorySlug: 'plumbing');
      final second = HomeownerService.instance
          .searchPros(zip: '33592', categorySlug: 'plumbing');
      await Future<void>.delayed(Duration.zero);
      response.complete(http.Response('{"success":true,"results":[]}', 200));
      expect(await first, await second);
      await HomeownerService.instance
          .searchPros(zip: '33592', categorySlug: 'plumbing');
      expect(requests, 1);
    },
        () => MockClient((request) {
              requests++;
              return response.future;
            }));
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/service_location.dart';

void main() {
  testWidgets(
      'Browse lazily renders and reveals a large category while deferring others',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocation.save(zip: '90210', locationName: 'Test area');
    var searchCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('zip-coverage')) {
        return http.Response(
            jsonEncode({
              'success': true,
              'zip': '90210',
              'categories': [
                {'categoryName': 'Plumbing', 'proCount': 100},
                {'categoryName': 'Electrical', 'proCount': 100},
              ]
            }),
            200);
      }
      searchCalls++;
      return http.Response(
          jsonEncode({
            'success': true,
            'covered': true,
            'count': 100,
            'results': List.generate(
                100,
                (i) => {
                      'contractorId': 'pro-$i',
                      'slug': 'pro-$i',
                      'businessName': 'Test Pro $i',
                    })
          }),
          200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SearchTab(onBookPro: (_) {}),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(searchCalls, 1);
      expect(find.text('12 pros loaded for 90210'), findsOneWidget);
      // Only cards near the viewport exist, even though the API returned 100.
      expect(find.textContaining('Test Pro').evaluate().length, lessThan(12));
      final scroll = find.byType(CustomScrollView);
      for (var i = 0; i < 12; i++) {
        await tester.drag(scroll, const Offset(0, -650));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(searchCalls, 1);
      // Scroll back to read the counter without loading another category.
      final scrollable = tester.state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first);
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('12 pros loaded for 90210'), findsNothing);
      expect(find.textContaining('pros loaded for 90210'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await ServiceLocation.clear();
    }, () => client);
  });
}

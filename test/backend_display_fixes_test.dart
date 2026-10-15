import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/service_catalog.dart';
import 'package:homeowners_app/utils/paid_amount.dart';
import 'package:homeowners_app/utils/rewards_data.dart';

Map<String, dynamic> service(int id, {bool active = true}) => {
      'subcategory_name': 'Service $id',
      'subcategory_slug': 'service-$id',
      'category_name': 'Test category',
      'category_slug': 'test',
      'is_active': active,
    };

void main() {
  test('public catalogue transport never inherits a signed-in customer token',
      () async {
    ServiceCatalog.fetchPage = null;
    await http.runWithClient(() async {
      await ServiceCatalog.load(forceRefresh: true);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/rest/v1/service_categories');
              expect(request.url.queryParameters['is_active'], 'eq.true');
              expect(request.url.queryParameters['limit'], '500');
              expect(request.headers['authorization'], isNull);
              expect(request.headers['apikey'], isNotEmpty);
              return http.Response(jsonEncode([service(1)]), 200);
            }));
    expect(ServiceCatalog.items.single.name, 'Service 1');
  });
  test('catalogue keeps every valid active service and removes duplicates', () {
    final rows = [
      service(1),
      service(1),
      service(2),
      service(3, active: false),
      <String, dynamic>{}
    ];
    expect(ServiceCatalog.parse(rows).map((s) => s.name),
        ['Service 1', 'Service 2']);
  });
  test(
      'catalogue paginates, shares in-flight requests and retains real data on failure',
      () async {
    var calls = 0;
    final ready = Completer<void>();
    ServiceCatalog.fetchPage = (from, to) async {
      calls++;
      await ready.future;
      return List.generate(from == 0 ? 500 : 2, (i) => service(from + i));
    };
    final first = ServiceCatalog.load(forceRefresh: true);
    final second = ServiceCatalog.load(forceRefresh: true);
    ready.complete();
    await Future.wait([first, second]);
    expect(calls, 2);
    expect(ServiceCatalog.items.length, 502);
    expect(ServiceCatalog.names.length, 502);
    ServiceCatalog.fetchPage = (_, __) async => throw Exception('offline');
    await ServiceCatalog.load(forceRefresh: true);
    expect(ServiceCatalog.items.length, 502);
    expect(ServiceCatalog.error, isNotNull);
    ServiceCatalog.fetchPage = (_, __) async => [];
    await ServiceCatalog.load(forceRefresh: true);
    expect(ServiceCatalog.items, isEmpty);
    expect(ServiceCatalog.loaded, isTrue);
    ServiceCatalog.fetchPage = null;
  });
  test('live rewards schema prefers earningBands and maps bonus/at', () {
    final normalized = normalizeRewards({
      'earningBands': [
        {'floor': 0, 'ceiling': 2500, 'rate': .03}
      ],
      'bands': [
        {'from': 0, 'upTo': 999, 'rate': .03}
      ],
      'milestones': [
        {'at': 2500, 'bonus': 50, 'reached': true, 'reachedAt': '2026-08-17'}
      ],
      'ledger': [
        {
          'type': 'milestone_bonus',
          'milestoneThreshold': 2500,
          'createdAt': '2026-08-17',
          'expiresAt': '2026-11-15'
        }
      ],
    });
    expect(normalized['bands'][0]['ceiling'], 2500);
    expect(normalized['milestones'][0]['amount'], 50);
    expect(normalized['milestones'][0]['threshold'], 2500);
    expect(normalized['milestones'][0]['expiresAt'], '2026-11-15');
    expect(
        normalizeRewards({
          'bands': [
            {'from': 2500, 'upTo': 6000}
          ]
        })['bands'][0]['floor'],
        2500);
    expect(normalizeRewards({})['bands'], isEmpty);
  });
  test('history uses actual customer payment, including zero, not quotes', () {
    expect(
        customerPaidAmount({
          'receiptReward': {'customerPaidAmount': 111},
          'invoiceAmount': 200
        }),
        111);
    expect(
        customerPaidAmount({
          'receiptReward': {'customerPaidAmount': 0},
          'price': 40
        }),
        0);
    expect(customerPaidAmount({'paidAmount': '149.00'}), 149);
    expect(
        customerPaidAmount({
          'status': 'completed',
          'invoiceAmount': 200,
          'creditsApplied': 89
        }),
        111);
    expect(
        customerPaidAmount(
            {'status': 'completed', 'price': 149, 'quoteAmount': 149}),
        isNull);
    expect(
        customerPaidAmount(
            {'status': 'accepted', 'invoiceAmount': 200, 'creditsApplied': 0}),
        isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/inbox_tab.dart';
import 'package:homeowners_app/utils/chat_work_order.dart';

void main() {
  test('mobile notification feed is title-only with optional job context', () {
    final item = ActivityItem.fromApi({
      'id': 1,
      'title': 'Your visit is scheduled',
      'type': 'status',
      'created_at': '2026-10-16T08:00:00Z',
      'read_at': null,
      'work_order_id': 42,
      'wo_number': 'WO-900',
      'pro_name': 'Your pro',
    });
    expect(item.title, 'Your visit is scheduled');
    expect(item.body, isEmpty);
    expect(item.workOrderId, 42);
    expect(item.workOrderLabel, 'WO-900');
    expect(item.unread, isTrue);
  });

  test('read timestamps are authoritative over boolean aliases', () {
    expect(
        ActivityItem.fromApi({'read_at': null, 'read': true}).unread, isTrue);
    expect(
        ActivityItem.fromApi({'read_at': '2026-10-16T08:00:00Z', 'read': false})
            .unread,
        isFalse);
    expect(ActivityItem.fromApi({'readAt': '2026-10-16T08:00:00Z'}).unread,
        isFalse);
    expect(ActivityItem.fromApi({}).unread, isTrue);
    expect(
        ActivityItem.fromApi({'read_at': null, 'readAt': 'stale-alias'}).unread,
        isTrue);
  });

  test('chat finds shared work orders by user identity and deduplicates tabs',
      () {
    final job = {
      'id': 42,
      'pro': {'id': 999, 'userId': 77}
    };
    final jobs = chatWorkOrders({
      'tabs': {
        'active': [
          job,
          {'id': 43, 'assigned_contractor_user_id': 77}
        ],
        'history': [
          job,
          {
            'id': 44,
            'contractor': {'user_id': 77}
          }
        ],
      },
    }, '77');
    expect(jobs.map((job) => job['id']), [42, 43, 44]);
  });

  test(
      'chat never matches a profile id, homeowner id, or business name as user id',
      () {
    expect(
        chatWorkOrders({
          'tabs': {
            'active': [
              {
                'id': 1,
                'userId': 77,
                'pro': {'id': 77, 'userId': 88, 'name': 'Same business'}
              },
              {'id': 2, 'proName': 'Same business'},
              {
                'id': 3,
                'pro': {'id': 77}
              },
              {'id': 0, 'contractorUserId': 77},
            ],
          },
        }, '77'),
        isEmpty);
    expect(isWorkOrderWithPro({'contractorUserId': ''}, ''), isFalse);
  });
}

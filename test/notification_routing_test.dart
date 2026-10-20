import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/notification_preferences.dart';
import 'package:homeowners_app/services/notification_routing.dart';

void main() {
  group('notification routing contract', () {
    const cases = <String, NotificationDestination>{
      'booking_confirmed': NotificationDestination.activity,
      'en_route': NotificationDestination.activity,
      'in_progress': NotificationDestination.activity,
      'cap': NotificationDestination.capApproval,
      'quote_ready': NotificationDestination.capApproval,
      'estimate': NotificationDestination.capApproval,
      'reschedule_proposed': NotificationDestination.rescheduleProposal,
      'reschedule_accepted': NotificationDestination.activity,
      'booking_cancelled': NotificationDestination.activity,
      'reminder': NotificationDestination.activity,
      'receipt': NotificationDestination.activity,
      'upload_receipt': NotificationDestination.jobMoney,
      'leave_review': NotificationDestination.leaveReview,
      'no_show_reported': NotificationDestination.noShowReply,
      'completed': NotificationDestination.activity,
      'expiring_soon': NotificationDestination.activity,
      'message': NotificationDestination.chat,
      'promo': NotificationDestination.activity,
      'unrecognized': NotificationDestination.activity,
    };

    for (final entry in cases.entries) {
      test('${entry.key} resolves to ${entry.value.name}', () {
        final message = RemoteMessage(data: {
          'type': entry.key,
          if (entry.key == 'message') 'channel_id': 'messaging:abc',
          if (entry.key != 'message') 'work_order_id': '24144',
        });
        final route = NotificationRouteData.fromData(message.data);
        expect(route.destination, entry.value);
        expect(route.id, entry.key == 'message' ? 'messaging:abc' : '24144');
      });
    }

    test('accepts legacy notification_type and work_order_id fields', () {
      final route = NotificationRouteData.fromData(const {
        'notification_type': 'cap',
        'work_order_id': 42,
      });
      expect(route.destination, NotificationDestination.capApproval);
      expect(route.workOrderId, 42);
    });

    test('malformed work-order and chat payloads fall back to Activity', () {
      expect(
        NotificationRouteData.fromData(const {
          'type': 'cap',
          'work_order_id': 'not-a-number',
        }).destination,
        NotificationDestination.activity,
      );
      expect(
        NotificationRouteData.fromData(const {'type': 'message'}).destination,
        NotificationDestination.activity,
      );
      expect(
        NotificationRouteData.fromData(const {'type': 'completed'}).destination,
        NotificationDestination.activity,
      );
    });
  });

  test('never mistakes an Activity row ID for a work order or channel', () {
    for (final type in ['cap', 'message', 'completed']) {
      expect(
          NotificationRouteData.fromData({'type': type, 'id': 1056})
              .destination,
          NotificationDestination.activity);
    }
  });

  test('invalid positive IDs and incomplete channels fall back safely', () {
    for (final id in ['0', '-2', 'not-an-id']) {
      expect(
          NotificationRouteData.fromData({
            'type': 'cap',
            'work_order_id': id,
          }).destination,
          NotificationDestination.activity);
    }
    expect(
        NotificationRouteData.fromData(const {
          'type': 'message',
          'channel_id': 'messaging:',
        }).destination,
        NotificationDestination.activity);
  });

  test('resolved actions open the job in Activity and Activity from push', () {
    final data = {'type': 'cap', 'work_order_id': 42, 'waiting_on_you': false};
    expect(NotificationRouteData.fromData(data).destination,
        NotificationDestination.activity);
    expect(NotificationRouteData.fromData(data, fromActivity: true).destination,
        NotificationDestination.workOrder);
    expect(
        notificationIsAction(
            {'type': 'reschedule_accepted', 'waiting_on_you': true}),
        isFalse);
    expect(
        notificationType(
            {'type': 'quote_ready', 'work_order_type': 'quote_request'}),
        'estimate');
    expect(notificationType({'type': 'something-new'}), 'status');
    expect(
        NotificationRouteData.fromData({
          'type': 'receipt',
          'work_order_id': 42,
          'waiting_on_you': true
        }).destination,
        NotificationDestination.jobMoney);
  });

  group('push registration contract', () {
    test('maps every supported platform value', () {
      expect(
        pushPlatformName(isWeb: true, platform: TargetPlatform.windows),
        'web',
      );
      expect(
        pushPlatformName(isWeb: false, platform: TargetPlatform.iOS),
        'ios',
      );
      expect(
        pushPlatformName(isWeb: false, platform: TargetPlatform.android),
        'android',
      );
    });

    test('uses opt-out defaults and emits the nested API payload', () {
      const preferences = NotificationPreferences();
      expect(preferences.pushStatus, isTrue);
      expect(preferences.pushMessages, isTrue);
      expect(preferences.pushCredits, isTrue);
      expect(preferences.pushPromos, isFalse);
      expect(preferences.emailReceipts, isTrue);
      expect(preferences.emailPromos, isFalse);
      expect(preferences.toApiPayload(), {
        'push': {
          'status': true,
          'messages': true,
          'credits': true,
          'promos': false,
        },
        'email': {'receipts': true, 'promos': false},
      });
    });

    test('reads nested preferences from the account response', () {
      final preferences = NotificationPreferences.fromAccount(const {
        'preferences': {
          'push': {
            'status': false,
            'messages': true,
            'credits': false,
            'promos': true,
          },
          'email': {'receipts': false, 'promos': true},
        },
      });
      expect(preferences.pushStatus, isFalse);
      expect(preferences.pushMessages, isTrue);
      expect(preferences.pushCredits, isFalse);
      expect(preferences.pushPromos, isTrue);
      expect(preferences.emailReceipts, isFalse);
      expect(preferences.emailPromos, isTrue);
    });
  });

  group('activity arrival tracking', () {
    test('baselines existing feed rows and alerts only for later IDs', () {
      final tracker = ActivityArrivalTracker();
      expect(
          tracker.takeNew([
            {'id': 'old'}
          ]),
          isEmpty);
      expect(
        tracker.takeNew([
          {'id': 'new', 'title': 'Visit changed'},
          {'id': 'old'},
        ]),
        [
          {'id': 'new', 'title': 'Visit changed'},
        ],
      );
      expect(
          tracker.takeNew([
            {'id': 'new'}
          ]),
          isEmpty);
    });

    test('ignores rows without IDs and clears history between users', () {
      final tracker = ActivityArrivalTracker();
      expect(tracker.takeNew([]), isEmpty);
      expect(
          tracker.takeNew([
            {'title': 'No ID'}
          ]),
          isEmpty);
      expect(
          tracker.takeNew([
            {'id': 'first'}
          ]),
          hasLength(1));
      tracker.reset();
      expect(
          tracker.takeNew([
            {'id': 'first'}
          ]),
          isEmpty);
    });
  });
}

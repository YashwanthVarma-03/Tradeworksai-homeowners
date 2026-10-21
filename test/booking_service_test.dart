import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:homeowners_app/services/homeowner_service.dart';
import 'package:homeowners_app/services/stream_service.dart';
import 'package:homeowners_app/screens/chat_screen.dart';
import 'package:homeowners_app/screens/work_orders/no_show_reply.dart';
import 'package:homeowners_app/screens/work_orders/leave_review.dart';
import 'package:homeowners_app/screens/work_orders/work_order_detail.dart';
import 'package:homeowners_app/screens/inbox_tab.dart';
import 'package:homeowners_app/screens/book_flow.dart';
import 'package:homeowners_app/screens/pro_profile.dart';
import 'package:homeowners_app/screens/search_tab.dart';
import 'package:homeowners_app/services/service_location.dart';
import 'package:homeowners_app/widgets/capsules.dart';
import 'package:homeowners_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <Map<String, dynamic>>[];
  var rejectCap = false;
  final api = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.contains('booking-commit') ||
        request.url.path.contains('work-orders-action')) {
      requests.add(body);
      if (rejectCap && body['action'] == 'approve_cap') {
        return http.Response(
            jsonEncode({
              'success': true,
              'ok': false,
              'reason': 'slot_unavailable',
            }),
            200);
      }
      if (body['action'] == 'hold') {
        return http.Response(
            jsonEncode({'success': true, 'ok': true, 'holdId': 123}), 200);
      }
    }
    return http.Response(
        jsonEncode({
          'success': true,
          'ok': true,
          'workOrderId': 9001,
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

  for (final status in [200, 409]) {
    for (final field in ['error', 'reason', 'code']) {
      test(
          'calendar blocked $status $field rejects the hold without committing',
          () async {
        final actions = <String>[];
        await http.runWithClient(() async {
          await expectLater(
            HomeownerService.instance.commitBooking(
              contractorId: 'calendar-test',
              action: 'commit',
              urgency: 'standard',
              booking: {'contractor_service_id': 246, 'address_zip': '33602'},
              startsAt: '2026-11-01T10:00:00Z',
              endsAt: '2026-11-01T12:00:00Z',
            ),
            throwsA(predicate((Object e) =>
                HomeownerService.instance.bookingErrorMessage(e) ==
                'That time was just taken. Pick another window.')),
          );
        },
            () => MockClient((request) async {
                  actions.add(
                      (jsonDecode(request.body) as Map)['action'] as String);
                  return http.Response(
                      jsonEncode({
                        'ok': false,
                        'error': 'Booking rejected',
                        field: 'CALENDAR_BLOCKED',
                      }),
                      status);
                }));
        expect(actions, ['hold']);
      });
    }
  }

  for (final scenario in ['search-null', 'fresh-null', 'empty', 'day']) {
    testWidgets('availability capsule handles $scenario for signed-in search',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 1400);
      addTearDown(tester.view.reset);
      final zip = '3370${[
        'search-null',
        'fresh-null',
        'empty',
        'day'
      ].indexOf(scenario)}';
      await ServiceLocation.save(zip: zip, locationName: 'Tampa');
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final date = tomorrow.toIso8601String().substring(0, 10);
      var availabilityCalls = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
              body: SearchTab(
            initialSearchQuery: 'Plumbing',
            onBookPro: (_) {},
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Calendar Test Pro'), findsOneWidget);
        expect(find.byType(AvailabilityCapsule),
            scenario == 'search-null' ? findsNothing : findsOneWidget);
        if (scenario == 'day') {
          expect(find.text('Next: Tomorrow'), findsOneWidget);
          final rating = tester.getCenter(find.byType(RatingCapsule));
          final availability =
              tester.getCenter(find.byType(AvailabilityCapsule));
          expect(rating.dx, lessThan(availability.dx));
          expect(rating.dy, closeTo(availability.dy, 1));
        }
        expect(availabilityCalls, 0,
            reason: 'Search already supplies availability; no per-card calls.');
        expect(find.text('Availability pending'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await ServiceLocation.clear();
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('contractor-search')) {
                  return http.Response(
                      jsonEncode({
                        'success': true,
                        'covered': true,
                        'results': [
                          {
                            'contractorId': 'calendar-$scenario',
                            'contractorServiceId': '246',
                            'businessName': 'Calendar Test Pro',
                            'verifiedRating': 4.8,
                            'verifiedCount': 32,
                            'workOrderType': scenario == 'search-null'
                                ? 'quote_request'
                                : 'nte',
                            'nextAvailable': scenario == 'search-null'
                                ? null
                                : '${date}T10:00:00Z',
                          }
                        ],
                      }),
                      200);
                }
                if (request.url.path.endsWith('availability-get')) {
                  availabilityCalls++;
                  return http.Response(
                      jsonEncode({
                        if (scenario == 'fresh-null') 'nextAvailable': null,
                        'slots': scenario == 'empty'
                            ? []
                            : [
                                {
                                  'start': '${date}T10:00:00Z',
                                  'end': '${date}T12:00:00Z',
                                }
                              ],
                      }),
                      200);
                }
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'categories': [
                        {'categoryName': 'Plumbing', 'proCount': 1}
                      ],
                    }),
                    200);
              }));
    });
  }

  test('support sends topic labels to the live route and returns a reference',
      () async {
    await http.runWithClient(() async {
      final result = await HomeownerService.instance.submitSupportRequest(
          topic: 'Service credits',
          message: 'Please check my credits.',
          workOrderId: 24144);
      expect(result?['reference'], 'SR-123');
    },
        () => MockClient((request) async {
              expect(request.url.path, '/homeowner/support-request');
              expect(jsonDecode(request.body),
                  containsPair('topic', 'Service credits'));
              return http.Response(
                  '{"success":true,"reference":"SR-123"}', 200);
            }));
  });

  test('unavailable canonical availability is requested only once', () async {
    var count = 0;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.getContractorAvailability(
              contractorId: 'missing-pro', forceRefresh: true),
          throwsException);
    },
        () => MockClient((request) async {
              count++;
              expect(request.url.path, '/contractor/availability-get');
              return http.Response(
                  '{"success":false,"error":"not_found"}', 404);
            }));
    expect(count, 1);
  });

  testWidgets(
      'review edits use the review timestamp instead of the job timestamp',
      (tester) async {
    Map<String, dynamic>? edit;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: LeaveReviewScreen(
        job: const {
          'status': 'completed',
          'updatedAt': '2026-10-19T10:00:00Z',
          'review': {'reviewId': 84, 'updatedAt': '2026-10-16T10:00:00Z'}
        },
        jobId: 24044,
        initialRating: 4,
        hasExistingReview: true,
        initialReviewText: 'Careful work and a clean finish.',
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(edit?['expectedUpdatedAt'], '2026-10-16T10:00:00Z');
      expect(edit?['reviewId'], 84);
      await tester.pumpWidget(const SizedBox());
      await HomeownerService.instance.syncInBackground();
    },
        () => MockClient((request) async {
              final body = request.body.isEmpty
                  ? <String, dynamic>{}
                  : jsonDecode(request.body);
              if (body['action'] == 'edit_review')
                edit = Map<String, dynamic>.from(body);
              return http.Response(
                  '{"success":true,"reviewId":84,"updatedAt":"2026-10-19T11:00:00Z","tabs":{},"addresses":[]}',
                  200);
            }));
  });

  testWidgets('no-show work order reads and displays the pro reply',
      (tester) async {
    var reads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: WorkOrderDetailScreen(job: {
        'workOrderId': 24081,
        'status': 'pro_no_show',
        'proName': 'Hutchins Plumbing Co.',
      })));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
          find.text(
              'Hutchins Plumbing Co. replied: I could not enter the gate.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/no-show-case')) {
                reads++;
                expect(request.method, 'GET');
                return http.Response(
                    '{"success":true,"case":{"contractorReply":"I could not enter the gate."}}',
                    200);
              }
              return http.Response('{"success":true,"tabs":{}}', 200);
            }));
  });

  testWidgets('empty activity feed stays empty even when bookings exist',
      (tester) async {
    await http.runWithClient(() async {
      await HomeownerService.instance.fetchWorkOrders(forceRefresh: true);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: InboxActivityView())));
      await tester.pumpAndSettle();
      expect(find.text('Booking confirmed · HVAC tune-up'), findsNothing);
      expect(find.text('No activity yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.contains('notifications')) {
                return http.Response(
                    '{"success":true,"notifications":[]}', 200);
              }
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'tabs': {
                      'scheduled': [
                        {
                          'workOrderId': 24144,
                          'woNumber': 'WO-24144',
                          'status': 'accepted',
                          'serviceName': 'HVAC tune-up',
                          'createdAt': DateTime.now().toIso8601String(),
                          'scheduledStart': DateTime.now()
                              .add(const Duration(hours: 24))
                              .toIso8601String(),
                          'scheduledEnd': DateTime.now()
                              .add(const Duration(hours: 26))
                              .toIso8601String(),
                        }
                      ]
                    }
                  }),
                  200);
            }));
  });

  testWidgets(
      'failed activity feed shows retry without invented work-order events',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: InboxActivityView())));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load activity"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('No activity yet'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient(
            (request) async => http.Response('{"error":"unavailable"}', 503)));
  });

  test('notification APIs use the documented methods and payloads', () async {
    final calls = <http.Request>[];
    var unreadCount = 1;
    final client = MockClient((request) async {
      calls.add(request);
      expect(request.headers['authorization'], startsWith('Bearer '));
      if (request.url.path.endsWith('/notifications-list')) {
        return http.Response(
            jsonEncode({
              'notifications': [
                {
                  'id': 123,
                  'type': 'cap',
                  'title': 'Approve cap',
                  'read_at': null
                },
              ],
              'unreadCount': unreadCount,
            }),
            200);
      }
      if (request.url.path.endsWith('/notifications-read') ||
          request.url.path == '/notifications/read-all') {
        unreadCount = 0;
        return http.Response(jsonEncode({'success': true}), 200);
      }
      if (request.url.path.endsWith('/push-tokens') &&
          request.method == 'POST') {
        return http.Response(jsonEncode({'tokenId': 456}), 200);
      }
      if (request.method == 'DELETE') {
        return http.Response('', 204);
      }
      return http.Response(jsonEncode({'success': true}), 200);
    });

    await http.runWithClient(() async {
      final service = HomeownerService.instance;
      await service.fetchAccount();
      await service.updateNotificationPreferences({
        'push': {'status': false},
      });
      final feed = await service.fetchNotifications(limit: 20, offset: 40);
      expect(feed?.single['id'], 123);
      expect(service.notificationUnreadCount.value, 1);
      await service.markNotificationRead('123');
      expect(service.notificationUnreadCount.value, 0);
      await service.markAllNotificationsRead();
      expect(service.notificationUnreadCount.value, 0);
      final tokenId = await service.registerPushDevice(
        token: 'device-token',
        platform: 'ios',
      );
      expect(tokenId, '456');
      await service.removePushDevice(tokenId!);
    }, () => client);

    expect(calls.map((request) => request.method), [
      'GET',
      'PATCH',
      'POST',
      'POST',
      'POST',
      'POST',
      'POST',
      'POST',
      'DELETE',
    ]);
    expect(calls[0].url.path, '/homeowner/account');
    expect(calls[0].url.host, 'tradeworks-api-7mobhz4bsq-ue.a.run.app');
    expect(calls[1].url.path, '/homeowner/account/notification-preferences');
    expect(jsonDecode(calls[1].body), {
      'preferences': {
        'push': {'status': false},
      },
    });
    expect(calls[2].url.queryParameters, {'limit': '20', 'offset': '40'});
    expect(jsonDecode(calls[2].body), isEmpty);
    expect(calls[3].url.path, '/homeowner/notifications-read');
    expect(jsonDecode(calls[3].body), {'id': 123});
    expect(calls[4].url.path, '/homeowner/notifications-list');
    expect(calls[5].url.path, '/notifications/read-all');
    expect(jsonDecode(calls[5].body), isEmpty);
    expect(calls[6].url.path, '/homeowner/notifications-list');
    expect(jsonDecode(calls[7].body), {
      'provider': 'fcm',
      'token': 'device-token',
      'platform': 'ios',
    });
    expect(calls[8].url.path, '/push-tokens/456');
  });

  test('notification pagination advances via query parameters', () async {
    final offsets = <int>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/homeowner/notifications-list');
      expect(request.method, 'POST');
      expect(jsonDecode(request.body), isEmpty);
      final offset = int.parse(request.url.queryParameters['offset']!);
      final limit = int.parse(request.url.queryParameters['limit']!);
      offsets.add(offset);
      return http.Response(
          jsonEncode({
            'notifications': List.generate(limit, (i) => {'id': offset + i}),
            'unreadCount': 30,
          }),
          200);
    });
    await http.runWithClient(() async {
      final first = await HomeownerService.instance
          .fetchNotifications(limit: 10, offset: 0);
      final second = await HomeownerService.instance
          .fetchNotifications(limit: 10, offset: 10);
      expect(first!.length, 10);
      expect(second!.first['id'], 10);
      expect(
          first
              .map((n) => n['id'])
              .toSet()
              .intersection(second.map((n) => n['id']).toSet()),
          isEmpty);
    }, () => client);
    expect(offsets, [0, 10]);
  });

  test('failed mark-all preserves unread count and reports failure', () async {
    final service = HomeownerService.instance;
    service.notificationUnreadCount.value = 7;
    await http.runWithClient(() async {
      await expectLater(service.markAllNotificationsRead(), throwsException);
      expect(service.notificationUnreadCount.value, 7);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/notifications/read-all');
              return http.Response(
                  '{"success":false,"error":"notification_update_failed"}',
                  503);
            }));
  });

  test('no-show reply uses dedicated route and returns case receipt', () async {
    final calls = <http.Request>[];
    await http.runWithClient(() async {
      final result = await HomeownerService.instance.replyToNoShow(
        workOrderId: 42,
        replyText: '  I was home.  ',
      );
      expect(result['caseId'], 8);
      expect(result['replyId'], 9);
      expect(result['replayed'], false);
    },
        () => MockClient((request) async {
              calls.add(request);
              expect(request.method, 'POST');
              expect(
                  request.url.path, '/homeowner/work-orders/42/no-show-reply');
              expect(request.headers['authorization'], startsWith('Bearer '));
              expect(jsonDecode(request.body), {'replyText': 'I was home.'});
              return http.Response(
                  '{"success":true,"workOrderId":42,"caseId":8,"replyId":9,"replayed":false}',
                  201);
            }));
    expect(calls.length, 1);
  });

  test('rejected no-show reply does not fall back to work-order actions',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.replyToNoShow(
            workOrderId: 42,
            replyText: 'I was home.',
          ),
          throwsException);
    },
        () => MockClient((request) async {
              calls++;
              expect(
                  request.url.path, '/homeowner/work-orders/42/no-show-reply');
              return http.Response(
                  '{"success":false,"error":"no_show_case_not_found"}', 409);
            }));
    expect(calls, 1);
  });

  test('no-show reply rejects empty and over-limit text before sending',
      () async {
    await http.runWithClient(() async {
      for (final text in [' ', 'x' * 2001]) {
        await expectLater(
            HomeownerService.instance.replyToNoShow(
              workOrderId: 42,
              replyText: text,
            ),
            throwsArgumentError);
      }
    },
        () => MockClient(
            (_) async => throw StateError('Unexpected HTTP request')));
  });

  test('chat uses canonical channel identity for new and existing threads',
      () async {
    for (final created in [true, false]) {
      await http.runWithClient(() async {
        expect(
            await HomeownerService.instance.resolveChatThread(workOrderId: 42),
            'messaging:server-channel-42');
      },
          () => MockClient((request) async {
                expect(request.method, 'POST');
                expect(request.url.path, '/shared/chat-threads');
                expect(request.headers['authorization'], startsWith('Bearer '));
                expect(jsonDecode(request.body), {'workOrderId': 42});
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'channelId': 'server-channel-42',
                      'channelType': 'messaging',
                      'created': created,
                    }),
                    created ? 201 : 200);
              }));
    }
  });

  test('invalid chat response cannot produce an invented channel', () async {
    for (final response in [
      http.Response('{"success":false,"error":"work_order_required"}', 403),
      http.Response('{"success":true}', 200),
      http.Response('{"success":true,"channelId":" "}', 201),
      http.Response('{"success":true,"channelId":42}', 201),
    ]) {
      var calls = 0;
      await http.runWithClient(() async {
        await expectLater(
            StreamService.instance.openWorkOrderChannel(
              workOrderId: 42,
            ),
            throwsException);
      },
          () => MockClient((request) async {
                calls++;
                expect(request.url.path, '/shared/chat-threads');
                return response;
              }));
      expect(calls, 1);
    }
  });

  test('a profile enquiry resolves a server thread using the profile ID',
      () async {
    await http.runWithClient(() async {
      final channel = await HomeownerService.instance
          .resolveChatThread(contractorProfileId: '900');
      expect(channel, 'messaging:tw-10-77');
    },
        () => MockClient((request) async {
              expect(request.url.path, '/shared/chat-threads');
              expect(jsonDecode(request.body), {'contractorId': '900'});
              return http.Response(
                  '{"success":true,"channelType":"messaging","channelId":"tw-10-77"}',
                  201);
            }));
  });

  testWidgets('no-show screen sends replyText and returns confirmed success',
      (tester) async {
    bool? sent;
    final calls = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              sent = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const NoShowReplyScreen(job: {'work_order_id': 42}),
                  ));
            },
            child: const Text('Open reply')),
      ))));
      await tester.tap(find.text('Open reply'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'I was waiting at home.');
      await tester.pump();
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      expect(sent, isTrue);
      expect(calls.length, 1);
      expect(jsonDecode(calls.single.body),
          {'replyText': 'I was waiting at home.'});
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              calls.add(request);
              expect(
                  request.url.path, '/homeowner/work-orders/42/no-show-reply');
              return http.Response(
                  '{"success":true,"workOrderId":42,"caseId":1,"replyId":2}',
                  201);
            }));
  });

  testWidgets('work-order chat asks backend even without a Stream user ID',
      (tester) async {
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: ChatScreen(
        contractorId: '',
        contractorName: 'Your pro',
        workOrderId: 42,
      )));
      await tester.pumpAndSettle();
      expect(calls, ['/shared/chat-threads']);
      expect(find.text('Messaging unavailable'), findsOneWidget);
    },
        () => MockClient((request) async {
              calls.add(request.url.path);
              expect(jsonDecode(request.body), {'workOrderId': 42});
              return http.Response(
                  '{"success":false,"error":"work_order_not_found"}', 404);
            }));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('profile chat requires an existing shared work order',
      (tester) async {
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: ChatScreen(
        contractorId: '77',
        contractorName: 'Your pro',
      )));
      await tester.pumpAndSettle();
      expect(calls, ['/homeowner/work-orders-list']);
      expect(
          find.text(
              'Book a service with this pro before starting a conversation.'),
          findsOneWidget);
    },
        () => MockClient((request) async {
              calls.add(request.url.path);
              return http.Response(
                  '{"success":true,"tabs":{"active":[],"scheduled":[],"history":[]}}',
                  200);
            }));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('cap acceptance retains the server action and chosen appointment',
      () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.respondToCap(
          workOrderId: 101,
          accept: true,
          expectedCap: 460,
          contractorId: 'contractor-7',
          startsAt: '2026-12-01T10:00:00Z',
          endsAt: '2026-12-01T11:00:00Z');
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single, containsPair('action', 'approve_cap'));
    expect(requests.single, containsPair('expectedCap', '460.00'));
    expect(requests.single, containsPair('startsAt', '2026-12-01T10:00:00Z'));
  });
  test('declining retains the server action and explicit reason', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.respondToCap(
          workOrderId: 102,
          accept: false,
          expectedCap: 460,
          reason: 'homeowner_declined_cap');
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single, containsPair('action', 'decline_cap'));
    expect(requests.single, containsPair('reason', 'homeowner_declined_cap'));
  });
  test('cap approval sends the chosen credit once', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.respondToCap(
        workOrderId: 101,
        accept: true,
        expectedCap: 460,
        contractorId: 'contractor-7',
        startsAt: '2026-12-01T10:00:00Z',
        endsAt: '2026-12-01T12:00:00Z',
        creditAmount: 20,
        creditRequestId: '2337b617-b21d-4815-a2a6-a0e5a10bf784',
      );
    }, () => api);
    final request =
        requests.singleWhere((row) => row['action'] == 'approve_cap');
    expect(request['serviceCreditAmount'], '20.00');
    expect(request['applyServiceCredit'], true);
    expect(request['creditRequestId'], '2337b617-b21d-4815-a2a6-a0e5a10bf784');
  });

  test('free estimate acceptance uses quote_accept with credit', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.respondToEstimate(
        workOrderId: 202,
        accept: true,
        contractorId: 'contractor-7',
        startsAt: '2026-12-02T10:00:00Z',
        endsAt: '2026-12-02T12:00:00Z',
        creditAmount: 15,
        creditRequestId: '2337b617-b21d-4815-a2a6-a0e5a10bf785',
      );
    }, () => api);
    final request =
        requests.singleWhere((row) => row['action'] == 'quote_accept');
    expect(request['serviceCreditAmount'], '15.00');
    expect(request['applyServiceCredit'], true);
    expect(request['contractorId'], 'contractor-7');
  });
  test('a rejected cap is not treated as successful approval', () async {
    rejectCap = true;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.respondToCap(
              workOrderId: 103,
              accept: true,
              expectedCap: 460,
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
  testWidgets(
      'profile fetches the selected offering window and keeps empty reviews',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);
    final slotDay = DateTime.now().toUtc().add(const Duration(days: 2));
    final date = slotDay.toIso8601String().substring(0, 10);
    var availabilityCalls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProProfileScreen(pro: {
            'slug': 'empty-review-test',
            'contractorId': 264,
            'contractorServiceId': 246,
            'zip': '33602',
            'businessName': 'Test Plumbing'
          })));
      await tester.pumpAndSettle();
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.byType(AvailabilityCapsule), findsOneWidget);
      expect(find.textContaining('9:15 AM – 10:45 AM'), findsNothing);
      expect(availabilityCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('availability-get')) {
                availabilityCalls++;
                expect(jsonDecode(request.body), {
                  'contractorId': '264',
                  'serviceId': '246',
                  'propertyZip': '33602',
                  'urgency': 'standard'
                });
                return http.Response(
                    jsonEncode({
                      'slots': [
                        {
                          'start': '${date}T09:15:00-04:00',
                          'end': '${date}T10:45:00-04:00'
                        }
                      ]
                    }),
                    200);
              }
              return http.Response(
                  jsonEncode({
                    'profile': {
                      'business_name': 'Test Plumbing',
                      'verifiedCount': 0,
                      'services': [
                        {
                          'contractor_service_id': 246,
                          'name': 'Pipe repair',
                          'category': 'Plumbing',
                          'rate_amount': 90,
                          'work_order_type': 'rate_card'
                        }
                      ]
                    }
                  }),
                  200);
            }));
  });
  for (final scenario in [
    (zipChanged: false, calendarBlocked: false),
    (zipChanged: true, calendarBlocked: false),
    (zipChanged: false, calendarBlocked: true),
  ])
    testWidgets(
        'booking preserves the selected window across address changes (ZIP changed: ${scenario.zipChanged}, calendar blocked: ${scenario.calendarBlocked})',
        (tester) async {
      final zipChanged = scenario.zipChanged;
      final calendarBlocked = scenario.calendarBlocked;
      var rejectedHold = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 1400);
      addTearDown(tester.view.reset);
      final day = DateTime.now().toUtc().add(const Duration(days: 3));
      final date = day.toIso8601String().substring(0, 10);
      final calls = <Map<String, dynamic>>[];
      final availabilityCalls = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await HomeownerService.instance.fetchProfile(forceRefresh: true);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: const BookFlowScreen(
                initialDescription: 'Kitchen pipe leaks overnight.',
                pro: {
                  'slug': 'wizard-offering-test',
                  'contractorId': 264,
                  'contractorServiceId': 246,
                  'zip': '33602'
                })));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Standard'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Pick your arrival window'), findsOneWidget);
        // The seventh real window used to be silently discarded by a four-slot cap.
        expect(find.textContaining('2:15'), findsWidgets);
        final last = find.textContaining('2:15').last;
        await tester.ensureVisible(last);
        await tester.tap(last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close booking'));
        await tester.pumpAndSettle();
        expect(find.text("Your time won't be held."), findsOneWidget);
        await tester.tap(find.text('Keep booking'));
        await tester.pumpAndSettle();
        final countBeforeAddress = availabilityCalls.length;
        final addressChange = find.widgetWithText(TextButton, 'Change').last;
        await tester.ensureVisible(addressChange);
        await tester.tap(addressChange);
        await tester.pumpAndSettle();
        await tester.tap(find.text('2 Main St'));
        await tester.pumpAndSettle();
        expect(availabilityCalls.length,
            zipChanged ? greaterThan(countBeforeAddress) : countBeforeAddress);
        expect(find.textContaining('2 Main St'), findsOneWidget);
        if (calendarBlocked) {
          final accessField = find.byWidgetPredicate(
              (widget) => widget is TextField && widget.maxLength == 500);
          await tester.ensureVisible(accessField);
          await tester.enterText(accessField, 'Side gate 2468');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        final beforeHold = availabilityCalls.length;
        await tester.tap(find.text('Confirm booking'));
        await tester.pumpAndSettle();
        if (calendarBlocked) {
          expect(calls.map((c) => c['action']), ['hold']);
          expect(find.text('That time was just taken. Pick another window.'),
              findsOneWidget);
          expect(availabilityCalls.length, greaterThan(beforeHold));
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(find.text('Pick your arrival window'), findsOneWidget);
          expect(find.textContaining(RegExp(r'^2:15')), findsNothing);
          final nextWindow = find.textContaining('1:15').last;
          await tester.ensureVisible(nextWindow);
          await tester.tap(nextWindow);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(find.text('Kitchen pipe leaks overnight.'), findsOneWidget);
          expect(find.text('Side gate 2468'), findsOneWidget);
          expect(find.textContaining('2 Main St'), findsOneWidget);
          await tester.tap(find.text('Confirm booking'));
          await tester.pumpAndSettle();
        }
        expect(calls.map((c) => c['action']),
            [if (calendarBlocked) 'hold', 'hold', 'commit']);
        expect(calls.last['contractorServiceId'], '246');
        expect(calls.last['startsAt'],
            '${date}T${calendarBlocked ? '13' : '14'}:15:00Z');
        if (calendarBlocked) {
          expect(calls.last['booking']['service_description'],
              'Kitchen pipe leaks overnight.');
          expect(calls.last['booking']['access_code'], 'Side gate 2468');
          expect(calls.last['booking']['address_id'], 2);
        }
        expect(
            availabilityCalls.every((c) =>
                c['serviceId'] == '246' &&
                ['33602', if (zipChanged) '33578'].contains(c['propertyZip'])),
            isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await HomeownerService.instance.syncInBackground();
      },
          () => MockClient((request) async {
                final body = request.body.isEmpty
                    ? <String, dynamic>{}
                    : jsonDecode(request.body) as Map<String, dynamic>;
                if (request.url.path.endsWith('contractor-profile-get'))
                  return http.Response(
                      jsonEncode({
                        'profile': {
                          'business_name': 'Test Plumbing',
                          'contractorId': 264,
                          'services': [
                            {
                              'contractor_service_id': 999,
                              'name': 'Other service',
                              'work_order_type': 'rate_card',
                              'rate_amount': 100
                            },
                            {
                              'contractor_service_id': 246,
                              'catalog_service_id': 9,
                              'name': 'Pipe repair',
                              'work_order_type': 'rate_card',
                              'rate_amount': 90
                            }
                          ]
                        }
                      }),
                      200);
                if (request.url.path.endsWith('availability-get')) {
                  availabilityCalls.add(body);
                  return http.Response(
                      jsonEncode({
                        'slots': List.generate(
                            rejectedHold ? 6 : 7,
                            (i) => {
                                  'start':
                                      '${date}T${(8 + i).toString().padLeft(2, '0')}:15:00Z',
                                  'end':
                                      '${date}T${(9 + i).toString().padLeft(2, '0')}:45:00Z'
                                })
                      }),
                      200);
                }
                if (request.url.path.endsWith('booking-commit')) {
                  calls.add(body);
                  if (calendarBlocked &&
                      !rejectedHold &&
                      body['action'] == 'hold') {
                    rejectedHold = true;
                    return http.Response(
                        '{"ok":false,"error":"CALENDAR_BLOCKED"}', 409);
                  }
                  if (body['action'] == 'hold')
                    return http.Response('{"ok":true,"holdId":601}', 200);
                  return http.Response(
                      '{"success":true,"workOrderId":9200,"woNumber":"WO-9200"}',
                      200);
                }
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'tabs': {},
                      'homeProfiles': [],
                      'profile': {},
                      'availableBalance': 0,
                      'addresses': [
                        {
                          'id': 1,
                          'isDefault': true,
                          'street': '1 Main St',
                          'city': 'Tampa',
                          'state': 'FL',
                          'zip': '33602'
                        },
                        {
                          'id': 2,
                          'isDefault': false,
                          'street': '2 Main St',
                          'city': 'Tampa',
                          'state': 'FL',
                          'zip': zipChanged ? '33578' : '33602'
                        }
                      ]
                    }),
                    200);
              }));
    });
  test('server-held urgent window and matching credit key reach commit',
      () async {
    final calls = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await HomeownerService.instance.commitBooking(
        contractorId: '264',
        action: 'commit',
        urgency: 'urgent',
        transactionId: '123e4567-e89b-42d3-a456-426614174015',
        startsAt: '2026-12-01T10:00:00Z',
        endsAt: '2026-12-01T11:00:00Z',
        booking: {
          'contractor_service_id': 246,
          'address_zip': '33602',
          'service_credits_applied': 10,
          'credit_request_id': 'different-old-key'
        },
      );
      await HomeownerService.instance.syncInBackground();
    },
        () => MockClient((request) async {
              final body = request.body.isEmpty
                  ? <String, dynamic>{}
                  : jsonDecode(request.body) as Map<String, dynamic>;
              if (request.url.path.endsWith('booking-commit')) calls.add(body);
              if (body['action'] == 'hold')
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      'holdId': 501,
                      'startsAt': '2026-12-01T10:30:00Z',
                      'endsAt': '2026-12-01T11:30:00Z'
                    }),
                    200);
              return http.Response(
                  '{"success":true,"workOrderId":9101,"tabs":{},"addresses":[]}',
                  200);
            }));
    expect(calls.last['startsAt'], '2026-12-01T10:30:00Z');
    expect(calls.last['endsAt'], '2026-12-01T11:30:00Z');
    expect(calls.last['creditRequestId'], calls.last['idempotencyKey']);
  });
  test('an uncertain commit retries the same hold and exact body', () async {
    final calls = <Map<String, dynamic>>[];
    var fail = true;
    Future<Map<String, dynamic>> book() =>
        HomeownerService.instance.commitBooking(
            contractorId: '264',
            action: 'commit',
            urgency: 'standard',
            transactionId: '123e4567-e89b-42d3-a456-426614174016',
            startsAt: '2026-12-01T10:00:00Z',
            endsAt: '2026-12-01T11:00:00Z',
            booking: {'contractor_service_id': 246, 'address_zip': '33602'});
    await http.runWithClient(() async {
      await expectLater(book(), throwsException);
      fail = false;
      expect((await book())['workOrderId'], 9102);
      await HomeownerService.instance.syncInBackground();
    },
        () => MockClient((request) async {
              final body = request.body.isEmpty
                  ? <String, dynamic>{}
                  : jsonDecode(request.body) as Map<String, dynamic>;
              if (request.url.path.endsWith('booking-commit')) calls.add(body);
              if (body['action'] == 'hold')
                return http.Response('{"ok":true,"holdId":502}', 200);
              if (body['action'] == 'commit' && fail)
                throw http.ClientException('connection lost');
              return http.Response(
                  '{"success":true,"workOrderId":9102,"tabs":{},"addresses":[]}',
                  200);
            }));
    expect(calls.where((c) => c['action'] == 'hold'), hasLength(1));
    expect(calls[1], calls[2]);
  });
  test('success without a work-order receipt is not a confirmed booking',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.commitBooking(
              contractorId: '264',
              action: 'quote_request',
              urgency: 'standard',
              startsAt: '2026-10-20T08:00:00-04:00',
              endsAt: '2026-10-20T10:00:00-04:00',
              booking: {'contractor_service_id': 252, 'address_zip': '33602'}),
          throwsException);
    }, () => MockClient((_) async => http.Response('{"success":true}', 200)));
  });
  test(
      'availability sends offering and ZIP and does not bypass service refusals',
      () async {
    var count = 0;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.getContractorAvailability(
              contractorId: '264',
              serviceId: '246',
              propertyZip: '33602',
              forceRefresh: true),
          throwsException);
    },
        () => MockClient((request) async {
              count++;
              expect(jsonDecode(request.body), {
                'contractorId': '264',
                'serviceId': '246',
                'propertyZip': '33602',
                'urgency': 'standard'
              });
              return http.Response(
                  '{"success":false,"error":"service_not_found"}', 404);
            }));
    expect(count, 1);
  });
  test('free visits send the chosen two-hour reservation', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.commitBooking(
        contractorId: 'contractor-7',
        action: 'quote_request',
        urgency: 'standard',
        startsAt: '2026-10-20T08:00:00-04:00',
        endsAt: '2026-10-20T10:00:00-04:00',
        booking: {
          'contractor_service_id': 252,
          'service_category': 'Roofing',
          'work_order_type': 'quote_request'
        },
      );
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single, containsPair('action', 'quote_request'));
    expect(requests.single['startsAt'], '2026-10-20T08:00:00-04:00');
    expect(requests.single['endsAt'], '2026-10-20T10:00:00-04:00');
  });
  test('a priced booking holds its window before committing', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.commitBooking(
        contractorId: 'contractor-7',
        action: 'commit',
        urgency: 'standard',
        startsAt: '2026-12-01T10:00:00Z',
        endsAt: '2026-12-01T12:00:00Z',
        transactionId: '123e4567-e89b-42d3-a456-426614174000',
        booking: {
          'contractor_service_id': 'service-9',
          'address_zip': '33578',
          'work_order_type': 'rate_card',
        },
      );
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests, hasLength(2));
    expect(requests.first, containsPair('action', 'hold'));
    expect(requests.first, containsPair('contractorServiceId', 'service-9'));
    expect(requests.last, containsPair('action', 'commit'));
    expect(requests.last, containsPair('holdId', 123));
    expect(requests.last,
        containsPair('idempotencyKey', '123e4567-e89b-42d3-a456-426614174000'));
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
  test('review editing sends explicit rating and tags, including clearing tags',
      () async {
    final calls = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.contains('review-action')) calls.add(body);
      return http.Response(
          jsonEncode({
            'success': true,
            'ok': true,
            'reviewId': 555,
            'editedAt': '2026-09-26T12:00:00Z',
            'tabs': {},
            'addresses': []
          }),
          200);
    });
    await http.runWithClient(() async {
      await HomeownerService.instance.submitReview(
          workOrderId: 555,
          rating: 2,
          text: 'The visit was late.',
          tags: [],
          hasExistingReview: true,
          reviewId: 555,
          expectedUpdatedAt: '2026-09-25T12:00:00Z');
      await HomeownerService.instance.syncInBackground();
    }, () => client);
    expect(calls.single['action'], 'edit_review');
    expect(calls.single['reviewId'], 555);
    expect(calls.single['expectedUpdatedAt'], '2026-09-25T12:00:00Z');
    expect(calls.single['requestId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(calls.single['tags'], isEmpty);
    expect(calls.single['rating'], 2);
    expect(HomeownerService.instance.cachedReviewForWorkOrder(555)!['editedAt'],
        '2026-09-26T12:00:00Z');
  });
  test('unselected rating never creates a review request', () async {
    var called = false;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.submitReview(
              workOrderId: 556, rating: 0, text: 'A neutral review.'),
          throwsException);
    },
        () => MockClient((request) async {
              called = true;
              return http.Response('{}', 200);
            }));
    expect(called, isFalse);
  });
  test('existing review details load through the canonical gateway', () async {
    final paths = <String>[];
    await http.runWithClient(() async {
      final review = await HomeownerService.instance.getReview(8765);
      expect(review, isNotNull);
      expect(review!['rating'], 4.0);
      expect(review['reviewText'], 'Careful work and a clean finish.');
      expect(review['tags'], ['Clean work']);
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['action'], 'get_review');
              expect(body['requesterUserId'], 'test-homeowner');
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'review': {
                      'id': 42,
                      'work_order_id': 8765,
                      'rating': 4,
                      'review_text': 'Careful work and a clean finish.',
                      'tags': ['Clean work']
                    }
                  }),
                  200);
            }));
    expect(paths, ['/homeowner/review-action']);
  });
  test('legacy home-profile success cannot claim extended fields were saved',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.saveHomeProfile({
            'addressId': 1,
            'propertyDetails': {'bedrooms': 3},
            'systems': [],
            'accessNotes': {'text': 'Gate instructions'},
            'documents': []
          }),
          throwsException);
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'homeProfile': {'addressId': 1, 'yearBuilt': 2000}
            }),
            200)));
  });
  test('deleting a review clears its cached metadata only after server success',
      () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.deleteReview(
        555,
        reviewId: 555,
        expectedUpdatedAt: '2026-09-26T12:00:00Z',
      );
      await HomeownerService.instance.syncInBackground();
    },
        () => MockClient((request) async => http.Response(
            jsonEncode(
                {'success': true, 'ok': true, 'tabs': {}, 'addresses': []}),
            200)));
    expect(HomeownerService.instance.cachedReviewForWorkOrder(555), isNull);
  });
  test(
      'receipt upload reserves metadata, PUTs bytes without JWT, then completes',
      () async {
    final paths = <String>[];
    final bytes = [37, 80, 68, 70];
    final syncBefore = HomeownerService.instance.syncVersion.value;
    await http.runWithClient(() async {
      final document = await HomeownerService.instance
          .uploadWorkOrderReceipt(workOrderId: 101, paidAmount: 90, file: {
        'fileName': 'receipt.pdf',
        'mimeType': 'application/pdf',
        'fileBase64': base64Encode(bytes)
      });
      expect(document['id'], 80);
    },
        () => MockClient((request) async {
              paths.add('${request.method} ${request.url.path}');
              if (request.url.host == 'storage.example.com') {
                expect(request.method, 'PUT');
                expect(request.bodyBytes, bytes);
                expect(request.headers.keys.map((e) => e.toLowerCase()),
                    isNot(contains('authorization')));
                return http.Response('{}', 200);
              }
              final body = jsonDecode(request.body) as Map;
              if (request.url.path.endsWith('/upload-url')) {
                expect(body, {
                  'fileName': 'receipt.pdf',
                  'mimeType': 'application/pdf',
                  'sizeBytes': 4
                });
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'document': {'id': 80},
                      'uploadUrl':
                          'https://storage.example.com/receipt?token=signed'
                    }),
                    201);
              }
              expect(body, {'documentId': 80, 'paidAmount': '90.00'});
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'document': {'id': 80}
                  }),
                  200);
            }));
    expect(paths, [
      'POST /homeowner/work-orders/101/receipt/upload-url',
      'PUT /receipt',
      'POST /homeowner/work-orders/101/receipt/complete'
    ]);
    expect(HomeownerService.instance.syncVersion.value, syncBefore + 1);
  });

  test('failed storage upload never confirms a receipt', () async {
    var completed = false;
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance
              .uploadWorkOrderReceipt(workOrderId: 101, paidAmount: 90, file: {
            'fileName': 'receipt.pdf',
            'mimeType': 'application/pdf',
            'fileBase64': base64Encode([1])
          }),
          throwsException);
    },
        () => MockClient((request) async {
              if (request.url.host == 'storage.example.com')
                return http.Response('{}', 500);
              if (request.url.path.endsWith('/complete')) completed = true;
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'document': {'id': 80},
                    'uploadUrl':
                        'https://storage.example.com/receipt?token=signed'
                  }),
                  201);
            }));
    expect(completed, isFalse);
  });

  test('document open requests a fresh private download URL each time',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      expect(await HomeownerService.instance.homeDocumentDownloadUrl(80),
          contains('token=1'));
      expect(await HomeownerService.instance.homeDocumentDownloadUrl(80),
          contains('token=2'));
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path,
                  endsWith('/homeowner/home-documents/80/download-url'));
              calls++;
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'downloadUrl':
                        'https://storage.example.com/receipt?token=$calls'
                  }),
                  200);
            }));
  });

  test(
      'rich home profile saves property, note and system to dedicated endpoints',
      () async {
    final paths = <String>[];
    await http.runWithClient(() async {
      await HomeownerService.instance.saveHomeProfile({
        'id': 7,
        'addressId': 1,
        'propertyDetails': {
          'yearBuilt': 2000,
          'squareFootage': 1200,
          'bedrooms': 3,
          'bathrooms': 2.5
        },
        'accessNotes': {'id': 8, 'text': 'Use side gate'},
        'systems': [
          {'id': 9, 'type': 'hvac', 'model': 'AC-1', 'location': 'Garage'}
        ]
      });
    },
        () => MockClient((request) async {
              paths.add('${request.method} ${request.url.path}');
              final body =
                  request.body.isEmpty ? {} : jsonDecode(request.body) as Map;
              if (request.url.path.endsWith('/property')) {
                expect(body['squareFeet'], 1200);
                expect(body['bathrooms'], 2.5);
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'home': {'id': 7}
                    }),
                    200);
              }
              if (request.url.path.endsWith('/home-profile-notes/8')) {
                expect(body['body'], 'Use side gate');
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'note': {'id': 8}
                    }),
                    200);
              }
              if (request.url.path.endsWith('/home-systems/9')) {
                expect(body['modelNumber'], 'AC-1');
                expect(body['specifications']['location'], 'Garage');
                expect(body.containsKey('lastServicedOn'), isFalse);
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'system': {'id': 9, 'type': 'hvac'}
                    }),
                    200);
              }
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'home': {'id': 7},
                    'notes': [],
                    'systems': [],
                    'documents': []
                  }),
                  200);
            }));
    expect(paths.map((p) => p.split(' ').first),
        ['PATCH', 'PATCH', 'PATCH', 'GET']);
  });
  test(
      'all existing access notes are shown and clearing the field deletes every note',
      () async {
    final deleted = <String>[];
    await http.runWithClient(() async {
      final data = await HomeownerService.instance.fetchHomeProfiles();
      final profile =
          (data['homeProfiles'] as List).single as Map<String, dynamic>;
      expect(profile['accessNotes']['text'], 'Side gate\n\nRing upstairs');
      await HomeownerService.instance.saveHomeProfile(profile);
      expect(deleted, isEmpty);
      profile['accessNotes']['text'] = '';
      await HomeownerService.instance.saveHomeProfile(profile);
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (request.method == 'DELETE') {
                deleted.add(path);
                return http.Response('{"success":true}', 200);
              }
              if (path.endsWith('/home-profiles')) {
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'homeProfiles': [
                        {'id': 7, 'addressId': 1}
                      ]
                    }),
                    200);
              }
              if (path.endsWith('/property'))
                return http.Response('{"success":true,"home":{"id":7}}', 200);
              if (path.endsWith('/home-profiles/7')) {
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'home': {'id': 7, 'addressId': 1},
                      'notes': [
                        {'id': 8, 'type': 'access', 'body': 'Side gate'},
                        {'id': 10, 'type': 'access', 'body': 'Ring upstairs'},
                        {'id': 11, 'type': 'pets', 'body': 'Cat indoors'}
                      ],
                      'systems': [],
                      'documents': []
                    }),
                    200);
              }
              return http.Response('{"success":true,"addresses":[]}', 200);
            }));
    expect(deleted, [
      '/homeowner/home-profile-notes/8',
      '/homeowner/home-profile-notes/10'
    ]);
  });

  test('a later system-save failure retains already-loaded photos and history',
      () async {
    final profile = <String, dynamic>{
      'id': 7,
      'addressId': 1,
      'propertyDetails': {},
      'accessNotes': {},
      'systems': [
        {
          'id': 9,
          'type': 'hvac',
          'documents': [
            {'id': 44}
          ],
          'serviceHistory': [
            {'id': 55}
          ]
        },
        {'id': 10, 'type': 'roof'}
      ]
    };
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.saveHomeProfile(profile), throwsException);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/property'))
                return http.Response('{"success":true,"home":{"id":7}}', 200);
              if (request.url.path.endsWith('/home-systems/9')) {
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'system': {
                        'id': 9,
                        'type': 'hvac',
                        'documents': [],
                        'serviceHistory': []
                      }
                    }),
                    200);
              }
              return http.Response(
                  '{"success":false,"error":"save_failed"}', 500);
            }));
    expect(profile['systems'][0]['documents'], [
      {'id': 44}
    ]);
    expect(profile['systems'][0]['serviceHistory'], [
      {'id': 55}
    ]);
  });
  test('credit choice and intake token reach the real top-level booking API',
      () async {
    await http.runWithClient(() async {
      await HomeownerService.instance.commitBooking(
          contractorId: 'contractor-7',
          action: 'commit',
          urgency: 'standard',
          startsAt: '2026-12-01T10:00:00Z',
          endsAt: '2026-12-01T12:00:00Z',
          booking: {
            'contractor_service_id': 77,
            'service_credits_applied': 25.50,
            'credit_request_id': '2337b617-b21d-4815-a2a6-a0e5a10bf784',
            'intake_session_token': 'signed-session',
            'service_category': 'HVAC'
          });
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    final commit = requests.singleWhere((row) => row['action'] == 'commit');
    expect(commit['applyServiceCredit'], true);
    expect(commit['serviceCreditAmount'], '25.50');
    expect(commit['creditRequestId'], '2337b617-b21d-4815-a2a6-a0e5a10bf784');
    expect(commit['idempotencyKey'], commit['creditRequestId']);
    expect(commit['intakeSessionToken'], 'signed-session');
    expect((commit['booking'] as Map).containsKey('service_credits_applied'),
        false);
  });
  test('profile details cannot silently change the sign-in email', () async {
    await http.runWithClient(() async {
      await HomeownerService.instance
          .updateAccountDetails({'name': 'New name', 'phone': '5551234567'});
      final result = await HomeownerService.instance
          .changeAccountEmail('new@example.com', 'current-password');
      expect(result['confirmationRequired'], true);
    },
        () => MockClient((request) async {
              final body = jsonDecode(request.body) as Map;
              if (request.method == 'PATCH') {
                expect(request.url.path, '/homeowner/account/details');
                expect(body.containsKey('email'), false);
              } else {
                expect(request.url.path, '/homeowner/account/change-email');
                expect(body['newEmail'], 'new@example.com');
                expect(body['currentPassword'], 'current-password');
              }
              return http.Response(
                  '{"success":true,"confirmationRequired":true}', 200);
            }));
  });
  test('rejected account closure is not treated as completed deletion',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          HomeownerService.instance.requestAccountClosure('CLOSE', 'password'),
          throwsException);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/homeowner/account/close');
              return http.Response(
                  '{"success":false,"error":"active_jobs_block_closure"}', 409);
            }));
    expect(AuthService.instance.isAuthenticated, true);
  });
}

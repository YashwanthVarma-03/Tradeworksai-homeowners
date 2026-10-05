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
          hasExistingReview: true);
      await HomeownerService.instance.syncInBackground();
    }, () => client);
    expect(calls.single['action'], 'update_review');
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
  test('existing review details load through the legacy gateway fallback',
      () async {
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
              if (request.url.path == '/homeowner/review-action') {
                return http.Response(
                  '{"success":false,"error":"not_found"}',
                  404,
                );
              }
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
    expect(paths,
        ['/homeowner/review-action', '/homeowner-review-action-v2-supabase']);
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
      await HomeownerService.instance.deleteReview(555);
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
          .uploadWorkOrderReceipt(workOrderId: 101, file: {
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
              expect(body, {'documentId': 80});
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
              .uploadWorkOrderReceipt(workOrderId: 101, file: {
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
            'service_credits_applied': 25.50,
            'credit_request_id': '2337b617-b21d-4815-a2a6-a0e5a10bf784',
            'intake_session_token': 'signed-session',
            'service_category': 'HVAC'
          });
      await HomeownerService.instance.syncInBackground();
    }, () => api);
    expect(requests.single['applyServiceCredit'], true);
    expect(requests.single['serviceCreditAmount'], '25.50');
    expect(requests.single['creditRequestId'],
        '2337b617-b21d-4815-a2a6-a0e5a10bf784');
    expect(requests.single['intakeSessionToken'], 'signed-session');
    expect(
        (requests.single['booking'] as Map)
            .containsKey('service_credits_applied'),
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

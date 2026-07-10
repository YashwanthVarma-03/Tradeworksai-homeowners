import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:homeowners_app/services/homeowner_service.dart';
import 'package:homeowners_app/services/stream_service.dart';

void main() {
  // Ensure Flutter binding and mock shared preferences
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Booking and Work Orders Integration Tests (Demo Mode)', () {
    setUp(() async {
      AuthService.instance.isTesting = true;
      await AuthService.instance.loadSession();
      await AuthService.instance.simulateGoogleSignInSuccess();
    });

    tearDown(() async {
      await AuthService.instance.logout();
    });

    test('AuthService sets up demo user correctly', () {
      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(AuthService.instance.userId, equals('999'));
      expect(
          AuthService.instance.userEmail, equals('demo.homeowner@gmail.com'));
    });

    test('commitBooking saves work order to mock state in demo mode', () async {
      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': 'HVAC',
        'service_description': 'Test HVAC Repair',
        'address_street': '124 Skyview Lane',
        'address_city': 'Tampa',
        'address_state': 'FL',
        'address_zip': '33569',
        'work_order_type': 'rate_card',
      };

      final response = await HomeownerService.instance.commitBooking(
        contractorId: '1',
        action: 'commit',
        urgency: 'standard',
        booking: bookingData,
        startsAt: DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        endsAt: DateTime.now()
            .add(const Duration(days: 1, hours: 2))
            .toIso8601String(),
      );

      expect(response['success'], isTrue);
      expect(response['ok'], isTrue);
      expect(response['woNumber'], startsWith('WO-'));

      // Fetch work orders and verify it contains the scheduled job
      final woData = await HomeownerService.instance.fetchWorkOrders();
      expect(woData['success'], isTrue);
      expect(woData['tabs'], isNotNull);

      final List<dynamic> scheduledJobs = woData['tabs']['scheduled'] ?? [];
      expect(scheduledJobs, isNotEmpty);

      final newJob = scheduledJobs.firstWhere(
        (j) =>
            j['serviceCategory'] == 'HVAC' &&
            j['description'] == 'Test HVAC Repair',
        orElse: () => <String, dynamic>{},
      );
      expect(newJob, isNotEmpty);
      expect(newJob['status'], equals('scheduled'));
    });

    test('reschedule resolver accepts raw contractor ids from work orders',
        () async {
      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': 'Plumbing',
        'service_description': 'Test reschedule',
        'address_street': '55 Palm Ave',
        'address_city': 'Tampa',
        'address_state': 'FL',
        'address_zip': '33569',
        'work_order_type': 'rate_card',
      };

      await HomeownerService.instance.commitBooking(
        contractorId: 'pro_alpha_42',
        action: 'commit',
        urgency: 'standard',
        booking: bookingData,
        startsAt: DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        endsAt: DateTime.now()
            .add(const Duration(days: 2, hours: 2))
            .toIso8601String(),
      );

      final woData = await HomeownerService.instance.fetchWorkOrders();
      final List<dynamic> scheduledJobs = woData['tabs']['scheduled'] ?? [];
      final newJob = scheduledJobs.firstWhere(
        (j) => j['description'] == 'Test reschedule',
        orElse: () => <String, dynamic>{},
      );

      final workOrderId = newJob['workOrderId'] as int?;
      expect(workOrderId, isNotNull);

      final contractorId = await HomeownerService.instance
          .resolveContractorIdForWorkOrder(workOrderId!);
      expect(contractorId, equals('pro_alpha_42'));
    });

    test('review submit persists in demo mode and becomes retrievable',
        () async {
      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': 'Electrical',
        'service_description': 'Completed visit review',
        'address_street': '10 Test Ave',
        'address_city': 'Tampa',
        'address_state': 'FL',
        'address_zip': '33569',
        'work_order_type': 'rate_card',
      };

      await HomeownerService.instance.commitBooking(
        contractorId: 'review_pro_7',
        action: 'commit',
        urgency: 'standard',
        booking: bookingData,
        startsAt: DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        endsAt: DateTime.now()
            .add(const Duration(days: 1, hours: 2))
            .toIso8601String(),
      );

      final woData = await HomeownerService.instance.fetchWorkOrders();
      final List<dynamic> scheduledJobs = woData['tabs']['scheduled'] ?? [];
      final newJob = scheduledJobs.firstWhere(
        (j) => j['description'] == 'Completed visit review',
        orElse: () => <String, dynamic>{},
      );

      final workOrderId = newJob['workOrderId'] as int?;
      expect(workOrderId, isNotNull);

      await HomeownerService.instance.performWorkOrderAction(
        workOrderId: workOrderId!,
        action: 'confirm_complete',
      );

      await HomeownerService.instance.submitReview(
        workOrderId: workOrderId,
        rating: 5,
        text: 'Excellent work and clear communication.',
        displayName: 'Demo Homeowner',
      );

      final review = await HomeownerService.instance.getReview(workOrderId);
      expect(review, isNotNull);
      expect(review!['rating'], equals(5));
      expect(review['reviewText'], contains('Excellent work'));
    });

    test('messaging resolver prefers contractor user ids over profile ids', () {
      final resolved = StreamService.instance.resolveMessagingUserId({
        'contractorId': 'profile_100',
        'userId': '20',
        'profile': {
          'user_id': '21',
        },
      });

      expect(resolved, equals('20'));
    });
  });
}

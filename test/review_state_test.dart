import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/homeowner_service.dart';

void main() {
  test('reviewed work orders are exposed through the shared review cache', () {
    const workOrderId = 987654;
    final service = HomeownerService.instance;
    final versionBefore = service.reviewVersion.value;

    service.rememberReviewedWorkOrder(workOrderId);

    final review = service.cachedReviewForWorkOrder(workOrderId);
    expect(review, isNotNull);
    expect(review!['reviewed'], isTrue);
    expect(review['detailsAvailable'], isFalse);
    expect(service.reviewVersion.value, versionBefore + 1);
  });

  test('cached review snapshots cannot mutate the service cache', () {
    const workOrderId = 987655;
    final service = HomeownerService.instance;
    service.rememberReviewedWorkOrder(workOrderId);

    final snapshot = service.cachedReviewForWorkOrder(workOrderId)!;
    snapshot['reviewed'] = false;

    expect(
      service.cachedReviewForWorkOrder(workOrderId)!['reviewed'],
      isTrue,
    );
  });
}

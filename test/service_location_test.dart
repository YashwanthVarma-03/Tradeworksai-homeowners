import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/service_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocation.clear();
  });

  test('does not restore a ZIP saved by an older app session', () async {
    SharedPreferences.setMockInitialValues({
      'selected_service_zip': '33578',
      'selected_service_location_name': 'Riverview, FL',
    });

    expect(await ServiceLocation.load(), isNull);
  });

  test('keeps an explicitly entered ZIP in memory only', () async {
    await ServiceLocation.save(
      zip: '33602',
      locationName: 'Tampa, FL',
    );

    final location = await ServiceLocation.load();
    expect(location?.zip, '33602');
    expect(location?.locationName, 'Tampa, FL');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_service_zip'), isNull);
    expect(prefs.getString('selected_service_location_name'), isNull);
  });

  test('clear removes the temporary ZIP and legacy persisted values', () async {
    SharedPreferences.setMockInitialValues({
      'selected_service_zip': '33578',
      'selected_service_location_name': 'Riverview, FL',
    });
    await ServiceLocation.save(zip: '33602', locationName: 'Tampa, FL');

    await ServiceLocation.clear();

    expect(await ServiceLocation.load(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_service_zip'), isNull);
    expect(prefs.getString('selected_service_location_name'), isNull);
  });

  test('clear requests a primary-address refresh without an override', () async {
    var notifications = 0;
    void listener() => notifications++;
    ServiceLocation.selected.addListener(listener);

    await ServiceLocation.clear();

    ServiceLocation.selected.removeListener(listener);
    expect(notifications, 1);
  });
}

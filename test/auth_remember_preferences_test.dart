import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('remember login is enabled by default', () async {
    expect(
      await AuthService.instance.loadRememberLoginPreference(),
      isTrue,
    );
    expect(await AuthService.instance.loadRememberedLoginEmail(), isNull);
  });

  test('remember login stores the normalized email address', () async {
    await AuthService.instance.setRememberLoginPreference(
      rememberMe: true,
      email: '  homeowner@example.com  ',
    );

    expect(
      await AuthService.instance.loadRememberedLoginEmail(),
      'homeowner@example.com',
    );
  });

  test('turning remember login off removes the remembered email', () async {
    await AuthService.instance.setRememberLoginPreference(
      rememberMe: true,
      email: 'homeowner@example.com',
    );
    await AuthService.instance.setRememberLoginPreference(
      rememberMe: false,
    );

    expect(
      await AuthService.instance.loadRememberLoginPreference(),
      isFalse,
    );
    expect(await AuthService.instance.loadRememberedLoginEmail(), isNull);
  });
}

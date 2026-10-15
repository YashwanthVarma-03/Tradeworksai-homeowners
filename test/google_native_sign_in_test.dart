import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:homeowners_app/services/api_config.dart';
import 'package:homeowners_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingNativeGoogleSignIn extends GoogleSignInPlatform {
  SignInInitParameters? parameters;
  int signInCalls = 0;
  bool cancel = false;

  @override
  Future<void> initWithParams(SignInInitParameters params) async {
    parameters = params;
  }

  @override
  Future<GoogleSignInUserData?> signIn() async {
    signInCalls++;
    if (cancel) return null;
    throw PlatformException(code: 'sign_in_failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS without its OAuth client never opens hosted sign-in', () async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(ApiConfig.googleIosClientId, isEmpty);
    await expectLater(
      AuthService.instance.signInWithGoogleInteractive(),
      throwsA(isA<StateError>()),
    );
  });

  test('Android Google failure stays in the native sign-in flow', () async {
    SharedPreferences.setMockInitialValues({});
    final originalPlatform = GoogleSignInPlatform.instance;
    final nativePlatform = _FailingNativeGoogleSignIn();
    GoogleSignInPlatform.instance = nativePlatform;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      GoogleSignInPlatform.instance = originalPlatform;
    });

    expect(ApiConfig.googleWebClientId, isNotEmpty);
    await expectLater(
      AuthService.instance.signInWithGoogleInteractive(),
      throwsA(isA<PlatformException>()),
    );
    expect(nativePlatform.signInCalls, 1);
    expect(nativePlatform.parameters?.serverClientId,
        ApiConfig.googleWebClientId);
    expect(nativePlatform.parameters?.clientId, isNull);

    nativePlatform.cancel = true;
    await expectLater(
      AuthService.instance.signInWithGoogleInteractive(),
      throwsA(isA<GoogleSignInCancelled>()),
    );
    expect(nativePlatform.signInCalls, 2);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/fcm_token_provider.dart';

void main() {
  test('iOS waits for APNs before obtaining FCM', () async {
    final calls = <String>[];
    var reads = 0;
    final provider = FcmTokenProvider(
      isApple: true,
      permissionGranted: () async => true,
      readApnsToken: () async {
        calls.add('apns');
        return ++reads == 3 ? 'apple-token' : null;
      },
      readFcmToken: () async {
        calls.add('fcm');
        return 'fcm-token';
      },
      delay: (_) async {
        calls.add('wait');
      },
    );
    expect(await provider.getToken(), 'fcm-token');
    expect(calls, ['apns', 'wait', 'apns', 'wait', 'apns', 'fcm']);
  });

  test('missing APNs has bounded waits and never calls FCM', () async {
    var waits = 0;
    final provider = FcmTokenProvider(
      isApple: true,
      permissionGranted: () async => true,
      readApnsToken: () async => null,
      readFcmToken: () async => throw StateError('FCM must not run'),
      delay: (_) async {
        waits++;
      },
    );
    expect(await provider.getToken(), isNull);
    expect(waits, 20);
  });

  test('denied or undecided permission does not request a token', () async {
    final provider = FcmTokenProvider(
      isApple: true,
      permissionGranted: () async => false,
      readApnsToken: () async => throw StateError('APNs must not run'),
      readFcmToken: () async => throw StateError('FCM must not run'),
    );
    expect(await provider.getToken(), isNull);
  });

  test('sign-out or backgrounding cancels an APNs wait', () async {
    var current = true;
    final provider = FcmTokenProvider(
      isApple: true,
      permissionGranted: () async => true,
      readApnsToken: () async => null,
      readFcmToken: () async => throw StateError('FCM must not run'),
      delay: (_) async {
        current = false;
      },
    );
    expect(await provider.getToken(isCurrent: () => current), isNull);
  });

  test('a later foreground attempt recovers from delayed APNs', () async {
    var ready = false;
    final provider = FcmTokenProvider(
      isApple: true,
      permissionGranted: () async => true,
      readApnsToken: () async => ready ? 'apple-token' : null,
      readFcmToken: () async => 'fcm-token',
      delay: (_) async {},
    );
    expect(await provider.getToken(), isNull);
    ready = true;
    expect(await provider.getToken(), 'fcm-token');
  });

  test('Android obtains FCM without touching APNs', () async {
    final provider = FcmTokenProvider(
      isApple: false,
      permissionGranted: () async => true,
      readApnsToken: () async => throw StateError('APNs must not run'),
      readFcmToken: () async => 'android-token',
    );
    expect(await provider.getToken(), 'android-token');
  });

  test('a session change while FCM resolves discards the token', () async {
    var current = true;
    final provider = FcmTokenProvider(
      isApple: false,
      permissionGranted: () async => true,
      readApnsToken: () async => null,
      readFcmToken: () async {
        current = false;
        return 'old-session-token';
      },
    );
    expect(await provider.getToken(isCurrent: () => current), isNull);
  });

  test('blank tokens are never registered', () async {
    final provider = FcmTokenProvider(
      isApple: false,
      permissionGranted: () async => true,
      readApnsToken: () async => null,
      readFcmToken: () async => ' ',
    );
    expect(await provider.getToken(), isNull);
  });
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_notification_config.dart';

/// One permission/APNs gate for both TradeWorks and Stream device registration.
/// Waiting is bounded and can be cancelled when the account or lifecycle changes.
class FcmTokenProvider {
  FcmTokenProvider({
    required this.isApple,
    required this.permissionGranted,
    required this.readApnsToken,
    required this.readFcmToken,
    Future<void> Function(Duration)? delay,
  }) : delay = delay ?? Future<void>.delayed;

  factory FcmTokenProvider.current() {
    final messaging = FirebaseMessaging.instance;
    return FcmTokenProvider(
      isApple: !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS),
      permissionGranted: () async {
        final settings = await messaging.getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      },
      readApnsToken: messaging.getAPNSToken,
      readFcmToken: () => messaging.getToken(
        vapidKey: kIsWeb && PushNotificationConfig.vapidKey.isNotEmpty
            ? PushNotificationConfig.vapidKey
            : null,
      ),
    );
  }

  final bool isApple;
  final Future<bool> Function() permissionGranted;
  final Future<String?> Function() readApnsToken;
  final Future<String?> Function() readFcmToken;
  final Future<void> Function(Duration) delay;

  Future<String?> getToken({bool Function()? isCurrent}) async {
    bool current() => isCurrent?.call() ?? true;
    if (!current() || !await permissionGranted() || !current()) return null;
    if (isApple) {
      var ready = false;
      for (var attempt = 0; attempt <= 20 && current(); attempt++) {
        final apnsToken = await readApnsToken();
        if (!current()) return null;
        if (apnsToken != null && apnsToken.trim().isNotEmpty) {
          ready = true;
          break;
        }
        if (attempt < 20) await delay(const Duration(milliseconds: 500));
      }
      if (!ready || !current()) return null;
    }
    final token = await readFcmToken();
    return current() && token != null && token.trim().isNotEmpty ? token : null;
  }
}

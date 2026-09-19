import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'homeowner_service.dart';
import 'notification_preferences.dart';
import 'push_notification_config.dart';

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  if (!PushNotificationConfig.isConfigured) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: PushNotificationConfig.options);
    }
  } catch (_) {
    // A broken deployment configuration must not crash a background isolate.
  }
}

/// Owns FCM registration, permission, token rotation, and foreground display.
/// The API only receives a device token after a signed-in user enables a push
/// category in Notification settings.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tradeworks_updates',
    'TradeWorks updates',
    description: 'Booking updates, messages, rewards, and offers.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  NotificationPreferences? _preferences;
  String? _activeUserId;
  bool _initialized = false;
  bool _initializationFailed = false;

  bool get isConfigured => PushNotificationConfig.isConfigured;
  bool get isAvailable => isConfigured && !_initializationFailed;

  Future<bool> initialize() async {
    if (!isAvailable || _initialized) return isAvailable;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: PushNotificationConfig.options);
      }

      if (!kIsWeb) {
        const settings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        await _localNotifications.initialize(settings);
        final android =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(_channel);
      }

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_showForeground);
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          final userId = _activeUserId;
          final preferences = _preferences;
          if (userId == null ||
              preferences == null ||
              !preferences.hasPushEnabled) {
            return;
          }
          unawaited(_registerToken(userId, token, preferences));
        },
      );
      _initialized = true;
      return true;
    } catch (_) {
      _initializationFailed = true;
      return false;
    }
  }

  Future<bool> requestPermissionAndRegister({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    _activeUserId = userId;
    _preferences = preferences;
    if (!preferences.hasPushEnabled) return true;
    if (!await initialize()) return false;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final permitted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!permitted) return false;

    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb && PushNotificationConfig.vapidKey.isNotEmpty
          ? PushNotificationConfig.vapidKey
          : null,
    );
    if (token == null || token.isEmpty) return false;
    await _registerToken(userId, token, preferences);
    return true;
  }

  Future<void> updatePreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    _activeUserId = userId;
    _preferences = preferences;
    if (!preferences.hasPushEnabled || !isConfigured) return;
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb && PushNotificationConfig.vapidKey.isNotEmpty
          ? PushNotificationConfig.vapidKey
          : null,
    );
    if (token == null || token.isEmpty) return;
    await _registerToken(userId, token, preferences);
  }

  Future<void> _registerToken(
    String userId,
    String token,
    NotificationPreferences preferences,
  ) {
    return HomeownerService.instance.registerPushDevice(
      userId: userId,
      token: token,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      preferences: preferences.toJson(),
    );
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (!_shouldPresent(message)) return;
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) return;

    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'Tradeworks One',
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tradeworks_updates',
          'TradeWorks updates',
          channelDescription: 'Booking updates, messages, rewards, and offers.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  bool _shouldPresent(RemoteMessage message) {
    final preferences = _preferences;
    if (preferences == null) return true;
    switch (message.data['notification_type']?.toString()) {
      case 'work_order_status':
        return preferences.pushStatus;
      case 'message':
        return preferences.pushMessages;
      case 'credit':
      case 'reward':
        return preferences.pushCredits;
      case 'promotion':
        return preferences.pushPromos;
      default:
        return preferences.hasPushEnabled;
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _tokenRefreshSubscription = null;
    _initialized = false;
    _activeUserId = null;
    _preferences = null;
  }
}

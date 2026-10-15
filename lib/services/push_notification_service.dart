import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'auth_service.dart';
import 'fcm_token_provider.dart';
import 'homeowner_service.dart';
import 'notification_preferences.dart';
import 'notification_routing.dart';
import 'push_notification_config.dart';
import 'stream_service.dart';

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

/// Owns FCM permission, app/backend registration, rotation, and routing.
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _tokenIdKey = 'push_token_record_id';
  static const String _tokenValueKey = 'push_token_value';
  static const String _pendingDeletePrefix = 'push_token_pending_delete_';
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
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<Event>? _chatMessageSubscription;
  StreamChatClient? _chatClient;
  NotificationPreferences? _preferences;
  String? _activeUserId;
  String? _activatedUserId;
  Future<bool>? _activationInFlight;
  int _sessionGeneration = 0;
  bool _initialized = false;
  Future<bool>? _initializationInFlight;
  Future<void>? _resumeRegistrationInFlight;
  Future<void> _registrationQueue = Future<void>.value();
  bool _initializationFailed = false;
  bool _logoutHookInstalled = false;
  bool _localInitialized = false;
  bool _chatListenerInstalled = false;
  bool _foregroundPermissionGranted = false;
  bool _lifecycleObserverInstalled = false;
  bool _activityFeedUnavailable = false;
  Timer? _activityTimer;
  Future<void>? _activityCheckInFlight;
  final ActivityArrivalTracker _activityArrivals = ActivityArrivalTracker();

  bool get isConfigured => PushNotificationConfig.isConfigured;
  bool get isAvailable => isConfigured && !_initializationFailed;

  bool get supportsOpenAppAlerts =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _initializeLocalNotifications() async {
    if (!supportsOpenAppAlerts) return false;
    if (_localInitialized) return true;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) =>
            _routeLocalPayload(response.payload),
      );
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      final launch =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        scheduleMicrotask(
          () => _routeLocalPayload(launch?.notificationResponse?.payload),
        );
      }
      _localInitialized = true;
      return true;
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'local notifications',
      ));
      return false;
    }
  }

  void _routeLocalPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        NotificationNavigation.request(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<bool> requestOpenAppAlertPermission() async {
    if (!await _initializeLocalNotifications()) return false;
    if (_foregroundPermissionGranted) return true;
    try {
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = defaultTargetPlatform == TargetPlatform.android
          ? await android?.requestNotificationsPermission()
          : await ios?.requestPermissions(
              alert: true, badge: true, sound: true);
      _foregroundPermissionGranted = granted != false;
    } catch (_) {
      _foregroundPermissionGranted = false;
    }
    return _foregroundPermissionGranted;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _activityFeedUnavailable = false;
      _startActivityChecks();
      unawaited(_checkActivity());
      unawaited(_refreshRegistrationOnResume());
    } else {
      _activityTimer?.cancel();
      _activityTimer = null;
    }
  }

  Future<void> _refreshRegistrationOnResume() async {
    final userId = _activeUserId;
    if (!isConfigured ||
        userId == null ||
        AuthService.instance.userId != userId ||
        _activationInFlight != null ||
        _resumeRegistrationInFlight != null) {
      return;
    }
    // A single foreground retry, not a polling timer. Also picks up permission
    // changes in iOS Settings and preferences changed on another device.
    final future =
        _activate(userId, promptForPermission: false).then<void>((_) {});
    _resumeRegistrationInFlight = future;
    try {
      await future;
    } catch (_) {
      // An offline resume must not surface an unhandled asynchronous error.
      // The next foreground transition can retry.
    } finally {
      if (identical(_resumeRegistrationInFlight, future)) {
        _resumeRegistrationInFlight = null;
      }
    }
  }

  void _startActivityChecks() {
    if (_activityTimer != null ||
        isConfigured ||
        _activityFeedUnavailable ||
        _activeUserId == null ||
        _preferences?.hasPushEnabled != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _activityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_checkActivity()),
    );
  }

  Future<void> _checkActivity() {
    if (_activityCheckInFlight != null) return _activityCheckInFlight!;
    final check = _checkActivityOnce();
    _activityCheckInFlight = check;
    return check.whenComplete(() => _activityCheckInFlight = null);
  }

  Future<void> _checkActivityOnce() async {
    if (_activityFeedUnavailable ||
        _activeUserId == null ||
        _preferences?.hasPushEnabled != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final userId = _activeUserId;
    final rows = await HomeownerService.instance.fetchNotifications();
    if (_activeUserId != userId ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (rows == null) {
      // An absent feed endpoint must not become a permanent request timer.
      _activityFeedUnavailable = true;
      _activityTimer?.cancel();
      _activityTimer = null;
      return;
    }
    final fresh = _activityArrivals.takeNew(rows);
    if (fresh.isEmpty) return;
    HomeownerService.instance.notifyIncomingNotification();
    unawaited(HomeownerService.instance.syncInBackground());
    if (!_foregroundPermissionGranted) return;
    for (final row in fresh.take(3)) {
      if (!_shouldPresentData(row)) continue;
      await _showLocalAlert(
        id: row['id'].toString().hashCode & 0x7fffffff,
        title: row['title']?.toString().trim().isNotEmpty == true
            ? row['title'].toString().trim()
            : 'TradeWorks update',
        body: row['body']?.toString().trim().isNotEmpty == true
            ? row['body'].toString().trim()
            : 'Open the app to see the latest activity.',
        data: row,
      );
    }
  }

  void _bindChatMessages() {
    final client = StreamService.instance.client;
    if (client == null || client.state.currentUser == null) {
      unawaited(_chatMessageSubscription?.cancel());
      _chatMessageSubscription = null;
      _chatClient = null;
      return;
    }
    if (identical(client, _chatClient)) return;
    unawaited(_chatMessageSubscription?.cancel());
    _chatClient = client;
    _chatMessageSubscription =
        client.on(EventType.messageNew).listen(_onChatMessage);
  }

  void _onChatMessage(Event event) {
    if (!supportsOpenAppAlerts ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        _activeUserId == null ||
        !_foregroundPermissionGranted ||
        _preferences?.pushMessages != true ||
        event.message == null ||
        event.message?.user?.id == _chatClient?.state.currentUser?.id) {
      return;
    }
    // FCM handles visible foreground alerts when configured. The Stream
    // socket provides the no-Firebase, open-app fallback without duplicates.
    if (isConfigured) return;
    final message = event.message!;
    final sender = event.user?.name ?? message.user?.name ?? 'Your pro';
    final body = message.text?.trim().isNotEmpty == true
        ? message.text!.trim()
        : 'Sent you a message';
    unawaited(_showLocalAlert(
      id: message.id.hashCode & 0x7fffffff,
      title: 'New message from $sender',
      body: body,
      data: {
        'type': 'message',
        'channel_id': event.cid ?? '',
        'contractor_name': sender,
      },
    ));
  }

  Future<void> _showLocalAlert({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      await _localNotifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tradeworks_updates',
            'TradeWorks updates',
            channelDescription:
                'Booking updates, messages, rewards, and offers.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (_) {
      // Notification permission or OS delivery may change while the app runs.
    }
  }

  Future<void> _startOpenAppAlerts({bool promptForPermission = true}) async {
    if (!supportsOpenAppAlerts || _preferences?.hasPushEnabled != true) return;
    if (promptForPermission) await requestOpenAppAlertPermission();
    if (!_lifecycleObserverInstalled) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverInstalled = true;
    }
    _startActivityChecks();
    unawaited(_checkActivity());
    if (!_chatListenerInstalled) {
      StreamService.instance.addListener(_bindChatMessages);
      _chatListenerInstalled = true;
    }
    _bindChatMessages();
    try {
      await StreamService.instance.ensureConnected();
      _bindChatMessages();
    } catch (_) {
      // An unavailable chat socket must not block the rest of the app.
    }
  }

  Future<bool> initialize() {
    if (!isConfigured) return Future.value(false);
    if (_initialized) return Future.value(true);
    if (_initializationInFlight != null) return _initializationInFlight!;
    final future = _initialize();
    _initializationInFlight = future;
    return future.whenComplete(() {
      if (identical(_initializationInFlight, future)) {
        _initializationInFlight = null;
      }
    });
  }

  Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: PushNotificationConfig.options);
      }
      if (supportsOpenAppAlerts && !await _initializeLocalNotifications()) {
        return false;
      }
      if (!_lifecycleObserverInstalled) {
        WidgetsBinding.instance.addObserver(this);
        _lifecycleObserverInstalled = true;
      }
      // A transient initialization failure can be retried on the next resume.
      await _foregroundSubscription?.cancel();
      await _openedSubscription?.cancel();
      await _tokenRefreshSubscription?.cancel();

      // iOS foreground delivery is native. Do not also post a local
      // notification or the user will see duplicates.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        _notifyFreshActivity(message.data);
        unawaited(_showForeground(message));
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) {
          _notifyFreshActivity(message.data);
          NotificationNavigation.request(message.data);
        },
      );
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        final preferences = _preferences;
        if (_activeUserId == null ||
            preferences == null ||
            !preferences.hasPushEnabled) {
          return;
        }
        unawaited(_registerToken(token, preferences).catchError(
          (Object error, StackTrace stackTrace) {
            FlutterError.reportError(FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'push notifications',
              context: ErrorDescription('while rotating the FCM token'),
            ));
          },
        ));
      });

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        scheduleMicrotask(
          () {
            _notifyFreshActivity(initialMessage.data);
            NotificationNavigation.request(initialMessage.data);
          },
        );
      }
      if (!_logoutHookInstalled) {
        AuthService.instance.addBeforeLogoutHook(unregisterActiveDevice);
        _logoutHookInstalled = true;
      }
      _initialized = true;
      _initializationFailed = false;
      return true;
    } catch (error, stackTrace) {
      _initializationFailed = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push notifications',
          context: ErrorDescription('while initializing Firebase Messaging'),
        ),
      );
      return false;
    }
  }

  Future<bool> activateForSignedInUser(String userId) {
    if (!_logoutHookInstalled) {
      AuthService.instance.addBeforeLogoutHook(unregisterActiveDevice);
      _logoutHookInstalled = true;
    }
    if (_activatedUserId == userId) return Future.value(true);
    if (_activeUserId == userId && _activationInFlight != null) {
      return _activationInFlight!;
    }
    final future = _activate(userId);
    _activationInFlight = future;
    return future.whenComplete(() {
      if (identical(_activationInFlight, future)) _activationInFlight = null;
    });
  }

  Future<bool> _activate(String userId,
      {bool promptForPermission = true}) async {
    if (userId.isEmpty) return false;
    final generation = _sessionGeneration;
    if (_activeUserId != userId) {
      _activityArrivals.reset();
      _activityFeedUnavailable = false;
    }
    _activeUserId = userId;
    NotificationPreferences preferences;
    try {
      preferences = NotificationPreferences.fromAccount(
        await HomeownerService.instance.fetchAccount(),
      );
      await preferences.cache();
    } catch (_) {
      preferences = await NotificationPreferences.loadCached() ??
          const NotificationPreferences();
    }
    if (generation != _sessionGeneration || _activeUserId != userId) {
      return false;
    }
    _preferences = preferences;
    await _startOpenAppAlerts(promptForPermission: promptForPermission);
    if (generation != _sessionGeneration || _activeUserId != userId) {
      return false;
    }
    if (!preferences.hasPushEnabled) {
      await unregisterActiveDevice(clearUser: false);
      _activatedUserId = userId;
      return true;
    }
    if (!isConfigured) {
      _activatedUserId = userId;
      return supportsOpenAppAlerts;
    }
    try {
      final activated = await requestPermissionAndRegister(
        userId: userId,
        preferences: preferences,
        promptForPermission: promptForPermission,
      );
      if (generation != _sessionGeneration || _activeUserId != userId) {
        return false;
      }
      if (activated) _activatedUserId = userId;
      return activated;
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'push notifications',
        context: ErrorDescription('while activating push for a signed-in user'),
      ));
      return false;
    }
  }

  Future<bool> requestPermissionAndRegister({
    required String userId,
    required NotificationPreferences preferences,
    bool promptForPermission = true,
  }) async {
    _activeUserId = userId;
    _preferences = preferences;
    if (!preferences.hasPushEnabled) return true;
    if (!isConfigured) {
      await _startOpenAppAlerts();
      return _foregroundPermissionGranted;
    }
    if (!await initialize()) return false;

    final generation = _sessionGeneration;
    var settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (promptForPermission &&
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    final permitted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!permitted ||
        generation != _sessionGeneration ||
        _activeUserId != userId) return false;

    final token = await _getFcmToken();
    if (token == null ||
        token.isEmpty ||
        generation != _sessionGeneration ||
        _activeUserId != userId) return false;
    await _registerToken(token, preferences);
    return generation == _sessionGeneration && _activeUserId == userId;
  }

  Future<void> updatePreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    _activeUserId = userId;
    _preferences = preferences;
    if (!preferences.hasPushEnabled) {
      _activityTimer?.cancel();
      _activityTimer = null;
      await unregisterActiveDevice(clearUser: false);
      return;
    }
    await _startOpenAppAlerts();
    if (!isConfigured) return;
    try {
      final token = await _getFcmToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token, preferences);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push notifications',
          context: ErrorDescription('while refreshing the push device'),
        ),
      );
    }
  }

  Future<String?> _getFcmToken() async {
    final userId = _activeUserId;
    final generation = _sessionGeneration;
    return FcmTokenProvider.current().getToken(
      isCurrent: () =>
          userId != null &&
          _activeUserId == userId &&
          _sessionGeneration == generation &&
          AuthService.instance.userId == userId &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached,
    );
  }

  Future<void> _registerToken(
    String token,
    NotificationPreferences preferences,
  ) {
    final userId = _activeUserId;
    final generation = _sessionGeneration;
    final future = _registrationQueue.then((_) async {
      if (token.trim().isEmpty ||
          userId == null ||
          userId != _activeUserId ||
          userId != AuthService.instance.userId ||
          generation != _sessionGeneration ||
          _preferences?.hasPushEnabled != true) return;
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      await _registerTokenNow(token, _preferences ?? preferences);
    });
    // Rotation, initial registration, and resume cannot overwrite each other's
    // saved token ID. Keep the queue usable after a transient HTTP failure.
    _registrationQueue = future.catchError((Object _) {});
    return future;
  }

  Future<void> _registerTokenNow(
    String token,
    NotificationPreferences preferences,
  ) async {
    final userId = _activeUserId;
    if (userId == null || userId != AuthService.instance.userId) return;
    final generation = _sessionGeneration;
    final store = await SharedPreferences.getInstance();
    final pendingKey = '$_pendingDeletePrefix$userId';
    final pendingId = store.getString(pendingKey);
    if (pendingId != null && pendingId.isNotEmpty) {
      try {
        await HomeownerService.instance.removePushDevice(pendingId);
        await store.remove(pendingKey);
      } catch (_) {
        // Keep the old record queued for the next authenticated session.
      }
    }
    final previousToken = store.getString(_tokenValueKey);
    final previousTokenId = store.getString(_tokenIdKey);
    if (generation != _sessionGeneration ||
        _activeUserId != userId ||
        AuthService.instance.userId != userId) return;
    final tokenId = await HomeownerService.instance.registerPushDevice(
      token: token,
      platform: pushPlatformName(
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      ),
    );
    if (tokenId == null || tokenId.isEmpty) {
      throw StateError('The server did not return a push token ID.');
    }
    if (_sessionGeneration != generation ||
        _activeUserId != userId ||
        AuthService.instance.userId != userId) {
      // An in-flight POST must not attach a device to a session that ended.
      try {
        await HomeownerService.instance.removePushDevice(tokenId);
      } catch (_) {}
      return;
    }
    await store.setString(_tokenIdKey, tokenId);
    await store.setString(_tokenValueKey, token);
    if (previousToken != null && previousToken != token) {
      try {
        await StreamService.instance
            .syncPushDevice(previousToken, enabled: false);
      } catch (error, stackTrace) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push notifications',
          context: ErrorDescription('while removing a rotated Stream device'),
        ));
      }
      if (previousTokenId != null && previousTokenId != tokenId) {
        try {
          await HomeownerService.instance.removePushDevice(previousTokenId);
        } catch (error, stackTrace) {
          await store.setString(pendingKey, previousTokenId);
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'push notifications',
            context: ErrorDescription('while removing a rotated push token'),
          ));
        }
      }
    }
    try {
      await StreamService.instance.syncPushDevice(
        token,
        enabled: preferences.pushMessages,
      );
    } catch (_) {
      // The Stream socket may not be connected yet; it syncs after connect.
    }
  }

  Future<void> unregisterActiveDevice({bool clearUser = true}) async {
    final userId = _activeUserId;
    if (clearUser) {
      _sessionGeneration++;
      _activeUserId = null;
      _activatedUserId = null;
    }
    // Finish/retire in-flight registration while the old JWT is still valid.
    await _registrationQueue;
    if (clearUser && _chatListenerInstalled) {
      StreamService.instance.removeListener(_bindChatMessages);
      _chatListenerInstalled = false;
      await _chatMessageSubscription?.cancel();
      _chatMessageSubscription = null;
      _chatClient = null;
    }
    if (clearUser) {
      _activityTimer?.cancel();
      _activityTimer = null;
      _activityArrivals.reset();
      _activityFeedUnavailable = false;
    }
    final store = await SharedPreferences.getInstance();
    final tokenId = store.getString(_tokenIdKey);
    final token = store.getString(_tokenValueKey);
    if (token != null && token.isNotEmpty) {
      try {
        await StreamService.instance.syncPushDevice(token, enabled: false);
      } catch (_) {}
    }
    if (tokenId != null && tokenId.isNotEmpty) {
      try {
        await HomeownerService.instance.removePushDevice(tokenId);
        if (userId != null) {
          await store.remove('$_pendingDeletePrefix$userId');
        }
      } catch (_) {
        if (userId != null) {
          await store.setString('$_pendingDeletePrefix$userId', tokenId);
        }
      }
    }
    if (clearUser && isConfigured) {
      try {
        // A failed server DELETE must not leave this phone receiving the old
        // homeowner's pushes after another person signs in here.
        await FirebaseMessaging.instance.deleteToken();
      } catch (error, stackTrace) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push notifications',
          context:
              ErrorDescription('while invalidating the signed-out FCM token'),
        ));
      }
    }
    await store.remove(_tokenIdKey);
    await store.remove(_tokenValueKey);
    if (clearUser) {
      await NotificationPreferences.clearCache();
      _activeUserId = null;
      _activatedUserId = null;
      _preferences = null;
      NotificationNavigation.requestedRoute.value = null;
      if (_localInitialized) await _localNotifications.cancelAll();
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (!_shouldPresentData(message.data)) return;
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
      payload: jsonEncode(message.data),
    );
  }

  void _notifyFreshActivity(Map<String, dynamic> data) {
    if (_activeUserId == null) return;
    HomeownerService.instance.notifyIncomingNotification();
    final type =
        '${data['type'] ?? data['notification_type'] ?? ''}'.toLowerCase();
    if (type != 'message') {
      unawaited(HomeownerService.instance.syncInBackground());
    }
  }

  bool _shouldPresentData(Map<String, dynamic> data) {
    final preferences = _preferences;
    if (preferences == null) return true;
    final type =
        '${data['type'] ?? data['notification_type'] ?? ''}'.toLowerCase();
    switch (type) {
      case 'cap':
      case 'booking_confirmed':
      case 'en_route':
      case 'in_progress':
      case 'estimate':
      case 'reschedule':
      case 'reschedule_answered':
      case 'booking_cancelled':
      case 'rebooked':
      case 'completed':
      case 'no_show':
      case 'no_show_reply':
      case 'reminder':
      case 'work_order_status':
        return preferences.pushStatus;
      case 'message':
        return preferences.pushMessages;
      case 'credit':
      case 'reward':
      case 'receipt':
      case 'expiring_soon':
        return preferences.pushCredits;
      case 'promo':
      case 'promotion':
        return preferences.pushPromos;
      default:
        return preferences.hasPushEnabled;
    }
  }

  Future<void> dispose() async {
    _activityTimer?.cancel();
    _activityTimer = null;
    if (_lifecycleObserverInstalled) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverInstalled = false;
    }
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _chatMessageSubscription?.cancel();
    if (_chatListenerInstalled) {
      StreamService.instance.removeListener(_bindChatMessages);
      _chatListenerInstalled = false;
    }
    if (_logoutHookInstalled) {
      AuthService.instance.removeBeforeLogoutHook(unregisterActiveDevice);
      _logoutHookInstalled = false;
    }
    _foregroundSubscription = null;
    _tokenRefreshSubscription = null;
    _openedSubscription = null;
    _chatMessageSubscription = null;
    _chatClient = null;
    _initialized = false;
    _activeUserId = null;
    _activatedUserId = null;
    _preferences = null;
  }
}

import 'package:firebase_core/firebase_core.dart';

/// Firebase values are supplied only at build time. Keeping them outside source
/// control prevents development credentials from being shipped accidentally.
class PushNotificationConfig {
  PushNotificationConfig._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _authDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String vapidKey =
      String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );
}

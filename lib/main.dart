import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard_shell.dart';
import 'screens/password_reset_page.dart';
import 'services/auth_service.dart';
import 'services/supabase_config.dart';
import 'services/push_notification_service.dart';
import 'services/push_notification_config.dart';
import 'theme.dart';
import 'widgets/app_keyboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    // Supabase enables diagnostic console logs automatically in debug builds.
    // The app handles auth and network failures in its UI, so keep browser
    // developer output focused on actionable application errors.
    debug: false,
  );
  await AuthService.instance.loadSession();
  if (kReleaseMode && !PushNotificationConfig.isConfigured) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError(
          'Push notifications are disabled: Firebase dart-defines are missing.',
        ),
        library: 'push notifications',
      ),
    );
  }

  runApp(const MyApp());
  // Capture cold-start notification taps even if the user must sign in first.
  // This initializes listeners only; permission is requested after sign-in.
  unawaited(PushNotificationService.instance.initialize());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        if (AuthService.instance.isAuthenticated) {
          final userId = AuthService.instance.userId;
          if (userId != null) {
            unawaited(
              PushNotificationService.instance.activateForSignedInUser(userId),
            );
          }
        }
        return MaterialApp(
          // Recovery replaces any open login/chat route, not only the Home tab.
          key: ValueKey(AuthService.instance.showPasswordRecovery),
          title: 'Tradeworks One',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          navigatorObservers: [KeyboardNavigationObserver()],
          // v3.3 §1.2: honour the phone's text size, clamped to 0.9×–1.3×.
          // Layouts bend (rows stack, text wraps) inside that range; beyond
          // it they would clip.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
            child: AppKeyboard(child: child ?? const SizedBox.shrink()),
          ),
          // The marketplace is intentionally public. Authentication unlocks
          // account data and booking submission, not the initial app shell.
          home: AuthService.instance.showPasswordRecovery
              ? const PasswordResetPage()
              : const DashboardShell(),
        );
      },
    );
  }
}

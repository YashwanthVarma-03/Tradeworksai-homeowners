import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard_shell.dart';
import 'services/auth_service.dart';
import 'services/supabase_config.dart';
import 'services/push_notification_service.dart';
import 'theme.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        if (AuthService.instance.isAuthenticated) {
          // This sets up foreground handling but deliberately does not show a
          // system permission prompt. Consent is requested from Settings.
          unawaited(PushNotificationService.instance.initialize());
        }
        return MaterialApp(
          title: 'Tradeworks One',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          // v3.3 §1.2: honour the phone's text size, clamped to 0.9×–1.3×.
          // Layouts bend (rows stack, text wraps) inside that range; beyond
          // it they would clip.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
            child: child ?? const SizedBox.shrink(),
          ),
          // The marketplace is intentionally public. Authentication unlocks
          // account data and booking submission, not the initial app shell.
          home: const DashboardShell(),
        );
      },
    );
  }
}

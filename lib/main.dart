import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard_shell.dart';
import 'services/auth_service.dart';
import 'services/supabase_config.dart';
import 'services/push_notification_service.dart';
import 'theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

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
      builder: (context, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, currentMode, _) {
          if (AuthService.instance.isAuthenticated) {
            // This sets up foreground handling but deliberately does not show a
            // system permission prompt. Consent is requested from Settings.
            unawaited(PushNotificationService.instance.initialize());
          }
          return MaterialApp(
            title: 'TradeWorksAI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentMode,
            // The marketplace is intentionally public. Authentication unlocks
            // account data and booking submission, not the initial app shell.
            home: const DashboardShell(),
          );
        },
      ),
    );
  }
}

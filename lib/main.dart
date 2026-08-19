import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard_shell.dart';
import 'screens/onboarding_slider.dart';
import 'services/auth_service.dart';
import 'services/supabase_config.dart';
import 'services/stream_service.dart';
import 'theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  await AuthService.instance.loadSession();
  await StreamService.instance.initialize();

  if (AuthService.instance.isAuthenticated &&
      AuthService.instance.userId != null) {
    try {
      await StreamService.instance.ensureConnected();
    } catch (e) {
      if (kDebugMode) {
        print('Stream startup connect error: $e');
      }
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'TradeWorksAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: AuthService.instance.isAuthenticated
              ? const DashboardShell()
              : const OnboardingSlider(),
        );
      },
    );
  }
}

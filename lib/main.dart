import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/onboarding_slider.dart';
import 'screens/dashboard_shell.dart';
import 'services/auth_service.dart';

// Global ValueNotifier to control theme switches dynamically
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.loadSession();
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

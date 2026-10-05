import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homeowners_app/screens/guest_experience.dart';
import 'package:homeowners_app/screens/home_tab.dart';
import 'package:homeowners_app/screens/login_page.dart';
import 'package:homeowners_app/screens/password_reset_page.dart';
import 'package:homeowners_app/screens/signup_page.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/main_bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final outfit = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Outfit-Bold.ttf'));
    await Future.wait([
      materialIcons.load(),
      inter.load(),
      outfit.load(),
    ]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpPhone(
    WidgetTester tester,
    Widget child, {
    bool withNavigation = false,
    int selectedTab = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
          key: const ValueKey('phone-surface'),
          child: withNavigation
              ? Scaffold(
                  body: SafeArea(child: child),
                  bottomNavigationBar: MainBottomNavigation(
                    currentIndex: selectedTab,
                    onTap: (_) {},
                  ),
                )
              : child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('guest home matches the iteration one surface', (tester) async {
    await pumpPhone(
      tester,
      HomeTab(
        isGuest: true,
        onBookTap: () {},
        onJobTap: (_) {},
        onInboxTap: () {},
        onHelpTap: () {},
        onSearchQuery: (_) {},
        onCategorySelected: (_) {},
        onGuidesTap: () {},
        onManageHomeTap: () {},
        onCreateAccount: () {},
        onSignIn: () {},
      ),
      withNavigation: true,
    );

    expect(find.text('What do you need done?'), findsOneWidget);
    expect(find.text('See all 22'), findsOneWidget);
    expect(find.text('All 22'), findsOneWidget);
    expect(find.text('CREATE YOUR ACCOUNT'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.tap(find.text('Browse by category'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode!
          .hasFocus,
      isFalse,
    );

    await expectLater(
      find.byKey(const ValueKey('phone-surface')),
      matchesGoldenFile('goldens/guest-home.png'),
    );
  });

  testWidgets('bookings gate matches the iteration one surface',
      (tester) async {
    await pumpPhone(
      tester,
      GuestGateTab(
        icon: Icons.calendar_today_outlined,
        title: 'Sign in to view bookings',
        message:
            'Create an account to book services, track your work orders, and manage appointments.',
        onCreateAccount: () {},
        onSignIn: () {},
      ),
      withNavigation: true,
      selectedTab: 2,
    );

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('phone-surface')),
      matchesGoldenFile('goldens/guest-gate.png'),
    );
  });

  testWidgets('authentication screens keep the approved copy', (tester) async {
    await pumpPhone(tester, const LoginPage());
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('phone-surface')),
      matchesGoldenFile('goldens/guest-login.png'),
    );

    await pumpPhone(tester, const SignupPage());
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Read our Privacy Policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('phone-surface')),
      matchesGoldenFile('goldens/guest-signup.png'),
    );

    await pumpPhone(tester, const PasswordResetPage());
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Request reset link'), findsOneWidget);
    expect(find.text('you@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('phone-surface')),
      matchesGoldenFile('goldens/guest-reset.png'),
    );
  });
}

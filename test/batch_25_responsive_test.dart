import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/guest_experience.dart';
import 'package:homeowners_app/screens/home_tab.dart';
import 'package:homeowners_app/screens/login_page.dart';
import 'package:homeowners_app/screens/booking_success_screen.dart';
import 'package:homeowners_app/screens/work_orders/cap_approval.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/widgets/main_bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('key screens fit phone and tablet widths at large text',
      (tester) async {
    addTearDown(tester.view.reset);

    for (final (size, textScale) in [
      (const Size(320, 640), 1.3),
      (const Size(390, 844), 1.0),
      (const Size(390, 844), 1.3),
      (const Size(768, 1024), 1.3),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      Widget app(Widget screen, {bool withNavigation = false}) => MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: withNavigation
                ? Scaffold(
                    body: SafeArea(child: screen),
                    bottomNavigationBar: MainBottomNavigation(
                      currentIndex: 0,
                      onTap: (_) {},
                    ),
                  )
                : screen,
          );

      await tester.pumpWidget(app(
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
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('What do you need done?'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Home at ${size.width} wide and $textScale text scale');

      await tester.pumpWidget(app(GuestGateTab(
        icon: Icons.calendar_today_outlined,
        title: 'Sign in to view bookings',
        message: 'Create an account to book services and track your work.',
        onCreateAccount: () {},
        onSignIn: () {},
      )));
      await tester.pump();
      expect(find.text('Create account'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Guest gate at ${size.width} wide and $textScale text scale');

      await tester.pumpWidget(app(const LoginPage()));
      await tester.pump();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Sign in at ${size.width} wide and $textScale text scale');

      await tester.pumpWidget(app(const CapApprovalScreen(job: {
        'id': 24164,
        'quoteAmount': 460,
        'proName': 'Hutchins Plumbing',
        'serviceCategory': 'Plumbing',
        'quote': {
          'diagnosis': 'A leaking supply line needs repair.',
          'items': [
            {'label': 'Replace supply line', 'amount': 460},
          ],
        },
      })));
      await tester.pump();
      expect(find.text('Approve cap'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason:
              'Cap approval at ${size.width} wide and $textScale text scale');

      await tester.pumpWidget(app(const BookingSuccessScreen(
        woNumber: 'WO-24144',
        contractorName: 'Hutchins Plumbing',
        trade: 'Plumbing',
        service: 'Drain cleaning',
        price: r'$189.00',
        workOrder: {'workOrderType': 'rate_card'},
      )));
      await tester.pump();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason:
              'Confirmation at ${size.width} wide and $textScale text scale');
    }
  });
}

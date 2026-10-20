import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homeowners_app/widgets/app_keyboard.dart';
import 'package:homeowners_app/utils/us_phone.dart';
import 'package:homeowners_app/ui/tw.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/screens/account/home_profile.dart';

void main() {
  test('US phone formatting and E.164 validation', () {
    expect(formatUsPhone('+18134777350'), '(813) 477-7350');
    expect(usPhoneE164('(813) 477-7350'), '+18134777350');
    expect(usPhoneE164('+44 20 7946 0958'), isNull);
    expect(usPhoneE164('+91 8134777350'), isNull);
    expect(usPhoneE164('813'), isNull);
  });

  testWidgets('numeric Done closes keyboard and sticky Save stays above it',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      navigatorObservers: [KeyboardNavigationObserver()],
      builder: (context, child) => AppKeyboard(child: child!),
      home: Scaffold(
        body: ListView(children: [
          TextField(focusNode: focus, keyboardType: TextInputType.number)
        ]),
        bottomNavigationBar: TwStickyBar(
            children: [TwPrimaryButton(label: 'Save', onPressed: () {})]),
      ),
    ));
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(tester.getBottomLeft(find.widgetWithText(ElevatedButton, 'Save')).dy,
        lessThanOrEqualTo(500));
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paired actions stack at large type and retain equal heights',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: SizedBox(
                width: 320,
                child: TwButtonPair(children: [
                  TwPrimaryButton(label: 'Leave a review', onPressed: () {}),
                  TwSecondaryButton(label: 'Book again', onPressed: () {})
                ]),
              )),
        )));
    final first = tester.getRect(find.byType(ElevatedButton));
    final second = tester.getRect(find.byType(OutlinedButton));
    expect(first.height, 52);
    expect(second.height, 52);
    expect(first.width, second.width);
    expect(second.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'home profile selects default, switches drafts, and remembers the property',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final data = <String, dynamic>{
      'addresses': [
        {
          'id': 1,
          'street': '1 Main St',
          'city': 'Tampa',
          'state': 'FL',
          'zip': '33602'
        },
        {
          'id': 2,
          'street': '2 Main St',
          'city': 'Tampa',
          'state': 'FL',
          'zip': '33602',
          'isDefault': true
        },
      ],
      'homeProfiles': [
        {
          'addressId': 1,
          'propertyDetails': {'squareFootage': 1200}
        },
        {
          'addressId': 2,
          'propertyDetails': {'squareFootage': 2400}
        },
      ]
    };
    Future<void> mount() async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeProfileScreen(
              addresses: const [], loadProfiles: () async => data)));
      await tester.pumpAndSettle();
    }

    await mount();
    expect(find.text('2 properties'), findsOneWidget);
    expect(find.text('Save 2 Main St'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '1 Main St'));
    await tester.pumpAndSettle();
    expect(find.text('Save 1 Main St'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.text('Property details'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount();
    expect(find.text('Save 1 Main St'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

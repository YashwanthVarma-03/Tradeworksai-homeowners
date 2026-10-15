import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/home_tab.dart';
import 'package:homeowners_app/widgets/loading_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  HomeTab home({required bool isGuest}) => HomeTab(
        isGuest: isGuest,
        onBookTap: () {},
        onJobTap: (_) {},
        onInboxTap: () {},
        onHelpTap: () {},
        onSearchQuery: (_) {},
        onCategorySelected: (_) {},
        onGuidesTap: () {},
        onManageHomeTap: () {},
      );

  testWidgets(
      'home leaves the skeleton when a reused guest tab becomes authenticated',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: home(isGuest: true))),
    );
    await tester.pump();
    expect(find.byType(SkeletonPage), findsNothing);

    // Keep the same widget type and position, matching DashboardShell across
    // login so Flutter reuses the existing HomeTab State object.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: home(isGuest: false))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonPage), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

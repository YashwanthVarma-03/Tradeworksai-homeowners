import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/support_page.dart';
import 'package:homeowners_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Future.wait([
      (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
      (FontLoader('Outfit')
            ..addFont(rootBundle.load('assets/fonts/Outfit-SemiBold.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Outfit-Bold.ttf')))
          .load(),
    ]);
  });

  testWidgets('Help and support matches the expanded F09 screen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1460);
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const SupportPage(),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Common questions'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(
      find.textContaining('We vet every pro on TradeWorks ourselves'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/support-f09.png'),
    );

    await tester.enterText(find.byType(TextField).first, 'credits expire');
    await tester.pump();
    expect(find.text('Do my service credits expire?'), findsOneWidget);
    expect(find.text('How are contractors vetted?'), findsNothing);

    for (final (size, scale) in [
      (const Size(320, 640), 1.3),
      (const Size(390, 844), 1.3),
      (const Size(768, 1024), 1.3),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: SupportPage(key: ValueKey(size.width)),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Common questions'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Help at ${size.width} wide and $scale text scale');
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
            'goldens/support-${size.width.toInt()}-large.png'),
      );

      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();
      expect(find.text('Topic'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Contact form at ${size.width} wide');
    }
  });
}

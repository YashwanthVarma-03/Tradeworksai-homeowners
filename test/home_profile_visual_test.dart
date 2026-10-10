import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/account/home_profile.dart';
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

  final address = <String, dynamic>{
    'id': 1,
    'label': 'Home',
    'street': '1420 Sandpiper Way',
    'city': 'Riverview',
    'state': 'FL',
    'zip': '33578',
    'propertyType': 'Single-family',
  };
  final data = <String, dynamic>{
    'addresses': [address],
    'homeProfiles': [
      {
        'id': 22,
        'addressId': 1,
        'propertyDetails': {
          'squareFootage': 2100,
          'yearBuilt': 2008,
          'bedrooms': 3,
          'bathrooms': 2,
        },
        'systems': [
          {
            'id': 31,
            'type': 'hvac',
            'brand': 'Carrier',
            'model': 'Central air',
            'installedYear': 2018,
          },
          {
            'id': 32,
            'type': 'water_heater',
            'model': 'Gas',
            'installedYear': 2019,
            'lastServicedAt': '[VALUE]',
          }
        ],
        'accessNotes': {'text': 'Gate code 4521'},
        'documents': <Map<String, dynamic>>[],
      }
    ],
  };

  testWidgets('Home profile matches F05 at 390 and adapts to larger text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.padding = const FakeViewPadding(bottom: 16);
    tester.view.viewPadding = const FakeViewPadding(bottom: 16);
    addTearDown(tester.view.reset);

    Widget screen({double scale = 1}) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: HomeProfileScreen(
            addresses: [address],
            loadProfiles: () async => data,
          ),
        );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Documents & warranties'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home-profile-f05.png'),
    );

    for (final (size, scale) in [
      (const Size(320, 700), 1.3),
      (const Size(390, 844), 1.3),
      (const Size(768, 1024), 1.3),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(screen(scale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Home profile at ${size.width} wide');
      final fields = find.byType(TextFormField);
      expect(
        tester.getTopLeft(fields.at(0)).dy ==
            tester.getTopLeft(fields.at(1)).dy,
        size.width >= 360,
        reason: 'Property fields at ${size.width} wide',
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
            'goldens/home-profile-${size.width.toInt()}-large.png'),
      );
    }
  });
}

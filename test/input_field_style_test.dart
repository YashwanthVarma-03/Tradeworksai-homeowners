import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/theme.dart';
import 'package:homeowners_app/ui/tw.dart';
import 'package:homeowners_app/widgets/service_search_bar.dart';
import 'package:homeowners_app/widgets/service_zip_entry_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Form fields keep the same padding and state borders',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TwFieldLabel('Email address'),
              TextField(
                key: const ValueKey('form-field'),
                style: TwType.body(color: AppTheme.navy),
                decoration: TwInputs.decoration(hint: 'you@example.com'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('icon-field'),
                style: TwType.body(color: AppTheme.navy),
                decoration: TwInputs.decoration(
                  hint: 'Search guides',
                  prefix: const Icon(Icons.search, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byKey(const ValueKey('form-field')));
    expect(tester.getSize(find.byKey(const ValueKey('form-field'))).height, 48);
    expect(tester.getSize(find.byKey(const ValueKey('icon-field'))).height, 48);
    expect(field.decoration!.contentPadding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
    expect((field.decoration!.enabledBorder as OutlineInputBorder).borderSide,
        const BorderSide(color: AppTheme.cardBorder));
    expect((field.decoration!.focusedBorder as OutlineInputBorder).borderSide,
        const BorderSide(color: AppTheme.blue, width: 1.5));
    expect((field.decoration!.errorBorder as OutlineInputBorder).borderSide,
        const BorderSide(color: AppTheme.red, width: 1.5));

    await tester.tap(find.byKey(const ValueKey('form-field')));
    await tester.pump();
    expect(
        tester
            .widget<InputDecorator>(find.byType(InputDecorator).first)
            .isFocused,
        isTrue);
  });

  testWidgets('Service search keeps one neutral outline on focus',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 220);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ServiceSearchBar(
          controller: controller,
          focusNode: focus,
          hint: 'Search a service',
          onSubmit: () {},
          onPhotoTap: () {},
          onVoiceTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration!.focusedBorder, InputBorder.none);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    final containers = tester.widgetList<Container>(find.descendant(
      of: find.byType(ServiceSearchBar),
      matching: find.byType(Container),
    ));
    final outline = containers
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.border)
        .whereType<Border>()
        .first;
    expect(outline.top.color, AppTheme.border);
    expect(outline.top.width, 1);
  });

  testWidgets('ZIP field uses the white 48 pixel dialog treatment',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => showServiceZipEntryDialog(context, initialZip: ''),
            child: const Text('Change ZIP'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Change ZIP'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.fillColor, AppTheme.white);
    expect((field.decoration!.enabledBorder as OutlineInputBorder).borderSide,
        const BorderSide(color: AppTheme.border));
    expect(tester.getSize(find.byType(TextField)).height, 48);
  });
}

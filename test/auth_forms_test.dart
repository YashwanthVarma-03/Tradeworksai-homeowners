import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/screens/signup_page.dart';

void main() {
  testWidgets('signup requires eight characters and places Apple above Google',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Homeowner');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), '1234567');
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    await tester.enterText(fields.at(2), '12345678');
    expect(form.validate(), isTrue);
    expect(tester.getTopLeft(find.text('Continue with Apple')).dy,
        lessThan(tester.getTopLeft(find.text('Continue with Google')).dy));
    expect(find.text('Read our Privacy Policy'), findsOneWidget);
  });
}

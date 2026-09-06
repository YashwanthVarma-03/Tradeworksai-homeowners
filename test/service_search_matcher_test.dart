import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/utils/service_search_matcher.dart';

void main() {
  const terms = <String, List<String>>{
    'HVAC': ['HVAC', 'AC repair', 'air conditioner'],
    'Plumbing': ['Plumbing', 'drain cleaning', 'water heater'],
    'Electrical': ['Electrical', 'ceiling fan install'],
  };

  test('maps an HVAC transposition to HVAC', () {
    expect(
      ServiceSearchMatcher.bestCategory(
        query: 'havc',
        termsByCategory: terms,
      ),
      'HVAC',
    );
  });

  test('maps a reordered HVAC acronym to HVAC', () {
    expect(
      ServiceSearchMatcher.bestCategory(
        query: 'hcav',
        termsByCategory: terms,
      ),
      'HVAC',
    );
  });

  test('maps ordinary spelling mistakes to the correct category', () {
    expect(
      ServiceSearchMatcher.bestCategory(
        query: 'plubming',
        termsByCategory: terms,
      ),
      'Plumbing',
    );
  });

  test('does not force unrelated requests into a category', () {
    expect(
      ServiceSearchMatcher.bestCategory(
        query: 'passport renewal',
        termsByCategory: terms,
      ),
      isNull,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/services/browse_search_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('preserves a search submitted while Browse history is loading',
      () async {
    SharedPreferences.setMockInitialValues({
      BrowseSearchHistory.storageKey: ['AC repair'],
    });
    final history = BrowseSearchHistory();

    final loading = history.load();
    final firstSave = history.save('Leaky faucet');
    final secondSave = history.save('Electrical repair');

    await loading;
    expect(
      await firstSave,
      ['Leaky faucet', 'AC repair'],
    );
    expect(
      await secondSave,
      ['Electrical repair', 'Leaky faucet', 'AC repair'],
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(BrowseSearchHistory.storageKey),
      ['Electrical repair', 'Leaky faucet', 'AC repair'],
    );
  });

  test('deduplicates recent searches without changing their original casing',
      () async {
    SharedPreferences.setMockInitialValues({
      BrowseSearchHistory.storageKey: ['AC Repair', 'Drain cleaning'],
    });
    final history = BrowseSearchHistory();

    expect(
      await history.save(' ac repair '),
      ['ac repair', 'Drain cleaning'],
    );
  });

  test('uses one device cache before and after account state changes',
      () async {
    SharedPreferences.setMockInitialValues({});

    // Separate instances model a guest Home tab followed by the Home tab
    // after sign-in. The history is intentionally not account-scoped.
    await BrowseSearchHistory().save('Garage door repair');
    await BrowseSearchHistory().save('Window replacement');

    expect(
      await BrowseSearchHistory().load(),
      ['Window replacement', 'Garage door repair'],
    );
  });

  test('keeps only the five most recent unique searches', () async {
    SharedPreferences.setMockInitialValues({});
    final history = BrowseSearchHistory();

    for (final query in const [
      'HVAC repair',
      'Drain cleaning',
      'Electrical repair',
      'Roof repair',
      'Window replacement',
      'Lawn care',
    ]) {
      await history.save(query);
    }

    expect(
      await history.load(),
      [
        'Lawn care',
        'Window replacement',
        'Roof repair',
        'Electrical repair',
        'Drain cleaning',
      ],
    );
  });
}

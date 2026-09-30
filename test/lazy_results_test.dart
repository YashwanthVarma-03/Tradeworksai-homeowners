import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/utils/lazy_results.dart';

void main() {
  test('large categories show 12 at a time without fetching later categories',
      () async {
    var calls = 0;
    final pages = LazyResults<int>(keyOf: (n) => '$n', sources: [
      () async {
        calls++;
        return List.generate(25, (i) => i);
      },
      () async {
        calls++;
        return [25, 26];
      },
    ]);
    expect(await pages.nextPage(), List.generate(12, (i) => i));
    expect(calls, 1);
    expect(await pages.nextPage(), List.generate(12, (i) => i + 12));
    expect(calls, 1);
    expect(await pages.nextPage(), [24]);
    expect(calls, 1);
    expect(await pages.nextPage(), [25, 26]);
    expect(calls, 2);
    expect(pages.hasMore, false);
    expect(await pages.nextPage(), isEmpty);
  });

  test('concurrent scroll requests share one fetch and one page', () async {
    final response = Completer<List<int>>();
    var calls = 0;
    final pages = LazyResults<int>(keyOf: (n) => '$n', sources: [
      () {
        calls++;
        return response.future;
      },
    ]);
    final first = pages.nextPage();
    final second = pages.nextPage();
    expect(identical(first, second), true);
    response.complete([1, 2]);
    expect(await first, [1, 2]);
    expect(await second, [1, 2]);
    expect(calls, 1);
  });

  test('failed category retries without losing or repeating previous results',
      () async {
    var attempts = 0;
    final pages = LazyResults<int>(keyOf: (n) => '$n', sources: [
      () async => [1, 2],
      () async {
        if (++attempts == 1) throw Exception('offline');
        return [2, 3];
      },
    ]);
    expect(await pages.nextPage(), [1, 2]);
    await expectLater(pages.nextPage(), throwsException);
    expect(pages.hasMore, true);
    expect(await pages.nextPage(), [3]);
    expect(attempts, 2);
    expect(pages.hasMore, false);
  });

  test('empty and duplicate-only sources do not prematurely end browsing',
      () async {
    final pages = LazyResults<int>(keyOf: (n) => '$n', sources: [
      () async => [],
      () async => [1, 1],
      () async => [1],
      () async => [],
      () async => [2],
    ]);
    expect(await pages.nextPage(), [1]);
    expect(pages.hasMore, true);
    expect(await pages.nextPage(), [2]);
    expect(pages.hasMore, false);
  });
}

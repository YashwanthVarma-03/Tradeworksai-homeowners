import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the queries shown in Browse's recent-search list.
///
/// Reads and writes are serialized because Browse can restore its history while
/// a user submits their first typed, voice, or camera search. Without that
/// ordering, a late restore can replace the just-saved list in memory.
class BrowseSearchHistory {
  static const storageKey = 'browse_recent_searches';
  static const _maxEntries = 5;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<void> _pendingOperation = Future<void>.value();

  Future<List<String>> load() {
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      return _normalise(prefs.getStringList(storageKey) ?? const []);
    });
  }

  Future<List<String>> save(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return load();
    }

    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(storageKey) ?? const [];
      final updated = _normalise([trimmed, ...current]);
      await prefs.setStringList(storageKey, updated);
      revision.value++;
      return updated;
    });
  }

  static Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _pendingOperation.then((_) => operation());
    _pendingOperation = next.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return next;
  }

  static List<String> _normalise(Iterable<String> values) {
    final seen = <String>{};
    final results = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) {
        continue;
      }
      results.add(trimmed);
      if (results.length == _maxEntries) {
        break;
      }
    }
    return results;
  }
}

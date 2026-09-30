import 'dart:math';

/// Equal random opportunity, stable across navigation, filtering and refreshes.
class SessionProOrder {
  SessionProOrder({int? seed}) : _random = Random(seed);
  static final instance = SessionProOrder();
  final Random _random;
  final Map<String, double> _positions = {};

  List<T> arrange<T>(Iterable<T> values, String Function(T) identity) {
    final result = values.toList();
    for (final value in result) {
      _positions.putIfAbsent(identity(value), _random.nextDouble);
    }
    result.sort((a, b) {
      final score =
          _positions[identity(a)]!.compareTo(_positions[identity(b)]!);
      return score != 0 ? score : identity(a).compareTo(identity(b));
    });
    return result;
  }
}

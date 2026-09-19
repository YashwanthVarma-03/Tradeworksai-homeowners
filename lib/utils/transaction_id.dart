import 'dart:math';

/// Creates opaque client transaction identifiers for idempotent mutations.
abstract final class TransactionId {
  static final Random _random = Random.secure();

  static String create(String namespace) {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List.generate(
      3,
      (_) => _random.nextInt(0x100000000).toRadixString(36).padLeft(7, '0'),
    ).join();
    return '$namespace-$timestamp-$entropy';
  }
}

import 'dart:math';

/// Creates opaque client transaction identifiers for idempotent mutations.
abstract final class TransactionId {
  static final Random _random = Random.secure();

  static String uuid() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String create(String namespace) {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List.generate(
      3,
      (_) => _random.nextInt(0x100000000).toRadixString(36).padLeft(7, '0'),
    ).join();
    return '$namespace-$timestamp-$entropy';
  }
}

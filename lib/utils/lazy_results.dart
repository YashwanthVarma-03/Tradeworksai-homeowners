import 'dart:collection';

/// Loads sources only as needed, buffering APIs that return a whole category.
/// Failed sources remain available for retry; concurrent callers share a page.
class LazyResults<T> {
  LazyResults({required this.sources, required this.keyOf, this.pageSize = 12})
      : assert(pageSize > 0);

  final List<Future<List<T>> Function()> sources;
  final String Function(T) keyOf;
  final int pageSize;
  final Queue<T> _buffer = Queue<T>();
  final Set<String> _seen = {};
  int _sourceIndex = 0;
  Future<List<T>>? _pending;

  bool get hasMore => _buffer.isNotEmpty || _sourceIndex < sources.length;

  Future<List<T>> nextPage() {
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<List<T>> _load() async {
    while (_buffer.isEmpty && _sourceIndex < sources.length) {
      final items = await sources[_sourceIndex]();
      _sourceIndex++;
      _buffer.addAll(items.where((item) => _seen.add(keyOf(item))));
    }
    return List.generate(
      _buffer.length < pageSize ? _buffer.length : pageSize,
      (_) => _buffer.removeFirst(),
    );
  }
}

/// Lightweight, on-device matching for service names and categories.
///
/// It handles common one-character mistakes and adjacent-key transpositions
/// before the request reaches the network-backed intake layer.
class ServiceSearchMatcher {
  const ServiceSearchMatcher._();

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String? bestCategory({
    required String query,
    required Map<String, Iterable<String>> termsByCategory,
  }) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return null;

    String? match;
    var bestDistance = 1 << 30;
    var bestTermLength = 0;
    for (final entry in termsByCategory.entries) {
      for (final rawTerm in entry.value) {
        final term = normalize(rawTerm);
        if (term.isEmpty) continue;
        if (term.contains(normalizedQuery) || normalizedQuery.contains(term)) {
          return entry.key;
        }
        // Service acronyms are commonly entered with their characters in the
        // wrong order (for example, "hcav"). Treat an exact character-set
        // match as high confidence only for short, single-token acronyms.
        if (_isReorderedAcronym(normalizedQuery, term)) {
          return entry.key;
        }
        final distance = _damerauLevenshtein(normalizedQuery, term);
        if (distance <= _maximumDistance(normalizedQuery, term) &&
            (distance < bestDistance ||
                (distance == bestDistance && term.length > bestTermLength))) {
          match = entry.key;
          bestDistance = distance;
          bestTermLength = term.length;
        }
      }
    }
    return match;
  }

  static bool _isReorderedAcronym(String query, String term) {
    if (query.contains(' ') || term.contains(' ')) return false;
    if (query.length < 3 || query.length > 5 || query.length != term.length) {
      return false;
    }
    final queryCharacters = query.split('')..sort();
    final termCharacters = term.split('')..sort();
    for (var index = 0; index < queryCharacters.length; index++) {
      if (queryCharacters[index] != termCharacters[index]) return false;
    }
    return true;
  }

  static int _maximumDistance(String query, String term) {
    final length = query.length > term.length ? query.length : term.length;
    if (length <= 4) return 1;
    if (length <= 8) return 2;
    if (length <= 14) return 3;
    return 4;
  }

  static int _damerauLevenshtein(String source, String target) {
    final matrix = List<List<int>>.generate(
      source.length + 1,
      (row) => List<int>.generate(target.length + 1, (column) => 0),
    );
    for (var row = 0; row <= source.length; row++) {
      matrix[row][0] = row;
    }
    for (var column = 0; column <= target.length; column++) {
      matrix[0][column] = column;
    }
    for (var row = 1; row <= source.length; row++) {
      for (var column = 1; column <= target.length; column++) {
        final cost = source[row - 1] == target[column - 1] ? 0 : 1;
        var value = [
          matrix[row - 1][column] + 1,
          matrix[row][column - 1] + 1,
          matrix[row - 1][column - 1] + cost,
        ].reduce((current, next) => current < next ? current : next);
        if (row > 1 &&
            column > 1 &&
            source[row - 1] == target[column - 2] &&
            source[row - 2] == target[column - 1]) {
          value = value < matrix[row - 2][column - 2] + cost
              ? value
              : matrix[row - 2][column - 2] + cost;
        }
        matrix[row][column] = value;
      }
    }
    return matrix[source.length][target.length];
  }
}

import 'dart:math';

/// High-performance Damerau-Levenshtein distance & Russian/English stemmer
/// for typo-tolerant smart search.
class FuzzyMatcher {
  const FuzzyMatcher._();

  /// Calculates the Damerau-Levenshtein distance between [s1] and [s2].
  /// Supports:
  /// - Insertions
  /// - Deletions
  /// - Substitutions
  /// - Adjacent character transpositions (e.g. "порект" -> "проект")
  static int damerauLevenshtein(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;
    if (s1 == s2) return 0;

    // Fast-path length difference
    if ((len1 - len2).abs() > 3) return (len1 - len2).abs();

    final d = List.generate(
      len1 + 2,
      (_) => List<int>.filled(len2 + 2, 0),
      growable: false,
    );

    final maxDist = len1 + len2;
    d[0][0] = maxDist;
    for (int i = 0; i <= len1; i++) {
      d[i + 1][1] = i;
      d[i + 1][0] = maxDist;
    }
    for (int j = 0; j <= len2; j++) {
      d[1][j + 1] = j;
      d[0][j + 1] = maxDist;
    }

    final lastRow = <int, int>{};

    for (int i = 1; i <= len1; i++) {
      int db = 0;
      final char1 = s1.codeUnitAt(i - 1);

      for (int j = 1; j <= len2; j++) {
        final char2 = s2.codeUnitAt(j - 1);
        final i1 = lastRow[char2] ?? 0;
        final j1 = db;
        final cost = char1 == char2 ? 0 : 1;
        if (cost == 0) db = j;

        d[i + 1][j + 1] = [
          d[i][j + 1] + 1, // deletion
          d[i + 1][j] + 1, // insertion
          d[i][j] + cost, // substitution
          d[i1][j1] + (i - i1 - 1) + 1 + (j - j1 - 1), // transposition
        ].reduce(min);
      }
      lastRow[char1] = i;
    }

    return d[len1 + 1][len2 + 1];
  }

  /// Maximum allowed edit distance for a given query word length.
  /// - 1-3 chars: 0 typos (exact only)
  /// - 4-6 chars: 1 typo
  /// - 7+ chars: up to 2 typos
  static int maxAllowedDistance(int length) {
    if (length <= 3) return 0;
    if (length <= 6) return 1;
    return 2;
  }

  /// Extracts the base stem of a word by stripping common Russian and English suffixes.
  /// E.g. "проектах" -> "проект", "агентов" -> "агент", "fluttering" -> "flutter".
  static String stem(String rawWord) {
    var word = rawWord.trim().toLowerCase();
    if (word.length <= 3) return word;

    // Russian noun/adjective common grammatical endings
    const ruEndings = [
      'иями', 'ями', 'ами', 'ому', 'ему', 'ого', 'его', 'ыми', 'ими',
      'ов', 'ев', 'ей', 'ом', 'ем', 'ам', 'ям', 'ах', 'ях', 'ой', 'ей',
      'ий', 'ый', 'ая', 'яя', 'ое', 'ее', 'ые', 'ие', 'ых', 'их', 'ую', 'юю',
      'ет', 'ут', 'ют', 'ит', 'ят', 'ил', 'ила', 'или', 'ать', 'ять', 'ить',
      'а', 'я', 'о', 'е', 'у', 'ю', 'ы', 'и', 'ь',
    ];

    for (final ending in ruEndings) {
      if (word.length > ending.length + 3 && word.endsWith(ending)) {
        return word.substring(0, word.length - ending.length);
      }
    }

    // English common suffixes
    const enEndings = ['ing', 'ies', 'es', 'ed', 'er', 'ly', 's'];
    for (final ending in enEndings) {
      if (word.length > ending.length + 3 && word.endsWith(ending)) {
        return word.substring(0, word.length - ending.length);
      }
    }

    return word;
  }

  /// Determines if [target] matches [queryWord] either exactly, via prefix,
  /// stem, or fuzzy Damerau-Levenshtein distance.
  static FuzzyWordMatch? matchWord(String queryWord, String target) {
    final q = queryWord.trim().toLowerCase();
    final t = target.trim().toLowerCase();
    if (q.isEmpty || t.isEmpty) return null;

    if (q == t) {
      return FuzzyWordMatch(
        matchedWord: target,
        distance: 0,
        isExact: true,
        isPrefix: false,
        isStem: false,
      );
    }

    // Prefix match (for active typing)
    if (t.startsWith(q) && q.length >= 3) {
      return FuzzyWordMatch(
        matchedWord: target,
        distance: 0,
        isExact: false,
        isPrefix: true,
        isStem: false,
      );
    }

    // Stem match (e.g. "проектах" and "проект")
    final qStem = stem(q);
    final tStem = stem(t);
    if (qStem.length >= 3 && (qStem == tStem || t.startsWith(qStem) || q.startsWith(tStem))) {
      return FuzzyWordMatch(
        matchedWord: target,
        distance: 0,
        isExact: false,
        isPrefix: false,
        isStem: true,
      );
    }

    // Fuzzy distance check
    final maxDist = maxAllowedDistance(q.length);
    if (maxDist > 0 && (q.length - t.length).abs() <= maxDist) {
      final dist = damerauLevenshtein(q, t);
      if (dist <= maxDist) {
        return FuzzyWordMatch(
          matchedWord: target,
          distance: dist,
          isExact: false,
          isPrefix: false,
          isStem: false,
        );
      }
    }

    return null;
  }

  /// Extracts words from any text, ignoring punctuation and whitespace.
  static List<String> tokenize(String text) {
    if (text.isEmpty) return const [];
    return text
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Fuzzy snippet extraction: finds the best match location in [fullText]
  /// even if the query words contain typos or modified grammatical endings.
  static FuzzySnippetResult? extractFuzzySnippet(
    String fullText,
    String query, {
    int radius = 45,
  }) {
    if (fullText.trim().isEmpty || query.trim().isEmpty) return null;
    final queryWords = tokenize(query);
    if (queryWords.isEmpty) return null;

    final lowerText = fullText.toLowerCase();

    // 1. Try exact full phrase first
    final exactIdx = lowerText.indexOf(query.trim().toLowerCase());
    if (exactIdx != -1) {
      final start = (exactIdx - radius).clamp(0, fullText.length);
      final end = (exactIdx + query.length + radius).clamp(0, fullText.length);
      var sub = fullText.substring(start, end).replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
      if (start > 0) sub = '...$sub';
      if (end < fullText.length) sub = '$sub...';
      return FuzzySnippetResult(
        snippet: sub,
        matchedTerm: query.trim(),
        isFuzzy: false,
      );
    }

    // 2. Scan text words for matches
    final wordRegex = RegExp(r'[\p{L}\p{N}]+', unicode: true);
    final matches = wordRegex.allMatches(fullText).toList();

    int bestMatchStart = -1;
    int bestMatchEnd = -1;
    String? bestMatchedTerm;
    bool isFuzzy = false;
    int minDistance = 999;

    for (final m in matches) {
      final candidate = m.group(0)!;
      for (final qWord in queryWords) {
        final match = matchWord(qWord, candidate);
        if (match != null) {
          if (match.distance < minDistance) {
            minDistance = match.distance;
            bestMatchStart = m.start;
            bestMatchEnd = m.end;
            bestMatchedTerm = candidate;
            isFuzzy = !match.isExact;
            if (minDistance == 0 && match.isExact) break;
          }
        }
      }
      if (minDistance == 0 && !isFuzzy) break;
    }

    if (bestMatchStart == -1) return null;

    final start = (bestMatchStart - radius).clamp(0, fullText.length);
    final end = (bestMatchEnd + radius).clamp(0, fullText.length);
    var sub = fullText.substring(start, end).replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (start > 0) sub = '...$sub';
    if (end < fullText.length) sub = '$sub...';

    return FuzzySnippetResult(
      snippet: sub,
      matchedTerm: bestMatchedTerm,
      isFuzzy: isFuzzy,
    );
  }
}

class FuzzyWordMatch {
  final String matchedWord;
  final int distance;
  final bool isExact;
  final bool isPrefix;
  final bool isStem;

  const FuzzyWordMatch({
    required this.matchedWord,
    required this.distance,
    required this.isExact,
    required this.isPrefix,
    required this.isStem,
  });
}

class FuzzySnippetResult {
  final String snippet;
  final String? matchedTerm;
  final bool isFuzzy;

  const FuzzySnippetResult({
    required this.snippet,
    this.matchedTerm,
    required this.isFuzzy,
  });
}

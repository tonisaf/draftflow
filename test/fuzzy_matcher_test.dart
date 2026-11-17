import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/search/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher Damerau-Levenshtein', () {
    test('calculates correct distance for substitutions, deletions, transpositions', () {
      expect(FuzzyMatcher.damerauLevenshtein('скилы', 'скиллы'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('работаит', 'работает'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('порект', 'проект'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('инстуркция', 'инструкция'), 1);
      expect(FuzzyMatcher.damerauLevenshtein('flutter', 'flutter'), 0);
      expect(FuzzyMatcher.damerauLevenshtein('fluter', 'flutter'), 1);
    });

    test('respects maxAllowedDistance', () {
      expect(FuzzyMatcher.maxAllowedDistance(2), 0);
      expect(FuzzyMatcher.maxAllowedDistance(3), 0);
      expect(FuzzyMatcher.maxAllowedDistance(5), 1);
      expect(FuzzyMatcher.maxAllowedDistance(8), 2);
    });
  });

  group('FuzzyMatcher Stemming', () {
    test('stems Russian grammatical case and plural endings', () {
      expect(FuzzyMatcher.stem('проектах'), 'проект');
      expect(FuzzyMatcher.stem('проекте'), 'проект');
      expect(FuzzyMatcher.stem('проекты'), 'проект');
      expect(FuzzyMatcher.stem('агентов'), 'агент');
      expect(FuzzyMatcher.stem('скиллами'), 'скилл');
    });

    test('stems English endings', () {
      expect(FuzzyMatcher.stem('working'), 'work');
      expect(FuzzyMatcher.stem('projects'), 'project');
      expect(FuzzyMatcher.stem('configured'), 'configur');
    });
  });

  group('FuzzyMatcher Word Matching & Snippets', () {
    test('matches typos and stems in text', () {
      final match1 = FuzzyMatcher.matchWord('порект', 'проект');
      expect(match1, isNotNull);
      expect(match1!.distance, 1);

      final match2 = FuzzyMatcher.matchWord('проект', 'проектах');
      expect(match2, isNotNull);
      expect(match2!.isPrefix || match2.isStem, isTrue);

      final match3 = FuzzyMatcher.matchWord('работаит', 'работает');
      expect(match3, isNotNull);
      expect(match3!.isStem || match3.distance <= 1, isTrue);
    });

    test('extracts fuzzy snippet when typo is present', () {
      const text = 'Как работает: агент читает информацию о проекте и передаёт задачу';
      final res = FuzzyMatcher.extractFuzzySnippet(text, 'работаит');
      expect(res, isNotNull);
      expect(res!.snippet, contains('Как работает'));
      expect(res.matchedTerm, 'работает');
      expect(res.isFuzzy, isTrue);
    });
  });
}

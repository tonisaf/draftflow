import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/page_stats.dart';

void main() {
  test('PageStats counts words, characters and reading time correctly', () {
    final doc = Document(
      root: pageNode(
        children: [
          paragraphNode(text: 'Это тестовый параграф для проверки подсчета слов.'),
          headingNode(level: 1, text: 'Заголовок секции'),
          paragraphNode(text: 'Еще немного текста.'),
        ],
      ),
    );

    final stats = PageStats.fromDocument(doc, 'Моя заметка');
    // 'Моя заметка Это тестовый параграф для проверки подсчета слов. Заголовок секции Еще немного текста.'
    expect(stats.words, greaterThanOrEqualTo(12));
    expect(stats.characters, greaterThan(50));
    expect(stats.readingTimeMinutes, 1);
    expect(stats.summary, contains('мин чтения'));
  });

  test('PageStats pluralizes Russian words and characters accurately', () {
    const s1 = PageStats(words: 1, characters: 1, readingTimeMinutes: 1);
    expect(s1.wordsFormatted, '1 слово');
    expect(s1.charactersFormatted, '1 знак');

    const s2 = PageStats(words: 3, characters: 4, readingTimeMinutes: 2);
    expect(s2.wordsFormatted, '3 слова');
    expect(s2.charactersFormatted, '4 знака');

    const s5 = PageStats(words: 5, characters: 15, readingTimeMinutes: 3);
    expect(s5.wordsFormatted, '5 слов');
    expect(s5.charactersFormatted, '15 знаков');
  });
}

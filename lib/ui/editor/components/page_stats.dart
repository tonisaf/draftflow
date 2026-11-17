import 'package:appflowy_editor/appflowy_editor.dart';

class PageStats {
  final int words;
  final int characters;
  final int readingTimeMinutes;

  const PageStats({
    required this.words,
    required this.characters,
    required this.readingTimeMinutes,
  });

  static PageStats fromDocument(Document? doc, String title) {
    final buffer = StringBuffer(title);
    buffer.write(' ');
    if (doc != null) {
      void extractText(Node node) {
        final delta = node.delta;
        if (delta != null) {
          buffer.write(delta.toPlainText());
          buffer.write(' ');
        }
        for (final child in node.children) {
          extractText(child);
        }
      }
      extractText(doc.root);
    }

    final raw = buffer.toString();
    final cleanWords = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = cleanWords.length;
    final charCount = raw.replaceAll(RegExp(r'\s+'), '').length;
    final minutes = (wordCount / 200).ceil().clamp(1, 999);

    return PageStats(
      words: wordCount,
      characters: charCount,
      readingTimeMinutes: minutes,
    );
  }

  String get wordsFormatted {
    final mod10 = words % 10;
    final mod100 = words % 100;
    if (mod100 >= 11 && mod100 <= 19) return '$words слов';
    if (mod10 == 1) return '$words слово';
    if (mod10 >= 2 && mod10 <= 4) return '$words слова';
    return '$words слов';
  }

  String get charactersFormatted {
    final mod10 = characters % 10;
    final mod100 = characters % 100;
    if (mod100 >= 11 && mod100 <= 19) return '$characters знаков';
    if (mod10 == 1) return '$characters знак';
    if (mod10 >= 2 && mod10 <= 4) return '$characters знака';
    return '$characters знаков';
  }

  String get readingTimeFormatted => '~$readingTimeMinutes мин чтения';

  String get summary => '$wordsFormatted · $charactersFormatted · $readingTimeFormatted';
}

import 'dart:convert';
import '../../data/db/app_database.dart';
import '../../data/model/page_settings.dart';

class QuickTodoItem {
  final String text;
  final bool isChecked;

  const QuickTodoItem({
    required this.text,
    required this.isChecked,
  });
}

class QuickListItem {
  final String text;
  final bool isNumbered;
  final int number;

  const QuickListItem({
    required this.text,
    required this.isNumbered,
    this.number = 1,
  });
}

class QuickNoteCardData {
  final Page page;
  final PageSettings settings;
  final String textSnippet;
  final String? codeSnippet;
  final String? codeLanguage;
  final String? codeTitle;
  final List<QuickTodoItem> todoItems;
  final List<QuickListItem> listItems;
  final List<String> extractedTags;

  const QuickNoteCardData({
    required this.page,
    required this.settings,
    this.textSnippet = '',
    this.codeSnippet,
    this.codeLanguage,
    this.codeTitle,
    this.todoItems = const [],
    this.listItems = const [],
    this.extractedTags = const [],
  });

  bool hasTag(String targetTag) {
    final cleanTarget = targetTag.replaceFirst(RegExp(r'^#'), '').trim().toLowerCase();
    if (cleanTarget.isEmpty) return true;
    for (final tag in extractedTags) {
      if (tag.replaceFirst(RegExp(r'^#'), '').trim().toLowerCase() == cleanTarget) {
        return true;
      }
    }
    return false;
  }

  static QuickNoteCardData fromPageAndBlocks(Page page, List<Block> blocks) {
    final settings = pageSettingsFromProperties(page.properties);
    String? foundCode;
    String? foundLanguage;
    String? foundCodeTitle;
    final todos = <QuickTodoItem>[];
    final listItems = <QuickListItem>[];
    final textLines = <String>[];
    final tagsSet = <String>{};

    if (settings.tag != null && settings.tag!.trim().isNotEmpty) {
      final t = settings.tag!.trim();
      tagsSet.add(t.startsWith('#') ? t : '#$t');
    }

    _extractHashtags(page.title, tagsSet);

    int numberedCount = 0;

    for (final block in blocks) {
      if (block.trashedAt != null) continue;
      try {
        final map = jsonDecode(block.content);
        if (map is! Map) continue;
        final data = (map['data'] as Map?) ?? (map['attributes'] as Map?) ?? map;
        final rawDelta = data['delta'];
        final text = _extractDeltaText(rawDelta).trim();
        final blockType = map['type'] as String? ?? block.type;

        if (text.isNotEmpty) {
          _extractHashtags(text, tagsSet);
        }

        if (blockType == 'code' && foundCode == null && text.isNotEmpty) {
          foundCode = text;
          final rawLang = data['language'] as String?;
          foundLanguage = (rawLang != null && rawLang.trim().isNotEmpty)
              ? rawLang.trim().toUpperCase()
              : 'CODE';
          final rawTitle = data['title'] as String?;
          if (rawTitle != null && rawTitle.trim().isNotEmpty) {
            foundCodeTitle = rawTitle.trim();
          }
        } else if (blockType == 'todo_list' || blockType == 'todo') {
          if (text.isNotEmpty) {
            final checked = data['check'] == true || data['checked'] == true;
            todos.add(QuickTodoItem(text: text, isChecked: checked));
          }
        } else if (blockType == 'bulleted_list') {
          if (text.isNotEmpty && listItems.length < 6) {
            listItems.add(QuickListItem(text: text, isNumbered: false));
          }
        } else if (blockType == 'numbered_list') {
          if (text.isNotEmpty && listItems.length < 6) {
            numberedCount++;
            listItems.add(
              QuickListItem(text: text, isNumbered: true, number: numberedCount),
            );
          }
        } else if (text.isNotEmpty && textLines.length < 5) {
          textLines.add(text);
        }
      } catch (_) {
        // Fallback for unparseable raw block content
        if (block.content.trim().isNotEmpty && textLines.length < 3) {
          final contentStr = block.content.trim();
          textLines.add(contentStr);
          _extractHashtags(contentStr, tagsSet);
        }
      }
    }

    return QuickNoteCardData(
      page: page,
      settings: settings,
      textSnippet: textLines.join('\n'),
      codeSnippet: foundCode,
      codeLanguage: foundLanguage,
      codeTitle: foundCodeTitle,
      todoItems: todos,
      listItems: listItems,
      extractedTags: tagsSet.toList(),
    );
  }

  static void _extractHashtags(String source, Set<String> target) {
    if (source.isEmpty) return;
    final regex = RegExp(r'#([a-zA-Zа-яА-Я0-9_-]+)');
    for (final match in regex.allMatches(source)) {
      final tag = match.group(0);
      if (tag != null && tag.length > 1) {
        target.add(tag);
      }
    }
  }

  static String _extractDeltaText(dynamic delta) {
    if (delta is List) {
      final sb = StringBuffer();
      for (final op in delta) {
        if (op is Map && op['insert'] != null) {
          sb.write(op['insert']);
        }
      }
      return sb.toString();
    } else if (delta is String) {
      return delta;
    }
    return '';
  }
}

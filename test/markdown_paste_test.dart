import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/editor/components/html_paste.dart';
import 'package:notes_here/ui/editor/components/inline_code_background.dart';
import 'package:notes_here/ui/editor/components/markdown_paste.dart';
import 'package:notes_here/ui/editor/components/notes_paragraph_component.dart';
import 'package:notes_here/ui/editor/components/notes_text_span_decorator.dart';
import 'package:notes_here/ui/editor/components/smooth_page_block_component.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const macosWindowChannel = MethodChannel('notes_here/macos_window');

  tearDown(() {
    AppFlowyClipboard.mockSetData(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(macosWindowChannel, null);
  });

  group('looksLikeMarkdown', () {
    test('detects headings, lists, inline code, bold, and code fences', () {
      expect(looksLikeMarkdown('### **Что исправлено**'), isTrue);
      expect(looksLikeMarkdown('- Пункт списка'), isTrue);
      expect(looksLikeMarkdown('1. Первый шаг'), isTrue);
      expect(looksLikeMarkdown('- [ ] Задача'), isTrue);
      expect(looksLikeMarkdown('> Цитата'), isTrue);
      expect(looksLikeMarkdown('```dart\nfinal a = 1;\n```'), isTrue);
      expect(looksLikeMarkdown('`task-493` ещё выполняется'), isTrue);
      expect(looksLikeMarkdown('Это **важно**'), isTrue);
      expect(looksLikeMarkdown('[Docs](https://example.com)'), isTrue);
    });

    test('does not misclassify plain multi-line text or snake_case as markdown',
        () {
      expect(looksLikeMarkdown('Обычный текст без разметки'), isFalse);
      expect(looksLikeMarkdown('Первая строка\nВторая строка'), isFalse);
      expect(
        looksLikeMarkdown('export_import_dialog.dart и _importError'),
        isFalse,
      );
      expect(looksLikeMarkdown('2 * 3 = 6'), isFalse);
    });
  });

  group('Markdown paste via smartLinkPasteCommand', () {
    test('pastes chat-like markdown into structured headings, lists, and code',
        () async {
      const chatMarkdown = '''
`task-493` ещё выполняется, жду завершения.

Окно импорта/экспорта и резервного копирования (export_import_dialog.dart) приведено к новому дизайну, пересобрано и запущено:

### **Что исправлено**

- **Таблица предпросмотра CSV:** исправлен альфа-баг в шапке (`skin.hover` вместо `surfaceVariant.withValues(alpha: 0.8)`).
- **Кнопки, табы, пилюли и закрытие:**
  - В шапке используется `CloseCross`.
  - `_TabButton`, `_ModePill` и `_ActionButton` переведены на `QuietButton`.
''';

      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: chatMarkdown),
      );

      final result = smartLinkPasteCommand.handler(editorState);
      expect(result, equals(KeyEventResult.handled));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      // Expected blocks: paragraph(`task-493`...), paragraph(Окно...), heading(Что исправлено), bullet(Таблица...), bullet(Кнопки...)
      expect(children.length, equals(5));

      // 1st block: paragraph with inline code `task-493`
      expect(children[0].type, equals(ParagraphBlockKeys.type));
      expect(
        children[0].delta!.toPlainText(),
        equals('task-493 ещё выполняется, жду завершения.'),
      );
      final firstCodeOp = children[0].delta!.toList().first;
      expect(firstCodeOp.data, equals('task-493'));
      expect(firstCodeOp.attributes?[AppFlowyRichTextKeys.code], isTrue);

      // 2nd block: snake_case filename stays unformatted (not italic)
      expect(children[1].type, equals(ParagraphBlockKeys.type));
      expect(
        children[1].delta!.toPlainText(),
        contains('export_import_dialog.dart'),
      );
      final hasItalicInFilename = children[1].delta!.toList().any(
            (op) => op.attributes?[AppFlowyRichTextKeys.italic] == true,
          );
      expect(hasItalicInFilename, isFalse);

      // 3rd block: Heading level 3 with bold text, no raw ### or **
      expect(children[2].type, equals(HeadingBlockKeys.type));
      expect(children[2].attributes[HeadingBlockKeys.level], equals(3));
      expect(children[2].delta!.toPlainText(), equals('Что исправлено'));
      expect(
        children[2].delta!.toList().first.attributes?[AppFlowyRichTextKeys.bold],
        isTrue,
      );

      // 4th block: bullet item with bold label and inline code spans
      expect(children[3].type, equals(BulletedListBlockKeys.type));
      final fourthOps = children[3].delta!.toList();
      expect(fourthOps.first.data, equals('Таблица предпросмотра CSV:'));
      expect(fourthOps.first.attributes?[AppFlowyRichTextKeys.bold], isTrue);
      expect(
        fourthOps.any(
          (op) =>
              op.data == 'skin.hover' &&
              op.attributes?[AppFlowyRichTextKeys.code] == true,
        ),
        isTrue,
      );

      // 5th block: bullet item with 2 nested sub-bullets
      expect(children[4].type, equals(BulletedListBlockKeys.type));
      expect(children[4].children.length, equals(2));
      expect(children[4].children[0].type, equals(BulletedListBlockKeys.type));
      expect(
        children[4].children[0].delta!.toPlainText(),
        equals('В шапке используется CloseCross.'),
      );
      expect(
        children[4].children[1].delta!.toList().any(
              (op) =>
                  op.data == '_TabButton' &&
                  op.attributes?[AppFlowyRichTextKeys.code] == true,
            ),
        isTrue,
      );
    });

    test('pastes inline formatted markdown inside existing paragraph',
        () async {
      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(delta: Delta()..insert('Статус: ')),
          ],
        ),
      );
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 8)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: '`task-493` **готов**'),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(1));
      expect(children[0].type, equals(ParagraphBlockKeys.type));
      expect(children[0].delta!.toPlainText(), equals('Статус: task-493 готов'));
      expect(
        children[0].delta!.toList().any(
              (op) =>
                  op.data == 'task-493' &&
                  op.attributes?[AppFlowyRichTextKeys.code] == true,
            ),
        isTrue,
      );
      expect(
        children[0].delta!.toList().any(
              (op) =>
                  op.data == 'готов' &&
                  op.attributes?[AppFlowyRichTextKeys.bold] == true,
            ),
        isTrue,
      );
    });

    test('pastes single block markdown heading and fenced code block',
        () async {
      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(
          text: '## Заголовок\n\n```dart\nvoid main() {}\n```',
        ),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(2));
      expect(children[0].type, equals(HeadingBlockKeys.type));
      expect(children[0].attributes[HeadingBlockKeys.level], equals(2));
      expect(children[0].delta!.toPlainText(), equals('Заголовок'));
      expect(children[1].type, equals(codeBlockType));
      expect(children[1].attributes['language'], equals('dart'));
      expect(children[1].delta!.toPlainText(), equals('void main() {}'));
    });

    test('keeps plain multi-line text as separate paragraphs via fallback',
        () async {
      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: 'Первая строка\nВторая строка'),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(2));
      expect(children[0].delta!.toPlainText(), equals('Первая строка'));
      expect(children[1].delta!.toPlainText(), equals('Вторая строка'));
    });

    test('pasteTextWithoutFormattingCommand pastes raw markdown literally',
        () async {
      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: '### **Заголовок**'),
      );

      final result = pasteTextWithoutFormattingCommand.handler(editorState);
      expect(result, equals(KeyEventResult.handled));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(1));
      expect(children[0].type, equals(ParagraphBlockKeys.type));
      expect(children[0].delta!.toPlainText(), equals('### **Заголовок**'));
    });

    test('pastes ordered lists, checklists, blockquotes, and links', () async {
      const mixedMarkdown = '''
1. Первый шаг
2. Второй шаг

- [ ] Не сделано
- [x] Сделано

> Важная цитата с [ссылкой](https://example.com)
''';

      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: mixedMarkdown),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(5));
      expect(children[0].type, equals(NumberedListBlockKeys.type));
      expect(children[0].delta!.toPlainText(), equals('Первый шаг'));
      expect(children[1].type, equals(NumberedListBlockKeys.type));
      expect(children[1].delta!.toPlainText(), equals('Второй шаг'));
      expect(children[2].type, equals(TodoListBlockKeys.type));
      expect(children[2].attributes[TodoListBlockKeys.checked], isFalse);
      expect(children[3].type, equals(TodoListBlockKeys.type));
      expect(children[3].attributes[TodoListBlockKeys.checked], isTrue);
      expect(children[4].type, equals(QuoteBlockKeys.type));
      expect(
        children[4].delta!.toList().any(
              (op) =>
                  op.data == 'ссылкой' &&
                  op.attributes?[AppFlowyRichTextKeys.href] ==
                      'https://example.com',
            ),
        isTrue,
      );
    });

    test('ignores smartLinkPasteCommand when cursor is inside a code block',
        () async {
      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(language: 'dart'),
          ],
        ),
      );
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      final result = smartLinkPasteCommand.handler(editorState);
      expect(result, equals(KeyEventResult.ignored));
    });
  });

  group('Inline code pills across block types', () {
    testWidgets(
        'renders transparent span + single InlineCodeBackground for bullet list item',
        (tester) async {
      final skin = Skin.of(Brightness.light);
      final doc = Document(
        root: pageNode(
          children: [
            bulletedListNode(
              delta: Delta()
                ..insert('Use ')
                ..insert('CloseCross', attributes: {'code': true}),
            ),
            paragraphNode(
              delta: Delta()
                ..insert('Run ')
                ..insert('task-493', attributes: {'code': true}),
            ),
          ],
        ),
      );
      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleController(),
          child: MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [skin]),
            home: Scaffold(
              body: AppFlowyEditor(
                editorState: editorState,
                blockComponentBuilders: {
                  ...standardBlockComponentBuilderMap,
                  PageBlockKeys.type: SmoothPageBlockComponentBuilder(
                    enableBlockReorder: true,
                  ),
                  ParagraphBlockKeys.type: NotesParagraphBlockComponentBuilder(),
                  codeBlockType: CodeBlockComponentBuilder(),
                },
                editorStyle: EditorStyle.desktop(
                  textSpanDecorator: notesTextSpanDecorator,
                  textStyleConfiguration: TextStyleConfiguration(
                    code: TextStyle(
                      fontFamily: 'Consolas',
                      color: skin.inlineCode,
                      backgroundColor: skin.inlineCodeSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One InlineCodeBackground for bulleted_list + one inside NotesParagraphBlockComponentWidget
      expect(find.byType(InlineCodeBackground), findsNWidgets(2));

      // Verify the rendered RichText span for 'CloseCross' inside the bulleted list
      // received transparent backgroundColor + inlineCode foreground from notesTextSpanDecorator.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final inlineCodeSpans = <TextSpan>[];
      void collectSpans(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text == 'CloseCross') {
            inlineCodeSpans.add(span);
          }
          span.children?.forEach(collectSpans);
        }
      }

      for (final rt in richTexts) {
        collectSpans(rt.text);
      }
      expect(inlineCodeSpans, isNotEmpty);
      expect(
        inlineCodeSpans.first.style?.backgroundColor,
        equals(Palette.transparent),
      );
      expect(
        inlineCodeSpans.first.style?.color,
        equals(skin.inlineCode),
      );
    });
  });

  group('HTML clipboard paste (chat / browser / Notion parity)', () {
    test(
        'reads HTML via macOS native channel when plain text is stripped of headings/lists/code',
        () async {
      const chatHtml = '''
<meta charset='utf-8'>
<div style="color: rgb(230, 230, 230); background-color: rgb(24, 24, 24);">
  <h3>Что изменено</h3>
  <ol>
    <li>
      <p><strong>Умная вставка Markdown</strong> (<code>markdown_paste.dart</code>, <code>editor_flowy_config.dart</code>):</p>
      <ul>
        <li>Добавлены <code>looksLikeMarkdown</code> и <code>pasteMarkdownText</code>.</li>
        <li>Inline: (<code>**жирный**</code>, <em>курсив</em>, <a href="https://example.com">ссылка</a>).</li>
      </ul>
    </li>
    <li>
      <p><span style="font-weight: 600; color: rgb(255, 255, 255);">Плашки inline-кода</span></p>
    </li>
  </ol>
</div>
''';
      const strippedPlainText = '''
Что изменено

Умная вставка Markdown (markdown_paste.dart, editor_flowy_config.dart):

Добавлены looksLikeMarkdown и pasteMarkdownText.

Inline: (**жирный**, курсив, ссылка).

Плашки inline-кода
''';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(macosWindowChannel, (call) async {
        if (call.method == 'getClipboardHtml') {
          return chatHtml;
        }
        return null;
      });

      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: strippedPlainText),
      );

      final result = smartLinkPasteCommand.handler(editorState);
      expect(result, equals(KeyEventResult.handled));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(3));

      // Heading
      expect(children[0].type, equals(HeadingBlockKeys.type));
      expect(children[0].attributes[HeadingBlockKeys.level], equals(3));
      expect(children[0].delta!.toPlainText(), equals('Что изменено'));

      // Ordered list item #1 + nested bulleted list
      expect(children[1].type, equals(NumberedListBlockKeys.type));
      final item1Ops = children[1].delta!.toList();
      expect(item1Ops.first.data, equals('Умная вставка Markdown'));
      expect(item1Ops.first.attributes?[AppFlowyRichTextKeys.bold], isTrue);
      expect(
        item1Ops.any(
          (op) =>
              op.data == 'markdown_paste.dart' &&
              op.attributes?[AppFlowyRichTextKeys.code] == true,
        ),
        isTrue,
      );

      expect(children[1].children.length, equals(2));
      expect(
        children[1].children[0].type,
        equals(BulletedListBlockKeys.type),
      );
      expect(
        children[1].children[0].delta!.toList().any(
              (op) =>
                  op.data == 'looksLikeMarkdown' &&
                  op.attributes?[AppFlowyRichTextKeys.code] == true,
            ),
        isTrue,
      );

      // Verify `**жирный**` inside <code> keeps literal asterisks with code attribute
      final secondSubOps = children[1].children[1].delta!.toList();
      expect(
        secondSubOps.any(
          (op) =>
              op.data == '**жирный**' &&
              op.attributes?[AppFlowyRichTextKeys.code] == true &&
              op.attributes?[AppFlowyRichTextKeys.bold] == null,
        ),
        isTrue,
      );
      expect(
        secondSubOps.any(
          (op) =>
              op.data == 'ссылка' &&
              op.attributes?[AppFlowyRichTextKeys.href] == 'https://example.com',
        ),
        isTrue,
      );

      // Ordered list item #2 has bold from CSS font-weight: 600, without dark CSS colors
      expect(children[2].type, equals(NumberedListBlockKeys.type));
      final item2Op = children[2].delta!.toList().first;
      expect(item2Op.data, equals('Плашки inline-кода'));
      expect(item2Op.attributes?[AppFlowyRichTextKeys.bold], isTrue);
      expect(item2Op.attributes?[AppFlowyRichTextKeys.textColor], isNull);
      expect(item2Op.attributes?[AppFlowyRichTextKeys.backgroundColor], isNull);
    });

    test('parses pre/code blocks, quotes, task checkboxes, and dividers', () {
      const html = '''
<pre><code class="language-dart">void main() {
  print('hi');
}
</code></pre>
<blockquote><p>Цитата из веб-страницы</p></blockquote>
<ul>
  <li><input type="checkbox" checked> Готово</li>
  <li><input type="checkbox"> В работе</li>
</ul>
<hr>
''';
      final nodes = htmlToEditorNodes(html);
      expect(nodes.length, equals(5));
      expect(nodes[0].type, equals(codeBlockType));
      expect(nodes[0].attributes['language'], equals('dart'));
      expect(nodes[0].delta!.toPlainText(), equals("void main() {\n  print('hi');\n}"));
      expect(nodes[1].type, equals(QuoteBlockKeys.type));
      expect(nodes[1].delta!.toPlainText(), equals('Цитата из веб-страницы'));
      expect(nodes[2].type, equals(TodoListBlockKeys.type));
      expect(nodes[2].attributes[TodoListBlockKeys.checked], isTrue);
      expect(nodes[3].type, equals(TodoListBlockKeys.type));
      expect(nodes[3].attributes[TodoListBlockKeys.checked], isFalse);
      expect(nodes[4].type, equals(DividerBlockKeys.type));
    });

    test('prefers Markdown over non-semantic wrapper HTML (e.g. VS Code copy)',
        () async {
      const nonSemanticWrapperHtml =
          '<div style="color:#abb2bf;"><span>### **Заголовок из редактора**</span></div>';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(macosWindowChannel, (call) async {
        if (call.method == 'getClipboardHtml') {
          return nonSemanticWrapperHtml;
        }
        return null;
      });

      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: '### **Заголовок из редактора**'),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(1));
      expect(children[0].type, equals(HeadingBlockKeys.type));
      expect(children[0].attributes[HeadingBlockKeys.level], equals(3));
      expect(children[0].delta!.toPlainText(), equals('Заголовок из редактора'));
    });

    test('pastes single inline HTML code snippet inside existing paragraph',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(macosWindowChannel, (call) async {
        if (call.method == 'getClipboardHtml') {
          return '<code>task-493</code>';
        }
        return null;
      });

      final doc = Document(
        root: pageNode(children: [paragraphNode(delta: Delta()..insert('Issue: '))]),
      );
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 7)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: 'task-493'),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(1));
      expect(children[0].delta!.toPlainText(), equals('Issue: task-493'));
      expect(
        children[0].delta!.toList()[1].attributes?[AppFlowyRichTextKeys.code],
        isTrue,
      );
    });

    test('multi-block paste starting with divider replaces empty paragraph',
        () async {
      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: '---\n\nПосле разделителя'),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(2));
      expect(children[0].type, equals(DividerBlockKeys.type));
      expect(children[1].type, equals(ParagraphBlockKeys.type));
      expect(children[1].delta!.toPlainText(), equals('После разделителя'));
    });

    test('handles nbsp/zero-width chars and layout/ragged HTML tables safely',
        () {
      const messyHtml = '''
<p>\u00A0Привет\u200B,\u00A0мир!\u00A0</p>
<table></table>
<table>
  <tr><th>Col 1</th><th>Col 2</th></tr>
  <tr><td>Only 1 cell</td></tr>
</table>
''';
      final nodes = htmlToEditorNodes(messyHtml);
      expect(nodes.length, equals(2));
      expect(nodes[0].delta!.toPlainText(), equals('Привет, мир!'));
      expect(nodes[1].type, equals(TableBlockKeys.type));
      expect(nodes[1].attributes[TableBlockKeys.rowsLen], equals(2));
      expect(nodes[1].attributes[TableBlockKeys.colsLen], equals(2));
      // 2x2 table must have 4 cells after padding ragged second row
      expect(nodes[1].children.length, equals(4));
    });

    test('formats selected text as link when pasting bare https:// URL',
        () async {
      final doc = Document(
        root: pageNode(
          children: [paragraphNode(delta: Delta()..insert('Read the docs now'))],
        ),
      );
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0], offset: 9),
          end: Position(path: [0], offset: 13),
        ),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: 'https://example.com/guide'),
      );

      smartLinkPasteCommand.handler(editorState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final ops = editorState.document.root.children.first.delta!.toList();
      expect(
        ops.any(
          (op) =>
              op.data == 'docs' &&
              op.attributes?[AppFlowyRichTextKeys.href] ==
                  'https://example.com/guide',
        ),
        isTrue,
      );
    });

    test('smartCopyCommand and smartCutCommand send rich HTML including code blocks',
        () async {
      String? copiedText;
      String? copiedHtml;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(macosWindowChannel, (call) async {
        if (call.method == 'setClipboardData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedText = args['text'] as String?;
          copiedHtml = args['html'] as String?;
          return true;
        }
        return null;
      });

      final doc = Document(
        root: pageNode(
          children: [
            headingNode(level: 3, text: 'Title'),
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('final a = 1;'),
            ),
          ],
        ),
      );
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0], offset: 0),
          end: Position(path: [1], offset: 12),
        ),
      );

      final copyResult = smartCopyCommand.handler(editorState);
      expect(copyResult, equals(KeyEventResult.handled));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(copiedText, contains('Title'));
      expect(copiedText, contains('final a = 1;'));
      expect(copiedHtml, contains('<h3>Title</h3>'));
      expect(copiedHtml, contains('<pre><code class="language-dart">'));
      expect(copiedHtml, contains('final a = 1;'));

      // Cut deletes the selected range after writing clipboard
      final cutResult = smartCutCommand.handler(editorState);
      expect(cutResult, equals(KeyEventResult.handled));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        editorState.document.root.children
            .map((n) => n.delta?.toPlainText() ?? '')
            .join(),
        isEmpty,
      );
    });
  });
}

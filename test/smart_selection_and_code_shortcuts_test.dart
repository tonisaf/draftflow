import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  group('Two-stage select all command (smartSelectAllCommand)', () {
    testWidgets('1st Ctrl+A selects current block, 2nd Ctrl+A selects whole page', (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(delta: Delta()..insert('First paragraph with text')),
            paragraphNode(delta: Delta()..insert('Second paragraph with text')),
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('line 1\nline 2\nline 3'),
            ),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                codeBlockType: CodeBlockComponentBuilder(),
              },
              commandShortcutEvents: [
                smartSelectAllCommand,
                ...standardCommandShortcutEvents,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Put cursor inside the first paragraph at offset 5
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 5));
      await tester.pumpAndSettle();

      // First Ctrl+A execution
      final result1 = smartSelectAllCommand.execute(editorState);
      expect(result1, KeyEventResult.handled);
      await tester.pumpAndSettle();

      // Expect ONLY the first paragraph to be selected
      expect(editorState.selection, isNotNull);
      expect(editorState.selection!.start.path, [0]);
      expect(editorState.selection!.start.offset, 0);
      expect(editorState.selection!.end.path, [0]);
      expect(editorState.selection!.end.offset, 'First paragraph with text'.length);

      // Second Ctrl+A execution
      final result2 = smartSelectAllCommand.execute(editorState);
      expect(result2, KeyEventResult.handled);
      await tester.pumpAndSettle();

      // Expect ALL blocks on the page to be selected
      expect(editorState.selection, isNotNull);
      expect(editorState.selection!.start.path, [0]);
      expect(editorState.selection!.end.path, [2]); // 3rd block (index 2)
    });

    testWidgets('1st Ctrl+A inside code block selects code block, 2nd selects whole page', (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(delta: Delta()..insert('Header text')),
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('void main() {\n  runApp(const App());\n}'),
            ),
            paragraphNode(delta: Delta()..insert('Footer text')),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                codeBlockType: CodeBlockComponentBuilder(),
              },
              commandShortcutEvents: [
                smartSelectAllCommand,
                ...standardCommandShortcutEvents,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Put cursor inside the code block (index [1]) at offset 10
      editorState.selection = Selection.collapsed(Position(path: [1], offset: 10));
      await tester.pumpAndSettle();

      // 1st Ctrl+A -> selects only the code block
      final result1 = smartSelectAllCommand.execute(editorState);
      expect(result1, KeyEventResult.handled);
      await tester.pumpAndSettle();

      final codeText = 'void main() {\n  runApp(const App());\n}';
      expect(editorState.selection!.start.path, [1]);
      expect(editorState.selection!.start.offset, 0);
      expect(editorState.selection!.end.path, [1]);
      expect(editorState.selection!.end.offset, codeText.length);

      // 2nd Ctrl+A -> selects the whole document
      final result2 = smartSelectAllCommand.execute(editorState);
      expect(result2, KeyEventResult.handled);
      await tester.pumpAndSettle();

      expect(editorState.selection!.start.path, [0]);
      expect(editorState.selection!.end.path, [2]);
    });
  });

  group('Code block Enter & Shift+Enter shortcuts', () {
    testWidgets('Shift+Enter in code block exits into a new paragraph below', (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('final a = 1;\nfinal b = 2;'),
            ),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                codeBlockType: CodeBlockComponentBuilder(),
              },
              commandShortcutEvents: [
                exitCodeBlockOnShiftEnterCommand,
                ...standardCommandShortcutEvents,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cursor inside code block
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 5));
      await tester.pumpAndSettle();

      // Press Shift+Enter
      final result = exitCodeBlockOnShiftEnterCommand.execute(editorState);
      expect(result, KeyEventResult.handled);
      await tester.pumpAndSettle();

      // Document should now have 2 blocks: code block and paragraph
      expect(doc.root.children.length, 2);
      expect(doc.root.children[0].type, codeBlockType);
      expect(doc.root.children[1].type, ParagraphBlockKeys.type);

      // Cursor should be focused on the new paragraph at [1]
      expect(editorState.selection?.start.path, [1]);
    });

    testWidgets('Enter in code block inserts newline without exiting', (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('print(1);\n'),
            ),
          ],
        ),
      );

      final editorState = EditorState(document: doc);
      final characterShortcuts = buildEditorCharacterShortcuts(
        selectionMenuItems: [],
        selectionMenuStyle: getSelectionMenuStyle(Skin.of(Brightness.light), false),
        onInsertPageMention: (_, {isWikilink = false}) async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                codeBlockType: CodeBlockComponentBuilder(),
              },
              characterShortcutEvents: characterShortcuts,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cursor at the end of the code block (after trailing newline)
      final text = 'print(1);\n';
      editorState.selection = Selection.collapsed(Position(path: [0], offset: text.length));
      await tester.pumpAndSettle();

      // Find 'insert newline in code block'
      final enterShortcut = characterShortcuts.firstWhere((s) => s.key == 'insert newline in code block');
      final handled = await enterShortcut.execute(editorState);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      // The document should still only have 1 block (the code block did NOT exit into paragraph)
      expect(doc.root.children.length, 1);
      expect(doc.root.children[0].type, codeBlockType);
      expect(doc.root.children[0].delta?.toPlainText(), 'print(1);\n\n');
    });

    testWidgets('Multi-tap (triple tap) in code block selects current line, not whole block', (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('line 1\nline 2 with text\nline 3'),
            ),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                codeBlockType: CodeBlockComponentBuilder(),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find AppFlowyRichText within CodeBlockComponentWidget
      final richTextFinder = find.descendant(
        of: find.byType(CodeBlockComponentWidget),
        matching: find.byType(AppFlowyRichText),
      );
      expect(richTextFinder, findsOneWidget);

      final richTextCenter = tester.getCenter(richTextFinder);

      // Perform triple tap
      await tester.tapAt(richTextCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(richTextCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(richTextCenter);
      await tester.pumpAndSettle();

      // Ensure that selection is NOT the entire code block (0 to 30)
      final selection = editorState.selection?.normalized;
      expect(selection, isNotNull);
      final text = 'line 1\nline 2 with text\nline 3';
      final totalLength = text.length;

      // It must NOT select from 0 to totalLength
      expect(
        selection!.start.offset == 0 && selection.end.offset == totalLength,
        isFalse,
      );

      // And it must be confined to the line tapped
      final selectedSubstring = text.substring(selection.start.offset, selection.end.offset);
      expect(selectedSubstring.contains('\n'), isFalse);
    });
  });
}

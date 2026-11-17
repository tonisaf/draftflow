import 'package:notes_here/ui/common/app_icons.dart';

import 'dart:ui' show PointerDeviceKind;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/editor/components/code_highlighter.dart';
import 'package:notes_here/ui/theme.dart';

Future<TestGesture> _hoverCodeBlock(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(
    tester.getCenter(find.byType(CodeBlockComponentWidget).first),
  );
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  test('codeBlockNode creates node with default and custom attributes', () {
    final node = codeBlockNode(
      language: 'python',
      collapsed: true,
      delta: Delta()..insert('print("Hello world")'),
    );

    expect(node.type, 'code');
    expect(node.attributes['language'], 'python');
    expect(node.attributes['collapsed'], true);
    expect(node.delta?.toPlainText(), 'print("Hello world")');
  });

  testWidgets(
    'renders CodeBlockComponentWidget with header, language selector, and copy button',
    (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(
              language: 'dart',
              collapsed: false,
              delta: Delta()..insert('void main() {\n  print("Hello");\n}'),
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

      // Header actions are available without hover and do not cover code.
      expect(find.byKey(const Key('code_block_header')), findsOneWidget);
      expect(find.byKey(const Key('code_block_title')), findsOneWidget);

      // Verify Dart language label is displayed
      expect(find.text('Dart'), findsOneWidget);

      // Verify Copy button is present
      expect(find.byTooltip('Copy code'), findsOneWidget);
      expect(find.byIcon(AppIcons.docOnDoc), findsOneWidget);

      // Verify Mode toggle button is present
      expect(find.byTooltip('Collapse code'), findsOneWidget);
      expect(find.byKey(const Key('code_fold_button')), findsOneWidget);

      // Verify code snippet is rendered inside RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('void main()'),
        ),
        findsOneWidget,
      );

      // Tap Mode button to switch to Compact mode
      await tester.tap(find.byTooltip('Collapse code'));
      await tester.pumpAndSettle();

      final codeNode = doc.root.children.first;
      expect(codeNode.attributes['collapsed'], true);
      expect(find.byTooltip('Expand code'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);

      // Tap Mode button again to switch back to Full mode
      await tester.tap(find.byTooltip('Expand code'));
      await tester.pumpAndSettle();

      expect(codeNode.attributes['collapsed'], false);
      expect(find.byTooltip('Collapse code'), findsOneWidget);
    },
  );

  testWidgets('collapsed header expands long code snippets', (tester) async {
    final longCode = List.generate(15, (i) => 'line $i = $i;').join('\n');
    final doc = Document(
      root: pageNode(
        children: [
          codeBlockNode(
            language: 'javascript',
            collapsed: true,
            delta: Delta()..insert(longCode),
          ),
        ],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
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

    // The header remains accessible while the body is fully folded.
    expect(find.byTooltip('Expand code'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand code'));
    await tester.pumpAndSettle();

    final codeNode = doc.root.children.first;
    expect(codeNode.attributes['collapsed'], false);
    expect(find.byTooltip('Collapse code'), findsOneWidget);
    expect(find.byTooltip('Expand code'), findsNothing);
  });

  testWidgets(
    'pasting multiline code keeps all lines inside the code block without creating paragraphs',
    (tester) async {
      const multilineSnippet = '''import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_here/core/settings.dart';

class _SlowStore extends MemorySettingsStore {''';

      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(language: 'dart', collapsed: false, delta: Delta()),
          ],
        ),
      );

      final editorState = EditorState(document: doc);
      // Put cursor at start of code block
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      // Set clipboard data
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return const <String, dynamic>{'text': multilineSnippet};
          }
          return null;
        },
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
              commandShortcutEvents: [
                codeBlockPasteCommand,
                codeBlockPasteWithoutFormattingCommand,
                ...standardCommandShortcutEvents,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hover to reveal paste button
      await _hoverCodeBlock(tester);

      // Paste is a secondary action in the header menu.
      await tester.tap(find.byKey(const Key('code_more_actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste code'));
      await tester.pumpAndSettle();

      // Verify all lines are preserved inside the code block
      final codeNode = doc.root.children.first;
      expect(codeNode.type, codeBlockType);
      final text = codeNode.delta?.toPlainText() ?? '';
      expect(text.contains("import 'dart:async';"), true);
      expect(
        text.contains("import 'package:tasks_here/core/settings.dart';"),
        true,
      );
      expect(
        text.contains("class _SlowStore extends MemorySettingsStore {"),
        true,
      );

      // Verify NO additional paragraph nodes were created below it!
      expect(doc.root.children.length, 1);
    },
  );

  test('codeBlockPasteCommand keyboard handler pastes all lines directly into code node', () async {
    const multiline = 'line 1\nline 2\nline 3';
    final doc = Document(
      root: pageNode(
        children: [codeBlockNode(language: 'dart', delta: Delta())],
      ),
    );
    final editorState = EditorState(document: doc);
    editorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: [0], offset: 0)),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return const <String, dynamic>{'text': multiline};
          }
          return null;
        });

    final result = codeBlockPasteCommand.handler(editorState);
    expect(result, KeyEventResult.handled);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final node = doc.root.children.first;
    expect(node.delta?.toPlainText(), multiline);
    expect(doc.root.children.length, 1);
  });

  test('CodeHighlighter correctly highlights keywords, types, strings, comments and numbers', () {
    const code = '''
import 'dart:async';
// This is a comment
class _SlowStore extends MemorySettingsStore {
  final int count = 42;
}
''';
    final spans = CodeHighlighter.highlight(
      text: code,
      language: 'dart',
      isDark: true,
      fontName: 'Menlo',
    );

    expect(spans, isNotEmpty);

    // Verify 'import' has keyword styling (FontWeight.w400)
    final importSpan = spans.firstWhere((s) => s.text == 'import');
    expect(importSpan.style?.fontWeight, FontWeight.w400);
    expect(importSpan.style?.color, const Color(0xFFC678DD));

    // Verify string has string color
    final stringSpan = spans.firstWhere((s) => s.text == "'dart:async'");
    expect(stringSpan.style?.color, const Color(0xFF98C379));

    // Verify comment has italic style
    final commentSpan = spans.firstWhere(
      (s) => s.text == '// This is a comment',
    );
    expect(commentSpan.style?.fontStyle, FontStyle.italic);
    expect(commentSpan.style?.color, const Color(0xFF5C6370));

    // Verify type 'MemorySettingsStore' has type color
    final typeSpan = spans.firstWhere((s) => s.text == 'MemorySettingsStore');
    expect(typeSpan.style?.color, const Color(0xFFE5C07B));

    // Verify number '42' has number color
    final numberSpan = spans.firstWhere((s) => s.text == '42');
    expect(numberSpan.style?.color, const Color(0xFFD19A66));
  });

  test('CodeHighlighter adapts keywords based on selected language', () {
    const pyCode = 'def process(item):\n    return True';
    final pySpans = CodeHighlighter.highlight(
      text: pyCode,
      language: 'python',
      isDark: false,
      fontName: 'Menlo',
    );

    final defSpan = pySpans.firstWhere((s) => s.text == 'def');
    expect(defSpan.style?.fontWeight, FontWeight.w400);

    // For SQL, 'SELECT' is a keyword, but not in Python
    const sqlCode = 'SELECT id, name FROM users;';
    final sqlSpans = CodeHighlighter.highlight(
      text: sqlCode,
      language: 'sql',
      isDark: false,
      fontName: 'Menlo',
    );
    final selectSpan = sqlSpans.firstWhere((s) => s.text == 'SELECT');
    expect(selectSpan.style?.fontWeight, FontWeight.w400);
  });

  testWidgets(
    'Selecting a new language in CodeBlockComponent updates language attribute and triggers syntax highlight',
    (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            codeBlockNode(
              language: 'dart',
              delta: Delta()..insert('def calculate():\n    return 42'),
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

      // Hover to reveal language selector badge
      await _hoverCodeBlock(tester);

      // Initially displays Dart
      expect(find.text('Dart'), findsOneWidget);

      // Open language menu by tapping Dart button
      await tester.tap(find.text('Dart'));
      await tester.pumpAndSettle();

      // Select Python from popup menu
      expect(find.text('Python'), findsWidgets);
      await tester.tap(find.text('Python').last);
      await tester.pumpAndSettle();

      // Verify node attribute updated to python
      final codeNode = doc.root.children.first;
      expect(codeNode.attributes['language'], 'python');
      expect(find.text('Python'), findsOneWidget);
    },
  );

  testWidgets('animates height smoothly when expanding and collapsing', (
    tester,
  ) async {
    final longCode = List.generate(25, (i) => 'const item$i = $i;').join('\n');
    final doc = Document(
      root: pageNode(
        children: [
          codeBlockNode(
            language: 'javascript',
            collapsed: true,
            delta: Delta()..insert(longCode),
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

    final initialHeight = tester
        .getSize(find.byType(CodeBlockComponentWidget))
        .height;
    expect(initialHeight, lessThan(80));

    // Expand from the persistent title panel.
    await tester.tap(find.byTooltip('Expand code'));
    await tester.pump(); // Deliver tap event to start animation
    await tester.pump(
      const Duration(milliseconds: 120),
    ); // Advance 120ms into the animation

    final intermediateHeight = tester
        .getSize(find.byType(CodeBlockComponentWidget))
        .height;
    expect(intermediateHeight, greaterThan(initialHeight));

    // Let animation complete
    await tester.pumpAndSettle();
    final fullHeight = tester
        .getSize(find.byType(CodeBlockComponentWidget))
        .height;
    expect(fullHeight, greaterThan(intermediateHeight));
    expect(doc.root.children.first.attributes['collapsed'], false);

    // Reverse a collapse while it is in flight. Retargeting must preserve
    // presentation height rather than restart at an endpoint.
    final codeNode = doc.root.children.first;
    Future<void> setCollapsed(bool collapsed) async {
      final transaction = editorState.transaction;
      transaction.updateNode(codeNode, {
        ...codeNode.attributes,
        'collapsed': collapsed,
      });
      await editorState.apply(transaction);
    }

    await setCollapsed(true);
    await tester.pump();
    // The body fades out before the container starts shrinking.
    await tester.pump(Motion.foldContent + const Duration(milliseconds: 1));
    expect(
      tester.getSize(find.byType(CodeBlockComponentWidget)).height,
      closeTo(fullHeight, 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final closingHeight = tester
        .getSize(find.byType(CodeBlockComponentWidget))
        .height;
    expect(closingHeight, lessThan(fullHeight));
    expect(closingHeight, greaterThan(initialHeight));
    await setCollapsed(false);
    await tester.pump();
    final reversalHeight = tester
        .getSize(find.byType(CodeBlockComponentWidget))
        .height;
    expect(reversalHeight, closeTo(closingHeight, 1));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CodeBlockComponentWidget)).height,
      closeTo(fullHeight, 1),
    );

    // Switching accessibility preferences during flight immediately settles
    // geometry and leaves no active spatial animation.
    await setCollapsed(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CodeBlockComponentWidget)).height,
      closeTo(initialHeight, 1),
    );
    await setCollapsed(false);
    await tester.pump();
    expect(
      tester.getSize(find.byType(CodeBlockComponentWidget)).height,
      closeTo(fullHeight, 1),
    );
    await tester.pumpAndSettle(); // Drain the editor history debounce.
  });
}

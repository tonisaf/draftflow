import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  for (final lines in [3, 40, 180]) {
    testWidgets('fold height never rebounds at its endpoint ($lines lines)', (
      t,
    ) async {
      final node = codeBlockNode(
        language: 'sql',
        delta: Delta()
          ..insert(List.generate(lines, (i) => 'SELECT $i;').join('\n')),
      );
      final editor = EditorState(
        document: Document(root: pageNode(children: [node])),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editor,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                codeBlockType: CodeBlockComponentBuilder(),
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final block = find.byType(CodeBlockComponentWidget);
      final openHeight = t.getSize(block).height;
      await t.tap(find.byTooltip('Collapse code'));
      await t.pump();
      final heights = <double>[t.getSize(block).height];
      for (var i = 0; i < 110; i++) {
        await t.pump(const Duration(milliseconds: 16));
        heights.add(t.getSize(block).height);
      }
      var rebound = 0.0;
      for (var i = 1; i < heights.length; i++) {
        final increase = heights[i] - heights[i - 1];
        if (increase > rebound) rebound = increase;
      }
      expect(
        rebound,
        lessThan(0.01),
        reason:
            'Clipping an elastic spring at zero must not let the body reappear',
      );
      final foldedHeight = heights.last;
      expect(foldedHeight, lessThan(openHeight - 20));
      var lastStep = 0.0;
      for (var i = 1; i < heights.length; i++) {
        if (heights[i - 1] - foldedHeight < 1) {
          final step = (heights[i] - heights[i - 1]).abs();
          if (step > lastStep) lastStep = step;
        }
      }
      expect(
        lastStep,
        lessThan(0.4),
        reason: 'No visible snap in the last pixel',
      );
      await t.pumpAndSettle();
      expect(t.getSize(block).height, closeTo(foldedHeight, 0.001));
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      editor.dispose();
    });
  }
}

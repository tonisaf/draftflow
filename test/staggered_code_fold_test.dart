import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'code grows before revealing and fades before shrinking ($brightness)',
      (t) async {
        final node = codeBlockNode(
          collapsed: true,
          language: 'sql',
          delta: Delta()
            ..insert(List.generate(40, (i) => 'SELECT $i;').join('\n')),
        );
        final editor = EditorState(
          document: Document(root: pageNode(children: [node])),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(brightness),
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
        final extent = find.byKey(const Key('code_fold_extent'));
        final fade = find.byKey(const Key('code_fold_content'));
        double opacity() => t.widget<FadeTransition>(fade).opacity.value;
        double height() => t.getSize(extent).height;
        double shift() => t
            .widget<Transform>(
              find.descendant(of: fade, matching: find.byType(Transform)).first,
            )
            .transform
            .storage[13];
        Future<void> collapse(bool value) async {
          await editor.apply(
            editor.transaction
              ..updateNode(node, {...node.attributes, 'collapsed': value}),
          );
          await t.pump();
        }

        expect(height(), 0);
        await collapse(false);
        await t.pump(const Duration(milliseconds: 80));
        expect(height(), greaterThan(0));
        expect(opacity(), 0);
        expect(shift(), 8);
        final growingHeight = height();
        // Tick past the exact endpoint to deliver TickerFuture completion.
        await t.pump(const Duration(milliseconds: 81));
        final fullHeight = height();
        expect(fullHeight, greaterThan(growingHeight));
        expect(opacity(), 0);
        await t.pump(); // Start the next phase's ticker at this frame time.
        await t.pump(const Duration(milliseconds: 50));
        expect(height(), fullHeight);
        expect(opacity(), inExclusiveRange(0, 1));
        expect(shift(), inExclusiveRange(0, 8));
        await t.pumpAndSettle();
        expect(opacity(), 1);
        expect(shift(), 0);

        await collapse(true);
        await t.pump(const Duration(milliseconds: 50));
        expect(height(), fullHeight);
        expect(opacity(), inExclusiveRange(0, 1));
        // Reversing the reveal phase retains its current opacity and extent.
        final interruptedOpacity = opacity();
        await collapse(false);
        expect(opacity(), interruptedOpacity);
        await t.pumpAndSettle();
        expect(height(), fullHeight);
        expect(opacity(), 1);
        await collapse(true);
        await t.pump(Motion.foldContent + const Duration(milliseconds: 1));
        expect(opacity(), 0);
        expect(height(), fullHeight);
        await t.pump();
        await t.pump(const Duration(milliseconds: 80));
        expect(height(), inExclusiveRange(0, fullHeight));
        expect(opacity(), 0);
        await t.pumpAndSettle();
        expect(height(), 0);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        editor.dispose();
      },
    );
  }
}

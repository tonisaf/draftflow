import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/inline_code_background.dart';
import 'package:notes_here/ui/editor/components/notes_paragraph_component.dart';
import 'package:notes_here/ui/editor/components/notes_text_span_decorator.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('$brightness code surfaces remain opaque with Mica', () {
      final regular = Skin.of(brightness);
      final mica = Skin.of(brightness, mica: true);
      expect(mica.sidebar.a, 0);
      expect(mica.codeSurface.a, 1);
      expect(mica.inlineCodeSurface.a, 1);
      expect(mica.codeSurface, regular.codeSurface);
      expect(mica.inlineCodeSurface, regular.inlineCodeSurface);
    });
    for (final mica in [false, true]) {
      testWidgets(
        '$brightness mica=$mica inline code preserves text offsets and editing',
        (tester) async {
          final node = paragraphNode(
            delta: Delta()
              ..insert('Before ')
              ..insert(
                'curl --silent https://example.test',
                attributes: {'code': true, 'href': 'https://example.test'},
              )
              ..insert(' after'),
          );
          final state = EditorState(
            document: Document(root: pageNode(children: [node])),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(brightness, mica: mica),
              home: Builder(
                builder: (context) => Scaffold(
                  body: AppFlowyEditor(
                    editorState: state,
                    blockComponentBuilders: {
                      ...standardBlockComponentBuilderMap,
                      'paragraph': NotesParagraphBlockComponentBuilder(),
                    },
                    editorStyle: EditorStyle.desktop(
                      textSpanDecorator: notesTextSpanDecorator,
                      textStyleConfiguration: TextStyleConfiguration(
                        text: TextStyle(
                          fontSize: UiType.editorBody,
                          height: UiType.editorLineHeight,
                          color: context.skin.text,
                        ),
                        code: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: UiType.code,
                          color: context.skin.inlineCode,
                          backgroundColor: context.skin.inlineCodeSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InlineCodeBackground), findsOneWidget);
          expect(
            node.delta!.toPlainText(),
            'Before curl --silent https://example.test after',
          );
          final text = tester
              .widgetList<RichText>(find.byType(RichText))
              .firstWhere(
                (text) => text.text.toPlainText().contains('Before curl'),
              );
          expect(text.text.toPlainText(), node.delta!.toPlainText());
          state.selection = Selection.single(
            path: [0],
            startOffset: 7,
            endOffset: 11,
          );
          await state.deleteSelection(state.selection!);
          await state.insertTextAtPosition(
            'wget',
            position: Position(path: [0], offset: 7),
          );
          await tester.pumpAndSettle();
          expect(
            node.delta!.toPlainText(),
            'Before wget --silent https://example.test after',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }
}

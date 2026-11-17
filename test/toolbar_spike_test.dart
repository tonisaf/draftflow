import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  testWidgets('renders AppFlowyEditor with FloatingToolbar', (tester) async {
    final editorState = EditorState(
      document: Document(root: pageNode(children: [paragraphNode(text: 'Hello world')])),
    );
    final scrollController = EditorScrollController(editorState: editorState);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingToolbar(
            items: [
              ...markdownFormatItems,
              linkItem,
              buildTextColorItem(),
              buildHighlightColorItem(),
            ],
            editorState: editorState,
            editorScrollController: scrollController,
            textDirection: TextDirection.ltr,
            child: AppFlowyEditor(
              editorState: editorState,
              editorScrollController: scrollController,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.byType(FloatingToolbar), findsOneWidget);
  });
}

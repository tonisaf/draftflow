import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  testWidgets('renders AppFlowyEditor with 50 blocks', (tester) async {
    final nodes = List.generate(50, (i) => paragraphNode(text: 'Block $i'));
    final editorState = EditorState(document: Document(root: pageNode(children: nodes)));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: editorState,
          ),
        ),
      ),
    );
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });
}

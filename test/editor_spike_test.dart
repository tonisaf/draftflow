import 'package:flutter_test/flutter_test.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  test('generate 1000 nodes', () {
    final nodes = <Node>[];
    for (int i = 0; i < 1000; i++) {
      if (i % 5 == 0) {
        nodes.add(headingNode(level: 1, text: 'Heading Block #$i'));
      } else if (i % 5 == 1) {
        nodes.add(todoListNode(checked: i % 2 == 0, text: 'Todo task #$i - checking editor responsiveness'));
      } else {
        nodes.add(paragraphNode(text: 'Paragraph block #$i: This is a sample paragraph testing high performance, selection across multiple blocks, and keyboard cursor movement.'));
      }
    }
    final editorState = EditorState(document: Document(root: pageNode(children: nodes)));
    expect(editorState.document.root.children.length, 1000);
  });
}

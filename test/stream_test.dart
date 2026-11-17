import 'package:flutter_test/flutter_test.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

void main() {
  test('editor transaction stream check', () {
    final editorState = EditorState.blank();
    expect(editorState.transactionStream, isNotNull);
  });
}

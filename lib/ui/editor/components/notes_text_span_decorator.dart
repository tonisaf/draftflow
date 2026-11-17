import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

TextSpan notesTextSpanDecorator(
  BuildContext context,
  Node node,
  int index,
  TextInsert text,
  TextSpan before,
  TextSpan after,
) {
  final decorated = defaultTextSpanDecoratorForAttribute(
    context,
    node,
    index,
    text,
    before,
    after,
  );
  if (node.type == 'code' || text.attributes?['code'] != true) {
    return decorated;
  }
  return TextSpan(
    text: decorated.text,
    children: decorated.children,
    style: decorated.style?.copyWith(
      backgroundColor: Palette.transparent,
      color: context.skin.inlineCode,
      decoration: TextDecoration.none,
    ),
    recognizer: decorated.recognizer,
    mouseCursor: decorated.mouseCursor,
    onEnter: decorated.onEnter,
    onExit: decorated.onExit,
    semanticsLabel: decorated.semanticsLabel,
    locale: decorated.locale,
    spellOut: decorated.spellOut,
  );
}

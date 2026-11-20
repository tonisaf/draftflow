import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import 'editor_link_popover.dart';

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

  final href = text.attributes?[AppFlowyRichTextKeys.href] as String?;
  if (href != null && href.isNotEmpty) {
    Timer? timer;
    int tapCount = 0;
    final editorState = context.read<EditorState>();

    final tapGestureRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        tapCount += 1;
        timer?.cancel();
        // meta / ctrl + click or double click opens the link directly
        if (tapCount == 2 ||
            !editorState.editable ||
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) {
          tapCount = 0;
          await editorLaunchUrl(href);
          return;
        }
        timer = Timer(const Duration(milliseconds: 200), () {
          tapCount = 0;
          final selection = Selection.single(
            path: node.path,
            startOffset: index,
            endOffset: index + text.text.length,
          );
          editorState.updateSelectionWithReason(
            selection,
            reason: SelectionUpdateReason.uiEvent,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showModernLinkPopover(
              context,
              editorState,
              selection,
              true,
              initialUrl: href,
            );
          });
        });
      };

    return TextSpan(
      style: decorated.style,
      text: text.text,
      recognizer: tapGestureRecognizer,
      mouseCursor: SystemMouseCursors.click,
    );
  }

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

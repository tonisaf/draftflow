import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/model/database_initial_data.dart';
import '../../../data/notes_repository.dart';
import '../../common/app_icons.dart';
import '../../theme.dart';
import 'callout_block_component.dart';
import 'code_block_component.dart';
import 'collapsible_heading_component.dart';
import 'database_block_component.dart';
import 'notes_image_component.dart';
import 'notes_paragraph_component.dart';
import 'page_link_block_component.dart';
import 'smooth_page_block_component.dart';
import 'toggle_block_component.dart';

/// Builds the complete editor block map styled with Neo-HIG typography,
/// Notion-inspired asymmetric heading/list rhythm, and [Skin] tokens.
Map<String, BlockComponentBuilder> buildNotesBlockComponentBuilders(
  BuildContext context, {
  required bool smallText,
  required NotesRepository repository,
  required Map<String, DatabaseInitialData> initialDatabases,
  ValueChanged<String>? onNavigateToPage,
}) {
  final skin = context.skin;
  final baseLineHeight =
      (smallText ? UiType.body : UiType.editorBody) * UiType.editorLineHeight;
  final hintStyle = TextStyle(color: skin.hint);

  return {
    ...standardBlockComponentBuilderMap,
    PageBlockKeys.type: SmoothPageBlockComponentBuilder(
      enableBlockReorder: true,
    ),
    ParagraphBlockKeys.type: NotesParagraphBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s4),
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
    ),
    HeadingBlockKeys.type: CollapsibleHeadingBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: _headingPadding,
        placeholderText: (node) =>
            'Heading ${node.attributes[HeadingBlockKeys.level] ?? 1}',
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
      textStyleBuilder: (level) => _headingTextStyle(level, smallText: smallText),
    ),
    BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s2_5),
        placeholderText: (_) => AppFlowyEditorL10n.current.listItemPlaceholder,
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
      iconBuilder: (ctx, node) => _BulletedListMarker(
        node: node,
        lineHeight: baseLineHeight,
      ),
    ),
    NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s2_5),
        placeholderText: (_) => AppFlowyEditorL10n.current.listItemPlaceholder,
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
    ),
    TodoListBlockKeys.type: TodoListBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s2_5),
        placeholderText: (_) => AppFlowyEditorL10n.current.toDoPlaceholder,
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
      toggleChildrenTriggers: const [
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
      ],
      textStyleBuilder: (checked) => checked
          ? TextStyle(
              decoration: TextDecoration.lineThrough,
              decorationColor: skin.muted,
              color: skin.muted,
            )
          : const TextStyle(),
      iconBuilder: (ctx, node, onCheck) => _TodoCheckboxIcon(
        checked: node.attributes[TodoListBlockKeys.checked] == true,
        lineHeight: baseLineHeight,
        onTap: onCheck,
      ),
    ),
    QuoteBlockKeys.type: QuoteBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s6),
        placeholderText: (_) => AppFlowyEditorL10n.current.quote,
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
      iconBuilder: (_, _) => const _NotesQuoteBar(),
    ),
    DividerBlockKeys.type: DividerBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s12),
      ),
      lineColor: skin.hairlineBorder,
      height: UiSpace.s1,
    ),
    calloutBlockType: CalloutBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s6),
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
    ),
    toggleBlockType: ToggleBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s2_5),
        placeholderTextStyle: (_, {textSpan}) => hintStyle,
      ),
    ),
    ImageBlockKeys.type: buildNotesImageBlockComponentBuilder(context),
    codeBlockType: CodeBlockComponentBuilder(),
    pageLinkBlockType: PageLinkBlockComponentBuilder(
      repository: repository,
      onNavigateToPage: onNavigateToPage,
    ),
    databaseBlockType: DatabaseBlockComponentBuilder(
      initialData: initialDatabases,
      repository: repository,
      onNavigateToPage: onNavigateToPage,
    ),
  };
}

EdgeInsets _headingPadding(Node node) {
  final level = (node.attributes[HeadingBlockKeys.level] as int?) ?? 1;
  final isFirstTopLevel = node.path.length == 1 && node.path.first == 0;
  final (top, bottom) = switch (level) {
    1 => (isFirstTopLevel ? UiSpace.s8 : 24.0, 8.0),
    2 => (isFirstTopLevel ? UiSpace.s6 : 20.0, 6.0),
    3 => (isFirstTopLevel ? UiSpace.s4 : 16.0, 4.0),
    _ => (isFirstTopLevel ? UiSpace.s4 : 10.0, 2.0),
  };
  return EdgeInsets.only(top: top, bottom: bottom);
}

// Color is intentionally omitted so HeadingBlockComponentWidget.updateTextStyle
// preserves inline code/link colors while inheriting skin.text from body text.
TextStyle _headingTextStyle(int level, {required bool smallText}) =>
    switch (level) {
      1 => TextStyle(
        fontSize: smallText ? 24.0 : 26.0,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.45,
      ),
      2 => TextStyle(
        fontSize: smallText ? 19.0 : 21.0,
        fontWeight: FontWeight.w600,
        height: 1.28,
        letterSpacing: -0.3,
      ),
      3 => TextStyle(
        fontSize: smallText ? 16.0 : 17.5,
        fontWeight: FontWeight.w600,
        height: 1.32,
        letterSpacing: -0.15,
      ),
      _ => TextStyle(
        fontSize: smallText ? 14.0 : 15.0,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.05,
      ),
    };

class _BulletedListMarker extends StatelessWidget {
  const _BulletedListMarker({
    required this.node,
    required this.lineHeight,
  });

  final Node node;
  final double lineHeight;

  int get _depth {
    var depth = 0;
    var parent = node.parent;
    while (parent != null) {
      if (parent.type == BulletedListBlockKeys.type) {
        depth++;
      }
      parent = parent.parent;
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final textScaleFactor =
        context.read<EditorState>().editorStyle.textScaleFactor;
    final shapeIndex = _depth % 3;

    return Container(
      width: 24.0 * textScaleFactor,
      height: lineHeight,
      padding: EdgeInsets.only(left: 6.0 * textScaleFactor),
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 18.0 * textScaleFactor,
        child: Center(
          child: switch (shapeIndex) {
            0 => Container(
              width: UiSpace.s6 * textScaleFactor,
              height: UiSpace.s6 * textScaleFactor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skin.text.withValues(alpha: 0.78),
              ),
            ),
            1 => Container(
              width: UiSpace.s6 * textScaleFactor,
              height: UiSpace.s6 * textScaleFactor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: skin.text.withValues(alpha: 0.7),
                  width: UiSpace.s1_3,
                ),
              ),
            ),
            _ => Container(
              width: UiSpace.s5 * textScaleFactor,
              height: UiSpace.s5 * textScaleFactor,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(UiRadius.hairline),
                color: skin.text.withValues(alpha: 0.62),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _TodoCheckboxIcon extends StatefulWidget {
  const _TodoCheckboxIcon({
    required this.checked,
    required this.lineHeight,
    required this.onTap,
  });

  final bool checked;
  final double lineHeight;
  final VoidCallback onTap;

  @override
  State<_TodoCheckboxIcon> createState() => _TodoCheckboxIconState();
}

class _TodoCheckboxIconState extends State<_TodoCheckboxIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final textScaleFactor =
        context.read<EditorState>().editorStyle.textScaleFactor;
    final boxSize = 16.0 * textScaleFactor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 24.0 * textScaleFactor,
          height: widget.lineHeight,
          padding: EdgeInsets.only(left: 4.0 * textScaleFactor),
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18.0 * textScaleFactor,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                width: boxSize,
                height: boxSize,
                decoration: ShapeDecoration(
                  color: widget.checked
                      ? Palette.accent
                      : (_hover ? skin.hover : Palette.transparent),
                  shape: UiRadius.squircle(
                    UiSpace.s4 + UiSpace.s0_6,
                    side: widget.checked
                        ? BorderSide.none
                        : BorderSide(
                            color: _hover ? skin.text : skin.outline,
                            width: UiSpace.s1_5,
                          ),
                  ),
                ),
                child: widget.checked
                    ? Center(
                        child: Icon(
                          AppIcons.checkMark,
                          size: UiSpace.s11 * textScaleFactor,
                          color: Palette.onAccent,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesQuoteBar extends StatelessWidget {
  const _NotesQuoteBar();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final textScaleFactor =
        context.read<EditorState>().editorStyle.textScaleFactor;

    return Container(
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(
        minWidth: UiSpace.s18,
        minHeight: UiSpace.s20,
      ) * textScaleFactor,
      padding: const EdgeInsets.only(right: UiSpace.s10),
      child: Container(
        width: UiSpace.s3 * textScaleFactor,
        decoration: BoxDecoration(
          color: skin.outline,
          borderRadius: BorderRadius.circular(UiSpace.s2),
        ),
      ),
    );
  }
}

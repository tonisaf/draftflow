import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/app_icons.dart';
import '../../theme.dart';

/// Проверяет, скрыт ли блок с индексом [index] внутри свернутой секции заголовка H1-H3.
/// Правило: блок скрыт, если ему предшествует заголовок с `collapsed: true`,
/// и между ними нет заголовка того же или более высокого уровня.
bool isNodeHiddenByCollapsedHeading(List<Node> children, int index) {
  if (index < 0 || index >= children.length) return false;
  final current = children[index];
  final currentLevel = current.type == HeadingBlockKeys.type
      ? (current.attributes[HeadingBlockKeys.level] as int? ?? 1)
      : 999;

  int minHeadingLevelEncountered = 999;
  for (int i = index - 1; i >= 0; i--) {
    final prev = children[i];
    if (prev.type == HeadingBlockKeys.type) {
      final prevLevel = prev.attributes[HeadingBlockKeys.level] as int? ?? 1;
      if (prevLevel < minHeadingLevelEncountered) {
        minHeadingLevelEncountered = prevLevel;
        if (prevLevel < currentLevel) {
          if (prev.attributes['collapsed'] == true) {
            return true;
          }
        }
      }
    }
  }
  return false;
}

class CollapsibleHeadingBlockComponentBuilder extends BlockComponentBuilder {
  CollapsibleHeadingBlockComponentBuilder({
    super.configuration,
    this.textStyleBuilder,
  });

  final TextStyle Function(int level)? textStyleBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CollapsibleHeadingBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      textStyleBuilder: textStyleBuilder,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }
}

class CollapsibleHeadingBlockComponentWidget
    extends BlockComponentStatefulWidget {
  const CollapsibleHeadingBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.textStyleBuilder,
  });

  final TextStyle Function(int level)? textStyleBuilder;

  @override
  State<CollapsibleHeadingBlockComponentWidget> createState() =>
      _CollapsibleHeadingBlockComponentWidgetState();
}

class _CollapsibleHeadingBlockComponentWidgetState
    extends State<CollapsibleHeadingBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: HeadingBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  int get level => widget.node.attributes[HeadingBlockKeys.level] as int? ?? 1;
  bool get isCollapsed => widget.node.attributes['collapsed'] == true;

  bool _hovered = false;

  TextStyle? defaultTextStyle(int level) {
    final fontSizes = [32.0, 28.0, 24.0, 18.0, 18.0, 18.0];
    final fontSize = fontSizes.elementAtOrNull(level - 1) ?? 18.0;

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
  }

  Future<void> _toggleCollapsed() async {
    final transaction = editorState.transaction
      ..updateNode(widget.node, {'collapsed': !isCollapsed});
    await editorState.apply(transaction, withUpdateSelection: false);
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget headerContent = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: double.infinity,
        alignment: alignment,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            // Стрелочка сворачивания/разворачивания заголовка вынесена в левый гаттер,
            // чтобы заголовок лежал на одной вертикальной оси с обычным текстом (Notion/Craft).
            Positioned(
              left: -22.0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _HeadingChevronButton(
                  isCollapsed: isCollapsed,
                  visible: isCollapsed || _hovered,
                  onTap: _toggleCollapsed,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              textDirection: textDirection,
              children: [
                Flexible(
                  child: AppFlowyRichText(
                    key: forwardKey,
                    delegate: this,
                    node: widget.node,
                    editorState: editorState,
                    textAlign: alignment?.toTextAlign ?? textAlign,
                    textSpanDecorator: (textSpan) {
                      var result = textSpan.updateTextStyle(
                        textStyleWithTextSpan(textSpan: textSpan),
                      );
                      result = result.updateTextStyle(
                        widget.textStyleBuilder?.call(level) ??
                            defaultTextStyle(level),
                      );
                      return result;
                    },
                    placeholderText: placeholderText,
                    placeholderTextSpanDecorator: (textSpan) => textSpan
                        .updateTextStyle(
                          widget.textStyleBuilder?.call(level) ??
                              defaultTextStyle(level),
                        )
                        .updateTextStyle(
                          placeholderTextStyleWithTextSpan(textSpan: textSpan),
                        ),
                    textDirection: textDirection,
                    cursorColor: editorState.editorStyle.cursorColor,
                    selectionColor: editorState.editorStyle.selectionColor,
                    cursorWidth: editorState.editorStyle.cursorWidth,
                  ),
                ),
                if (isCollapsed) ...[
                  const SizedBox(width: 8),
                  _CollapsedSectionIndicator(
                    onTap: _toggleCollapsed,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    headerContent = Container(
      key: blockComponentKey,
      decoration: decoration,
      padding: padding,
      child: headerContent,
    );

    headerContent = BlockSelectionContainer(
      node: widget.node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: headerContent,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      headerContent = BlockComponentActionWrapper(
        node: widget.node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: headerContent,
      );
    }

    return headerContent;
  }
}

class _HeadingChevronButton extends StatefulWidget {
  final bool isCollapsed;
  final bool visible;
  final VoidCallback onTap;

  const _HeadingChevronButton({
    required this.isCollapsed,
    required this.visible,
    required this.onTap,
  });

  @override
  State<_HeadingChevronButton> createState() => _HeadingChevronButtonState();
}

class _HeadingChevronButtonState extends State<_HeadingChevronButton> {
  bool _btnHover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      opacity: widget.visible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _btnHover = true),
          onExit: (_) => setState(() => _btnHover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 18,
              height: 18,
              decoration: ShapeDecoration(
                color: _btnHover
                    ? skin.hover
                    : (widget.isCollapsed
                        ? Palette.accent.withValues(alpha: 0.12)
                        : Palette.transparent),
                shape: UiRadius.squircle(UiRadius.control),
              ),
              child: Center(
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  turns: widget.isCollapsed ? 0.0 : 0.25,
                  child: Icon(
                    AppIcons.chevronRight,
                    size: 12,
                    color: widget.isCollapsed
                        ? Palette.accent
                        : (_btnHover ? skin.text : skin.muted),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedSectionIndicator extends StatefulWidget {
  final VoidCallback onTap;

  const _CollapsedSectionIndicator({required this.onTap});

  @override
  State<_CollapsedSectionIndicator> createState() =>
      _CollapsedSectionIndicatorState();
}

class _CollapsedSectionIndicatorState
    extends State<_CollapsedSectionIndicator> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Tooltip(
      message: 'Развернуть секцию',
      preferBelow: false,
      waitDuration: Motion.tooltipDelay,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: ShapeDecoration(
              color: _hover
                  ? skin.hover
                  : Palette.accent.withValues(alpha: 0.10),
              shape: UiRadius.squircle(
                UiRadius.compact,
                side: BorderSide(
                  color: Palette.accent.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.chevronRight,
                  size: 10,
                  color: Palette.accent,
                ),
                const SizedBox(width: 2),
                Text(
                  '···',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Palette.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

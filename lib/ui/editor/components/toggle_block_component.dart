import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/locale_controller.dart';
import '../../common/app_icons.dart';
import '../../common/quiet_button.dart';
import '../../theme.dart';

const String toggleBlockType = 'toggle';

abstract final class ToggleBlockKeys {
  static const String type = toggleBlockType;
  static const String collapsed = 'collapsed';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

Node toggleNode({
  bool collapsed = false,
  String? text,
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  Iterable<Node>? children,
}) => Node(
  type: ToggleBlockKeys.type,
  attributes: {
    ToggleBlockKeys.collapsed: collapsed,
    ToggleBlockKeys.delta: (delta ?? (Delta()..insert(text ?? ''))).toJson(),
    ...?attributes,
    ToggleBlockKeys.textDirection: ?textDirection,
  },
  children: children ?? [],
);

class ToggleBlockComponentBuilder extends BlockComponentBuilder {
  ToggleBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ToggleBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class ToggleBlockComponentWidget extends BlockComponentStatefulWidget {
  const ToggleBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<ToggleBlockComponentWidget> createState() =>
      _ToggleBlockComponentWidgetState();
}

class _ToggleBlockComponentWidgetState extends State<ToggleBlockComponentWidget>
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
    debugLabel: ToggleBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  bool get _isCollapsed => node.attributes[ToggleBlockKeys.collapsed] == true;

  Future<void> _toggleCollapsed() async {
    final transaction = editorState.transaction
      ..updateNode(node, {ToggleBlockKeys.collapsed: !_isCollapsed});
    await editorState.apply(transaction, withUpdateSelection: false);
  }

  Future<void> _addFirstChild() async {
    if (!editorState.editable) return;
    final childPath = [...node.path, 0];
    final transaction = editorState.transaction
      ..insertNode(childPath, paragraphNode())
      ..afterSelection = Selection.collapsed(Position(path: childPath));
    await editorState.apply(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final textScaleFactor = editorState.editorStyle.textScaleFactor;
    final lineHeight =
        (editorState.editorStyle.textStyleConfiguration.text.fontSize ??
            UiType.editorBody) *
        UiType.editorLineHeight;

    Widget headerRow = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          QuietButton(
            key: ValueKey('toggle_chevron_${node.id}'),
            label: node.delta?.toPlainText() ?? context.l10n.togglePlaceholder,
            expanded: !_isCollapsed,
            onTap: () => unawaited(_toggleCollapsed()),
            builder: (context, {required hover, required focus, required pressed}) =>
                Container(
                  constraints: BoxConstraints(
                    minWidth: UiSpace.s24,
                    minHeight: lineHeight,
                  ) * textScaleFactor,
                  padding: const EdgeInsets.only(right: UiSpace.s4),
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: hover || focus ? skin.hover : Palette.transparent,
                      shape: UiRadius.squircle(
                        UiRadius.action,
                        side: focus
                            ? BorderSide(color: skin.outline)
                            : BorderSide.none,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(UiSpace.s2),
                      child: AnimatedRotation(
                        turns: _isCollapsed ? 0 : 0.25,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          AppIcons.chevronRight,
                          size: UiSpace.s14 * textScaleFactor,
                          color: hover ? skin.text : skin.muted,
                        ),
                      ),
                    ),
                  ),
                ),
          ),
          Flexible(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: context.l10n.togglePlaceholder,
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                    placeholderTextStyleWithTextSpan(textSpan: textSpan),
                  ),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );

    headerRow = Container(
      key: blockComponentKey,
      decoration: decoration,
      padding: padding,
      child: headerRow,
    );

    headerRow = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: headerRow,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      headerRow = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: headerRow,
      );
    }

    if (_isCollapsed) {
      return headerRow;
    }

    final childrenIndent = directionPadding(textDirection);
    final hasChildren = node.children.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerRow,
        Padding(
          padding: childrenIndent,
          child: hasChildren
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: editorState.renderer.buildList(
                    context,
                    node.children,
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: QuietButton(
                    key: ValueKey('toggle_empty_add_${node.id}'),
                    label: context.l10n.toggleEmptyHint,
                    onTap: editorState.editable
                        ? () => unawaited(_addFirstChild())
                        : null,
                    builder:
                        (
                          context, {
                          required hover,
                          required focus,
                          required pressed,
                        }) => DecoratedBox(
                          decoration: ShapeDecoration(
                            color: hover || focus
                                ? skin.hover
                                : Palette.transparent,
                            shape: UiRadius.squircle(UiRadius.small),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UiSpace.s6,
                              vertical: UiSpace.s4,
                            ),
                            child: Text(
                              context.l10n.toggleEmptyHint,
                              style: TextStyle(
                                fontSize: UiType.caption,
                                color: hover ? skin.muted : skin.hint,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
        ),
      ],
    );
  }

  EdgeInsets directionPadding(TextDirection direction) =>
      direction == TextDirection.rtl
      ? const EdgeInsets.only(right: UiSpace.s24)
      : const EdgeInsets.only(left: UiSpace.s24);
}

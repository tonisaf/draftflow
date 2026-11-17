import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../l10n/locale_controller.dart';
import '../../common/emoji_picker_dialog.dart';
import '../../common/quiet_button.dart';
import '../../theme.dart';

const String calloutBlockType = 'callout';

abstract final class CalloutBlockKeys {
  static const String type = calloutBlockType;
  static const String icon = 'icon';
  static const String tone = 'tone';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

Node calloutNode({
  String icon = '💡',
  String tone = 'neutral',
  String? text,
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  Iterable<Node>? children,
}) => Node(
  type: CalloutBlockKeys.type,
  attributes: {
    CalloutBlockKeys.icon: icon,
    CalloutBlockKeys.tone: tone,
    CalloutBlockKeys.delta: (delta ?? (Delta()..insert(text ?? ''))).toJson(),
    ...?attributes,
    CalloutBlockKeys.textDirection: ?textDirection,
  },
  children: children ?? [],
);

class CalloutBlockComponentBuilder extends BlockComponentBuilder {
  CalloutBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CalloutBlockComponentWidget(
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

class CalloutBlockComponentWidget extends BlockComponentStatefulWidget {
  const CalloutBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CalloutBlockComponentWidget> createState() =>
      _CalloutBlockComponentWidgetState();
}

class _CalloutBlockComponentWidgetState
    extends State<CalloutBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: CalloutBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  String get _icon {
    final raw = node.attributes[CalloutBlockKeys.icon] as String?;
    return raw != null && raw.isNotEmpty ? raw : '💡';
  }

  String get _tone =>
      (node.attributes[CalloutBlockKeys.tone] as String?) ?? 'neutral';

  (Color bg, Color border) _toneColors(Skin skin) => switch (_tone) {
    'info' => (
      Palette.accent.withValues(alpha: 0.08),
      Palette.accent.withValues(alpha: 0.24),
    ),
    'warning' => (skin.warningBg, skin.warningText.withValues(alpha: 0.28)),
    'danger' => (skin.dangerBg, skin.dangerText.withValues(alpha: 0.28)),
    'success' => (skin.successBg, skin.successText.withValues(alpha: 0.28)),
    _ => (skin.hover, skin.hairlineBorder),
  };

  Future<void> _pickIcon() async {
    if (!editorState.editable) return;
    final picked = await showEmojiPickerDialog(context, currentEmoji: _icon);
    if (!mounted || picked == null || picked == _icon) return;
    final transaction = editorState.transaction
      ..updateNode(node, {CalloutBlockKeys.icon: picked});
    await editorState.apply(transaction, withUpdateSelection: false);
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final skin = context.skin;
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final (bg, border) = _toneColors(skin);
    final hint = context.l10n.calloutPlaceholder;

    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        color: bg,
        shape: UiRadius.squircle(
          UiRadius.card,
          side: BorderSide(color: border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s14,
          vertical: UiSpace.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: textDirection,
          children: [
            QuietButton(
              key: ValueKey('callout_icon_${node.id}'),
              label: context.l10n.changeIcon,
              onTap: editorState.editable ? () => unawaited(_pickIcon()) : null,
              builder: (context, {required hover, required focus, required pressed}) =>
                  Container(
                    width: UiSpace.s26,
                    height: UiSpace.s24,
                    margin: const EdgeInsets.only(right: UiSpace.s8),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: hover || focus ? skin.hover : Palette.transparent,
                      shape: UiRadius.squircle(
                        UiRadius.small,
                        side: focus
                            ? BorderSide(color: skin.outline)
                            : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      _icon,
                      style: const TextStyle(fontSize: UiType.editorTitle, height: 1),
                    ),
                  ),
            ),
            Expanded(
              child: AppFlowyRichText(
                key: forwardKey,
                delegate: this,
                node: node,
                editorState: editorState,
                textAlign: alignment?.toTextAlign ?? textAlign,
                placeholderText: hint,
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
      ),
    );

    card = Container(
      key: blockComponentKey,
      width: double.infinity,
      padding: padding,
      child: card,
    );

    card = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: card,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      card = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: card,
      );
    }

    return card;
  }
}

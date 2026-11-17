import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/locale_controller.dart';
import '../../common/app_icons.dart';
import '../../common/menu.dart';
import '../../common/popover.dart';
import '../../theme.dart';
import 'callout_block_component.dart';
import 'code_block_component.dart';
import 'toggle_block_component.dart';

/// Moves one top-level block as one isolated editor transaction. The original
/// nodes (including their descendants and metadata) are retained.
Future<bool> movePageBlock(
  EditorState editor,
  Node source,
  Node target, {
  required bool after,
}) async {
  if (editor.isDisposed || !editor.editable) return false;
  final nodes = editor.document.root.children;
  final from = nodes.indexOf(source);
  final targetIndex = nodes.indexOf(target);
  if (from < 0 || targetIndex < 0 || from == targetIndex) return false;
  final slot = targetIndex + (after ? 1 : 0);
  final destination = slot - (from < slot ? 1 : 0);
  if (destination == from) return false;

  Position remap(Position position) {
    if (position.path.isEmpty) return position;
    final index = position.path.first;
    final mapped = index == from
        ? destination
        : from < destination && index > from && index <= destination
        ? index - 1
        : from > destination && index >= destination && index < from
        ? index + 1
        : index;
    return Position(
      path: [mapped, ...position.path.skip(1)],
      offset: position.offset,
    );
  }

  final selection = editor.selection;
  final transaction = editor.transaction;
  transaction.moveNode([slot], source);
  transaction.afterSelection = selection == null
      ? null
      : Selection(start: remap(selection.start), end: remap(selection.end));
  // Typing immediately before/after a move must remain a separate undo step.
  if (editor.undoManager.undoStack.isNonEmpty) {
    editor.undoManager.undoStack.last.seal();
  }
  await editor.apply(transaction, skipHistoryDebounce: true);
  return true;
}

/// Inserts an empty paragraph immediately above or below [target] as an
/// isolated undoable step and places the caret inside it.
Future<Node?> insertParagraphRelative(
  EditorState editor,
  Node target, {
  required bool after,
}) async {
  if (editor.isDisposed || !editor.editable) return null;
  final path = target.path;
  if (path.isEmpty) return null;
  final parent = target.parent;
  if (parent == null) return null;
  final index = parent.children.indexOf(target);
  if (index < 0) return null;

  final insertPath = [...path.take(path.length - 1), index + (after ? 1 : 0)];
  final paragraph = paragraphNode();
  final transaction = editor.transaction;
  transaction.insertNode(insertPath, paragraph);
  transaction.afterSelection = Selection.collapsed(
    Position(path: insertPath, offset: 0),
  );
  if (editor.undoManager.undoStack.isNonEmpty) {
    editor.undoManager.undoStack.last.seal();
  }
  await editor.apply(transaction, skipHistoryDebounce: true);
  return paragraph;
}

/// Duplicates [source] immediately below it as one isolated undoable step,
/// generating fresh IDs for the cloned node and all descendants.
Future<Node?> duplicatePageBlock(EditorState editor, Node source) async {
  if (editor.isDisposed || !editor.editable) return null;
  final nodes = editor.document.root.children;
  final index = nodes.indexOf(source);
  if (index < 0) return null;

  final clone = _cloneNodeWithFreshIds(source);
  final insertPath = [index + 1];
  final transaction = editor.transaction;
  transaction.insertNode(insertPath, clone);
  transaction.afterSelection = Selection.collapsed(
    Position(path: insertPath, offset: clone.delta?.length ?? 0),
  );
  if (editor.undoManager.undoStack.isNonEmpty) {
    editor.undoManager.undoStack.last.seal();
  }
  await editor.apply(transaction, skipHistoryDebounce: true);
  return clone;
}

/// Deletes [source] as one isolated undoable step. When deleting the last
/// remaining top-level block, replaces it with an empty paragraph so the page
/// remains editable.
Future<bool> deletePageBlock(EditorState editor, Node source) async {
  if (editor.isDisposed || !editor.editable) return false;
  final nodes = editor.document.root.children;
  final index = nodes.indexOf(source);
  if (index < 0) return false;

  final transaction = editor.transaction;
  if (nodes.length == 1) {
    final replacement = paragraphNode();
    transaction.insertNode([0], replacement);
    transaction.deleteNode(source);
    transaction.afterSelection = Selection.collapsed(Position(path: [0]));
  } else {
    transaction.deleteNode(source);
    if (index < nodes.length - 1) {
      transaction.afterSelection = Selection.collapsed(
        Position(path: [index]),
      );
    } else {
      final prev = nodes[index - 1];
      transaction.afterSelection = Selection.collapsed(
        Position(path: [index - 1], offset: prev.delta?.length ?? 0),
      );
    }
  }
  if (editor.undoManager.undoStack.isNonEmpty) {
    editor.undoManager.undoStack.last.seal();
  }
  await editor.apply(transaction, skipHistoryDebounce: true);
  return true;
}

/// Whether the node can be converted to another text-based block type.
bool isConvertibleBlock(Node node) {
  const convertibleTypes = {
    ParagraphBlockKeys.type,
    HeadingBlockKeys.type,
    BulletedListBlockKeys.type,
    NumberedListBlockKeys.type,
    TodoListBlockKeys.type,
    QuoteBlockKeys.type,
    codeBlockType,
    calloutBlockType,
    toggleBlockType,
  };
  return convertibleTypes.contains(node.type);
}

/// Transforms [source] into a different block type as an isolated undoable
/// step, preserving its text delta, text direction, and nested children.
Future<bool> turnPageBlockInto(
  EditorState editor,
  Node source,
  String targetType, {
  Map<String, dynamic>? attributes,
}) async {
  if (editor.isDisposed || !editor.editable) return false;
  final path = source.path;
  if (path.isEmpty) return false;

  final delta = source.delta ?? Delta();
  final textDirection =
      source.attributes[blockComponentTextDirection] as String?;

  final Node newNode;
  switch (targetType) {
    case HeadingBlockKeys.type:
      final level = (attributes?['level'] as int?) ?? 1;
      newNode = headingNode(
        level: level,
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case BulletedListBlockKeys.type:
      newNode = bulletedListNode(
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case NumberedListBlockKeys.type:
      newNode = numberedListNode(
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case TodoListBlockKeys.type:
      final checked = (attributes?['checked'] as bool?) ?? false;
      newNode = todoListNode(
        checked: checked,
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case QuoteBlockKeys.type:
      newNode = quoteNode(
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case codeBlockType:
      final lang = (attributes?['language'] as String?) ?? 'plaintext';
      newNode = codeBlockNode(
        language: lang,
        delta: delta,
      );
      break;
    case calloutBlockType:
      newNode = calloutNode(
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case toggleBlockType:
      newNode = toggleNode(
        delta: delta,
        textDirection: textDirection,
      );
      break;
    case ParagraphBlockKeys.type:
    default:
      newNode = paragraphNode(
        delta: delta,
        textDirection: textDirection,
      );
      break;
  }

  for (final child in source.children) {
    newNode.children.add(_cloneNodeWithFreshIds(child)..parent = newNode);
  }

  final transaction = editor.transaction;
  transaction.insertNode(path, newNode);
  transaction.deleteNode(source);
  final caretOffset = (editor.selection?.start.offset ?? delta.length)
      .clamp(0, delta.length);
  transaction.afterSelection = Selection.collapsed(
    Position(path: path, offset: caretOffset),
  );

  if (editor.undoManager.undoStack.isNonEmpty) {
    editor.undoManager.undoStack.last.seal();
  }
  await editor.apply(transaction, skipHistoryDebounce: true);
  return true;
}

/// Relative vertical offset within a block so the 28px grip centers on the
/// block's first line of text (added on top of `editorStyle.padding.top`).
double blockHandleTopOffset(Node node) {
  switch (node.type) {
    case 'code':
    case 'database':
    case 'image':
      return UiSpace.s8;
    case 'callout':
      return UiSpace.s14;
    case 'divider':
      return -UiSpace.s1_5;
    case 'quote':
      return UiSpace.s2;
    case 'heading':
      final level = (node.attributes['level'] as int?) ?? 1;
      final isFirst = node.path.length == 1 && node.path.first == 0;
      return switch (level) {
        1 => (isFirst ? UiSpace.s6 : UiSpace.s24) + UiSpace.s2,
        2 => isFirst ? UiSpace.s6 : UiSpace.s18,
        3 => isFirst ? UiSpace.s2 : UiSpace.s11_5,
        _ => isFirst ? 0.0 : UiSpace.s6,
      };
    case 'bulleted_list':
    case 'numbered_list':
    case 'todo_list':
    case 'toggle':
      return -UiSpace.s1_5;
    default:
      return -UiSpace.s1;
  }
}

Node _cloneNodeWithFreshIds(Node source) {
  final clonedAttrs = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(source.attributes)) as Map<String, dynamic>,
  );
  return Node(
    type: source.type,
    attributes: clonedAttrs,
    children: source.children.map(_cloneNodeWithFreshIds),
  );
}

class _BlockDrag {
  const _BlockDrag(this.editor, this.node);
  final EditorState editor;
  final Node node;
}

/// This frame surrounds the full-width list item, outside its centered content
/// padding. Its handle occupies existing whitespace and never changes layout.
class PageBlockReorderFrame extends StatefulWidget {
  const PageBlockReorderFrame({
    super.key,
    required this.editor,
    required this.node,
    required this.contentLeft,
    required this.contentRight,
    required this.child,
  });
  final EditorState editor;
  final Node node;
  final double contentLeft;
  final double contentRight;
  final Widget child;

  @override
  State<PageBlockReorderFrame> createState() => _PageBlockReorderFrameState();
}

class _PageBlockReorderFrameState extends State<PageBlockReorderFrame> {
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;
  bool _after = false;

  bool _accepts(_BlockDrag data) =>
      identical(data.editor, widget.editor) &&
      !identical(data.node, widget.node) &&
      !widget.editor.isDisposed &&
      widget.editor.editable &&
      widget.editor.document.root.children.contains(data.node) &&
      widget.editor.document.root.children.contains(widget.node);

  bool _isAfter(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    return box.globalToLocal(global).dy >= box.size.height / 2;
  }

  Future<void> _move(Node source, Node target, {required bool after}) async {
    final editor = widget.editor;
    if (await movePageBlock(editor, source, target, after: after)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!editor.isDisposed && editor.editable) {
          editor.service.keyboardService?.enableShortcuts();
          editor.service.keyboardService?.enable();
        }
      });
    }
  }

  void _moveDirection({required bool down}) {
    if (!mounted || widget.editor.isDisposed || !widget.editor.editable) return;
    final nodes = widget.editor.document.root.children;
    final index = nodes.indexOf(widget.node);
    final target = index + (down ? 1 : -1);
    if (index < 0 || target < 0 || target >= nodes.length) return;
    unawaited(_move(widget.node, nodes[target], after: down));
  }

  Future<void> _menu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    final nodes = widget.editor.document.root.children;
    final index = nodes.indexOf(widget.node);
    if (index < 0 || !widget.editor.editable) return;
    await showBlockContextMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      editor: widget.editor,
      node: widget.node,
      onMoveDirection: (down) => _moveDirection(down: down),
    );
  }

  String get _label => switch (widget.node.type) {
    'code' => context.l10n.blockCode,
    'database' => context.l10n.blockDatabase,
    'callout' => context.l10n.blockCallout,
    'toggle' => context.l10n.blockToggle,
    'image' => context.l10n.blockImage,
    _ => context.l10n.blockText,
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final showHandle = _hovered || _focused || _dragging;
    final canReorder = widget.editor.document.root.children.length > 1;

    Widget buildHandleButton() => Builder(
      builder: (buttonContext) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (_) => unawaited(_menu(buttonContext)),
        child: IconButton(
          key: ValueKey('page_block_handle_${widget.node.id}'),
          tooltip: context.l10n.blockMoveHandle,
          mouseCursor: canReorder
              ? SystemMouseCursors.grab
              : SystemMouseCursors.click,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 26, height: 28),
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => unawaited(_menu(buttonContext)),
          icon: CustomPaint(
            size: const Size(14, 16),
            painter: _BlockGripPainter(skin.muted),
          ),
        ),
      ),
    );

    final handleButton = buildHandleButton();
    final handleWidget = canReorder
        ? Draggable<_BlockDrag>(
            data: _BlockDrag(widget.editor, widget.node),
            maxSimultaneousDrags: 1,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: () => setState(() => _dragging = true),
            onDragEnd: (_) {
              if (mounted) setState(() => _dragging = false);
            },
            feedback: Container(
              key: const Key('page_block_drag_preview'),
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(UiSpace.s10),
              decoration: ShapeDecoration(
                color: skin.card,
                shape: UiRadius.squircle(
                  UiRadius.control,
                  side: BorderSide(color: skin.hairlineBorder),
                ),
                shadows: skin.popoverShadows,
              ),
              child: Text(
                widget.node.delta?.toPlainText().trim().isNotEmpty == true
                    ? widget.node.delta!.toPlainText().trim()
                    : _label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: UiType.body,
                  color: skin.text,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            child: handleButton,
          )
        : handleButton;

    return DragTarget<_BlockDrag>(
      onWillAcceptWithDetails: (details) {
        _after = _isAfter(details.offset);
        return _accepts(details.data);
      },
      onMove: (details) {
        final after = _isAfter(details.offset);
        if (_after != after) setState(() => _after = after);
      },
      onAcceptWithDetails: (details) => unawaited(
        _move(details.data.node, widget.node, after: _isAfter(details.offset)),
      ),
      builder: (context, candidates, rejected) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(opacity: _dragging ? 0.4 : 1, child: widget.child),
            Positioned(
              left: (widget.contentLeft - 30).clamp(0, double.infinity),
              top:
                  widget.editor.editorStyle.padding.top +
                  blockHandleTopOffset(widget.node),
              width: 26,
              height: 28,
              child: Focus(
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: AnimatedOpacity(
                  curve: Motion.curve,
                  opacity: showHandle ? 1 : 0,
                  duration: Motion.of(context, Motion.micro),
                  child: handleWidget,
                ),
              ),
            ),
            if (candidates.isNotEmpty)
              Positioned(
                left: widget.contentLeft,
                right: widget.contentRight,
                top: _after ? null : 1,
                bottom: _after ? 1 : null,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const Key('page_block_drop_line'),
                    decoration: BoxDecoration(
                      color: skin.accentText,
                      borderRadius: BorderRadius.circular(UiRadius.hairline),
                    ),
                    child: const SizedBox(height: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlockGripPainter extends CustomPainter {
  const _BlockGripPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final x in [4.0, 10.0]) {
      for (final y in [3.0, 8.0, 13.0]) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlockGripPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Displays the block-level context menu next to [anchor].
Future<void> showBlockContextMenu(
  BuildContext context, {
  required Rect anchor,
  required EditorState editor,
  required Node node,
  VoidCallback? onPaste,
  void Function(bool down)? onMoveDirection,
}) {
  return showPopover(
    context,
    anchor: anchor,
    width: DesktopUx.menuWidth,
    builder: (_, close) => BlockContextMenuCard(
      editor: editor,
      node: node,
      onClose: close,
      onPaste: onPaste,
      onMoveDirection: onMoveDirection,
      asCard: false,
    ),
  );
}

/// Rich block-level context menu card matching Notion / Craft behavior.
/// Includes block transforms ("Turn into..."), reordering, duplication,
/// deletion, and clipboard actions.
class BlockContextMenuCard extends StatefulWidget {
  const BlockContextMenuCard({
    super.key,
    required this.editor,
    required this.node,
    required this.onClose,
    this.onPaste,
    this.onMoveDirection,
    this.width = DesktopUx.menuWidth,
    this.alignment = Alignment.topLeft,
    this.asCard = true,
  });

  final EditorState editor;
  final Node node;
  final VoidCallback onClose;
  final VoidCallback? onPaste;
  final void Function(bool down)? onMoveDirection;
  final double width;
  final Alignment alignment;
  final bool asCard;

  @override
  State<BlockContextMenuCard> createState() => _BlockContextMenuCardState();
}

class _BlockContextMenuCardState extends State<BlockContextMenuCard> {
  int _page = 0;

  bool get _isText => widget.node.type == ParagraphBlockKeys.type;
  bool get _isH1 =>
      widget.node.type == HeadingBlockKeys.type &&
      widget.node.attributes[HeadingBlockKeys.level] == 1;
  bool get _isH2 =>
      widget.node.type == HeadingBlockKeys.type &&
      widget.node.attributes[HeadingBlockKeys.level] == 2;
  bool get _isH3 =>
      widget.node.type == HeadingBlockKeys.type &&
      widget.node.attributes[HeadingBlockKeys.level] == 3;
  bool get _isBullet => widget.node.type == BulletedListBlockKeys.type;
  bool get _isNumbered => widget.node.type == NumberedListBlockKeys.type;
  bool get _isTodo => widget.node.type == TodoListBlockKeys.type;
  bool get _isQuote => widget.node.type == QuoteBlockKeys.type;
  bool get _isCode => widget.node.type == codeBlockType;
  bool get _isCallout => widget.node.type == calloutBlockType;
  bool get _isToggle => widget.node.type == toggleBlockType;

  void _restoreKeyboard() {
    final editor = widget.editor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!editor.isDisposed && editor.editable) {
        editor.service.keyboardService?.enableShortcuts();
        editor.service.keyboardService?.enable();
      }
    });
  }

  void _moveDirection({required bool down}) {
    widget.onClose();
    if (widget.onMoveDirection != null) {
      widget.onMoveDirection!(down);
      return;
    }
    if (widget.editor.isDisposed || !widget.editor.editable) return;
    final nodes = widget.editor.document.root.children;
    final index = nodes.indexOf(widget.node);
    final target = index + (down ? 1 : -1);
    if (index < 0 || target < 0 || target >= nodes.length) return;
    unawaited(
      movePageBlock(widget.editor, widget.node, nodes[target], after: down),
    );
    _restoreKeyboard();
  }

  Future<void> _duplicate() async {
    widget.onClose();
    await duplicatePageBlock(widget.editor, widget.node);
    _restoreKeyboard();
  }

  Future<void> _delete() async {
    widget.onClose();
    await deletePageBlock(widget.editor, widget.node);
    _restoreKeyboard();
  }

  Future<void> _insertParagraph({required bool after}) async {
    widget.onClose();
    await insertParagraphRelative(widget.editor, widget.node, after: after);
    _restoreKeyboard();
  }

  Future<void> _copyText() async {
    widget.onClose();
    final text = widget.node.delta?.toPlainText();
    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    _restoreKeyboard();
  }

  Future<void> _turnInto(
    String targetType, {
    Map<String, dynamic>? attributes,
  }) async {
    widget.onClose();
    await turnPageBlockInto(
      widget.editor,
      widget.node,
      targetType,
      attributes: attributes,
    );
    _restoreKeyboard();
  }

  void _handlePaste() {
    widget.onClose();
    if (widget.onPaste != null) {
      widget.onPaste!();
    } else {
      pasteCommand.handler(widget.editor);
    }
    _restoreKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodes = widget.editor.document.root.children;
    final index = nodes.indexOf(widget.node);
    final canMoveUp = index > 0;
    final canMoveDown = index >= 0 && index < nodes.length - 1;
    final canTurnInto = isConvertibleBlock(widget.node);
    final plainText = widget.node.delta?.toPlainText().trim();
    final hasText = plainText != null && plainText.isNotEmpty;

    final List<Widget> children;
    if (_page == 1) {
      children = [
        MenuRow(
          label: l10n.back,
          glyph: AppIcons.chevronLeft,
          onTap: () => setState(() => _page = 0),
        ),
        const MenuDivider(),
        MenuRow(
          label: l10n.turnIntoText,
          glyph: AppIcons.textformat,
          selected: _isText,
          onTap: () => unawaited(_turnInto(ParagraphBlockKeys.type)),
        ),
        MenuRow(
          label: l10n.turnIntoH1,
          glyph: AppIcons.textformatSize,
          selected: _isH1,
          onTap: () => unawaited(
            _turnInto(HeadingBlockKeys.type, attributes: {'level': 1}),
          ),
        ),
        MenuRow(
          label: l10n.turnIntoH2,
          glyph: AppIcons.textformatSize,
          selected: _isH2,
          onTap: () => unawaited(
            _turnInto(HeadingBlockKeys.type, attributes: {'level': 2}),
          ),
        ),
        MenuRow(
          label: l10n.turnIntoH3,
          glyph: AppIcons.textformatSize,
          selected: _isH3,
          onTap: () => unawaited(
            _turnInto(HeadingBlockKeys.type, attributes: {'level': 3}),
          ),
        ),
        MenuRow(
          label: l10n.turnIntoBulletList,
          glyph: AppIcons.listBullet,
          selected: _isBullet,
          onTap: () => unawaited(_turnInto(BulletedListBlockKeys.type)),
        ),
        MenuRow(
          label: l10n.turnIntoNumberedList,
          glyph: AppIcons.number,
          selected: _isNumbered,
          onTap: () => unawaited(_turnInto(NumberedListBlockKeys.type)),
        ),
        MenuRow(
          label: l10n.turnIntoTodoList,
          glyph: AppIcons.checkmarkSquare,
          selected: _isTodo,
          onTap: () => unawaited(_turnInto(TodoListBlockKeys.type)),
        ),
        MenuRow(
          label: l10n.turnIntoQuote,
          glyph: AppIcons.textAlignleft,
          selected: _isQuote,
          onTap: () => unawaited(_turnInto(QuoteBlockKeys.type)),
        ),
        MenuRow(
          label: l10n.turnIntoCode,
          glyph: AppIcons.chevronLeftSlashChevronRight,
          selected: _isCode,
          onTap: () => unawaited(_turnInto(codeBlockType)),
        ),
        MenuRow(
          label: l10n.turnIntoCallout,
          glyph: AppIcons.exclamationmarkCircle,
          selected: _isCallout,
          onTap: () => unawaited(_turnInto(calloutBlockType)),
        ),
        MenuRow(
          label: l10n.turnIntoToggle,
          glyph: AppIcons.chevronRight,
          selected: _isToggle,
          onTap: () => unawaited(_turnInto(toggleBlockType)),
        ),
      ];
    } else {
      children = [
        if (widget.editor.editable)
          MenuRow(
            label: l10n.paste,
            glyph: AppIcons.docOnClipboard,
            shortcut: menuShortcut('V'),
            onTap: _handlePaste,
          ),
        if (canTurnInto && widget.editor.editable)
          MenuRow(
            label: l10n.turnInto,
            glyph: AppIcons.arrowRightArrowLeft,
            trailing: const Icon(AppIcons.chevronRight, size: UiSpace.s14),
            onTap: () => setState(() => _page = 1),
          ),
        if (widget.editor.editable) const MenuDivider(),
        if (widget.editor.editable) ...[
          MenuRow(
            label: l10n.blockInsertAbove,
            glyph: AppIcons.arrowUp,
            onTap: () => unawaited(_insertParagraph(after: false)),
          ),
          MenuRow(
            label: l10n.blockInsertBelow,
            glyph: AppIcons.arrowDown,
            onTap: () => unawaited(_insertParagraph(after: true)),
          ),
          if (canMoveUp)
            MenuRow(
              label: l10n.blockMoveUp,
              glyph: AppIcons.chevronUp,
              onTap: () => _moveDirection(down: false),
            ),
          if (canMoveDown)
            MenuRow(
              label: l10n.blockMoveDown,
              glyph: AppIcons.chevronDown,
              onTap: () => _moveDirection(down: true),
            ),
          const MenuDivider(),
        ],
        if (hasText)
          MenuRow(
            label: l10n.copyBlockText,
            glyph: AppIcons.docOnDoc,
            onTap: () => unawaited(_copyText()),
          ),
        if (widget.editor.editable)
          MenuRow(
            label: l10n.duplicate,
            glyph: AppIcons.docOnDoc,
            shortcut: menuShortcut('D'),
            onTap: () => unawaited(_duplicate()),
          ),
        if (widget.editor.editable) ...[
          const MenuDivider(),
          MenuRow(
            label: l10n.delete,
            glyph: AppIcons.trash,
            destructive: true,
            shortcut: '⌫',
            onTap: () => unawaited(_delete()),
          ),
        ],
      ];
    }

    if (!widget.asCard) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return MenuCard(
      alignment: widget.alignment,
      width: widget.width,
      onClosed: widget.onClose,
      children: children,
    );
  }
}

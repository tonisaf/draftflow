import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/popover.dart';
import '../../theme.dart';

/// Modern desktop floating link popover (Apple HIG / Linear style)
/// for viewing, editing, opening, copying, and removing links in DraftFlow document editor.
class EditorLinkPopover extends StatefulWidget {
  final String? initialUrl;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onOpenLink;
  final ValueChanged<String> onCopyLink;
  final VoidCallback onRemoveLink;

  const EditorLinkPopover({
    super.key,
    this.initialUrl,
    required this.onClose,
    required this.onSubmitted,
    required this.onOpenLink,
    required this.onCopyLink,
    required this.onRemoveLink,
  });

  @override
  State<EditorLinkPopover> createState() => _EditorLinkPopoverState();
}

class _EditorLinkPopoverState extends State<EditorLinkPopover> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '');
    _hasText = _controller.text.isNotEmpty;

    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText && mounted) {
        setState(() => _hasText = hasText);
      }
    });

    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });

    if (_controller.text.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmitted(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final hasExistingLink =
        widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Localized & simplified compact header
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            hasExistingLink ? 'Ссылка' : 'Добавить ссылку',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: skin.hint,
              letterSpacing: -0.1,
            ),
          ),
        ),

        // 2. Desktop density URL TextField
        Container(
          height: 35.0,
          decoration: BoxDecoration(
            color: _isFocused
                ? (isDark ? const Color(0xFF282A2E) : Colors.white)
                : (isDark ? const Color(0xFF1E2024) : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _isFocused
                  ? (isDark ? Palette.accent : const Color(0xFF1A73E8))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
              width: _isFocused ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('editor_link_input'),
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w400,
                    color: skin.text,
                  ),
                  cursorColor: Palette.accent,
                  cursorWidth: 1.5,
                  cursorHeight: 16.0,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSubmit(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'https://...',
                    hintStyle: TextStyle(
                      fontSize: 13.0,
                      color: skin.hint,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (_hasText) ...[
                _ClearButton(
                  onTap: () {
                    _controller.clear();
                    _focusNode.requestFocus();
                  },
                ),
                if (!hasExistingLink) ...[
                  const SizedBox(width: 4.0),
                  _SubmitButton(onTap: _handleSubmit),
                ],
              ],
            ],
          ),
        ),

        // 3. Menu items, icons & destructive separation (when a link exists)
        if (hasExistingLink) ...[
          const SizedBox(height: 6.0),
          _PopoverRow(
            key: const Key('editor_link_open_action'),
            label: 'Открыть ссылку',
            icon: CupertinoIcons.arrow_up_right,
            onTap: () {
              final url = _controller.text.trim().isNotEmpty
                  ? _controller.text.trim()
                  : (widget.initialUrl ?? '');
              widget.onOpenLink(url);
            },
          ),
          _PopoverRow(
            key: const Key('editor_link_copy_action'),
            label: _copied ? 'Скопировано' : 'Копировать ссылку',
            icon: _copied
                ? CupertinoIcons.checkmark_alt
                : CupertinoIcons.doc_on_doc,
            iconColor: _copied ? const Color(0xFF16A34A) : null,
            textColor: _copied ? const Color(0xFF16A34A) : null,
            onTap: () {
              final url = _controller.text.trim().isNotEmpty
                  ? _controller.text.trim()
                  : (widget.initialUrl ?? '');
              widget.onCopyLink(url);
              setState(() => _copied = true);
              _copyTimer?.cancel();
              _copyTimer = Timer(const Duration(milliseconds: 900), () {
                if (mounted) {
                  widget.onClose();
                }
              });
            },
          ),
          Container(
            height: 1.0,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _PopoverRow(
            key: const Key('editor_link_remove_action'),
            label: 'Удалить ссылку',
            icon: CupertinoIcons.trash,
            destructive: true,
            onTap: widget.onRemoveLink,
          ),
        ],
      ],
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: Icon(
            CupertinoIcons.clear_circled_solid,
            size: 16.0,
            color: _hover
                ? (skin.isDark ? skin.text : const Color(0xFF4B5563))
                : (skin.isDark ? skin.muted : const Color(0xFF9CA3AF)),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SubmitButton({required this.onTap});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.skin.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            width: 22.0,
            height: 22.0,
            decoration: BoxDecoration(
              color: _hover
                  ? (isDark
                      ? Palette.accent.withValues(alpha: 0.25)
                      : const Color(0x1A1A73E8))
                  : (isDark
                      ? Palette.accent.withValues(alpha: 0.15)
                      : const Color(0x0F1A73E8)),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.arrow_right,
                size: 12.0,
                color: isDark ? Palette.accent : const Color(0xFF1A73E8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  final Color? iconColor;
  final Color? textColor;

  const _PopoverRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.iconColor,
    this.textColor,
  });

  @override
  State<_PopoverRow> createState() => _PopoverRowState();
}

class _PopoverRowState extends State<_PopoverRow> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    Color bg;
    Color fg;
    Color iconFg;

    if (widget.destructive) {
      if (_hover) {
        bg = const Color(0x14EF4444);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        iconFg = fg;
      } else {
        bg = Colors.transparent;
        fg = isDark ? const Color(0xFFF87171) : skin.destructive;
        iconFg = isDark ? const Color(0xFFF87171) : skin.destructive;
      }
    } else {
      if (_hover) {
        bg = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.045);
        fg = widget.textColor ??
            (isDark ? Colors.white : const Color(0xFF111827));
        iconFg = widget.iconColor ??
            (isDark ? skin.text : const Color(0xFF4B5563));
      } else {
        bg = Colors.transparent;
        fg = widget.textColor ??
            (isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827));
        iconFg = widget.iconColor ??
            (isDark ? skin.muted : const Color(0xFF6B7280));
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            height: 33.0,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 15.0,
                  color: iconFg,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// Computes the anchor Rect for the popover based on editor selection
Rect calculateEditorSelectionAnchor(EditorState editorState) {
  try {
    final rects = editorState.selectionRects();
    final renderBox = editorState.renderBox;
    if (renderBox != null && renderBox.hasSize && rects.isNotEmpty) {
      final r = rects.first;
      final topLeft = renderBox.localToGlobal(r.topLeft);
      final bottomRight = renderBox.localToGlobal(r.bottomRight);
      return Rect.fromPoints(topLeft, bottomRight);
    }
  } catch (_) {}

  try {
    final renderBox = editorState.renderBox;
    if (renderBox != null && renderBox.hasSize) {
      final center = renderBox.localToGlobal(
        renderBox.size.center(Offset.zero),
      );
      return Rect.fromCenter(center: center, width: 20, height: 20);
    }
  } catch (_) {}

  return const Rect.fromLTWH(200, 200, 20, 20);
}

/// Retrieves existing link address from selection, checking both delta attribute
/// and node attributes around the selection offset as fallback.
String? getLinkFromSelection(EditorState editorState, Selection selection) {
  try {
    final val = editorState.getDeltaAttributeValueInSelection(
      AppFlowyRichTextKeys.href,
      selection,
    );
    if (val is String && val.isNotEmpty) return val;
  } catch (_) {}

  try {
    final node = editorState.getNodeAtPath(selection.start.path);
    final delta = node?.delta;
    if (delta != null) {
      final offset = selection.start.offset;
      int cur = 0;
      for (final op in delta) {
        final len = op.length;
        if (offset >= cur && offset <= cur + len) {
          final href = op.attributes?[AppFlowyRichTextKeys.href];
          if (href is String && href.isNotEmpty) return href;
        }
        cur += len;
      }
    }
  } catch (_) {}
  return null;
}

/// If selection is collapsed but the caret is inside a link, expands the selection
/// to encompass the full link text range.
Selection resolveLinkSelection(EditorState editorState, Selection selection) {
  if (!selection.isCollapsed) return selection;
  try {
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return selection;
    final delta = node.delta;
    if (delta != null) {
      final offset = selection.start.offset;
      int cur = 0;
      for (final op in delta) {
        final len = op.length;
        if (offset >= cur && offset <= cur + len) {
          final href = op.attributes?[AppFlowyRichTextKeys.href];
          if (href != null) {
            return Selection.single(
              path: node.path,
              startOffset: cur,
              endOffset: cur + len,
            );
          }
        }
        cur += len;
      }
    }
  } catch (_) {}
  return selection;
}

/// Formats raw text into a valid link (prepending https:// if scheme is missing).
String formatLinkUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('page://') ||
      trimmed.startsWith('mailto:')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

/// Opens the modern desktop link popover next to the current selection.
Future<void> showModernLinkPopover(
  BuildContext context,
  EditorState editorState,
  Selection selection,
  bool isHref, {
  String? initialUrl,
}) async {
  final resolvedSelection = resolveLinkSelection(editorState, selection);
  String? linkText = initialUrl;
  if (linkText == null || linkText.isEmpty) {
    linkText = getLinkFromSelection(editorState, resolvedSelection);
  }

  final anchor = calculateEditorSelectionAnchor(editorState);

  keepEditorFocusNotifier.increase();
  try {
    await showPopover(
      context,
      anchor: anchor,
      width: 290.0,
      menuPadding: const EdgeInsets.all(8.0),
      builder: (popoverContext, close) {
        return EditorLinkPopover(
          initialUrl: linkText,
          onClose: close,
          onSubmitted: (url) async {
            close();
            final formatted = formatLinkUrl(url);
            if (formatted.isNotEmpty) {
              await editorState.formatDelta(resolvedSelection, {
                AppFlowyRichTextKeys.href: formatted,
              });
            }
          },
          onOpenLink: (url) async {
            close();
            final formatted = formatLinkUrl(url);
            if (formatted.isNotEmpty) {
              await editorLaunchUrl(formatted);
            }
          },
          onCopyLink: (url) async {
            final formatted = formatLinkUrl(url);
            if (formatted.isNotEmpty) {
              await Clipboard.setData(ClipboardData(text: formatted));
            }
          },
          onRemoveLink: () async {
            close();
            final node = editorState.getNodeAtPath(resolvedSelection.end.path);
            if (node != null) {
              final transaction = editorState.transaction
                ..formatText(
                  node,
                  resolvedSelection.normalized.startIndex,
                  resolvedSelection.length,
                  {AppFlowyRichTextKeys.href: null},
                );
              await editorState.apply(transaction);
            } else {
              await editorState.formatDelta(resolvedSelection, {
                AppFlowyRichTextKeys.href: null,
              });
            }
          },
        );
      },
    );
  } finally {
    keepEditorFocusNotifier.decrease();
  }
}

/// Cmd+K / Ctrl+K shortcut event that summons the modern link popover.
final CommandShortcutEvent modernLinkMenuCommand = CommandShortcutEvent(
  key: 'modern link menu',
  getDescription: () => 'Показать меню ссылки',
  command: 'ctrl+k',
  macOSCommand: 'cmd+k',
  handler: (editorState) {
    final selection = editorState.selection;
    if (selection == null) {
      return KeyEventResult.ignored;
    }
    final resolvedSelection = resolveLinkSelection(editorState, selection);
    final context = editorState
        .getNodeAtPath(resolvedSelection.end.path)
        ?.key
        .currentContext;
    if (context == null) {
      return KeyEventResult.ignored;
    }
    final nodes = editorState.getNodesInSelection(resolvedSelection);
    final isHref = nodes.any(
      (node) =>
          node.delta?.any(
            (op) => op.attributes?[AppFlowyRichTextKeys.href] != null,
          ) ??
          false,
    );

    showModernLinkPopover(context, editorState, resolvedSelection, isHref);
    return KeyEventResult.handled;
  },
);

import 'expanded_cell_editor.dart';
import 'database_grid_navigation.dart';
import '../../../common/app_icons.dart';

import 'package:appflowy_editor/appflowy_editor.dart' show safeLaunchUrl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/theme.dart';

class UrlCellInput extends StatefulWidget {
  final DatabaseCellEditor? editor;
  final ValueChanged<bool>? onEditingChanged;
  final String initialValue;
  final bool isCellHovered;
  final ValueChanged<String> onChanged;
  final void Function(String url)? onOpenUrl;

  const UrlCellInput({
    this.editor,
    super.key,
    this.onEditingChanged,
    required this.initialValue,
    this.isCellHovered = false,
    required this.onChanged,
    this.onOpenUrl,
  });

  static String normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  static String formatUrlForDisplay(String input) {
    var display = input.trim();
    if (display.isEmpty) return '';
    if (display.startsWith('https://')) {
      display = display.substring(8);
    } else if (display.startsWith('http://')) {
      display = display.substring(7);
    } else if (display.startsWith('mailto:')) {
      display = display.substring(7);
    }
    return display;
  }

  static bool isValidUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:')) {
      return true;
    }
    return trimmed.contains('.') && !trimmed.contains(' ');
  }

  @override
  State<UrlCellInput> createState() => _UrlCellInputState();
}

class _UrlCellInputState extends State<UrlCellInput> {
  late final TextEditingController _controller;
  VoidCallback? _closeEditor;
  String _lastSubmittedValue = '';
  bool _isEditing = false;
  bool _isHovered = false;
  bool _isCopied = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSubmittedValue = widget.initialValue;
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text != _lastSubmittedValue) {
      _lastSubmittedValue = text;
      widget.onChanged(text);
    }
  }

  @override
  void didUpdateWidget(UrlCellInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_isEditing) {
      _controller.text = widget.initialValue;
      _lastSubmittedValue = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _closeEditor?.call();
    _commit();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyUrl(String url) async {
    final target = UrlCellInput.normalizeUrl(url);
    await Clipboard.setData(ClipboardData(text: target));
    if (mounted) {
      setState(() => _isCopied = true);
      Future.delayed(Motion.copiedFeedback, () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  Future<void> _startEditing() async {
    if (_isEditing) return;
    setState(() => _isEditing = true);
    widget.onEditingChanged?.call(true);
    await showExpandedCellEditor(
      context,
      _controller.text,
      anchorContext: widget.editor?.anchorContext?.call(),
      minWidth: UiLayout.cellUrlEditorMinWidth,
      multiline: false,
      keyboardType: TextInputType.url,
      onCloseReady: (close) => _closeEditor = close,
      onSave: (value) {
        _controller.text = value;
        _commit();
      },
    );
    if (!mounted) return;
    _closeEditor = null;
    setState(() => _isEditing = false);
    widget.onEditingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    widget.editor?.open = _startEditing;
    widget.editor?.cancel = () {
      _controller.text = widget.initialValue;
    };
    final skin = context.skin;
    final currentUrl = _controller.text.trim();

    if (currentUrl.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _startEditing();
        },
        child: Container(
          alignment: Alignment.centerLeft,
          child: widget.isCellHovered
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.link, size: UiSpace.s14, color: skin.hint),
                    const SizedBox(width: UiSpace.s4),
                    Text(
                      context.l10n.urlAdd,
                      style: TextStyle(fontSize: UiType.body, color: skin.hint),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    final isLikely = UrlCellInput.isValidUrl(currentUrl);
    final targetUrl = UrlCellInput.normalizeUrl(currentUrl);
    final displayUrl = UrlCellInput.formatUrlForDisplay(currentUrl);
    final showActions = _isHovered || widget.isCellHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Tooltip(
              message: context.l10n.urlClickToOpenTooltip(targetUrl),
              waitDuration: Motion.tooltipDelay,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final now = DateTime.now();
                  if (_lastTapTime != null &&
                      now.difference(_lastTapTime!) < Motion.doubleTapWindow) {
                    _startEditing();
                  } else {
                    _lastTapTime = now;
                    if (widget.onOpenUrl != null) {
                      widget.onOpenUrl!(targetUrl);
                    } else {
                      safeLaunchUrl(targetUrl);
                    }
                  }
                },
                child: Text(
                  displayUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UiType.body,
                    color: skin.text,
                    decoration: TextDecoration.underline,
                    decorationColor: skin.hint,
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: showActions,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: UiSpace.s4),
                Tooltip(
                  message: context.l10n.urlEdit,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(UiRadius.scrollbar),
                    onTap: () {
                      _startEditing();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(UiSpace.s2),
                      child: Icon(
                        AppIcons.pencil,
                        size: UiSpace.s14,
                        color: skin.muted,
                      ),
                    ),
                  ),
                ),
                if (isLikely) ...[
                  Tooltip(
                    message: _isCopied
                        ? context.l10n.urlCopied
                        : context.l10n.urlCopyLink,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(UiRadius.scrollbar),
                      onTap: () => _copyUrl(currentUrl),
                      child: Padding(
                        padding: const EdgeInsets.all(UiSpace.s2),
                        child: Icon(
                          _isCopied ? AppIcons.checkMark : AppIcons.docOnDoc,
                          size: UiSpace.s14,
                          color: _isCopied ? Palette.success : skin.muted,
                        ),
                      ),
                    ),
                  ),
                ],
                Tooltip(
                  message: context.l10n.urlClear,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(UiRadius.scrollbar),
                    onTap: () {
                      _controller.clear();
                      _commit();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(UiSpace.s2),
                      child: Icon(
                        AppIcons.xmark,
                        size: UiSpace.s14,
                        color: skin.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

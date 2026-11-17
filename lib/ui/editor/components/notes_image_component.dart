import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/locale_controller.dart';
import '../../../platform/desktop_services.dart';
import '../../common/app_icons.dart';
import '../../common/quiet_button.dart';
import '../../theme.dart';
import 'html_paste.dart';
import 'image_paste.dart';
import 'page_block_reorder.dart';

/// Builds a Neo-HIG image block with squircle corners, hairline framing,
/// edge resize handles, and a hover toolbar for alignment, copy, and delete.
BlockComponentBuilder buildNotesImageBlockComponentBuilder(
  BuildContext context,
) {
  return _NotesImageBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      padding: (_) => const EdgeInsets.symmetric(vertical: UiSpace.s8),
    ),
  );
}

class _NotesImageBlockComponentBuilder extends BlockComponentBuilder {
  _NotesImageBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NotesImageBlockComponentWidget(
      key: node.key,
      node: node,
      showActions: showActions(node),
      configuration: configuration,
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class NotesImageBlockComponentWidget extends BlockComponentStatefulWidget {
  const NotesImageBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<NotesImageBlockComponentWidget> createState() =>
      _NotesImageBlockComponentWidgetState();
}

class _NotesImageBlockComponentWidgetState
    extends State<NotesImageBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _frameKey = GlobalKey();
  bool _hovered = false;

  late final EditorState _editorState = Provider.of<EditorState>(
    context,
    listen: false,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  Alignment _alignmentFor(String? value) {
    return switch (value) {
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };
  }

  Future<void> _setWidth(double width) async {
    if (_editorState.isDisposed || !_editorState.editable) return;
    final transaction = _editorState.transaction
      ..updateNode(widget.node, {ImageBlockKeys.width: width});
    await _editorState.apply(transaction, withUpdateSelection: false);
  }

  bool _isNodeSelected(Selection? selection) {
    if (selection == null) return false;
    return widget.node.path.inSelection(selection.normalized);
  }

  @override
  Widget build(BuildContext context) {
    final attributes = widget.node.attributes;
    final src = (attributes[ImageBlockKeys.url] as String?) ?? '';
    final align = attributes[ImageBlockKeys.align] as String?;
    final width = (attributes[ImageBlockKeys.width] as num?)?.toDouble();
    final height = (attributes[ImageBlockKeys.height] as num?)?.toDouble();

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Align(
          alignment: _alignmentFor(align),
          child: ValueListenableBuilder<Selection?>(
            valueListenable: _editorState.selectionNotifier,
            builder: (context, selection, _) => _PolishedImageFrame(
              frameKey: _frameKey,
              src: src,
              storedWidth: width,
              storedHeight: height,
              maxWidth: maxWidth,
              align: align ?? 'center',
              hovered: _hovered,
              selected: _isNodeSelected(selection),
              editable: _editorState.editable,
              onCommitWidth: _setWidth,
            ),
          ),
        );
      },
    );

    content = Padding(
      key: _imageKey,
      padding: padding,
      child: content,
    );

    content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: UiSpace.s44),
      child: content,
    );

    // Selection visual is painted strictly around the rounded image frame
    // inside `_PolishedImageFrame`, avoiding off-center sharp overlay rects.
    content = BlockSelectionContainer(
      node: widget.node,
      delegate: this,
      listenable: _editorState.selectionNotifier,
      remoteSelection: _editorState.remoteSelections,
      blockColor: Palette.transparent,
      cursorColor: Palette.transparent,
      supportTypes: const [],
      child: content,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      content = BlockComponentActionWrapper(
        node: widget.node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: content,
      );
    }

    return MouseRegion(
      opaque: false,
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Stack(
        children: [
          content,
          if (_hovered)
            _ImageBlockHoverToolbar(
              node: widget.node,
              editorState: _editorState,
            ),
        ],
      ),
    );
  }

  Rect? _frameRectRelativeToSelf() {
    final box = _renderBox;
    final frameBox = _frameKey.currentContext?.findRenderObject();
    if (box == null || frameBox is! RenderBox || !frameBox.hasSize) {
      return null;
    }
    return frameBox.localToGlobal(Offset.zero, ancestor: box) & frameBox.size;
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final frameRect = _frameRectRelativeToSelf();
    if (frameRect != null) return frameRect;
    final imageBox = _imageKey.currentContext?.findRenderObject();
    if (imageBox is RenderBox) {
      return Offset.zero & imageBox.size;
    }
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) => _frameRectRelativeToSelf();

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final frameRect = _frameRectRelativeToSelf();
    if (frameRect != null) return [frameRect];
    final box = _renderBox;
    if (box == null) return [];
    return [Offset.zero & box.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
    path: widget.node.path,
    startOffset: 0,
    endOffset: 1,
  );

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);
}

class _PolishedImageFrame extends StatefulWidget {
  const _PolishedImageFrame({
    required this.frameKey,
    required this.src,
    required this.storedWidth,
    required this.storedHeight,
    required this.maxWidth,
    required this.align,
    required this.hovered,
    required this.selected,
    required this.editable,
    required this.onCommitWidth,
  });

  final GlobalKey frameKey;
  final String src;
  final double? storedWidth;
  final double? storedHeight;
  final double maxWidth;
  final String align;
  final bool hovered;
  final bool selected;
  final bool editable;
  final ValueChanged<double> onCommitWidth;

  @override
  State<_PolishedImageFrame> createState() => _PolishedImageFrameState();
}

class _PolishedImageFrameState extends State<_PolishedImageFrame> {
  static const double _minWidth = 48.0;

  double? _dragWidth;
  String? _cachedSrc;
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _syncDecodedBytes();
  }

  @override
  void didUpdateWidget(covariant _PolishedImageFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _syncDecodedBytes();
    }
    if (oldWidget.storedWidth != widget.storedWidth) {
      _dragWidth = null;
    }
  }

  void _syncDecodedBytes() {
    if (_cachedSrc == widget.src) return;
    _cachedSrc = widget.src;
    _cachedBytes = _decodeBase64Source(widget.src);
  }

  static Uint8List? _decodeBase64Source(String src) {
    final trimmed = src.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('file://')) {
      return null;
    }
    final dataUriPayload = stripDataImageUriBase64(trimmed);
    if (dataUriPayload != null) {
      return base64Decode(dataUriPayload);
    }
    // JPEG base64 payloads always start with `/9j/`; only skip base64 when the
    // string actually refers to a local POSIX file path.
    if (trimmed.startsWith('/') &&
        !trimmed.startsWith('/9j/') &&
        trimmed.length < 1024 &&
        File(trimmed).existsSync()) {
      return null;
    }
    try {
      return base64Decode(trimmed.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException {
      return null;
    }
  }

  void _onDragStart() {
    final box = widget.frameKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _dragWidth = widget.storedWidth ?? box?.size.width ?? widget.maxWidth;
    });
  }

  void _onDragDelta(double delta, {required bool isLeftEdge}) {
    final current = _dragWidth;
    if (current == null) return;
    final signed = isLeftEdge ? -delta : delta;
    final factor = widget.align == 'center' ? 2.0 : 1.0;
    final upper = math.max(_minWidth, widget.maxWidth);
    setState(() {
      _dragWidth = (current + signed * factor).clamp(_minWidth, upper);
    });
  }

  void _onDragEnd() {
    final target = _dragWidth;
    if (target == null) return;
    widget.onCommitWidth(target.roundToDouble());
  }

  Widget _buildImageContent(BuildContext context, double? effectiveWidth) {
    final src = widget.src.trim();
    final fit = effectiveWidth != null ? BoxFit.fitWidth : BoxFit.contain;

    Widget fallback() => _BrokenImagePlaceholder(width: effectiveWidth);

    if (_cachedBytes != null) {
      return Image.memory(
        _cachedBytes!,
        width: effectiveWidth,
        height: widget.storedHeight,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: effectiveWidth,
        height: widget.storedHeight,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    if (src.startsWith('file://') || src.startsWith('/')) {
      final path = src.startsWith('file://')
          ? Uri.parse(src).toFilePath()
          : src;
      return Image.file(
        File(path),
        width: effectiveWidth,
        height: widget.storedHeight,
        fit: fit,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return fallback();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final upper = math.max(_minWidth, widget.maxWidth);
    final rawWidth = _dragWidth ?? widget.storedWidth;
    final effectiveWidth = rawWidth?.clamp(_minWidth, upper);
    final shape = UiRadius.squircle(UiRadius.badge);

    final containerDecor = ShapeDecoration(
      color: widget.selected
          ? Palette.accent.withValues(alpha: 0.12)
          : Palette.transparent,
      shape: UiRadius.squircle(
        UiRadius.badge,
        side: widget.selected
            ? const BorderSide(color: Palette.accent, width: UiSpace.s2)
            : BorderSide(color: skin.hairlineBorder),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            key: widget.frameKey,
            foregroundDecoration: containerDecor,
            child: ClipPath.shape(
              shape: shape,
              child: _buildImageContent(context, effectiveWidth),
            ),
          ),
          if (widget.hovered && widget.editable) ...[
            Positioned(
              left: UiSpace.s6,
              child: _ResizePillHandle(
                onDragStart: _onDragStart,
                onDragUpdate: (d) => _onDragDelta(d, isLeftEdge: true),
                onDragEnd: _onDragEnd,
              ),
            ),
            Positioned(
              right: UiSpace.s6,
              child: _ResizePillHandle(
                onDragStart: _onDragStart,
                onDragUpdate: (d) => _onDragDelta(d, isLeftEdge: false),
                onDragEnd: _onDragEnd,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResizePillHandle extends StatelessWidget {
  const _ResizePillHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpace.s4,
            vertical: UiSpace.s8,
          ),
          child: Container(
            width: UiSpace.s5,
            height: UiSpace.s32,
            decoration: ShapeDecoration(
              color: skin.glassSurface,
              shape: UiRadius.squircle(
                UiRadius.pill,
                side: BorderSide(color: skin.hairlineBorder),
              ),
              shadows: skin.cardShadows,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrokenImagePlaceholder extends StatelessWidget {
  const _BrokenImagePlaceholder({this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: width ?? UiSpace.s64 * 3,
      height: UiSpace.s60,
      color: skin.sidebar,
      alignment: Alignment.center,
      child: Icon(
        AppIcons.photo,
        size: UiSpace.s22,
        color: skin.muted,
      ),
    );
  }
}

class _ImageBlockHoverToolbar extends StatefulWidget {
  const _ImageBlockHoverToolbar({
    required this.node,
    required this.editorState,
  });

  final Node node;
  final EditorState editorState;

  @override
  State<_ImageBlockHoverToolbar> createState() =>
      _ImageBlockHoverToolbarState();
}

class _ImageBlockHoverToolbarState extends State<_ImageBlockHoverToolbar> {
  bool _copied = false;

  Future<void> _setAlign(String align) async {
    final editor = widget.editorState;
    if (editor.isDisposed || !editor.editable) return;
    final transaction = editor.transaction
      ..updateNode(widget.node, {ImageBlockKeys.align: align});
    await editor.apply(transaction, withUpdateSelection: false);
  }

  Future<void> _copyImage() async {
    final html = const HTMLImageDataUriParser().transformNodeToHTMLString(
      widget.node,
      encodeParsers: const [HTMLImageDataUriParser()],
    );
    await AppFlowyClipboard.setData(html: html.isEmpty ? null : html);
    await writeClipboardData(html: html.isEmpty ? null : html);
    if (!mounted) return;
    setState(() => _copied = true);
    Timer(Motion.copiedFeedback, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _deleteImage() async {
    await deletePageBlock(widget.editorState, widget.node);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final currentAlign =
        (widget.node.attributes[ImageBlockKeys.align] as String?) ?? 'center';

    return Positioned(
      top: UiSpace.s6,
      right: UiSpace.s8,
      child: DecoratedBox(
        key: ValueKey('image_toolbar_${widget.node.id}'),
        decoration: ShapeDecoration(
          color: skin.glassSurface,
          shape: UiRadius.squircle(
            UiRadius.control,
            side: BorderSide(color: skin.hairlineBorder),
          ),
          shadows: skin.popoverShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(UiSpace.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarAction(
                icon: AppIcons.textAlignleft,
                label: 'Left',
                selected: currentAlign == 'left',
                onTap: () => unawaited(_setAlign('left')),
              ),
              _ToolbarAction(
                icon: AppIcons.textAligncenter,
                label: 'Center',
                selected: currentAlign == 'center',
                onTap: () => unawaited(_setAlign('center')),
              ),
              _ToolbarAction(
                icon: AppIcons.textAlignright,
                label: 'Right',
                selected: currentAlign == 'right',
                onTap: () => unawaited(_setAlign('right')),
              ),
              Container(
                width: UiSpace.s1,
                height: UiSpace.s14,
                margin: const EdgeInsets.symmetric(horizontal: UiSpace.s3),
                color: skin.hairlineBorder,
              ),
              _ToolbarAction(
                icon: _copied ? AppIcons.checkMark : AppIcons.docOnDoc,
                label: l10n.copy,
                selected: _copied,
                onTap: () => unawaited(_copyImage()),
              ),
              _ToolbarAction(
                icon: AppIcons.trash,
                label: l10n.delete,
                destructive: true,
                onTap: () => unawaited(_deleteImage()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      tooltip: label,
      selected: selected,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) {
        final foreground = destructive
            ? skin.destructive
            : (selected ? skin.text : (hover ? skin.text : skin.muted));
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: selected
                ? skin.sidebarSelected
                : (hover || focus ? skin.hover : Palette.transparent),
            shape: UiRadius.squircle(
              UiRadius.small,
              side: focus
                  ? BorderSide(color: skin.outline)
                  : BorderSide.none,
            ),
          ),
          child: SizedBox(
            width: UiSpace.s26,
            height: UiSpace.s24,
            child: Center(
              child: Icon(icon, size: UiSpace.s14, color: foreground),
            ),
          ),
        );
      },
    );
  }
}

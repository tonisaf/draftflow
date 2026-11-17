import '../../common/menu.dart';
import '../../common/popover.dart';

import '../../common/app_icons.dart';

import 'dart:ui' as ui;
import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import 'code_highlighter.dart';

const String codeBlockType = 'code';

/// Supported languages with user-friendly display labels
const List<(String id, String label)> supportedCodeLanguages = [
  ('dart', 'Dart'),
  ('javascript', 'JavaScript'),
  ('typescript', 'TypeScript'),
  ('python', 'Python'),
  ('json', 'JSON'),
  ('sql', 'SQL'),
  ('bash', 'Bash / Shell'),
  ('html', 'HTML'),
  ('css', 'CSS'),
  ('rust', 'Rust'),
  ('go', 'Go'),
  ('yaml', 'YAML'),
  ('markdown', 'Markdown'),
  ('plaintext', 'Plain Text'),
];

Node codeBlockNode({
  String language = 'dart',
  bool collapsed = false,
  String? title,
  Delta? delta,
}) => Node(
  type: codeBlockType,
  attributes: {
    'delta': (delta ?? Delta()).toJson(),
    'language': language,
    'collapsed': collapsed,
    if (title != null && title.isNotEmpty) 'title': title,
  },
);

class CodeBlockComponentBuilder extends BlockComponentBuilder {
  CodeBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CodeBlockComponentWidget(
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
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class CodeBlockComponentWidget extends BlockComponentStatefulWidget {
  const CodeBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CodeBlockComponentWidget> createState() =>
      _CodeBlockComponentWidgetState();
}

class _CodeBlockComponentWidgetState extends State<CodeBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin,
        TickerProviderStateMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: codeBlockType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  String get _nodeTitle {
    final title = node.attributes['title'];
    return title is String ? title : '';
  }

  bool _isCopied = false;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocus;
  bool _moreOpen = false;
  bool _isHovered = false;

  late final AnimationController _foldController;
  late final AnimationController _contentController;
  late final Listenable _foldAnimation;
  int _foldGeneration = 0;
  bool _reducedMotion = false;
  bool? _lastCollapsed;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _nodeTitle);
    _titleFocus = FocusNode(debugLabel: 'code_block_title')
      ..addListener(_onTitleFocusChanged);
    final initialCollapsed =
        (widget.node.attributes['collapsed'] as bool?) ?? false;
    _lastCollapsed = initialCollapsed;
    _foldController = AnimationController(
      vsync: this,
      value: initialCollapsed ? 0.0 : 1.0,
    );
    _contentController = AnimationController(
      vsync: this,
      value: initialCollapsed ? 0.0 : 1.0,
    );
    _foldAnimation = Listenable.merge([_foldController, _contentController]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _syncFold(_lastCollapsed ?? false);
  }

  void _syncFold(bool collapsed) {
    final generation = ++_foldGeneration;
    _foldController.stop();
    _contentController.stop();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    final target = collapsed ? 0.0 : 1.0;
    if (_reducedMotion) {
      _foldController.value = target;
      _contentController.value = target;
      return;
    }
    unawaited(_animateFold(collapsed, generation));
  }

  Future<void> _animateFold(bool collapsed, int generation) async {
    Future<void> drive(
      AnimationController controller,
      double target,
      Duration duration,
    ) async {
      if (controller.value == target) return;
      await controller
          .animateTo(target, duration: duration, curve: Motion.curve)
          .orCancel;
    }

    try {
      if (collapsed) {
        await drive(_contentController, 0, Motion.foldContent);
        if (!mounted || generation != _foldGeneration) return;
        await drive(_foldController, 0, Motion.foldSize);
      } else {
        await drive(_foldController, 1, Motion.foldSize);
        if (!mounted || generation != _foldGeneration) return;
        await drive(_contentController, 1, Motion.foldContent);
      }
    } on TickerCanceled {
      // Reversal, reduced motion and disposal supersede the previous sequence.
    }
  }

  @override
  void didUpdateWidget(CodeBlockComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final title = _nodeTitle;
    if (_titleController.text != title) _titleController.text = title;
    final isCollapsed = (node.attributes['collapsed'] as bool?) ?? false;
    if (_lastCollapsed != isCollapsed) {
      _lastCollapsed = isCollapsed;
      _syncFold(isCollapsed);
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onTitleFocusChanged);
    _titleFocus.dispose();
    _titleController.dispose();
    _foldController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _sealTitleHistory() {
    if (editorState.undoManager.undoStack.isNonEmpty) {
      editorState.undoManager.undoStack.last.seal();
    }
  }

  void _onTitleFocusChanged() {
    if (editorState.isDisposed || !editorState.editable) return;
    _sealTitleHistory();
    if (_titleFocus.hasFocus) {
      editorState.selection = null;
      editorState.service.keyboardService?.disableShortcuts();
    } else {
      editorState.service.keyboardService?.enableShortcuts();
    }
    if (mounted) setState(() {});
  }

  void _setTitle(String value) {
    if (!editorState.editable || editorState.isDisposed) return;
    if (_nodeTitle == value) return;
    final transaction = editorState.transaction;
    transaction.updateNode(node, {...node.attributes, 'title': value});
    editorState.apply(transaction, withUpdateSelection: false);
  }

  void _finishTitle() {
    _titleFocus.unfocus();
    if (editorState.editable && !editorState.isDisposed) {
      editorState.selection = Selection.collapsed(Position(path: node.path));
      editorState.service.keyboardService?.enableShortcuts();
      editorState.service.keyboardService?.enable();
    }
  }

  Future<void> _showMore(BuildContext buttonContext) async {
    if (_moreOpen || !editorState.editable) return;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final l10n = context.l10n;
    _moreOpen = true;
    try {
      await showPopover(
        context,
        anchor: box.localToGlobal(Offset.zero) & box.size,
        width: DesktopUx.menuWidth,
        builder: (_, close) => MenuRow(
          label: l10n.codePaste,
          glyph: AppIcons.docOnClipboard,
          autofocus: true,
          onTap: () {
            close();
            if (mounted) _pasteCode();
          },
        ),
      );
    } finally {
      _moreOpen = false;
    }
  }

  void _copyCode() {
    final text = node.delta?.toPlainText() ?? '';
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _isCopied = true);
    Future.delayed(Motion.copiedFeedback, () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  void _pasteCode() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text;
    if (!mounted ||
        editorState.isDisposed ||
        !editorState.editable ||
        text == null ||
        text.isEmpty ||
        editorState.getNodeAtPath(node.path) != node) {
      return;
    }
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final selection = editorState.selection;
    if (selection != null && selection.start.path.equals(node.path)) {
      if (!selection.isCollapsed) {
        await editorState.deleteSelection(selection);
      }
      await editorState.insertTextAtPosition(
        normalized,
        position: editorState.selection?.start,
      );
    } else {
      final currentText = node.delta?.toPlainText() ?? '';
      final newText = currentText.isEmpty
          ? normalized
          : '$currentText\n$normalized';
      final transaction = editorState.transaction;
      transaction.updateNode(node, {
        ...node.attributes,
        'delta': (Delta()..insert(newText)).toJson(),
      });
      await editorState.apply(transaction);
    }
  }

  void _setLanguage(String lang) {
    if (!editorState.editable || editorState.isDisposed) return;
    final transaction = editorState.transaction;
    transaction.updateNode(node, {...node.attributes, 'language': lang});
    editorState.apply(transaction);
  }

  void _toggleCollapsed() {
    if (!editorState.editable || editorState.isDisposed) return;
    final current = node.attributes['collapsed'] as bool? ?? false;
    final next = !current;
    _lastCollapsed = next;
    _syncFold(next);
    final transaction = editorState.transaction;
    transaction.updateNode(node, {...node.attributes, 'collapsed': next});
    if (next && editorState.selection?.start.path.equals(node.path) == true) {
      transaction.afterSelection = null;
    }
    editorState.apply(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final language = (node.attributes['language'] as String?) ?? 'dart';
    final isCollapsed = (node.attributes['collapsed'] as bool?) ?? false;

    if (_lastCollapsed != isCollapsed) {
      _lastCollapsed = isCollapsed;
      _syncFold(isCollapsed);
    }

    final langLabel = supportedCodeLanguages
        .firstWhere(
          (l) => l.$1.toLowerCase() == language.toLowerCase(),
          orElse: () => (language, language.toUpperCase()),
        )
        .$2;

    final codeBg = skin.codeSurface;
    final codeTextColor = skin.codeText;

    final fontName = defaultTargetPlatform == TargetPlatform.macOS
        ? 'Menlo'
        : 'Consolas';

    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    // Code RichText editing field
    Widget codeEditor = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        UiSpace.s16,
        UiSpace.s12,
        UiSpace.s16,
        UiSpace.s12,
      ),
      child: AppFlowyRichText(
        key: forwardKey,
        delegate: this,
        node: widget.node,
        editorState: editorState,
        textAlign: alignment?.toTextAlign ?? textAlign,
        placeholderText: context.l10n.codePlaceholder,
        textSpanDecorator: (textSpan) {
          final rawText = node.delta?.toPlainText() ?? '';
          if (rawText.isEmpty) {
            return textSpan.updateTextStyle(
              TextStyle(
                fontFamily: fontName,
                fontSize: UiType.code,
                height: UiType.codeLineHeight,
                fontWeight: FontWeight.w400,
                color: codeTextColor,
              ),
            );
          }
          final spans = CodeHighlighter.highlight(
            text: rawText,
            language: language,
            isDark: isDark,
            fontName: fontName,
            fontSize: UiType.code,
            height: UiType.codeLineHeight,
          );
          return TextSpan(
            style: TextStyle(
              fontFamily: fontName,
              fontSize: UiType.code,
              height: UiType.codeLineHeight,
              fontWeight: FontWeight.w400,
              color: codeTextColor,
            ),
            children: spans.isNotEmpty ? spans : [textSpan],
          );
        },
        placeholderTextSpanDecorator: (textSpan) => textSpan.updateTextStyle(
          TextStyle(
            fontFamily: fontName,
            fontSize: UiType.code,
            height: UiType.codeLineHeight,
            fontWeight: FontWeight.w400,
            color: skin.hint,
          ),
        ),
        textDirection: textDirection,
        cursorColor: Palette.accent,
        selectionColor: Palette.accent.withValues(alpha: 0.25),
        cursorWidth: editorState.editorStyle.cursorWidth,
      ),
    );

    final foldingContent = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _foldAnimation,
        child: RepaintBoundary(child: codeEditor),
        builder: (context, child) {
          final hidden = isCollapsed || _contentController.value == 0;
          return IgnorePointer(
            ignoring: hidden,
            child: ExcludeFocus(
              excluding: hidden,
              child: ExcludeSemantics(
                excluding: hidden,
                child: _CodeFoldExtent(
                  key: const Key('code_fold_extent'),
                  expanded: !isCollapsed,
                  progress: _foldController.value,
                  collapsedHeight: 0,
                  child: FadeTransition(
                    key: const Key('code_fold_content'),
                    opacity: _contentController,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        UiSpace.s8 * (1 - _contentController.value),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    Widget child = Container(
      key: const Key('code_block_surface'),
      margin: const EdgeInsets.symmetric(vertical: UiSpace.s8),
      decoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(UiRadius.dialog),
      ),
      clipBehavior: Clip.antiAlias,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onEnter: (_) {
          if (!_isHovered) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (_isHovered) setState(() => _isHovered = false);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TapRegion(
              groupId: editorTapGroup,
              child: Container(
                key: const Key('code_block_header'),
                color: skin.codeBadge,
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s8,
                  vertical: UiSpace.s4,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 300;
                    final title = Row(
                      children: [
                        _CompactIconButton(
                          buttonKey: const Key('code_fold_button'),
                          tooltip: isCollapsed
                              ? context.l10n.codeExpand
                              : context.l10n.codeCollapse,
                          icon: isCollapsed
                              ? AppIcons.chevronRight
                              : AppIcons.chevronDown,
                          onTap: editorState.editable ? _toggleCollapsed : null,
                        ),
                        const SizedBox(width: UiSpace.s4),
                        Expanded(
                          child: TextField(
                            key: const Key('code_block_title'),
                            controller: _titleController,
                            focusNode: _titleFocus,
                            selectAllOnFocus: false,
                            readOnly: !editorState.editable,
                            contextMenuBuilder: (context, state) =>
                                appTextMenu(context, state),
                            onChanged: _setTitle,
                            onSubmitted: (_) => _finishTitle(),
                            style: TextStyle(
                              fontSize: UiType.editorTitle,
                              fontWeight: FontWeight.w600,
                              height: UiType.editorLineHeight,
                              color: skin.text,
                            ),
                            decoration: InputDecoration(
                              hintText: context.l10n.codeTitlePlaceholder,
                              hintStyle: TextStyle(
                                color: (_isHovered || _titleFocus.hasFocus)
                                    ? skin.hint
                                    : Colors.transparent,
                                fontWeight: FontWeight.w400,
                              ),
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: UiSpace.s4,
                                vertical: UiSpace.s4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                    final actions = AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: (_isHovered || _moreOpen) ? 1.0 : 0.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: (constraints.maxWidth - 64).clamp(
                                40.0,
                                120.0,
                              ),
                            ),
                            child: _LanguageBadge(
                              language: language,
                              langLabel: langLabel,
                              onSelected: editorState.editable
                                  ? _setLanguage
                                  : null,
                            ),
                          ),
                          const SizedBox(width: UiSpace.s4),
                          _CompactIconButton(
                            tooltip: _isCopied
                                ? context.l10n.copied
                                : context.l10n.codeCopy,
                            icon: _isCopied
                                ? AppIcons.checkMark
                                : AppIcons.docOnDoc,
                            iconColor: _isCopied ? Palette.success : null,
                            onTap: _copyCode,
                          ),
                          if (editorState.editable)
                            Builder(
                              builder: (buttonContext) => _CompactIconButton(
                                buttonKey: const Key('code_more_actions'),
                                tooltip: context.l10n.codeMoreActions,
                                icon: AppIcons.ellipsis,
                                onTap: () => _showMore(buttonContext),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          title,
                          Align(alignment: Alignment.centerRight, child: actions),
                        ],
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: UiSpace.s28),
                      child: Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: UiSpace.s8),
                          actions,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            foldingContent,
          ],
        ),
      ),
    );

    child = Container(
      decoration: decoration,
      key: blockComponentKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }
}

class _LanguageBadge extends StatelessWidget {
  final String language;
  final String langLabel;
  final ValueChanged<String>? onSelected;

  const _LanguageBadge({
    required this.language,
    required this.langLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return PopupMenuButton<String>(
      tooltip: context.l10n.codeLanguageTooltip(langLabel),
      enabled: onSelected != null,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopUx.menuRadius),
        side: BorderSide(color: skin.divider),
      ),
      color: skin.card,
      child: Container(
        constraints: BoxConstraints(minHeight: UiSpace.s24, minWidth: 0),
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s4,
          vertical: UiSpace.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                langLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: UiType.caption,
                  fontWeight: FontWeight.w400,
                  color: skin.muted,
                ),
              ),
            ),
            const SizedBox(width: UiSpace.s3),
            Icon(AppIcons.chevronDown, size: UiSpace.s14, color: skin.muted),
          ],
        ),
      ),
      itemBuilder: (context) => [
        for (final item in supportedCodeLanguages)
          PopupMenuItem<String>(
            value: item.$1,
            height: DesktopUx.menuRowHeight,
            child: Text(
              item.$2,
              style: TextStyle(
                fontSize: UiType.body,
                fontWeight: item.$1 == language
                    ? FontWeight.w500
                    : FontWeight.w400,
                color: item.$1 == language ? skin.accentText : skin.text,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.buttonKey,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: tooltip,
    onPressed: onTap,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(
      width: UiSpace.s24,
      height: UiSpace.s24,
    ),
    style: IconButton.styleFrom(
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.small),
      ),
    ),
    icon: Icon(icon, size: UiSpace.s14, color: iconColor ?? context.skin.muted),
  );
}

/// Measures the complete editor while its container changes height.
class _CodeFoldExtent extends SingleChildRenderObjectWidget {
  const _CodeFoldExtent({
    super.key,
    required this.expanded,
    required this.progress,
    required this.collapsedHeight,
    required super.child,
  });

  final bool expanded;
  final double progress;
  final double collapsedHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCodeFoldExtent(expanded, progress, collapsedHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCodeFoldExtent renderObject,
  ) {
    renderObject.update(expanded, progress, collapsedHeight);
  }
}

class _RenderCodeFoldExtent extends RenderProxyBox {
  _RenderCodeFoldExtent(this._expanded, this._progress, this._collapsedHeight);

  bool _expanded;
  double _progress;
  double _collapsedHeight;
  double? _openHeight;

  void update(bool expanded, double progress, double collapsedHeight) {
    if (_expanded == expanded &&
        _progress == progress &&
        _collapsedHeight == collapsedHeight) {
      return;
    }
    _expanded = expanded;
    _progress = progress;
    _collapsedHeight = collapsedHeight;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    final naturalHeight = child!.size.height;
    if (_expanded || _progress >= 0.99) {
      _openHeight = naturalHeight;
    }
    final targetOpen = _openHeight ?? naturalHeight;
    final currentTarget = naturalHeight <= _collapsedHeight
        ? naturalHeight
        : (ui.lerpDouble(_collapsedHeight, targetOpen, _progress) ??
              naturalHeight);

    size = constraints.constrain(Size(child!.size.width, currentTarget));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) return constraints.smallest;
    final natural = child!.getDryLayout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
    );
    final targetOpen = _openHeight ?? natural.height;
    final currentTarget = natural.height <= _collapsedHeight
        ? natural.height
        : (ui.lerpDouble(_collapsedHeight, targetOpen, _progress) ??
              natural.height);
    return constraints.constrain(Size(natural.width, currentTarget));
  }
}

/// Command shortcut that intercepts Cmd+V / Ctrl+V in code blocks
/// to ensure multi-line code pastes cleanly inside the block rather
/// than splitting it into multiple paragraph blocks.
final CommandShortcutEvent codeBlockPasteCommand = CommandShortcutEvent(
  key: 'paste in code block',
  getDescription: () => 'paste in code block',
  command: 'ctrl+v',
  macOSCommand: 'cmd+v',
  handler: _codeBlockPasteHandler,
);

final CommandShortcutEvent codeBlockPasteWithoutFormattingCommand =
    CommandShortcutEvent(
      key: 'paste text without formatting in code block',
      getDescription: () => 'paste text without formatting in code block',
      command: 'ctrl+shift+v',
      macOSCommand: 'cmd+shift+v',
      handler: _codeBlockPasteHandler,
    );

KeyEventResult _codeBlockPasteHandler(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) return KeyEventResult.ignored;

  final node = editorState.getNodeAtPath(selection.start.path);
  if (node?.type != codeBlockType) {
    return KeyEventResult.ignored;
  }

  () async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text;
    if (text == null || text.isEmpty) return;

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final currentSelection = editorState.selection;
    if (currentSelection != null && !currentSelection.isCollapsed) {
      await editorState.deleteSelection(currentSelection);
    }

    await editorState.insertTextAtPosition(
      normalized,
      position: editorState.selection?.start,
    );
  }();

  return KeyEventResult.handled;
}

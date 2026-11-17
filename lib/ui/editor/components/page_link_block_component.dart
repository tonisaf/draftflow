import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:provider/provider.dart';

import '../../../data/db/app_database.dart';
import '../../../data/notes_repository.dart';
import '../../../l10n/locale_controller.dart';
import '../../common/app_icons.dart';
import '../../common/page_link_utils.dart';
import '../../common/quiet_button.dart';
import '../../theme.dart';
import 'page_block_reorder.dart';

const String pageLinkBlockType = 'page_link';

abstract final class PageLinkBlockKeys {
  static const String type = pageLinkBlockType;
  static const String pageId = 'pageId';
  static const String title = 'title';
  static const String icon = 'icon';
}

Node pageLinkNode({
  required String pageId,
  String? title,
  String? icon,
}) =>
    Node(
      type: PageLinkBlockKeys.type,
      attributes: {
        PageLinkBlockKeys.pageId: pageId,
        if (title != null && title.isNotEmpty) PageLinkBlockKeys.title: title,
        if (icon != null && icon.isNotEmpty) PageLinkBlockKeys.icon: icon,
      },
    );

class PageLinkBlockComponentBuilder extends BlockComponentBuilder {
  final NotesRepository repository;
  final ValueChanged<String>? onNavigateToPage;

  PageLinkBlockComponentBuilder({
    super.configuration,
    required this.repository,
    this.onNavigateToPage,
  });

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return PageLinkBlockComponentWidget(
      key: node.key,
      node: node,
      repository: repository,
      onNavigateToPage: onNavigateToPage,
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
      (node) => node.attributes[PageLinkBlockKeys.pageId] != null;
}

class PageLinkBlockComponentWidget extends BlockComponentStatefulWidget {
  final NotesRepository repository;
  final ValueChanged<String>? onNavigateToPage;

  const PageLinkBlockComponentWidget({
    super.key,
    required super.node,
    required this.repository,
    this.onNavigateToPage,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<PageLinkBlockComponentWidget> createState() =>
      _PageLinkBlockComponentWidgetState();
}

class _PageLinkBlockComponentWidgetState
    extends State<PageLinkBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  late Stream<Page?> _pageStream;
  String _lastPageId = '';

  late final EditorState _editorState = Provider.of<EditorState>(
    context,
    listen: false,
  );

  @override
  void initState() {
    super.initState();
    _lastPageId =
        widget.node.attributes[PageLinkBlockKeys.pageId] as String? ?? '';
    _pageStream = widget.repository.watchPage(_lastPageId);
  }

  @override
  void didUpdateWidget(PageLinkBlockComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentPageId =
        widget.node.attributes[PageLinkBlockKeys.pageId] as String? ?? '';
    if (currentPageId != _lastPageId ||
        oldWidget.repository != widget.repository) {
      _lastPageId = currentPageId;
      _pageStream = widget.repository.watchPage(_lastPageId);
    }
  }

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

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
    final box = _renderBox;
    if (box != null && box.hasSize) {
      return Offset.zero & box.size;
    }
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) => getBlockRect();

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) => [getBlockRect()];

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox?.localToGlobal(offset) ?? offset;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final pageId =
        widget.node.attributes[PageLinkBlockKeys.pageId] as String? ?? '';
    final cachedTitle =
        widget.node.attributes[PageLinkBlockKeys.title] as String? ?? '';
    final cachedIcon =
        widget.node.attributes[PageLinkBlockKeys.icon] as String?;

    Widget content = StreamBuilder<Page?>(
      stream: _pageStream,
      builder: (context, snapshot) {
        final page = snapshot.data;
        final isDeleted = page == null || page.trashedAt != null;

        final title = isDeleted
            ? (cachedTitle.isNotEmpty ? cachedTitle : 'Удалённая страница')
            : (page.title.trim().isEmpty
                ? context.l10n.untitled
                : page.title.trim());
        final icon = isDeleted
            ? null
            : (page.icon?.isNotEmpty == true ? page.icon : cachedIcon);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: UiSpace.s4),
          child: QuietButton(
            key: ValueKey('page_link_${pageId}_$isDeleted'),
            label: title,
            onTap: isDeleted ? null : () => widget.onNavigateToPage?.call(pageId),
            onSecondaryTapDown: (details) {
              unawaited(
                showBlockContextMenu(
                  context,
                  anchor: Rect.fromLTWH(
                    details.globalPosition.dx,
                    details.globalPosition.dy,
                    1,
                    1,
                  ),
                  editor: _editorState,
                  node: widget.node,
                ),
              );
            },
            builder: (context, {required hover, required focus, required pressed}) =>
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: hover
                        ? skin.sidebarSelected
                        : skin.hover,
                    shape: UiRadius.squircle(
                      UiRadius.card,
                      side: focus
                          ? BorderSide(color: skin.outline)
                          : BorderSide(
                              color: skin.hairlineBorder,
                              width: UiSpace.s1,
                            ),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: UiLayout.subpageCardHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(UiSpace.s14),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: UiSpace.s24,
                            child: Center(
                              child: isDeleted
                                  ? Icon(
                                      AppIcons.trash,
                                      size: UiSpace.s16,
                                      color: skin.muted,
                                    )
                                  : (icon != null && icon.isNotEmpty
                                      ? Text(
                                          icon,
                                          style: const TextStyle(
                                            fontSize: UiType.editorBody,
                                          ),
                                        )
                                      : Icon(
                                          AppIcons.docText,
                                          size: UiSpace.s16,
                                          color: skin.muted,
                                        )),
                            ),
                          ),
                          const SizedBox(width: UiSpace.s10),
                          Expanded(
                            child: Tooltip(
                              message: title,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: UiType.title,
                                  fontWeight: FontWeight.w400,
                                  color: isDeleted ? skin.muted : skin.text,
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          if (hover && !isDeleted) ...[
                            QuietButton(
                              label: 'Копировать ссылку',
                              tooltip: 'Копировать ссылку',
                              onTap: () {
                                copyPageLinkDetailsToClipboard(
                                  context,
                                  pageId: pageId,
                                  title: title,
                                  icon: icon,
                                );
                              },
                              builder: (context, {required hover, required focus, required pressed}) =>
                                  Padding(
                                    padding: const EdgeInsets.all(UiSpace.s4),
                                    child: Icon(
                                      AppIcons.link,
                                      size: UiSpace.s14,
                                      color: hover ? skin.text : skin.muted,
                                    ),
                                  ),
                            ),
                            const SizedBox(width: UiSpace.s4),
                          ],
                          Icon(
                            AppIcons.arrowUpRightSquare,
                            size: UiSpace.s16,
                            color: skin.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
        );
      },
    );

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

    return content;
  }
}

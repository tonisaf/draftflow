import '../common/app_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart' hide Page;

import '../../data/model/page_tree_node.dart';
import '../../l10n/locale_controller.dart';
import '../common/menu.dart';
import '../common/page_icon_view.dart';
import '../common/page_link_utils.dart';
import '../common/popover.dart';
import '../common/spring_motion.dart';
import '../theme.dart';
import 'sidebar_drop_indicator.dart';

class SidebarItem extends StatefulWidget {
  final PageTreeNode node;
  final PageTreeNode? prevSibling;
  final PageTreeNode? nextSibling;
  final bool isExpanded;
  final bool isSelected;
  final bool Function(String draggedId) canAcceptDrop;
  final VoidCallback onTap;
  final VoidCallback onToggleExpand;
  final VoidCallback onAddSubpage;
  final VoidCallback onDelete;
  final VoidCallback? onExport;
  final VoidCallback? onImportNotionCsv;
  final ValueChanged<String> onDropAbove;
  final ValueChanged<String> onDropBelow;
  final ValueChanged<String> onDropInside;
  final VoidCallback onRequestAutoExpand;

  const SidebarItem({
    super.key,
    required this.node,
    this.prevSibling,
    this.nextSibling,
    required this.isExpanded,
    required this.isSelected,
    required this.canAcceptDrop,
    required this.onTap,
    required this.onToggleExpand,
    required this.onAddSubpage,
    required this.onDelete,
    this.onExport,
    this.onImportNotionCsv,
    required this.onDropAbove,
    required this.onDropBelow,
    required this.onDropInside,
    required this.onRequestAutoExpand,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;
  DropPosition? _currentDropPosition;
  Timer? _autoExpandTimer;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoExpand() {
    _autoExpandTimer?.cancel();
    if (!widget.isExpanded && widget.node.hasChildren) {
      _autoExpandTimer = Timer(Motion.dragExpandDelay, () {
        if (mounted && _currentDropPosition == DropPosition.inside) {
          widget.onRequestAutoExpand();
        }
      });
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final anchor = Rect.fromCenter(
      center: globalPos,
      width: UiSpace.s1,
      height: 1,
    );

    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.pageMenuWidth,
      builder: (popContext, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onExport != null || widget.onImportNotionCsv != null)
            MenuSectionHeader(title: context.l10n.importExportSection),
          if (widget.onExport != null)
            MenuRow(
              label: context.l10n.exportMarkdownEllipsis,
              glyph: AppIcons.squareArrowUp,
              onTap: () {
                close();
                widget.onExport?.call();
              },
            ),
          if (widget.onImportNotionCsv != null)
            MenuRow(
              label: context.l10n.importNotionCsvEllipsis,
              glyph: AppIcons.table,
              onTap: () {
                close();
                widget.onImportNotionCsv?.call();
              },
            ),
          const MenuDivider(),
          MenuSectionHeader(title: context.l10n.pageSection),
          MenuRow(
            label: context.l10n.copyLinkToPage,
            glyph: AppIcons.link,
            onTap: () {
              close();
              copyPageLinkToClipboard(context, widget.node.page);
            },
          ),
          MenuRow(
            label: context.l10n.newSubpage,
            glyph: AppIcons.plus,
            onTap: () {
              close();
              widget.onAddSubpage();
            },
          ),
          const MenuDivider(),
          MenuRow(
            label: context.l10n.deletePage,
            glyph: AppIcons.trash,
            destructive: true,
            onTap: () {
              close();
              widget.onDelete();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final depth = widget.node.depth;
    final hasChildren = widget.node.hasChildren;
    final title = widget.node.page.title.trim().isEmpty
        ? context.l10n.untitled
        : widget.node.page.title;

    Color fill;
    Border? border;

    if (_currentDropPosition == DropPosition.inside) {
      fill = Palette.accent.withValues(alpha: 0.16);
      border = Border.all(color: Palette.accent, width: UiSpace.s1_5);
    } else if (widget.isSelected) {
      fill = skin.sidebarSelected;
      border = null;
    } else if (_isHovered || _isFocused) {
      fill = skin.hover;
      border = null;
    } else {
      fill = Palette.transparent;
      border = null;
    }

    final itemContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onHighlightChanged: (highlighted) =>
            setState(() => _isPressed = highlighted),
        onTap: widget.onTap,
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: SpringPress(
          pressed: _isPressed,
          scale: 0.985,
          child: Container(
          constraints: const BoxConstraints(
            minHeight: DesktopUx.sidebarRowHeight,
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: UiSpace.s10,
            vertical: UiSpace.s1,
          ),
          padding: EdgeInsets.fromLTRB(
            UiSpace.s8 + (depth * DesktopUx.treeIndent),
            UiSpace.s6,
            UiSpace.s8,
            UiSpace.s6,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
            border: border,
          ),
          child: Row(
            children: [
              // Page icon (Custom emoji, folder, or doc)
              SizedBox.square(
                dimension: UiSpace.s18,
                child: Center(
                  child:
                      (widget.node.page.icon != null &&
                          widget.node.page.icon!.isNotEmpty)
                      ? PageIconView(
                          icon: widget.node.page.icon!,
                          size: UiType.title,
                        )
                      : (hasChildren
                            ? Icon(
                                widget.isExpanded
                                    ? AppIcons.folder
                                    : AppIcons.folder,
                                size: DesktopUx.sidebarIconSize,
                                color: widget.isSelected
                                    ? skin.text
                                    : skin.muted,
                              )
                            : Icon(
                                AppIcons.docText,
                                size: DesktopUx.sidebarIconSize,
                                color: widget.isSelected
                                    ? skin.text
                                    : skin.muted,
                              )),
                ),
              ),
              const SizedBox(width: DesktopUx.sidebarIconGap),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UiType.title,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: skin.text,
                  ),
                ),
              ),
              if (_isHovered || _isFocused) ...[
                // Add Subpage button
                Tooltip(
                  message: context.l10n.newSubpage,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onAddSubpage,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UiSpace.s2,
                      ),
                      child: Icon(
                        AppIcons.plus,
                        size: UiSpace.s14,
                        color: skin.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: UiSpace.s4),
                // Delete button
                Tooltip(
                  message: context.l10n.deletePage,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UiSpace.s2,
                      ),
                      child: Icon(
                        AppIcons.xmark,
                        size: UiSpace.s14,
                        color: skin.destructive,
                      ),
                    ),
                  ),
                ),
              ],
              if (hasChildren)
                SizedBox.square(
                  dimension: UiSpace.s18,
                  child: IconButton(
                    tooltip: widget.isExpanded
                        ? context.l10n.collapsePage
                        : context.l10n.expandPage,
                    padding: EdgeInsets.zero,
                    onPressed: widget.onToggleExpand,
                    icon: SpringRotation(
                      turns: widget.isExpanded ? 0.25 : 0.0,
                      child: Icon(
                        AppIcons.chevronRight,
                        size: UiSpace.s16,
                        color: skin.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );

    return RepaintBoundary(
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
        return widget.canAcceptDrop(details.data);
      },
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(details.offset);
        final height = renderBox.size.height;

        final threshold = (height * 0.30).clamp(8.0, 12.0);
        final DropPosition newPos;
        if (localPos.dy < threshold) {
          newPos = DropPosition.above;
        } else if (localPos.dy > height - threshold) {
          newPos = DropPosition.below;
        } else {
          newPos = DropPosition.inside;
        }

        if (_currentDropPosition != newPos) {
          setState(() => _currentDropPosition = newPos);
          if (newPos == DropPosition.inside) {
            _scheduleAutoExpand();
          } else {
            _autoExpandTimer?.cancel();
          }
        }
      },
      onLeave: (_) {
        _autoExpandTimer?.cancel();
        if (_currentDropPosition != null) {
          setState(() => _currentDropPosition = null);
        }
      },
      onAcceptWithDetails: (details) {
        _autoExpandTimer?.cancel();
        final pos = _currentDropPosition ?? DropPosition.inside;
        setState(() => _currentDropPosition = null);
        if (pos == DropPosition.above) {
          widget.onDropAbove(details.data);
        } else if (pos == DropPosition.below) {
          widget.onDropBelow(details.data);
        } else {
          widget.onDropInside(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Draggable<String>(
          data: widget.node.page.id,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Palette.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UiSpace.s10,
                vertical: UiSpace.s6,
              ),
              decoration: BoxDecoration(
                color: skin.surface,
                borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
                border: Border.all(color: Palette.accent, width: UiSpace.s1_5),
                boxShadow: [
                  BoxShadow(
                    color: skin.shadow,
                    blurRadius: UiSpace.s14,
                    offset: const Offset(0, UiSpace.s4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.node.page.icon != null &&
                      widget.node.page.icon!.isNotEmpty) ...[
                    PageIconView(
                      icon: widget.node.page.icon!,
                      size: UiType.title,
                    ),
                    const SizedBox(width: UiSpace.s6),
                  ] else ...[
                    Icon(
                      AppIcons.docText,
                      size: UiSpace.s14,
                      color: Palette.accent,
                    ),
                    const SizedBox(width: UiSpace.s6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: UiType.body,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: itemContent),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              itemContent,
              if (_currentDropPosition == DropPosition.above)
                Positioned(
                  top: -1.5,
                  left: UiSpace.s10 + widget.node.depth * DesktopUx.treeIndent,
                  right: UiSpace.s10,
                  child: const DropLineIndicator(),
                ),
              if (_currentDropPosition == DropPosition.below)
                Positioned(
                  bottom: -1.5,
                  left: UiSpace.s10 + widget.node.depth * DesktopUx.treeIndent,
                  right: UiSpace.s10,
                  child: const DropLineIndicator(),
                ),
            ],
          ),
        );
      },
    ),
  );
}
}

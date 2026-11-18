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
  final String? parentTitle;
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
    this.parentTitle,
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
  Timer? _hoverPreviewTimer;
  OverlayEntry? _hoverPreviewEntry;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    _hoverPreviewTimer?.cancel();
    _hoverPreviewEntry?.remove();
    _hoverPreviewEntry = null;
    super.dispose();
  }

  void _hideHoverCard() {
    _hoverPreviewTimer?.cancel();
    _hoverPreviewEntry?.remove();
    _hoverPreviewEntry = null;
  }

  String _formatPreviewTimestamp(DateTime date) {
    final now = DateTime.now();
    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (isToday) {
      return 'Updated $hour:$minute';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day;
    if (isYesterday) {
      return 'Updated Yesterday, $hour:$minute';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'Updated $day.$month $hour:$minute';
  }

  void _showHoverCard() {
    if (!mounted || !_isHovered || _hoverPreviewEntry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final globalPos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.sizeOf(context);

    final top = (globalPos.dy - 4.0).clamp(10.0, (screenSize.height - 110.0).clamp(10.0, double.infinity));
    final left = globalPos.dx + size.width + 10.0;

    _hoverPreviewEntry = OverlayEntry(
      builder: (overlayContext) {
        final skin = context.skin;
        final title = widget.node.page.title.trim().isEmpty
            ? context.l10n.untitled
            : widget.node.page.title;

        return Positioned(
          top: top,
          left: left,
          child: IgnorePointer(
            child: Material(
              color: Palette.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240, minWidth: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  color: skin.card,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: skin.hairlineBorder),
                  boxShadow: skin.popoverShadows,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.parentTitle != null &&
                        widget.parentTitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 5.0),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 13.0,
                            color: skin.muted,
                          ),
                          const SizedBox(width: 4.0),
                          Flexible(
                            child: Text(
                              widget.parentTitle!,
                              style: TextStyle(
                                fontSize: 11.0,
                                color: skin.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13.0,
                          color: skin.muted,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          _formatPreviewTimestamp(widget.node.page.createdAt),
                          style: TextStyle(
                            fontSize: 11.0,
                            color: skin.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_hoverPreviewEntry!);
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

    final hasCustomIcon = widget.node.page.icon != null &&
        widget.node.page.icon!.isNotEmpty;

    final itemContent = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverPreviewTimer?.cancel();
        _hoverPreviewTimer = Timer(const Duration(milliseconds: 450), _showHoverCard);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hideHoverCard();
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onHighlightChanged: (highlighted) =>
            setState(() => _isPressed = highlighted),
        onTap: () {
          _hideHoverCard();
          widget.onTap();
          if (hasChildren) {
            widget.onToggleExpand();
          }
        },
        onSecondaryTapUp: (details) {
          _hideHoverCard();
          _showContextMenu(context, details.globalPosition);
        },
        child: SpringPress(
          pressed: _isPressed,
          scale: 0.985,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: DesktopUx.sidebarRowHeight,
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: UiSpace.s8,
              vertical: 1.0,
            ),
            padding: EdgeInsets.fromLTRB(
              UiSpace.s8 + (depth * DesktopUx.treeIndent),
              UiSpace.s4,
              UiSpace.s6,
              UiSpace.s4,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
              border: border,
            ),
            child: Row(
              children: [
                if (hasCustomIcon) ...[
                  SizedBox.square(
                    dimension: 16.0,
                    child: Center(
                      child: PageIconView(
                        icon: widget.node.page.icon!,
                        size: 13.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: UiSpace.s6),
                ] else if (hasChildren) ...[
                  SizedBox.square(
                    dimension: 16.0,
                    child: Center(
                      child: Icon(
                        Icons.folder_outlined,
                        size: 15.0,
                        color: widget.isSelected ? skin.text : skin.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: UiSpace.s6),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: widget.isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      letterSpacing: -0.1,
                      color: skin.text,
                    ),
                  ),
                ),
                if (_isHovered || _isFocused) ...[
                  // Add Subpage button
                  Tooltip(
                    message: context.l10n.newSubpage,
                    child: InkResponse(
                      radius: 12,
                      onTap: () {
                        _hideHoverCard();
                        widget.onAddSubpage();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3.0,
                          vertical: 2.0,
                        ),
                        child: Icon(
                          AppIcons.plus,
                          size: 14.0,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2.0),
                  // Options menu button (replaces red cross!)
                  Tooltip(
                    message: context.l10n.pageOptions,
                    child: InkResponse(
                      radius: 12,
                      onTapDown: (details) {
                        _hideHoverCard();
                        _showContextMenu(context, details.globalPosition);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3.0,
                          vertical: 2.0,
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 15.0,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ),
                ],
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
          onDragStarted: _hideHoverCard,
          feedback: Material(
            color: Palette.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UiSpace.s8,
                vertical: UiSpace.s4,
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
                      size: 13.0,
                    ),
                    const SizedBox(width: UiSpace.s6),
                  ] else if (hasChildren) ...[
                    Icon(
                      Icons.folder_outlined,
                      size: 14.0,
                      color: Palette.accent,
                    ),
                    const SizedBox(width: UiSpace.s6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
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

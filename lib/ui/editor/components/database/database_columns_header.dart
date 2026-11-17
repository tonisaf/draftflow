import 'database_grid_navigation.dart';

import 'package:flutter/services.dart';

import '../../../common/app_icons.dart';

import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/menu.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_models.dart';
import 'database_property_menu.dart';
import 'database_sticky_pane.dart';

// ----------------------------------------------------------------------------
// Columns Header Row
// ----------------------------------------------------------------------------

class ColumnsHeaderRow extends StatelessWidget {
  final DatabaseGridSelectionController? selectionController;
  final ScrollController? horizontalScrollController;
  final bool freezeTitle;
  final List<DatabaseColumn> columns;
  final Map<String, double> columnWidths;
  final Color headerBg;
  final Color borderColor;
  final DatabaseSortConfig? sortConfig;
  final void Function(String? colId, bool ascending) onSortChanged;
  final void Function(String colId, double width) onResize;
  final void Function(String colId, double width) onResizeEnd;
  final void Function(String colId)? onAutoFit;
  final void Function(String colId, String newName)? onRenameColumn;
  final void Function(String colId, String newType)? onChangeColumnType;
  final void Function(String colId, String newOptions)? onChangeColumnOptions;
  final void Function(String colId)? onMoveColumnLeft;
  final void Function(String colId)? onMoveColumnRight;
  final void Function(String draggedColId, String targetColId)? onReorderColumn;
  final ValueChanged<String> onDeleteColumn;
  final VoidCallback onAddColumn;
  final Key? addPropertyKey;

  const ColumnsHeaderRow({
    this.selectionController,
    this.horizontalScrollController,
    this.freezeTitle = true,
    super.key,
    required this.columns,
    required this.columnWidths,
    required this.headerBg,
    required this.borderColor,
    this.sortConfig,
    required this.onSortChanged,
    required this.onResize,
    required this.onResizeEnd,
    this.onAutoFit,
    this.onRenameColumn,
    this.onChangeColumnType,
    this.onChangeColumnOptions,
    this.onMoveColumnLeft,
    this.onMoveColumnRight,
    this.onReorderColumn,
    required this.onDeleteColumn,
    required this.onAddColumn,
    this.addPropertyKey,
  });

  @override
  Widget build(BuildContext context) {
    final controller = selectionController;
    if (controller == null) return _build(context, null);
    return ValueListenableBuilder<DatabaseGridRange?>(
      valueListenable: controller,
      builder: (context, range, _) => _build(context, range),
    );
  }

  Widget _buildGutter(BuildContext context, Skin skin) {
    return SizedBox(
      width: DesktopUx.databaseGutterWidth,
      child: selectionController == null
          ? null
          : IconButton(
              key: const Key('database_select_all'),
              tooltip: context.l10n.databaseSelectPage,
              padding: EdgeInsets.zero,
              icon: Icon(
                AppIcons.table,
                size: UiSpace.s14,
                color: skin.muted,
              ),
              onPressed: selectionController!.selectAll,
            ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int i,
    DatabaseGridRange? range,
  ) {
    final col = columns[i];
    final isTitle = col.type == 'title';
    return ResizableColumnHeader(
      key: ValueKey(col.id),
      column: col,
      columnIndex: i,
      selected:
          range != null &&
          range.firstRow == 0 &&
          range.lastRow >= 0 &&
          i >= range.firstColumn &&
          i <= range.lastColumn &&
          (range.mode == DatabaseSelectionMode.columns ||
              range.mode == DatabaseSelectionMode.all),
      onSelect: selectionController == null
          ? null
          : () => selectionController!.selectColumn(
              col.id,
              extend: HardwareKeyboard.instance.isShiftPressed,
            ),
      width: columnWidths[col.id] ?? col.width,
      icon: iconForColumnType(col.type),
      borderColor: borderColor,
      isSorted: sortConfig?.columnId == col.id,
      sortAscending: sortConfig?.ascending ?? true,
      canMoveLeft: !isTitle && i > 1,
      canMoveRight: !isTitle && i < columns.length - 1,
      onMoveLeft: onMoveColumnLeft != null
          ? () => onMoveColumnLeft!(col.id)
          : null,
      onMoveRight: onMoveColumnRight != null
          ? () => onMoveColumnRight!(col.id)
          : null,
      onReorder: onReorderColumn != null
          ? (draggedId) => onReorderColumn!(draggedId, col.id)
          : null,
      onSort: (asc) => onSortChanged(col.id, asc),
      onClearSort: () => onSortChanged(null, true),
      onResize: (w) => onResize(col.id, w),
      onResizeEnd: (w) => onResizeEnd(col.id, w),
      onAutoFit: onAutoFit != null ? () => onAutoFit!(col.id) : null,
      onRename: onRenameColumn != null
          ? (newName) => onRenameColumn!(col.id, newName)
          : null,
      onChangeType: onChangeColumnType != null
          ? (newType) => onChangeColumnType!(col.id, newType)
          : null,
      onOptionsChange: onChangeColumnOptions != null
          ? (newOptions) =>
                onChangeColumnOptions!(col.id, newOptions)
          : null,
      onDelete: isTitle ? null : () => onDeleteColumn(col.id),
    );
  }

  Widget _buildAddButton(BuildContext context, Skin skin) {
    return Tooltip(
      message: context.l10n.databaseAddProperty,
      child: InkWell(
        key: addPropertyKey,
        onTap: onAddColumn,
        child: Container(
          width: UiSpace.s36,
          height: DesktopUx.databaseHeaderHeight,
          alignment: Alignment.center,
          child: Icon(
            AppIcons.plus,
            size: UiSpace.s16,
            color: skin.muted,
          ),
        ),
      ),
    );
  }

  Widget _build(BuildContext context, DatabaseGridRange? range) {
    final skin = context.skin;

    final shouldFreeze = freezeTitle &&
        columns.isNotEmpty &&
        columns.first.type == 'title' &&
        horizontalScrollController != null;

    if (!shouldFreeze) {
      return Container(
        color: headerBg,
        height: DesktopUx.databaseHeaderHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGutter(context, skin),
            for (int i = 0; i < columns.length; i++)
              _buildHeader(context, i, range),
            _buildAddButton(context, skin),
          ],
        ),
      );
    }

    final titleWidth = columnWidths[columns[0].id] ?? columns[0].width;
    final frozenWidth = DesktopUx.databaseGutterWidth + titleWidth;

    return Container(
      color: headerBg,
      height: DesktopUx.databaseHeaderHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: frozenWidth),
              for (int i = 1; i < columns.length; i++)
                _buildHeader(context, i, range),
              _buildAddButton(context, skin),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: DatabaseStickyPane(
              horizontalScrollController: horizontalScrollController,
              width: frozenWidth,
              backgroundColor: headerBg,
              borderColor: borderColor,
              isFrozen: true,
              child: Row(
                children: [
                  _buildGutter(context, skin),
                  _buildHeader(context, 0, range),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnDrag {
  final String id;
  final String databaseId;
  final int index;

  const _ColumnDrag(this.id, this.databaseId, this.index);
}

class ResizableColumnHeader extends StatefulWidget {
  final VoidCallback? onSelect;
  final bool selected;
  final DatabaseColumn column;
  final int columnIndex;
  final double width;
  final IconData icon;
  final Color borderColor;
  final bool isSorted;
  final bool sortAscending;
  final ValueChanged<bool> onSort;
  final VoidCallback onClearSort;
  final ValueChanged<double> onResize;
  final ValueChanged<double> onResizeEnd;
  final VoidCallback? onAutoFit;
  final ValueChanged<String>? onRename;
  final ValueChanged<String>? onChangeType;
  final ValueChanged<String>? onOptionsChange;
  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final ValueChanged<String>? onReorder;
  final VoidCallback? onDelete;

  const ResizableColumnHeader({
    this.onSelect,
    this.selected = false,
    super.key,
    required this.column,
    this.columnIndex = 0,
    required this.width,
    required this.icon,
    required this.borderColor,
    this.isSorted = false,
    this.sortAscending = true,
    required this.onSort,
    required this.onClearSort,
    required this.onResize,
    required this.onResizeEnd,
    this.onAutoFit,
    this.onRename,
    this.onChangeType,
    this.onOptionsChange,
    this.canMoveLeft = false,
    this.canMoveRight = false,
    this.onMoveLeft,
    this.onMoveRight,
    this.onReorder,
    this.onDelete,
  });

  @override
  State<ResizableColumnHeader> createState() => _ResizableColumnHeaderState();
}

class _ResizableColumnHeaderState extends State<ResizableColumnHeader> {
  bool _isHovered = false;
  bool _isHandleHovered = false;
  double? _resizeStartX;
  double? _resizeStartWidth;
  double? _resizeWidth;
  bool _resizing = false;

  double _headerX(Offset globalPosition) =>
      (context.findRenderObject()! as RenderBox)
          .globalToLocal(globalPosition)
          .dx;

  void _resizeTo(Offset globalPosition) {
    final startX = _resizeStartX;
    final startWidth = _resizeStartWidth;
    if (startX == null || startWidth == null) return;
    final minimum = widget.column.type == 'checkbox' ? 60.0 : 115.0;
    // Use the complete displacement, independent of parent rebuild frequency.
    // Local header coordinates also preserve 1:1 movement under a UI transform.
    final width = (startWidth + _headerX(globalPosition) - startX).clamp(
      minimum,
      double.infinity,
    );
    _resizeWidth = width;
    widget.onResize(width);
  }

  void _finishResize() {
    final width = _resizeWidth;
    final commit = _resizing && width != null && width != _resizeStartWidth;
    _resizing = false;
    _resizeStartX = null;
    _resizeStartWidth = null;
    _resizeWidth = null;
    if (commit) widget.onResizeEnd(width);
  }

  void _openColumnMenu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    var deleted = false;
    showDatabasePropertyMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      name: widget.column.name,
      type: widget.column.type,
      options: widget.column.options,
      onRename: widget.onRename,
      onChangeType: widget.onChangeType,
      onOptionsChange: widget.onOptionsChange,
      canCommit: () => !deleted,
      actions: (close) => [
        if (widget.onSelect != null)
          MenuRow(
            label: context.l10n.databaseSelectColumn,
            glyph: AppIcons.table,
            onTap: () {
              close();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.onSelect?.call();
              });
            },
          ),
        if (widget.canMoveLeft)
          MenuRow(
            label: context.l10n.columnMoveLeft,
            glyph: AppIcons.arrowLeft,
            onTap: () {
              close();
              widget.onMoveLeft?.call();
            },
          ),
        if (widget.canMoveRight)
          MenuRow(
            label: context.l10n.columnMoveRight,
            glyph: AppIcons.arrowRight,
            onTap: () {
              close();
              widget.onMoveRight?.call();
            },
          ),
        if (widget.onAutoFit != null)
          MenuRow(
            label: context.l10n.columnAutoFit,
            glyph: AppIcons.arrowLeftRight,
            onTap: () {
              close();
              widget.onAutoFit?.call();
            },
          ),
        MenuRow(
          label: context.l10n.columnSortAscending,
          glyph: AppIcons.arrowUp,
          onTap: () {
            close();
            widget.onSort(true);
          },
        ),
        MenuRow(
          label: context.l10n.columnSortDescending,
          glyph: AppIcons.arrowDown,
          onTap: () {
            close();
            widget.onSort(false);
          },
        ),
        if (widget.isSorted)
          MenuRow(
            label: context.l10n.databaseClearSort,
            glyph: AppIcons.xmark,
            onTap: () {
              close();
              widget.onClearSort();
            },
          ),
        if (widget.onDelete != null) ...[
          const MenuDivider(),
          MenuRow(
            label: context.l10n.columnDelete,
            glyph: AppIcons.trash,
            destructive: true,
            onTap: () {
              deleted = true;
              close();
              widget.onDelete?.call();
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDraggable =
        widget.column.type != 'title' && widget.onReorder != null;

    final baseHeader = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.selected
              ? skin.accentText.withValues(alpha: 0.12)
              : _isHovered
              ? skin.hover
              : null,
        ),
        child: Stack(
          children: [
            // Column Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8),
              child: Builder(
                builder: (headerCtx) => InkWell(
                  onTap: () => _openColumnMenu(headerCtx),
                  child: Row(
                    children: [
                      Tooltip(
                        message: context.l10n.databaseSelectColumn,
                        child: InkWell(
                          key: ValueKey(
                            'database_select_column_${widget.column.id}',
                          ),
                          onTap: widget.onSelect,
                          child: SizedBox(
                            width: UiSpace.s18,
                            height: DesktopUx.databaseHeaderHeight,
                            child: Center(
                              child: widget.column.type == 'title'
                                  ? Text(
                                      'Aa',
                                      style: TextStyle(
                                        fontSize: UiType.body,
                                        color: skin.muted,
                                      ),
                                    )
                                  : Icon(
                                      widget.icon,
                                      size: UiSpace.s14,
                                      color: skin.muted,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: UiSpace.s6),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: widget.column.name,
                                waitDuration: const Duration(milliseconds: 500),
                                child: Text(
                                  widget.column.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: UiType.body,
                                    fontWeight: FontWeight.w400,
                                    color: skin.muted,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.isSorted) ...[
                              const SizedBox(width: UiSpace.s4),
                              Icon(
                                widget.sortAscending
                                    ? AppIcons.arrowUp
                                    : AppIcons.arrowDown,
                                size: UiSpace.s14,
                                color: Palette.accent,
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        curve: Motion.curve,
                        duration: Motion.of(context, Motion.micro),
                        opacity: (_isHovered || widget.isSorted) ? 1.0 : 0.0,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: SizedBox(
                            width: UiSpace.s16,
                            height: UiSpace.s16,
                            child: Icon(
                              AppIcons.ellipsis,
                              size: UiSpace.s14,
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
            // Drag-to-resize handle on right edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: UiSpace.s8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                onEnter: (_) => setState(() => _isHandleHovered = true),
                onExit: (_) => setState(() => _isHandleHovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: widget.onAutoFit,
                  onHorizontalDragDown: (details) {
                    _resizeStartX = _headerX(details.globalPosition);
                    _resizeStartWidth = widget.width;
                    _resizeWidth = null;
                  },
                  onHorizontalDragStart: (details) {
                    _resizing = true;
                    _resizeTo(details.globalPosition);
                  },
                  onHorizontalDragUpdate: (details) =>
                      _resizeTo(details.globalPosition),
                  onHorizontalDragEnd: (_) => _finishResize(),
                  onHorizontalDragCancel: _finishResize,
                  child: Center(
                    child: Container(
                      width: UiSpace.s2_5,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: _isHandleHovered
                            ? Palette.accent
                            : Palette.transparent,
                        borderRadius: BorderRadius.circular(UiRadius.handle),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isDraggable) return baseHeader;

    return DragTarget<_ColumnDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.id != widget.column.id &&
          details.data.databaseId == widget.column.databaseId,
      onAcceptWithDetails: (details) {
        widget.onReorder?.call(details.data.id);
      },
      builder: (context, candidateData, rejectedData) {
        final dragged = candidateData.firstOrNull;
        // The repository moves to the target's original index: after it when
        // moving right, before it when moving left.
        final insertAfter =
            dragged != null && dragged.index < widget.columnIndex;
        return Draggable<_ColumnDrag>(
          data: _ColumnDrag(
            widget.column.id,
            widget.column.databaseId,
            widget.columnIndex,
          ),
          axis: Axis.horizontal,
          maxSimultaneousDrags: 1,
          dragAnchorStrategy: childDragAnchorStrategy,
          feedback: Material(
            key: ValueKey('database_column_drag_${widget.column.id}'),
            color: Palette.transparent,
            child: Container(
              width: widget.width,
              height: DesktopUx.databaseHeaderHeight,
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8),
              decoration: BoxDecoration(
                color: skin.surface,
                borderRadius: BorderRadius.circular(UiRadius.small),
                border: Border.all(
                  color: skin.accentText.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: skin.shadow,
                    blurRadius: UiSpace.s12,
                    offset: const Offset(0, UiSpace.s4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: UiSpace.s14, color: skin.muted),
                  const SizedBox(width: UiSpace.s10),
                  Expanded(
                    child: Text(
                      widget.column.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.body,
                        fontWeight: FontWeight.w400,
                        color: skin.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: IgnorePointer(
            child: Opacity(opacity: 0.35, child: baseHeader),
          ),
          child: Stack(
            children: [
              baseHeader,
              if (dragged != null)
                Positioned(
                  left: insertAfter ? null : 0,
                  right: insertAfter ? 0 : null,
                  top: 0,
                  bottom: 0,
                  width: UiSpace.s3,
                  child: IgnorePointer(
                    child: ColoredBox(
                      key: ValueKey('database_column_drop_${widget.column.id}'),
                      color: skin.accentText,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

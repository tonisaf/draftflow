import 'database_grid_navigation.dart';

import '../../../../services/database_cell_saves.dart';
import '../../../common/app_icons.dart';

import 'package:flutter/material.dart' hide Page, DataCell;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_cells.dart';

// ----------------------------------------------------------------------------
// Data Row View
// ----------------------------------------------------------------------------

class DataRowView extends StatefulWidget {
  final DatabaseCellSaves? saves;
  final int? rowIndex;
  final Page page;
  final Map<String, dynamic>? properties;
  final List<DatabaseColumn> columns;
  final Map<String, double> columnWidths;
  final Color borderColor;
  final bool isEven;
  final NotesRepository repository;
  final VoidCallback onOpenPage;
  final ValueChanged<String> onUpdateTitle;
  final ValueChanged<Map<String, dynamic>> onPatchProperties;
  final VoidCallback onDeleteRow;

  const DataRowView({
    super.key,
    this.saves,
    this.rowIndex,
    required this.page,
    this.properties,
    required this.columns,
    required this.columnWidths,
    required this.borderColor,
    required this.isEven,
    required this.repository,
    required this.onOpenPage,
    required this.onUpdateTitle,
    required this.onPatchProperties,
    required this.onDeleteRow,
  });

  @override
  State<DataRowView> createState() => _DataRowViewState();
}

class _DataRowViewState extends State<DataRowView> {
  bool _isHovered = false;

  late Map<String, dynamic> _properties =
      widget.properties ?? decodeRowProperties(widget.page.properties);

  @override
  void didUpdateWidget(DataRowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.properties != widget.page.properties ||
        oldWidget.properties != widget.properties) {
      _properties =
          widget.properties ?? decodeRowProperties(widget.page.properties);
    }
  }

  void _setProperty(String key, dynamic val) {
    widget.onPatchProperties({key: val});
  }

  @override
  Widget build(BuildContext context) {
    final navigation = DatabaseGridScope.maybeOf(context);
    final skin = context.skin;
    final thinBorderColor = widget.borderColor;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          height: DesktopUx.databaseRowHeight,
        decoration: BoxDecoration(
          color: _isHovered ? skin.hover : Palette.transparent,
          border: Border(
            bottom: BorderSide(color: thinBorderColor, width: UiSpace.s0_8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quiet gutter: a real open action, not a decorative drag affordance.
            SizedBox(
              width: DesktopUx.databaseGutterWidth,
              child: navigation == null
                  ? IconButton(
                      tooltip: context.l10n.rowOpenAsPage,
                      onPressed: widget.onOpenPage,
                      icon: const Icon(
                        AppIcons.arrowUpRightSquare,
                        size: UiSpace.s14,
                      ),
                    )
                  : ValueListenableBuilder<DatabaseGridRange?>(
                      valueListenable: navigation.selection,
                      builder: (context, range, _) => Semantics(
                        button: true,
                        label: context.l10n.databaseSelectRow,
                        onTap: () =>
                            navigation.selectRow(widget.page.id, false),
                        onLongPress: widget.onOpenPage,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            onDoubleTap: widget.onOpenPage,
                            child: IconButton(
                              key: ValueKey(
                                'database_select_row_${widget.page.id}',
                              ),
                              tooltip: context.l10n.databaseSelectRow,
                              onPressed: navigation.focus,
                              iconSize: UiSpace.s14,
                              padding: EdgeInsets.zero,
                              style: ButtonStyle(
                                foregroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) =>
                                          navigation.isRowSelected(
                                                widget.page.id,
                                              ) ||
                                              _isHovered ||
                                              states.contains(
                                                WidgetState.focused,
                                              )
                                          ? skin.muted
                                          : Palette.transparent,
                                    ),
                              ),
                              icon: Icon(
                                navigation.isRowSelected(widget.page.id)
                                    ? AppIcons.checkmarkSquare
                                    : AppIcons.square,
                                size: UiSpace.s14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // Cells
            for (final col in widget.columns) ...[
              DataCell(
                saves: widget.saves,
                rowId: widget.page.id,
                key: ValueKey(col.id),
                column: col,
                width: widget.columnWidths[col.id] ?? col.width,
                borderColor: widget.borderColor,
                pageTitle: widget.page.title,
                cellValue: _properties[col.id],
                repository: widget.repository,
                onUpdateTitle: widget.onUpdateTitle,
                onUpdateValue: (val) => _setProperty(col.id, val),
                onOpenPage: widget.onOpenPage,
              ),
            ],
            SizedBox(
              width: DesktopUx.databaseActionWidth,
              child: IconButton(
                tooltip: context.l10n.rowMoveToTrash,
                onPressed: widget.onDeleteRow,
                iconSize: UiSpace.s14,
                padding: EdgeInsets.zero,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        _isHovered || states.contains(WidgetState.focused)
                        ? skin.destructive
                        : Palette.transparent,
                  ),
                ),
                icon: const Icon(AppIcons.xmark, size: UiSpace.s14),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

// ----------------------------------------------------------------------------
// Bottom '+ New row' Button
// ----------------------------------------------------------------------------

class BottomAddRowButton extends StatelessWidget {
  const BottomAddRowButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TextButton.icon(
      key: const Key('database_add_row_button'),
      onPressed: onTap,
      style:
          TextButton.styleFrom(
            foregroundColor: skin.muted,
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s4),
            minimumSize: const Size(0, UiSpace.s28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
            ),
            textStyle: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: UiType.body, fontWeight: FontWeight.w400),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                  ? skin.hover
                  : Palette.transparent,
            ),
          ),
      icon: const Icon(AppIcons.plus, size: UiSpace.s16),
      label: Text(
        context.l10n.newPage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

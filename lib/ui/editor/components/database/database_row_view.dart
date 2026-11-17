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
import 'database_sticky_pane.dart';

// ----------------------------------------------------------------------------
// Data Row View
// ----------------------------------------------------------------------------

class DataRowView extends StatefulWidget {
  final DatabaseCellSaves? saves;
  final ScrollController? horizontalScrollController;
  final bool freezeTitle;
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
    this.horizontalScrollController,
    this.freezeTitle = true,
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

  Widget _buildGutter(
    BuildContext context,
    Skin skin,
    DatabaseGridNavigation? navigation,
  ) {
    return SizedBox(
      width: DesktopUx.databaseGutterWidth,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: UiSpace.s6),
          child: navigation == null
              ? IconButton(
                  tooltip: context.l10n.rowOpenAsPage,
                  onPressed: widget.onOpenPage,
                  constraints: const BoxConstraints(
                    minWidth: UiSpace.s20,
                    minHeight: UiSpace.s20,
                  ),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(UiSpace.s20, UiSpace.s20),
                    padding: EdgeInsets.zero,
                  ),
                  padding: EdgeInsets.zero,
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
                          constraints: const BoxConstraints(
                            minWidth: UiSpace.s20,
                            minHeight: UiSpace.s20,
                          ),
                          iconSize: UiSpace.s14,
                          padding: EdgeInsets.zero,
                          style: ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const WidgetStatePropertyAll(
                              Size(UiSpace.s20, UiSpace.s20),
                            ),
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
      ),
    );
  }

  Widget _buildCell(DatabaseColumn col, {bool transparentBorder = false}) {
    return DataCell(
      saves: widget.saves,
      rowId: widget.page.id,
      key: ValueKey(col.id),
      column: col,
      width: widget.columnWidths[col.id] ?? col.width,
      borderColor: transparentBorder ? Palette.transparent : widget.borderColor,
      pageTitle: widget.page.title,
      cellValue: _properties[col.id],
      repository: widget.repository,
      onUpdateTitle: widget.onUpdateTitle,
      onUpdateValue: (val) => _setProperty(col.id, val),
      onOpenPage: widget.onOpenPage,
    );
  }

  Widget _buildAction(BuildContext context, Skin skin) {
    return SizedBox(
      width: DesktopUx.databaseActionWidth,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: UiSpace.s6),
          child: IconButton(
            tooltip: context.l10n.rowMoveToTrash,
            onPressed: widget.onDeleteRow,
            constraints: const BoxConstraints(
              minWidth: UiSpace.s20,
              minHeight: UiSpace.s20,
            ),
            iconSize: UiSpace.s14,
            padding: EdgeInsets.zero,
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const WidgetStatePropertyAll(
                Size(UiSpace.s20, UiSpace.s20),
              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigation = DatabaseGridScope.maybeOf(context);
    final skin = context.skin;
    final thinBorderColor = widget.borderColor;

    final shouldFreeze = widget.freezeTitle &&
        widget.columns.isNotEmpty &&
        widget.columns.first.type == 'title' &&
        widget.horizontalScrollController != null;

    if (!shouldFreeze) {
      return RepaintBoundary(
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: DesktopUx.databaseRowHeight,
            ),
            decoration: BoxDecoration(
              color: _isHovered ? skin.hover : Palette.transparent,
              border: Border(
                bottom: BorderSide(color: thinBorderColor, width: UiSpace.s0_8),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGutter(context, skin, navigation),
                  for (final col in widget.columns)
                    _buildCell(col),
                  _buildAction(context, skin),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final titleWidth =
        widget.columnWidths[widget.columns[0].id] ?? widget.columns[0].width;
    final frozenWidth = DesktopUx.databaseGutterWidth + titleWidth;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: DesktopUx.databaseRowHeight,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? skin.hover : Palette.transparent,
            border: Border(
              bottom: BorderSide(color: thinBorderColor, width: UiSpace.s0_8),
            ),
          ),
          child: IntrinsicHeight(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: frozenWidth),
                    for (int i = 1; i < widget.columns.length; i++)
                      _buildCell(widget.columns[i]),
                    _buildAction(context, skin),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: DatabaseStickyPane(
                    horizontalScrollController: widget.horizontalScrollController,
                    width: frozenWidth,
                    backgroundColor: _isHovered ? skin.hover : skin.surface,
                    borderColor: thinBorderColor,
                    isFrozen: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGutter(context, skin, navigation),
                        _buildCell(widget.columns[0], transparentBorder: true),
                      ],
                    ),
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

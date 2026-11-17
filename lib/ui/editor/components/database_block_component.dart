import '../../common/app_dialog.dart';
import '../../common/smooth_wheel_region.dart';
import 'database/database_grid_navigation.dart';
import '../../../services/database_range_edits.dart';
import '../../../services/database_cell_saves.dart';
import 'database/database_save_status.dart';
import 'database/database_grid_selection.dart';
import '../../common/app_icons.dart';

import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart' hide Page, DataCell;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:provider/provider.dart';

import '../../../data/model/database_initial_data.dart';
import '../../../l10n/locale_controller.dart';

// Export all database subcomponents for backward-compatibility
export 'database/database_models.dart';
export 'database/database_dialogs.dart';
export 'database/database_header.dart';
export 'database/database_columns_header.dart';
export 'database/database_cells.dart';
export 'database/database_row_modal.dart';
export 'database/database_summary_row.dart';

import 'database/database_models.dart';
import 'database/database_header.dart';
import 'database/database_columns_header.dart';
import 'database/database_cells.dart';
import 'database/database_row_modal.dart';
import 'database/database_property_menu.dart';
import 'database/database_summary_row.dart';

/// Reuse adjacent editable text instead of accumulating empty paragraphs.
Future<void> insertTextAroundDatabase(
  EditorState state,
  Node database, {
  required bool before,
}) async {
  final siblings = database.parent?.children ?? state.document.root.children;
  final index = siblings.indexOf(database);
  if (index < 0) return;
  final adjacentIndex = before ? index - 1 : index + 1;
  final adjacent = adjacentIndex >= 0 && adjacentIndex < siblings.length
      ? siblings[adjacentIndex]
      : null;
  if (adjacent?.delta != null) {
    state.selection = Selection.collapsed(
      Position(
        path: adjacent!.path,
        offset: before ? adjacent.delta!.toPlainText().length : 0,
      ),
    );
    return;
  }
  final path = before ? database.path : database.path.next;
  final transaction = state.transaction;
  transaction.insertNode(path, paragraphNode());
  transaction.afterSelection = Selection.collapsed(Position(path: path));
  await state.apply(transaction);
}

// ----------------------------------------------------------------------------
// Database Block Component Builder & Widget
// ----------------------------------------------------------------------------

class DatabaseBlockComponentBuilder extends BlockComponentBuilder {
  final Map<String, DatabaseInitialData> initialData;
  final NotesRepository repository;
  final ValueChanged<String>? onNavigateToPage;

  DatabaseBlockComponentBuilder({
    required this.repository,
    this.onNavigateToPage,
    this.initialData = const {},
    super.configuration,
  });

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return DatabaseBlockComponentWidget(
      key: node.key,
      node: node,
      repository: repository,
      initialData: initialData[node.attributes['databaseId']],
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
      (node) => node.attributes['databaseId'] != null;
}

class DatabaseBlockComponentWidget extends BlockComponentStatefulWidget {
  final DatabaseInitialData? initialData;
  final NotesRepository repository;
  final ValueChanged<String>? onNavigateToPage;

  const DatabaseBlockComponentWidget({
    super.key,
    required super.node,
    required this.repository,
    this.onNavigateToPage,
    this.initialData,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<DatabaseBlockComponentWidget> createState() =>
      _DatabaseBlockComponentWidgetState();
}

class _DatabaseBlockComponentWidgetState
    extends State<DatabaseBlockComponentWidget>
    with
        SelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: databaseBlockType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  DatabaseCellSaves get _cellSaves =>
      DatabaseCellSaves.forRepository(widget.repository);

  String get _databaseId => widget.node.attributes['databaseId'] as String;

  final Map<String, double> _columnWidths = {};
  final GlobalKey _addPropertyKey = GlobalKey();
  final ScrollController _horizontalScrollController = ScrollController();

  DatabaseSortConfig? _sortConfig;
  final List<DatabaseFilterRule> _filterRules = [];
  String _searchQuery = '';
  String _appliedSearch = '';
  int _offset = 0;
  Timer? _searchTimer;
  final ScrollController _rowsScrollController = ScrollController();
  final _gridSelection = DatabaseGridSelectionController();
  Stream<Database?>? _databaseStream;
  Stream<List<DatabaseColumn>>? _columnsStream;
  Stream<DatabaseRowsPage>? _rowsStream;
  String? _streamDatabaseId;
  Object? _streamRepository;
  String? _querySignature;
  String? _summarySignature;
  Stream<Map<String, DatabaseSummaryStats>>? _summaryStream;
  final Map<String, String> _localSummaries = {};

  Map<String, String> get _summaries {
    final raw = widget.node.attributes['summaries'];
    if (raw is Map) {
      return {
        ..._localSummaries,
        for (final entry in raw.entries)
          entry.key.toString(): entry.value.toString(),
      };
    }
    return _localSummaries;
  }

  void _setColumnSummary(String columnId, String? summaryType) {
    setState(() {
      if (summaryType == null) {
        _localSummaries.remove(columnId);
      } else {
        _localSummaries[columnId] = summaryType;
      }
    });
    try {
      final current = Map<String, dynamic>.from(
        widget.node.attributes['summaries'] as Map? ?? {},
      );
      if (summaryType == null) {
        current.remove(columnId);
      } else {
        current[columnId] = summaryType;
      }
      final transaction = editorState.transaction;
      transaction.updateNode(widget.node, {'summaries': current});
      editorState.apply(transaction);
    } catch (_) {}
  }

  void _resetPage() {
    _offset = 0;
    if (_rowsScrollController.hasClients) _rowsScrollController.jumpTo(0);
  }

  void _searchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchTimer?.cancel();
    _searchTimer = Timer(DatabaseQueryPolicy.searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _appliedSearch = value;
        _resetPage();
      });
    });
  }

  void _ensureSummaryStream(List<DatabaseColumn> columns) {
    final active = _summaries.entries
        .where((entry) => entry.value != 'none')
        .map((entry) => entry.key)
        .toSet();
    final signature = jsonEncode([
      _databaseId,
      _appliedSearch,
      for (final rule in _filterRules)
        [rule.columnId, rule.operator, rule.value],
      for (final col in columns)
        [col.id, col.type, col.options, active.contains(col.id)],
    ]);
    if (_summarySignature == signature) return;
    _summarySignature = signature;
    final source = widget.repository.watchDatabaseSummaryGroups(
      _databaseId,
      active,
      filters: List.unmodifiable(_filterRules),
      search: _appliedSearch,
    );
    final formats = {
      for (final col in columns)
        col.id: NumberColumnConfig.fromOptions(col.options).format,
    };
    _summaryStream = source.asyncMap(
      (groups) => calculateDatabaseSummaryStats(groups, formats: formats),
    );
  }

  void _ensureStreams(List<DatabaseColumn> columns) {
    final signature = jsonEncode([
      _databaseId,
      _offset,
      _appliedSearch,
      _sortConfig?.columnId,
      _sortConfig?.ascending,
      for (final rule in _filterRules)
        [rule.columnId, rule.operator, rule.value],
      for (final col in columns) [col.id, col.type],
    ]);
    if (_rowsStream == null || signature != _querySignature) {
      _querySignature = signature;
      _rowsStream = widget.repository.watchDatabaseRowsPage(
        _databaseId,
        sort: _sortConfig,
        filters: List.unmodifiable(_filterRules),
        search: _appliedSearch,
        offset: _offset,
      );
    }
  }

  void _setSort(String? columnId, bool ascending) {
    setState(() {
      _resetPage();
      if (columnId == null) {
        _sortConfig = null;
      } else {
        _sortConfig = DatabaseSortConfig(
          columnId: columnId,
          ascending: ascending,
        );
      }
    });
  }

  void _addFilter(DatabaseFilterRule rule) {
    setState(() {
      _resetPage();
      _filterRules.removeWhere((r) => r.columnId == rule.columnId);
      _filterRules.add(rule);
    });
  }

  void _removeFilter(String columnId) {
    setState(() {
      _resetPage();
      _filterRules.removeWhere((r) => r.columnId == columnId);
    });
  }

  void _clearFilters() {
    setState(() {
      _resetPage();
      _searchTimer?.cancel();
      _filterRules.clear();
      _searchQuery = '';
      _appliedSearch = '';
    });
  }

  void _changePage(int offset) {
    setState(() {
      if (_rowsScrollController.hasClients) _rowsScrollController.jumpTo(0);
      _offset = offset;
    });
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
    final box = blockComponentKey.currentContext?.findRenderObject();
    if (box is RenderBox) {
      return Offset.zero & box.size;
    }
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return Rect.fromLTWH(0, 0, box.size.width, box.size.height);
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return [];
    return [Offset.zero & box.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.localToGlobal(offset) ?? offset;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _gridSelection.dispose();
    _rowsScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _createRow() async {
    await widget.repository.createDatabaseRow(_databaseId, title: '');
  }

  void _openRowModal(Page page, List<DatabaseColumn> columns) {
    showAppDialog(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: context.skin.scrim,
      barrierDismissible: true,
      builder: (ctx) => DatabaseRowModal(
        repository: widget.repository,
        databaseId: _databaseId,
        page: page,
        columns: columns,
        onNavigateToPage: (pageId) {
          widget.onNavigateToPage?.call(pageId);
        },
      ),
    );
  }

  void _showAddColumn() {
    final box =
        (_addPropertyKey.currentContext ?? context).findRenderObject()
            as RenderBox?;
    if (box == null) return;
    showDatabasePropertyMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      name: 'New Column',
      type: 'text',
      onAdd: (name, type, {options}) async {
        await widget.repository.addColumn(
          _databaseId,
          name: name,
          type: type,
          options: options,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    if (_streamDatabaseId != _databaseId ||
        _streamRepository != widget.repository) {
      _streamDatabaseId = _databaseId;
      _streamRepository = widget.repository;
      _databaseStream = widget.repository.watchDatabase(_databaseId);
      _columnsStream = widget.repository.watchColumns(_databaseId);
      _rowsStream = null;
      _offset = 0;
    }
    final borderColor = skin.tableDivider;
    const headerBg = Palette.transparent;

    Widget child = StreamBuilder<Database?>(
      initialData: widget.initialData?.database,
      stream: _databaseStream,
      builder: (context, dbSnap) {
        if (dbSnap.hasError) return _tableLoadError();
        final database = dbSnap.data;
        if (database == null) {
          return widget.initialData != null ||
                  dbSnap.connectionState == ConnectionState.active
              ? const SizedBox.shrink()
              : _loadingTable();
        }
        if (database.trashedAt != null) return const SizedBox.shrink();
        final dbTitle = database.title;

        return StreamBuilder<List<DatabaseColumn>>(
          initialData: widget.initialData?.columns,
          stream: _columnsStream,
          builder: (context, colSnap) {
            if (colSnap.hasError) return _tableLoadError();
            if (!colSnap.hasData) return _loadingTable();
            final columns = colSnap.data!;

            _ensureStreams(columns);
            _ensureSummaryStream(columns);
            return StreamBuilder<DatabaseRowsPage>(
              initialData: widget.initialData?.rows,
              stream: _rowsStream,
              builder: (context, rowSnap) {
                final result = rowSnap.data;
                if (result == null && rowSnap.hasError) {
                  return _tableLoadError();
                }
                if (result == null && !rowSnap.hasError) return _loadingTable();
                final data = result?.rows ?? <DatabaseRowData>[];
                final displayRows = data.map((row) => row.page).toList();
                final rowOffset = result?.offset ?? _offset;
                final tableWidth =
                    DesktopUx.databaseGutterWidth +
                    DesktopUx.databaseActionWidth +
                    columns.fold<double>(
                      0,
                      (width, col) =>
                          width + (_columnWidths[col.id] ?? col.width),
                    );
                return RepaintBoundary(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tableWidth),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: UiSpace.s12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Header Bar
                          DatabaseHeader(
                            title: dbTitle,
                            totalRowCount: result?.totalCount ?? 0,
                            filteredRowCount: result?.filteredCount ?? 0,
                            columns: columns,
                            sortConfig: _sortConfig,
                            filterRules: _filterRules,
                            searchQuery: _searchQuery,
                            onSortChanged: _setSort,
                            onAddFilter: _addFilter,
                            onRemoveFilter: _removeFilter,
                            onClearFilters: _clearFilters,
                            onSearchChanged: _searchChanged,
                            onAddRow: _createRow,
                            onAddColumn: _showAddColumn,
                            onTitleChanged: (newTitle) {
                              widget.repository.updateDatabaseTitle(
                                _databaseId,
                                newTitle,
                              );
                            },
                          ),
                          // Horizontally Scrollable Table
                          Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: false,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: SmoothWheelRegion(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: UiLayout.tableMinWidth,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Column Headers
                                      ColumnsHeaderRow(
                                        selectionController: _gridSelection,
                                        addPropertyKey: _addPropertyKey,
                                        columns: columns,
                                        columnWidths: _columnWidths,
                                        headerBg: headerBg,
                                        borderColor: borderColor,
                                        sortConfig: _sortConfig,
                                        onSortChanged: _setSort,
                                        onResize: (colId, newWidth) {
                                          setState(() {
                                            _columnWidths[colId] = newWidth;
                                          });
                                        },
                                        onResizeEnd: (colId, width) {
                                          widget.repository.updateColumn(
                                            colId,
                                            width: width,
                                          );
                                        },
                                        onRenameColumn: (colId, newName) {
                                          widget.repository.updateColumn(
                                            colId,
                                            name: newName,
                                          );
                                        },
                                        onChangeColumnType: (colId, newType) {
                                          widget.repository.updateColumn(
                                            colId,
                                            type: newType,
                                          );
                                        },
                                        onChangeColumnOptions:
                                            (colId, newOptions) {
                                              widget.repository.updateColumn(
                                                colId,
                                                options: newOptions,
                                              );
                                            },
                                        onMoveColumnLeft: (colId) {
                                          widget.repository.moveColumnDirection(
                                            databaseId: _databaseId,
                                            columnId: colId,
                                            moveLeft: true,
                                          );
                                        },
                                        onMoveColumnRight: (colId) {
                                          widget.repository.moveColumnDirection(
                                            databaseId: _databaseId,
                                            columnId: colId,
                                            moveLeft: false,
                                          );
                                        },
                                        onReorderColumn:
                                            (draggedColId, targetColId) {
                                              if (draggedColId == targetColId) {
                                                return;
                                              }
                                              final targetIndex = columns
                                                  .indexWhere(
                                                    (c) => c.id == targetColId,
                                                  );
                                              if (targetIndex <= 0) return;
                                              widget.repository.reorderColumn(
                                                databaseId: _databaseId,
                                                columnId: draggedColId,
                                                targetIndex: targetIndex,
                                              );
                                            },
                                        onDeleteColumn: (colId) {
                                          widget.repository.deleteColumn(colId);
                                        },
                                        onAddColumn: _showAddColumn,
                                      ),
                                      Divider(
                                        height: 1,
                                        thickness: UiSpace.s0_8,
                                        color: borderColor,
                                      ),

                                      // Fixed viewport: only visible rows (and focused inputs) mount.
                                      if (rowSnap.hasError)
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _rowsStream = null,
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: skin.destructive,
                                          ),
                                          child: Text(
                                            context.l10n.databaseLoadError,
                                          ),
                                        ),
                                      if (result == null && !rowSnap.hasError)
                                        SizedBox(
                                          width: tableWidth,
                                          child: TickerMode(
                                            enabled:
                                                !MediaQuery.disableAnimationsOf(
                                                  context,
                                                ),
                                            child: LinearProgressIndicator(
                                              color: Palette.accent,
                                              backgroundColor: skin.hover,
                                            ),
                                          ),
                                        ),
                                      SizedBox(
                                        width: tableWidth,
                                        height:
                                            displayRows.length.clamp(
                                              0,
                                              DesktopUx.databaseVisibleRows,
                                            ) *
                                            DesktopUx.databaseRowHeight,
                                        child: DatabaseGridSelection(
                                          controller: _gridSelection,
                                          rangeEdits:
                                              DatabaseRangeEdits.forRepository(
                                                widget.repository,
                                              ),
                                          saves: _cellSaves,
                                          horizontalScrollController:
                                              _horizontalScrollController,
                                          columns: columns,
                                          widths: _columnWidths,
                                          rows: data,
                                          scrollController:
                                              _rowsScrollController,
                                          child: ListView.builder(
                                            key: const Key(
                                              'database_rows_viewport',
                                            ),
                                            controller: _rowsScrollController,
                                            primary: false,
                                            itemExtent:
                                                DesktopUx.databaseRowHeight,
                                            itemCount: displayRows.length,
                                            findChildIndexCallback: (key) {
                                              final index = displayRows
                                                  .indexWhere(
                                                    (row) =>
                                                        ValueKey(row.id) == key,
                                                  );
                                              return index < 0 ? null : index;
                                            },
                                            itemBuilder: (context, i) {
                                              return SmoothWheelRegion(
                                                key: ValueKey(
                                                  displayRows[i].id,
                                                ),
                                                child: DataRowView(
                                                  saves: _cellSaves,
                                                  key: ValueKey(
                                                    displayRows[i].id,
                                                  ),
                                                  rowIndex: rowOffset + i + 1,
                                                  page: displayRows[i],
                                                  properties:
                                                      data[i].properties,
                                                  columns: columns,
                                                  columnWidths: _columnWidths,
                                                  borderColor: borderColor,
                                                  isEven: i % 2 == 0,
                                                  repository: widget.repository,
                                                  onOpenPage: () {
                                                    _openRowModal(
                                                      displayRows[i],
                                                      columns,
                                                    );
                                                  },
                                                  onUpdateTitle: (newTitle) {
                                                    widget.repository
                                                        .updateRowTitle(
                                                          displayRows[i].id,
                                                          newTitle,
                                                        );
                                                  },
                                                  onPatchProperties: (changes) {
                                                    patchRowPropertiesFromCell(
                                                      context,
                                                      widget.repository,
                                                      displayRows[i].id,
                                                      changes,
                                                    );
                                                  },
                                                  onDeleteRow: () {
                                                    widget.repository
                                                        .deleteDatabaseRow(
                                                          displayRows[i].id,
                                                        );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      StreamBuilder<
                                        Map<String, DatabaseSummaryStats>
                                      >(
                                        key: ValueKey(_summarySignature),
                                        stream: _summaryStream,
                                        builder: (context, summary) =>
                                            TableSummaryRow(
                                              stats: summary.data,
                                              loading:
                                                  !summary.hasData &&
                                                  !summary.hasError,
                                              error: summary.hasError,
                                              key: const Key(
                                                'database_add_row',
                                              ),
                                              onAddRow: _createRow,
                                              columns: columns,
                                              columnWidths: _columnWidths,
                                              borderColor: borderColor,
                                              rows: data,
                                              summaries: _summaries,
                                              onSummaryChanged:
                                                  _setColumnSummary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: UiSpace.s6,
                              bottom: UiSpace.s6,
                              right: UiSpace.s8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: UiSpace.s12,
                                    runSpacing: UiSpace.s4,
                                    children: [
                                      DatabaseSaveStatus(
                                        saves: _cellSaves,
                                        databaseId: _databaseId,
                                      ),
                                      DatabaseSelectionStatus(
                                        controller: _gridSelection,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: UiSpace.s8),
                                Text(
                                  _filterRules.isNotEmpty ||
                                          _searchQuery.isNotEmpty
                                      ? context.l10n.databaseFilteredItemsCount(
                                          result?.filteredCount ?? 0,
                                          result?.totalCount ?? 0,
                                        )
                                      : context.l10n.databaseItemsCount(
                                          result?.totalCount ?? 0,
                                        ),
                                  style: TextStyle(
                                    fontSize: UiType.caption,
                                    color: skin.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (result != null &&
                              result.filteredCount > result.limit)
                            Padding(
                              padding: const EdgeInsets.all(DesktopUx.spacing),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: context.l10n.databasePreviousRows,
                                    color: skin.accentText,
                                    onPressed: rowOffset == 0
                                        ? null
                                        : () => _changePage(
                                            rowOffset - result.limit,
                                          ),
                                    icon: const Icon(
                                      AppIcons.chevronLeft,
                                      size: UiSpace.s14,
                                    ),
                                  ),
                                  Text(
                                    context.l10n.databasePageRange(
                                      rowOffset + 1,
                                      rowOffset + displayRows.length,
                                      result.filteredCount,
                                    ),
                                    style: TextStyle(
                                      color: skin.muted,
                                      fontSize: DesktopUx.captionSize,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.l10n.databaseNextRows,
                                    color: skin.accentText,
                                    onPressed:
                                        rowOffset + result.limit >=
                                            result.filteredCount
                                        ? null
                                        : () => _changePage(
                                            rowOffset + result.limit,
                                          ),
                                    icon: const Icon(
                                      AppIcons.chevronRight,
                                      size: UiSpace.s14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ));
              },
            );
          },
        );
      },
    );

    child = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DatabaseTextTarget(
          before: true,
          onTap: () =>
              insertTextAroundDatabase(editorState, node, before: true),
        ),
        child,
        _DatabaseTextTarget(
          before: false,
          onTap: () =>
              insertTextAroundDatabase(editorState, node, before: false),
        ),
      ],
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

  Widget _loadingTable() => SizedBox(
    height: DesktopUx.databaseLoadingHeight,
    child: Center(
      child: Text(
        context.l10n.loadingTable,
        style: TextStyle(fontSize: UiType.body, color: context.skin.muted),
      ),
    ),
  );

  Widget _tableLoadError() => SizedBox(
    height: DesktopUx.databaseLoadingHeight,
    child: Center(
      child: TextButton(
        onPressed: () => setState(() => _streamRepository = null),
        child: Text(context.l10n.couldNotLoadTable),
      ),
    ),
  );
}

class _DatabaseTextTarget extends StatefulWidget {
  const _DatabaseTextTarget({required this.before, required this.onTap});
  final bool before;
  final VoidCallback onTap;
  @override
  State<_DatabaseTextTarget> createState() => _DatabaseTextTargetState();
}

class _DatabaseTextTargetState extends State<_DatabaseTextTarget> {
  bool _active = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.text,
    onEnter: (_) => setState(() => _active = true),
    onExit: (_) => setState(() => _active = false),
    child: InkWell(
      key: ValueKey(
        widget.before ? 'database_text_before' : 'database_text_after',
      ),
      onTap: widget.onTap,
      onFocusChange: (focus) => setState(() => _active = focus),
      child: SizedBox(
        height: widget.before ? UiSpace.s24 : UiSpace.s44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.before
                ? context.l10n.databaseAddTextAbove
                : context.l10n.databaseAddTextBelow,
            style: TextStyle(
              fontSize: UiType.body,
              color: _active ? context.skin.hint : Palette.transparent,
            ),
          ),
        ),
      ),
    ),
  );
}

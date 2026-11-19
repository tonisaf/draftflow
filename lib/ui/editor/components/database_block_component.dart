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
import 'package:flutter/foundation.dart';
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
export 'database/database_autofit.dart';
export 'database/database_views.dart';
export 'database/database_view_tabs.dart';

import 'database/database_models.dart';
import 'database/database_header.dart';
import 'database/database_columns_header.dart';
import 'database/database_cells.dart';
import 'database/database_row_modal.dart';
import 'database/database_property_menu.dart';
import 'database/database_summary_row.dart';
import 'database/database_autofit.dart';
import 'database/database_views.dart';
import 'database/database_view_tabs.dart';

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

  @override
  void initState() {
    super.initState();
    final view = _activeView;
    _sortConfig = view.sort;
    _filterRules.addAll(view.filters);
  }
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

  bool get _freezeTitle =>
      widget.node.attributes['freezeTitle'] as bool? ?? true;

  List<DatabaseViewConfig> get _views {
    final parsed = parseDatabaseViews(widget.node.attributes['views']);
    if (parsed.isNotEmpty) return parsed;
    return const [
      DatabaseViewConfig(
        id: 'view_default',
        name: 'Table',
        type: DatabaseViewType.table,
      ),
    ];
  }

  String get _activeViewId {
    final id = widget.node.attributes['activeViewId'] as String?;
    final views = _views;
    if (id != null && views.any((v) => v.id == id)) return id;
    return views.first.id;
  }

  DatabaseViewConfig get _activeView {
    final views = _views;
    return views.firstWhere(
      (v) => v.id == _activeViewId,
      orElse: () => views.first,
    );
  }

  void _persistViews(List<DatabaseViewConfig> views, {String? activeId}) {
    try {
      final transaction = editorState.transaction;
      final updates = <String, dynamic>{
        'views': views.map((v) => v.toJson()).toList(),
      };
      if (activeId != null) {
        updates['activeViewId'] = activeId;
      }
      transaction.updateNode(widget.node, updates);
      editorState.apply(transaction);
    } catch (_) {}
    setState(() {});
  }

  void _onSelectView(DatabaseViewConfig view) {
    if (view.id == _activeViewId) return;
    setState(() {
      _sortConfig = view.sort;
      _filterRules.clear();
      _filterRules.addAll(view.filters);
      _resetPage();
      _rowsStream = null;
    });
    try {
      final transaction = editorState.transaction;
      transaction.updateNode(widget.node, {'activeViewId': view.id});
      editorState.apply(transaction);
    } catch (_) {}
  }

  void _onAddView(DatabaseViewType type) {
    final views = List<DatabaseViewConfig>.from(_views);
    final newId = 'view_${DateTime.now().millisecondsSinceEpoch}';
    String defaultName;
    switch (type) {
      case DatabaseViewType.board:
        defaultName = context.l10n.viewTypeBoard;
        break;
      case DatabaseViewType.gallery:
        defaultName = context.l10n.viewTypeGallery;
        break;
      case DatabaseViewType.list:
        defaultName = context.l10n.viewTypeList;
        break;
      case DatabaseViewType.table:
        defaultName = '${context.l10n.viewTypeTable} ${views.length + 1}';
        break;
    }
    final newView = DatabaseViewConfig(
      id: newId,
      name: defaultName,
      type: type,
    );
    views.add(newView);
    _persistViews(views, activeId: newId);
    _onSelectView(newView);
  }

  void _onDuplicateView(DatabaseViewConfig view) {
    final views = List<DatabaseViewConfig>.from(_views);
    final newId = 'view_${DateTime.now().millisecondsSinceEpoch}';
    final dup = view.copyWith(
      id: newId,
      name: '${view.name} (Copy)',
    );
    views.add(dup);
    _persistViews(views, activeId: newId);
    _onSelectView(dup);
  }

  void _onRenameView(DatabaseViewConfig view, String newName) {
    final views = _views.map((v) {
      if (v.id == view.id) return v.copyWith(name: newName);
      return v;
    }).toList();
    _persistViews(views);
  }

  void _onDeleteView(DatabaseViewConfig view) {
    if (_views.length <= 1) return;
    final views = _views.where((v) => v.id != view.id).toList();
    final newActiveId = view.id == _activeViewId ? views.first.id : null;
    _persistViews(views, activeId: newActiveId);
    if (newActiveId != null) {
      _onSelectView(views.first);
    }
  }

  void _onUpdateColumnVisibility(
    DatabaseViewConfig view,
    List<String> visibleCols,
  ) {
    final views = _views.map((v) {
      if (v.id == view.id) return v.copyWith(visibleColumnIds: visibleCols);
      return v;
    }).toList();
    _persistViews(views);
  }

  void _toggleFreezeTitle() {
    final next = !_freezeTitle;
    try {
      final transaction = editorState.transaction;
      transaction.updateNode(widget.node, {'freezeTitle': next});
      editorState.apply(transaction);
    } catch (_) {}
    setState(() {});
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
    final newSort = columnId == null
        ? null
        : DatabaseSortConfig(columnId: columnId, ascending: ascending);
    setState(() {
      _resetPage();
      _sortConfig = newSort;
    });
    final views = _views.map((v) {
      if (v.id == _activeViewId) {
        return v.copyWith(sort: newSort, clearSort: newSort == null);
      }
      return v;
    }).toList();
    _persistViews(views);
  }

  void _addFilter(DatabaseFilterRule rule) {
    setState(() {
      _resetPage();
      _filterRules.removeWhere((r) => r.columnId == rule.columnId);
      _filterRules.add(rule);
    });
    final views = _views.map((v) {
      if (v.id == _activeViewId) {
        return v.copyWith(filters: List.from(_filterRules));
      }
      return v;
    }).toList();
    _persistViews(views);
  }

  void _removeFilter(String columnId) {
    setState(() {
      _resetPage();
      _filterRules.removeWhere((r) => r.columnId == columnId);
    });
    final views = _views.map((v) {
      if (v.id == _activeViewId) {
        return v.copyWith(filters: List.from(_filterRules));
      }
      return v;
    }).toList();
    _persistViews(views);
  }

  void _clearFilters() {
    setState(() {
      _resetPage();
      _searchTimer?.cancel();
      _filterRules.clear();
      _searchQuery = '';
      _appliedSearch = '';
    });
    final views = _views.map((v) {
      if (v.id == _activeViewId) {
        return v.copyWith(filters: const []);
      }
      return v;
    }).toList();
    _persistViews(views);
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

  void _autoFitColumn(
    String colId,
    List<DatabaseColumn> columns,
    List<DatabaseRowData> rows,
  ) {
    final col = columns.where((c) => c.id == colId).firstOrNull;
    if (col == null) return;
    final width = calculateAutoFitColumnWidth(
      column: col,
      rows: rows,
      cellSaves: _cellSaves,
    );
    setState(() {
      _columnWidths[colId] = width;
    });
    widget.repository.updateColumn(colId, width: width);
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
            final allColumns = colSnap.data!;
            final activeView = _activeView;
            final columns = activeView.visibleColumnIds.isEmpty
                ? allColumns
                : allColumns
                    .where(
                      (c) =>
                          c.type == 'title' ||
                          activeView.visibleColumnIds.contains(c.id),
                    )
                    .toList();

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
                            freezeTitle: _freezeTitle,
                            onToggleFreezeTitle: _toggleFreezeTitle,
                            tabs: DatabaseViewTabs(
                              views: _views,
                              activeViewId: _activeViewId,
                              columns: allColumns,
                              onSelectView: _onSelectView,
                              onAddView: _onAddView,
                              onRenameView: _onRenameView,
                              onDuplicateView: _onDuplicateView,
                              onDeleteView: _onDeleteView,
                              onUpdateColumnVisibility:
                                  _onUpdateColumnVisibility,
                            ),
                          ),
                          // Horizontally Scrollable Table
                          Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: false,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: defaultTargetPlatform ==
                                          TargetPlatform.macOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.iOS
                                  ? const BouncingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    )
                                  : const ClampingScrollPhysics(),
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
                                        horizontalScrollController:
                                            _horizontalScrollController,
                                        freezeTitle: _freezeTitle,
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
                                        onAutoFit: (colId) =>
                                            _autoFitColumn(colId, columns, data),
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
                                      Builder(
                                        builder: (context) {
                                          double totalHeight = 0;
                                          for (final row in displayRows.take(DesktopUx.databaseVisibleRows)) {
                                            double rowH = DesktopUx.databaseRowHeight;
                                            final rData = data.firstWhere(
                                              (d) => d.page.id == row.id,
                                              orElse: () => DatabaseRowData(row),
                                            );
                                            for (final col in columns) {
                                              final val = rData.properties[col.id]?.toString();
                                              if (val != null && val.length > 35) {
                                                final lines = (val.length / 32).ceil().clamp(1, 8);
                                                final h = lines * 20.0 + 8.0;
                                                if (h > rowH) rowH = h;
                                              }
                                            }
                                            totalHeight += rowH;
                                          }
                                          final viewportHeight = totalHeight.clamp(
                                            displayRows.isEmpty ? 0.0 : DesktopUx.databaseRowHeight,
                                            DesktopUx.databaseMaxVisibleHeight,
                                          );
                                          return SizedBox(
                                            width: tableWidth,
                                            height: viewportHeight,
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
                                            cacheExtent: 500.0,
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
                                                  horizontalScrollController:
                                                      _horizontalScrollController,
                                                  freezeTitle: _freezeTitle,
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
                                        );
                                      },
                                    ),
                                      StreamBuilder<
                                        Map<String, DatabaseSummaryStats>
                                      >(
                                        key: ValueKey(_summarySignature),
                                        stream: _summaryStream,
                                        builder: (context, summary) =>
                                            TableSummaryRow(
                                              horizontalScrollController:
                                                  _horizontalScrollController,
                                              freezeTitle: _freezeTitle,
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

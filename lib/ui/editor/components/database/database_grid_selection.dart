import '../../../common/app_dialog.dart';
import '../../../common/app_icons.dart';
import '../../../common/modern_dialog.dart';

import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../../../../data/model/database_paste.dart';
import '../../../../services/database_range_edits.dart';
import '../../../../l10n/locale_controller.dart';
import 'numeric_input_message.dart';
import '../../../../services/database_cell_saves.dart';

import 'package:notes_here/data/db/app_database.dart' show DatabaseColumn;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme.dart';
import 'database_models.dart';
import 'database_grid_navigation.dart';

String databaseClipboardValue(
  DatabaseColumn column,
  DatabaseRowData row, {
  DatabaseCellSaves? saves,
}) {
  final entry = saves?.lookup((
    databaseId: column.databaseId,
    rowId: row.page.id,
    columnId: column.id,
    title: column.type == 'title',
  ));
  final value = entry != null && entry.hasDraft
      ? entry.desired
      : column.type == 'title'
      ? row.page.title
      : row.properties[column.id];
  if (column.type == 'checkbox') {
    return (value == true || value == 'true' || value == 1) ? 'true' : 'false';
  }
  if (value == null) return '';
  if (column.type == 'select' ||
      column.type == 'multi_select' ||
      column.type == 'status') {
    try {
      final options = jsonDecode(column.options ?? '[]') as List;
      String label(dynamic id) =>
          options
              .cast<Map>()
              .where((opt) => opt['id'].toString() == id.toString())
              .map((opt) => opt['label'].toString())
              .firstOrNull ??
          id.toString();
      if (value is List) {
        final labels = value.map(label).toList();
        return labels.any((name) => name.contains(',') || name.startsWith('['))
            ? jsonEncode(labels)
            : labels.join(', ');
      }
      return label(value);
    } catch (_) {
      return value.toString();
    }
  }
  return value.toString();
}

String databaseRangeTsv(
  List<DatabaseColumn> columns,
  List<DatabaseRowData> rows,
  int firstRow,
  int lastRow,
  int firstColumn,
  int lastColumn, {
  DatabaseCellSaves? saves,
}) {
  String escape(String value) => value.contains(RegExp('[\t\r\n"]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;
  return [
    for (
      var row = math.min(firstRow, lastRow);
      row <= math.max(firstRow, lastRow);
      row++
    )
      [
        for (
          var column = math.min(firstColumn, lastColumn);
          column <= math.max(firstColumn, lastColumn);
          column++
        )
          escape(
            databaseClipboardValue(columns[column], rows[row], saves: saves),
          ),
      ].join('\t'),
  ].join('\r\n');
}

/// Drag across cells or Shift-click to select a rectangle; native text drags
/// inside one cell remain owned by TextField. No extra row widgets are mounted.
class DatabaseGridSelection extends StatefulWidget {
  const DatabaseGridSelection({
    super.key,
    required this.columns,
    required this.widths,
    required this.rows,
    required this.scrollController,
    required this.child,
    this.horizontalScrollController,
    this.saves,
    this.rangeEdits,
    this.controller,
  });
  final DatabaseGridSelectionController? controller;
  final DatabaseCellSaves? saves;
  final DatabaseRangeEdits? rangeEdits;
  final List<DatabaseColumn> columns;
  final Map<String, double> widths;
  final List<DatabaseRowData> rows;
  final ScrollController scrollController;
  final Widget child;
  final ScrollController? horizontalScrollController;
  @override
  State<DatabaseGridSelection> createState() => _DatabaseGridSelectionState();
}

class _DatabaseGridSelectionState extends State<DatabaseGridSelection>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _localSelection = DatabaseGridSelectionController();
  DatabaseGridSelectionController get _selection =>
      widget.controller ?? _localSelection;
  bool _publishPending = false;
  DatabaseSelectionMode _mode = DatabaseSelectionMode.cells;
  int? _wholeAnchor;
  (int, int)? _wholeActive;
  (int, int)? get _active => _wholeActive ?? _extent ?? _anchor;
  late final Ticker _ticker;
  Duration? _lastTick;
  int? _pointer;
  Offset? _pointerGlobal;
  DatabaseSelectionMode _dragMode = DatabaseSelectionMode.cells;
  final _focus = FocusNode(debugLabel: 'Database grid');
  late var _navigation = DatabaseGridNavigation(
    focus: _returnFocus,
    tab: _tab,
    activate: _activate,
    selectRow: _selectRowById,
    isRowSelected: _isRowSelected,
    selection: _selection,
  );
  int _editGeneration = 0;

  DatabaseGridRange? get _range =>
      !_selected || (!_focus.hasPrimaryFocus && !_dragging)
      ? null
      : DatabaseGridRange(
          math.min(_anchor!.$1, _extent!.$1),
          math.max(_anchor!.$1, _extent!.$1),
          math.min(_anchor!.$2, _extent!.$2),
          math.max(_anchor!.$2, _extent!.$2),
          _mode,
        );

  void _publish() {
    if (_publishPending) return;
    _publishPending = true;
    scheduleMicrotask(() {
      _publishPending = false;
      if (mounted) _selection.value = _range;
    });
  }

  bool _isRowSelected(String id) {
    final range = _range;
    final index = widget.rows.indexWhere((r) => r.page.id == id);
    return range != null &&
        range.firstColumn == 0 &&
        range.lastColumn == widget.columns.length - 1 &&
        index >= range.firstRow &&
        index <= range.lastRow;
  }

  void _bindSelection() {
    _selection.selectColumnHandler = _selectColumnById;
    _selection.selectAllHandler = _selectAll;
  }

  void _selectRowById(String id, bool extend) {
    final index = widget.rows.indexWhere((r) => r.page.id == id);
    if (index >= 0) _selectWhole(DatabaseSelectionMode.rows, index, extend);
  }

  void _selectColumnById(String id, bool extend) {
    final index = widget.columns.indexWhere((c) => c.id == id);
    if (index >= 0) _selectWhole(DatabaseSelectionMode.columns, index, extend);
  }

  void _selectWhole(DatabaseSelectionMode mode, int index, bool extend) {
    if (widget.rows.isEmpty || widget.columns.isEmpty) return;
    final active = _active ?? (0, 0);
    _editGeneration++;
    setState(() {
      _wholeActive = mode == DatabaseSelectionMode.rows
          ? (index, active.$2)
          : (active.$1, index);
      if (!extend || _mode != mode || _wholeAnchor == null) {
        _wholeAnchor = index;
      }
      _mode = mode;
      if (mode == DatabaseSelectionMode.rows) {
        _anchor = (_wholeAnchor!, 0);
        _extent = (index, widget.columns.length - 1);
      } else {
        _anchor = (0, _wholeAnchor!);
        _extent = (widget.rows.length - 1, index);
      }
    });
    _returnFocus();
  }

  void _selectAll() {
    if (widget.rows.isEmpty || widget.columns.isEmpty) return;
    _editGeneration++;
    setState(() {
      _wholeActive = _active ?? (0, 0);
      _mode = DatabaseSelectionMode.all;
      _wholeAnchor = null;
      _anchor = (0, 0);
      _extent = (widget.rows.length - 1, widget.columns.length - 1);
    });
    _returnFocus();
  }

  Rect? _visibleViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    var rect = box.localToGlobal(Offset.zero) & box.size;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final viewport = element.findRenderObject();
        if (viewport is RenderBox && viewport.hasSize) {
          rect = rect.intersect(
            viewport.localToGlobal(Offset.zero) & viewport.size,
          );
        }
      }
      return true;
    });
    return rect.isEmpty ? null : rect;
  }

  double _edgeVelocity(
    double pointer,
    double start,
    double end,
    ScrollController? scroll,
  ) {
    if (scroll == null || !scroll.hasClients || end <= start) return 0;
    final edge = math.min(UiSpace.s24, (end - start) / 3);
    final direction = pointer < start + edge
        ? -((start + edge - pointer) / edge).clamp(0.0, 1.0)
        : pointer > end - edge
        ? ((pointer - end + edge) / edge).clamp(0.0, 1.0)
        : 0.0;
    if (direction < 0 && scroll.offset <= scroll.position.minScrollExtent ||
        direction > 0 && scroll.offset >= scroll.position.maxScrollExtent) {
      return 0;
    }
    return direction * DesktopUx.databaseRowHeight * 18;
  }

  Offset _velocity() {
    final point = _pointerGlobal, rect = _visibleViewport();
    if (point == null || rect == null) return Offset.zero;
    return Offset(
      _dragMode == DatabaseSelectionMode.rows
          ? 0
          : _edgeVelocity(
              point.dx,
              rect.left,
              rect.right,
              widget.horizontalScrollController,
            ),
      _edgeVelocity(point.dy, rect.top, rect.bottom, widget.scrollController),
    );
  }

  void _syncTicker() {
    final run = _dragging && _pointer != null && _velocity() != Offset.zero;
    if (run && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  void _tick(Duration elapsed) {
    if (!mounted || !_dragging || _pointerGlobal == null) {
      _stopDrag();
      return;
    }
    final seconds = _lastTick == null
        ? 1 / 60
        : ((elapsed - _lastTick!).inMicroseconds / 1000000).clamp(0.0, 0.05);
    _lastTick = elapsed;
    final speed = _velocity();
    void jump(ScrollController? scroll, double velocity) {
      if (scroll == null || !scroll.hasClients || velocity == 0) return;
      scroll.jumpTo(
        (scroll.offset + velocity * seconds).clamp(
          scroll.position.minScrollExtent,
          scroll.position.maxScrollExtent,
        ),
      );
    }

    jump(widget.scrollController, speed.dy);
    jump(widget.horizontalScrollController, speed.dx);
    _updateDrag();
    _syncTicker();
  }

  void _stopDrag() {
    _ticker.stop();
    _lastTick = null;
    _pointer = null;
    _pointerGlobal = null;
    _down = null;
    _dragging = false;
  }

  void _updateDrag() {
    final box = context.findRenderObject(),
        point = _pointerGlobal,
        viewport = _visibleViewport();
    if (box is! RenderBox ||
        point == null ||
        viewport == null ||
        widget.rows.isEmpty ||
        widget.columns.isEmpty) {
      return;
    }
    final local = box.globalToLocal(
      Offset(
        point.dx.clamp(viewport.left, viewport.right - 0.1),
        point.dy.clamp(viewport.top, viewport.bottom - 0.1),
      ),
    );
    final next = _cellClamped(local);
    if (_dragMode == DatabaseSelectionMode.rows) {
      setState(() {
        _extent = (next.$1, widget.columns.length - 1);
        _wholeActive = (next.$1, _wholeActive?.$2 ?? 0);
      });
    } else if (next != _down || _dragging || !viewport.contains(point)) {
      setState(() {
        _extent = next;
        _dragging = true;
      });
      _returnFocus();
    }
  }

  (int, int) _cellClamped(Offset point) {
    final row = ((point.dy + _offset) / DesktopUx.databaseRowHeight)
        .floor()
        .clamp(0, widget.rows.length - 1);
    var x = DesktopUx.databaseGutterWidth;
    for (var c = 0; c < widget.columns.length; c++) {
      x += widget.widths[widget.columns[c].id] ?? widget.columns[c].width;
      if (point.dx < x) return (row, c);
    }
    return (row, widget.columns.length - 1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopDrag();
  }

  void _activate(String row, String column) {
    final r = widget.rows.indexWhere((value) => value.page.id == row);
    final c = widget.columns.indexWhere((value) => value.id == column);
    if (r < 0 || c < 0 || _dragging) return;
    setState(() {
      _mode = DatabaseSelectionMode.cells;
      _wholeActive = null;
      _wholeAnchor = null;
      _anchor = (r, c);
      _extent = null;
    });
  }

  void _returnFocus() {
    if (!mounted) return;
    _focus.requestFocus();
    if (_anchor != null && _extent == null) setState(() => _extent = _anchor);
  }

  void _reveal((int, int) cell) {
    final vertical = widget.scrollController;
    if (vertical.hasClients) {
      final top = cell.$1 * DesktopUx.databaseRowHeight;
      final bottom = top + DesktopUx.databaseRowHeight;
      final view = vertical.position.viewportDimension;
      final target = top < vertical.offset
          ? top
          : bottom > vertical.offset + view
          ? bottom - view
          : vertical.offset;
      vertical.jumpTo(target.clamp(0.0, vertical.position.maxScrollExtent));
    }
    final horizontal = widget.horizontalScrollController;
    if (horizontal != null && horizontal.hasClients) {
      var left = DesktopUx.databaseGutterWidth;
      for (var i = 0; i < cell.$2; i++) {
        left += widget.widths[widget.columns[i].id] ?? widget.columns[i].width;
      }
      final width =
          widget.widths[widget.columns[cell.$2].id] ??
          widget.columns[cell.$2].width;
      final view = horizontal.position.viewportDimension;
      final target = left < horizontal.offset || width > view
          ? left
          : left + width > horizontal.offset + view
          ? left + width - view
          : horizontal.offset;
      horizontal.jumpTo(target.clamp(0.0, horizontal.position.maxScrollExtent));
    }
  }

  void _move((int, int) cell, {bool extend = false}) {
    _editGeneration++;
    setState(() {
      _mode = DatabaseSelectionMode.cells;
      _wholeActive = null;
      _wholeAnchor = null;
      if (!extend || _anchor == null) _anchor = cell;
      _extent = cell;
    });
    _focus.requestFocus();
    _reveal(cell);
  }

  void _tab(bool reverse) {
    if (!mounted || widget.rows.isEmpty || widget.columns.isEmpty) return;
    final active = _active ?? (0, 0);
    final index =
        active.$1 * widget.columns.length + active.$2 + (reverse ? -1 : 1);
    if (index < 0 || index >= widget.rows.length * widget.columns.length) {
      _focus.requestFocus();
      if (reverse) {
        _focus.previousFocus();
      } else {
        _focus.nextFocus();
      }
      return;
    }
    _move((index ~/ widget.columns.length, index % widget.columns.length));
  }

  void _edit() {
    if (_rangeBusy) return;
    final active = _active;
    if (active == null) return;
    final key = (widget.rows[active.$1].page.id, widget.columns[active.$2].id);
    final generation = ++_editGeneration;
    _reveal(active);
    void open() {
      if (mounted && generation == _editGeneration && _focus.hasPrimaryFocus) {
        _navigation.editors[key]?.open?.call();
      }
    }

    // A keyboard move can scroll to a cell whose lazy row mounts next frame.
    if (_navigation.editors.containsKey(key)) {
      open();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
    }
  }

  bool _rangeBusy = false;

  Future<void> _rangeError(Object error) async {
    if (!mounted) return;
    setState(() => _rangeBusy = false);
    final l10n = context.l10n;
    var message = l10n.databasePasteFailed;
    if (error is DatabasePasteException) {
      message = error.numericIssue != null
          ? numericInputMessage(context, error.numericIssue!)
          : switch (error.issue) {
              DatabasePasteIssue.malformed => l10n.databasePasteMalformed,
              DatabasePasteIssue.ragged => l10n.databasePasteRagged,
              DatabasePasteIssue.tooLarge => l10n.databasePasteTooLarge,
              DatabasePasteIssue.bounds => l10n.databasePasteBounds,
              DatabasePasteIssue.shape => l10n.databasePasteShape,
              DatabasePasteIssue.checkbox => l10n.databasePasteCheckbox,
              DatabasePasteIssue.date => l10n.databasePasteDate,
              DatabasePasteIssue.url => l10n.databasePasteUrl,
              DatabasePasteIssue.tag => l10n.databasePasteTag,
              DatabasePasteIssue.unsupported => l10n.databasePasteUnsupported,
              DatabasePasteIssue.conflict => l10n.databasePasteConflict,
              DatabasePasteIssue.drafts => l10n.databasePasteDrafts,
              DatabasePasteIssue.busy => l10n.databasePasteBusy,
            };
      if (error.row != null) {
        message = l10n.databasePasteCellError(
          error.row!,
          error.column ?? '',
          message,
        );
      }
    }
    await showAppDialog<void>(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: context.skin.scrim,
      builder: (context) => ModernDialog(
        title: l10n.databasePasteTitle,
        icon: AppIcons.exclamationmarkCircle,
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _rangeNotice(String message, {bool? undo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: undo == null
            ? null
            : SnackBarAction(
                label: undo
                    ? context.l10n.databasePasteUndo
                    : context.l10n.databasePasteRedo,
                onPressed: () => _replay(undo: undo),
              ),
      ),
    );
  }

  Future<void> _paste() async {
    final history = widget.rangeEdits;
    if (history == null || _rangeBusy || _anchor == null) return;
    setState(() => _rangeBusy = true);
    final generation = _editGeneration;
    final rows = List<DatabaseRowData>.of(widget.rows),
        columns = List<DatabaseColumn>.of(widget.columns);
    final start = _extent == null
        ? _anchor!
        : (
            math.min(_anchor!.$1, _extent!.$1),
            math.min(_anchor!.$2, _extent!.$2),
          );
    final height = _extent == null ? 1 : (_anchor!.$1 - _extent!.$1).abs() + 1;
    final width = _extent == null ? 1 : (_anchor!.$2 - _extent!.$2).abs() + 1;
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted ||
          generation != _editGeneration ||
          !_focus.hasPrimaryFocus ||
          history != widget.rangeEdits) {
        return;
      }
      if (clipboard?.text == null) return;
      final matrix = parseDatabaseTsv(clipboard!.text!);
      final fill = matrix.length == 1 && matrix.first.length == 1;
      final pastedHeight = fill ? height : matrix.length;
      final pastedWidth = fill ? width : matrix.first.length;
      final changes = planDatabasePaste(
        text: clipboard.text!,
        columns: columns,
        rows: rows,
        startRow: start.$1,
        startColumn: start.$2,
        selectedRows: height,
        selectedColumns: width,
        currentValue: (column, row) {
          final entry = history.saves.lookup((
            databaseId: column.databaseId,
            rowId: row.page.id,
            columnId: column.id,
            title: column.type == 'title',
          ));
          if (entry != null &&
              (entry.editing || entry.phase != CellSavePhase.saved)) {
            throw const DatabasePasteException(DatabasePasteIssue.drafts);
          }
          return entry != null && entry.hasDraft
              ? entry.desired
              : column.type == 'title'
              ? row.page.title
              : row.properties[column.id];
        },
      );
      final count = await history.paste(changes);
      if (!mounted || history != widget.rangeEdits) return;
      if (count > 0 && generation == _editGeneration) {
        setState(() {
          _anchor = start;
          _extent = (start.$1 + pastedHeight - 1, start.$2 + pastedWidth - 1);
        });
      }
      if (mounted) {
        _rangeNotice(
          count == 0
              ? context.l10n.databasePasteUnchanged
              : context.l10n.databasePasteSaved(count),
          undo: count == 0 ? null : true,
        );
      }
    } catch (error) {
      await _rangeError(error);
    } finally {
      if (mounted) {
        setState(() => _rangeBusy = false);
      } else {
        _rangeBusy = false;
      }
    }
  }

  Future<void> _replay({required bool undo}) async {
    final history = widget.rangeEdits;
    if (history == null || _rangeBusy || widget.columns.isEmpty) return;
    setState(() => _rangeBusy = true);
    final databaseId = widget.columns.first.databaseId;
    try {
      final count = await (undo
          ? history.undo(databaseId)
          : history.redo(databaseId));
      if (!mounted || history != widget.rangeEdits) return;
      _rangeNotice(
        count == 0
            ? (undo
                  ? context.l10n.databasePasteNothingUndo
                  : context.l10n.databasePasteNothingRedo)
            : undo
            ? context.l10n.databasePasteUndone(count)
            : context.l10n.databasePasteRedone(count),
        undo: count == 0 ? null : !undo,
      );
    } catch (error) {
      await _rangeError(error);
    } finally {
      if (mounted) {
        setState(() => _rangeBusy = false);
      } else {
        _rangeBusy = false;
      }
    }
  }

  (int, int)? _anchor, _extent, _down;
  bool _dragging = false;
  bool get _selected => _anchor != null && _extent != null;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
    _bindSelection();
    widget.horizontalScrollController?.addListener(_scroll);
    widget.scrollController.addListener(_scroll);
  }

  void _scroll() {
    if (_selected) setState(() {});
    if (_dragging) _updateDrag();
  }

  @override
  void didUpdateWidget(DatabaseGridSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows.map((r) => r.page.id).join('|') !=
            widget.rows.map((r) => r.page.id).join('|') ||
        oldWidget.columns.map((c) => c.id).join('|') !=
            widget.columns.map((c) => c.id).join('|')) {
      _editGeneration++;
      _stopDrag();
      _mode = DatabaseSelectionMode.cells;
      _wholeActive = null;
      _wholeAnchor = null;
      _anchor = _extent = _down = null;
    }
    if (oldWidget.controller != widget.controller) {
      final old = oldWidget.controller ?? _localSelection;
      if (old.selectColumnHandler == _selectColumnById) {
        old.selectColumnHandler = null;
        old.selectAllHandler = null;
        old.clearWhenDetached();
      }
      _navigation = DatabaseGridNavigation(
        focus: _returnFocus,
        tab: _tab,
        activate: _activate,
        selectRow: _selectRowById,
        isRowSelected: _isRowSelected,
        selection: _selection,
      );
      _bindSelection();
    }
    if (oldWidget.horizontalScrollController !=
        widget.horizontalScrollController) {
      _stopDrag();
      oldWidget.horizontalScrollController?.removeListener(_scroll);
      widget.horizontalScrollController?.addListener(_scroll);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _stopDrag();
      oldWidget.scrollController.removeListener(_scroll);
      widget.scrollController.addListener(_scroll);
    }
  }

  @override
  void dispose() {
    _stopDrag();
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_selection.selectColumnHandler == _selectColumnById) {
      _selection.selectColumnHandler = null;
      _selection.selectAllHandler = null;
      _selection.clearWhenDetached();
    }
    widget.horizontalScrollController?.removeListener(_scroll);
    widget.scrollController.removeListener(_scroll);
    _localSelection.dispose();
    _focus.dispose();
    super.dispose();
  }

  double get _offset =>
      widget.scrollController.hasClients ? widget.scrollController.offset : 0;
  (int, int)? _cell(Offset point) {
    final row = ((point.dy + _offset) / DesktopUx.databaseRowHeight).floor();
    if (row < 0 || row >= widget.rows.length) return null;
    var x = DesktopUx.databaseGutterWidth;
    for (var i = 0; i < widget.columns.length; i++) {
      final right =
          x + (widget.widths[widget.columns[i].id] ?? widget.columns[i].width);
      if (point.dx >= x && point.dx < right) return (row, i);
      x = right;
    }
    return null;
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_focus.hasPrimaryFocus &&
        widget.rangeEdits != null &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        !HardwareKeyboard.instance.isAltPressed) {
      if (key == LogicalKeyboardKey.keyV) {
        if (event is KeyDownEvent) _paste();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.keyY) {
        if (event is KeyDownEvent) {
          _replay(
            undo:
                key == LogicalKeyboardKey.keyZ &&
                !HardwareKeyboard.instance.isShiftPressed,
          );
        }
        return KeyEventResult.handled;
      }
    }
    if (widget.rows.isEmpty || widget.columns.isEmpty) {
      return KeyEventResult.ignored;
    }
    final modifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;
    if (key == LogicalKeyboardKey.tab && !modifier) {
      _tab(HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (!_focus.hasPrimaryFocus) {
      if (key == LogicalKeyboardKey.escape && !modifier) {
        final cell = _active;
        if (cell != null) {
          _navigation
              .editors[(
                widget.rows[cell.$1].page.id,
                widget.columns[cell.$2].id,
              )]
              ?.cancel
              ?.call();
        }
        _returnFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.space &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      final active = _active ?? (0, 0);
      if (HardwareKeyboard.instance.isControlPressed) {
        _selectWhole(
          DatabaseSelectionMode.columns,
          active.$2,
          HardwareKeyboard.instance.isShiftPressed,
        );
        return KeyEventResult.handled;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        _selectWhole(DatabaseSelectionMode.rows, active.$1, false);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _extent = null);
      return KeyEventResult.handled;
    }
    if (!modifier &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.f2 ||
            (key == LogicalKeyboardKey.space &&
                (_active) != null &&
                widget.columns[(_active)!.$2].type == 'checkbox'))) {
      if (event is KeyDownEvent) _edit();
      return KeyEventResult.handled;
    }
    if (!modifier) {
      final delta = key == LogicalKeyboardKey.arrowLeft
          ? (0, -1)
          : key == LogicalKeyboardKey.arrowRight
          ? (0, 1)
          : key == LogicalKeyboardKey.arrowUp
          ? (-1, 0)
          : key == LogicalKeyboardKey.arrowDown
          ? (1, 0)
          : null;
      if (delta != null) {
        final active = _active ?? (0, 0);
        if (HardwareKeyboard.instance.isShiftPressed &&
            _mode == DatabaseSelectionMode.rows &&
            delta.$1 != 0) {
          final row = (active.$1 + delta.$1).clamp(0, widget.rows.length - 1);
          _selectWhole(DatabaseSelectionMode.rows, row, true);
          _reveal((row, active.$2));
          return KeyEventResult.handled;
        }
        if (HardwareKeyboard.instance.isShiftPressed &&
            _mode == DatabaseSelectionMode.columns &&
            delta.$2 != 0) {
          final column = (active.$2 + delta.$2).clamp(
            0,
            widget.columns.length - 1,
          );
          _selectWhole(DatabaseSelectionMode.columns, column, true);
          _reveal((active.$1, column));
          return KeyEventResult.handled;
        }
        _move((
          (active.$1 + delta.$1).clamp(0, widget.rows.length - 1),
          (active.$2 + delta.$2).clamp(0, widget.columns.length - 1),
        ), extend: HardwareKeyboard.instance.isShiftPressed);
        return KeyEventResult.handled;
      }
    }
    if (!_selected) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        Clipboard.setData(
          ClipboardData(
            text: databaseRangeTsv(
              widget.columns,
              widget.rows,
              _anchor!.$1,
              _extent!.$1,
              _anchor!.$2,
              _extent!.$2,
              saves: widget.saves,
            ),
          ),
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          widget.rows.isNotEmpty &&
          widget.columns.isNotEmpty) {
        _selectAll();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _publish();
    Rect? selection;
    if (_selected && (_focus.hasPrimaryFocus || _dragging)) {
      final first = math.min(_anchor!.$2, _extent!.$2),
          last = math.max(_anchor!.$2, _extent!.$2);
      var x = DesktopUx.databaseGutterWidth, width = 0.0;
      for (var i = 0; i <= last; i++) {
        final w =
            widget.widths[widget.columns[i].id] ?? widget.columns[i].width;
        if (i < first) {
          x += w;
        } else {
          width += w;
        }
      }
      selection = Rect.fromLTWH(
        x,
        math.min(_anchor!.$1, _extent!.$1) * DesktopUx.databaseRowHeight -
            _offset,
        width,
        ((_anchor!.$1 - _extent!.$1).abs() + 1) * DesktopUx.databaseRowHeight,
      );
    }
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      descendantsAreTraversable: false,
      skipTraversal: widget.rows.isEmpty || widget.columns.isEmpty,
      onFocusChange: (focused) {
        if (!mounted) return;
        if (!focused) _stopDrag();
        setState(() {
          if (focused &&
              _focus.hasPrimaryFocus &&
              _anchor == null &&
              widget.rows.isNotEmpty &&
              widget.columns.isNotEmpty) {
            _anchor = _extent = (0, 0);
          }
        });
      },
      child: DatabaseGridScope(
        navigation: _navigation,
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons != kPrimaryButton ||
                _pointer != null ||
                widget.rows.isEmpty ||
                widget.columns.isEmpty) {
              return;
            }
            _editGeneration++;
            _pointer = event.pointer;
            _pointerGlobal = event.position;
            _dragging = false;
            final point = event.localPosition;
            if (point.dx >= 0 &&
                point.dx < DesktopUx.databaseGutterWidth &&
                point.dy >= 0 &&
                point.dy <
                    (context.findRenderObject() as RenderBox).size.height) {
              _down = _cellClamped(point);
              _dragMode = DatabaseSelectionMode.rows;
              _selectWhole(
                DatabaseSelectionMode.rows,
                _down!.$1,
                HardwareKeyboard.instance.isShiftPressed,
              );
              _dragging = true;
            } else {
              _down = _cell(point);
              _dragMode = DatabaseSelectionMode.cells;
              if (_down == null) {
                _stopDrag();
                return;
              }
              setState(() {
                _mode = DatabaseSelectionMode.cells;
                _wholeActive = null;
                _wholeActive = null;
                _wholeAnchor = null;
                if (HardwareKeyboard.instance.isShiftPressed &&
                    _anchor != null) {
                  _extent = _down;
                  _dragging = true;
                } else {
                  _anchor = _down;
                  _extent = null;
                }
              });
            }
          },
          onPointerMove: (event) {
            if (event.pointer != _pointer) return;
            if (event.buttons != kPrimaryButton) {
              _stopDrag();
              return;
            }
            _pointerGlobal = event.position;
            _updateDrag();
            _syncTicker();
          },
          onPointerUp: (event) {
            if (event.pointer == _pointer) {
              final selected = _dragging;
              _stopDrag();
              if (selected) _returnFocus();
              setState(() {});
            }
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) {
              _stopDrag();
              setState(() {});
            }
          },
          child: ClipRect(
            child: Stack(
              children: [
                widget.child,
                if (_rangeBusy)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: TickerMode(
                        enabled: !MediaQuery.disableAnimationsOf(context),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                  ),
                if (selection != null)
                  Positioned.fromRect(
                    rect: selection,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('database_range_selection'),
                        decoration: BoxDecoration(
                          color: _anchor == _extent
                              ? Palette.transparent
                              : context.skin.accentText.withValues(alpha: 0.12),
                          border: Border.all(color: context.skin.accentText),
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
  }
}

class DatabaseSelectionStatus extends StatelessWidget {
  const DatabaseSelectionStatus({super.key, required this.controller});
  final DatabaseGridSelectionController controller;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<DatabaseGridRange?>(
        valueListenable: controller,
        builder: (context, range, _) {
          if (range == null) return const SizedBox.shrink();
          final label = context.l10n.databaseSelectionSize(
            range.rows,
            range.columns,
            range.cells,
          );
          return Tooltip(
            message: context.l10n.databaseSelectionScope,
            child: Semantics(
              liveRegion: true,
              child: Text(
                label,
                key: const Key('database_selection_dimensions'),
                style: TextStyle(
                  fontSize: UiType.caption,
                  color: context.skin.muted,
                ),
              ),
            ),
          );
        },
      );
}

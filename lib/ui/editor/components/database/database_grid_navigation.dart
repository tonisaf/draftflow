import 'dart:async';

import 'package:flutter/widgets.dart';

enum DatabaseSelectionMode { cells, rows, columns, all }

@immutable
class DatabaseGridRange {
  const DatabaseGridRange(
    this.firstRow,
    this.lastRow,
    this.firstColumn,
    this.lastColumn,
    this.mode,
  );
  final int firstRow, lastRow, firstColumn, lastColumn;
  final DatabaseSelectionMode mode;
  int get rows => lastRow - firstRow + 1;
  int get columns => lastColumn - firstColumn + 1;
  int get cells => rows * columns;
  @override
  bool operator ==(Object other) =>
      other is DatabaseGridRange &&
      firstRow == other.firstRow &&
      lastRow == other.lastRow &&
      firstColumn == other.firstColumn &&
      lastColumn == other.lastColumn &&
      mode == other.mode;
  @override
  int get hashCode =>
      Object.hash(firstRow, lastRow, firstColumn, lastColumn, mode);
}

class DatabaseGridSelectionController
    extends ValueNotifier<DatabaseGridRange?> {
  DatabaseGridSelectionController() : super(null);
  bool _disposed = false;
  void clearWhenDetached() {
    scheduleMicrotask(() {
      if (!_disposed && selectColumnHandler == null) value = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void Function(String, bool)? selectColumnHandler;
  VoidCallback? selectAllHandler;
  void selectColumn(String id, {bool extend = false}) =>
      selectColumnHandler?.call(id, extend);
  void selectAll() => selectAllHandler?.call();
}

/// A mounted cell exposes its existing editor without keeping virtual rows alive.
class DatabaseCellEditor {
  VoidCallback? open;
  VoidCallback? cancel;
  BuildContext? Function()? anchorContext;
}

class DatabaseGridNavigation {
  DatabaseGridNavigation({
    required this.focus,
    required this.tab,
    required this.activate,
    required this.selectRow,
    required this.isRowSelected,
    required this.selection,
  });
  final void Function(String, bool) selectRow;
  final bool Function(String) isRowSelected;
  final DatabaseGridSelectionController selection;
  final VoidCallback focus;
  final ValueChanged<bool> tab;
  final void Function(String row, String column) activate;
  final editors = <(String, String), DatabaseCellEditor>{};
}

class DatabaseGridScope extends InheritedWidget {
  const DatabaseGridScope({
    super.key,
    required this.navigation,
    required super.child,
  });
  final DatabaseGridNavigation navigation;
  static DatabaseGridNavigation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DatabaseGridScope>()
      ?.navigation;
  @override
  bool updateShouldNotify(DatabaseGridScope oldWidget) =>
      navigation != oldWidget.navigation;
}

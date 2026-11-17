import 'dart:math' as math;
import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import '../../../../services/database_cell_saves.dart';
import '../../../theme.dart';
import 'database_grid_selection.dart' show databaseClipboardValue;
import 'database_models.dart';

/// Calculates the ideal column width based on the header title and the visible
/// contents of cells in that column, clamped to [minWidth, 600.0].
double calculateAutoFitColumnWidth({
  required DatabaseColumn column,
  required List<DatabaseRowData> rows,
  DatabaseCellSaves? cellSaves,
  TextStyle headerStyle = const TextStyle(
    fontSize: UiType.small,
    fontWeight: FontWeight.w600,
  ),
  TextStyle cellStyle = const TextStyle(fontSize: UiType.body),
}) {
  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );

  double measureText(String text, TextStyle style) {
    if (text.isEmpty) return 0.0;
    textPainter.text = TextSpan(text: text, style: style);
    textPainter.layout();
    return textPainter.size.width;
  }

  // Header measurement: icon (14) + spacing (6) + title text + menu (16) + padding (16) + sort buffer (12)
  final headerTextWidth = measureText(column.name, headerStyle);
  final headerWidth = headerTextWidth + 64.0;

  double maxCellWidth = 0.0;

  if (column.type == 'checkbox') {
    maxCellWidth = 40.0;
  } else {
    // Sample rows up to 100 loaded rows for performance
    for (final row in rows.take(100)) {
      final rawValue = databaseClipboardValue(column, row, saves: cellSaves);
      if (rawValue.isNotEmpty) {
        // In case of multiline content, measure the longest line
        for (final line in rawValue.split('\n')) {
          final w = measureText(line, cellStyle);
          if (w > maxCellWidth) {
            maxCellWidth = w;
          }
        }
      }
    }
    // Add cell padding (horizontal 8 * 2 = 16) + breathing room (12)
    maxCellWidth += 28.0;
  }

  final minWidth = column.type == 'checkbox' ? 60.0 : 115.0;
  final idealWidth = math.max(headerWidth, maxCellWidth);
  return idealWidth.clamp(minWidth, 600.0);
}

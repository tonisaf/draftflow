import 'dart:convert';

import '../db/app_database.dart' show DatabaseColumn;
import 'database_query.dart';
import 'numeric_cell_input.dart';

enum DatabasePasteIssue {
  malformed,
  ragged,
  tooLarge,
  bounds,
  shape,
  checkbox,
  date,
  url,
  tag,
  unsupported,
  conflict,
  drafts,
  busy,
}

class DatabasePasteException implements Exception {
  const DatabasePasteException(
    this.issue, {
    this.row,
    this.column,
    this.numericIssue,
  });
  final DatabasePasteIssue issue;
  final int? row;
  final String? column;
  final NumericInputIssue? numericIssue;
}

const databasePasteMaxCells = 2000;

/// Excel TSV quoting, including doubled quotes and embedded line breaks.
List<List<String>> parseDatabaseTsv(String text) {
  if (text.length > 2000000) {
    throw const DatabasePasteException(DatabasePasteIssue.tooLarge);
  }
  final rows = <List<String>>[];
  var row = <String>[], value = StringBuffer();
  var quoted = false, closed = false, fieldStart = true, endedRow = false;
  void field() {
    row.add(value.toString());
    value = StringBuffer();
    closed = false;
    fieldStart = true;
  }

  void line() {
    field();
    rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    endedRow = false;
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          value.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        value.write(c);
      }
      continue;
    }
    if (c == '\t') {
      field();
    } else if (c == '\r' || c == '\n') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      line();
      endedRow = true;
    } else if (closed) {
      throw const DatabasePasteException(DatabasePasteIssue.malformed);
    } else if (c == '"' && fieldStart) {
      quoted = true;
      fieldStart = false;
    } else {
      value.write(c);
      fieldStart = false;
    }
    if (rows.length + row.length > databasePasteMaxCells) {
      throw const DatabasePasteException(DatabasePasteIssue.tooLarge);
    }
  }
  if (quoted) throw const DatabasePasteException(DatabasePasteIssue.malformed);
  if (!endedRow) line();
  if (rows.isEmpty) {
    return [
      [''],
    ];
  }
  if (rows.any((r) => r.length != rows.first.length)) {
    throw const DatabasePasteException(DatabasePasteIssue.ragged);
  }
  if (rows.length * rows.first.length > databasePasteMaxCells) {
    throw const DatabasePasteException(DatabasePasteIssue.tooLarge);
  }
  return rows;
}

List<Map> _tags(DatabaseColumn column) {
  try {
    return (jsonDecode(column.options ?? '[]') as List).cast<Map>();
  } catch (_) {
    throw const DatabasePasteException(DatabasePasteIssue.tag);
  }
}

dynamic parseDatabasePasteValue(DatabaseColumn column, String raw) {
  final value = raw.trim();
  switch (column.type) {
    case 'title':
    case 'text':
      return raw;
    case 'number':
      final parsed = parseNumericCellInput(
        raw,
        format: numericColumnFormat(column.options),
      );
      if (!parsed.valid) {
        throw DatabasePasteException(
          DatabasePasteIssue.unsupported,
          numericIssue: parsed.issue,
        );
      }
      return parsed.value;
    case 'checkbox':
      if (['', 'false', '0', 'no', 'нет'].contains(value.toLowerCase())) {
        return false;
      }
      if (['true', '1', 'yes', 'да'].contains(value.toLowerCase())) return true;
      throw const DatabasePasteException(DatabasePasteIssue.checkbox);
    case 'date':
      if (value.isEmpty) return null;
      final date = DateTime.tryParse(value);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          date == null ||
          date.toIso8601String().substring(0, 10) != value ||
          date.year < 1970 ||
          date.year > 2100) {
        throw const DatabasePasteException(DatabasePasteIssue.date);
      }
      return value;
    case 'url':
      if (value.isEmpty) return '';
      final normalized = value.contains('://') || value.startsWith('mailto:')
          ? value
          : 'https://$value';
      final uri = Uri.tryParse(normalized);
      if (uri == null ||
          value.contains(RegExp(r'\s')) ||
          !(['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty ||
              uri.scheme == 'mailto' && uri.path.contains('@'))) {
        throw const DatabasePasteException(DatabasePasteIssue.url);
      }
      return normalized;
    case 'select':
    case 'multi_select':
    case 'status':
      if (value.isEmpty) {
        return (column.type == 'select' || column.type == 'status')
            ? null
            : <String>[];
      }
      final tags = _tags(column);
      List<String> labels = [value];
      if (column.type == 'multi_select' &&
          !tags.any((t) => t['label'] == value)) {
        if (value.startsWith('[')) {
          try {
            labels = (jsonDecode(value) as List).cast<String>();
          } catch (_) {
            throw const DatabasePasteException(DatabasePasteIssue.tag);
          }
        } else {
          labels = value.split(',').map((s) => s.trim()).toList();
        }
      }
      final ids = <String>[];
      for (final label in labels) {
        var matches = tags.where((t) => t['label'] == label).toList();
        if (matches.isEmpty) {
          matches = tags
              .where(
                (t) =>
                    t['label'].toString().toLowerCase() == label.toLowerCase(),
              )
              .toList();
        }
        if (matches.length != 1) {
          throw const DatabasePasteException(DatabasePasteIssue.tag);
        }
        final id = matches.single['id'].toString();
        if (!ids.contains(id)) ids.add(id);
      }
      return (column.type == 'select' || column.type == 'status')
          ? ids.single
          : ids;
    default:
      throw const DatabasePasteException(DatabasePasteIssue.unsupported);
  }
}

bool validDatabasePasteValue(DatabaseColumn column, dynamic value) {
  if (column.type == 'number') {
    return (value == null || value is num) &&
        parseNumericCellInput(
          value,
          format: numericColumnFormat(column.options),
        ).valid;
  }
  if (column.type == 'title' || column.type == 'text') return value is String;
  if (column.type == 'checkbox') {
    return value is bool || value == 'true' || value == 'false';
  }
  if (column.type == 'select' ||
      column.type == 'multi_select' ||
      column.type == 'status') {
    final ids = _tags(column).map((t) => t['id'].toString()).toSet();
    return (column.type == 'select' || column.type == 'status')
        ? value == null || value is String && ids.contains(value)
        : value is List &&
            value.every((v) => v is String && ids.contains(v)) &&
            value.toSet().length == value.length;
  }
  if (column.type == 'date' && value == null) return true;
  if (value is! String) return false;
  try {
    return parseDatabasePasteValue(column, value) == value;
  } catch (_) {
    return false;
  }
}

class DatabaseCellChange {
  DatabaseCellChange({
    required this.databaseId,
    required this.rowId,
    required this.column,
    required dynamic before,
    required dynamic after,
  }) : before = jsonDecode(jsonEncode(before)),
       after = jsonDecode(jsonEncode(after));
  final String databaseId, rowId;
  final DatabaseColumn column;
  final dynamic before, after;
}

List<DatabaseCellChange> planDatabasePaste({
  required String text,
  required List<DatabaseColumn> columns,
  required List<DatabaseRowData> rows,
  required int startRow,
  required int startColumn,
  int selectedRows = 1,
  int selectedColumns = 1,
  dynamic Function(DatabaseColumn, DatabaseRowData)? currentValue,
}) {
  final matrix = parseDatabaseTsv(text);
  final fill = matrix.length == 1 && matrix.first.length == 1;
  final height = fill ? selectedRows : matrix.length,
      width = fill ? selectedColumns : matrix.first.length;
  if (height <= 0 || width <= 0 || height * width > databasePasteMaxCells) {
    throw const DatabasePasteException(DatabasePasteIssue.tooLarge);
  }
  if (startRow < 0 ||
      startColumn < 0 ||
      startRow + height > rows.length ||
      startColumn + width > columns.length) {
    throw const DatabasePasteException(DatabasePasteIssue.bounds);
  }
  if (!fill &&
      (selectedRows > 1 || selectedColumns > 1) &&
      (selectedRows != height || selectedColumns != width)) {
    throw const DatabasePasteException(DatabasePasteIssue.shape);
  }
  final changes = <DatabaseCellChange>[];
  for (var r = 0; r < height; r++) {
    for (var c = 0; c < width; c++) {
      final column = columns[startColumn + c], row = rows[startRow + r];
      dynamic value;
      try {
        value = parseDatabasePasteValue(
          column,
          matrix[fill ? 0 : r][fill ? 0 : c],
        );
      } on DatabasePasteException catch (error) {
        throw DatabasePasteException(
          error.issue,
          row: startRow + r + 1,
          column: column.name,
          numericIssue: error.numericIssue,
        );
      }
      final before = currentValue == null
          ? (column.type == 'title'
                ? row.page.title
                : row.properties[column.id])
          : currentValue(column, row);
      if (jsonEncode(before) == jsonEncode(value)) continue;
      changes.add(
        DatabaseCellChange(
          databaseId: column.databaseId,
          rowId: row.page.id,
          column: column,
          before: before,
          after: value,
        ),
      );
    }
  }
  return changes;
}

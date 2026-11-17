import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import '../model/database_query.dart';

class DatabaseRowsSql {
  final String sql;
  final List<Variable> variables;
  final int limit;
  const DatabaseRowsSql(this.sql, this.variables, this.limit);
}

DatabaseRowsSql buildDatabaseRowsQuery(
  String databaseId,
  List<DatabaseColumn> columns, {
  DatabaseSortConfig? sort,
  List<DatabaseFilterRule> filters = const [],
  String search = '',
  int offset = 0,
  int limit = DatabaseQueryPolicy.pageSize,
  bool allFiltered = false,
}) {
  if (offset < 0 || limit < 1 || limit > DatabaseQueryPolicy.maxPageSize) {
    throw ArgumentError('Invalid database page bounds');
  }
  final variables = <Variable>[];
  String bind(Object value) {
    variables.add(
      value is int ? Variable<int>(value) : Variable<String>(value.toString()),
    );
    return '?${variables.length}';
  }

  final byId = {for (final col in columns) col.id: col};
  final database = bind(databaseId);
  final totalWhere =
      'p.database_id = $database AND p.trashed_at IS NULL AND EXISTS '
      '(SELECT 1 FROM databases d WHERE d.id = p.database_id AND d.trashed_at IS NULL)';
  final conditions = [totalWhere];
  String properties(bool folded) =>
      "CASE WHEN json_valid(p.${folded ? 'properties_folded' : 'properties'}) THEN p.${folded ? 'properties_folded' : 'properties'} ELSE '{}' END";
  String field(DatabaseColumn col, {bool folded = false}) => col.type == 'title'
      ? (folded ? 'COALESCE(p.title_folded, lower(p.title))' : 'p.title')
      : 'json_extract(${properties(folded)}, ${bind('\$.${jsonEncode(col.id)}')})';
  String type(DatabaseColumn col) => col.type == 'title'
      ? "'text'"
      : 'json_type(${properties(false)}, ${bind('\$.${jsonEncode(col.id)}')})';
  String text(DatabaseColumn col, {bool folded = false}) {
    final value = field(col, folded: folded);
    return "CASE ${type(col)} WHEN 'true' THEN 'true' WHEN 'false' THEN 'false' ELSE CAST($value AS TEXT) END";
  }

  for (final filter in filters) {
    final col = byId[filter.columnId];
    if (col == null) continue; // Deleted columns no longer constrain the view.
    final value = text(col);
    final empty = "($value IS NULL OR trim($value) = '' OR trim($value) = '[]')";
    switch (filter.operator) {
      case 'is_true':
        conditions.add(
          "(${type(col)} = 'true' OR ${field(col)} = 1 OR lower(${field(col)}) = 'true')",
        );
      case 'is_false':
        conditions.add(
          "NOT (${type(col)} = 'true' OR ${field(col)} = 1 OR lower(${field(col)}) = 'true')",
        );
      case 'is_empty':
        conditions.add(empty);
      case 'is_not_empty':
        conditions.add('NOT $empty');
      case 'equals':
        conditions.add(
          filter.value == null
              ? '$value IS NULL'
              : '$value = ${bind(filter.value.toString())}',
        );
      case 'contains':
        if (filter.value != null && filter.value.toString().isNotEmpty) {
          conditions.add(
            'instr(COALESCE(${text(col, folded: true)}, \'\'), ${bind(filter.value.toString().toLowerCase())}) > 0',
          );
        }
      default:
        throw ArgumentError('Unsupported database filter operator');
    }
  }
  if (search.trim().isNotEmpty) {
    final query = bind(search.trim().toLowerCase());
    conditions.add(
      '(instr(COALESCE(p.title_folded, lower(p.title)), $query) > 0 OR '
      "instr(COALESCE(p.properties_folded, ''), $query) > 0)",
    );
  }
  if (allFiltered) {
    return DatabaseRowsSql(
      'SELECT p.* FROM pages p WHERE ${conditions.join(' AND ')}',
      variables,
      0,
    );
  }
  var order = 'p.order_key ASC, p.created_at ASC, p.id ASC';
  final sortColumn = byId[sort?.columnId];
  if (sortColumn != null) {
    final raw = text(sortColumn);
    final empty = "($raw IS NULL OR trim($raw) = '')";
    final value = switch (sortColumn.type) {
      'number' => (() {
        final raw = field(sortColumn);
        final numericText =
            "CASE WHEN substr($raw, 1, 1) = '+' THEN substr($raw, 2) ELSE $raw END";
        return "CASE WHEN ${type(sortColumn)} IN ('integer', 'real') THEN CAST($raw AS REAL) "
            "WHEN ${type(sortColumn)} = 'text' THEN CASE WHEN json_valid($numericText) THEN "
            "CASE WHEN json_type($numericText) IN ('integer', 'real') THEN CAST($numericText AS REAL) ELSE 0 END "
            "ELSE 0 END ELSE 0 END";
      })(),
      'checkbox' =>
        "CASE WHEN ${type(sortColumn)} = 'true' OR ${field(sortColumn)} = 1 OR lower(${field(sortColumn)}) = 'true' THEN 1 ELSE 0 END",
      _ => 'trim(${text(sortColumn, folded: true)})',
    };
    order = '$empty ASC, $value ${sort!.ascending ? 'ASC' : 'DESC'}, $order';
  }
  final where = conditions.join(' AND ');
  final requested = bind(offset);
  final pageSize = bind(limit);
  return DatabaseRowsSql(
    '''
    WITH counts AS (
      SELECT (SELECT COUNT(*) FROM pages p WHERE $totalWhere) AS total_count,
        (SELECT COUNT(*) FROM pages p WHERE $where) AS filtered_count
    ), bounds AS (
      SELECT *, CASE WHEN $requested >= filtered_count THEN
        CASE WHEN filtered_count > 0 THEN ((filtered_count - 1) / $pageSize) * $pageSize ELSE 0 END
        ELSE $requested END AS actual_offset FROM counts
    ), slice AS (
      SELECT p.* FROM pages p WHERE $where ORDER BY $order
      LIMIT $pageSize OFFSET (SELECT actual_offset FROM bounds)
    )
    SELECT slice.*, bounds.total_count, bounds.filtered_count, bounds.actual_offset
    FROM bounds LEFT JOIN slice ON 1 = 1
    ORDER BY ${order.replaceAll('p.', 'slice.')}
  ''',
    variables,
    limit,
  );
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../model/database_cell_conflict.dart';
import '../../model/database_paste.dart';
import '../../model/database_query.dart';
import '../../model/numeric_cell_input.dart';
import '../app_database.dart';
import '../database_rows_query.dart';

class DatabaseRowsDao extends DatabaseAccessor<AppDatabase> {
  DatabaseRowsDao(super.db);

  $PagesTable get pages => db.pages;
  $DatabasesTable get databases => db.databases;
  $DatabaseColumnsTable get databaseColumns => db.databaseColumns;

  Future<List<Page>> getDatabaseRows(String databaseId) {
    return (select(pages)
          ..where(
            (tbl) => tbl.databaseId.equals(databaseId) & tbl.trashedAt.isNull(),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.orderKey),
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();
  }

  Stream<List<Page>> watchDatabaseRows(String databaseId) {
    return (select(pages)
          ..where(
            (tbl) => tbl.databaseId.equals(databaseId) & tbl.trashedAt.isNull(),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.orderKey),
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .watch();
  }

  Future<DatabaseRowsSql> _rowPageSql(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) async => buildDatabaseRowsQuery(
    databaseId,
    await db.databasesDao.getColumnsForDatabase(databaseId),
    sort: sort,
    filters: filters,
    search: search,
    offset: offset,
    limit: limit,
  );

  DatabaseRowsPage _mapRowPage(
    List<QueryRow> result,
    int limit, {
    Map<String, DatabaseRowData>? cache,
  }) {
    final stored = result
        .where((row) => row.data['id'] != null)
        .map((row) => pages.map(row.data))
        .toList();
    DatabaseRowData decode(Page page) {
      final old = cache?[page.id];
      final data = old?.page == page
          ? old!
          : DatabaseRowData(
              page,
              properties: old?.page.properties == page.properties
                  ? old?.properties
                  : null,
            );
      cache?[page.id] = data;
      return data;
    }

    final retained = stored.map((page) => page.id).toSet();
    cache?.removeWhere((id, _) => !retained.contains(id));
    return DatabaseRowsPage(
      pages: stored,
      totalCount: result.first.read<int>('total_count'),
      filteredCount: result.first.read<int>('filtered_count'),
      offset: result.first.read<int>('actual_offset'),
      limit: limit,
      decode: decode,
    );
  }

  Future<DatabaseRowsPage> queryDatabaseRows(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) async {
    final query = await _rowPageSql(
      databaseId,
      sort: sort,
      filters: filters,
      search: search,
      offset: offset,
      limit: limit,
    );
    final rows = await customSelect(
      query.sql,
      variables: query.variables,
    ).get();
    return _mapRowPage(rows, limit);
  }

  /// Query parameters are fixed for this subscription. The table view creates
  /// a new subscription when filters, sorting or column types change.
  Stream<DatabaseRowsPage> watchDatabaseRowsPage(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) async* {
    final query = await _rowPageSql(
      databaseId,
      sort: sort,
      filters: filters,
      search: search,
      offset: offset,
      limit: limit,
    );
    final cache = <String, DatabaseRowData>{};
    yield* customSelect(
      query.sql,
      variables: query.variables,
      readsFrom: {pages, databases},
    ).watch().map((result) => _mapRowPage(result, limit, cache: cache));
  }

  Stream<Map<String, List<DatabaseValueGroup>>> watchDatabaseSummaryGroups(
    String databaseId,
    Set<String> columnIds, {
    List<DatabaseFilterRule> filters = const [],
    String search = '',
  }) async* {
    final columns = await db.databasesDao.getColumnsForDatabase(databaseId);
    final selected = columns
        .where((column) => columnIds.contains(column.id))
        .toList();
    if (selected.isEmpty) {
      yield {};
      return;
    }
    final filtered = buildDatabaseRowsQuery(
      databaseId,
      columns,
      filters: filters,
      search: search,
      allFiltered: true,
    );
    final variables = [...filtered.variables];
    String bind(String value) {
      variables.add(Variable<String>(value));
      return '?${variables.length}';
    }

    final parts = <String>[];
    for (final column in selected) {
      final id = bind(column.id);
      final path = column.type == 'title'
          ? ''
          : bind('\$.${jsonEncode(column.id)}');
      const properties =
          "CASE WHEN json_valid(p.properties) THEN p.properties ELSE '{}' END";
      final value = column.type == 'title'
          ? 'p.title'
          : 'json_extract($properties, $path)';
      final type = column.type == 'title'
          ? "'text'"
          : 'json_type($properties, $path)';
      parts.add(
        'SELECT $id AS column_id, $type AS value_type, $value AS value, COUNT(*) AS frequency FROM filtered p GROUP BY $type, $value',
      );
    }
    yield* customSelect(
      'WITH filtered AS (${filtered.sql}) ${parts.join(' UNION ALL ')}',
      variables: variables,
      readsFrom: {pages, databases, databaseColumns},
    ).watch().map((records) {
      final groups = <String, List<DatabaseValueGroup>>{
        for (final col in selected) col.id: [],
      };
      for (final row in records) {
        final type = row.data['value_type'];
        dynamic value = row.data['value'];
        if (type == 'true') {
          value = true;
        } else if (type == 'false') {
          value = false;
        } else if ((type == 'array' || type == 'object') && value is String) {
          value = jsonDecode(value);
        }
        groups[row.read<String>('column_id')]!.add(
          DatabaseValueGroup(value, row.read<int>('frequency')),
        );
      }
      return groups;
    });
  }

  Future<void> compareAndSetDatabaseCell(
    String pageId,
    String columnId,
    dynamic value,
    dynamic expected, {
    required bool title,
  }) => transaction(() async {
    final row = await db.pagesDao.getPageById(pageId);
    if (row == null || row.databaseId == null || row.trashedAt != null) {
      throw StateError('Cannot edit a missing or trashed row');
    }
    final database = await db.databasesDao.getDatabaseById(row.databaseId!);
    if (database == null || database.trashedAt != null) {
      throw StateError('Missing database');
    }
    final columns = await db.databasesDao.getColumnsForDatabase(row.databaseId!);
    final column = columns.where((col) => col.id == columnId).firstOrNull;
    if (column == null || (column.type == 'title') != title) {
      throw StateError('Missing or changed column');
    }
    final properties = row.properties == null
        ? <String, dynamic>{}
        : jsonDecode(row.properties!) as Map<String, dynamic>;
    if (column.type == 'number') {
      final parsed = parseNumericCellInput(
        value,
        format: numericColumnFormat(column.options),
      );
      if (!parsed.valid) throw NumericCellValidationException(parsed.issue!);
      // Interactive writers must submit canonical numbers, never raw strings.
      if (value != null && value is! num) {
        throw NumericCellValidationException(
          numericColumnFormat(column.options).startsWith('duration')
              ? NumericInputIssue.duration
              : NumericInputIssue.number,
        );
      }
    }
    final current = title ? row.title : properties[columnId];
    if (jsonEncode(current) != jsonEncode(expected) &&
        jsonEncode(current) != jsonEncode(value)) {
      throw DatabaseCellConflict(current);
    }
    if (title) {
      await db.pagesDao.updatePageTitle(pageId, value as String);
    } else {
      await patchRowProperties(pageId, {columnId: value});
    }
  });

  /// Validate the complete range before writing. The outer transaction also
  /// rolls back sync outbox triggers and Unicode search projections on failure.
  Future<void> applyDatabaseCellChanges(
    List<DatabaseCellChange> changes, {
    bool undo = false,
  }) => transaction(() async {
    if (changes.isEmpty) return;
    if (changes.length > databasePasteMaxCells ||
        changes.map((c) => c.databaseId).toSet().length != 1) {
      throw const DatabasePasteException(DatabasePasteIssue.tooLarge);
    }
    final databaseId = changes.first.databaseId;
    final database = await db.databasesDao.getDatabaseById(databaseId);
    if (database == null || database.trashedAt != null) {
      throw const DatabasePasteException(DatabasePasteIssue.conflict);
    }
    final columns = {
      for (final c in await db.databasesDao.getColumnsForDatabase(databaseId))
        c.id: c,
    };
    final snapshots = <String, Page>{};
    final properties = <String, Map<String, dynamic>>{};
    final seen = <(String, String)>{};
    for (final change in changes) {
      final column = columns[change.column.id];
      if (!seen.add((change.rowId, change.column.id)) ||
          column == null ||
          column.type != change.column.type ||
          column.options != change.column.options) {
        throw const DatabasePasteException(DatabasePasteIssue.conflict);
      }
      var row = snapshots[change.rowId];
      if (row == null) {
        row = await db.pagesDao.getPageById(change.rowId);
        if (row == null ||
            row.databaseId != databaseId ||
            row.trashedAt != null) {
          throw const DatabasePasteException(DatabasePasteIssue.conflict);
        }
        snapshots[change.rowId] = row;
        properties[change.rowId] = row.properties == null
            ? {}
            : (jsonDecode(row.properties!) as Map).cast<String, dynamic>();
      }
      final current = column.type == 'title'
          ? row.title
          : properties[change.rowId]![column.id];
      if (jsonEncode(current) !=
          jsonEncode(undo ? change.after : change.before)) {
        throw const DatabasePasteException(DatabasePasteIssue.conflict);
      }
      if (!undo && !validDatabasePasteValue(column, change.after)) {
        throw const DatabasePasteException(DatabasePasteIssue.unsupported);
      }
    }
    for (final rowId in snapshots.keys) {
      final patch = <String, dynamic>{};
      for (final change in changes.where((c) => c.rowId == rowId)) {
        final value = undo ? change.before : change.after;
        if (change.column.type == 'title') {
          await db.pagesDao.updatePageTitle(rowId, value as String);
        } else {
          patch[change.column.id] = value;
        }
      }
      if (patch.isNotEmpty) await patchRowProperties(rowId, patch);
    }
  });

  /// Merge only the supplied column values into the latest stored row.
  /// Null clears a cell; arrays are replaced as values, not merged elementwise.
  Future<void> patchRowProperties(
    String pageId,
    Map<String, dynamic> changes,
  ) async {
    // Detach mutable inputs before waiting for another transaction.
    final patch = (jsonDecode(jsonEncode(changes)) as Map)
        .cast<String, dynamic>();
    if (patch.isEmpty) return;
    await transaction(() async {
      final row = await db.pagesDao.getPageById(pageId);
      if (row == null || row.trashedAt != null || row.databaseId == null) {
        throw StateError(
          'Cannot patch a missing, trashed, or non-database row',
        );
      }
      final database = await db.databasesDao.getDatabaseById(row.databaseId!);
      if (database == null || database.trashedAt != null) {
        throw StateError('Cannot patch a row in a missing or trashed database');
      }
      final columns = await db.databasesDao.getColumnsForDatabase(row.databaseId!);
      final writableIds = columns
          .where((c) => c.type != 'title')
          .map((c) => c.id)
          .toSet();
      if (patch.keys.any((key) => !writableIds.contains(key))) {
        throw ArgumentError(
          'Properties must belong to writable columns of this database',
        );
      }
      final Map<String, dynamic> current;
      if (row.properties == null) {
        current = {};
      } else {
        final decoded = jsonDecode(row.properties!);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Row properties must be a JSON object');
        }
        current = decoded;
      }
      current.addAll(patch);
      await replaceRowProperties(pageId, jsonEncode(current));
    });
  }

  /// Full replacement for explicit bulk operations; cell edits use a patch.
  Future<void> replaceRowProperties(String pageId, String propertiesJson) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(
        properties: Value(propertiesJson),
        propertiesFolded: Value(foldProperties(propertiesJson)),
      ),
    );
  }
}

import 'package:drift/drift.dart';

import '../app_database.dart';

class DatabasesDao extends DatabaseAccessor<AppDatabase> {
  DatabasesDao(super.db);

  $DatabasesTable get databases => db.databases;
  $DatabaseColumnsTable get databaseColumns => db.databaseColumns;

  Future<List<Database>> getAllDatabases() => select(databases).get();

  Future<List<DatabaseColumn>> getAllDatabaseColumns() =>
      select(databaseColumns).get();

  Future<void> upsertDatabase(DatabasesCompanion database) =>
      into(databases).insertOnConflictUpdate(database);

  Future<Database?> getDatabaseById(String id) =>
      (select(databases)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<Database?> watchDatabase(String id) =>
      (select(databases)..where((tbl) => tbl.id.equals(id)))
          .watchSingleOrNull();

  Future<void> updateDatabaseTitle(String id, String title) =>
      (update(databases)..where((tbl) => tbl.id.equals(id))).write(
        DatabasesCompanion(title: Value(title)),
      );

  Future<void> updateDatabaseIcon(String id, String? icon) =>
      (update(databases)..where((tbl) => tbl.id.equals(id))).write(
        DatabasesCompanion(icon: Value(icon)),
      );

  Future<void> upsertDatabaseColumn(DatabaseColumnsCompanion column) =>
      into(databaseColumns).insertOnConflictUpdate(column);

  Future<void> updateDatabaseColumn(
    String columnId,
    DatabaseColumnsCompanion companion,
  ) => (update(
    databaseColumns,
  )..where((tbl) => tbl.id.equals(columnId))).write(companion);

  Future<List<DatabaseColumn>> getColumnsForDatabase(String databaseId) {
    return (select(databaseColumns)
          ..where((tbl) => tbl.databaseId.equals(databaseId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.orderKey)]))
        .get();
  }

  Stream<List<DatabaseColumn>> watchColumnsForDatabase(String databaseId) {
    return (select(databaseColumns)
          ..where((tbl) => tbl.databaseId.equals(databaseId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.orderKey)]))
        .watch();
  }

  Future<void> deleteDatabaseColumn(String columnId) =>
      (delete(databaseColumns)..where((tbl) => tbl.id.equals(columnId))).go();
}

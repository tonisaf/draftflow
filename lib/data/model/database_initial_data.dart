import '../db/app_database.dart';
import 'database_query.dart';

/// The first bounded viewport of a database, prepared before showing a page.
/// Live streams take over immediately after the editor mounts.
class DatabaseInitialData {
  const DatabaseInitialData({
    required this.database,
    required this.columns,
    required this.rows,
  });
  final Database? database;
  final List<DatabaseColumn> columns;
  final DatabaseRowsPage rows;
}

import 'package:drift/drift.dart';

class Databases extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('Untitled Database'))();
  TextColumn get icon => text().nullable()();
  TextColumn get parentPageId => text().nullable()(); // null if standalone full-page database
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get trashedAt => dateTime().nullable()();
  TextColumn get trashBatchId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'database_columns_order', columns: {#databaseId, #orderKey})
class DatabaseColumns extends Table {
  TextColumn get id => text()();
  TextColumn get databaseId => text().references(Databases, #id)();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'title', 'text', 'number', 'select', 'multi_select', 'status', 'checkbox', 'date', 'url'
  TextColumn get options => text().nullable()(); // JSON string for select tags, colors, number formats
  RealColumn get width => real().withDefault(const Constant(160.0))(); // Column width in px
  TextColumn get orderKey => text()(); // Fractional indexing order
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'pages_database_order', columns: {#databaseId, #trashedAt, #orderKey, #createdAt, #id})
@TableIndex(name: 'pages_parent_order', columns: {#parentId, #trashedAt, #orderKey})
class Pages extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get parentId => text().nullable()(); // null for root pages
  TextColumn get icon => text().nullable()(); // optional emoji or icon identifier
  TextColumn get cover => text().nullable()(); // optional cover preset or color
  TextColumn get orderKey => text().nullable()(); // optional fractional order key
  TextColumn get databaseId => text().nullable().references(Databases, #id)(); // if this page is a row inside a database
  TextColumn get properties => text().nullable()(); // Row values {col_id: value}; normal pages may store namespaced page settings.
  TextColumn get titleFolded => text().nullable()();
  TextColumn get propertiesFolded => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get trashedAt => dateTime().nullable()();
  TextColumn get trashBatchId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'blocks_page_order', columns: {#pageId, #trashedAt, #orderKey, #id})
class Blocks extends Table {
  TextColumn get id => text()();
  TextColumn get pageId => text().references(Pages, #id)();
  TextColumn get parentId => text().nullable()(); // null for root blocks
  TextColumn get type => text()(); // 'text', 'h1', 'todo', 'code', 'database', etc.
  TextColumn get content => text()(); // JSON string of block attributes/content
  TextColumn get orderKey => text()(); // String key from fractional_indexing
  DateTimeColumn get trashedAt => dateTime().nullable()();
  TextColumn get trashBatchId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class EditorDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get pageId => text()();
  TextColumn get baseVersion => text()();
  TextColumn get content => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

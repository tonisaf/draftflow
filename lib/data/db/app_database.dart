import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../sync/sync_outbox.dart';
import '../model/database_paste.dart';
import '../model/database_query.dart';
import '../model/trash_entry.dart';
import 'daos/blocks_dao.dart';
import 'daos/dao_shared.dart';
import 'daos/database_rows_dao.dart';
import 'daos/databases_dao.dart';
import 'daos/pages_dao.dart';
import 'daos/trash_dao.dart';
import 'tables.dart';

export 'daos/blocks_dao.dart';
export 'daos/dao_shared.dart';
export 'daos/database_rows_dao.dart';
export 'daos/databases_dao.dart';
export 'daos/pages_dao.dart';
export 'daos/trash_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Pages, Blocks, Databases, DatabaseColumns, EditorDrafts],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 11;

  /// Auth identity only, never an email or an arbitrary filesystem path.
  static String accountDatabaseName(String accountId) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(accountId)) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Expected an auth UUID',
      );
    }
    return 'notes_here_account_${accountId.toLowerCase()}';
  }

  factory AppDatabase.forAccount(String accountId) =>
      AppDatabase(driftDatabase(name: accountDatabaseName(accountId)));

  late final PagesDao pagesDao = PagesDao(this);
  late final BlocksDao blocksDao = BlocksDao(this);
  late final DatabasesDao databasesDao = DatabasesDao(this);
  late final DatabaseRowsDao databaseRowsDao = DatabaseRowsDao(this);
  late final TrashDao trashDao = TrashDao(this);

  // Singular convenience getters
  PagesDao get pageDao => pagesDao;
  BlocksDao get blockDao => blocksDao;
  DatabasesDao get databaseDao => databasesDao;
  DatabaseRowsDao get databaseRowDao => databaseRowsDao;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await installSyncStorage(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(pages, pages.parentId);
        await m.addColumn(pages, pages.icon);
      }
      if (from < 3) {
        await m.addColumn(pages, pages.cover);
      }
      if (from < 4) {
        await m.addColumn(pages, pages.orderKey);
      }
      if (from < 5) {
        await m.createTable(databases);
        await m.createTable(databaseColumns);
        await m.addColumn(pages, pages.databaseId);
        await m.addColumn(pages, pages.properties);
      }
      if (from < 6) {
        await m.createTable(editorDrafts);
      }
      if (from < 7) {
        // Newly created tables already contain their latest columns.
        await m.addColumn(pages, pages.trashBatchId);
        await m.addColumn(blocks, blocks.trashBatchId);
        if (from >= 5) await m.addColumn(databases, databases.trashBatchId);
      }
      if (from < 8) await normalizeLegacyBlocks();
      if (from < 9) {
        await m.addColumn(pages, pages.titleFolded);
        await m.addColumn(pages, pages.propertiesFolded);
        await refreshRowSearchData();
        await m.createIndex(pagesDatabaseOrder);
        await m.createIndex(pagesParentOrder);
        await m.createIndex(blocksPageOrder);
        await m.createIndex(databaseColumnsOrder);
      }
      if (from < 11) await installSyncStorage(this);
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'notes_here_db');
  }

  // --------------------------------------------------------------------------
  // Pages
  // --------------------------------------------------------------------------

  Future<void> upsertPage(PagesCompanion page) => pagesDao.upsertPage(page);

  Future<void> refreshRowSearchData() => pagesDao.refreshRowSearchData();

  Stream<List<Page>> watchActivePages() => pagesDao.watchActivePages();

  Stream<List<Page>> watchTrashedPages() => trashDao.watchTrashedPages();

  Future<Page?> getPageById(String pageId) => pagesDao.getPageById(pageId);

  Stream<Page?> watchPageById(String pageId) => pagesDao.watchPageById(pageId);

  Future<List<PageMatchRecord>> searchPagesWithMatches(String query) =>
      pagesDao.searchPagesWithMatches(query);

  Future<List<Page>> searchPages(String query) => pagesDao.searchPages(query);

  Future<List<Page>> getBacklinksForPage(String targetPageId) =>
      pagesDao.getBacklinksForPage(targetPageId);

  Future<void> updatePageTitle(String pageId, String title) =>
      pagesDao.updatePageTitle(pageId, title);

  Future<void> updatePageParent(String pageId, String? parentId) =>
      pagesDao.updatePageParent(pageId, parentId);

  Future<void> updatePageParentAndOrder(
    String pageId,
    String? parentId,
    String? orderKey,
  ) => pagesDao.updatePageParentAndOrder(pageId, parentId, orderKey);

  Future<void> updatePageIcon(String pageId, String? icon) =>
      pagesDao.updatePageIcon(pageId, icon);

  Future<void> updatePageCover(String pageId, String? cover) =>
      pagesDao.updatePageCover(pageId, cover);

  Future<List<Page>> getAllPages() => pagesDao.getAllPages();

  // --------------------------------------------------------------------------
  // Trash & Ownership
  // --------------------------------------------------------------------------

  Stream<List<TrashEntry>> watchTrashEntries() => trashDao.watchTrashEntries();

  Stream<List<Database>> watchTrashedDatabases() =>
      trashDao.watchTrashedDatabases();

  Future<void> trashPage(String pageId) => trashDao.trashPage(pageId);

  Future<void> trashDatabase(String id) => trashDao.trashDatabase(id);

  Future<void> restorePage(String pageId) => trashDao.restorePage(pageId);

  Future<void> restoreDatabase(String id) => trashDao.restoreDatabase(id);

  Future<void> permanentlyDeletePage(String pageId) =>
      trashDao.permanentlyDeletePage(pageId);

  Future<void> deleteDatabasePermanently(String id) =>
      trashDao.deleteDatabasePermanently(id);

  Future<void> emptyTrash() => trashDao.emptyTrash();

  Future<void> restoreWorkspaceData({
    required List<PagesCompanion> pagesList,
    required List<BlocksCompanion> blocksList,
    required List<DatabasesCompanion> databasesList,
    required List<DatabaseColumnsCompanion> columnsList,
    bool wipeExisting = false,
  }) => trashDao.restoreWorkspaceData(
    pagesList: pagesList,
    blocksList: blocksList,
    databasesList: databasesList,
    columnsList: columnsList,
    wipeExisting: wipeExisting,
  );

  // --------------------------------------------------------------------------
  // Blocks
  // --------------------------------------------------------------------------

  Future<List<Block>> getAllBlocks() => blocksDao.getAllBlocks();

  Future<void> insertBlocksBatch(List<BlocksCompanion> blockList) =>
      blocksDao.insertBlocksBatch(blockList);

  Future<String> savePageBlockChanges(
    String pageId,
    List<BlockWrite> desired, {
    String? expectedVersion,
  }) => blocksDao.savePageBlockChanges(
    pageId,
    desired,
    expectedVersion: expectedVersion,
  );

  Future<void> normalizeLegacyBlocks() => blocksDao.normalizeLegacyBlocks();

  Future<({List<Block> blocks, String version})> getPageBlocksSnapshot(
    String pageId,
  ) => blocksDao.getPageBlocksSnapshot(pageId);

  Future<List<Block>> getBlocksForPage(String pageId) =>
      blocksDao.getBlocksForPage(pageId);

  Future<void> deletePageBlocks(String pageId) =>
      blocksDao.deletePageBlocks(pageId);

  // --------------------------------------------------------------------------
  // Databases & Columns
  // --------------------------------------------------------------------------

  Future<List<Database>> getAllDatabases() => databasesDao.getAllDatabases();

  Future<List<DatabaseColumn>> getAllDatabaseColumns() =>
      databasesDao.getAllDatabaseColumns();

  Future<void> upsertDatabase(DatabasesCompanion database) =>
      databasesDao.upsertDatabase(database);

  Future<Database?> getDatabaseById(String id) =>
      databasesDao.getDatabaseById(id);

  Stream<Database?> watchDatabase(String id) => databasesDao.watchDatabase(id);

  Future<void> updateDatabaseTitle(String id, String title) =>
      databasesDao.updateDatabaseTitle(id, title);

  Future<void> updateDatabaseIcon(String id, String? icon) =>
      databasesDao.updateDatabaseIcon(id, icon);

  Future<void> upsertDatabaseColumn(DatabaseColumnsCompanion column) =>
      databasesDao.upsertDatabaseColumn(column);

  Future<void> updateDatabaseColumn(
    String columnId,
    DatabaseColumnsCompanion companion,
  ) => databasesDao.updateDatabaseColumn(columnId, companion);

  Future<List<DatabaseColumn>> getColumnsForDatabase(String databaseId) =>
      databasesDao.getColumnsForDatabase(databaseId);

  Stream<List<DatabaseColumn>> watchColumnsForDatabase(String databaseId) =>
      databasesDao.watchColumnsForDatabase(databaseId);

  Future<void> deleteDatabaseColumn(String columnId) =>
      databasesDao.deleteDatabaseColumn(columnId);

  // --------------------------------------------------------------------------
  // Database Rows & Cells
  // --------------------------------------------------------------------------

  Future<List<Page>> getDatabaseRows(String databaseId) =>
      databaseRowsDao.getDatabaseRows(databaseId);

  Stream<List<Page>> watchDatabaseRows(String databaseId) =>
      databaseRowsDao.watchDatabaseRows(databaseId);

  Future<DatabaseRowsPage> queryDatabaseRows(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) => databaseRowsDao.queryDatabaseRows(
    databaseId,
    sort: sort,
    filters: filters,
    search: search,
    offset: offset,
    limit: limit,
  );

  Stream<DatabaseRowsPage> watchDatabaseRowsPage(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) => databaseRowsDao.watchDatabaseRowsPage(
    databaseId,
    sort: sort,
    filters: filters,
    search: search,
    offset: offset,
    limit: limit,
  );

  Stream<Map<String, List<DatabaseValueGroup>>> watchDatabaseSummaryGroups(
    String databaseId,
    Set<String> columnIds, {
    List<DatabaseFilterRule> filters = const [],
    String search = '',
  }) => databaseRowsDao.watchDatabaseSummaryGroups(
    databaseId,
    columnIds,
    filters: filters,
    search: search,
  );

  Future<void> compareAndSetDatabaseCell(
    String pageId,
    String columnId,
    dynamic value,
    dynamic expected, {
    required bool title,
  }) => databaseRowsDao.compareAndSetDatabaseCell(
    pageId,
    columnId,
    value,
    expected,
    title: title,
  );

  Future<void> applyDatabaseCellChanges(
    List<DatabaseCellChange> changes, {
    bool undo = false,
  }) => databaseRowsDao.applyDatabaseCellChanges(changes, undo: undo);

  Future<void> patchRowProperties(
    String pageId,
    Map<String, dynamic> changes,
  ) => databaseRowsDao.patchRowProperties(pageId, changes);

  Future<void> replaceRowProperties(String pageId, String propertiesJson) =>
      databaseRowsDao.replaceRowProperties(pageId, propertiesJson);
}

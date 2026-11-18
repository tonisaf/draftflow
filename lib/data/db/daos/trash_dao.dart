import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../model/trash_entry.dart';
import '../app_database.dart';
import 'dao_shared.dart';

typedef _OwnedIds = ({Set<String> pages, Set<String> databases});

/// Ownership comes from parentId / parentPageId / databaseId. Page links and
/// linked table blocks are references and do not transfer ownership.
class _OwnershipTree {
  _OwnershipTree(List<Page> pages, List<Database> databases) {
    for (final page in pages) {
      pagesById[page.id] = page;
      if (page.parentId != null) {
        children.putIfAbsent(page.parentId!, () => []).add(page.id);
      }
      if (page.databaseId != null) {
        rows.putIfAbsent(page.databaseId!, () => []).add(page.id);
      }
    }
    for (final database in databases) {
      databasesById[database.id] = database;
      if (database.parentPageId != null) {
        embedded.putIfAbsent(database.parentPageId!, () => []).add(database.id);
      }
    }
  }
  final pagesById = <String, Page>{};
  final databasesById = <String, Database>{};
  final children = <String, List<String>>{};
  final rows = <String, List<String>>{};
  final embedded = <String, List<String>>{};

  _OwnedIds collect({
    Iterable<String> pageIds = const [],
    Iterable<String> databaseIds = const [],
    bool Function(Page)? includePage,
    bool Function(Database)? includeDatabase,
  }) {
    final pageSet = <String>{};
    final databaseSet = <String>{};
    final queue = <(String, bool)>[
      for (final id in pageIds) (id, false),
      for (final id in databaseIds) (id, true),
    ];
    for (var i = 0; i < queue.length; i++) {
      final (id, isDatabase) = queue[i];
      if (isDatabase) {
        final database = databasesById[id];
        if (database == null ||
            (includeDatabase != null && !includeDatabase(database)) ||
            !databaseSet.add(id)) {
          continue;
        }
        queue.addAll((rows[id] ?? []).map((id) => (id, false)));
      } else {
        final page = pagesById[id];
        if (page == null ||
            (includePage != null && !includePage(page)) ||
            !pageSet.add(id)) {
          continue;
        }
        queue.addAll((children[id] ?? []).map((id) => (id, false)));
        queue.addAll((embedded[id] ?? []).map((id) => (id, true)));
      }
    }
    return (pages: pageSet, databases: databaseSet);
  }
}

class TrashDao extends DatabaseAccessor<AppDatabase> {
  TrashDao(super.db);

  $PagesTable get pages => db.pages;
  $BlocksTable get blocks => db.blocks;
  $DatabasesTable get databases => db.databases;
  $DatabaseColumnsTable get databaseColumns => db.databaseColumns;
  $EditorDraftsTable get editorDrafts => db.editorDrafts;

  /// One reactive query avoids a lookup per trash row and observes parent
  /// renames as well as restore/delete actions.
  Stream<List<TrashEntry>> watchTrashEntries() =>
      customSelect(
        '''
    SELECT p.id AS id, p.title, p.icon, 0 AS is_database,
           p.trashed_at AS deleted_at,
           COALESCE(container.title, parent.title) AS parent_title
    FROM pages p
    LEFT JOIN databases container ON container.id = p.database_id
    LEFT JOIN pages parent ON parent.id = p.parent_id
    WHERE p.trashed_at IS NOT NULL
    UNION ALL
    SELECT d.id, d.title, d.icon, 1 AS is_database,
           d.trashed_at AS deleted_at, parent.title AS parent_title
    FROM databases d
    LEFT JOIN pages parent ON parent.id = d.parent_page_id
    WHERE d.trashed_at IS NOT NULL
    ORDER BY deleted_at DESC, is_database DESC, id
    ''',
        readsFrom: {pages, databases},
      ).watch().map(
        (rows) => [
          for (final row in rows)
            TrashEntry(
              id: row.read<String>('id'),
              title: row.read<String>('title'),
              icon: row.readNullable<String>('icon'),
              isDatabase: row.read<int>('is_database') != 0,
              deletedAt: row.read<DateTime>('deleted_at'),
              parentTitle: row.readNullable<String>('parent_title'),
            ),
        ],
      );

  Stream<List<Page>> watchTrashedPages() {
    return (select(pages)
          ..where((tbl) => tbl.trashedAt.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.trashedAt)]))
        .watch();
  }

  Stream<List<Database>> watchTrashedDatabases() =>
      (select(databases)
            ..where((t) => t.trashedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.trashedAt)]))
          .watch();

  Future<_OwnershipTree> _ownershipTree() async =>
      _OwnershipTree(await db.pagesDao.getAllPages(), await db.databasesDao.getAllDatabases());

  Future<void> trashPage(String pageId) => _trashTree(pageId: pageId);

  Future<void> trashDatabase(String id) => _trashTree(databaseId: id);

  Future<void> _trashTree({
    String? pageId,
    String? databaseId,
  }) => transaction(() async {
    final tree = await _ownershipTree();
    final owned = tree.collect(
      pageIds: pageId == null ? const [] : [pageId],
      databaseIds: databaseId == null ? const [] : [databaseId],
      includePage: (p) => p.trashedAt == null,
      includeDatabase: (d) => d.trashedAt == null,
    );
    final batchId = const Uuid().v4();
    final now = DateTime.now();
    for (final ids in chunks(owned.pages)) {
      await (update(pages)..where((t) => t.id.isIn(ids))).write(
        PagesCompanion(trashedAt: Value(now), trashBatchId: Value(batchId)),
      );
      await (update(
        blocks,
      )..where((t) => t.pageId.isIn(ids) & t.trashedAt.isNull())).write(
        BlocksCompanion(trashedAt: Value(now), trashBatchId: Value(batchId)),
      );
    }
    for (final ids in chunks(owned.databases)) {
      await (update(databases)..where((t) => t.id.isIn(ids))).write(
        DatabasesCompanion(trashedAt: Value(now), trashBatchId: Value(batchId)),
      );
    }
  });

  Future<void> restorePage(String pageId) => _restoreTree(pageId: pageId);

  Future<void> restoreDatabase(String id) => _restoreTree(databaseId: id);

  Future<void> _restoreTree({String? pageId, String? databaseId}) =>
      transaction(() async {
        final tree = await _ownershipTree();
        final visited = <String>{};
        final visiting = <String>{};

        Future<void> restore(String id, bool isDatabase) async {
          final key = '${isDatabase ? 'database' : 'page'}:$id';
          if (visited.contains(key)) return;
          if (!visiting.add(key)) throw StateError('Cycle in page ownership');
          final page = isDatabase ? null : tree.pagesById[id];
          final database = isDatabase ? tree.databasesById[id] : null;
          if (page == null && database == null) {
            throw StateError('Cannot restore an object whose owner is missing');
          }
          if (page?.parentId != null) await restore(page!.parentId!, false);
          if (page?.databaseId != null) await restore(page!.databaseId!, true);
          if (database?.parentPageId != null) {
            await restore(database!.parentPageId!, false);
          }

          final deletedAt = page?.trashedAt ?? database?.trashedAt;
          final batchId = page?.trashBatchId ?? database?.trashBatchId;
          if (deletedAt != null) {
            final owned = tree.collect(
              pageIds: isDatabase ? const [] : [id],
              databaseIds: isDatabase ? [id] : const [],
              // Legacy trash has no batch: restore only its requested root.
              includePage: (p) =>
                  p.trashedAt == null ||
                  (batchId != null
                      ? p.trashBatchId == batchId
                      : !isDatabase && p.id == id),
              includeDatabase: (d) =>
                  d.trashedAt == null ||
                  (batchId != null
                      ? d.trashBatchId == batchId
                      : isDatabase && d.id == id),
            );
            for (final ids in chunks(owned.pages)) {
              await (update(pages)..where((t) => t.id.isIn(ids))).write(
                const PagesCompanion(
                  trashedAt: Value(null),
                  trashBatchId: Value(null),
                ),
              );
              if (batchId != null) {
                await (update(blocks)..where(
                      (t) =>
                          t.pageId.isIn(ids) & t.trashBatchId.equals(batchId),
                    ))
                    .write(
                      const BlocksCompanion(
                        trashedAt: Value(null),
                        trashBatchId: Value(null),
                      ),
                    );
              }
            }
            for (final ids in chunks(owned.databases)) {
              await (update(databases)..where((t) => t.id.isIn(ids))).write(
                const DatabasesCompanion(
                  trashedAt: Value(null),
                  trashBatchId: Value(null),
                ),
              );
            }
          }
          visiting.remove(key);
          visited.add(key);
        }

        if (pageId != null) await restore(pageId, false);
        if (databaseId != null) await restore(databaseId, true);
      });

  Future<void> permanentlyDeletePage(String pageId) => transaction(() async {
    final tree = await _ownershipTree();
    await _deleteOwned(tree.collect(pageIds: [pageId]));
  });

  Future<void> deleteDatabasePermanently(String id) => transaction(() async {
    final tree = await _ownershipTree();
    await _deleteOwned(tree.collect(databaseIds: [id]));
  });

  Future<void> _deleteOwned(_OwnedIds owned) async {
    for (final ids in chunks(owned.pages)) {
      await (delete(blocks)..where((t) => t.pageId.isIn(ids))).go();
      await (delete(editorDrafts)..where((t) => t.pageId.isIn(ids))).go();
      await (delete(pages)..where((t) => t.id.isIn(ids))).go();
    }
    for (final ids in chunks(owned.databases)) {
      await (delete(
        databaseColumns,
      )..where((t) => t.databaseId.isIn(ids))).go();
      await (delete(databases)..where((t) => t.id.isIn(ids))).go();
    }
  }

  Future<void> emptyTrash() => transaction(() async {
    final tree = await _ownershipTree();
    await _deleteOwned(
      tree.collect(
        pageIds: tree.pagesById.values
            .where((p) => p.trashedAt != null)
            .map((p) => p.id),
        databaseIds: tree.databasesById.values
            .where((d) => d.trashedAt != null)
            .map((d) => d.id),
      ),
    );
  });

  Future<void> restoreWorkspaceData({
    required List<PagesCompanion> pagesList,
    required List<BlocksCompanion> blocksList,
    required List<DatabasesCompanion> databasesList,
    required List<DatabaseColumnsCompanion> columnsList,
    bool wipeExisting = false,
  }) async {
    await transaction(() async {
      if (wipeExisting) {
        await delete(blocks).go();
        await delete(databaseColumns).go();
        await delete(databases).go();
        await delete(pages).go();
      }
      if (databasesList.isNotEmpty) {
        await batch(
          (b) => b.insertAllOnConflictUpdate(databases, databasesList),
        );
      }
      if (columnsList.isNotEmpty) {
        await batch(
          (b) => b.insertAllOnConflictUpdate(databaseColumns, columnsList),
        );
      }
      if (pagesList.isNotEmpty) {
        await batch(
          (b) => b.insertAllOnConflictUpdate(
            pages,
            pagesList.map(db.pagesDao.withSearchFields).toList(),
          ),
        );
      }
      if (blocksList.isNotEmpty) {
        await batch((b) => b.insertAllOnConflictUpdate(blocks, blocksList));
      }
      await db.blocksDao.normalizeLegacyBlocks();
    });
  }
}

import '../model/trash_entry.dart';
import '../model/database_paste.dart';
import '../model/numeric_cell_input.dart';
import '../model/database_cell_conflict.dart';

import 'dart:convert';

import '../../sync/sync_outbox.dart';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/extensions/native.dart';

import 'tables.dart';
import 'database_rows_query.dart';
import '../model/block_ordering.dart';
import '../model/block_codec.dart';
import '../model/database_query.dart';
import '../search/fuzzy_matcher.dart';

import 'package:fractional_indexing/fractional_indexing.dart';

import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

class DocumentConflictException implements Exception {
  final String pageId;
  const DocumentConflictException(this.pageId);
}

class PageMatchRecord {
  final Page page;
  final String? snippet;
  final bool isContentMatch;
  final bool isFuzzyMatch;
  final String? matchedTerm;
  final int score;

  const PageMatchRecord({
    required this.page,
    this.snippet,
    this.isContentMatch = false,
    this.isFuzzyMatch = false,
    this.matchedTerm,
    this.score = 0,
  });
}

String _extractPlainBlockText(String rawContent) {
  if (rawContent.isEmpty) return '';
  try {
    final decoded = jsonDecode(rawContent);
    if (decoded is Map) {
      final data = decoded['data'] ?? decoded['attributes'] ?? decoded;
      if (data is Map && data['delta'] != null) {
        return _extractDeltaText(data['delta']);
      }
    } else if (decoded is List) {
      return _extractDeltaText(decoded);
    }
  } catch (_) {
    return rawContent;
  }
  return '';
}

String _extractDeltaText(dynamic delta) {
  if (delta is List) {
    final sb = StringBuffer();
    for (final op in delta) {
      if (op is Map && op['insert'] != null) {
        sb.write(op['insert']);
      }
    }
    return sb.toString();
  } else if (delta is String) {
    return delta;
  }
  return '';
}

String? _extractSnippetAround(String fullText, String query, {int radius = 40}) {
  if (fullText.trim().isEmpty || query.trim().isEmpty) return null;
  final lowerText = fullText.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final idx = lowerText.indexOf(lowerQuery);
  if (idx == -1) return null;

  final start = (idx - radius).clamp(0, fullText.length);
  final end = (idx + query.length + radius).clamp(0, fullText.length);

  var sub = fullText.substring(start, end).replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  if (start > 0) sub = '...$sub';
  if (end < fullText.length) sub = '$sub...';
  return sub;
}

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

  Future<void> upsertPage(PagesCompanion page) =>
      into(pages).insertOnConflictUpdate(_withSearchFields(page));

  PagesCompanion _withSearchFields(PagesCompanion page) => page.copyWith(
    titleFolded: page.title.present
        ? Value(page.title.value.toLowerCase())
        : const Value.absent(),
    propertiesFolded: page.properties.present
        ? Value(foldProperties(page.properties.value))
        : const Value.absent(),
  );

  Future<void> refreshRowSearchData() async {
    final stored = await getAllPages();
    await batch((batch) {
      for (final page in stored) {
        batch.update(
          pages,
          PagesCompanion(
            titleFolded: Value(page.title.toLowerCase()),
            propertiesFolded: Value(foldProperties(page.properties)),
          ),
          where: (t) => t.id.equals(page.id),
        );
      }
    });
  }

  Stream<List<Page>> watchActivePages() {
    return (select(pages)
          ..where((tbl) => tbl.trashedAt.isNull() & tbl.databaseId.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.orderKey),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
  }

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

  Future<Page?> getPageById(String pageId) {
    return (select(
      pages,
    )..where((tbl) => tbl.id.equals(pageId))).getSingleOrNull();
  }

  Stream<Page?> watchPageById(String pageId) {
    return (select(
      pages,
    )..where((tbl) => tbl.id.equals(pageId))).watchSingleOrNull();
  }

  Future<List<PageMatchRecord>> searchPagesWithMatches(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      final recent = await (select(pages)
            ..where((tbl) => tbl.trashedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(25))
          .get();
      return recent.map((p) => PageMatchRecord(page: p)).toList();
    }

    final resultMap = <String, PageMatchRecord>{};

    // 1. Search page titles (both folded and Unicode case-insensitive)
    final titleMatches = await (select(pages)
          ..where(
            (tbl) =>
                tbl.trashedAt.isNull() &
                (tbl.titleFolded.contains(clean) |
                 tbl.title.containsCase(clean, caseSensitive: false) |
                 tbl.title.contains(query.trim())),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(40))
        .get();

    for (final page in titleMatches) {
      final lowerTitle = page.title.trim().toLowerCase();
      int score = 70;
      if (lowerTitle == clean) {
        score = 100;
      } else if (lowerTitle.startsWith(clean)) {
        score = 85;
      }
      resultMap[page.id] = PageMatchRecord(
        page: page,
        isContentMatch: false,
        score: score,
      );
    }

    // 2. Search block contents (case-insensitive for Cyrillic and Unicode)
    final words = clean.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    final blockMatches = await (select(blocks)
          ..where((tbl) {
            Expression<bool> contentPredicate =
                tbl.content.containsCase(clean, caseSensitive: false);
            if (words.length > 1) {
              Expression<bool> allWords =
                  tbl.content.containsCase(words[0], caseSensitive: false);
              for (int i = 1; i < words.length; i++) {
                allWords = allWords &
                    tbl.content.containsCase(words[i], caseSensitive: false);
              }
              contentPredicate = contentPredicate | allWords;
            }
            return tbl.trashedAt.isNull() & contentPredicate;
          })
          ..limit(80))
        .get();

    for (final block in blockMatches) {
      final plainText = _extractPlainBlockText(block.content);
      var snippet = _extractSnippetAround(plainText, clean);
      if (snippet == null && words.isNotEmpty) {
        for (final word in words) {
          snippet = _extractSnippetAround(plainText, word);
          if (snippet != null) break;
        }
      }
      if (snippet == null) continue;

      if (resultMap.containsKey(block.pageId)) {
        final existing = resultMap[block.pageId]!;
        if (existing.snippet == null) {
          resultMap[block.pageId] = PageMatchRecord(
            page: existing.page,
            snippet: snippet,
            isContentMatch: existing.isContentMatch,
            isFuzzyMatch: existing.isFuzzyMatch,
            matchedTerm: existing.matchedTerm,
            score: existing.score + 15,
          );
        }
      } else {
        final page = await (select(pages)
              ..where((tbl) => tbl.id.equals(block.pageId) & tbl.trashedAt.isNull()))
            .getSingleOrNull();
        if (page != null) {
          resultMap[page.id] = PageMatchRecord(
            page: page,
            snippet: snippet,
            isContentMatch: true,
            isFuzzyMatch: false,
            score: 40,
          );
        }
      }
    }

    // 3. Phase 2: Fuzzy & Typo tolerance matching on titles
    if (resultMap.length < 25 && clean.length >= 3) {
      final allPages = await (select(pages)
            ..where((tbl) => tbl.trashedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(120))
          .get();

      final queryWords = FuzzyMatcher.tokenize(clean);
      for (final p in allPages) {
        if (resultMap.containsKey(p.id)) continue;
        final titleWords = FuzzyMatcher.tokenize(p.title);
        if (titleWords.isEmpty) continue;

        int bestScore = 0;
        String? bestTerm;
        bool isFuzzy = false;

        for (final qW in queryWords) {
          for (final tW in titleWords) {
            final match = FuzzyMatcher.matchWord(qW, tW);
            if (match != null) {
              int score = 0;
              if (match.isExact) {
                score = 70;
              } else if (match.isPrefix || match.isStem) {
                score = 65;
                isFuzzy = true;
                bestTerm = tW;
              } else if (match.distance == 1) {
                score = 55;
                isFuzzy = true;
                bestTerm = tW;
              } else if (match.distance == 2) {
                score = 45;
                isFuzzy = true;
                bestTerm = tW;
              }
              if (score > bestScore) {
                bestScore = score;
              }
            }
          }
        }

        if (bestScore > 0) {
          resultMap[p.id] = PageMatchRecord(
            page: p,
            isContentMatch: false,
            isFuzzyMatch: isFuzzy,
            matchedTerm: bestTerm,
            score: bestScore,
          );
        }
      }
    }

    // 4. Phase 2: Fuzzy matching on blocks if results are still sparse
    if (resultMap.length < 15 && clean.length >= 4) {
      final recentBlocks = await (select(blocks)
            ..where((tbl) => tbl.trashedAt.isNull())
            ..limit(160))
          .get();

      for (final b in recentBlocks) {
        if (resultMap.containsKey(b.pageId)) continue;
        final plain = _extractPlainBlockText(b.content);
        final fuzzySnippet = FuzzyMatcher.extractFuzzySnippet(plain, clean);
        if (fuzzySnippet != null) {
          final page = await (select(pages)
                ..where((tbl) => tbl.id.equals(b.pageId) & tbl.trashedAt.isNull()))
              .getSingleOrNull();
          if (page != null) {
            resultMap[page.id] = PageMatchRecord(
              page: page,
              snippet: fuzzySnippet.snippet,
              isContentMatch: true,
              isFuzzyMatch: fuzzySnippet.isFuzzy,
              matchedTerm: fuzzySnippet.matchedTerm,
              score: fuzzySnippet.isFuzzy ? 32 : 40,
            );
          }
        }
      }
    }

    final list = resultMap.values.toList();
    list.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return b.page.createdAt.compareTo(a.page.createdAt);
    });

    return list;
  }

  Future<List<Page>> searchPages(String query) async {
    final matches = await searchPagesWithMatches(query);
    return matches.map((m) => m.page).toList();
  }

  Future<List<Page>> getBacklinksForPage(String targetPageId) async {
    final needle = 'page://$targetPageId';
    final referencingBlocks =
        await (select(blocks)..where(
              (tbl) =>
                  tbl.trashedAt.isNull() &
                  tbl.content.contains(needle) &
                  tbl.pageId.equals(targetPageId).not(),
            ))
            .get();

    final pageIds = referencingBlocks.map((b) => b.pageId).toSet();
    if (pageIds.isEmpty) return [];

    return (select(pages)
          ..where((tbl) => tbl.trashedAt.isNull() & tbl.id.isIn(pageIds))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<void> updatePageTitle(String pageId, String title) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(
        title: Value(title),
        titleFolded: Value(title.toLowerCase()),
      ),
    );
  }

  Future<void> updatePageParent(String pageId, String? parentId) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(parentId: Value(parentId)),
    );
  }

  Future<void> updatePageParentAndOrder(
    String pageId,
    String? parentId,
    String? orderKey,
  ) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(parentId: Value(parentId), orderKey: Value(orderKey)),
    );
  }

  Future<void> updatePageIcon(String pageId, String? icon) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(icon: Value(icon)),
    );
  }

  Future<void> updatePageCover(String pageId, String? cover) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(cover: Value(cover)),
    );
  }

  Future<_OwnershipTree> _ownershipTree() async =>
      _OwnershipTree(await getAllPages(), await getAllDatabases());

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
    for (final ids in _chunks(owned.pages)) {
      await (update(pages)..where((t) => t.id.isIn(ids))).write(
        PagesCompanion(trashedAt: Value(now), trashBatchId: Value(batchId)),
      );
      await (update(
        blocks,
      )..where((t) => t.pageId.isIn(ids) & t.trashedAt.isNull())).write(
        BlocksCompanion(trashedAt: Value(now), trashBatchId: Value(batchId)),
      );
    }
    for (final ids in _chunks(owned.databases)) {
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
            for (final ids in _chunks(owned.pages)) {
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
            for (final ids in _chunks(owned.databases)) {
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
    for (final ids in _chunks(owned.pages)) {
      await (delete(blocks)..where((t) => t.pageId.isIn(ids))).go();
      await (delete(editorDrafts)..where((t) => t.pageId.isIn(ids))).go();
      await (delete(pages)..where((t) => t.id.isIn(ids))).go();
    }
    for (final ids in _chunks(owned.databases)) {
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

  Stream<List<Database>> watchTrashedDatabases() =>
      (select(databases)
            ..where((t) => t.trashedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.trashedAt)]))
          .watch();

  Future<List<Page>> getAllPages() => select(pages).get();

  Future<List<Block>> getAllBlocks() => select(blocks).get();

  Future<List<Database>> getAllDatabases() => select(databases).get();

  Future<List<DatabaseColumn>> getAllDatabaseColumns() =>
      select(databaseColumns).get();

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
            pagesList.map(_withSearchFields).toList(),
          ),
        );
      }
      if (blocksList.isNotEmpty) {
        await batch((b) => b.insertAllOnConflictUpdate(blocks, blocksList));
      }
      await normalizeLegacyBlocks();
    });
  }

  Future<void> insertBlocksBatch(List<BlocksCompanion> blockList) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(blocks, blockList);
    });
  }

  /// Apply a document diff atomically; unchanged rows are never rewritten.
  Future<String> savePageBlockChanges(
    String pageId,
    List<BlockWrite> desired, {
    String? expectedVersion,
  }) => transaction(() async {
    final page = await getPageById(pageId);
    final current = await getPageBlocksSnapshot(pageId);
    if (page == null ||
        page.trashedAt != null ||
        (expectedVersion != null && current.version != expectedVersion)) {
      if (expectedVersion != null) throw DocumentConflictException(pageId);
      throw StateError('Cannot save blocks to a missing or trashed page');
    }
    final ids = desired.map((b) => b.id).toSet();
    if (ids.length != desired.length || ids.contains('')) {
      throw ArgumentError('Block IDs must be nonempty and unique');
    }
    for (final block in desired) {
      if (block.parentId != null && !ids.contains(block.parentId)) {
        throw ArgumentError('A block parent must belong to the same document');
      }
    }
    // An imported or copied ID must never steal a block from another page, or
    // overwrite a separately trashed block that still belongs to the workspace.
    for (final chunk in _chunks(ids)) {
      final collisions = await (select(
        blocks,
      )..where((t) => t.id.isIn(chunk))).get();
      if (collisions.any((b) => b.pageId != pageId || b.trashedAt != null)) {
        throw ArgumentError('Block ID already belongs to another stored block');
      }
    }
    final existing = {for (final block in current.blocks) block.id: block};
    final siblings = <String?, List<BlockWrite>>{};
    for (final block in desired) {
      siblings.putIfAbsent(block.parentId, () => []).add(block);
    }
    final reachable = <String>{};
    final queue = <BlockWrite>[...?siblings[null]];
    for (var i = 0; i < queue.length; i++) {
      final block = queue[i];
      if (!reachable.add(block.id)) throw ArgumentError('Cycle in block tree');
      queue.addAll(siblings[block.id] ?? []);
    }
    if (reachable.length != desired.length) {
      throw ArgumentError('Cycle in block tree');
    }
    final keys = <String, String>{};
    for (final group in siblings.values) {
      final reconciled = reconcileBlockOrder(
        group.map((b) {
          final old = existing[b.id];
          return old != null && old.parentId == b.parentId
              ? old.orderKey
              : null;
        }).toList(),
      );
      for (var i = 0; i < group.length; i++) {
        keys[group[i].id] = reconciled[i];
      }
    }
    for (final chunk in _chunks(
      existing.keys.where((id) => !ids.contains(id)).toSet(),
    )) {
      await (delete(
        blocks,
      )..where((t) => t.pageId.equals(pageId) & t.id.isIn(chunk))).go();
    }
    await batch((batch) {
      for (final block in desired) {
        final old = existing[block.id];
        final key = keys[block.id]!;
        if (old == null) {
          batch.insert(
            blocks,
            BlocksCompanion.insert(
              id: block.id,
              pageId: pageId,
              parentId: Value(block.parentId),
              type: block.type,
              content: block.content,
              orderKey: key,
            ),
          );
          continue;
        }
        final contentChanged =
            canonicalBlockJson(jsonDecode(old.content)) != block.content;
        if (old.type == block.type &&
            !contentChanged &&
            old.parentId == block.parentId &&
            old.orderKey == key) {
          continue;
        }
        batch.update(
          blocks,
          BlocksCompanion(
            type: old.type == block.type
                ? const Value.absent()
                : Value(block.type),
            content: contentChanged
                ? Value(block.content)
                : const Value.absent(),
            parentId: old.parentId == block.parentId
                ? const Value.absent()
                : Value(block.parentId),
            orderKey: old.orderKey == key ? const Value.absent() : Value(key),
          ),
          where: (t) => t.id.equals(block.id),
        );
      }
    });
    return (await getPageBlocksSnapshot(pageId)).version;
  });

  /// Upgrade the former root-block JSON format, including blocks in the trash.
  /// Called on schema upgrade and after importing an older workspace backup.
  Future<void> normalizeLegacyBlocks() => transaction(() async {
    final stored = await getAllBlocks();
    final usedIds = stored.map((b) => b.id).toSet();
    for (final root in stored) {
      final json = jsonDecode(root.content) as Map<String, dynamic>;
      if ((json['children'] as List? ?? []).isEmpty) continue;
      Future<void> expand(
        Map<String, dynamic> node,
        String id,
        String? parentId,
        String orderKey,
        bool isRoot,
      ) async {
        final children = node['children'] as List? ?? [];
        final shallow = Map<String, dynamic>.from(node)
          ..remove('children')
          ..remove('id');
        final content = canonicalBlockJson(shallow);
        if (isRoot) {
          await (update(blocks)..where((t) => t.id.equals(id))).write(
            BlocksCompanion(content: Value(content)),
          );
        } else {
          await into(blocks).insert(
            BlocksCompanion.insert(
              id: id,
              pageId: root.pageId,
              parentId: Value(parentId),
              type: node['type'] as String,
              content: content,
              orderKey: orderKey,
              trashedAt: Value(root.trashedAt),
              trashBatchId: Value(root.trashBatchId),
            ),
          );
        }
        final keys = FractionalIndexer.generateNKeysBetween(
          null,
          null,
          children.length,
        );
        for (var i = 0; i < children.length; i++) {
          final child = (children[i] as Map).cast<String, dynamic>();
          var childId = child['id'] as String? ?? const Uuid().v4();
          while (childId.isEmpty || !usedIds.add(childId)) {
            childId = const Uuid().v4();
          }
          await expand(child, childId, id, keys[i]!, false);
        }
      }

      await expand(json, root.id, root.parentId, root.orderKey, true);
    }
  });

  // The opaque content token covers direct DAO writes and workspace restores too.
  // It intentionally excludes page metadata, which is saved independently.
  Future<({List<Block> blocks, String version})> getPageBlocksSnapshot(
    String pageId,
  ) async {
    final rows = await getBlocksForPage(pageId);
    return (
      blocks: rows,
      version: jsonEncode(rows.map((row) => row.toJson()).toList()),
    );
  }

  Future<List<Block>> getBlocksForPage(String pageId) {
    return (select(blocks)
          ..where((tbl) => tbl.pageId.equals(pageId) & tbl.trashedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.orderKey),
            (tbl) => OrderingTerm.asc(tbl.id),
          ]))
        .get();
  }

  Future<void> deletePageBlocks(String pageId) {
    return (delete(blocks)..where((tbl) => tbl.pageId.equals(pageId))).go();
  }

  // --------------------------------------------------------------------------
  // Databases & Table View
  // --------------------------------------------------------------------------

  Future<void> upsertDatabase(DatabasesCompanion database) =>
      into(databases).insertOnConflictUpdate(database);

  Future<Database?> getDatabaseById(String id) =>
      (select(databases)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<Database?> watchDatabase(String id) => (select(
    databases,
  )..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();

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
    await getColumnsForDatabase(databaseId),
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
    final columns = (await getColumnsForDatabase(databaseId));
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
    final row = await getPageById(pageId);
    if (row == null || row.databaseId == null || row.trashedAt != null) {
      throw StateError('Cannot edit a missing or trashed row');
    }
    final database = await getDatabaseById(row.databaseId!);
    if (database == null || database.trashedAt != null) {
      throw StateError('Missing database');
    }
    final columns = await getColumnsForDatabase(row.databaseId!);
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
      await updatePageTitle(pageId, value as String);
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
    final database = await getDatabaseById(databaseId);
    if (database == null || database.trashedAt != null) {
      throw const DatabasePasteException(DatabasePasteIssue.conflict);
    }
    final columns = {
      for (final c in await getColumnsForDatabase(databaseId)) c.id: c,
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
        row = await getPageById(change.rowId);
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
          await updatePageTitle(rowId, value as String);
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
      final row = await getPageById(pageId);
      if (row == null || row.trashedAt != null || row.databaseId == null) {
        throw StateError(
          'Cannot patch a missing, trashed, or non-database row',
        );
      }
      final database = await getDatabaseById(row.databaseId!);
      if (database == null || database.trashedAt != null) {
        throw StateError('Cannot patch a row in a missing or trashed database');
      }
      final columns = await getColumnsForDatabase(row.databaseId!);
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

typedef _OwnedIds = ({Set<String> pages, Set<String> databases});

Iterable<List<String>> _chunks(Set<String> ids) sync* {
  final values = ids.toList();
  const size = 400;
  for (var i = 0; i < values.length; i += size) {
    yield values.sublist(i, (i + size).clamp(0, values.length));
  }
}

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

/// A detached, flat block snapshot. List order defines order within each parent.
typedef BlockWrite = ({
  String id,
  String? parentId,
  String type,
  String content,
});

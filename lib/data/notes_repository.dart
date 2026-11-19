import 'model/trash_entry.dart';
import 'model/database_paste.dart';
import '../ui/inbox/inbox_models.dart';

import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fractional_indexing/fractional_indexing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'db/app_database.dart';
import 'model/block_codec.dart';
import 'model/database_query.dart';
import 'model/page_settings.dart';
import 'model/database_initial_data.dart';

class SearchResultItem {
  final Page page;
  final String path;
  final bool isContentMatch;
  final bool isFuzzyMatch;
  final String? matchedTerm;
  final String? snippet;
  final int score;
  final String? matchedTag;
  final bool isQuickNote;

  const SearchResultItem({
    required this.page,
    this.path = '',
    this.isContentMatch = false,
    this.isFuzzyMatch = false,
    this.matchedTerm,
    this.snippet,
    this.score = 0,
    this.matchedTag,
    this.isQuickNote = false,
  });
}

class NotesRepository {
  final AppDatabase db;
  final Uuid _uuid;
  final _titleWrites = <String, Future<void>>{};

  NotesRepository(this.db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  Stream<List<Page>> watchActivePages() => db.watchActivePages();

  drift.Selectable<Page> _childPagesQuery(String parentId) =>
      (db.select(db.pages)
        ..where(
          (p) =>
              p.parentId.equals(parentId) &
              p.trashedAt.isNull() &
              p.databaseId.isNull(),
        )
        ..orderBy([
          (p) => drift.OrderingTerm.asc(p.orderKey),
          (p) => drift.OrderingTerm.asc(p.id),
        ]));

  Stream<List<Page>> watchChildPages(String parentId) =>
      _childPagesQuery(parentId).watch();
  Future<List<Page>> getChildPages(String parentId) =>
      _childPagesQuery(parentId).get();

  Future<void> updatePageSettings(
    String pageId, {
    SubpageLayout? subpageLayout,
    bool? fullWidth,
    bool? smallText,
    bool? coverToTop,
    double? coverY,
    bool? isPinned,
    String? cardColor,
    bool? isQuickNote,
    String? tag,
  }) => db.transaction(() async {
    final page = await getPage(pageId);
    if (page == null || page.trashedAt != null || page.databaseId != null) {
      throw StateError('Page settings require an active normal page');
    }
    final decoded = jsonDecode(page.properties ?? '{}');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid page metadata');
    }
    final previous = decoded[pageSettingsKey];
    decoded[pageSettingsKey] = {
      if (previous is Map) ...previous.cast<String, dynamic>(),
      if (subpageLayout != null) 'subpageLayout': subpageLayout.name,
      'fullWidth': ?fullWidth,
      'smallText': ?smallText,
      'coverToTop': ?coverToTop,
      'coverY': ?coverY,
      'isPinned': ?isPinned,
      'cardColor': ?cardColor,
      'isQuickNote': ?isQuickNote,
      'tag': ?tag,
    };
    await db.replaceRowProperties(pageId, jsonEncode(decoded));
  });

  Future<void> togglePagePinned(String pageId) => db.transaction(() async {
    final page = await getPage(pageId);
    if (page == null) return;
    final settings = pageSettingsFromProperties(page.properties);
    await updatePageSettings(pageId, isPinned: !settings.isPinned);
  });

  Future<String> createQuickNote({
    required String title,
    String? body,
    bool isCode = false,
    bool isPinned = false,
    String? tag,
    String? cardColor,
  }) async {
    final effectiveTitle = title.trim();
    final pageId = await createPage(title: effectiveTitle);
    await updatePageSettings(
      pageId,
      isQuickNote: true,
      isPinned: isPinned,
      tag: tag,
      cardColor: cardColor,
    );
    final rawContent = (body != null && body.trim().isNotEmpty)
        ? body.trim()
        : (isCode && effectiveTitle.isNotEmpty ? effectiveTitle : null);
    if (rawContent != null && rawContent.isNotEmpty) {
      final blockType = isCode ? 'code' : 'paragraph';
      final blockContent = jsonEncode({
        'type': blockType,
        'data': {
          'delta': [
            {'insert': rawContent}
          ],
          if (isCode) 'language': 'bash',
        },
      });
      final key = FractionalIndexer.generateKeyBetween(null, null)!;
      await db.insertBlocksBatch([
        BlocksCompanion(
          id: drift.Value(_uuid.v4()),
          pageId: drift.Value(pageId),
          type: drift.Value(blockType),
          content: drift.Value(blockContent),
          orderKey: drift.Value(key),
        ),
      ]);
    }
    return pageId;
  }

  Future<void> updateQuickNote({
    required String pageId,
    required String title,
    String? body,
    bool? isPinned,
    String? cardColor,
    String? tag,
    bool isCode = false,
  }) => db.transaction(() async {
    await updatePageTitle(pageId, title.isEmpty ? 'Untitled' : title);
    await updatePageSettings(
      pageId,
      isPinned: isPinned,
      cardColor: cardColor,
      tag: tag,
    );
    if (body != null) {
      await db.deletePageBlocks(pageId);
      final trimmed = body.trim();
      if (trimmed.isNotEmpty) {
        final blockType = isCode ? 'code' : 'paragraph';
        final blockContent = jsonEncode({
          'type': blockType,
          'data': {
            'delta': [
              {'insert': trimmed}
            ],
            if (isCode) 'language': 'bash',
          },
        });
        final key = FractionalIndexer.generateKeyBetween(null, null)!;
        await db.insertBlocksBatch([
          BlocksCompanion(
            id: drift.Value(_uuid.v4()),
            pageId: drift.Value(pageId),
            type: drift.Value(blockType),
            content: drift.Value(blockContent),
            orderKey: drift.Value(key),
          ),
        ]);
      }
    }
  });

  Future<void> updateSubpageLayout(String pageId, SubpageLayout layout) =>
      updatePageSettings(pageId, subpageLayout: layout);

  Future<String> createInboxItem({
    required String title,
    InboxItemType type = InboxItemType.link,
    String? url,
    String? domain,
    String? faviconUrl,
    String? previewImageUrl,
    String? excerpt,
    String? body,
    String? author,
    bool isArchived = false,
  }) async {
    final effectiveTitle = title.trim().isNotEmpty ? title.trim() : (domain ?? 'Входящее');
    final pageId = await createPage(title: effectiveTitle);

    final metadata = InboxItemMetadata(
      isInboxItem: true,
      type: type,
      url: url,
      domain: domain,
      faviconUrl: faviconUrl,
      previewImageUrl: previewImageUrl,
      excerpt: excerpt,
      author: author,
      isArchived: isArchived,
      savedAt: DateTime.now(),
    );

    final page = await getPage(pageId);
    final updatedProps = mergeInboxItemToProperties(page?.properties, metadata);
    await db.replaceRowProperties(pageId, updatedProps);

    final rawContent = (body != null && body.trim().isNotEmpty)
        ? body.trim()
        : (excerpt != null && excerpt.trim().isNotEmpty ? excerpt.trim() : null);

    if (rawContent != null && rawContent.isNotEmpty) {
      final blockType = type == InboxItemType.quote ? 'quote' : 'paragraph';
      final blockContent = jsonEncode({
        'type': blockType,
        'data': {
          'delta': [
            {'insert': rawContent}
          ],
        },
      });
      final key = FractionalIndexer.generateKeyBetween(null, null)!;
      await db.insertBlocksBatch([
        BlocksCompanion(
          id: drift.Value(_uuid.v4()),
          pageId: drift.Value(pageId),
          type: drift.Value(blockType),
          content: drift.Value(blockContent),
          orderKey: drift.Value(key),
        ),
      ]);
    }

    return pageId;
  }

  Future<void> updateInboxItemStatus(String pageId, {required bool isArchived}) async {
    final page = await getPage(pageId);
    if (page == null) return;
    final metadata = inboxItemFromProperties(page.properties);
    final updatedMetadata = metadata.copyWith(isArchived: isArchived);
    final updatedProps = mergeInboxItemToProperties(page.properties, updatedMetadata);
    await db.replaceRowProperties(pageId, updatedProps);
  }

  Future<void> convertInboxItemToPage(String pageId, {String? targetParentId}) async {
    final page = await getPage(pageId);
    if (page == null) return;
    final metadata = inboxItemFromProperties(page.properties);
    final updatedMetadata = metadata.copyWith(isInboxItem: false, isArchived: true);
    final updatedProps = mergeInboxItemToProperties(page.properties, updatedMetadata);
    await db.replaceRowProperties(pageId, updatedProps);
    if (targetParentId != null) {
      await movePage(pageId, targetParentId: targetParentId);
    }
  }

  Future<void> deleteInboxItem(String pageId) async {
    await trashPage(pageId);
  }

  Stream<List<TrashEntry>> watchTrashEntries() => db.watchTrashEntries();

  Stream<List<Page>> watchTrashedPages() => db.watchTrashedPages();

  Future<Page?> getPage(String pageId) => db.getPageById(pageId);

  Stream<Page?> watchPage(String pageId) => db.watchPageById(pageId);

  Future<String> createPage({
    String title = 'Untitled',
    String? parentId,
    String? icon,
    String? cover,
    String? orderKey,
  }) async {
    final pageId = _uuid.v4();
    final now = DateTime.now();

    String? pageOrderKey = orderKey;
    if (pageOrderKey == null) {
      final allPages = await db.getAllPages();
      final siblings = allPages
          .where((p) => p.trashedAt == null && p.parentId == parentId)
          .toList();
      final lastKey = siblings.isNotEmpty ? siblings.last.orderKey : null;
      pageOrderKey = FractionalIndexer.generateKeyBetween(lastKey, null)!;
    }

    await db.upsertPage(
      PagesCompanion(
        id: drift.Value(pageId),
        title: drift.Value(title),
        parentId: drift.Value(parentId),
        icon: drift.Value(icon),
        cover: drift.Value(cover),
        orderKey: drift.Value(pageOrderKey),
        createdAt: drift.Value(now),
      ),
    );

    // Initial empty paragraph
    final initialNode = paragraphNode();
    final initialKey = FractionalIndexer.generateKeyBetween(null, null)!;

    await db.insertBlocksBatch([
      BlocksCompanion(
        id: drift.Value(
          initialNode.id.isNotEmpty ? initialNode.id : _uuid.v4(),
        ),
        pageId: drift.Value(pageId),
        parentId: const drift.Value(null),
        type: drift.Value(initialNode.type),
        content: drift.Value(jsonEncode(initialNode.toJson())),
        orderKey: drift.Value(initialKey),
        trashedAt: const drift.Value(null),
      ),
    ]);

    return pageId;
  }

  Future<bool> movePage(
    String pageId, [
    String? targetParentId,
    String? orderKey,
  ]) async {
    if (targetParentId != null) {
      if (pageId == targetParentId) return false;

      // Cycle prevention: ensure targetParentId is not a descendant of pageId
      String? current = targetParentId;
      while (current != null) {
        if (current == pageId) return false;
        final p = await getPage(current);
        current = p?.parentId;
      }
    }

    await db.updatePageParentAndOrder(pageId, targetParentId, orderKey);
    return true;
  }

  Future<bool> reorderPage({
    required String pageId,
    String? targetParentId,
    String? prevOrderKey,
    String? nextOrderKey,
  }) async {
    final String newOrderKey;
    if (prevOrderKey != null &&
        nextOrderKey != null &&
        prevOrderKey.compareTo(nextOrderKey) >= 0) {
      newOrderKey = FractionalIndexer.generateKeyBetween(prevOrderKey, null)!;
    } else {
      newOrderKey = FractionalIndexer.generateKeyBetween(
        prevOrderKey,
        nextOrderKey,
      )!;
    }

    return movePage(pageId, targetParentId, newOrderKey);
  }

  Future<List<Page>> getBreadcrumbs(String pageId) async {
    final chain = <Page>[];
    String? currentId = pageId;
    final visited = <String>{};

    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      final p = await getPage(currentId);
      if (p == null) break;
      chain.insert(0, p);
      currentId = p.parentId;
    }

    return chain;
  }

  Future<List<SearchResultItem>> searchPages(String query) async {
    final matches = await db.searchPagesWithMatches(query);
    final results = <SearchResultItem>[];

    for (final m in matches) {
      final p = m.page;
      final crumbs = await getBreadcrumbs(p.id);
      final pathParts = crumbs.length > 1
          ? crumbs
                .sublist(0, crumbs.length - 1)
                .map((c) => c.title.trim().isEmpty ? 'Untitled' : c.title)
                .toList()
          : <String>[];
      final pathStr = pathParts.join(' / ');
      final settings = pageSettingsFromProperties(p.properties);

      results.add(
        SearchResultItem(
          page: p,
          path: pathStr,
          isContentMatch: m.isContentMatch,
          isFuzzyMatch: m.isFuzzyMatch,
          matchedTerm: m.matchedTerm,
          snippet: m.snippet,
          score: m.score,
          matchedTag: settings.tag,
          isQuickNote: settings.isQuickNote,
        ),
      );
    }

    return results;
  }

  static const _kRecentSearchQueriesKey = 'notes_recent_search_queries';

  Future<List<String>> getRecentSearchQueries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kRecentSearchQueriesKey) ?? const [];
  }

  Future<void> addRecentSearchQuery(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_kRecentSearchQueriesKey) ?? []).toList();
    list.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    list.insert(0, clean);
    if (list.length > 8) {
      list.removeRange(8, list.length);
    }
    await prefs.setStringList(_kRecentSearchQueriesKey, list);
  }

  Future<void> removeRecentSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_kRecentSearchQueriesKey) ?? []).toList();
    list.removeWhere((q) => q.toLowerCase() == query.trim().toLowerCase());
    await prefs.setStringList(_kRecentSearchQueriesKey, list);
  }

  Future<void> clearRecentSearchQueries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchQueriesKey);
  }

  Future<List<Page>> getBacklinks(String pageId) =>
      db.getBacklinksForPage(pageId);

  Future<void> updatePageTitle(String pageId, String title) {
    final previous = _titleWrites[pageId];
    late final Future<void> write;
    // Defer execution until the queue entry is assigned, including when a DAO
    // throws synchronously before returning its Future.
    write = Future<void>.microtask(() async {
      try {
        if (previous != null) {
          try {
            await previous;
          } catch (_) {
            // A failed write must not block the next one.
          }
        }
        await db.updatePageTitle(pageId, title);
      } finally {
        if (identical(_titleWrites[pageId], write)) {
          _titleWrites.remove(pageId);
        }
      }
    });
    _titleWrites[pageId] = write;
    return write;
  }

  Future<void> updatePageIcon(String pageId, String? icon) {
    return db.updatePageIcon(pageId, icon);
  }

  Future<void> updatePageCover(String pageId, String? cover) {
    return db.updatePageCover(pageId, cover);
  }

  Future<void> trashPage(String pageId) {
    return db.trashPage(pageId);
  }

  Future<void> restorePage(String pageId) {
    return db.restorePage(pageId);
  }

  Future<void> permanentlyDeletePage(String pageId) {
    return db.permanentlyDeletePage(pageId);
  }

  Future<void> emptyTrash() {
    return db.emptyTrash();
  }

  Future<void> saveDraft(
    String id,
    String pageId,
    String baseVersion,
    List<Node> nodes,
  ) {
    return db.transaction(() async {
      if (await db.getPageById(pageId) == null) {
        throw StateError('Cannot save a draft for a permanently deleted page');
      }
      await db
          .into(db.editorDrafts)
          .insertOnConflictUpdate(
            EditorDraftsCompanion.insert(
              id: id,
              pageId: pageId,
              baseVersion: baseVersion,
              content: jsonEncode(
                nodes
                    .map((n) => {'id': n.id, 'node': encodeNodeWithIds(n)})
                    .toList(),
              ),
              updatedAt: DateTime.now(),
            ),
          );
    });
  }

  Future<List<EditorDraft>> getDrafts(String pageId) =>
      (db.select(db.editorDrafts)
            ..where((t) => t.pageId.equals(pageId))
            ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
          .get();

  Document documentFromDraft(EditorDraft draft) {
    final nodes = (jsonDecode(draft.content) as List)
        .map(
          (entry) =>
              decodeNodeWithIds((entry['node'] as Map).cast<String, Object>())
                ..id = entry['id'] as String,
        )
        .toList();
    return Document(root: pageNode(children: nodes));
  }

  Future<void> deleteDraft(
    String id, {
    EditorDraft? recoveredDraft,
  }) => db.transaction(() async {
    await (db.delete(db.editorDrafts)..where((t) => t.id.equals(id))).go();
    if (recoveredDraft != null) {
      // Another editor may have updated the recovery source in the meantime.
      await (db.delete(db.editorDrafts)..where(
            (t) =>
                t.id.equals(recoveredDraft.id) &
                t.content.equals(recoveredDraft.content) &
                t.baseVersion.equals(recoveredDraft.baseVersion),
          ))
          .go();
    }
  });

  Future<void> discardDraft(
    String id,
    String pageId,
    String expectedVersion, {
    EditorDraft? recoveredDraft,
  }) => db.transaction(() async {
    if ((await db.getPageBlocksSnapshot(pageId)).version != expectedVersion) {
      throw DocumentConflictException(pageId);
    }
    await deleteDraft(id, recoveredDraft: recoveredDraft);
  });

  Future<Document> loadPageDocument(String pageId) async {
    return (await loadPageSnapshot(pageId)).document;
  }

  Future<({Document document, String version})> loadPageSnapshot(
    String pageId,
  ) async {
    final snapshot = await db.getPageBlocksSnapshot(pageId);
    final blocks = snapshot.blocks;
    if (blocks.isEmpty) {
      return (
        document: Document(root: pageNode(children: [paragraphNode()])),
        version: snapshot.version,
      );
    }

    final children = <String?, List<Block>>{};
    for (final block in blocks) {
      children.putIfAbsent(block.parentId, () => []).add(block);
    }
    final visited = <String>{};
    Node build(Block block) {
      if (!visited.add(block.id)) {
        throw const FormatException('Cycle in block tree');
      }
      final json = (jsonDecode(block.content) as Map).cast<String, Object>();
      return Node(
        type: json['type'] as String,
        id: block.id,
        attributes: (json['data'] as Map? ?? {}).cast<String, dynamic>(),
        children: (children[block.id] ?? []).map(build).toList(),
      );
    }

    final nodes = (children[null] ?? []).map(build).toList();
    if (visited.length != blocks.length) {
      throw const FormatException('Orphaned block in document');
    }
    return (
      document: Document(root: pageNode(children: nodes)),
      version: snapshot.version,
    );
  }

  Future<String> savePageNodes(
    String pageId,
    List<Node> nodes, {
    String? expectedVersion,
  }) async {
    final desired = <BlockWrite>[];
    final visited = <String>{};
    void flatten(Node node, String? parentId) {
      if (node.id.isEmpty) node.id = _uuid.v4();
      if (!visited.add(node.id)) {
        throw ArgumentError('Duplicate or cyclic block ID');
      }
      final json = shallowNodeJson(node);
      desired.add((
        id: node.id,
        parentId: parentId,
        type: node.type,
        content: canonicalBlockJson(json),
      ));
      for (final child in node.children) {
        flatten(child, node.id);
      }
    }

    for (final node in nodes) {
      flatten(node, null);
    }
    return db.savePageBlockChanges(
      pageId,
      desired,
      expectedVersion: expectedVersion,
    );
  }

  // --------------------------------------------------------------------------
  // Databases / Table View
  // --------------------------------------------------------------------------

  Future<String> createDatabase({
    String title = 'Untitled Database',
    String? icon,
    String? parentPageId,
    List<({String name, String type, String? options, double width})>?
    initialColumns,
  }) async {
    final databaseId = _uuid.v4();
    final now = DateTime.now();

    await db.upsertDatabase(
      DatabasesCompanion(
        id: drift.Value(databaseId),
        title: drift.Value(title),
        icon: drift.Value(icon),
        parentPageId: drift.Value(parentPageId),
        createdAt: drift.Value(now),
      ),
    );

    // Create default columns if none supplied: Title, Tags, Done
    final cols =
        initialColumns ??
        [
          (name: 'Name', type: 'title', options: null, width: 200.0),
          (
            name: 'Tags',
            type: 'select',
            options: jsonEncode([
              {'id': 'todo', 'label': 'To Do', 'color': '0xFF4A90E2'},
              {
                'id': 'in_progress',
                'label': 'In Progress',
                'color': '0xFFF5A623',
              },
              {'id': 'done', 'label': 'Done', 'color': '0xFF7ED321'},
            ]),
            width: 160.0,
          ),
          (name: 'Done', type: 'checkbox', options: null, width: 100.0),
        ];

    String? prevKey;
    for (final col in cols) {
      final key = FractionalIndexer.generateKeyBetween(prevKey, null)!;
      prevKey = key;
      await db.upsertDatabaseColumn(
        DatabaseColumnsCompanion(
          id: drift.Value(_uuid.v4()),
          databaseId: drift.Value(databaseId),
          name: drift.Value(col.name),
          type: drift.Value(col.type),
          options: drift.Value(col.options),
          width: drift.Value(col.width),
          orderKey: drift.Value(key),
          createdAt: drift.Value(now),
        ),
      );
    }

    return databaseId;
  }

  Future<Database?> getDatabase(String id) => db.getDatabaseById(id);

  Future<DatabaseInitialData> loadDatabaseInitialData(String databaseId) =>
      db.transaction(
        () async => DatabaseInitialData(
          database: await getDatabase(databaseId),
          columns: await getColumns(databaseId),
          rows: await queryDatabaseRows(databaseId),
        ),
      );

  Stream<Database?> watchDatabase(String id) => db.watchDatabase(id);

  Future<void> updateDatabaseTitle(String id, String title) =>
      db.updateDatabaseTitle(id, title);

  Future<void> updateDatabaseIcon(String id, String? icon) =>
      db.updateDatabaseIcon(id, icon);

  Future<void> trashDatabase(String id) => db.trashDatabase(id);

  Future<void> restoreDatabase(String id) => db.restoreDatabase(id);

  Stream<List<Database>> watchTrashedDatabases() => db.watchTrashedDatabases();

  Future<void> deleteDatabasePermanently(String id) =>
      db.deleteDatabasePermanently(id);

  // Columns
  Future<List<DatabaseColumn>> getColumns(String databaseId) =>
      db.getColumnsForDatabase(databaseId);

  Stream<List<DatabaseColumn>> watchColumns(String databaseId) =>
      db.watchColumnsForDatabase(databaseId);

  Future<String> addColumn(
    String databaseId, {
    required String name,
    required String type,
    String? options,
    double width = 160.0,
  }) async {
    final existing = await getColumns(databaseId);
    final lastKey = existing.isNotEmpty ? existing.last.orderKey : null;
    final key = FractionalIndexer.generateKeyBetween(lastKey, null)!;
    final colId = _uuid.v4();

    final resolvedOptions = options ??
        (type == 'status'
            ? jsonEncode([
                {
                  'id': 'not_started',
                  'label': 'Not started',
                  'color': '0xFF9E9E9E',
                },
                {
                  'id': 'in_progress',
                  'label': 'In progress',
                  'color': '0xFF2196F3',
                },
                {
                  'id': 'done',
                  'label': 'Done',
                  'color': '0xFF4CAF50',
                },
              ])
            : null);

    await db.upsertDatabaseColumn(
      DatabaseColumnsCompanion(
        id: drift.Value(colId),
        databaseId: drift.Value(databaseId),
        name: drift.Value(name),
        type: drift.Value(type),
        options: drift.Value(resolvedOptions),
        width: drift.Value(width),
        orderKey: drift.Value(key),
        createdAt: drift.Value(DateTime.now()),
      ),
    );

    return colId;
  }

  Future<void> updateColumn(
    String columnId, {
    String? name,
    String? type,
    String? options,
    double? width,
    String? orderKey,
  }) {
    return db.updateDatabaseColumn(
      columnId,
      DatabaseColumnsCompanion(
        name: name != null ? drift.Value(name) : const drift.Value.absent(),
        type: type != null ? drift.Value(type) : const drift.Value.absent(),
        options: options != null
            ? drift.Value(options)
            : const drift.Value.absent(),
        width: width != null ? drift.Value(width) : const drift.Value.absent(),
        orderKey: orderKey != null
            ? drift.Value(orderKey)
            : const drift.Value.absent(),
      ),
    );
  }

  Future<void> deleteColumn(String columnId) =>
      db.deleteDatabaseColumn(columnId);

  Future<void> reorderColumn({
    required String databaseId,
    required String columnId,
    required int targetIndex,
  }) async {
    final columns = await getColumns(databaseId);
    final colIndex = columns.indexWhere((c) => c.id == columnId);
    if (colIndex == -1) return;

    final movedCol = columns.removeAt(colIndex);
    // Title column must remain at index 0, so targetIndex must be >= 1
    final safeTargetIndex = targetIndex.clamp(1, columns.length);
    columns.insert(safeTargetIndex, movedCol);

    final prevKey = safeTargetIndex > 0
        ? columns[safeTargetIndex - 1].orderKey
        : null;
    final nextKey = safeTargetIndex < columns.length - 1
        ? columns[safeTargetIndex + 1].orderKey
        : null;

    final newKey = FractionalIndexer.generateKeyBetween(prevKey, nextKey);
    if (newKey != null && newKey != movedCol.orderKey) {
      await updateColumn(columnId, orderKey: newKey);
    } else {
      // Re-index all columns to ensure unique monotonic keys
      final keys = FractionalIndexer.generateNKeysBetween(
        null,
        null,
        columns.length,
      );
      for (int i = 0; i < columns.length; i++) {
        await updateColumn(columns[i].id, orderKey: keys[i]);
      }
    }
  }

  Future<void> moveColumnDirection({
    required String databaseId,
    required String columnId,
    required bool moveLeft,
  }) async {
    final columns = await getColumns(databaseId);
    final colIndex = columns.indexWhere((c) => c.id == columnId);
    if (colIndex <= 0) return; // cannot move title or not found

    final targetIndex = moveLeft ? colIndex - 1 : colIndex + 1;
    if (targetIndex < 1 || targetIndex >= columns.length) return;

    await reorderColumn(
      databaseId: databaseId,
      columnId: columnId,
      targetIndex: targetIndex,
    );
  }

  // Rows (Pages belonging to this database)
  Future<String> createDatabaseRow(
    String databaseId, {
    String title = '',
    Map<String, dynamic>? properties,
  }) async {
    final rowId = _uuid.v4();
    final now = DateTime.now();
    final lastRow =
        await (db.select(db.pages)
              ..where(
                (t) => t.databaseId.equals(databaseId) & t.trashedAt.isNull(),
              )
              ..orderBy([
                (t) => drift.OrderingTerm.desc(t.orderKey),
                (t) => drift.OrderingTerm.desc(t.createdAt),
                (t) => drift.OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    final lastKey = lastRow?.orderKey;
    final rowOrderKey = FractionalIndexer.generateKeyBetween(lastKey, null)!;

    final propsJson = properties != null ? jsonEncode(properties) : null;

    await db.upsertPage(
      PagesCompanion(
        id: drift.Value(rowId),
        title: drift.Value(title),
        databaseId: drift.Value(databaseId),
        properties: drift.Value(propsJson),
        orderKey: drift.Value(rowOrderKey),
        createdAt: drift.Value(now),
      ),
    );

    // Initialize with an empty paragraph block so it can be edited as a page
    final initialNode = paragraphNode();
    final initialKey = FractionalIndexer.generateKeyBetween(null, null)!;

    await db.insertBlocksBatch([
      BlocksCompanion(
        id: drift.Value(initialNode.id),
        pageId: drift.Value(rowId),
        parentId: const drift.Value(null),
        type: drift.Value(initialNode.type),
        content: drift.Value(jsonEncode(initialNode.toJson())),
        orderKey: drift.Value(initialKey),
        trashedAt: const drift.Value(null),
      ),
    ]);

    return rowId;
  }

  Future<List<Page>> getDatabaseRows(String databaseId) =>
      db.getDatabaseRows(databaseId);

  Stream<List<Page>> watchDatabaseRows(String databaseId) =>
      db.watchDatabaseRows(databaseId);

  Future<DatabaseRowsPage> queryDatabaseRows(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) => db.queryDatabaseRows(
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
  }) => db.watchDatabaseRowsPage(
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
  }) => db.watchDatabaseSummaryGroups(
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
  }) => db.compareAndSetDatabaseCell(
    pageId,
    columnId,
    value,
    expected,
    title: title,
  );

  Future<void> applyDatabaseCellChanges(
    List<DatabaseCellChange> changes, {
    bool undo = false,
  }) => db.applyDatabaseCellChanges(changes, undo: undo);

  Future<void> patchRowProperties(
    String pageId,
    Map<String, dynamic> changes,
  ) => db.patchRowProperties(pageId, changes);

  /// Replace all properties intentionally. Use [patchRowProperties] for cell edits.
  Future<void> replaceRowProperties(
    String pageId,
    Map<String, dynamic> properties,
  ) {
    return db.replaceRowProperties(pageId, jsonEncode(properties));
  }

  Future<void> updateRowTitle(String pageId, String title) =>
      updatePageTitle(pageId, title);

  /// Rows are pages: deleting a row moves its owned subtree to the trash.
  Future<void> deleteDatabaseRow(String pageId) {
    return db.trashPage(pageId);
  }
}

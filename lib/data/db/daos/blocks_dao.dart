import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fractional_indexing/fractional_indexing.dart';
import 'package:uuid/uuid.dart';

import '../../model/block_codec.dart';
import '../../model/block_ordering.dart';
import '../app_database.dart';
import 'dao_shared.dart';

class BlocksDao extends DatabaseAccessor<AppDatabase> {
  BlocksDao(super.db);

  $BlocksTable get blocks => db.blocks;

  Future<List<Block>> getAllBlocks() => select(blocks).get();

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
    final page = await db.pagesDao.getPageById(pageId);
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
    for (final chunk in chunks(ids)) {
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
    for (final chunk in chunks(
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
}

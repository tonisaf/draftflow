import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('createPage creates page and initial block', () async {
    final pageId = await repo.createPage(title: 'My First Page');
    final page = await repo.getPage(pageId);
    expect(page, isNotNull);
    expect(page!.title, 'My First Page');

    final doc = await repo.loadPageDocument(pageId);
    expect(doc.root.children.isNotEmpty, true);
  });

  test('savePageNodes and loadPageDocument preserves block order and type', () async {
    final pageId = await repo.createPage(title: 'Notes');
    final nodes = [
      headingNode(level: 1, text: 'Title H1'),
      paragraphNode(text: 'Paragraph body'),
      todoListNode(checked: true, text: 'Done item'),
    ];

    await repo.savePageNodes(pageId, nodes);
    final restoredDoc = await repo.loadPageDocument(pageId);

    expect(restoredDoc.root.children.length, 3);
    expect(restoredDoc.root.children[0].type, 'heading');
    expect(restoredDoc.root.children[1].type, 'paragraph');
    expect(restoredDoc.root.children[2].type, 'todo_list');
  });

  test('savePageNodes rolls back deletion and partial inserts on failure', () async {
    final pageId = await repo.createPage(title: 'Notes');
    await repo.savePageNodes(pageId, [
      paragraphNode(text: 'Original paragraph'),
      todoListNode(checked: true, text: 'Original task'),
    ]);
    final originalBlocks = await db.getBlocksForPage(pageId);

    // Allow the first replacement block, then fail partway through the batch.
    await db.customStatement('''
      CREATE TRIGGER reject_heading BEFORE INSERT ON blocks
      WHEN NEW.type = 'heading'
      BEGIN
        SELECT RAISE(ABORT, 'Injected block insert failure');
      END
    ''');

    await expectLater(
      repo.savePageNodes(pageId, [
        paragraphNode(text: 'Replacement paragraph'),
        headingNode(level: 1, text: 'Rejected heading'),
      ]),
      throwsA(isA<SqliteException>()),
    );

    expect(await db.getBlocksForPage(pageId), originalBlocks);

    // A failed save must not prevent a subsequent successful save.
    await db.customStatement('DROP TRIGGER reject_heading');
    await repo.savePageNodes(pageId, [paragraphNode(text: 'Recovered')]);
    final restored = await repo.loadPageDocument(pageId);
    expect(restored.root.children.single.delta!.toPlainText(), 'Recovered');
  });

  test('only one writer can save against the same document version', () async {
    final pageId = await repo.createPage();
    final snapshot = await repo.loadPageSnapshot(pageId);
    Future<bool> save(String text) async {
      try {
        await repo.savePageNodes(pageId, [paragraphNode(text: text)],
            expectedVersion: snapshot.version);
        return true;
      } on DocumentConflictException {
        return false;
      }
    }
    final results = await Future.wait([save('First'), save('Second')]);
    expect(results.where((saved) => saved).length, 1);
    final doc = await repo.loadPageDocument(pageId);
    expect(doc.root.children.single.delta!.toPlainText(), results.first ? 'First' : 'Second');
  });

  test('page metadata changes do not conflict with document saves', () async {
    final pageId = await repo.createPage();
    final snapshot = await repo.loadPageSnapshot(pageId);
    await repo.updatePageTitle(pageId, 'Renamed');
    final version = await repo.savePageNodes(pageId, [paragraphNode(text: 'Text')],
        expectedVersion: snapshot.version);
    expect(version, (await repo.loadPageSnapshot(pageId)).version);
    expect((await repo.getPage(pageId))!.title, 'Renamed');
  });

  test('direct block deletion and page trash invalidate a document save', () async {
    final pageId = await repo.createPage();
    final snapshot = await repo.loadPageSnapshot(pageId);
    await db.deletePageBlocks(pageId);
    await expectLater(repo.savePageNodes(pageId, [paragraphNode(text: 'Stale')],
        expectedVersion: snapshot.version), throwsA(isA<DocumentConflictException>()));
    final empty = await repo.loadPageSnapshot(pageId);
    await repo.trashPage(pageId);
    await expectLater(repo.savePageNodes(pageId, [], expectedVersion: empty.version),
        throwsA(isA<DocumentConflictException>()));
  });

  test('watchActivePages filters out trashed pages', () async {
    final pageId = await repo.createPage(title: 'To Trash');
    final pagesBefore = await repo.watchActivePages().first;
    expect(pagesBefore.any((p) => p.id == pageId), true);

    await repo.trashPage(pageId);
    final pagesAfter = await repo.watchActivePages().first;
    expect(pagesAfter.any((p) => p.id == pageId), false);

    final trashedPages = await repo.watchTrashedPages().first;
    expect(trashedPages.any((p) => p.id == pageId), true);
  });

  test('subpages and breadcrumbs chain', () async {
    final rootId = await repo.createPage(title: 'Root Folder');
    final subId = await repo.createPage(title: 'Sub Project', parentId: rootId);
    final leafId = await repo.createPage(title: 'Deep Leaf Note', parentId: subId);

    final breadcrumbs = await repo.getBreadcrumbs(leafId);
    expect(breadcrumbs.length, 3);
    expect(breadcrumbs[0].id, rootId);
    expect(breadcrumbs[1].id, subId);
    expect(breadcrumbs[2].id, leafId);
  });

  test('movePage prevents circular dependencies', () async {
    final parentId = await repo.createPage(title: 'Parent');
    final childId = await repo.createPage(title: 'Child', parentId: parentId);

    // Trying to make Parent a child of Child should be rejected
    final moved = await repo.movePage(parentId, childId);
    expect(moved, false);

    // Parent should still have null parentId
    final parentPage = await repo.getPage(parentId);
    expect(parentPage!.parentId, isNull);
  });

  test('createPage and updatePageIcon & updatePageCover', () async {
    final pageId = await repo.createPage(
      title: 'Icon & Cover Test',
      icon: '💡',
      cover: 'gradient:sunset',
    );

    var page = await repo.getPage(pageId);
    expect(page, isNotNull);
    expect(page!.icon, '💡');
    expect(page.cover, 'gradient:sunset');

    // Update icon to new emoji
    await repo.updatePageIcon(pageId, '🚀');
    page = await repo.getPage(pageId);
    expect(page!.icon, '🚀');

    // Remove icon
    await repo.updatePageIcon(pageId, null);
    page = await repo.getPage(pageId);
    expect(page!.icon, isNull);

    // Update cover to color
    await repo.updatePageCover(pageId, 'color:blue');
    page = await repo.getPage(pageId);
    expect(page!.cover, 'color:blue');

    // Remove cover
    await repo.updatePageCover(pageId, null);
    page = await repo.getPage(pageId);
    expect(page!.cover, isNull);
  });

  test('searchPages finds pages by title and content with breadcrumbs', () async {
    final rootId = await repo.createPage(title: 'Architecture');
    final childId = await repo.createPage(title: 'Database Schema', parentId: rootId);
    final secretId = await repo.createPage(title: 'Random Note');

    // Add block with unique text inside 'Random Note'
    await repo.savePageNodes(secretId, [
      paragraphNode(text: 'This contains confidential quantum algorithms body text'),
    ]);

    // 1. Empty query returns recent pages
    final recent = await repo.searchPages('');
    expect(recent.length, greaterThanOrEqualTo(3));

    // 2. Search by title
    final titleResults = await repo.searchPages('schema');
    expect(titleResults.length, 1);
    expect(titleResults.first.page.id, childId);
    expect(titleResults.first.path, 'Architecture');
    expect(titleResults.first.isContentMatch, false);

    // 3. Search by body content
    final contentResults = await repo.searchPages('quantum');
    expect(contentResults.length, 1);
    expect(contentResults.first.page.id, secretId);
    expect(contentResults.first.isContentMatch, true);
  });

  test('reorderPage updates parent and calculates valid orderKey between siblings', () async {
    final rootA = await repo.createPage(title: 'Folder A');
    final rootB = await repo.createPage(title: 'Folder B');
    final item1 = await repo.createPage(title: 'Item 1', parentId: rootA);
    final item2 = await repo.createPage(title: 'Item 2', parentId: rootA);
    final page1 = (await repo.getPage(item1))!;
    final page2 = (await repo.getPage(item2))!;

    // Reorder: Move item from Folder A into Folder B
    final moved = await repo.reorderPage(
      pageId: item1,
      targetParentId: rootB,
      prevOrderKey: null,
      nextOrderKey: null,
    );
    expect(moved, true);
    final movedPage = (await repo.getPage(item1))!;
    expect(movedPage.parentId, rootB);
    expect(movedPage.orderKey, isNotNull);

    // Reorder: place between two keys
    final midSuccess = await repo.reorderPage(
      pageId: item1,
      targetParentId: rootA,
      prevOrderKey: page1.orderKey,
      nextOrderKey: page2.orderKey,
    );
    expect(midSuccess, true);
    final midPage = (await repo.getPage(item1))!;
    expect(midPage.parentId, rootA);
    expect(midPage.orderKey!.compareTo(page1.orderKey!) >= 0, true);
    expect(midPage.orderKey!.compareTo(page2.orderKey!) <= 0, true);
  });

  test('getBacklinks returns referencing pages without self-references', () async {
    final pageA = await repo.createPage(title: 'Project Roadmap');
    final pageB = await repo.createPage(title: 'API Specification');
    final pageC = await repo.createPage(title: 'Weekly Standup');

    // Link page B from page A
    await repo.savePageNodes(pageA, [
      paragraphNode(text: 'See details in API Specification: page://$pageB'),
    ]);

    // Link page B from page C
    await repo.savePageNodes(pageC, [
      paragraphNode(text: 'Discussed API Specification: page://$pageB'),
    ]);

    // Self-link inside page B
    await repo.savePageNodes(pageB, [
      paragraphNode(text: 'Self mention page://$pageB'),
    ]);

    final backlinksForB = await repo.getBacklinks(pageB);
    expect(backlinksForB.length, 2);
    final backlinkIds = backlinksForB.map((p) => p.id).toSet();
    expect(backlinkIds.contains(pageA), true);
    expect(backlinkIds.contains(pageC), true);
    expect(backlinkIds.contains(pageB), false); // No self reference
  });
}

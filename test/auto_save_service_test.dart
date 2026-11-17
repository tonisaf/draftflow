import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/auto_save_service.dart';

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

  test(
    'AutoSaveService triggers save on document transaction and updates status',
    () async {
      final pageId = await repo.createPage(title: 'AutoSave Test');
      final snapshot = await repo.loadPageSnapshot(pageId);
      final doc = snapshot.document;
      final editorState = EditorState(document: doc);

      final autoSave = AutoSaveService(
        repository: repo,
        pageId: pageId,
        editorState: editorState,
        initialVersion: snapshot.version,
        debounceDuration: const Duration(milliseconds: 50),
      );

      expect(autoSave.statusNotifier.value, SaveStatus.saved);

      // Insert a new heading node via transaction
      final transaction = editorState.transaction
        ..insertNode([1], headingNode(level: 1, text: 'Auto Saved Title'));
      await editorState.apply(transaction);

      // Immediately status should become saving
      expect(autoSave.statusNotifier.value, SaveStatus.saving);

      // Wait for debounce timer to fire
      await Future.delayed(const Duration(milliseconds: 80));

      expect(autoSave.statusNotifier.value, SaveStatus.saved);

      // Verify persisted document in database
      final savedDoc = await repo.loadPageDocument(pageId);
      expect(savedDoc.root.children.length, 2);
      expect(savedDoc.root.children[1].type, 'heading');

      autoSave.dispose();
    },
  );

  test('slow saves are serialized and include edits made during a save', () async {
    final controlled = _ControlledRepository(db, blockSecond: true);
    final pageId = await controlled.createPage();
    final snapshot = await controlled.loadPageSnapshot(pageId);
    final editor = EditorState(document: snapshot.document);
    final service = AutoSaveService(
      repository: controlled,
      pageId: pageId,
      editorState: editor,
      initialVersion: snapshot.version,
      debounceDuration: const Duration(days: 1),
    );
    addTearDown(service.dispose);

    await editor.apply(
      editor.transaction..insertNode([1], paragraphNode(text: 'First')),
    );
    final first = service.forceSave();
    await controlled.started.future;
    // Mutate an existing node while the first snapshot is waiting to be saved.
    await editor.apply(
      editor.transaction
        ..insertText(editor.document.root.children[1], 5, ' edited'),
    );
    final second = service.forceSave();
    expect(controlled.calls, 1);
    expect(service.statusNotifier.value, SaveStatus.saving);
    controlled.release.complete();
    await controlled.secondStarted.future;
    expect(service.statusNotifier.value, SaveStatus.saving);
    controlled.releaseSecond.complete();
    await Future.wait([first, second]);

    expect(controlled.maxActive, 1);
    expect(controlled.capturedTexts, ['First', 'First edited']);
    expect(service.statusNotifier.value, SaveStatus.saved);
    final stored = await controlled.loadPageDocument(pageId);
    expect(stored.root.children[1].delta!.toPlainText(), 'First edited');
  });

  test('external changes cause a sticky conflict without replacing the local draft', () async {
    final pageId = await repo.createPage();
    final snapshot = await repo.loadPageSnapshot(pageId);
    final editor = EditorState(document: snapshot.document);
    final service = AutoSaveService(
      repository: repo,
      pageId: pageId,
      editorState: editor,
      initialVersion: snapshot.version,
      debounceDuration: const Duration(days: 1),
    );
    addTearDown(service.dispose);
    await repo.savePageNodes(pageId, [paragraphNode(text: 'External')]);
    await editor.apply(
      editor.transaction..insertNode([1], paragraphNode(text: 'Local draft')),
    );
    await service.forceSave();
    expect(service.statusNotifier.value, SaveStatus.conflict);
    expect(
      editor.document.root.children[1].delta!.toPlainText(),
      'Local draft',
    );
    await service.forceSave();
    expect(service.statusNotifier.value, SaveStatus.conflict);
    expect(
      (await repo.loadPageDocument(pageId)).root.children.single.delta!
          .toPlainText(),
      'External',
    );
  });

  test(
    'flush of an unchanged editor does not overwrite external changes',
    () async {
      final pageId = await repo.createPage();
      final snapshot = await repo.loadPageSnapshot(pageId);
      final service = AutoSaveService(
        repository: repo,
        pageId: pageId,
        editorState: EditorState(document: snapshot.document),
        initialVersion: snapshot.version,
      );
      await repo.savePageNodes(pageId, [paragraphNode(text: 'External')]);
      await service.forceSave();
      service.dispose();
      expect(
        (await repo.loadPageDocument(pageId)).root.children.single.delta!
            .toPlainText(),
        'External',
      );
    },
  );

  test('failed save remains dirty and an explicit flush can retry', () async {
    final failing = _FailingRepository(db);
    final pageId = await failing.createPage();
    final snapshot = await failing.loadPageSnapshot(pageId);
    final editor = EditorState(document: snapshot.document);
    final service = AutoSaveService(
      repository: failing,
      pageId: pageId,
      editorState: editor,
      initialVersion: snapshot.version,
      debounceDuration: const Duration(days: 1),
    );
    addTearDown(service.dispose);
    await editor.apply(
      editor.transaction..insertNode([1], paragraphNode(text: 'Retry me')),
    );
    await service.forceSave();
    expect(service.statusNotifier.value, SaveStatus.error);
    await service.forceSave();
    expect(service.statusNotifier.value, SaveStatus.saved);
    expect(
      (await failing.loadPageDocument(pageId)).root.children[1].delta!
          .toPlainText(),
      'Retry me',
    );
  });

  test('a captured flush finishes after disposal', () async {
    final controlled = _ControlledRepository(db);
    final pageId = await controlled.createPage();
    final snapshot = await controlled.loadPageSnapshot(pageId);
    final editor = EditorState(document: snapshot.document);
    final service = AutoSaveService(
      repository: controlled,
      pageId: pageId,
      editorState: editor,
      initialVersion: snapshot.version,
      debounceDuration: const Duration(days: 1),
    );
    await editor.apply(
      editor.transaction..insertNode([1], paragraphNode(text: 'Last edit')),
    );
    final saving = service.forceSave();
    await controlled.started.future;
    service.dispose();
    controlled.release.complete();
    await saving;
    expect(
      (await controlled.loadPageDocument(pageId)).root.children[1].delta!
          .toPlainText(),
      'Last edit',
    );
  });
}

class _ControlledRepository extends NotesRepository {
  _ControlledRepository(super.db, {this.blockSecond = false});
  final bool blockSecond;
  final secondStarted = Completer<void>();
  final releaseSecond = Completer<void>();
  final started = Completer<void>();
  final release = Completer<void>();
  final capturedTexts = <String>[];
  int calls = 0;
  int active = 0;
  int maxActive = 0;

  @override
  Future<String> savePageNodes(
    String pageId,
    List<Node> nodes, {
    String? expectedVersion,
  }) async {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    if (!started.isCompleted) started.complete();
    try {
      await release.future;
      if (blockSecond && calls == 2) {
        secondStarted.complete();
        await releaseSecond.future;
      }
      capturedTexts.add(nodes[1].delta!.toPlainText());
      return await super.savePageNodes(
        pageId,
        nodes,
        expectedVersion: expectedVersion,
      );
    } finally {
      active--;
    }
  }
}

class _FailingRepository extends NotesRepository {
  _FailingRepository(super.db);
  bool fail = true;
  @override
  Future<String> savePageNodes(
    String pageId,
    List<Node> nodes, {
    String? expectedVersion,
  }) async {
    if (fail) {
      fail = false;
      throw StateError('Injected save failure');
    }
    return super.savePageNodes(pageId, nodes, expectedVersion: expectedVersion);
  }
}

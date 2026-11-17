import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/title_edit_session.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/editor/components/page_header.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart';
import 'package:notes_here/ui/editor/components/database/database_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Finder titleField() => find.descendant(
    of: find.byType(PageHeader),
    matching: find.byType(TextField),
  );

  for (final keyed in [true, false]) {
    testWidgets(
      'switch before debounce flushes the old page title (keyed: $keyed)',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = NotesRepository(db);
        final first = await repo.createPage(title: 'First');
        final second = await repo.createPage(title: 'Second');
        final selected = ValueNotifier(first);
        addTearDown(selected.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: selected,
                builder: (_, id, _) => PageEditorView(
                  key: keyed ? ValueKey(id) : null,
                  repository: repo,
                  pageId: id,
                  title: id == first ? 'First' : 'Second',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final oldEditor = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState;
        await tester.enterText(titleField(), 'Last keystroke');
        selected.value = second;
        await tester.pump(); // No 300ms wait before the page is replaced.
        await tester.pumpAndSettle();
        expect((await repo.getPage(first))!.title, 'Last keystroke');
        expect((await repo.getPage(second))!.title, 'Second');
        expect(oldEditor.isDisposed, isTrue);
        expect(
          tester.widget<TextField>(titleField()).controller!.text,
          'Second',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final editLocally in [true, false]) {
    testWidgets(
      'background title is deferred while focused (edited: $editLocally)',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = NotesRepository(db);
        final id = await repo.createPage(title: 'Original');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: StreamBuilder<Page?>(
                stream: repo.watchPage(id),
                builder: (_, snapshot) => snapshot.data == null
                    ? const SizedBox()
                    : PageEditorView(
                        repository: repo,
                        pageId: id,
                        title: snapshot.data!.title,
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(titleField());
        await tester.pump();
        if (editLocally) {
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'Local typing',
              selection: TextSelection(baseOffset: 2, extentOffset: 5),
              composing: TextRange(start: 0, end: 5),
            ),
          );
          await tester.pump();
        }
        final controller = tester.widget<TextField>(titleField()).controller!;
        final value = controller.value;
        await repo.updatePageTitle(id, 'Background');
        await tester.pumpAndSettle();
        expect(
          controller.value,
          value,
        ); // Text, selection and IME composition survive.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(controller.text, editLocally ? 'Local typing' : 'Background');
        expect(
          (await repo.getPage(id))!.title,
          editLocally ? 'Local typing' : 'Background',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('app suspension flushes the title immediately', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NotesRepository(db);
    final id = await repo.createPage(title: 'Original');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: PageEditorView(repository: repo, pageId: id, title: 'Original'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(titleField(), 'Before suspension');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect((await repo.getPage(id))!.title, 'Before suspension');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'switching after a deferred background update recommits the active local title',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NotesRepository(db);
      final id = await repo.createPage(title: 'Original');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: StreamBuilder<Page?>(
              stream: repo.watchPage(id),
              builder: (_, snapshot) => snapshot.data == null
                  ? const SizedBox()
                  : PageEditorView(
                      repository: repo,
                      pageId: id,
                      title: snapshot.data!.title,
                    ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(titleField(), 'Local');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect((await repo.getPage(id))!.title, 'Local');
      await repo.updatePageTitle(id, 'Background');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect((await repo.getPage(id))!.title, 'Local');
    },
  );

  testWidgets('a late page load cannot replace the current editor', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _ControlledLoadRepository(db);
    final first = await repo.createPage(title: 'First');
    final second = await repo.createPage(title: 'Second');
    repo.delayedPage = first;
    final selected = ValueNotifier(first);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: selected,
            builder: (_, id, _) => PageEditorView(
              repository: repo,
              pageId: id,
              title: id == first ? 'First' : 'Second',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    selected.value = second;
    await tester.pumpAndSettle();
    final state = tester
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    repo.release.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState,
      same(state),
    );
    expect(tester.widget<TextField>(titleField()).controller!.text, 'Second');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('failed page loads offer a working retry', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _ControlledLoadRepository(db)..failNext = true;
    final id = await repo.createPage();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: PageEditorView(repository: repo, pageId: id, title: 'Note'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load this page. Retry'), findsOneWidget);
    await tester.tap(find.text('Could not load this page. Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test(
    'title writes from separate sessions are ordered even after a failure',
    () async {
      final db = _ControlledTitleDatabase();
      addTearDown(db.close);
      final repo = NotesRepository(db);
      final id = await repo.createPage();
      final first = repo.updatePageTitle(id, 'Older');
      final failure = expectLater(first, throwsStateError);
      final second = repo.updateRowTitle(id, 'Latest');
      await Future<void>.delayed(Duration.zero);
      expect(db.calls, 1);
      db.release.complete();
      await failure;
      await second;
      expect((await repo.getPage(id))!.title, 'Latest');
      expect(db.calls, 2);
    },
  );

  for (final databaseHeader in [true, false]) {
    for (final edited in [true, false]) {
      testWidgets(
        'inline title defers external text (database: $databaseHeader, edited: $edited)',
        (tester) async {
          final value = ValueNotifier('Original');
          addTearDown(value.dispose);
          final commits = <String>[];
          void commit(String text) {
            commits.add(text);
            value.value = text;
          }

          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(Brightness.light),
              home: Scaffold(
                body: ValueListenableBuilder<String>(
                  valueListenable: value,
                  builder: (_, text, _) => databaseHeader
                      ? DatabaseHeader(
                          title: text,
                          totalRowCount: 0,
                          filteredRowCount: 0,
                          columns: const [],
                          filterRules: const [],
                          searchQuery: '',
                          onSortChanged: (_, _) {},
                          onAddFilter: (_) {},
                          onRemoveFilter: (_) {},
                          onClearFilters: () {},
                          onSearchChanged: (_) {},
                          onAddRow: () {},
                          onTitleChanged: commit,
                        )
                      : TitleCellInput(initialValue: text, onChanged: commit),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final inlineField = find.byType(TextField).first;
          final backingController = tester
              .widget<TextField>(inlineField)
              .controller!;
          await tester.tap(inlineField);
          await tester.pumpAndSettle();
          final field = databaseHeader
              ? inlineField
              : find.byKey(const Key('expanded_database_cell'));
          if (edited) await tester.enterText(field, 'Local');
          final controller = tester.widget<TextField>(field).controller!;
          final before = controller.value;
          value.value = 'Background';
          await tester.pumpAndSettle();
          expect(controller.value, before);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(backingController.text, edited ? 'Local' : 'Background');
          expect(commits, edited ? ['Local'] : isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  test('title snapshots drain in order and survive disposal', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final writes = <String>[];
    var active = 0;
    var maxActive = 0;
    final session = TitleEditSession(
      title: 'Original',
      debounce: const Duration(days: 1),
      save: (text) async {
        active++;
        if (active > maxActive) maxActive = active;
        if (!started.isCompleted) started.complete();
        await release.future;
        writes.add(text);
        active--;
      },
    );
    session.controller.text = 'First';
    session.edited('First');
    final saving = session.flush();
    await started.future;
    session.controller.text = 'Latest';
    session.edited('Latest');
    session.dispose();
    release.complete();
    await saving;
    expect(writes, ['First', 'Latest']);
    expect(maxActive, 1);
  });

  test('a failed older snapshot does not discard the final title queued on disposal', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final saved = <String>[];
    final session = TitleEditSession(
      title: 'Original',
      debounce: const Duration(days: 1),
      save: (text) async {
        if (text == 'Older') {
          started.complete();
          await release.future;
          throw StateError('Injected failure');
        }
        saved.add(text);
      },
    );
    session.controller.text = 'Older';
    session.edited('Older');
    final saving = session.flush();
    await started.future;
    session.controller.text = 'Latest';
    session.edited('Latest');
    session.dispose();
    release.complete();
    await saving;
    expect(saved, ['Latest']);
  });

  test('a failed title save retains dirty text for retry', () async {
    var fail = true;
    var saved = '';
    final session = TitleEditSession(
      title: 'Original',
      save: (text) async {
        if (fail) throw StateError('Injected failure');
        saved = text;
      },
    );
    session.controller.text = 'Local';
    session.edited('Local');
    await session.flush();
    expect(session.status.value, TitleSaveStatus.error);
    fail = false;
    await session.flush();
    expect(saved, 'Local');
    expect(session.status.value, TitleSaveStatus.saved);
    session.dispose();
  });
}

class _ControlledLoadRepository extends NotesRepository {
  _ControlledLoadRepository(super.db);
  String? delayedPage;
  bool failNext = false;
  final release = Completer<void>();
  @override
  Future<({Document document, String version})> loadPageSnapshot(
    String pageId,
  ) async {
    if (failNext) {
      failNext = false;
      throw StateError('Injected load failure');
    }
    final snapshot = await super.loadPageSnapshot(pageId);
    if (pageId == delayedPage) await release.future;
    return snapshot;
  }
}

class _ControlledTitleDatabase extends AppDatabase {
  _ControlledTitleDatabase() : super(NativeDatabase.memory());
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<void> updatePageTitle(String pageId, String title) async {
    calls++;
    if (calls == 1) {
      await release.future;
      throw StateError('Injected old write failure');
    }
    await super.updatePageTitle(pageId, title);
  }
}

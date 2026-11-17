import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart'
    as cells;
import 'package:notes_here/ui/editor/components/database/database_save_status.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  const key = (databaseId: 'd', rowId: 'r', columnId: 'c', title: false);

  test(
    'acknowledgement waits for success; failure retains draft and retry',
    () async {
      final release = Completer<void>();
      var fail = true;
      final saves = DatabaseCellSaves((_, value) async {
        await release.future;
        if (fail) throw StateError('write');
      });
      final entry = saves.entry(key);
      expect(entry.display('old'), 'old');
      final writing = saves.submit(key, 'new');
      expect(entry.phase, CellSavePhase.saving);
      expect(entry.acknowledged, 'old');
      expect(entry.display('old'), 'new');
      release.complete();
      await writing;
      expect(entry.phase, CellSavePhase.failed);
      expect(entry.acknowledged, 'old');
      expect(entry.display('old'), 'new');
      fail = false;
      await saves.retry(key);
      expect(entry.phase, CellSavePhase.saved);
      expect(entry.acknowledged, 'new');
      expect(
        entry.display('old'),
        'new',
        reason: 'a delayed row stream must not flash stale text',
      );
      expect(entry.display('new'), 'new');
      expect(entry.hasDraft, isFalse);
    },
  );

  test(
    'one cell serializes rapid writes and acknowledges only completed values',
    () async {
      final first = Completer<void>(), second = Completer<void>();
      final calls = <dynamic>[];
      final saves = DatabaseCellSaves((_, value) {
        calls.add(value);
        return calls.length == 1 ? first.future : second.future;
      });
      final entry = saves.entry(key)..display('old');
      final writing = saves.submit(key, 'first');
      await Future<void>.value();
      saves.submit(key, 'latest');
      expect(calls, ['first']);
      first.complete();
      await Future<void>.value();
      await Future<void>.value();
      expect(calls, ['first', 'latest']);
      expect(entry.acknowledged, 'first');
      expect(entry.phase, CellSavePhase.saving);
      expect(entry.display('first'), 'latest');
      second.complete();
      await writing;
      expect(entry.acknowledged, 'latest');
    },
  );

  test(
    'null, false, zero and mutable arrays retain their exact values',
    () async {
      final values = <dynamic>[];
      final saves = DatabaseCellSaves((_, value) async {
        values.add(value);
      });
      final entry = saves.entry(key)..display('old');
      for (final value in [null, false, 0]) {
        await saves.submit(key, value);
        expect(entry.display('old'), value);
      }
      final list = ['a'];
      final task = saves.submit(key, list);
      list.add('mutated');
      await task;
      expect(values, [
        null,
        false,
        0,
        ['a'],
      ]);
    },
  );

  test('retry only retries failed cells in the selected database', () async {
    var fail = true;
    final calls = <CellSaveKey>[];
    final saves = DatabaseCellSaves((key, _) async {
      calls.add(key);
      if (fail) throw StateError('write');
    });
    const other = (
      databaseId: 'other',
      rowId: 'r',
      columnId: 'c',
      title: false,
    );
    await saves.submit(key, 'draft');
    await saves.submit(other, 'other draft');
    fail = false;
    await saves.retryDatabase('d');
    expect(calls, [key, other, key]);
    expect(saves.entry(other).phase, CellSavePhase.failed);
  });

  test('writer validation errors become failed drafts, not synchronous UI exceptions', () async {
    final saves = DatabaseCellSaves((_, value) async {
      jsonEncode(value);
    });
    final entry = saves.entry(key)..display('old');
    await saves.submit(key, double.infinity);
    expect(entry.phase, CellSavePhase.failed);
    expect(entry.acknowledged, 'old');
    expect(entry.desired, double.infinity);
  });

  test('a superseded failure does not overwrite a newer queued edit', () async {
    final first = Completer<void>();
    final calls = <dynamic>[];
    final saves = DatabaseCellSaves((_, value) async {
      calls.add(value);
      if (calls.length == 1) {
        await first.future;
        throw StateError('older write failed');
      }
    });
    final entry = saves.entry(key)..display('old');
    final writing = saves.submit(key, 'older');
    await Future<void>.value();
    saves.submit(key, 'latest');
    first.complete();
    await writing;
    expect(calls, ['older', 'latest']);
    expect(entry.phase, CellSavePhase.saved);
    expect(entry.acknowledged, 'latest');
  });

  test('unmounted failed drafts remain available while clean cells can be released', () async {
    final saves = DatabaseCellSaves((_, value) async {
      if (value == 'draft') throw StateError('write');
    });
    final failed = saves.entry(key)..display('old');
    await saves.submit(key, 'draft');
    saves.release(key);
    await Future<void>.value();
    expect(identical(saves.entry(key), failed), isTrue);
    expect(failed.display('old'), 'draft');
    await saves.submit(key, 'saved');
    saves.release(key);
    await Future<void>.value();
    expect(saves.forDatabase('d'), isEmpty);
  });

  test('repository session persists title and property writes without replacing other fields', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = NotesRepository(db);
    final database = await repo.createDatabase();
    final column = await repo.addColumn(database, name: 'Text', type: 'text');
    final row = await repo.createDatabaseRow(
      database,
      title: 'old',
      properties: {'legacy': 42},
    );
    final saves = DatabaseCellSaves.forRepository(repo);
    await saves.submit((
      databaseId: database,
      rowId: row,
      columnId: column,
      title: false,
    ), 'new');
    await saves.submit((
      databaseId: database,
      rowId: row,
      columnId: 'title',
      title: true,
    ), 'New title');
    expect((await repo.getPage(row))!.title, 'New title');
    expect(jsonDecode((await repo.getPage(row))!.properties!), {
      'legacy': 42,
      column: 'new',
    });
    expect(identical(saves, DatabaseCellSaves.forRepository(repo)), isTrue);
    await db.close();
  });

  testWidgets('failed edit survives remount and can be retried from status', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = NotesRepository(db);
    var fail = true;
    dynamic stored = 'old';
    final saves = DatabaseCellSaves((_, value) async {
      if (fail) throw StateError('write');
      stored = value;
    });
    final column = DatabaseColumn(
      id: 'c',
      databaseId: 'd',
      name: 'Text',
      type: 'text',
      width: 300,
      orderKey: 'a',
      createdAt: DateTime(2026),
    );
    Widget mount() => MaterialApp(
      theme: buildTheme(Brightness.light),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            cells.DataCell(
              column: column,
              width: 300,
              borderColor: Colors.transparent,
              rowId: 'r',
              saves: saves,
              pageTitle: '',
              cellValue: 'old',
              repository: repo,
              onUpdateTitle: (_) => throw StateError('fallback'),
              onUpdateValue: (_) => throw StateError('fallback'),
              onOpenPage: () {},
            ),
            DatabaseSaveStatus(saves: saves, databaseId: 'd'),
          ],
        ),
      ),
    );
    await tester.pumpWidget(mount());
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expanded_database_cell')),
      'draft',
    );
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(stored, 'old');
    expect(find.text('Не сохранено ячеек: 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(mount());
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'draft',
    );
    await tester.tap(find.byKey(const Key('database_recover_saves')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .any((text) => text.data == 'draft'),
      isTrue,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Не сохранено ячеек: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('database_recover_saves')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Использовать сохранённую версию'));
    await tester.pumpAndSettle();
    expect(stored, 'old');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'old',
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expanded_database_cell')),
      'draft',
    );
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    fail = false;
    await tester.tap(find.byKey(const Key('database_retry_saves')));
    await tester.pumpAndSettle();
    expect(stored, 'draft');
    expect(find.text('Сохранено'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}

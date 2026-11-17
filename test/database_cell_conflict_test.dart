import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_cell_conflict.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart'
    as cells;
import 'package:notes_here/ui/editor/components/database/database_save_status.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  test('atomic cell comparison preserves unrelated edits and detects unseen updates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = NotesRepository(db);
    final database = await repo.createDatabase();
    final column = await repo.addColumn(database, name: 'Text', type: 'text');
    final other = await repo.addColumn(database, name: 'Other', type: 'text');
    final title = (await repo.getColumns(database))
        .firstWhere((col) => col.type == 'title')
        .id;
    final row = await repo.createDatabaseRow(
      database,
      title: 'Old title',
      properties: {column: 'old'},
    );
    final key = (
      databaseId: database,
      rowId: row,
      columnId: column,
      title: false,
    );
    final saves = DatabaseCellSaves.forRepository(repo);
    final entry = saves.entry(key)..display('old');
    saves.editingChanged(key, true);
    await repo.patchRowProperties(row, {
      other: 'independent',
      column: 'remote',
    });
    await saves.submit(
      key,
      'local',
    ); // no display(remote) call: stream has not caught up
    saves.editingChanged(key, false);
    expect(entry.phase, CellSavePhase.conflict);
    expect(entry.desired, 'local');
    expect(entry.remoteValue, 'remote');
    expect(await saves.flush(), isFalse);
    await saves.retryDatabase(database);
    expect(entry.phase, CellSavePhase.conflict);
    expect(
      jsonDecode((await repo.getPage(row))!.properties!)[column],
      'remote',
    );
    await repo.patchRowProperties(row, {column: 'newer'});
    await saves.resolveConflict(
      key,
      keepLocal: true,
      compareReviewed: true,
      reviewedRemote: 'remote',
    );
    expect(entry.phase, CellSavePhase.conflict);
    expect(entry.remoteValue, 'newer');
    expect(entry.conflictBase, 'old');
    await saves.resolveConflict(
      key,
      keepLocal: true,
      compareReviewed: true,
      reviewedRemote: 'newer',
    );
    expect(entry.phase, CellSavePhase.saved);
    expect(jsonDecode((await repo.getPage(row))!.properties!), {
      column: 'local',
      other: 'independent',
    });
    await repo.compareAndSetDatabaseCell(
      row,
      title,
      'New title',
      'Old title',
      title: true,
    );
    await expectLater(
      repo.compareAndSetDatabaseCell(
        row,
        title,
        'Stale title',
        'Old title',
        title: true,
      ),
      throwsA(isA<DatabaseCellConflict>()),
    );
    expect((await repo.getPage(row))!.title, 'New title');
    await db.close();
  });

  testWidgets('tag conflict presents labels rather than internal IDs', (
    tester,
  ) async {
    const key = (databaseId: 'd', rowId: 'r', columnId: 'c', title: false);
    final saves = DatabaseCellSaves(
      (_, _) async {},
      guardedWrite: (_, _, _) async {
        throw const DatabaseCellConflict('remote-id');
      },
    );
    final entry = saves.entry(key)
      ..display('old-id')
      ..columnType = 'select'
      ..columnOptions = jsonEncode([
        {'id': 'old-id', 'label': 'Original tag'},
        {'id': 'local-id', 'label': 'My tag'},
        {'id': 'remote-id', 'label': 'External tag'},
      ]);
    await saves.submit(key, 'local-id');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DatabaseSaveStatus(saves: saves, databaseId: 'd'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('database_resolve_conflicts')));
    await tester.pumpAndSettle();
    final values = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((text) => text.data)
        .toList();
    expect(values, containsAll(['Original tag', 'External tag', 'My tag']));
    expect(values, isNot(contains('remote-id')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(entry.phase, CellSavePhase.conflict);
  });

  for (final type in ['text', 'title', 'number', 'url']) {
    for (final edited in [false, true]) {
      testWidgets(
        '$type edited=$edited defers external updates without moving the caret',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          final repo = NotesRepository(db);
          final dynamic original = type == 'number'
              ? 10
              : type == 'url'
              ? 'https://old.test'
              : 'original';
          final dynamic remote = type == 'number'
              ? 20
              : type == 'url'
              ? 'https://remote.test'
              : 'remote';
          final dynamic local = type == 'number'
              ? 15
              : type == 'url'
              ? 'https://local.test'
              : 'local';
          final current = ValueNotifier<dynamic>(original);
          final key = (
            databaseId: 'd',
            rowId: 'r',
            columnId: 'c',
            title: type == 'title',
          );
          final saves = DatabaseCellSaves(
            (_, _) async => fail('missing baseline'),
            guardedWrite: (_, value, expected) async {
              if (jsonEncode(current.value) != jsonEncode(expected)) {
                throw DatabaseCellConflict(current.value);
              }
              current.value = value;
            },
          );
          final column = DatabaseColumn(
            id: 'c',
            databaseId: 'd',
            name: 'Column',
            type: type,
            width: 300,
            orderKey: 'a',
            createdAt: DateTime(2026),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(Brightness.light),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Column(
                  children: [
                    ValueListenableBuilder<dynamic>(
                      valueListenable: current,
                      builder: (_, value, _) => cells.DataCell(
                        saves: saves,
                        rowId: 'r',
                        column: column,
                        width: 300,
                        borderColor: Colors.transparent,
                        pageTitle: type == 'title' ? value as String : 'Row',
                        cellValue: value,
                        repository: repo,
                        onUpdateTitle: (_) {},
                        onUpdateValue: (_) {},
                        onOpenPage: () {},
                      ),
                    ),
                    DatabaseSaveStatus(saves: saves, databaseId: 'd'),
                  ],
                ),
              ),
            ),
          );
          if (type == 'url') {
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await mouse.addPointer();
            await mouse.moveTo(tester.getCenter(find.byType(cells.DataCell)));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Edit URL'));
            await mouse.removePointer();
          } else if (type == 'number') {
            await tester.tap(find.text('10'));
          } else {
            await tester.tap(find.byType(TextField));
          }
          await tester.pumpAndSettle();
          final field = type == 'text' || type == 'title'
              ? find.byKey(const Key('expanded_database_cell'))
              : find.byType(TextField);
          if (edited) await tester.enterText(field, local.toString());
          final controller = tester.widget<TextField>(field).controller!;
          final before = controller.value;
          current.value = remote;
          await tester.pumpAndSettle();
          expect(controller.value, before);
          if (type == 'text' || type == 'title') {
            await tester.tapAt(const Offset(700, 500));
          } else {
            FocusManager.instance.primaryFocus?.unfocus();
          }
          await tester.pumpAndSettle();
          final entry = saves.entry(key);
          expect(entry.editing, isFalse);
          dynamic expectedAfter = remote;
          if (edited) {
            expect(entry.phase, CellSavePhase.conflict);
            expect(entry.desired, local);
            expect(current.value, remote);
            await tester.tap(
              find.byKey(const Key('database_resolve_conflicts')),
            );
            await tester.pumpAndSettle();
            expect(find.text('Cell changed elsewhere'), findsWidgets);
            if (type == 'text') {
              current.value = 'newer';
              await tester.pumpAndSettle();
              await tester.tap(find.text('Save my version'));
              await tester.pumpAndSettle();
              expect(entry.phase, CellSavePhase.conflict);
              expect(
                find.text(
                  'This cell changed again. Review the new value before saving.',
                ),
                findsOneWidget,
              );
              expectedAfter = 'newer';
            }

            await tester.tap(find.text('Use the new value'));
            await tester.pumpAndSettle();
            expect(entry.phase, CellSavePhase.saved);
            expect(current.value, expectedAfter);
          } else {
            expect(entry.submitted, isFalse);
          }
          if (type == 'text' || type == 'title') {
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              expectedAfter,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          current.dispose();
          await db.close();
        },
      );
    }
  }
}

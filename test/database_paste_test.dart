import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_paste.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/services/database_range_edits.dart';
import 'package:notes_here/sync/sync_outbox.dart';
import 'package:notes_here/ui/editor/components/database/database_grid_selection.dart';

DatabaseColumn col(String type, {String? options}) => DatabaseColumn(
  id: type,
  databaseId: 'd',
  name: type,
  type: type,
  options: options,
  width: 120,
  orderKey: type,
  createdAt: DateTime(2026),
);
Matcher issue(DatabasePasteIssue value) => throwsA(
  isA<DatabasePasteException>().having((e) => e.issue, 'issue', value),
);
void main() {
  test(
    'TSV roundtrips tabs, quotes, CRLF, multiline and trailing empty fields',
    () {
      final columns = [col('title'), col('text')];
      final rows = [
        DatabaseRowData(
          Page(id: 'r', title: 'A "quote"', createdAt: DateTime(2026)),
          properties: {'text': 'a\tb\r\nc'},
        ),
      ];
      expect(parseDatabaseTsv(databaseRangeTsv(columns, rows, 0, 0, 0, 1)), [
        ['A "quote"', 'a\tb\r\nc'],
      ]);
      expect(parseDatabaseTsv('one\t\r\ntwo\t\r\n'), [
        ['one', ''],
        ['two', ''],
      ]);
      expect(parseDatabaseTsv(''), [
        [''],
      ]);
      expect(parseDatabaseTsv('a\n\n'), [
        ['a'],
        [''],
      ]);
      expect(
        () => parseDatabaseTsv('"unfinished'),
        issue(DatabasePasteIssue.malformed),
      );
      expect(
        () => parseDatabaseTsv('"a" x'),
        issue(DatabasePasteIssue.malformed),
      );
      expect(
        () => parseDatabaseTsv('a\tb\nc'),
        issue(DatabasePasteIssue.ragged),
      );
      expect(
        () => parseDatabaseTsv(List.filled(2001, 'a').join('\t')),
        issue(DatabasePasteIssue.tooLarge),
      );
    },
  );
  test('multitag clipboard roundtrips labels that contain commas', () {
    final column = col(
      'multi_select',
      options: '[{"id":"a","label":"Alpha"},{"id":"b","label":"One, Two"}]',
    );
    final row = DatabaseRowData(
      Page(id: 'r', title: '', createdAt: DateTime(2026)),
      properties: {
        column.id: ['a', 'b'],
      },
    );
    final copied = databaseRangeTsv([column], [row], 0, 0, 0, 0);
    expect(
      parseDatabasePasteValue(column, parseDatabaseTsv(copied).single.single),
      ['a', 'b'],
    );
  });
  test('typed conversion is strict and preserves plain text literally', () {
    expect(parseDatabasePasteValue(col('text'), ' =SUM(2) '), ' =SUM(2) ');
    expect(parseDatabasePasteValue(col('number'), '12,5'), 12.5);
    expect(parseDatabasePasteValue(col('number'), ''), isNull);
    expect(
      parseDatabasePasteValue(
        col('number', options: '{"format":"duration_human"}'),
        '-1h30m',
      ),
      -5400,
    );
    for (final value in ['32+32', 'NaN', 'Infinity', '1h']) {
      expect(
        () => parseDatabasePasteValue(col('number'), value),
        throwsA(isA<DatabasePasteException>()),
      );
    }
    expect(parseDatabasePasteValue(col('checkbox'), 'ДА'), isTrue);
    expect(parseDatabasePasteValue(col('checkbox'), ''), isFalse);
    expect(
      () => parseDatabasePasteValue(col('checkbox'), 'maybe'),
      issue(DatabasePasteIssue.checkbox),
    );
    expect(parseDatabasePasteValue(col('date'), '2024-02-29'), '2024-02-29');
    for (final value in [
      '2025-02-29',
      '09/11/2026',
      '2026-01-01T10:00:00',
      '1969-01-01',
    ]) {
      expect(
        () => parseDatabasePasteValue(col('date'), value),
        issue(DatabasePasteIssue.date),
      );
    }
    expect(
      parseDatabasePasteValue(col('url'), 'example.com/path'),
      'https://example.com/path',
    );
    expect(
      () => parseDatabasePasteValue(col('url'), 'javascript:alert(1)'),
      issue(DatabasePasteIssue.url),
    );
    expect(
      () => parseDatabasePasteValue(col('formula'), '12'),
      issue(DatabasePasteIssue.unsupported),
    );
  });
  test('tag labels resolve existing IDs without creating or guessing ambiguous tags', () {
    const options =
        '[{"id":"a","label":"Alpha"},{"id":"b","label":"Beta"},{"id":"c","label":"One, Two"}]';
    expect(
      parseDatabasePasteValue(col('select', options: options), 'alpha'),
      'a',
    );
    expect(
      parseDatabasePasteValue(
        col('multi_select', options: options),
        'Alpha, Beta',
      ),
      ['a', 'b'],
    );
    expect(
      parseDatabasePasteValue(
        col('multi_select', options: options),
        '["One, Two","Alpha"]',
      ),
      ['c', 'a'],
    );
    expect(
      () => parseDatabasePasteValue(col('select', options: options), 'Unknown'),
      issue(DatabasePasteIssue.tag),
    );
    expect(
      () => parseDatabasePasteValue(
        col(
          'select',
          options: '[{"id":"1","label":"X"},{"id":"2","label":"X"}]',
        ),
        'X',
      ),
      issue(DatabasePasteIssue.tag),
    );
  });
  test('planner fills a selection, checks bounds/shape and reports invalid cell coordinates', () {
    final columns = [col('text'), col('number')];
    final rows = [
      for (var i = 0; i < 2; i++)
        DatabaseRowData(Page(id: '$i', title: 'R', createdAt: DateTime(2026))),
    ];
    List<DatabaseCellChange> plan(
      String text, {
      int height = 1,
      int width = 1,
    }) => planDatabasePaste(
      text: text,
      columns: columns,
      rows: rows,
      startRow: 0,
      startColumn: 0,
      selectedRows: height,
      selectedColumns: width,
    );
    expect(plan('12', height: 2, width: 2).map((c) => c.after), [
      '12',
      12,
      '12',
      12,
    ]);
    expect(() => plan('a\t1\textra'), issue(DatabasePasteIssue.bounds));
    expect(
      () => plan('a\t1', height: 2, width: 2),
      issue(DatabasePasteIssue.shape),
    );
    expect(
      () => plan('a\t1\nb\t32+32'),
      throwsA(
        isA<DatabasePasteException>()
            .having((e) => e.row, 'row', 2)
            .having((e) => e.column, 'column', 'number')
            .having((e) => e.numericIssue, 'numeric', isNotNull),
      ),
    );
  });

  group('atomic range history', () {
    late AppDatabase db;
    late NotesRepository repo;
    late DatabaseRangeEdits history;
    late String database, number, other, first, second;
    late List<DatabaseColumn> columns;
    late List<DatabaseRowData> rows;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = NotesRepository(db);
      history = DatabaseRangeEdits.forRepository(repo);
      database = await repo.createDatabase();
      number = await repo.addColumn(database, name: 'Number', type: 'number');
      other = await repo.addColumn(database, name: 'Other', type: 'text');
      first = await repo.createDatabaseRow(
        database,
        title: 'First',
        properties: {number: 1, other: 'unchanged'},
      );
      second = await repo.createDatabaseRow(
        database,
        title: 'Second',
        properties: {number: 2},
      );
      final all = await repo.getColumns(database);
      columns = [
        all.firstWhere((c) => c.type == 'title'),
        all.firstWhere((c) => c.id == number),
      ];
      rows = [
        DatabaseRowData((await repo.getPage(first))!),
        DatabaseRowData((await repo.getPage(second))!),
      ];
    });
    tearDown(() => db.close());
    List<DatabaseCellChange> plan() => planDatabasePaste(
      text: 'New first\t12,5\nNew second\t20',
      columns: columns,
      rows: rows,
      startRow: 0,
      startColumn: 0,
    );
    Future<dynamic> value(String row) async =>
        jsonDecode((await repo.getPage(row))!.properties!)[number];
    test(
      'one undo/redo restores the whole range and preserves unrelated columns',
      () async {
        expect(await history.paste(plan()), 4);
        expect(await value(first), 12.5);
        expect((await repo.getPage(second))!.title, 'New second');
        await repo.patchRowProperties(first, {other: 'external'});
        expect(await history.undo(database), 4);
        expect(await value(first), 1);
        expect(await value(second), 2);
        expect((await repo.getPage(first))!.title, 'First');
        expect(
          jsonDecode((await repo.getPage(first))!.properties!)[other],
          'external',
        );
        expect(await history.redo(database), 4);
        expect(await value(first), 12.5);
        expect(history.canUndo(database), isTrue);
        expect(history.canRedo(database), isFalse);
      },
    );
    test(
      'external edit rejects complete undo and retains history for retry',
      () async {
        await history.paste(plan());
        await repo.patchRowProperties(second, {number: 99});
        await expectLater(
          history.undo(database),
          issue(DatabasePasteIssue.conflict),
        );
        expect(await value(first), 12.5);
        expect(await value(second), 99);
        expect((await repo.getPage(first))!.title, 'New first');
        expect(history.canUndo(database), isTrue);
        await repo.patchRowProperties(second, {number: 20});
        await history.undo(database);
        expect(await value(first), 1);
      },
    );
    test('column metadata changes and row trash reject stale paste before any write', () async {
      final changes = plan();
      await repo.updateColumn(number, options: '{"format":"percent"}');
      await expectLater(
        history.paste(changes),
        issue(DatabasePasteIssue.conflict),
      );
      expect((await repo.getPage(first))!.title, 'First');
      expect(history.canUndo(database), isFalse);
      columns[1] = (await repo.getColumns(database))
          .firstWhere((c) => c.id == number);
      final newer = plan();
      await repo.deleteDatabaseRow(second);
      await expectLater(
        history.paste(newer),
        issue(DatabasePasteIssue.conflict),
      );
      expect(await value(first), 1);
    });
    test('write-time failure rolls back rows, search projection and sync outbox', () async {
      await SyncOutbox(db).enable();
      final outbox = await db
          .customSelect('SELECT COUNT(*) AS n FROM notes_sync_outbox')
          .getSingle();
      await db.customStatement(
        "CREATE TRIGGER fail_paste BEFORE UPDATE ON pages WHEN NEW.id = '$second' BEGIN SELECT RAISE(ABORT, 'blocked'); END;",
      );
      await expectLater(history.paste(plan()), throwsA(anything));
      expect((await repo.getPage(first))!.title, 'First');
      expect(await value(first), 1);
      final count = await db
          .customSelect('SELECT COUNT(*) AS n FROM notes_sync_outbox')
          .getSingle();
      expect(count.read<int>('n'), outbox.read<int>('n'));
      expect(history.canUndo(database), isFalse);
      expect(
        (await repo.queryDatabaseRows(database, search: 'New first')).rows,
        isEmpty,
      );
    });
    test(
      'legacy invalid numeric content is restored exactly by undo',
      () async {
        await repo.patchRowProperties(first, {number: 'legacy 32+32'});
        rows[0] = DatabaseRowData((await repo.getPage(first))!);
        await history.paste(plan());
        await history.undo(database);
        expect(await value(first), 'legacy 32+32');
        await history.redo(database);
        expect(await value(first), 12.5);
      },
    );
    test(
      'unsaved target draft blocks paste; unrelated invalid draft does not',
      () async {
        final key = (
          databaseId: database,
          rowId: first,
          columnId: number,
          title: false,
        );
        final saves = history.saves;
        saves.entry(key)
          ..columnType = 'number'
          ..display(1);
        await saves.submit(key, 'bad');
        await expectLater(
          history.paste(plan()),
          issue(DatabasePasteIssue.drafts),
        );
        expect(await value(first), 1);
        expect(saves.entry(key).desired, 'bad');
        saves.discardFailed(database);
        final unrelated = (
          databaseId: database,
          rowId: first,
          columnId: 'elsewhere',
          title: false,
        );
        saves.entry(unrelated).columnType = 'number';
        await saves.submit(unrelated, 'bad');
        await history.paste(plan());
        expect(await value(first), 12.5);
      },
    );
    test(
      'redo is cleared by a new paste and histories are database scoped',
      () async {
        await history.paste(plan());
        await history.undo(database);
        expect(await history.undo('other database'), 0);
        expect(history.canRedo(database), isTrue);
        await history.paste(plan());
        expect(history.canRedo(database), isFalse);
      },
    );
  });
  test('batch gate makes flush wait and serializes a newer typed edit after acknowledgement', () async {
    final release = Completer<void>(), writes = <dynamic>[];
    final saves = DatabaseCellSaves((_, value) async {
      writes.add(value);
    });
    const key = (databaseId: 'd', rowId: 'r', columnId: 'number', title: false);
    final entry = saves.entry(key)
      ..columnType = 'number'
      ..display(1);
    final batch = saves.applyBatch([
      DatabaseCellChange(
        databaseId: 'd',
        rowId: 'r',
        column: col('number'),
        before: 1,
        after: 10,
      ),
    ], () => release.future);
    var flushed = false;
    final flush = saves.flush().then((_) => flushed = true);
    final typing = saves.submit(key, 20);
    await Future<void>.value();
    expect(writes, isEmpty);
    expect(flushed, isFalse);
    release.complete();
    await batch;
    await typing;
    await flush;
    expect(writes, [20]);
    expect(entry.acknowledged, 20);
    expect(entry.desired, 20);
  });
}

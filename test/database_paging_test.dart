import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/db/database_rows_query.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late String database;
  late String number;
  late String text;
  late String done;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    database = await repo.createDatabase();
    number = await repo.addColumn(database, name: 'Points', type: 'number');
    text = await repo.addColumn(database, name: 'Notes', type: 'text');
    done = (await repo.getColumns(database))
        .firstWhere((c) => c.type == 'checkbox')
        .id;
  });
  tearDown(() => db.close());

  Future<void> seed(int count) async {
    await db.batch((batch) {
      batch.insertAll(
        db.pages,
        List.generate(count, (i) {
          final title = 'Row ${i.toString().padLeft(4, '0')}';
          final properties = jsonEncode({
            number: count - i,
            done: i.isEven,
            text: 'Note $i',
          });
          return PagesCompanion(
            id: drift.Value('row-$i'),
            databaseId: drift.Value(database),
            title: drift.Value(title),
            properties: drift.Value(properties),
            titleFolded: drift.Value(title.toLowerCase()),
            propertiesFolded: drift.Value(foldProperties(properties)),
            orderKey: drift.Value(i.toString().padLeft(8, '0')),
          );
        }),
      );
    });
  }

  test(
    'pages are bounded with correct counts and deterministic ordering',
    () async {
      await seed(123);
      final first = await repo.queryDatabaseRows(database);
      final second = await repo.queryDatabaseRows(database, offset: 50);
      final last = await repo.queryDatabaseRows(database, offset: 100);
      expect(first.rows.length, 50);
      expect(first.totalCount, 123);
      expect(second.rows.first.page.id, 'row-50');
      expect(last.rows.length, 23);
      expect(
        [
          ...first.rows,
          ...second.rows,
          ...last.rows,
        ].map((r) => r.page.id).toSet().length,
        123,
      );
      final clamped = await repo.queryDatabaseRows(database, offset: 10000);
      expect(clamped.offset, 100);
      expect(clamped.rows.length, 23);
      await expectLater(
        repo.queryDatabaseRows(database, limit: 201),
        throwsArgumentError,
      );
      await expectLater(
        repo.queryDatabaseRows(database, offset: -1),
        throwsArgumentError,
      );
    },
  );

  test('filter, search and numeric sort run before pagination', () async {
    await seed(120);
    final page = await repo.queryDatabaseRows(
      database,
      limit: 10,
      sort: DatabaseSortConfig(columnId: number),
      filters: [DatabaseFilterRule(columnId: done, operator: 'is_true')],
    );
    expect(page.totalCount, 120);
    expect(page.filteredCount, 60);
    expect(page.rows.first.page.id, 'row-118');
    final search = await repo.queryDatabaseRows(database, search: 'Note 119');
    expect(search.filteredCount, 1);
    expect(search.rows.single.page.id, 'row-119');
  });

  test(
    'Unicode search caches are refreshed on title and property edits',
    () async {
      final id = await repo.createDatabaseRow(
        database,
        title: 'ЗАМЕТКА',
        properties: {text: 'ПРИВЕТ'},
      );
      expect(
        (await repo.queryDatabaseRows(
          database,
          search: 'заметка',
        )).rows.single.page.id,
        id,
      );
      expect(
        (await repo.queryDatabaseRows(
          database,
          filters: [
            DatabaseFilterRule(
              columnId: text,
              operator: 'contains',
              value: 'привет',
            ),
          ],
        )).filteredCount,
        1,
      );
      await repo.updateRowTitle(id, 'ДРУГОЕ');
      await repo.patchRowProperties(id, {text: 'НОВОЕ'});
      expect(
        (await repo.queryDatabaseRows(
          database,
          search: 'заметка',
        )).filteredCount,
        0,
      );
      expect(
        (await repo.queryDatabaseRows(database, search: 'новое')).filteredCount,
        1,
      );
      expect(
        (await repo.queryDatabaseRows(
          database,
          search: 'другое',
        )).filteredCount,
        1,
      );
    },
  );

  test(
    'sort keeps empty values last in both directions and excludes trash',
    () async {
      final missing = await repo.createDatabaseRow(database, title: 'Empty');
      final high = await repo.createDatabaseRow(
        database,
        properties: {number: 20},
      );
      final low = await repo.createDatabaseRow(
        database,
        properties: {number: 2},
      );
      final deleted = await repo.createDatabaseRow(
        database,
        properties: {number: 1},
      );
      await repo.trashPage(deleted);
      for (final asc in [true, false]) {
        final result = await repo.queryDatabaseRows(
          database,
          sort: DatabaseSortConfig(columnId: number, ascending: asc),
        );
        expect(
          result.rows.map((r) => r.page.id),
          asc ? [low, high, missing] : [high, low, missing],
        );
        expect(result.totalCount, 3);
      }
      await repo.trashDatabase(database);
      final result = await repo.queryDatabaseRows(database);
      expect(result.rows, isEmpty);
      expect(result.totalCount, 0);
    },
  );

  test(
    'invalid numeric strings sort as zero rather than a numeric prefix',
    () async {
      final invalid = await repo.createDatabaseRow(
        database,
        properties: {number: '12oops'},
      );
      final numeric = await repo.createDatabaseRow(
        database,
        properties: {number: 2},
      );
      final signed = await repo.createDatabaseRow(
        database,
        properties: {number: '+10'},
      );
      final page = await repo.queryDatabaseRows(
        database,
        sort: DatabaseSortConfig(columnId: number),
      );
      expect(page.rows.map((r) => r.page.id), [invalid, numeric, signed]);
    },
  );

  test(
    'query values are bound literals and malformed JSON does not crash reading',
    () async {
      final literal = "' OR 1=1 -- %_";
      final id = await repo.createDatabaseRow(
        database,
        properties: {text: literal},
      );
      final other = await repo.createDatabaseRow(database);
      await db.replaceRowProperties(other, 'invalid json');
      final result = await repo.queryDatabaseRows(
        database,
        filters: [
          DatabaseFilterRule(
            columnId: text,
            operator: 'contains',
            value: literal,
          ),
        ],
      );
      expect(result.rows.single.page.id, id);
      expect(
        (await repo.queryDatabaseRows(
          database,
          search: 'unmatched',
        )).filteredCount,
        0,
      );
    },
  );

  test(
    'reactive pages reuse decoded properties until the JSON changes',
    () async {
      final id = await repo.createDatabaseRow(
        database,
        properties: {text: 'Same'},
      );
      final iterator = StreamIterator(repo.watchDatabaseRowsPage(database));
      addTearDown(iterator.cancel);
      await iterator.moveNext();
      final initial = iterator.current.rows.single.properties;
      await repo.updateRowTitle(id, 'Renamed');
      await iterator.moveNext();
      expect(iterator.current.rows.single.properties, same(initial));
      await repo.patchRowProperties(id, {text: 'Changed'});
      await iterator.moveNext();
      expect(iterator.current.rows.single.properties, isNot(same(initial)));
      expect(iterator.current.rows.single.properties[text], 'Changed');
    },
  );

  test(
    'new queries use changed column types and ignore deleted filters',
    () async {
      final first = await repo.createDatabaseRow(
        database,
        properties: {text: '2'},
      );
      final second = await repo.createDatabaseRow(
        database,
        properties: {text: '10'},
      );
      final sorted = await repo.queryDatabaseRows(
        database,
        sort: DatabaseSortConfig(columnId: text),
      );
      expect(sorted.rows.map((r) => r.page.id), [second, first]);
      await repo.updateColumn(text, type: 'number');
      final numeric = await repo.queryDatabaseRows(
        database,
        sort: DatabaseSortConfig(columnId: text),
      );
      expect(numeric.rows.map((r) => r.page.id), [first, second]);
      final filters = [
        DatabaseFilterRule(columnId: text, operator: 'equals', value: '2'),
      ];
      expect(
        (await repo.queryDatabaseRows(
          database,
          filters: filters,
        )).filteredCount,
        1,
      );
      await repo.deleteColumn(text);
      expect(
        (await repo.queryDatabaseRows(
          database,
          filters: filters,
        )).filteredCount,
        2,
      );
    },
  );

  test(
    'a live page clamps its offset after the final page is deleted',
    () async {
      await seed(51);
      final iterator = StreamIterator(
        repo.watchDatabaseRowsPage(database, offset: 50),
      );
      await iterator.moveNext();
      expect(iterator.current.rows.length, 1);
      await repo.trashPage('row-50');
      await iterator.moveNext();
      expect(iterator.current.offset, 0);
      expect(iterator.current.rows.length, 50);
      expect(iterator.current.filteredCount, 50);
      await iterator.cancel();
    },
  );

  test('default page query uses the database-order index', () async {
    await seed(200);
    final query = buildDatabaseRowsQuery(
      database,
      await repo.getColumns(database),
    );
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN ${query.sql}',
          variables: query.variables,
        )
        .get();
    final details = plan.map((r) => r.read<String>('detail')).join('\n');
    expect(details, contains('pages_database_order'));
    expect(details, isNot(contains('SCAN p')));
  });

  testWidgets(
    'large tables mount only visible rows and page without loading the full list',
    (tester) async {
      await seed(1000);
      final tracked = _PagedOnlyRepository(db);
      final state = EditorState(
        document: Document(
          root: pageNode(children: [databaseBlockNode(databaseId: database)]),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: state,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                databaseBlockType: DatabaseBlockComponentBuilder(
                  repository: tracked,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1000 items'), findsOneWidget);
      expect(find.text('1–50 of 1000'), findsOneWidget);
      expect(find.byType(DataRowView).evaluate().length, lessThan(50));
      expect(find.text('Row 0999'), findsNothing);
      final queries = tracked.pageSubscriptions;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Row 0000')));
      await tester.pumpAndSettle();
      expect(tracked.pageSubscriptions, queries);
      await tester.tap(find.byTooltip('Next rows'));
      await tester.pumpAndSettle();
      expect(find.text('51–100 of 1000'), findsOneWidget);
      expect(find.text('Row 0050'), findsOneWidget);
      expect(find.byType(DataRowView).evaluate().length, lessThan(50));
      await tester.tap(find.byTooltip('Previous rows'));
      await tester.pumpAndSettle();
      expect(find.text('Row 0000'), findsOneWidget);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  test(
    'schema 8 migration creates indexes and backfills Unicode search data',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'notes_here_paging_',
      );
      addTearDown(() async {
        await db.close();
        if (await directory.exists()) {
          try {
            await directory.delete(recursive: true);
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            if (await directory.exists()) {
              await directory.delete(recursive: true);
            }
          }
        }
      });
      final file = File('${directory.path}/notes.sqlite');
      db = AppDatabase(NativeDatabase(file));
      repo = NotesRepository(db);
      final database = await repo.createDatabase();
      final id = await repo.createDatabaseRow(database, title: 'ПРИВЕТ');
      for (final index in [
        'pages_database_order',
        'pages_parent_order',
        'blocks_page_order',
        'database_columns_order',
      ]) {
        await db.customStatement('DROP INDEX $index');
      }
      await db.customStatement('ALTER TABLE pages DROP COLUMN title_folded');
      await db.customStatement(
        'ALTER TABLE pages DROP COLUMN properties_folded',
      );
      await db.customStatement('PRAGMA user_version = 8');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repo = NotesRepository(db);
      expect(
        (await repo.queryDatabaseRows(
          database,
          search: 'привет',
        )).rows.single.page.id,
        id,
      );
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND name='pages_database_order'",
            )
            .get(),
        hasLength(1),
      );
    },
  );
}

class _PagedOnlyRepository extends NotesRepository {
  _PagedOnlyRepository(super.db);
  int pageSubscriptions = 0;
  @override
  Stream<List<Page>> watchDatabaseRows(String databaseId) =>
      throw StateError('Unbounded UI query');
  @override
  Stream<DatabaseRowsPage> watchDatabaseRowsPage(
    String databaseId, {
    DatabaseSortConfig? sort,
    List<DatabaseFilterRule> filters = const [],
    String search = '',
    int offset = 0,
    int limit = DatabaseQueryPolicy.pageSize,
  }) {
    pageSubscriptions++;
    return super.watchDatabaseRowsPage(
      databaseId,
      sort: sort,
      filters: filters,
      search: search,
      offset: offset,
      limit: limit,
    );
  }
}

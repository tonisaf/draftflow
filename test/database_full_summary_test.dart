import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database/database_summary_row.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late String database, amount, done;
  final ids = <String>[];
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    database = await repo.createDatabase();
    amount = await repo.addColumn(
      database,
      name: 'Amount',
      type: 'number',
      options: '{"format":"duration_human"}',
    );
    done = (await repo.getColumns(database))
        .firstWhere((col) => col.type == 'checkbox')
        .id;
    ids.clear();
    await db.transaction(() async {
      for (var i = 0; i < 70; i++) {
        ids.add(
          await repo.createDatabaseRow(
            database,
            title: i < 60 ? 'Normal $i' : 'Keep $i',
            properties: {amount: i < 60 ? 10 : '1m', done: i >= 60},
          ),
        );
      }
    });
  });
  tearDown(() => db.close());

  test(
    'summary covers every page and keeps weighted duration semantics',
    () async {
      final page = await repo.queryDatabaseRows(database);
      expect(page.rows, hasLength(50));
      final groups = await repo.watchDatabaseSummaryGroups(database, {
        amount,
        done,
      }).first;
      expect(groups[amount], hasLength(2));
      final stats = (await calculateDatabaseSummaryStats(
        groups,
        formats: {amount: 'duration_human'},
      ))[amount]!;
      expect(stats.rows, 70);
      expect(stats.numericCount, 70);
      expect(stats.sum, 1200);
      expect(stats.min, 10);
      expect(stats.max, 60);
      expect(summarizeDatabaseGroups(groups[done]!).checked, 10);
      await repo.queryDatabaseRows(database, offset: 50);
      expect(
        summarizeDatabaseGroups(
          (await repo.watchDatabaseSummaryGroups(database, {
            amount,
          }).first)[amount]!,
          format: 'duration_human',
        ).sum,
        1200,
      );
    },
  );

  test(
    'search, filters and trash use the same scope as the row query',
    () async {
      final groups = await repo
          .watchDatabaseSummaryGroups(
            database,
            {amount},
            filters: [DatabaseFilterRule(columnId: done, operator: 'is_true')],
            search: 'KEEP',
          )
          .first;
      expect(
        summarizeDatabaseGroups(groups[amount]!, format: 'duration_human').sum,
        600,
      );
      await repo.deleteDatabaseRow(ids.last);
      final afterTrash = await repo.watchDatabaseSummaryGroups(database, {
        amount,
      }, search: 'keep').first;
      expect(
        summarizeDatabaseGroups(
          afterTrash[amount]!,
          format: 'duration_human',
        ).sum,
        540,
      );
      final empty = await repo.watchDatabaseSummaryGroups(database, {
        amount,
      }, search: 'missing-row').first;
      expect(summarizeDatabaseGroups(empty[amount]!).rows, 0);
      expect(summarizeDatabaseGroups(empty[amount]!).sum, 0);
    },
  );

  test(
    'a cell edit on a different page updates the active summary subscription',
    () async {
      final initial = Completer<void>();
      final updated = Completer<void>();
      final subscription = repo
          .watchDatabaseSummaryGroups(database, {amount})
          .listen((groups) {
            final sum = summarizeDatabaseGroups(
              groups[amount]!,
              format: 'duration_human',
            ).sum;
            if (sum == 1200 && !initial.isCompleted) initial.complete();
            if (sum == 1205 && !updated.isCompleted) updated.complete();
          });
      await initial.future;
      await repo.patchRowProperties(ids.last, {amount: 65});
      await updated.future;
      await subscription.cancel();
    },
  );
}

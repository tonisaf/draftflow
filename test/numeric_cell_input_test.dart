import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/model/numeric_cell_input.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/ui/editor/components/database/database_summary_row.dart';

void main() {
  test('decimal notation, grouping, percent and clearing', () {
    for (final entry in {
      '12,5': 12.5,
      '-12.5': -12.5,
      '1 234,5': 1234.5,
      '1\u00a0234': 1234,
      '1\u202f234': 1234,
      '1e3': 1000,
      '.5': .5,
    }.entries) {
      expect(
        parseNumericCellInput(entry.key).value,
        entry.value,
        reason: entry.key,
      );
    }
    expect(parseNumericCellInput('50%', format: 'percent').value, 50);
    expect(parseNumericCellInput(' ').valid, isTrue);
    expect(parseNumericCellInput('').value, isNull);
  });
  test('invalid numbers cannot partially parse or become formulas', () {
    for (final input in [
      'NaN',
      'Infinity',
      '-Infinity',
      '∞',
      '1e999',
      '1,234.5',
      '12 34',
      '0xff',
      '32+32',
      '=SUM(2)',
      '1/0',
      '2*3',
      'abc',
      '1h',
    ]) {
      expect(parseNumericCellInput(input).valid, isFalse, reason: input);
    }
    expect(parseNumericCellInput(double.nan).valid, isFalse);
    expect(parseNumericCellInput(double.infinity).valid, isFalse);
    expect(parseNumericCellInput('32+32').issue, NumericInputIssue.formula);
  });
  test(
    'duration grammar consumes all input and preserves signs and fractions',
    () {
      for (final entry in {
        '1h30m': 5400,
        '1ч 30мин': 5400,
        '1.5h': 5400,
        '500ms': .5,
        '-1h 30m': -5400,
        '05:30': 330,
        '01:30:00': 5400,
        '1:02:03:04.5': 93784.5,
        '500': 500,
      }.entries) {
        expect(
          parseNumericCellInput(entry.key, format: 'duration_human').value,
          entry.value,
          reason: entry.key,
        );
      }
      for (final input in [
        '1h garbage',
        '1h 2bad',
        '1hourly',
        '1h 2hours',
        '1:99',
        '1:60:00',
        '1:24:00:00',
        '1h+2m',
        '1e300',
      ]) {
        expect(
          parseNumericCellInput(input, format: 'duration_human').valid,
          isFalse,
          reason: input,
        );
      }
    },
  );
  const key = (databaseId: 'd', rowId: 'r', columnId: 'c', title: false);
  test(
    'invalid draft is retained, not written or retried; correction normalizes',
    () async {
      final writes = <dynamic>[];
      final saves = DatabaseCellSaves((_, value) async {
        writes.add(value);
      });
      final entry = saves.entry(key)..columnType = 'number';
      entry.display(10);
      await saves.submit(key, '32+32');
      expect(entry.phase, CellSavePhase.invalid);
      expect(entry.display(10), '32+32');
      expect(entry.acknowledged, 10);
      expect(await saves.flush(), isFalse);
      await saves.retryDatabase('d');
      expect(writes, isEmpty);
      await saves.submit(key, '12,5');
      expect(writes, [12.5]);
      expect(await saves.flush(), isTrue);
      await saves.submit(key, 'bad');
      saves.discardFailed('d');
      expect(entry.validationIssue, isNull);
      expect(entry.desired, 12.5);
    },
  );
  test(
    'invalid draft arriving during valid write never reaches writer',
    () async {
      final gate = Completer<void>();
      final writes = <dynamic>[];
      final saves = DatabaseCellSaves((_, value) async {
        writes.add(value);
        await gate.future;
      });
      final entry = saves.entry(key)..columnType = 'number';
      entry.display(0);
      final writing = saves.submit(key, 20);
      await Future<void>.value();
      await saves.submit(key, 'bad');
      gate.complete();
      await writing;
      expect(writes, [20]);
      expect(entry.acknowledged, 20);
      expect(entry.desired, 'bad');
      expect(entry.phase, CellSavePhase.invalid);
    },
  );
  test(
    'summaries respect column format and skip invalid legacy values',
    () async {
      final groups = [
        DatabaseValueGroup('12,5', 2),
        DatabaseValueGroup('1h', 1),
        DatabaseValueGroup('1h garbage', 1),
        DatabaseValueGroup(double.infinity, 1),
      ];
      expect(summarizeDatabaseGroups(groups).sum, 25);
      expect(summarizeDatabaseGroups(groups).numericCount, 2);
      final result = await calculateDatabaseSummaryStats(
        {'c': groups},
        formats: {'c': 'duration_human'},
      );
      expect(result['c']!.sum, 3625);
      expect(result['c']!.numericCount, 3);
    },
  );
}

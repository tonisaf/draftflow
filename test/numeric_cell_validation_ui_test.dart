import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/data/model/numeric_cell_input.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart'
    as cells;
import 'package:notes_here/ui/editor/components/database/database_number_cell.dart';
import 'package:notes_here/ui/editor/components/database/database_save_status.dart';
import 'package:notes_here/ui/theme.dart';

Widget localized(Widget child, {String locale = 'en'}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  test('interactive database guard rejects invalid numbers without rewriting legacy data', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = NotesRepository(db);
    final database = await repo.createDatabase();
    final column = await repo.addColumn(
      database,
      name: 'Number',
      type: 'number',
    );
    final row = await repo.createDatabaseRow(
      database,
      properties: {column: 'legacy'},
    );
    for (final value in ['32+32', '12,5', double.infinity, double.nan]) {
      await expectLater(
        repo.compareAndSetDatabaseCell(
          row,
          column,
          value,
          'legacy',
          title: false,
        ),
        throwsA(isA<NumericCellValidationException>()),
      );
    }
    expect(
      jsonDecode((await repo.getPage(row))!.properties!)[column],
      'legacy',
    );
    await repo.compareAndSetDatabaseCell(
      row,
      column,
      12.5,
      'legacy',
      title: false,
    );
    expect(jsonDecode((await repo.getPage(row))!.properties!)[column], 12.5);
    await db.close();
  });
  testWidgets(
    'invalid input survives remount, explains error and corrects without resizing',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final writes = <dynamic>[];
      final saves = DatabaseCellSaves((_, value) async {
        writes.add(value);
      });
      final column = DatabaseColumn(
        id: 'c',
        databaseId: 'd',
        name: 'Number',
        type: 'number',
        width: 240,
        orderKey: 'a',
        createdAt: DateTime(2026),
      );
      Widget mount() => localized(
        Column(
          children: [
            SizedBox(
              height: 36,
              child: cells.DataCell(
                column: column,
                width: 240,
                borderColor: Colors.transparent,
                rowId: 'r',
                saves: saves,
                pageTitle: 'Row',
                cellValue: 10,
                repository: repo,
                onUpdateTitle: (_) {},
                onUpdateValue: (_) {},
                onOpenPage: () {},
              ),
            ),
            DatabaseSaveStatus(saves: saves, databaseId: 'd'),
          ],
        ),
      );
      await tester.pumpWidget(mount());
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '32+32');
      await tester.pump();
      expect(tester.getSize(find.byType(cells.DataCell)).height, 36);
      expect(
        find.byTooltip(
          'Formulas are not supported. Enter the calculated value.',
        ),
        findsOneWidget,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.text('Correct invalid cell values'), findsOneWidget);
      expect(find.byKey(const Key('database_retry_saves')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(mount());
      await tester.pumpAndSettle();
      expect(find.text('32+32'), findsOneWidget);
      await tester.tap(find.text('32+32'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes, [12.5]);
      expect(find.text('Saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
  for (final locale in ['en', 'ru']) {
    testWidgets(
      'duration picker preserves negative fractional value and rejects garbage ($locale)',
      (tester) async {
        num? result;
        var closed = false;
        await tester.pumpWidget(
          localized(
            SizedBox(
              width: 270,
              child: DurationPickerContent(
                initialSeconds: -90.1,
                onApply: (v) => result = v,
                onClose: () => closed = true,
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('apply_duration_btn')));
        await tester.pumpAndSettle();
        expect(result, -90.1);
        expect(closed, isTrue);
        result = null;
        closed = false;
        await tester.enterText(
          find.byKey(const ValueKey('duration_hours_input')),
          'abc',
        );
        await tester.tap(find.byKey(const ValueKey('apply_duration_btn')));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(closed, isFalse);
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const ValueKey('duration_hours_input')),
          '24',
        );
        await tester.tap(find.byKey(const ValueKey('apply_duration_btn')));
        await tester.pumpAndSettle();
        expect(result, isNull);
      },
    );
  }
}

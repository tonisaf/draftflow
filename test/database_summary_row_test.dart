import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/database/database_models.dart';
import 'package:notes_here/ui/editor/components/database/database_summary_row.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('calculateSummary unit tests', () {
    testWidgets('calculates Sum, Average, Min, Max, Range for number column', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final numberCol = DatabaseColumn(
                id: 'num_col',
                databaseId: 'db1',
                name: 'Price',
                type: 'number',
                width: 160,
                orderKey: 'a',
                createdAt: DateTime.now(),
              );

              final rows = [
                DatabaseRowData(
                  Page(
                    id: 'r1',
                    title: 'Row 1',
                    createdAt: DateTime.now(),
                  ),
                  properties: {'num_col': 10},
                ),
                DatabaseRowData(
                  Page(
                    id: 'r2',
                    title: 'Row 2',
                    createdAt: DateTime.now(),
                  ),
                  properties: {'num_col': 20},
                ),
                DatabaseRowData(
                  Page(
                    id: 'r3',
                    title: 'Row 3',
                    createdAt: DateTime.now(),
                  ),
                  properties: {'num_col': 30},
                ),
              ];

              expect(
                calculateSummary(
                  type: SummaryType.sum,
                  column: numberCol,
                  rows: rows,
                  context: context,
                ),
                'Sum 60',
              );

              expect(
                calculateSummary(
                  type: SummaryType.average,
                  column: numberCol,
                  rows: rows,
                  context: context,
                ),
                'Average 20',
              );

              expect(
                calculateSummary(
                  type: SummaryType.min,
                  column: numberCol,
                  rows: rows,
                  context: context,
                ),
                'Min 10',
              );

              expect(
                calculateSummary(
                  type: SummaryType.max,
                  column: numberCol,
                  rows: rows,
                  context: context,
                ),
                'Max 30',
              );

              expect(
                calculateSummary(
                  type: SummaryType.range,
                  column: numberCol,
                  rows: rows,
                  context: context,
                ),
                'Range 20',
              );

              expect(
                calculateSummary(
                  type: SummaryType.count,
                  column: numberCol,
                  rows: rows,
                  context: context,
                ),
                'Count 3',
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('calculates Checked, Unchecked, and PercentChecked for checkbox column', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final checkCol = DatabaseColumn(
                id: 'done_col',
                databaseId: 'db1',
                name: 'Done',
                type: 'checkbox',
                width: 100,
                orderKey: 'a',
                createdAt: DateTime.now(),
              );

              final rows = [
                DatabaseRowData(
                  Page(
                    id: 'r1',
                    title: 'Task 1',
                    createdAt: DateTime.now(),
                  ),
                  properties: {'done_col': true},
                ),
                DatabaseRowData(
                  Page(
                    id: 'r2',
                    title: 'Task 2',
                    createdAt: DateTime.now(),
                  ),
                  properties: {'done_col': false},
                ),
                DatabaseRowData(
                  Page(
                    id: 'r3',
                    title: 'Task 3',
                    createdAt: DateTime.now(),
                  ),
                  properties: {'done_col': true},
                ),
                DatabaseRowData(
                  Page(
                    id: 'r4',
                    title: 'Task 4',
                    createdAt: DateTime.now(),
                  ),
                  properties: {},
                ),
              ];

              expect(
                calculateSummary(
                  type: SummaryType.checked,
                  column: checkCol,
                  rows: rows,
                  context: context,
                ),
                'Отмечено 2',
              );

              expect(
                calculateSummary(
                  type: SummaryType.unchecked,
                  column: checkCol,
                  rows: rows,
                  context: context,
                ),
                'Не отмечено 2',
              );

              expect(
                calculateSummary(
                  type: SummaryType.percentChecked,
                  column: checkCol,
                  rows: rows,
                  context: context,
                ),
                '50%',
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('calculates Unique, Empty, Not empty for select column', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final selectCol = DatabaseColumn(
                id: 'tag_col',
                databaseId: 'db1',
                name: 'Tag',
                type: 'select',
                width: 120,
                orderKey: 'a',
                createdAt: DateTime.now(),
              );

              final rows = [
                DatabaseRowData(
                  Page(id: 'r1', title: '1', createdAt: DateTime.now()),
                  properties: {'tag_col': 'dev'},
                ),
                DatabaseRowData(
                  Page(id: 'r2', title: '2', createdAt: DateTime.now()),
                  properties: {'tag_col': 'design'},
                ),
                DatabaseRowData(
                  Page(id: 'r3', title: '3', createdAt: DateTime.now()),
                  properties: {'tag_col': 'dev'},
                ),
                DatabaseRowData(
                  Page(id: 'r4', title: '4', createdAt: DateTime.now()),
                  properties: {},
                ),
              ];

              expect(
                calculateSummary(
                  type: SummaryType.unique,
                  column: selectCol,
                  rows: rows,
                  context: context,
                ),
                'Unique 2',
              );

              expect(
                calculateSummary(
                  type: SummaryType.empty,
                  column: selectCol,
                  rows: rows,
                  context: context,
                ),
                'Empty 1',
              );

              expect(
                calculateSummary(
                  type: SummaryType.notEmpty,
                  column: selectCol,
                  rows: rows,
                  context: context,
                ),
                'Not empty 3',
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('TableSummaryRow widget tests', () {
    testWidgets('renders summary cells and allows changing calculation type via popover', (tester) async {
      final numberCol = DatabaseColumn(
        id: 'num_col',
        databaseId: 'db1',
        name: 'Amount',
        type: 'number',
        width: 150,
        orderKey: 'a',
        createdAt: DateTime.now(),
      );

      final rows = [
        DatabaseRowData(
          Page(id: 'r1', title: 'A', createdAt: DateTime.now()),
          properties: {'num_col': 50},
        ),
        DatabaseRowData(
          Page(id: 'r2', title: 'B', createdAt: DateTime.now()),
          properties: {'num_col': 150},
        ),
      ];

      final summaries = <String, String>{};
      String? updatedColumn;
      String? updatedSummary;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TableSummaryRow(
                  columns: [numberCol],
                  columnWidths: {'num_col': 150},
                  borderColor: Colors.grey,
                  rows: rows,
                  summaries: summaries,
                  onSummaryChanged: (colId, type) {
                    setState(() {
                      updatedColumn = colId;
                      updatedSummary = type;
                      if (type == null) {
                        summaries.remove(colId);
                      } else {
                        summaries[colId] = type;
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summaryCell = find.byKey(const ValueKey('summary_num_col'));
      expect(summaryCell, findsOneWidget);

      // Tap summary cell to open popover
      await tester.tap(summaryCell);
      await tester.pumpAndSettle();

      // Verify calculation options are present
      expect(find.text('Сумма'), findsOneWidget);
      expect(find.text('Среднее'), findsOneWidget);
      expect(find.text('Минимум'), findsOneWidget);
      expect(find.text('Максимум'), findsOneWidget);

      // Select 'Сумма'
      await tester.tap(find.text('Сумма'));
      await tester.pumpAndSettle();

      expect(updatedColumn, 'num_col');
      expect(updatedSummary, 'sum');
      expect(find.textContaining('СУММА'), findsOneWidget);
      expect(find.textContaining('200'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}

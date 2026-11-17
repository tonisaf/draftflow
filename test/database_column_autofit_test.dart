import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/ui/editor/components/database/database_autofit.dart';
import 'package:notes_here/ui/editor/components/database/database_columns_header.dart';
import 'package:notes_here/ui/editor/components/database/database_models.dart';
import 'package:notes_here/l10n/app_localizations.dart';

void main() {
  group('calculateAutoFitColumnWidth', () {
    test('expands to fit long cell content', () {
      final col = DatabaseColumn(
        id: 'c1',
        databaseId: 'd1',
        name: 'Title',
        type: 'title',
        width: 160.0,
        orderKey: 'a0',
        createdAt: DateTime.now(),
      );

      final row1 = DatabaseRowData(
        Page(
          id: 'p1',
          title: 'A very long page title that exceeds the normal column width',
          createdAt: DateTime.now(),
        ),
      );

      final width = calculateAutoFitColumnWidth(
        column: col,
        rows: [row1],
      );

      expect(width, greaterThan(250.0));
      expect(width, lessThanOrEqualTo(600.0));
    });

    test('expands to fit long column name when rows are short', () {
      final col = DatabaseColumn(
        id: 'c2',
        databaseId: 'd1',
        name: 'Super Long Column Header Title Describing Important Metadata',
        type: 'text',
        width: 160.0,
        orderKey: 'a1',
        createdAt: DateTime.now(),
      );

      final row1 = DatabaseRowData(
        Page(
          id: 'p1',
          title: 'Short',
          createdAt: DateTime.now(),
          properties: '{"c2": "tiny"}',
        ),
      );

      final width = calculateAutoFitColumnWidth(
        column: col,
        rows: [row1],
      );

      expect(width, greaterThan(300.0));
    });

    test('clamps checkbox columns to 60.0 minimum', () {
      final col = DatabaseColumn(
        id: 'c3',
        databaseId: 'd1',
        name: 'Done',
        type: 'checkbox',
        width: 100.0,
        orderKey: 'a2',
        createdAt: DateTime.now(),
      );

      final width = calculateAutoFitColumnWidth(
        column: col,
        rows: [],
      );

      expect(width, greaterThanOrEqualTo(60.0));
      expect(width, lessThanOrEqualTo(120.0));
    });

    test('clamps text columns to 115.0 minimum', () {
      final col = DatabaseColumn(
        id: 'c4',
        databaseId: 'd1',
        name: 'X',
        type: 'text',
        width: 160.0,
        orderKey: 'a3',
        createdAt: DateTime.now(),
      );

      final width = calculateAutoFitColumnWidth(
        column: col,
        rows: [],
      );

      expect(width, equals(115.0));
    });
  });

  group('Auto-fit UI interaction', () {
    testWidgets('double clicking resize handle fires onAutoFit', (tester) async {
      String? autoFitColId;
      final columns = [
        DatabaseColumn(
          id: 'col_name',
          databaseId: 'db1',
          name: 'Name',
          type: 'title',
          width: 200.0,
          orderKey: 'a0',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ColumnsHeaderRow(
              columns: columns,
              columnWidths: const {'col_name': 200.0},
              headerBg: Colors.white,
              borderColor: Colors.grey,
              onSortChanged: (_, _) {},
              onResize: (_, _) {},
              onResizeEnd: (_, _) {},
              onAutoFit: (colId) => autoFitColId = colId,
              onDeleteColumn: (_) {},
              onAddColumn: () {},
            ),
          ),
        ),
      );

      // Find the resize handle GestureDetector (on the right edge of ResizableColumnHeader)
      final handleFinder = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      expect(handleFinder, findsOneWidget);

      await tester.tap(handleFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(handleFinder);
      await tester.pumpAndSettle();

      expect(autoFitColId, equals('col_name'));
    });

    testWidgets('property menu contains Auto-fit width option', (tester) async {
      String? autoFitColId;
      final columns = [
        DatabaseColumn(
          id: 'col_tags',
          databaseId: 'db1',
          name: 'Tags',
          type: 'select',
          width: 160.0,
          orderKey: 'a1',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ColumnsHeaderRow(
              columns: columns,
              columnWidths: const {'col_tags': 160.0},
              headerBg: Colors.white,
              borderColor: Colors.grey,
              onSortChanged: (_, _) {},
              onResize: (_, _) {},
              onResizeEnd: (_, _) {},
              onAutoFit: (colId) => autoFitColId = colId,
              onDeleteColumn: (_) {},
              onAddColumn: () {},
            ),
          ),
        ),
      );

      // Tap on the header to open property menu
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      // Find the auto-fit menu item
      final autoFitItem = find.text('Auto-fit width');
      expect(autoFitItem, findsOneWidget);

      await tester.tap(autoFitItem);
      await tester.pumpAndSettle();

      expect(autoFitColId, equals('col_tags'));
    });
  });
}

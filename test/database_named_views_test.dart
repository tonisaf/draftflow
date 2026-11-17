import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/app_localizations.dart';
import 'package:notes_here/ui/common/app_icons.dart';
import 'package:notes_here/ui/editor/components/database/database_models.dart';
import 'package:notes_here/ui/editor/components/database/database_views.dart';
import 'package:notes_here/ui/editor/components/database/database_view_tabs.dart';

void main() {
  group('DatabaseViewConfig & serialization', () {
    test('JSON serialization roundtrip preserves all view settings', () {
      final view = DatabaseViewConfig(
        id: 'view_1',
        name: 'Urgent Tasks',
        type: DatabaseViewType.board,
        sort: const DatabaseSortConfig(columnId: 'col_due', ascending: true),
        filters: [
          DatabaseFilterRule(
            columnId: 'col_status',
            operator: 'equals',
            value: 'in_progress',
          ),
        ],
        visibleColumnIds: const ['col_due', 'col_status'],
        columnWidths: const {'col_due': 180.0},
        groupByColumnId: 'col_status',
        wrapCells: true,
      );

      final json = view.toJson();
      final parsed = DatabaseViewConfig.fromJson(json);

      expect(parsed.id, equals('view_1'));
      expect(parsed.name, equals('Urgent Tasks'));
      expect(parsed.type, equals(DatabaseViewType.board));
      expect(parsed.sort?.columnId, equals('col_due'));
      expect(parsed.sort?.ascending, isTrue);
      expect(parsed.filters.length, equals(1));
      expect(parsed.filters.first.columnId, equals('col_status'));
      expect(parsed.filters.first.value, equals('in_progress'));
      expect(parsed.visibleColumnIds, equals(['col_due', 'col_status']));
      expect(parsed.columnWidths['col_due'], equals(180.0));
      expect(parsed.groupByColumnId, equals('col_status'));
      expect(parsed.wrapCells, isTrue);
    });

    test('parseDatabaseViews handles empty or legacy formats safely', () {
      expect(parseDatabaseViews(null), isEmpty);
      expect(parseDatabaseViews('invalid'), isEmpty);
      expect(parseDatabaseViews([]), isEmpty);

      final parsed = parseDatabaseViews([
        {'id': 'v1', 'name': 'Table', 'type': 'table'},
      ]);
      expect(parsed.length, equals(1));
      expect(parsed.first.id, equals('v1'));
      expect(parsed.first.name, equals('Table'));
      expect(parsed.first.type, equals(DatabaseViewType.table));
    });
  });

  group('DatabaseViewTabs UI Widget', () {
    final columns = [
      DatabaseColumn(
        id: 'col_title',
        databaseId: 'db1',
        name: 'Name',
        type: 'title',
        width: 200.0,
        orderKey: 'a0',
        createdAt: DateTime.now(),
      ),
      DatabaseColumn(
        id: 'col_status',
        databaseId: 'db1',
        name: 'Status',
        type: 'status',
        width: 150.0,
        orderKey: 'a1',
        createdAt: DateTime.now(),
      ),
    ];

    testWidgets('renders all view tabs and highlights active tab', (tester) async {
      final views = [
        const DatabaseViewConfig(id: 'v1', name: 'All Tasks', type: DatabaseViewType.table),
        const DatabaseViewConfig(id: 'v2', name: 'Kanban', type: DatabaseViewType.board),
      ];

      DatabaseViewConfig? selected;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DatabaseViewTabs(
              views: views,
              activeViewId: 'v1',
              columns: columns,
              onSelectView: (v) => selected = v,
              onAddView: (_) {},
              onRenameView: (_, _) {},
              onDuplicateView: (_) {},
              onDeleteView: (_) {},
              onUpdateColumnVisibility: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.text('All Tasks'), findsOneWidget);
      expect(find.text('Kanban'), findsOneWidget);

      // Tap on second tab
      await tester.tap(find.text('Kanban'));
      await tester.pumpAndSettle();

      expect(selected?.id, equals('v2'));
    });

    testWidgets('tapping add button shows view types popover and triggers onAddView',
        (tester) async {
      final views = [
        const DatabaseViewConfig(id: 'v1', name: 'Table', type: DatabaseViewType.table),
      ];

      DatabaseViewType? addedType;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DatabaseViewTabs(
              views: views,
              activeViewId: 'v1',
              columns: columns,
              onSelectView: (_) {},
              onAddView: (type) => addedType = type,
              onRenameView: (_, _) {},
              onDuplicateView: (_) {},
              onDeleteView: (_) {},
              onUpdateColumnVisibility: (_, _) {},
            ),
          ),
        ),
      );

      // Find and tap add view '+' button
      final addBtn = find.byTooltip('Add view');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Expect view type choices in popover: Table, Board, Gallery, List
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);

      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(addedType, equals(DatabaseViewType.board));
    });

    testWidgets('tab options menu allows duplicate and properties visibility',
        (tester) async {
      final views = [
        const DatabaseViewConfig(id: 'v1', name: 'Table', type: DatabaseViewType.table),
        const DatabaseViewConfig(id: 'v2', name: 'Board', type: DatabaseViewType.board),
      ];

      DatabaseViewConfig? duplicated;
      DatabaseViewConfig? deleted;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DatabaseViewTabs(
              views: views,
              activeViewId: 'v1',
              columns: columns,
              onSelectView: (_) {},
              onAddView: (_) {},
              onRenameView: (_, _) {},
              onDuplicateView: (v) => duplicated = v,
              onDeleteView: (v) => deleted = v,
              onUpdateColumnVisibility: (_, _) {},
            ),
          ),
        ),
      );

      // Tap on ellipsis menu inside active tab
      final menuFinder = find.descendant(
        of: find.byType(DatabaseViewTabs),
        matching: find.byIcon(AppIcons.ellipsis),
      );
      expect(menuFinder, findsOneWidget);

      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      // Expect options: Rename view, Duplicate view, Properties visibility, Delete view
      expect(find.text('Rename view'), findsOneWidget);
      expect(find.text('Duplicate view'), findsOneWidget);
      expect(find.text('Properties visibility'), findsOneWidget);
      expect(find.text('Delete view'), findsOneWidget);

      // Tap Duplicate view
      await tester.tap(find.text('Duplicate view'));
      await tester.pumpAndSettle();

      expect(duplicated?.id, equals('v1'));
    });
  });
}

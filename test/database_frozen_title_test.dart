import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/app_localizations.dart';
import 'package:notes_here/ui/editor/components/database/database_columns_header.dart';
import 'package:notes_here/ui/editor/components/database/database_header.dart';
import 'package:notes_here/ui/editor/components/database/database_sticky_pane.dart';

void main() {
  group('DatabaseStickyPane', () {
    testWidgets('translates child by horizontal scroll offset when scrolled',
        (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 2000,
                child: Row(
                  children: [
                    DatabaseStickyPane(
                      horizontalScrollController: controller,
                      width: 200,
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey,
                      isFrozen: true,
                      child: const Text('Pinned Content'),
                    ),
                    const SizedBox(width: 1800),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pinned Content'), findsOneWidget);

      // Initially offset is 0, so transform offset is 0
      Transform transform = tester.widget(
        find.descendant(
          of: find.byType(DatabaseStickyPane),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().x, equals(0.0));

      // Scroll horizontally to 150px
      controller.jumpTo(150.0);
      await tester.pump();

      transform = tester.widget(
        find.descendant(
          of: find.byType(DatabaseStickyPane),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().x, equals(150.0));
    });
  });

  group('ColumnsHeaderRow with Frozen Title Column', () {
    testWidgets('renders pinned title header in DatabaseStickyPane',
        (tester) async {
      final controller = ScrollController();
      final columns = [
        DatabaseColumn(
          id: 'c_title',
          databaseId: 'db1',
          name: 'Name',
          type: 'title',
          width: 200.0,
          orderKey: 'a0',
          createdAt: DateTime.now(),
        ),
        DatabaseColumn(
          id: 'c_text',
          databaseId: 'db1',
          name: 'Description',
          type: 'text',
          width: 250.0,
          orderKey: 'a1',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: ColumnsHeaderRow(
                horizontalScrollController: controller,
                freezeTitle: true,
                columns: columns,
                columnWidths: const {'c_title': 200.0, 'c_text': 250.0},
                headerBg: Colors.white,
                borderColor: Colors.grey,
                onSortChanged: (_, _) {},
                onResize: (_, _) {},
                onResizeEnd: (_, _) {},
                onDeleteColumn: (_) {},
                onAddColumn: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DatabaseStickyPane), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);

      // Scroll to 100px
      controller.jumpTo(100.0);
      await tester.pump();

      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(DatabaseStickyPane),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().x, equals(100.0));
    });
  });

  group('DatabaseHeader Options Menu', () {
    testWidgets('toggles Freeze title column', (tester) async {
      var toggled = false;
      final columns = [
        DatabaseColumn(
          id: 'c1',
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
            body: DatabaseHeader(
              title: 'Tasks',
              totalRowCount: 5,
              filteredRowCount: 5,
              columns: columns,
              filterRules: const [],
              searchQuery: '',
              onSortChanged: (_, _) {},
              onAddFilter: (_) {},
              onRemoveFilter: (_) {},
              onClearFilters: () {},
              onSearchChanged: (_) {},
              onAddRow: () {},
              onTitleChanged: (_) {},
              freezeTitle: true,
              onToggleFreezeTitle: () => toggled = true,
            ),
          ),
        ),
      );

      // Tap options button (...)
      final optionsBtn = find.byTooltip('Database options');
      expect(optionsBtn, findsOneWidget);
      await tester.tap(optionsBtn);
      await tester.pumpAndSettle();

      // Find "Freeze title column" menu item
      final freezeItem = find.text('Freeze title column');
      expect(freezeItem, findsOneWidget);

      await tester.tap(freezeItem);
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });
  });
}

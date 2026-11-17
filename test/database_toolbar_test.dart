import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/ui/editor/components/database/database_header.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  final columns = [
    DatabaseColumn(
      id: 'name',
      databaseId: 'db',
      name: 'A very long property name that must fit a narrow toolbar',
      type: 'title',
      width: 220,
      orderKey: 'a',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  ];
  Widget header({
    required double width,
    required Brightness brightness,
    VoidCallback? add,
    VoidCallback? property,
    ValueChanged<String>? rename,
    bool active = false,
  }) => MaterialApp(
    key: ValueKey('$width-$brightness-$active'),
    theme: buildTheme(brightness),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: DatabaseHeader(
            title: 'Untitled Table',
            totalRowCount: 4,
            filteredRowCount: 2,
            columns: columns,
            sortConfig: active
                ? const DatabaseSortConfig(columnId: 'name')
                : null,
            filterRules: active
                ? [
                    DatabaseFilterRule(
                      columnId: 'name',
                      operator: 'contains',
                      value: 'a',
                    ),
                  ]
                : [],
            searchQuery: '',
            onSortChanged: (_, _) {},
            onAddFilter: (_) {},
            onRemoveFilter: (_) {},
            onClearFilters: () {},
            onSearchChanged: (_) {},
            onAddRow: add ?? () {},
            onAddColumn: property ?? () {},
            onTitleChanged: rename ?? (_) {},
          ),
        ),
      ),
    ),
  );
  testWidgets(
    'toolbar and long active chips fit narrow and wide layouts in both themes',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final width in [280.0, 480.0, 760.0]) {
          await tester.pumpWidget(
            header(width: width, brightness: brightness, active: true),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Search'));
          await tester.pumpAndSettle();
          expect(find.text('Search...'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Close search'));
          await tester.pumpAndSettle();
          expect(find.text('Search...'), findsNothing);
        }
      }
    },
  );
  testWidgets('split New menu keeps page and property creation functional', (
    tester,
  ) async {
    var added = 0, properties = 0;
    await tester.pumpWidget(
      header(
        width: 600,
        brightness: Brightness.light,
        add: () => added++,
        property: () => properties++,
      ),
    );
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(added, 1);
    await tester.tap(find.byTooltip('More creation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();
    expect(properties, 1);
    expect(added, 1);
    await tester.tap(find.byTooltip('More creation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New page'));
    await tester.pumpAndSettle();
    expect(added, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/database/database_columns_header.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  final columns = [
    for (var i = 0; i < 4; i++)
      DatabaseColumn(
        id: 'c$i',
        databaseId: 'db',
        name: 'Column $i',
        type: i == 0 ? 'title' : 'text',
        width: 160,
        orderKey: '$i',
        createdAt: DateTime(2026),
      ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets(
      'column drag stays aligned and indicates destination $brightness',
      (t) async {
        final moves = <String>[];
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: ColumnsHeaderRow(
                  columns: columns,
                  columnWidths: const {},
                  headerBg: Colors.transparent,
                  borderColor: Colors.grey,
                  onSortChanged: (_, _) {},
                  onResize: (_, _) {},
                  onResizeEnd: (_, _) {},
                  onDeleteColumn: (_) {},
                  onAddColumn: () {},
                  onReorderColumn: (from, to) => moves.add('$from:$to'),
                ),
              ),
            ),
          ),
        );
        final source = find.byKey(const ValueKey('c1'));
        final target = find.byKey(const ValueKey('c3'));
        final sourceRect = t.getRect(source);
        final targetRect = t.getRect(target);
        final gesture = await t.startGesture(
          sourceRect.center,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(25, 0));
        await t.pump();
        await gesture.moveTo(
          Offset(targetRect.center.dx, sourceRect.center.dy + 70),
        );
        await t.pump();
        final preview = find.byKey(const ValueKey('database_column_drag_c1'));
        expect(t.getSize(preview), sourceRect.size);
        expect(t.getTopLeft(preview).dy, closeTo(sourceRect.top, 0.01));
        expect(find.text('Column 1'), findsNWidgets(2));
        final line = find.byKey(const ValueKey('database_column_drop_c3'));
        expect(line, findsOneWidget);
        expect(t.getRect(line).right, closeTo(targetRect.right, 0.01));
        await gesture.up();
        await t.pumpAndSettle();
        expect(moves, ['c1:c3']);
        expect(preview, findsNothing);
        expect(line, findsNothing);

        final reverse = await t.startGesture(
          targetRect.center,
          kind: PointerDeviceKind.mouse,
        );
        await reverse.moveBy(const Offset(-25, 0));
        await t.pump();
        await reverse.moveTo(sourceRect.center);
        await t.pump();
        final before = find.byKey(const ValueKey('database_column_drop_c1'));
        expect(t.getRect(before).left, closeTo(sourceRect.left, 0.01));
        // Title stays fixed and cannot receive a column.
        await reverse.moveTo(t.getCenter(find.byKey(const ValueKey('c0'))));
        await t.pump();
        expect(
          find.byKey(const ValueKey('database_column_drop_c0')),
          findsNothing,
        );
        await reverse.up();
        await t.pumpAndSettle();
        expect(moves, ['c1:c3']);
        expect(t.takeException(), isNull);
      },
    );
  }
}

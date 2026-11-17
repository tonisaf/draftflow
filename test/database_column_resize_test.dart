import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/app_icons.dart';
import 'package:notes_here/ui/editor/components/database/database_columns_header.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late double width;
  late List<double> saved;
  late List<double> updates;
  setUp(() {
    saved = [];
    updates = [];
  });
  Widget app({double initial = 200, String type = 'text', double scale = 1}) {
    width = initial;
    return MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                height: 36,
                child: Row(
                  children: [
                    ResizableColumnHeader(
                      key: const Key('header'),
                      column: DatabaseColumn(
                        id: 'test',
                        databaseId: 'db',
                        name: 'Column',
                        type: type,
                        width: initial,
                        orderKey: 'a',
                        createdAt: DateTime(2026),
                      ),
                      width: width,
                      icon: AppIcons.table,
                      borderColor: Colors.grey,
                      onSort: (_) {},
                      onClearSort: () {},
                      onResize: (value) {
                        updates.add(value);
                        setState(() => width = value);
                      },
                      onResizeEnd: saved.add,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset edge(WidgetTester t, {double scale = 1}) {
    final rect = t.getRect(find.byKey(const Key('header')));
    return Offset(rect.left + (width - 2) * scale, rect.top + 18 * scale);
  }

  testWidgets(
    'rapid movement between frames retains every pixel and saves final width',
    (t) async {
      await t.pumpWidget(app());
      final start = edge(t);
      final drag = await t.startGesture(start, kind: PointerDeviceKind.mouse);
      // No frames/rebuilds between updates or before release.
      for (var x = 30; x <= 300; x += 30) {
        await drag.moveTo(start + Offset(x.toDouble(), 0));
      }
      await drag.up();
      expect(width, closeTo(500, 0.01));
      expect(saved, [500]);
      await t.pumpAndSettle();
      expect(t.getSize(find.byKey(const Key('header'))).width, 500);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('columns can grow past 600 without a hidden cap', (t) async {
    await t.pumpWidget(app(initial: 500));
    final drag = await t.startGesture(edge(t), kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(300, 0));
    await drag.up();
    expect(width, closeTo(800, 0.01));
    expect(saved, [800]);
    await t.pumpAndSettle();
  });

  testWidgets(
    'rebuilds and display transforms keep the boundary under the cursor',
    (t) async {
      await t.pumpWidget(app(initial: 160, scale: 1.5));
      final start = edge(t, scale: 1.5);
      final drag = await t.startGesture(start, kind: PointerDeviceKind.mouse);
      for (var x = 30; x <= 300; x += 30) {
        await drag.moveTo(start + Offset(x.toDouble(), 0));
        await t.pump();
      }
      await drag.up();
      expect(width, closeTo(360, 0.01));
      expect(saved.single, closeTo(360, 0.01));
      await t.pumpAndSettle();
      final end = edge(t, scale: 1.5);
      expect(end.dx, closeTo(start.dx + 300, 0.01));
    },
  );

  for (final type in ['text', 'checkbox']) {
    testWidgets('$type minimum and cancellation preserve the visible width', (
      t,
    ) async {
      await t.pumpWidget(app(type: type));
      final start = edge(t);
      final drag = await t.startGesture(start, kind: PointerDeviceKind.mouse);
      await drag.moveTo(start - const Offset(500, 0));
      await t.pump();
      expect(width, type == 'checkbox' ? 60 : 115);
      await drag.moveTo(start + const Offset(80, 0));
      await drag.cancel();
      expect(width, closeTo(280, 0.01));
      expect(saved, [280]);
      await t.pumpAndSettle();
      await t.tapAt(edge(t));
      await t.pumpAndSettle();
      expect(saved, [280]);
      expect(t.takeException(), isNull);
    });
  }
}

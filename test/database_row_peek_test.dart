import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page, DataCell;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart';
import 'package:notes_here/ui/editor/components/database/database_row_modal.dart';
import 'package:notes_here/ui/editor/components/page_header.dart';
import 'package:notes_here/ui/editor/components/page_more_actions_button.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  testWidgets(
    'peek keeps actions in its header and property values aligned in both themes',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final id = await repo.createDatabase(
        title: 'A database with a long title',
      );
      await repo.addColumn(
        id,
        name: 'A property name that must truncate',
        type: 'text',
      );
      final rowId = await repo.createDatabaseRow(id, title: '');
      final page = (await repo.getPage(rowId))!;
      final columns = await repo.getColumns(id);
      String? opened;
      for (final brightness in Brightness.values) {
        for (final width in [320.0, 400.0, 1000.0]) {
          await tester.binding.setSurfaceSize(Size(width, 850));
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$brightness-$width'),
              theme: buildTheme(brightness),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DatabaseRowModal(
                        repository: repo,
                        databaseId: id,
                        page: page,
                        columns: columns,
                        onNavigateToPage: (id) => opened = id,
                      ),
                    ),
                    child: const Text('Open row'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open row'));
          await tester.pumpAndSettle();
          expect(find.byType(PageHeader), findsOneWidget);
          final close = tester.getRect(
            find.byKey(const ValueKey('row_peek_close')),
          );
          final editor = tester.getRect(find.byType(PageEditorView));
          expect(close.right, closeTo(editor.right - UiSpace.s12, 1));
          final title = find.descendant(
            of: find.byType(PageHeader),
            matching: find.byType(TextField),
          );
          final titleWidget = tester.widget<TextField>(title);
          expect(titleWidget.controller!.text, isEmpty);
          expect(titleWidget.style!.fontWeight, FontWeight.w600);
          expect(titleWidget.style!.color, Skin.of(brightness).text);
          final valueLefts = tester.getTopLeft(find.byType(DataCell).first).dx;
          for (final element in find.byType(DataCell).evaluate()) {
            expect(
              tester.getTopLeft(find.byWidget(element.widget)).dx,
              closeTo(valueLefts, 0.1),
            );
          }
          expect(
            tester.getTopLeft(find.byKey(const Key('page_save_status'))).dy,
            lessThan(tester.getTopLeft(find.byType(ModalPropertiesSection)).dy),
          );
          expect(
            tester.getTopLeft(find.byType(PageMoreActionsButton)).dy,
            lessThan(tester.getTopLeft(find.byType(ModalPropertiesSection)).dy),
          );
          final exception = tester.takeException();
          expect(exception, isNull, reason: '$brightness at $width');
          if (width == 1000 && brightness == Brightness.dark) {
            final checkbox = find.byKey(const ValueKey('database_checkbox'));
            expect(tester.getSize(checkbox), const Size(16, 16));
            await tester.tap(checkbox);
            await tester.pumpAndSettle();
            final properties = jsonDecode(
              (await repo.getPage(rowId))!.properties!,
            ) as Map<String, dynamic>;
            expect(
              properties[columns.firstWhere((c) => c.type == 'checkbox').id],
              true,
            );
            await tester.tap(find.text('Open full page'));
            await tester.pumpAndSettle();
            expect(opened, rowId);
          } else {
            await tester.tap(find.byKey(const ValueKey('row_peek_close')));
            await tester.pumpAndSettle();
          }
          expect(find.byType(DatabaseRowModal), findsNothing);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(null);
      await db.close();
    },
  );
}

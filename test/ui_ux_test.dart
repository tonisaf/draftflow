import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/main.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/trash/trash_view.dart';
import 'package:notes_here/ui/common/spring_motion.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  test('ThemeController cycles through system, light, dark', () {
    final controller = ThemeController(ThemeMode.system);
    expect(controller.mode, ThemeMode.system);

    controller.cycleNext();
    expect(controller.mode, ThemeMode.light);

    controller.cycleNext();
    expect(controller.mode, ThemeMode.dark);

    controller.cycleNext();
    expect(controller.mode, ThemeMode.system);
  });

  test('Skin depth, micro-border, pastel status and squircle tokens', () {
    final light = Skin.of(Brightness.light);
    final dark = Skin.of(Brightness.dark);
    final lightMica = Skin.of(Brightness.light, mica: true);

    expect(light.isDark, isFalse);
    expect(dark.isDark, isTrue);
    expect(lightMica.hairlineBorder, equals(light.hairlineBorder));
    expect(light.hairlineBorder.a, lessThan(0.1));
    expect(dark.hairlineBorder.a, closeTo(0.10, 0.01));

    expect(light.cardShadows.length, greaterThanOrEqualTo(2));
    expect(light.popoverShadows.length, greaterThanOrEqualTo(2));
    expect(light.modalShadows.length, greaterThanOrEqualTo(2));
    expect(dark.modalShadows.length, greaterThanOrEqualTo(2));

    expect(light.glassStrong.a, lessThan(1.0));
    expect(light.glassSurface.a, lessThan(1.0));
    expect(light.frostedSurface.a, lessThan(1.0));
    expect(dark.frostedPopover.a, lessThan(1.0));

    expect(light.warningBg.a, lessThan(0.25));
    expect(light.dangerBg.a, lessThan(0.25));
    expect(light.successBg.a, lessThan(0.25));

    final shape = UiRadius.squircle(UiRadius.modal);
    expect(shape, isA<ContinuousRectangleBorder>());
  });

  testWidgets('SpringPress scales on press and skips Transform at rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SpringPress(pressed: false, child: Text('Tap')),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(SpringPress),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SpringPress(pressed: true, scale: 0.95, child: Text('Tap')),
      ),
    );
    await tester.pumpAndSettle();
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(SpringPress),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.storage[0], closeTo(0.95, 0.01));
  });

  testWidgets('TrashView displays trashed items and allows emptying trash',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = NotesRepository(db);

    // Create a page and trash it
    final pageId = await repo.createPage(title: 'To Be Deleted');
    await repo.trashPage(pageId);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: TrashView(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('To Be Deleted'), findsOneWidget);
    expect(find.text('Empty Trash'), findsOneWidget);

    // Tap Empty Trash
    await tester.tap(find.text('Empty Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Empty Trash?'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('To Be Deleted'), findsOneWidget);

    // Tap Empty Trash again and confirm
    await tester.tap(find.text('Empty Trash'));
    await tester.pumpAndSettle();
    // In the dialog:
    await tester.tap(find.widgetWithText(FilledButton, 'Empty Trash'));
    await tester.pumpAndSettle();

    // Now trash should be empty
    expect(find.text('Trash is empty'), findsOneWidget);
    expect(find.text('To Be Deleted'), findsNothing);

    await db.close();
  });
}

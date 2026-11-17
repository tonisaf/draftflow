import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/page_settings.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('PageSettings serialization and repository updates preserve other properties', () async {
    final pageId = await repo.createPage(title: 'Style Test');
    await db.replaceRowProperties(
      pageId,
      jsonEncode({
        'customData': 'hello',
        pageSettingsKey: {'subpageLayout': 'list'},
      }),
    );

    // Initial settings
    var page = (await repo.getPage(pageId))!;
    var settings = pageSettingsFromProperties(page.properties);
    expect(settings.fullWidth, isFalse);
    expect(settings.smallText, isFalse);
    expect(settings.subpageLayout, SubpageLayout.list);

    // Update full width
    await repo.updatePageSettings(pageId, fullWidth: true);
    page = (await repo.getPage(pageId))!;
    settings = pageSettingsFromProperties(page.properties);
    expect(settings.fullWidth, isTrue);
    expect(settings.smallText, isFalse);

    // Update small text
    await repo.updatePageSettings(pageId, smallText: true);
    page = (await repo.getPage(pageId))!;
    settings = pageSettingsFromProperties(page.properties);
    expect(settings.fullWidth, isTrue);
    expect(settings.smallText, isTrue);

    // Verify existing custom properties are preserved
    final decoded = jsonDecode(page.properties!);
    expect(decoded['customData'], 'hello');
  });

  testWidgets(
    'Page more actions menu allows toggling small text and full width',
    (tester) async {
      final pageId = await repo.createPage(title: 'Settings Page');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageEditorView(
              repository: repo,
              pageId: pageId,
              title: 'Settings Page',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Page actions menu
      await tester.tap(find.byKey(const Key('page_more_actions_button')));
      await tester.pumpAndSettle();

      // Verify Style section and toggle switches exist
      expect(find.text('Стиль'), findsOneWidget);
      expect(find.text('Мелкий шрифт'), findsOneWidget);
      expect(find.text('Во всю ширину'), findsOneWidget);

      // Toggle small text
      await tester.tap(find.byKey(const Key('page_style_small_text_switch')));
      await tester.pumpAndSettle();

      final smallTextSwitch = tester.widget<Switch>(
        find.byKey(const Key('page_style_small_text_switch')),
      );
      expect(smallTextSwitch.value, isTrue);

      var page = (await repo.getPage(pageId))!;
      var settings = pageSettingsFromProperties(page.properties);
      expect(settings.smallText, isTrue);

      // Toggle full width
      await tester.tap(find.byKey(const Key('page_style_full_width_switch')));
      await tester.pumpAndSettle();

      final fullWidthSwitch = tester.widget<Switch>(
        find.byKey(const Key('page_style_full_width_switch')),
      );
      expect(fullWidthSwitch.value, isTrue);

      page = (await repo.getPage(pageId))!;
      settings = pageSettingsFromProperties(page.properties);
      expect(settings.fullWidth, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

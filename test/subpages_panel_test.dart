import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/page_settings.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/sync/sync_outbox.dart';
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

  test('layout belongs to each page, preserves metadata and enters the sync outbox', () async {
    final parent = await repo.createPage(title: 'Parent');
    final other = await repo.createPage(title: 'Other');
    await db.replaceRowProperties(
      parent,
      jsonEncode({
        'other': true,
        pageSettingsKey: {'futureSetting': 42},
      }),
    );
    final outbox = SyncOutbox(db);
    await outbox.enable();
    await outbox.acknowledge(
      (await outbox.pending()).map((p) => p.operationId),
    );
    await repo.updateSubpageLayout(parent, SubpageLayout.cards);
    final saved = (await repo.getPage(parent))!;
    expect(subpageLayoutFromProperties(saved.properties), SubpageLayout.cards);
    expect(
      subpageLayoutFromProperties((await repo.getPage(other))!.properties),
      SubpageLayout.list,
    );
    final props = jsonDecode(saved.properties!);
    expect(props['other'], true);
    expect(props[pageSettingsKey]['futureSetting'], 42);
    final pending = (await outbox.pending())
        .where((p) => p.entityId == parent)
        .last;
    expect(
      subpageLayoutFromProperties(
        jsonDecode(pending.payload)['properties'] as String,
      ),
      SubpageLayout.cards,
    );
    await repo.updateSubpageLayout(parent, SubpageLayout.list);
    expect(
      subpageLayoutFromProperties((await repo.getPage(parent))!.properties),
      SubpageLayout.list,
    );
  });

  test('children query excludes grandchildren, trash and database rows and tracks moves', () async {
    final parent = await repo.createPage(title: 'Parent');
    final child = await repo.createPage(parentId: parent, title: 'Child');
    await repo.createPage(parentId: child, title: 'Grandchild');
    final trashed = await repo.createPage(parentId: parent, title: 'Deleted');
    await repo.trashPage(trashed);
    final databaseId = await repo.createDatabase(parentPageId: parent);
    await repo.createDatabaseRow(databaseId, title: 'A database row');
    expect((await repo.watchChildPages(parent).first).map((p) => p.id), [
      child,
    ]);
    await repo.reorderPage(pageId: child, targetParentId: null);
    expect(await repo.watchChildPages(parent).first, isEmpty);
  });

  testWidgets(
    'page menu switches views, links navigate and new children belong to the current page',
    (tester) async {
      final parent = await repo.createPage(title: 'Getting Started');
      final child = await repo.createPage(
        parentId: parent,
        title: 'Architecture & Design',
      );
      String? opened;
      for (final brightness in Brightness.values) {
        for (final width in [320.0, 900.0]) {
          await repo.updateSubpageLayout(parent, SubpageLayout.list);
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$brightness-$width'),
              theme: buildTheme(brightness),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: PageEditorView(
                  repository: repo,
                  pageId: parent,
                  title: 'Getting Started',
                  onNavigateToPage: (id) => opened = id,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('subpages_list')), findsOneWidget);
          await tester.tap(find.byKey(ValueKey('subpage_$child')));
          expect(opened, child);
          await tester.tap(find.byKey(const Key('page_more_actions_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Карточки'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('subpages_cards')), findsOneWidget);
          expect(
            subpageLayoutFromProperties(
              (await repo.getPage(parent))!.properties,
            ),
            SubpageLayout.cards,
          );
          expect(tester.takeException(), isNull, reason: '$brightness $width');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageEditorView(
              repository: repo,
              pageId: parent,
              title: 'Getting Started',
              onNavigateToPage: (id) => opened = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subpages_cards')), findsOneWidget);
      await tester.tap(find.text('Новая страница'));
      await tester.pumpAndSettle();
      expect(opened, isNot(child));
      expect((await repo.getPage(opened!))!.parentId, parent);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(null);
    },
  );
}

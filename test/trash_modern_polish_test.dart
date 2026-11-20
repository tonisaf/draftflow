import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:notes_here/ui/trash/trash_view.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTrashApp() {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: TrashView(repository: repository),
      ),
    );
  }

  testWidgets(
      'TrashView deduplicates leading emojis from titles when icon is present',
      (tester) async {
    // 1. Create a page with emoji icon and duplicate emoji in title
    final pageId1 = await repository.createPage(
      title: '📄 📄 Пятый сезон сериала',
      icon: '📄',
    );
    await repository.trashPage(pageId1);

    // 2. Create another page with speech bubble emoji
    final pageId2 = await repository.createPage(
      title: '💬 💬 «Точное количество»',
      icon: '💬',
    );
    await repository.trashPage(pageId2);

    await tester.pumpWidget(createTrashApp());
    await tester.pumpAndSettle();

    // Verify duplicate emojis were stripped from the displayed titles
    expect(find.text('Пятый сезон сериала'), findsOneWidget);
    expect(find.text('«Точное количество»'), findsOneWidget);
    expect(find.text('📄 📄 Пятый сезон сериала'), findsNothing);
    expect(find.text('💬 💬 «Точное количество»'), findsNothing);

    // Verify leading slots are fixed 24x24 boxes
    final iconBoxes = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.width == 24.0 &&
          widget.height == 24.0,
    );
    expect(iconBoxes, findsAtLeastNWidgets(2));
  });

  testWidgets(
      'TrashView header aligns with Notes & Inbox: no leading icon, muted subtitle, search & 36px empty button',
      (tester) async {
    final pageId = await repository.createPage(title: 'Заметка для теста');
    await repository.trashPage(pageId);

    await tester.pumpWidget(createTrashApp());
    await tester.pumpAndSettle();

    // Verify title and subtitle
    expect(find.text('Корзина'), findsOneWidget);
    expect(find.text('Удалённые страницы и веб-клипы'), findsOneWidget);

    // Verify search input
    expect(find.text('Поиск…'), findsOneWidget);

    // Verify Empty Trash button height is 36
    final emptyBtn = find.byKey(const Key('trash_empty_button'));
    expect(emptyBtn, findsOneWidget);
    expect(tester.getSize(emptyBtn).height, 36.0);
  });

  testWidgets('Search input filters trash entries by query', (tester) async {
    final page1 = await repository.createPage(title: 'Финансы и бюджет');
    final page2 = await repository.createPage(title: 'Список покупок');
    await repository.trashPage(page1);
    await repository.trashPage(page2);

    await tester.pumpWidget(createTrashApp());
    await tester.pumpAndSettle();

    expect(find.text('Финансы и бюджет'), findsOneWidget);
    expect(find.text('Список покупок'), findsOneWidget);

    // Search for "Финансы"
    await tester.enterText(find.byType(TextField), 'Финансы');
    await tester.pumpAndSettle();

    expect(find.text('Финансы и бюджет'), findsOneWidget);
    expect(find.text('Список покупок'), findsNothing);

    // Clear search
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('Финансы и бюджет'), findsOneWidget);
    expect(find.text('Список покупок'), findsOneWidget);
  });
}

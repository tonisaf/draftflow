import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:notes_here/ui/trash/trash_view.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });
  tearDown(() => db.close());
  Widget app({
    Brightness brightness = Brightness.light,
    double scale = 1,
    Key? preview,
    bool font = false,
  }) => RepaintBoundary(
    key: preview,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: font
          ? buildTheme(brightness).copyWith(
              textTheme: buildTheme(brightness).textTheme
                  .apply(fontFamily: 'Trash preview'),
            )
          : buildTheme(brightness),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: TrashView(repository: repo)),
    ),
  );
  void size(WidgetTester t, double width) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 900);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets(
    'centered unframed rows show live parent context and match reference width',
    (t) async {
      size(t, 1400);
      final parent = await repo.createPage(title: 'Работа');
      final child = await repo.createPage(
        title: 'Новая заметка',
        parentId: parent,
      );
      await repo.trashPage(child);
      final database = await repo.createDatabase(
        title: 'Проектные SQL',
        parentPageId: parent,
      );
      await repo.createDatabaseRow(database, title: 'Активные подключения');
      await repo.trashDatabase(database);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final row = find.byKey(ValueKey('trash_row_page:$child'));
      expect(t.getSize(row).width, 720);
      expect(t.getRect(row).center.dx, 700);
      expect(t.getSize(row).height, 48);
      expect(t.getSize(find.byKey(const Key('trash_empty_button'))).height, 36);
      expect(find.text('Работа'), findsNWidgets(2));
      expect(find.text('Проектные SQL'), findsNWidgets(2));
      expect(find.text('Восстановить'), findsNothing);
      expect(find.byTooltip('Восстановить'), findsNWidgets(3));
      expect(find.byType(Divider), findsNothing);
      final decoration = t.widget<Container>(row).decoration as BoxDecoration;
      expect(decoration.border, isNull);
      final title = t.widget<Text>(find.byKey(const Key('trash_heading')));
      expect(title.style!.fontSize, 26);
      await repo.updatePageTitle(parent, 'Обновлённый проект');
      await t.pumpAndSettle();
      expect(find.text('Работа'), findsNothing);
      expect(find.text('Обновлённый проект'), findsNWidgets(2));
      await finish(t);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'narrow trash with large text keeps actions reachable $brightness',
      (t) async {
        size(t, 320);
        final parent = await repo.createPage(
          title: 'Родительская страница с длинным названием',
        );
        final child = await repo.createPage(
          parentId: parent,
          title: 'Очень длинное название удалённой страницы',
        );
        await repo.trashPage(child);
        await t.pumpWidget(app(brightness: brightness, scale: 1.8));
        await t.pumpAndSettle();
        final restore = find.byKey(ValueKey('trash_restore_page:$child'));
        final remove = find.byKey(ValueKey('trash_delete_page:$child'));
        expect(t.getRect(restore).overlaps(t.getRect(remove)), isFalse);
        expect(t.getRect(remove).right, lessThanOrEqualTo(320));
        expect(t.takeException(), isNull);
        await t.tap(restore);
        await t.pumpAndSettle();
        expect((await repo.getPage(child))!.trashedAt, isNull);
        expect(find.text('Корзина пуста'), findsOneWidget);
        await finish(t);
      },
    );
  }

  testWidgets(
    'native keyboard restore and permanent delete preserve action semantics',
    (t) async {
      final a = await repo.createPage(title: 'Первая');
      await repo.trashPage(a);
      final b = await repo.createPage(title: 'Вторая');
      await repo.trashPage(b);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      final remaining = await repo.watchTrashEntries().first;
      expect(remaining.length, 1);
      final removed = remaining.single.id;
      final restored = removed == a ? b : a;
      expect((await repo.getPage(restored))!.trashedAt, isNull);
      await t.tap(find.byKey(ValueKey('trash_delete_page:$removed')));
      await t.pumpAndSettle();
      expect(await repo.getPage(removed), isNull);
      expect(find.text('Корзина пуста'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets('native font preview of reference-style trash', (t) async {
    size(t, 1400);
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Trash preview')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await t.runAsync(() => loader.load());
    }
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await t.runAsync(() => material.load());
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await t.runAsync(() => icons.load());
    final parent = await repo.createPage(title: 'Работа');
    for (final name in ['Архив', 'Обновление', 'Документы', 'Проекты']) {
      final page = await repo.createPage(title: name, parentId: parent);
      await repo.trashPage(page);
    }
    for (final name in ['Черновик', 'Без названия', 'Untitled Table']) {
      final page = await repo.createPage(title: name);
      await repo.trashPage(page);
    }
    final preview = GlobalKey();
    await t.pumpWidget(app(preview: preview, font: font.existsSync()));
    await t.pumpAndSettle();
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(preview));
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory('build/logs').create(recursive: true);
      await File('build/logs/trash-reference-preview.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
    await finish(t);
  });
}

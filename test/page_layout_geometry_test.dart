import 'package:notes_here/data/model/page_settings.dart';

import 'dart:ui' show PointerDeviceKind;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/editor/components/notes_paragraph_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late String page;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    page = await repo.createPage(title: 'Заметка');
    await repo.updatePageCover(page, 'gradient:aurora');
    await repo.updatePageIcon(page, '⚡');
    await repo.savePageNodes(page, [
      paragraphNode(text: 'Текст страницы по центру'),
    ]);
  });
  tearDown(() => db.close());
  Widget app({
    Brightness brightness = Brightness.light,
    Key? preview,
    bool font = false,
  }) => RepaintBoundary(
    key: preview,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: font
          ? buildTheme(brightness).copyWith(
              platform: TargetPlatform.windows,
              textTheme: buildTheme(brightness).textTheme
                  .apply(fontFamily: 'Page preview'),
            )
          : buildTheme(brightness),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PageEditorView(
          repository: repo,
          pageId: page,
          title: 'Заметка',
          initialIcon: '⚡',
          initialCover: 'gradient:aurora',
        ),
      ),
    ),
  );
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  void size(WidgetTester t, double width) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 800);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'centered content, edge-to-edge cover and corner actions ($brightness)',
      (t) async {
        size(t, 1600);
        await t.pumpWidget(app(brightness: brightness));
        await t.pumpAndSettle();
        final title = t.getRect(find.byKey(const Key('page_title_input')));
        final paragraph = t.getRect(
          find.byType(NotesParagraphBlockComponentWidget).first,
        );
        expect(title.center.dx, 800);
        expect(title.width, UiLayout.editorMaxWidth - 80);
        expect(paragraph.center.dx, 800);
        expect(paragraph.left, closeTo(title.left, 1));
        final cover = t.getRect(find.byKey(const Key('page_cover_banner')));
        expect(cover.left, 0);
        expect(cover.right, 1600);
        expect(cover.height, UiLayout.coverHeight);
        expect(
          t.getRect(find.byKey(const Key('page_editor_surface'))),
          const Rect.fromLTWH(0, 0, 1600, 800),
        );
        final menu = t.getRect(
          find.byKey(const Key('page_more_actions_button')),
        );
        expect(menu.right, 1584);
        expect(menu.top, 8);
        expect(cover.top, menu.bottom + 8);
        final tile = t.getRect(find.byKey(const Key('page_icon_button'))),
            glyph = t.getRect(find.byKey(const Key('page_icon_glyph')));
        expect(tile.left, title.left);
        expect(tile.center, glyph.center);
        expect(tile.center.dy, cover.bottom);
        expect(find.text('Сохранено'), findsNothing);
        expect(find.byTooltip('Сохранено'), findsOneWidget);
        expect(find.text('Удалить иконку'), findsNothing);
        expect(find.text('Сменить обложку'), findsNothing);
        expect(find.text('Удалить обложку'), findsNothing);
        expect(find.byTooltip('Сменить обложку'), findsOneWidget);
        expect(find.byTooltip('Удалить обложку'), findsOneWidget);
        await finish(t);
      },
    );
  }
  testWidgets(
    'full width toggles content without moving cover or corner menu',
    (t) async {
      size(t, 1600);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final cover = t.getRect(find.byKey(const Key('page_cover_banner'))),
          menu = t.getRect(find.byKey(const Key('page_more_actions_button')));
      await repo.updatePageSettings(page, fullWidth: true);
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('page_title_input'))).left, 40);
      expect(t.getRect(find.byKey(const Key('page_title_input'))).width, 1520);
      expect(
        t.getRect(find.byType(NotesParagraphBlockComponentWidget).first).left,
        40,
      );
      expect(t.getRect(find.byKey(const Key('page_cover_banner'))), cover);
      expect(
        t.getRect(find.byKey(const Key('page_more_actions_button'))),
        menu,
      );
      await repo.updatePageSettings(page, fullWidth: false);
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(const Key('page_title_input'))).center.dx,
        800,
      );
      await finish(t);
    },
  );
  testWidgets(
    'upper overlapping icon is clickable and removal lives only in picker',
    (t) async {
      size(t, 1000);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final tile = t.getRect(find.byKey(const Key('page_icon_button')));
      await t.tapAt(tile.topLeft + const Offset(32, 8));
      await t.pumpAndSettle();
      expect(find.text('Удалить иконку'), findsOneWidget);
      await t.tap(find.text('Удалить иконку'));
      await t.pumpAndSettle();
      expect((await repo.getPage(page))!.icon, isNull);
      expect(find.byKey(const Key('page_icon_button')), findsNothing);
      expect((await repo.getPage(page))!.cover, 'gradient:aurora');
      await finish(t);
    },
  );
  testWidgets(
    'cover icon actions open picker and remove cover, keeping page icon',
    (t) async {
      size(t, 1000);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        t.getCenter(find.byKey(const Key('page_cover_banner'))),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Сменить обложку'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await mouse.moveTo(
        t.getCenter(find.byKey(const Key('page_cover_banner'))),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Удалить обложку'));
      await t.pumpAndSettle();
      await mouse.removePointer();
      expect((await repo.getPage(page))!.cover, isNull);
      expect(find.byKey(const Key('page_cover_banner')), findsNothing);
      expect(find.byKey(const Key('page_icon_button')), findsOneWidget);
      await finish(t);
    },
  );
  testWidgets('narrow pages remain within the viewport in both width modes', (
    t,
  ) async {
    size(t, 320);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    for (final full in [false, true]) {
      await repo.updatePageSettings(page, fullWidth: full);
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('page_cover_banner'))).width, 320);
      expect(
        t.getRect(find.byKey(const Key('page_more_actions_button'))).right,
        304,
      );
      expect(t.getRect(find.byKey(const Key('page_title_input'))).left, 40);
      expect(t.takeException(), isNull);
    }
    await finish(t);
  });
  testWidgets('save a page header preview at desktop width', (t) async {
    size(t, 1400);
    final file = File('C:/Windows/Fonts/segoeui.ttf');
    if (file.existsSync()) {
      final loader = FontLoader('Page preview')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await t.runAsync(() => loader.load());
    }
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (emoji.existsSync()) {
      final loader = FontLoader('Segoe UI Emoji')
        ..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())));
      await t.runAsync(() => loader.load());
    }
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await t.runAsync(() => icons.load());
    final preview = GlobalKey();
    await t.pumpWidget(app(preview: preview, font: file.existsSync()));
    await t.pumpAndSettle();
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(preview));
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/logs').create(recursive: true);
      await File('build/logs/page-header-layout.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await repo.updatePageSettings(page, coverToTop: true);
    await t.pumpAndSettle();
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(t.getCenter(find.byKey(const Key('page_cover_banner'))));
    await t.pumpAndSettle();
    final tile = t.getRect(find.byKey(const Key('page_icon_button')));
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      if (emoji.existsSync()) {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int? inkTop, inkBottom;
        for (var y = tile.top.ceil(); y < tile.bottom.floor(); y++) {
          for (var x = tile.left.ceil(); x < tile.right.floor(); x++) {
            final offset = (y * image.width + x) * 4;
            final r = rgba.getUint8(offset);
            final g = rgba.getUint8(offset + 1);
            final b = rgba.getUint8(offset + 2);
            if (r > 220 && g > 50 && g < 200 && b < 80) {
              inkTop ??= y;
              inkBottom = y;
            }
          }
        }
        expect(inkTop, isNotNull);
        final topGap = inkTop! - tile.top;
        final bottomGap = tile.bottom - (inkBottom! + 1);
        expect(
          (topGap - bottomGap).abs(),
          lessThanOrEqualTo(1),
          reason: 'Center visible emoji ink, not just its line box',
        );
      }
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/logs/cover-to-top-preview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await mouse.removePointer();
    await finish(t);
  });
  testWidgets(
    'cover controls are visible and clickable only while the cover is hovered',
    (t) async {
      size(t, 1000);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final visibility = find.byKey(const Key('cover_actions_visibility'));
      final toggle = find.byKey(const Key('cover_to_top_button'));
      final title = t.getRect(find.byKey(const Key('page_title_input')));
      expect(t.widget<AnimatedOpacity>(visibility).opacity, 0);
      expect(toggle.hitTestable(), findsNothing);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        t.getCenter(find.byKey(const Key('page_cover_banner'))),
      );
      await t.pumpAndSettle();
      expect(t.widget<AnimatedOpacity>(visibility).opacity, 1);
      expect(toggle.hitTestable(), findsOneWidget);
      expect(find.byType(AppFlowyEditor), findsOneWidget);
      await mouse.moveTo(title.center);
      await t.pumpAndSettle();
      expect(t.widget<AnimatedOpacity>(visibility).opacity, 0);
      expect(toggle.hitTestable(), findsNothing);
      expect(t.getRect(find.byKey(const Key('page_title_input'))), title);
      await mouse.removePointer();
      await finish(t);
    },
  );
  testWidgets(
    'cover moves to panel top, persists and toggles back without replacing the editor',
    (t) async {
      size(t, 1000);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final state = t
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      final title = t.getRect(find.byKey(const Key('page_title_input')));
      final menu = t.getRect(find.byKey(const Key('page_more_actions_button')));
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        t.getCenter(find.byKey(const Key('page_cover_banner'))),
      );
      await t.pumpAndSettle();
      final button = t.getRect(find.byKey(const Key('cover_to_top_button')));
      await t.tap(find.byKey(const Key('cover_to_top_button')));
      await t.pump();
      for (final ms in [16, 40, 80]) {
        await t.pump(Duration(milliseconds: ms));
        expect(find.byType(AppFlowyEditor), findsOneWidget);
        expect(
          t.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState,
          same(state),
        );
      }
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('page_cover_banner'))).top, 0);
      expect(
        t.getRect(find.byKey(const Key('page_title_input'))).top,
        closeTo(title.top - UiLayout.pageToolbarHeight, 0.1),
      );
      expect(
        t.getRect(find.byKey(const Key('page_more_actions_button'))),
        menu,
      );
      expect(
        t.getRect(find.byKey(const Key('cover_to_top_button'))).top,
        closeTo(button.top, 0.1),
      );
      expect(
        pageSettingsFromProperties((await repo.getPage(page))!.properties)
            .coverToTop,
        isTrue,
      );
      await repo.updatePageSettings(page, fullWidth: true, smallText: true);
      await t.pumpAndSettle();
      expect(
        pageSettingsFromProperties((await repo.getPage(page))!.properties)
            .coverToTop,
        isTrue,
      );
      await finish(t);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('page_cover_banner'))).top, 0);
      await mouse.moveTo(
        t.getCenter(find.byKey(const Key('page_cover_banner'))),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('Обложка под верхней панелью'), findsOneWidget);
      await t.tap(find.byKey(const Key('cover_to_top_button')));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(const Key('page_cover_banner'))).top,
        UiLayout.pageToolbarHeight,
      );
      expect(
        pageSettingsFromProperties((await repo.getPage(page))!.properties)
            .coverToTop,
        isFalse,
      );
      await mouse.removePointer();
      await finish(t);
    },
  );
  testWidgets(
    'top cover mode fits narrow dark pages and removal restores the normal toolbar',
    (t) async {
      size(t, 320);
      await repo.updatePageSettings(page, coverToTop: true);
      await t.pumpWidget(app(brightness: Brightness.dark));
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('page_cover_banner'))).top, 0);
      expect(
        t.getRect(find.byKey(const Key('page_more_actions_button'))).right,
        304,
      );
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(const Offset(160, 100));
      await t.pumpAndSettle();
      final toggle = t.getRect(find.byKey(const Key('cover_to_top_button')));
      expect(toggle.left, greaterThan(0));
      expect(toggle.bottom, lessThan(UiLayout.coverHeight));
      await t.tap(find.byTooltip('Удалить обложку'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('page_cover_banner')), findsNothing);
      expect((await repo.getPage(page))!.cover, isNull);
      expect(
        pageSettingsFromProperties((await repo.getPage(page))!.properties)
            .coverToTop,
        isTrue,
      );
      expect(t.takeException(), isNull);
      await mouse.removePointer();
      await finish(t);
    },
  );
  test(
    'cover top metadata defaults and copy preserve independent settings',
    () async {
      expect(pageSettingsFromProperties(null).coverToTop, isFalse);
      const settings = PageSettings(coverToTop: true);
      expect(settings.copyWith(fullWidth: true).coverToTop, isTrue);
      expect(settings, const PageSettings(coverToTop: true));
      expect(settings == const PageSettings(), isFalse);
      await repo.updatePageSettings(page, coverToTop: true);
      await repo.updatePageSettings(page, smallText: true);
      final parsed = pageSettingsFromProperties(
        (await repo.getPage(page))!.properties,
      );
      expect(parsed.coverToTop, isTrue);
      expect(parsed.smallText, isTrue);
    },
  );
}

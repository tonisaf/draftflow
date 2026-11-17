import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/home_screen.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/editor/components/page_header.dart';
import 'package:notes_here/ui/theme.dart';

class _DelayedRepository extends NotesRepository {
  _DelayedRepository(super.db);
  String? slowPage;
  Completer<void>? gate;
  @override
  Future<({Document document, String version})> loadPageSnapshot(
    String pageId,
  ) async {
    if (pageId == slowPage && gate != null) await gate!.future;
    return super.loadPageSnapshot(pageId);
  }
}

void main() {
  late AppDatabase db;
  late _DelayedRepository repo;
  late String alpha, beta, gamma;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = _DelayedRepository(db);
    alpha = await repo.createPage(title: 'Page Alpha');
    beta = await repo.createPage(title: 'Page Beta');
    gamma = await repo.createPage(title: 'Page Gamma');
    await repo.savePageNodes(alpha, [
      for (var i = 0; i < 20; i++) paragraphNode(text: 'ALPHA BODY $i'),
    ]);
    await repo.savePageNodes(beta, [paragraphNode(text: 'BETA BODY')]);
    await repo.savePageNodes(gamma, [paragraphNode(text: 'GAMMA BODY')]);
    await repo.updatePageCover(beta, 'gradient:aurora');
    await repo.updatePageIcon(beta, '⚡');
    await repo.updatePageSettings(beta, fullWidth: true);
  });
  tearDown(() => db.close());
  Widget app({
    Brightness brightness = Brightness.light,
    bool reduced = false,
  }) => MaterialApp(
    theme: buildTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: HomeScreen(repository: repo),
  );
  Future<void> open(
    WidgetTester t, {
    Brightness brightness = Brightness.light,
    bool reduced = false,
  }) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(app(brightness: brightness, reduced: reduced));
    await t.pumpAndSettle();
    if (t.widget<PageEditorView>(find.byType(PageEditorView)).pageId != alpha) {
      await t.tap(find.text('Page Alpha').first);
      await t.pumpAndSettle();
    }
  }

  void onlyPage(WidgetTester t, String id) {
    expect(find.byType(PageEditorView), findsOneWidget);
    expect(t.widget<PageEditorView>(find.byType(PageEditorView)).pageId, id);
    expect(find.byType(PageHeader).evaluate().length, lessThanOrEqualTo(1));
    expect(find.byType(AppFlowyEditor).evaluate().length, lessThanOrEqualTo(1));
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        'only one live page in every transition frame ($brightness, reduced=$reduced)',
        (t) async {
          await open(t, brightness: brightness, reduced: reduced);
          onlyPage(t, alpha);
          for (final destination in [
            (beta, 'Page Beta'),
            (gamma, 'Page Gamma'),
            (alpha, 'Page Alpha'),
          ]) {
            await t.tap(find.text(destination.$2).first);
            await t.pump();
            onlyPage(t, destination.$1);
            for (final ms in [16, 40, 80, 160]) {
              await t.pump(Duration(milliseconds: ms));
              onlyPage(t, destination.$1);
            }
            await t.pumpAndSettle();
            onlyPage(t, destination.$1);
            final content = t
                .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
                .editorState
                .document
                .root
                .children
                .map((n) => n.delta?.toPlainText() ?? '')
                .join();
            expect(
              content,
              contains(
                destination.$1 == alpha
                    ? 'ALPHA BODY'
                    : destination.$1 == beta
                    ? 'BETA BODY'
                    : 'GAMMA BODY',
              ),
            );
            expect(t.takeException(), isNull);
          }
          await finish(t);
        },
      );
    }
  }
  testWidgets('late loading page never replaces the page selected afterwards', (
    t,
  ) async {
    await open(t);
    repo.slowPage = beta;
    repo.gate = Completer<void>();
    await t.tap(find.text('Page Beta').first);
    await t.pump();
    onlyPage(t, beta);
    expect(find.byType(AppFlowyEditor), findsNothing);
    await t.tap(find.text('Page Gamma').first);
    await t.pumpAndSettle();
    onlyPage(t, gamma);
    repo.gate!.complete();
    await t.pumpAndSettle();
    onlyPage(t, gamma);
    final content = t
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState
        .document
        .root
        .children
        .single
        .delta!
        .toPlainText();
    expect(content, contains('GAMMA BODY'));
    expect(t.takeException(), isNull);
    await finish(t);
  });
  testWidgets('switching flushes title/body edits to their original page', (
    t,
  ) async {
    await open(t);
    await t.enterText(
      find.byKey(const Key('page_title_input')),
      'Alpha edited',
    );
    final state = t
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    await state.apply(
      state.transaction
        ..insertText(state.document.root.children.first, 0, 'UNSAVED PREFIX '),
    );
    await t.tap(find.text('Page Beta').first);
    await t.pump();
    onlyPage(t, beta);
    await t.pumpAndSettle();
    expect((await repo.getPage(alpha))!.title, 'Alpha edited');
    expect((await repo.getPage(beta))!.title, 'Page Beta');
    expect(
      (await repo.loadPageSnapshot(alpha)).document.root.children.first.delta!
          .toPlainText(),
      startsWith('UNSAVED PREFIX '),
    );
    expect(
      (await repo.loadPageSnapshot(beta)).document.root.children.first.delta!
          .toPlainText(),
      'BETA BODY',
    );
    await finish(t);
  });
}

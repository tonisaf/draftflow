import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:notes_here/ui/editor/components/smooth_page_block_component.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/app_scroll_behavior.dart';
import 'package:notes_here/ui/common/smooth_wheel_region.dart';

void main() {
  late ScrollController vertical;
  late ScrollController horizontal;
  late ScrollController outer;
  setUp(() {
    vertical = ScrollController();
    horizontal = ScrollController();
    outer = ScrollController();
  });
  tearDown(() {
    vertical.dispose();
    horizontal.dispose();
    outer.dispose();
  });

  Widget mount({bool reduced = false}) => MaterialApp(
    theme: ThemeData(platform: TargetPlatform.windows),
    scrollBehavior: const AppScrollBehavior(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: SingleChildScrollView(
          controller: outer,
          child: SmoothWheelRegion(
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    controller: horizontal,
                    scrollDirection: Axis.horizontal,
                    child: SmoothWheelRegion(
                      child: SizedBox(
                        width: 1600,
                        child: ListView.builder(
                          controller: vertical,
                          itemExtent: 40,
                          itemCount: 50,
                          itemBuilder: (_, i) => SmoothWheelRegion(
                            child: SizedBox(
                              key: ValueKey('row_$i'),
                              height: 40,
                              child: Text('Row $i'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> wheel(
    WidgetTester t,
    Offset delta, {
    Offset? at,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    await t.sendEventToBinding(
      PointerScrollEvent(
        position: at ?? const Offset(120, 90),
        scrollDelta: delta,
        kind: kind,
      ),
    );
  }

  testWidgets(
    'wheel interpolates frames, accumulates notches and reverses immediately',
    (t) async {
      await t.pumpWidget(mount());
      await wheel(t, const Offset(0, 120));
      expect(vertical.offset, 0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 35));
      final first = vertical.offset;
      expect(first, inExclusiveRange(0, 120));
      await wheel(t, const Offset(0, 120));
      expect(vertical.offset, first);
      await t.pumpAndSettle();
      expect(vertical.offset, closeTo(240, 0.1));
      expect(outer.offset, 0);
      await wheel(t, const Offset(0, 240));
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      final beforeReverse = vertical.offset;
      await wheel(t, const Offset(0, -80));
      await t.pumpAndSettle();
      expect(vertical.offset, closeTo(beforeReverse - 80, 0.1));
    },
  );

  testWidgets('live Reduce Motion settles wheel motion after row recycling', (
    t,
  ) async {
    await t.pumpWidget(mount());
    await wheel(t, const Offset(0, 1200));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(vertical.offset, inExclusiveRange(0, 1200));
    await t.pumpWidget(mount(reduced: true));
    final settled = vertical.offset;
    expect(settled, closeTo(1200, 0.1));
    await t.pump(const Duration(milliseconds: 300));
    expect(vertical.offset, settled);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('horizontal wheel and Shift+wheel stay horizontal', (t) async {
    await t.pumpWidget(mount());
    await wheel(t, const Offset(100, 0));
    expect(horizontal.offset, 0);
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    expect(horizontal.offset, inExclusiveRange(0, 100));
    await t.pumpAndSettle();
    expect(horizontal.offset, closeTo(100, 0.1));
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await wheel(t, const Offset(0, 120));
    await t.pumpAndSettle();
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(horizontal.offset, closeTo(220, 0.1));
    expect(vertical.offset, 0);
    expect(outer.offset, 0);
    await wheel(t, const Offset(-80, 0));
    await t.pumpAndSettle();
    expect(horizontal.offset, closeTo(140, 0.1));
  });

  testWidgets(
    'table boundary transfers wheel to page with no duplicate scrolling',
    (t) async {
      await t.pumpWidget(mount());
      vertical.jumpTo(vertical.position.maxScrollExtent);
      await t.pumpAndSettle();
      await wheel(t, const Offset(0, 100));
      await t.pumpAndSettle();
      expect(outer.offset, closeTo(100, 0.1));
      expect(vertical.offset, vertical.position.maxScrollExtent);
      await wheel(t, const Offset(0, -90));
      await t.pumpAndSettle();
      expect(
        vertical.offset,
        closeTo(vertical.position.maxScrollExtent - 90, 0.1),
      );
      expect(outer.offset, closeTo(100, 0.1));
    },
  );

  testWidgets(
    'reduced motion and trackpad signals retain immediate native behavior',
    (t) async {
      await t.pumpWidget(mount(reduced: true));
      await wheel(t, const Offset(0, 100));
      expect(vertical.offset, closeTo(100, 0.1));
      await t.pumpWidget(mount());
      await wheel(t, const Offset(0, 30), kind: PointerDeviceKind.trackpad);
      expect(vertical.offset, closeTo(130, 0.1));
    },
  );

  testWidgets(
    'programmatic jump cancels pending wheel distance; disposal is safe',
    (t) async {
      await t.pumpWidget(mount());
      await wheel(t, const Offset(0, 150));
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      vertical.jumpTo(400);
      await t.pump();
      await wheel(t, const Offset(0, 40));
      await t.pumpAndSettle();
      expect(vertical.offset, closeTo(440, 0.1));
      await wheel(t, const Offset(0, 100));
      await t.pump();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('real virtualized page smooths wheel over body and side margin', (
    t,
  ) async {
    final editor = EditorState(
      document: Document(
        root: pageNode(
          children: [
            for (var i = 0; i < 100; i++)
              paragraphNode(text: 'Document line $i'),
          ],
        ),
      ),
    );
    final scroll = EditorScrollController(editorState: editor);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: editor,
            editorScrollController: scroll,
            editorStyle: EditorStyle.desktop(maxWidth: 400),
            blockComponentBuilders: {
              ...standardBlockComponentBuilderMap,
              PageBlockKeys.type: SmoothPageBlockComponentBuilder(),
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final region = find.byType(SmoothWheelRegion).first;
    expect(t.getSize(region).width, 800);
    final y = t.getCenter(region).dy;
    final pagePosition = Scrollable.of(t.element(region)).position;
    final initial = pagePosition.pixels;
    await wheel(t, const Offset(0, 100), at: Offset(780, y));
    expect(pagePosition.pixels, initial);
    await t.pump();
    await t.pump(const Duration(milliseconds: 35));
    expect(pagePosition.pixels, inExclusiveRange(initial, initial + 100));
    await wheel(t, const Offset(0, 80), at: const Offset(400, 80));
    await t.pumpAndSettle();
    expect(pagePosition.pixels, closeTo(initial + 180, 0.1));
    // A pending wheel animation is disposed together with its live page.
    await wheel(t, const Offset(0, 80), at: const Offset(400, 80));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    scroll.dispose();
    editor.dispose();
    expect(t.takeException(), isNull);
  });
}

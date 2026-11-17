import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/app_scroll_behavior.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  test('macos scrollbar theme: configured with native macOS pill styling', () {
    final lightTheme = buildTheme(Brightness.light);
    final darkTheme = buildTheme(Brightness.dark);

    final lightScrollbar = lightTheme.scrollbarTheme;
    final darkScrollbar = darkTheme.scrollbarTheme;

    // 1. Not permanently visible by default (idle)
    expect(lightScrollbar.thumbVisibility?.resolve({}), isFalse);
    expect(darkScrollbar.thumbVisibility?.resolve({}), isFalse);

    // 2. Visible when hovered or dragged
    expect(lightScrollbar.thumbVisibility?.resolve({WidgetState.hovered}), isTrue);
    expect(lightScrollbar.thumbVisibility?.resolve({WidgetState.dragged}), isTrue);
    expect(darkScrollbar.thumbVisibility?.resolve({WidgetState.hovered}), isTrue);
    expect(darkScrollbar.thumbVisibility?.resolve({WidgetState.dragged}), isTrue);

    // 3. Thickness: 5.0 idle, expands to 9.0 on hover or drag
    expect(lightScrollbar.thickness?.resolve({}), 5.0);
    expect(lightScrollbar.thickness?.resolve({WidgetState.hovered}), 9.0);
    expect(lightScrollbar.thickness?.resolve({WidgetState.dragged}), 9.0);

    expect(darkScrollbar.thickness?.resolve({}), 5.0);
    expect(darkScrollbar.thickness?.resolve({WidgetState.hovered}), 9.0);
    expect(darkScrollbar.thickness?.resolve({WidgetState.dragged}), 9.0);

    // 4. Fully rounded pill radius
    expect(lightScrollbar.radius, const Radius.circular(10.0));
    expect(darkScrollbar.radius, const Radius.circular(10.0));

    // 5. Track is invisible (no layout shift)
    expect(lightScrollbar.trackVisibility?.resolve({}), isFalse);
    expect(darkScrollbar.trackVisibility?.resolve({}), isFalse);

    // 6. Floating margin & minimum thumb length
    expect(lightScrollbar.crossAxisMargin, 2.5);
    expect(darkScrollbar.crossAxisMargin, 2.5);
    expect(lightScrollbar.mainAxisMargin, 4.0);
    expect(darkScrollbar.mainAxisMargin, 4.0);
    expect(lightScrollbar.minThumbLength, 36.0);
    expect(darkScrollbar.minThumbLength, 36.0);

    // 7. Interactive
    expect(lightScrollbar.interactive, isTrue);
    expect(darkScrollbar.interactive, isTrue);

    // 8. Thumb color darkens on hover and drag
    final lightIdle = lightScrollbar.thumbColor?.resolve({});
    final lightHover = lightScrollbar.thumbColor?.resolve({WidgetState.hovered});
    final lightDrag = lightScrollbar.thumbColor?.resolve({WidgetState.dragged});

    expect(lightIdle, isNotNull);
    expect(lightHover, isNotNull);
    expect(lightDrag, isNotNull);
    expect(lightDrag!.a, greaterThan(lightHover!.a));
    expect(lightHover.a, greaterThan(lightIdle!.a));

    final darkIdle = darkScrollbar.thumbColor?.resolve({});
    final darkHover = darkScrollbar.thumbColor?.resolve({WidgetState.hovered});
    final darkDrag = darkScrollbar.thumbColor?.resolve({WidgetState.dragged});

    expect(darkIdle, isNotNull);
    expect(darkHover, isNotNull);
    expect(darkDrag, isNotNull);
    expect(darkDrag!.a, greaterThan(darkHover!.a));
    expect(darkHover.a, greaterThan(darkIdle!.a));
  });

  testWidgets('macos scrollbar: AppScrollBehavior builds interactive Scrollbar for vertical lists', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemBuilder: (_, index) => SizedBox(height: 50, child: Text('Item $index')),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsOneWidget);
  });
}

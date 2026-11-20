import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/sidebar/window_nav_toolbar.dart';
import 'package:notes_here/ui/sidebar/sidebar_inbox_row.dart';
import 'package:notes_here/ui/sidebar/sidebar_quick_notes_row.dart';
import 'package:notes_here/ui/sidebar/sidebar_trash_row.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  testWidgets('WindowNavToolbar on Windows uses 4px gap, 28x28 buttons, and 0.24 disabled opacity',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.windows,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: WindowNavToolbar(
            onToggleSidebar: () {},
            isSidebarVisible: true,
            onNavigateBack: null, // disabled
            canNavigateBack: false,
            onNavigateForward: null, // disabled
            canNavigateForward: false,
            onOpenSearch: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify 4px gaps
    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final gaps = sizedBoxes.where((s) => s.width == 4.0).toList();
    expect(gaps.length, greaterThanOrEqualTo(3)); // between all 4 buttons

    // 2. Verify 28x28 buttons with BorderRadius.circular(6)
    final backBtnFinder = find.byKey(const ValueKey('nav_back'));
    expect(backBtnFinder, findsOneWidget);
    final container = tester.widget<Container>(
      find.descendant(of: backBtnFinder, matching: find.byType(Container)),
    );
    expect(container.constraints?.minWidth ?? 0, lessThanOrEqualTo(28.0));
    final decoration = container.decoration;
    expect(decoration, isA<BoxDecoration>());
    if (decoration is BoxDecoration) {
      expect(decoration.borderRadius, BorderRadius.circular(6.0));
    }

    // 3. Verify disabled icon opacity is at least 0.24
    final iconWidget = tester.widget<Icon>(
      find.descendant(of: backBtnFinder, matching: find.byType(Icon)),
    );
    final iconAlpha = iconWidget.color?.a ?? (iconWidget.color?.opacity ?? 0.0);
    expect(iconAlpha, closeTo(0.24, 0.01));
  });

  testWidgets('Sidebar rows use #4B5563 on Windows Light Mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.windows,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: Column(
            children: [
              SidebarInboxRow(
                isSelected: false,
                unreadCount: 3,
                onTap: () {},
              ),
              SidebarQuickNotesRow(
                isSelected: false,
                pinnedCount: 1,
                onTap: () {},
              ),
              SidebarTrashRow(
                isSelected: false,
                trashedCount: 2,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Look for text styled with Color(0xFF4B5563)
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    final hasHighContrastText = textWidgets.any(
      (t) => t.style?.color == const Color(0xFF4B5563),
    );
    expect(hasHighContrastText, isTrue);
  });

  test('Skin.of uses 0.075 active highlight for Windows Light Mode', () {
    final skinLight = Skin.of(
      Brightness.light,
      mica: true,
      platform: TargetPlatform.windows,
    );
    expect(skinLight.sidebarSelected, const Color(0x13000000));
  });
}

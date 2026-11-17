import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:notes_here/ui/sidebar/sidebar_quick_notes_row.dart';

void main() {
  test('UiType.tabular provides tabularFigures font feature', () {
    expect(UiType.tabular, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('SidebarQuickNotesRow pinned count badge applies UiType.tabular', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SidebarQuickNotesRow(
            isSelected: false,
            pinnedCount: 5,
            onTap: () {},
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('5'));
    expect(textWidget.style?.fontFeatures, UiType.tabular);
  });
}

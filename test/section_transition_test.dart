import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/section_transition.dart';

void main() {
  testWidgets('SectionItem applies staggered intervals and animates child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionContent(
            child: Column(
              children: const [
                SectionItem(index: 0, child: Text('Item 0')),
                SectionItem(index: 1, child: Text('Item 1')),
                SectionItem(index: 2, child: Text('Item 2')),
              ],
            ),
          ),
        ),
      ),
    );

    // Initial frame at t=0
    await tester.pump();
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);

    // Check fade transitions
    final fades = tester.widgetList<FadeTransition>(find.byType(FadeTransition)).toList();
    expect(fades.length, greaterThanOrEqualTo(3));

    // Fast-forward animation to completion
    await tester.pumpAndSettle();

    // Verify all items reached opacity 1.0
    for (final fade in tester.widgetList<FadeTransition>(find.byType(FadeTransition))) {
      expect(fade.opacity.value, 1.0);
    }
  });

  testWidgets('SectionItem bypasses animation when Reduce Motion is active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SectionContent(
              child: const SectionItem(index: 0, child: Text('Instant Item')),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Instant Item'), findsOneWidget);
    // When animations are disabled, SectionItem immediately returns child without wrapping in FadeTransition
    expect(
      find.descendant(
        of: find.byType(SectionItem),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('SectionTransition forwards animation on section switch', (tester) async {
    var currentSection = 'sectionA';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SectionTransition(
                section: currentSection,
                child: SectionItem(
                  index: 0,
                  child: Text('Content $currentSection'),
                ),
              ),
              floatingActionButton: TextButton(
                onPressed: () => setState(() => currentSection = 'sectionB'),
                child: const Text('Switch'),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Content sectionA'), findsOneWidget);

    // Tap switch
    await tester.tap(find.text('Switch'));
    await tester.pump();

    expect(find.text('Content sectionB'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Content sectionB'), findsOneWidget);
  });
}

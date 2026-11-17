import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/context_menu.dart';
import 'package:notes_here/ui/common/grow_in.dart';
import 'package:notes_here/ui/common/popover.dart';

void main() {
  testWidgets('showPopover smartly anchors to topLeft for left-side anchors', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              host = ctx;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    // Left-side anchor
    showPopover(
      host,
      anchor: const Rect.fromLTWH(20, 50, 40, 30),
      builder: (_, close) => const Text('Left Popover Content'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Left Popover Content'), findsOneWidget);
    final growIn = tester.widget<GrowIn>(find.byType(GrowIn));
    expect(growIn.alignment, Alignment.topLeft);
  });

  testWidgets('showPopover smartly anchors to topRight for right-side anchors', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              host = ctx;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    // Right-side anchor (e.g. at x=700 on an 800-wide screen)
    showPopover(
      host,
      anchor: const Rect.fromLTWH(700, 50, 40, 30),
      builder: (_, close) => const Text('Right Popover Content'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Right Popover Content'), findsOneWidget);
    final growIn = tester.widget<GrowIn>(find.byType(GrowIn));
    expect(growIn.alignment, Alignment.topRight);
  });

  testWidgets('showContextMenu displays items and fires callback', (tester) async {
    var actionFired = false;
    late BuildContext host;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              host = ctx;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    showContextMenu(
      host,
      const Offset(100, 100),
      [
        MenuEntry(
          Icons.star,
          'Test Action',
          () => actionFired = true,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Action'), findsOneWidget);
    await tester.tap(find.text('Test Action'));
    await tester.pumpAndSettle();

    expect(actionFired, isTrue);
    expect(find.text('Test Action'), findsNothing);
  });
}

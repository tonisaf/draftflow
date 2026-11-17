import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/grow_in.dart';
import 'package:notes_here/ui/common/app_dialog.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  testWidgets('live Reduce Motion finishes dialog and barrier transitions', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late BuildContext host;
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    var completed = false;
    showAppDialog<void>(
      context: host,
      builder: (context) {
        dialogContext = context;
        return const Dialog(child: Text('dialog'));
      },
    ).then((_) => completed = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final route = ModalRoute.of(dialogContext)!;
    expect(route.animation!.value, inExclusiveRange(0, 1));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    await tester.pump();
    expect(route.animation!.value, 1);
    Navigator.pop(dialogContext);
    await tester.pump();
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('dialog'), findsNothing);
  });

  Widget grow({
    bool open = true,
    bool reduced = false,
    VoidCallback? onClosed,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: GrowIn(
        alignment: Alignment.topLeft,
        distance: 8,
        open: open,
        onClosed: onClosed,
        child: const SizedBox(width: 100, height: 50),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(GrowIn),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('GrowIn snaps on open, close and live reduced-motion changes', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(grow(reduced: true));
    expect(opacity(tester), 1);
    expect(
      find.descendant(
        of: find.byType(GrowIn),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    await tester.pumpWidget(
      grow(open: false, reduced: true, onClosed: () => closed++),
    );
    expect(opacity(tester), 0);
    expect(closed, 1);
    await tester.pump(Motion.panel);
    expect(opacity(tester), 0);
    expect(closed, 1);

    await tester.pumpWidget(grow());
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpWidget(grow(reduced: true));
    expect(opacity(tester), 1);
    await tester.pump(Motion.panel);
    expect(opacity(tester), 1);
  });

  testWidgets('reversing a close does not deliver a stale completion', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(grow(onClosed: () => closed++));
    await tester.pumpAndSettle();
    await tester.pumpWidget(grow(open: false, onClosed: () => closed++));
    await tester.pump(const Duration(milliseconds: 50));
    final closingOpacity = opacity(tester);
    await tester.pumpWidget(grow(onClosed: () => closed++));
    expect(opacity(tester), closingOpacity);
    await tester.pumpAndSettle();
    expect(closed, 0);
    await tester.pumpWidget(grow(open: false, onClosed: () => closed++));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('popover stays mounted until the closing animation completes', (
    tester,
  ) async {
    late BuildContext host;
    late VoidCallback close;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    var completed = false;
    showPopover(
      host,
      anchor: const Rect.fromLTWH(100, 100, 20, 20),
      builder: (_, dismiss) {
        close = dismiss;
        return const Text('popup');
      },
    ).then((_) => completed = true);
    await tester.pumpAndSettle();
    close();
    close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('popup'), findsOneWidget);
    expect(completed, isFalse);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('popup'), findsNothing);
  });

  testWidgets('live Reduce Motion finishes a closing popover immediately', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late BuildContext host;
    late VoidCallback close;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    var completed = false;
    showPopover(
      host,
      anchor: const Rect.fromLTWH(100, 100, 20, 20),
      builder: (_, dismiss) {
        close = dismiss;
        return const Text('popup');
      },
    ).then((_) => completed = true);
    await tester.pumpAndSettle();
    close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('popup'), findsNothing);
  });

  testWidgets('reduced dialog route has zero duration and the Skin scrim', (
    tester,
  ) async {
    late BuildContext host;
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    showAppDialog<void>(
      context: host,
      barrierColor: host.skin.scrim,
      animationStyle: Motion.dialogStyle(host),
      builder: (context) {
        dialogContext = context;
        return const Dialog(child: Text('dialog'));
      },
    );
    await tester.pump();
    final route = ModalRoute.of(dialogContext)!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(route.barrierColor, host.skin.scrim);
    Navigator.pop(dialogContext);
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
  });
}

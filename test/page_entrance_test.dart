import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/page_entrance.dart';

void main() {
  Widget app(String id, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: PageEntrance(key: ValueKey(id), child: Text(id)),
    ),
  );
  double opacity(WidgetTester t) => t
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(PageEntrance),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;
  double shift(WidgetTester t) => t
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(PageEntrance),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .storage[13];

  testWidgets('only the incoming page fades and springs into place', (
    t,
  ) async {
    await t.pumpWidget(app('alpha'));
    await t.pumpAndSettle();
    await t.pumpWidget(app('beta'));
    expect(find.text('alpha'), findsNothing);
    expect(find.text('beta'), findsOneWidget);
    expect(opacity(t), 0);
    expect(shift(t), 8);
    await t.pump(const Duration(milliseconds: 50));
    expect(opacity(t), inExclusiveRange(0, 1));
    expect(shift(t), inExclusiveRange(0, 8));
    await t.pumpWidget(app('gamma'));
    expect(find.text('beta'), findsNothing);
    expect(find.byType(PageEntrance), findsOneWidget);
    expect(opacity(t), 0);
    await t.pumpAndSettle();
    expect(opacity(t), 1);
    expect(shift(t), 0);
    await t.pumpWidget(app('gamma'));
    expect(opacity(t), 1);
  });

  testWidgets(
    'Reduce Motion settles the page immediately and does not replay',
    (t) async {
      await t.pumpWidget(app('alpha', reduced: true));
      expect(opacity(t), 1);
      expect(shift(t), 0);
      await t.pumpWidget(app('beta'));
      await t.pump(const Duration(milliseconds: 50));
      expect(opacity(t), inExclusiveRange(0, 1));
      await t.pumpWidget(app('beta', reduced: true));
      expect(opacity(t), 1);
      expect(shift(t), 0);
      await t.pumpWidget(app('beta'));
      expect(opacity(t), 1);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
}

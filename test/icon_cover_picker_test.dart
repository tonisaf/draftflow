import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/cover_picker_dialog.dart';
import 'package:notes_here/ui/common/emoji_picker_dialog.dart';
import 'package:notes_here/ui/editor/cover_presets.dart';

void main() {
  test('Cover presets decode correctly', () {
    final sunset = getCoverDecoration('gradient:sunset');
    expect(sunset, isNotNull);
    expect(sunset!.gradient, isNotNull);

    final blue = getCoverDecoration('color:blue');
    expect(blue, isNotNull);
    expect(blue!.color, const Color(0xFF1A73E8));

    final hex = getCoverDecoration('color:#FF0000');
    expect(hex, isNotNull);
    expect(hex!.color, const Color(0xFFFF0000));

    expect(getCoverDecoration(null), isNull);
    expect(getCoverDecoration(''), isNull);
  });

  testWidgets('Emoji picker dialog shows categories and allows selection', (tester) async {
    String? selectedEmoji;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedEmoji = await showEmojiPickerDialog(context, currentEmoji: '💡');
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );

    // Open picker
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Эмодзи'), findsOneWidget);

    // Select emoji '🚀'
    final rocketFinder = find.text('🚀');
    expect(rocketFinder, findsOneWidget);
    await tester.tap(rocketFinder);
    await tester.pumpAndSettle();

    expect(selectedEmoji, '🚀');
  });

  testWidgets('Cover picker dialog shows presets and selects one', (tester) async {
    String? selectedCover;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedCover = await showCoverPickerDialog(context, currentCover: 'gradient:sunset');
              },
              child: const Text('Open Cover Picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Cover Picker'));
    await tester.pumpAndSettle();

    expect(find.text('Page Cover'), findsOneWidget);
    expect(find.text('Gradients'), findsOneWidget);
    expect(find.text('Solid Colors'), findsOneWidget);

    // Tap on the first preset card inside GridView
    final presetCard = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(presetCard);
    await tester.pumpAndSettle();

    expect(selectedCover, isNotNull);
  });
}

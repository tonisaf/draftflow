import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/editor_link_popover.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestPopover({
    String? initialUrl,
    VoidCallback? onClose,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onOpenLink,
    ValueChanged<String>? onCopyLink,
    VoidCallback? onRemoveLink,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(
          child: Container(
            width: 290,
            padding: const EdgeInsets.all(8.0),
            child: EditorLinkPopover(
              initialUrl: initialUrl,
              onClose: onClose ?? () {},
              onSubmitted: onSubmitted ?? (_) {},
              onOpenLink: onOpenLink ?? (_) {},
              onCopyLink: onCopyLink ?? (_) {},
              onRemoveLink: onRemoveLink ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  group('EditorLinkPopover', () {
    testWidgets('renders "Ссылка" and actions when initialUrl is provided',
        (tester) async {
      await tester.pumpWidget(
        buildTestPopover(initialUrl: 'https://example.com'),
      );
      await tester.pumpAndSettle();

      // Header label
      expect(find.text('Ссылка'), findsOneWidget);
      expect(find.text('Добавить ссылку'), findsNothing);

      // Text field has initial URL
      expect(find.text('https://example.com'), findsOneWidget);

      // Actions
      expect(find.text('Открыть ссылку'), findsOneWidget);
      expect(find.text('Копировать ссылку'), findsOneWidget);
      expect(find.text('Удалить ссылку'), findsOneWidget);

      // Clear button is visible
      expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsOneWidget);
    });

    testWidgets('renders "Добавить ссылку" and no actions when initialUrl is null',
        (tester) async {
      await tester.pumpWidget(
        buildTestPopover(initialUrl: null),
      );
      await tester.pumpAndSettle();

      // Header label
      expect(find.text('Добавить ссылку'), findsOneWidget);
      expect(find.text('Ссылка'), findsNothing);

      // No action rows
      expect(find.text('Открыть ссылку'), findsNothing);
      expect(find.text('Копировать ссылку'), findsNothing);
      expect(find.text('Удалить ссылку'), findsNothing);

      // Clear button is not visible when text is empty
      expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsNothing);
    });

    testWidgets('clears text when clear button is tapped', (tester) async {
      await tester.pumpWidget(
        buildTestPopover(initialUrl: 'https://github.com'),
      );
      await tester.pumpAndSettle();

      expect(find.text('https://github.com'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
      await tester.pumpAndSettle();

      expect(find.text('https://github.com'), findsNothing);
      expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsNothing);
    });

    testWidgets('submits on text field Enter', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        buildTestPopover(
          initialUrl: null,
          onSubmitted: (url) => submitted = url,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('editor_link_input')),
        'https://draftflow.app',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, 'https://draftflow.app');
    });

    testWidgets('calls onOpenLink when "Открыть ссылку" is tapped',
        (tester) async {
      String? opened;
      await tester.pumpWidget(
        buildTestPopover(
          initialUrl: 'https://flutter.dev',
          onOpenLink: (url) => opened = url,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editor_link_open_action')));
      await tester.pumpAndSettle();

      expect(opened, 'https://flutter.dev');
    });

    testWidgets(
        'copies to clipboard, switches to "Скопировано", and triggers close',
        (tester) async {
      String? copied;
      bool closed = false;

      await tester.pumpWidget(
        buildTestPopover(
          initialUrl: 'https://linear.app',
          onCopyLink: (url) => copied = url,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Копировать ссылку'), findsOneWidget);
      expect(find.text('Скопировано'), findsNothing);

      await tester.tap(find.byKey(const Key('editor_link_copy_action')));
      await tester.pump();

      // Immediately shows "Скопировано" with green checkmark
      expect(find.text('Скопировано'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
      expect(copied, 'https://linear.app');

      // Fast forward past the 900ms micro-interaction timer
      await tester.pump(const Duration(milliseconds: 950));
      expect(closed, isTrue);
    });

    testWidgets('calls onRemoveLink when "Удалить ссылку" is tapped',
        (tester) async {
      bool removed = false;
      await tester.pumpWidget(
        buildTestPopover(
          initialUrl: 'https://apple.com',
          onRemoveLink: () => removed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editor_link_remove_action')));
      await tester.pumpAndSettle();

      expect(removed, isTrue);
    });

    testWidgets('formatLinkUrl prepends https:// when scheme is absent',
        (tester) async {
      expect(formatLinkUrl('dtf.ru'), 'https://dtf.ru');
      expect(formatLinkUrl('https://dtf.ru'), 'https://dtf.ru');
      expect(formatLinkUrl('http://dtf.ru'), 'http://dtf.ru');
      expect(formatLinkUrl('page://abc-123'), 'page://abc-123');
      expect(formatLinkUrl('mailto:test@example.com'), 'mailto:test@example.com');
      expect(formatLinkUrl('   '), '');
    });
  });
}

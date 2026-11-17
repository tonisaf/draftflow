import 'dart:convert';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/page_settings.dart';
import 'package:notes_here/l10n/app_localizations.dart';
import 'package:notes_here/ui/common/app_icons.dart';
import 'package:notes_here/ui/quick_notes/quick_note_card.dart';
import 'package:notes_here/ui/quick_notes/quick_note_models.dart';
import 'package:notes_here/ui/sidebar/sidebar_quick_notes_row.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  group('PageSettings isPinned & cardColor', () {
    test('serializes and deserializes isPinned and cardColor correctly', () {
      const settings = PageSettings(
        isPinned: true,
        cardColor: 'amber',
        fullWidth: true,
      );

      final json = jsonEncode({
        pageSettingsKey: {
          'isPinned': settings.isPinned,
          'cardColor': settings.cardColor,
          'fullWidth': settings.fullWidth,
        },
      });

      final parsed = pageSettingsFromProperties(json);
      expect(parsed.isPinned, isTrue);
      expect(parsed.cardColor, equals('amber'));
      expect(parsed.fullWidth, isTrue);
    });

    test('defaults to false for isPinned when omitted', () {
      final parsed = pageSettingsFromProperties('{}');
      expect(parsed.isPinned, isFalse);
      expect(parsed.cardColor, isNull);
    });
  });

  group('QuickNoteCardData snippet extraction', () {
    test('extracts code block and todo items from block content', () {
      final page = Page(
        id: 'p-1',
        title: 'DevOps Script',
        createdAt: DateTime.now(),
      );

      final blocks = [
        Block(
          id: 'b-1',
          pageId: 'p-1',
          type: 'code',
          content: jsonEncode({
            'type': 'code',
            'data': {
              'delta': [
                {'insert': 'DATE=\$(date +%d%m%Y)\nsystemctl stop wildfly'}
              ],
              'language': 'bash',
            },
          }),
          orderKey: 'a0',
        ),
        Block(
          id: 'b-2',
          pageId: 'p-1',
          type: 'todo_list',
          content: jsonEncode({
            'type': 'todo_list',
            'data': {
              'delta': [
                {'insert': 'Check service status'}
              ],
              'checked': true,
            },
          }),
          orderKey: 'a1',
        ),
      ];

      final cardData = QuickNoteCardData.fromPageAndBlocks(page, blocks);
      expect(cardData.codeSnippet, contains('systemctl stop wildfly'));
      expect(cardData.codeLanguage, equals('BASH'));
      expect(cardData.todoItems.length, equals(1));
      expect(cardData.todoItems.first.text, equals('Check service status'));
      expect(cardData.todoItems.first.isChecked, isTrue);
    });

    test('extracts bulleted and numbered lists, and tags', () {
      final page = Page(
        id: 'p-2',
        title: 'Project Roadmap #Release',
        createdAt: DateTime.now(),
      );

      final blocks = [
        Block(
          id: 'b-3',
          pageId: 'p-2',
          type: 'bulleted_list',
          content: jsonEncode({
            'type': 'bulleted_list',
            'data': {
              'delta': [
                {'insert': 'Design mockups #UI'}
              ],
            },
          }),
          orderKey: 'a0',
        ),
        Block(
          id: 'b-4',
          pageId: 'p-2',
          type: 'numbered_list',
          content: jsonEncode({
            'type': 'numbered_list',
            'data': {
              'delta': [
                {'insert': 'Implement backend'}
              ],
            },
          }),
          orderKey: 'a1',
        ),
      ];

      final cardData = QuickNoteCardData.fromPageAndBlocks(page, blocks);
      expect(cardData.listItems.length, equals(2));
      expect(cardData.listItems.first.isNumbered, isFalse);
      expect(cardData.listItems.first.text, equals('Design mockups #UI'));
      expect(cardData.listItems[1].isNumbered, isTrue);
      expect(cardData.listItems[1].number, equals(1));
      expect(cardData.hasTag('Release'), isTrue);
      expect(cardData.hasTag('#UI'), isTrue);
      expect(cardData.hasTag('NonExistent'), isFalse);
    });
  });

  group('SidebarQuickNotesRow Widget', () {
    testWidgets('renders title and pinned badge and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: SidebarQuickNotesRow(
              isSelected: false,
              pinnedCount: 3,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byType(SidebarQuickNotesRow));
      expect(tapped, isTrue);
    });
  });

  group('QuickNoteCard Widget', () {
    testWidgets('displays title, code block, and triggers open & pin', (tester) async {
      bool opened = false;
      bool pinToggled = false;

      final cardData = QuickNoteCardData(
        page: Page(
          id: 'card-1',
          title: 'Steam FPS Presets',
          createdAt: DateTime.now(),
        ),
        settings: const PageSettings(isPinned: true),
        codeSnippet: 'Balatro: 1536x960 50fps',
        codeLanguage: 'CONFIG',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: QuickNoteCard(
              cardData: cardData,
              onOpenPage: (_) => opened = true,
              onTogglePin: () => pinToggled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Steam FPS Presets'), findsOneWidget);
      expect(find.text('Balatro: 1536x960 50fps'), findsOneWidget);
      expect(find.text('⚡ CONFIG'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.pinFill));
      expect(pinToggled, isTrue);

      await tester.tap(find.byType(QuickNoteCard));
      expect(opened, isTrue);
    });

    testWidgets('displays list items, tags, and triggers onTagTap', (tester) async {
      String? tappedTag;

      final cardData = QuickNoteCardData(
        page: Page(
          id: 'card-2',
          title: 'Shopping List',
          createdAt: DateTime.now(),
        ),
        settings: const PageSettings(),
        listItems: const [
          QuickListItem(text: 'Milk & Bread', isNumbered: false),
          QuickListItem(text: 'Coffee Beans', isNumbered: true, number: 1),
        ],
        extractedTags: const ['#Groceries', '#Weekend'],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: QuickNoteCard(
              cardData: cardData,
              onOpenPage: (_) {},
              onTogglePin: () {},
              onTagTap: (tag) => tappedTag = tag,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Shopping List'), findsOneWidget);
      expect(find.text('Milk & Bread'), findsOneWidget);
      expect(find.text('Coffee Beans'), findsOneWidget);
      expect(find.text('#Groceries'), findsOneWidget);

      await tester.tap(find.text('#Groceries'));
      expect(tappedTag, equals('#Groceries'));
    });
  });
}

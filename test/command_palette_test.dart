import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/quick_search_dialog.dart';

void main() {
  group('Command Palette (Phase 3)', () {
    test('appCommands has all core system actions with shortcuts', () {
      expect(appCommands.length, greaterThanOrEqualTo(8));
      
      final commands = appCommands.map((c) => c.command).toSet();
      expect(commands.contains(QuickCommand.newRootPage), isTrue);
      expect(commands.contains(QuickCommand.newQuickNote), isTrue);
      expect(commands.contains(QuickCommand.toggleSidebar), isTrue);
      expect(commands.contains(QuickCommand.openQuickNotes), isTrue);
      expect(commands.contains(QuickCommand.openTrash), isTrue);
      expect(commands.contains(QuickCommand.openBackup), isTrue);
      expect(commands.contains(QuickCommand.toggleTheme), isTrue);
      expect(commands.contains(QuickCommand.toggleLanguage), isTrue);

      final newPageCmd = appCommands.firstWhere((c) => c.command == QuickCommand.newRootPage);
      expect(newPageCmd.shortcut, '⌘N');

      final sidebarCmd = appCommands.firstWhere((c) => c.command == QuickCommand.toggleSidebar);
      expect(sidebarCmd.shortcut, '⌘\\');
    });

    test('matches commands by keyword and title', () {
      bool matches(CommandDefinition cmd, String q) {
        final query = q.toLowerCase();
        return cmd.title.toLowerCase().contains(query) ||
            cmd.subtitle.toLowerCase().contains(query) ||
            cmd.keywords.any((k) => k.toLowerCase().contains(query));
      }

      // 'тема'
      final themeMatches = appCommands.where((c) => matches(c, 'тема')).toList();
      expect(themeMatches.any((c) => c.command == QuickCommand.toggleTheme), isTrue);

      // 'бэкап'
      final backupMatches = appCommands.where((c) => matches(c, 'бэкап')).toList();
      expect(backupMatches.any((c) => c.command == QuickCommand.openBackup), isTrue);

      // 'корзина'
      final trashMatches = appCommands.where((c) => matches(c, 'корзина')).toList();
      expect(trashMatches.any((c) => c.command == QuickCommand.openTrash), isTrue);

      // 'сайдбар'
      final sidebarMatches = appCommands.where((c) => matches(c, 'сайдбар')).toList();
      expect(sidebarMatches.any((c) => c.command == QuickCommand.toggleSidebar), isTrue);
    });

    test('ExecuteCommandResult holds QuickCommand enum', () {
      const res = ExecuteCommandResult(QuickCommand.toggleTheme);
      expect(res.command, QuickCommand.toggleTheme);
    });
  });
}

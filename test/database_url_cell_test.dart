import 'package:notes_here/ui/common/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/l10n/app_localizations.dart';
import 'package:notes_here/ui/editor/components/database/database_url_cell.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  group('UrlCellInput unit tests', () {
    test('formatUrlForDisplay strips http://, https://, and mailto:', () {
      expect(
        UrlCellInput.formatUrlForDisplay('https://jira.example.com:8443/browse/PROJECT-101'),
        'jira.example.com:8443/browse/PROJECT-101',
      );
      expect(
        UrlCellInput.formatUrlForDisplay('http://example.com/docs'),
        'example.com/docs',
      );
      expect(
        UrlCellInput.formatUrlForDisplay('mailto:support@example.com'),
        'support@example.com',
      );
      expect(
        UrlCellInput.formatUrlForDisplay('google.com'),
        'google.com',
      );
      expect(
        UrlCellInput.formatUrlForDisplay('   '),
        '',
      );
    });

    test('normalizeUrl prepends https:// when missing', () {
      expect(
        UrlCellInput.normalizeUrl('jira.example.com:8443'),
        'https://jira.example.com:8443',
      );
      expect(
        UrlCellInput.normalizeUrl('http://insecure.site'),
        'http://insecure.site',
      );
    });
  });

  group('UrlCellInput widget tests', () {
    testWidgets('renders clean link without https:// or link icon, launches on click, edits on double-click', (tester) async {
      String? launchedUrl;
      String? updatedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: UrlCellInput(
                  initialValue: 'https://jira.example.com:8443/browse/PROJECT-101',
                  onChanged: (val) => updatedValue = val,
                  onOpenUrl: (url) => launchedUrl = url,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clean display without protocol
      expect(find.text('jira.example.com:8443/browse/PROJECT-101'), findsOneWidget);
      expect(find.text('https://jira.example.com:8443/browse/PROJECT-101'), findsNothing);

      // Single click launches browser
      await tester.tap(find.text('jira.example.com:8443/browse/PROJECT-101'));
      await tester.pumpAndSettle();
      expect(launchedUrl, 'https://jira.example.com:8443/browse/PROJECT-101');

      // Wait past double-tap window
      await tester.pump(const Duration(milliseconds: 400));

      // Quick second tap within 300ms enters edit mode
      await tester.tap(find.text('jira.example.com:8443/browse/PROJECT-101'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('jira.example.com:8443/browse/PROJECT-101'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'https://google.com');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(updatedValue, 'https://google.com');
      expect(find.text('google.com'), findsOneWidget);
    });

    testWidgets('shows Add URL when empty and cell is hovered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: UrlCellInput(
                  initialValue: '',
                  isCellHovered: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Добавить URL'), findsOneWidget);
      expect(find.byIcon(AppIcons.link), findsOneWidget);
    });
  });
}

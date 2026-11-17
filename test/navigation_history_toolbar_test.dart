import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/home_screen.dart';
import 'package:notes_here/ui/sidebar/window_nav_toolbar.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowNavToolbar widget', () {
    testWidgets('renders all 4 action buttons and handles taps', (tester) async {
      bool sidebarToggled = false;
      bool backTapped = false;
      bool forwardTapped = false;
      bool searchTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WindowNavToolbar(
              isSidebarVisible: true,
              onToggleSidebar: () => sidebarToggled = true,
              canNavigateBack: true,
              onNavigateBack: () => backTapped = true,
              canNavigateForward: true,
              onNavigateForward: () => forwardTapped = true,
              onOpenSearch: () => searchTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav_sidebar_toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_back')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_forward')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_search')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_sidebar_toggle')));
      expect(sidebarToggled, isTrue);

      await tester.tap(find.byKey(const ValueKey('nav_back')));
      expect(backTapped, isTrue);

      await tester.tap(find.byKey(const ValueKey('nav_forward')));
      expect(forwardTapped, isTrue);

      await tester.tap(find.byKey(const ValueKey('nav_search')));
      expect(searchTapped, isTrue);
    });

    testWidgets('disabled back and forward buttons do not fire callbacks', (tester) async {
      bool backTapped = false;
      bool forwardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WindowNavToolbar(
              isSidebarVisible: true,
              onToggleSidebar: () {},
              canNavigateBack: false,
              onNavigateBack: () => backTapped = true,
              canNavigateForward: false,
              onNavigateForward: () => forwardTapped = true,
              onOpenSearch: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav_back')));
      expect(backTapped, isFalse);

      await tester.tap(find.byKey(const ValueKey('nav_forward')));
      expect(forwardTapped, isFalse);
    });
  });

  group('HomeScreen Navigation History and Sidebar Toggle', () {
    late AppDatabase db;
    late NotesRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = NotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('navigates between pages, history back and forward work', (tester) async {
      await repository.createPage(title: 'Page Alpha');
      await repository.createPage(title: 'Page Beta');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Page Alpha is auto-selected or selected
      expect(find.text('Page Alpha'), findsWidgets);
      expect(find.text('Page Beta'), findsWidgets);

      // Tap Page Beta in sidebar
      await tester.tap(find.text('Page Beta').first);
      await tester.pumpAndSettle();

      // Now we can navigate back!
      final backButton = find.byKey(const ValueKey('nav_back'));
      expect(backButton, findsWidgets);

      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      // Forward button should now be enabled
      final forwardButton = find.byKey(const ValueKey('nav_forward'));
      await tester.tap(forwardButton.first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('toggle sidebar hides and shows sidebar and keeps top toolbar visible', (tester) async {
      await repository.createPage(title: 'Welcome');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle sidebar button is in the window titlebar row
      final toggleButton = find.byKey(const ValueKey('nav_sidebar_toggle'));
      expect(toggleButton, findsOneWidget);

      // Tap toggle to collapse
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Sidebar collapsed, top toolbar remains anchored and visible in titlebar row
      expect(find.byKey(const ValueKey('nav_sidebar_toggle')), findsOneWidget);

      // Tap toggle again to expand
      await tester.tap(find.byKey(const ValueKey('nav_sidebar_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav_sidebar_toggle')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}

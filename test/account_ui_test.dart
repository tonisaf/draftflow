import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/account/account_controller.dart';
import 'package:notes_here/account/account_scope.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/main.dart';
import 'package:notes_here/ui/account/account_button.dart';
import 'package:notes_here/ui/editor/components/page_header.dart';
import 'package:notes_here/ui/theme.dart';

import 'support/fake_account_auth.dart';

void main() {
  late AppDatabase guestDb;
  late NotesRepository guest;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    guestDb = AppDatabase(NativeDatabase.memory());
    guest = NotesRepository(guestDb);
  });
  tearDown(() async {
    await guestDb.close();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });
  testWidgets(
    'unconfigured account remains usable locally and exposes no login form',
    (tester) async {
      final controller = AccountController(guest: guest);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AccountScope(
          controller: controller,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AccountButton()),
          ),
        ),
      );
      await tester.tap(find.text('Войти в аккаунт'));
      await tester.pumpAndSettle();
      expect(find.textContaining('пока не настроен'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(controller.repository, same(guest));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'registration validates fields and keeps guest data during email confirmation',
    (tester) async {
      final auth = FakeAccountAuth()..confirmation = true;
      final controller = AccountController(guest: guest, auth: auth);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AccountScope(
          controller: controller,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AccountButton()),
          ),
        ),
      );
      await tester.tap(find.text('Войти в аккаунт'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Укажите email'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Создать аккаунт'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Подтвердите email'), findsOneWidget);
      expect(controller.repository, same(guest));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'account switch flushes a title before debounce and remounts the workspace',
    (tester) async {
      final pageId = await guest.createPage(title: 'Guest note');
      final accountDb = AppDatabase(NativeDatabase.memory());
      addTearDown(accountDb.close);
      final auth = FakeAccountAuth()
        ..identity = const NotesIdentity('account-a', 'a@example.com');
      final controller = AccountController(
        guest: guest,
        auth: auth,
        openAccount: (_) async => NotesRepository(accountDb),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        NotesApp(repository: guest, accountController: controller),
      );
      await tester.pumpAndSettle();
      final titleField = find.descendant(
        of: find.byType(PageHeader),
        matching: find.byType(TextField),
      );
      await tester.enterText(titleField, 'Unsaved last keystroke');
      expect(await controller.signIn('a@example.com', 'password'), isTrue);
      expect((await guest.getPage(pageId))!.title, 'Unsaved last keystroke');
      await tester.pumpAndSettle();
      expect(find.byType(PageHeader), findsNothing);
      expect(await accountDb.getAllPages(), isEmpty);
      expect(await controller.signOut(), isTrue);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(titleField).controller!.text,
        'Unsaved last keystroke',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

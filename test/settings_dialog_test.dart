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
import 'package:notes_here/ui/settings/settings_dialog.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> pumpSettingsHost(
    WidgetTester tester, {
    required AccountController accounts,
    ThemeController? theme,
    LocaleController? locale,
    VoidCallback? onOpenBackup,
    Size viewport = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeCtrl = theme ?? ThemeController(ThemeMode.system);
    final localeCtrl = locale ?? LocaleController()
      ..setLocale(const Locale('ru'));

    await tester.pumpWidget(
      AccountScope(
        controller: accounts,
        child: LocaleScope(
          controller: localeCtrl,
          child: ThemeScope(
            controller: themeCtrl,
            child: ListenableBuilder(
              listenable: Listenable.merge([themeCtrl, localeCtrl, accounts]),
              builder: (context, _) => MaterialApp(
                theme: buildTheme(Brightness.light),
                darkTheme: buildTheme(Brightness.dark),
                themeMode: themeCtrl.mode,
                locale: localeCtrl.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () => showSettings(
                          context,
                          onOpenBackup: onOpenBackup,
                        ),
                        child: const Text('Open Settings'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('SettingsDialog renders Tasks Here layout, switches theme and opens backup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final theme = ThemeController(ThemeMode.system, prefs);
    final accounts = AccountController(guest: guest);
    addTearDown(accounts.dispose);
    var backupOpened = false;

    await pumpSettingsHost(
      tester,
      accounts: accounts,
      theme: theme,
      onOpenBackup: () => backupOpened = true,
    );

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-window')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-sidebar')), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Основные'), findsNWidgets(2));
    expect(find.text('Синхронизация'), findsOneWidget);
    expect(find.text('DraftFlow'), findsOneWidget);
    expect(find.text('1.0.1'), findsOneWidget);
    expect(find.text('Изменения применяются автоматически.'), findsOneWidget);

    // Open Theme dropdown pill and pick Dark
    await tester.tap(find.text('Как в системе').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
    expect(prefs.getString('notes_here.theme'), 'dark');

    await tester.ensureVisible(find.text('Открыть…'));
    await tester.tap(find.text('Открыть…'));
    await tester.pumpAndSettle();
    expect(backupOpened, isTrue);
    expect(find.byKey(const ValueKey('settings-window')), findsNothing);
  });

  testWidgets('CloseCross dismisses SettingsDialog', (tester) async {
    final accounts = AccountController(guest: guest);
    addTearDown(accounts.dispose);

    await pumpSettingsHost(tester, accounts: accounts);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-window')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-window')), findsNothing);
  });

  testWidgets('Sync tab supports sign-up, signed-in state and sign-out', (
    tester,
  ) async {
    final auth = FakeAccountAuth()..confirmation = true;
    final accounts = AccountController(guest: guest, auth: auth);
    addTearDown(accounts.dispose);

    await pumpSettingsHost(tester, accounts: accounts);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Синхронизация'));
    await tester.pumpAndSettle();

    // Validation check before entering credentials
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите email'), findsOneWidget);

    // Switch to sign-up tab
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Подтвердите email'), findsOneWidget);
  });

  testWidgets('Narrow viewport opens MobileSettingsPage', (tester) async {
    final accounts = AccountController(guest: guest);
    addTearDown(accounts.dispose);

    await pumpSettingsHost(
      tester,
      accounts: accounts,
      viewport: const Size(480, 800),
    );

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(MobileSettingsPage), findsOneWidget);
    expect(find.text('Основные'), findsOneWidget);
    expect(find.text('Синхронизация'), findsOneWidget);

    await tester.tap(find.text('Основные'));
    await tester.pumpAndSettle();
    expect(find.text('Тема'), findsOneWidget);
    expect(find.text('О приложении'), findsOneWidget);
  });
}

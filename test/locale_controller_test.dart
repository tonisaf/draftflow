import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleController unit tests', () {
    test('cycles through system (null), English, and Russian', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);

      expect(controller.locale, isNull);

      controller.cycleNext();
      expect(controller.locale, const Locale('en'));
      expect(prefs.getString('notes_here.locale'), 'en');

      controller.cycleNext();
      expect(controller.locale, const Locale('ru'));
      expect(prefs.getString('notes_here.locale'), 'ru');

      controller.cycleNext();
      expect(controller.locale, isNull);
      expect(prefs.getString('notes_here.locale'), isNull);
    });

    test('restores saved locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'notes_here.locale': 'ru'});
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);

      expect(controller.locale, const Locale('ru'));
    });

    test('toggleRuEn toggles between ru and en', () async {
      final controller = LocaleController();
      controller.setLocale(const Locale('en'));

      controller.toggleRuEn();
      expect(controller.locale, const Locale('ru'));

      controller.toggleRuEn();
      expect(controller.locale, const Locale('en'));
    });
  });

  group('Language switcher widget test', () {
    testWidgets('settings language picker updates UI strings reactively', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localeController = LocaleController(prefs);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NotesRepository(db);
      await repo.createPage(title: 'Test Note');

      await tester.pumpWidget(
        NotesApp(
          repository: repo,
          localeController: localeController,
        ),
      );
      await tester.pumpAndSettle();

      // Set to English explicitly
      localeController.setLocale(const Locale('en'));
      await tester.pumpAndSettle();

      expect(find.text('New page'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);

      // Open Settings from sidebar gear icon and switch language to Russian
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      // Tap the Language pill dropdown (currently set to English)
      await tester.ensureVisible(find.text('English'));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Русский'));
      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      expect(localeController.locale, const Locale('ru'));
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Новая страница'), findsOneWidget);
      expect(find.text('Корзина'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}

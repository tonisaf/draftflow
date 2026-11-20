import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/modules/core/app_module.dart';
import 'package:notes_here/modules/core/module_manager.dart';
import 'package:notes_here/modules/core/module_scope.dart';
import 'package:notes_here/ui/home_screen.dart';
import 'package:notes_here/ui/settings/settings_dialog.dart';
import 'package:notes_here/ui/settings/settings_widgets.dart';
import 'package:notes_here/ui/sidebar/sidebar.dart';
import 'package:notes_here/ui/theme.dart';

class DummyModule implements AppModule {
  @override
  String get id => 'dummy_mod';
  @override
  String get title => 'Тестовый Модуль';
  @override
  String get description => 'Описание тестового модуля';
  @override
  IconData get icon => Icons.stars;
  @override
  bool get isConfigured => true;

  @override
  Widget buildSettings(BuildContext context, {required NotesRepository repository}) =>
      const Text('Настройки тестового модуля');

  @override
  Widget buildView(
    BuildContext context, {
    required NotesRepository repository,
    required ValueChanged<String> onOpenPage,
  }) =>
      const Scaffold(
        body: Center(child: Text('Витрина тестового модуля')),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NotesRepository repository;
  late AppModuleManager moduleManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'module_enabled_dummy_mod': true});
    db = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(db);

    moduleManager = AppModuleManager();
    moduleManager.register(DummyModule());
    await moduleManager.loadPreferences();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({Widget? child}) {
    return AppModuleScope(
      manager: moduleManager,
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? HomeScreen(repository: repository),
      ),
    );
  }

  testWidgets('Sidebar renders enabled module and notifies on click', (tester) async {
    String? selectedId;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: Sidebar(
            pages: const [],
            selectedPageId: null,
            onSelectPage: (_) {},
            onNewRootPage: () {},
            onNewSubpage: (_) {},
            onTrashPage: (_) {},
            onOpenSearch: () {},
            onMovePage: (_, {nextOrderKey, prevOrderKey, targetParentId}) {},
            onToggleTrash: () {},
            selectedModuleId: null,
            onSelectModule: (id) => selectedId = id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify module title is displayed in sidebar
    expect(find.text('Тестовый Модуль'), findsOneWidget);
    expect(find.byIcon(Icons.stars), findsOneWidget);

    // Tap on the module row
    await tester.tap(find.text('Тестовый Модуль'));
    await tester.pumpAndSettle();

    expect(selectedId, 'dummy_mod');
  });

  testWidgets('HomeScreen navigates to module view when selected', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Click module in sidebar
    await tester.tap(find.text('Тестовый Модуль'));
    await tester.pumpAndSettle();

    // Verify module's view is rendered
    expect(find.text('Витрина тестового модуля'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsDialog contains "Модули" tab and renders modules list', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showSettings(ctx, repository: repository),
              child: const Text('Открыть настройки'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть настройки'));
    await tester.pumpAndSettle();

    // Verify "Модули" tab exists
    expect(find.text('Модули'), findsOneWidget);

    // Switch to "Модули" tab
    await tester.tap(find.text('Модули'));
    await tester.pumpAndSettle();

    // Verify module list item exists
    expect(find.text('Тестовый Модуль'), findsOneWidget);
    expect(find.text('Описание тестового модуля'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CupertinoSwitch || w is Switch || w is MacOSToggleSwitch,
      ),
      findsWidgets,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

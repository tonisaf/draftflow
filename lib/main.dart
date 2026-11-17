import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account/account_controller.dart';
import 'account/account_scope.dart';
import 'account/supabase_account_auth.dart';
import 'data/db/app_database.dart';
import 'data/notes_repository.dart';
import 'l10n/locale_controller.dart';
import 'modules/core/module_manager.dart';
import 'modules/core/module_scope.dart';
import 'modules/tmdb/tmdb_module.dart';
import 'platform/desktop_services.dart';
import 'ui/common/app_scroll_behavior.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

const String _prefThemeKey = 'notes_here.theme';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode;
  final SharedPreferences? _prefs;

  ThemeController([ThemeMode initial = ThemeMode.system, this._prefs])
    : _mode = _loadMode(_prefs) ?? initial;

  static ThemeMode? _loadMode(SharedPreferences? prefs) {
    final saved = prefs?.getString(_prefThemeKey);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (mode == ThemeMode.system) {
      _prefs?.remove(_prefThemeKey);
    } else {
      _prefs?.setString(_prefThemeKey, mode.name);
    }
    notifyListeners();
  }

  void cycleNext() {
    setMode(switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope?.notifier ?? _defaultController;
  }

  static final _defaultController = ThemeController();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final localeController = LocaleController(prefs);
  final themeController = ThemeController(ThemeMode.system, prefs);

  final database = AppDatabase();
  final repository = NotesRepository(database);

  // Seed default onboarding page and subpage if database is fresh
  final existingPages = await database.getAllPages();
  if (existingPages.isEmpty) {
    final rootId = await repository.createPage(title: 'Getting Started ⚡');
    await repository.createPage(
      title: 'Architecture & Design',
      parentId: rootId,
    );
  }

  AccountAuth? auth;
  String? configurationError;
  try {
    auth = SupabaseAccountAuth.fromEnvironment();
  } on AccountFailure catch (e) {
    configurationError = e.message;
  }
  FocusNode? syncFocus;
  final accounts = AccountController(
    guest: repository,
    auth: auth,
    waitForEditorFrame: () async {
      syncFocus = FocusManager.instance.primaryFocus;
      await WidgetsBinding.instance.endOfFrame;
    },
    afterRemoteApply: () {
      final focus = syncFocus;
      syncFocus = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focus?.context != null && focus!.canRequestFocus) {
          focus.requestFocus();
        }
      });
    },
  );
  accounts.error = configurationError;
  final moduleManager = AppModuleManager();
  final tmdbModule = TmdbModule();
  await tmdbModule.init();
  moduleManager.register(tmdbModule);
  await moduleManager.loadPreferences();

  runApp(NotesApp(
    repository: repository,
    accountController: accounts,
    themeController: themeController,
    localeController: localeController,
    moduleManager: moduleManager,
  ));
  if (configurationError == null) unawaited(accounts.restore());
}

class NotesApp extends StatefulWidget {
  final NotesRepository repository;
  final ThemeController? themeController;
  final LocaleController? localeController;
  final AccountController? accountController;
  final AppModuleManager? moduleManager;

  const NotesApp({
    super.key,
    required this.repository,
    this.themeController,
    this.localeController,
    this.accountController,
    this.moduleManager,
  });

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> with WidgetsBindingObserver {
  late final ThemeController _themeController;
  late final LocaleController _localeController;
  late final AppModuleManager _moduleManager;
  late bool _mica = defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _themeController = widget.themeController ?? ThemeController();
    _localeController = widget.localeController ?? LocaleController();
    _moduleManager = widget.moduleManager ?? AppModuleManager();
    if (widget.moduleManager == null) {
      final tmdb = TmdbModule();
      _moduleManager.register(tmdb);
      unawaited(tmdb.init().then((_) => _moduleManager.loadPreferences()));
    }
    _themeController.addListener(_themeChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_applyBackdrop());
  }

  @override
  void dispose() {
    _themeController.removeListener(_themeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _themeChanged() {
    unawaited(_applyBackdrop());
  }

  @override
  void didChangePlatformBrightness() => unawaited(_applyBackdrop());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_applyBackdrop());
    }
  }

  Future<void> _applyBackdrop() async {
    final dark = switch (_themeController.mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    final mica = await applyBackdrop(dark: dark);
    if (mounted && mica != _mica) setState(() => _mica = mica);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountController;
    final app = LocaleScope(
      controller: _localeController,
      child: ThemeScope(
        controller: _themeController,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _themeController,
            _localeController,
            ?accounts,
          ]),
          builder: (context, _) {
            return MaterialApp(
              title: 'DraftFlow',
              debugShowCheckedModeBanner: false,
              scrollBehavior: const AppScrollBehavior(),
              themeMode: _themeController.mode,
              theme: buildTheme(Brightness.light, mica: _mica),
              darkTheme: buildTheme(Brightness.dark, mica: _mica),
              locale: _localeController.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ExcludeFocus(
                excluding:
                    (accounts?.busy ?? false) ||
                    (accounts?.applyingRemote ?? false),
                child: AbsorbPointer(
                  absorbing:
                      (accounts?.busy ?? false) ||
                      (accounts?.applyingRemote ?? false),
                  child: HomeScreen(
                    key: ObjectKey(accounts?.repository ?? widget.repository),
                    repository: accounts?.repository ?? widget.repository,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final scoped = AppModuleScope(manager: _moduleManager, child: app);
    return accounts == null
        ? scoped
        : AccountScope(controller: accounts, child: scoped);
  }
}

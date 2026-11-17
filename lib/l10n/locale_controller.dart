import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

const String _prefLocaleKey = 'notes_here.locale';

class LocaleController extends ChangeNotifier {
  Locale? _locale;
  final SharedPreferences? _prefs;

  LocaleController([this._prefs]) {
    final savedCode = _prefs?.getString(_prefLocaleKey);
    if (savedCode != null && savedCode.isNotEmpty) {
      if (savedCode == 'en' || savedCode == 'ru') {
        _locale = Locale(savedCode);
      }
    }
  }

  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    if (_locale == locale) return;
    _locale = locale;
    if (locale == null) {
      _prefs?.remove(_prefLocaleKey);
    } else {
      _prefs?.setString(_prefLocaleKey, locale.languageCode);
    }
    notifyListeners();
  }

  void cycleNext() {
    // Cycles: system (null) -> en -> ru -> system (null)
    final next = switch (_locale?.languageCode) {
      'en' => const Locale('ru'),
      'ru' => null, // back to system
      _ => const Locale('en'),
    };
    setLocale(next);
  }

  void toggleRuEn() {
    // Quick toggle between RU and EN
    if (_locale?.languageCode == 'ru') {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('ru'));
    }
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.notifier ?? _defaultController;
  }

  static final _defaultController = LocaleController();
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      // Fallback in test environments or before MaterialApp initializes
      return lookupAppLocalizations(const Locale('en'));
    }
    return localizations;
  }
}

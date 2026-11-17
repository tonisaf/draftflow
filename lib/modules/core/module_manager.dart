import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_module.dart';

/// Central registry and lifecycle manager for app modules.
class AppModuleManager extends ChangeNotifier {
  final Map<String, AppModule> _modules = {};
  final Set<String> _enabledModuleIds = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<AppModule> get allModules => _modules.values.toList();
  List<AppModule> get enabledModules =>
      _modules.values.where((m) => _enabledModuleIds.contains(m.id)).toList();

  AppModule? getModule(String id) => _modules[id];

  bool isEnabled(String id) => _enabledModuleIds.contains(id);

  /// Registers an available module.
  void register(AppModule module) {
    _modules[module.id] = module;
  }

  /// Loads persisted enabled states from SharedPreferences.
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabledModuleIds.clear();
      for (final id in _modules.keys) {
        // By default, modules can be disabled until user toggles them, or enabled if configured.
        final enabled = prefs.getBool('module_enabled_$id') ?? false;
        if (enabled) {
          _enabledModuleIds.add(id);
        }
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AppModuleManager: Failed to load preferences: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Toggles or sets enabled state for a module.
  Future<void> setEnabled(String id, bool enabled) async {
    if (!_modules.containsKey(id)) return;
    if (enabled) {
      _enabledModuleIds.add(id);
    } else {
      _enabledModuleIds.remove(id);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('module_enabled_$id', enabled);
    } catch (e) {
      debugPrint('AppModuleManager: Failed to save preference for $id: $e');
    }
  }
}

import 'package:flutter/widgets.dart';
import 'module_manager.dart';

class AppModuleScope extends InheritedNotifier<AppModuleManager> {
  const AppModuleScope({
    super.key,
    required AppModuleManager manager,
    required super.child,
  }) : super(notifier: manager);

  static AppModuleManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppModuleScope>();
    assert(scope != null, 'No AppModuleScope found in context');
    return scope!.notifier!;
  }

  static AppModuleManager? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppModuleScope>()?.notifier;
  }
}

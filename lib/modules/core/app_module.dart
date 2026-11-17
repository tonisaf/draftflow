import 'package:flutter/material.dart';
import '../../data/notes_repository.dart';

/// Base abstraction for all pluggable modules (TMDB, Books, etc.).
abstract class AppModule {
  /// Unique identifier of the module (e.g., 'tmdb', 'books').
  String get id;

  /// Display name of the module.
  String get title;

  /// Short description of what this module does.
  String get description;

  /// Icon representing this module in navigation/settings.
  IconData get icon;

  /// Whether the module has required credentials/configuration set up.
  bool get isConfigured;

  /// Builds the settings widget for configuring credentials/options for this module.
  Widget buildSettings(BuildContext context, {required NotesRepository repository});

  /// Builds the main view/screen for this module.
  Widget buildView(
    BuildContext context, {
    required NotesRepository repository,
    required ValueChanged<String> onOpenPage,
  });
}

import 'package:flutter/material.dart';
import '../../data/notes_repository.dart';
import '../core/app_module.dart';
import 'services/tmdb_api_client.dart';
import 'services/tmdb_config_service.dart';
import 'services/tmdb_database_sync.dart';
import 'ui/tmdb_settings_view.dart';
import 'ui/tmdb_view.dart';

class TmdbModule implements AppModule {
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  TmdbDatabaseSync? _syncService;

  TmdbModule({
    TmdbApiClient? client,
    TmdbConfigService? config,
  })  : apiClient = client ?? TmdbApiClient(),
        configService = config ?? TmdbConfigService();

  Future<void> init() async {
    await configService.init();
  }

  TmdbDatabaseSync getSyncService(NotesRepository repository) {
    if (_syncService == null || _syncService!.repository != repository) {
      _syncService = TmdbDatabaseSync(repository: repository);
    }
    return _syncService!;
  }

  @override
  String get id => 'tmdb';

  @override
  String get title => 'Фильмы и Сериалы';

  @override
  String get description => 'Подключение TMDB: каталог фильмов, синхронизация списков и рецензий';

  @override
  IconData get icon => Icons.movie_outlined;

  @override
  bool get isConfigured => configService.hasApiToken;

  @override
  Widget buildSettings(BuildContext context, {required NotesRepository repository}) {
    final sync = getSyncService(repository);
    return ListenableBuilder(
      listenable: configService,
      builder: (context, _) {
        return TmdbSettingsView(
          apiClient: apiClient,
          configService: configService,
          syncService: sync,
        );
      },
    );
  }

  @override
  Widget buildView(
    BuildContext context, {
    required NotesRepository repository,
    required ValueChanged<String> onOpenPage,
  }) {
    final sync = getSyncService(repository);
    return ListenableBuilder(
      listenable: configService,
      builder: (context, _) => TmdbView(
        repository: repository,
        apiClient: apiClient,
        configService: configService,
        syncService: sync,
        onOpenPage: onOpenPage,
      ),
    );
  }
}

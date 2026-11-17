import 'package:flutter/material.dart';

import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import 'tmdb_detail_dialog.dart';
import 'tmdb_favorite_persons_dialog.dart';
import 'tmdb_person_dialog.dart';
import 'tmdb_recommendations_dialog.dart';
import 'tmdb_search_dialog.dart';

sealed class TmdbModalRoute {
  final String title;
  const TmdbModalRoute(this.title);
}

class TmdbMovieDetailRoute extends TmdbModalRoute {
  final TmdbMediaItem item;
  final ValueChanged<String>? onOpenAsPage;
  TmdbMovieDetailRoute({
    required this.item,
    this.onOpenAsPage,
  }) : super(item.title);
}

class TmdbPersonRoute extends TmdbModalRoute {
  final int? personId;
  final String personName;
  final String? initialRole;
  final String? initialProfilePath;
  TmdbPersonRoute({
    this.personId,
    required this.personName,
    this.initialRole,
    this.initialProfilePath,
  }) : super(personName);
}

class TmdbFavoritePersonsRoute extends TmdbModalRoute {
  final ValueChanged<String>? onFilterByPerson;
  const TmdbFavoritePersonsRoute({this.onFilterByPerson})
      : super('Любимые актёры и режиссёры');
}

class TmdbRecommendationsRoute extends TmdbModalRoute {
  final ValueChanged<String>? onOpenAsPage;
  const TmdbRecommendationsRoute({this.onOpenAsPage})
      : super('Умные рекомендации');
}

class TmdbSearchRoute extends TmdbModalRoute {
  final String? initialQuery;
  final ValueChanged<String>? onPageCreated;
  const TmdbSearchRoute({this.initialQuery, this.onPageCreated})
      : super('Поиск в TMDB');
}

class TmdbModalHost extends StatefulWidget {
  final TmdbModalRoute initialRoute;
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final List<TmdbMediaItem> localItems;
  final ValueChanged<String>? onOpenPage;

  const TmdbModalHost({
    super.key,
    required this.initialRoute,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    required this.localItems,
    this.onOpenPage,
  });

  static Future<void> show(
    BuildContext context, {
    required TmdbModalRoute initialRoute,
    required TmdbApiClient apiClient,
    required TmdbConfigService configService,
    required TmdbDatabaseSync syncService,
    required List<TmdbMediaItem> localItems,
    ValueChanged<String>? onOpenPage,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TmdbModalHost',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => TmdbModalHost(
        initialRoute: initialRoute,
        apiClient: apiClient,
        configService: configService,
        syncService: syncService,
        localItems: localItems,
        onOpenPage: onOpenPage,
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<TmdbModalHost> createState() => _TmdbModalHostState();
}

class _TmdbModalHostState extends State<TmdbModalHost> {
  final List<TmdbModalRoute> _stack = [];

  @override
  void initState() {
    super.initState();
    _stack.add(widget.initialRoute);
  }

  void _push(TmdbModalRoute route) {
    setState(() => _stack.add(route));
  }

  void _pop() {
    if (_stack.length > 1) {
      setState(() => _stack.removeLast());
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = _stack.last;
    final canPop = _stack.length > 1;

    return PopScope(
      canPop: !canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && canPop) {
          _pop();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_stack.length.toString() + currentRoute.title),
          child: _buildRouteView(currentRoute, canPop),
        ),
      ),
    );
  }

  Widget _buildRouteView(TmdbModalRoute route, bool canPop) {
    final onBack = canPop ? _pop : null;

    if (route is TmdbMovieDetailRoute) {
      return TmdbDetailDialog(
        item: route.item,
        apiClient: widget.apiClient,
        configService: widget.configService,
        syncService: widget.syncService,
        onOpenAsPage: route.onOpenAsPage ?? widget.onOpenPage,
        onBack: onBack,
        onNavigateToPerson: (personId, name, role, profilePath) {
          _push(TmdbPersonRoute(
            personId: personId,
            personName: name,
            initialRole: role,
            initialProfilePath: profilePath,
          ));
        },
        onNavigateToMovie: (item) {
          _push(TmdbMovieDetailRoute(
            item: item,
            onOpenAsPage: widget.onOpenPage,
          ));
        },
      );
    } else if (route is TmdbPersonRoute) {
      return TmdbPersonDialog(
        personId: route.personId,
        personName: route.personName,
        initialRole: route.initialRole,
        initialProfilePath: route.initialProfilePath,
        apiClient: widget.apiClient,
        configService: widget.configService,
        syncService: widget.syncService,
        localItems: widget.localItems,
        onBack: onBack,
        onNavigateToMovie: (item) {
          _push(TmdbMovieDetailRoute(
            item: item,
            onOpenAsPage: widget.onOpenPage,
          ));
        },
      );
    } else if (route is TmdbFavoritePersonsRoute) {
      return TmdbFavoritePersonsDialog(
        localItems: widget.localItems,
        apiClient: widget.apiClient,
        configService: widget.configService,
        syncService: widget.syncService,
        onFilterByPerson: route.onFilterByPerson,
        onBack: onBack,
        onNavigateToPerson: (personId, name, role, profilePath) {
          _push(TmdbPersonRoute(
            personId: personId,
            personName: name,
            initialRole: role,
            initialProfilePath: profilePath,
          ));
        },
      );
    } else if (route is TmdbRecommendationsRoute) {
      return TmdbSmartRecommendationsDialog(
        libraryItems: widget.localItems,
        apiClient: widget.apiClient,
        configService: widget.configService,
        syncService: widget.syncService,
        onOpenAsPage: route.onOpenAsPage ?? widget.onOpenPage,
        onBack: onBack,
        onNavigateToMovie: (item) {
          _push(TmdbMovieDetailRoute(
            item: item,
            onOpenAsPage: widget.onOpenPage,
          ));
        },
      );
    } else if (route is TmdbSearchRoute) {
      return TmdbSearchDialog(
        apiClient: widget.apiClient,
        configService: widget.configService,
        syncService: widget.syncService,
        initialQuery: route.initialQuery,
        onPageCreated: route.onPageCreated ?? widget.onOpenPage,
        onBack: onBack,
        onNavigateToMovie: (item) {
          _push(TmdbMovieDetailRoute(
            item: item,
            onOpenAsPage: widget.onOpenPage,
          ));
        },
      );
    }

    return const SizedBox.shrink();
  }
}

import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/tmdb_favorite_persons_service.dart';
import '../services/tmdb_image_cache.dart';
import 'tmdb_modal_host.dart';
import 'tmdb_detail_dialog.dart';

enum _MediaTypeFilter { all, movies, tv }

enum _PersonSortOption { popularity, year }

class TmdbPersonDialog extends StatefulWidget {
  final int? personId;
  final String personName;
  final String? initialRole;
  final String? initialProfilePath;
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final List<TmdbMediaItem> localItems;
  final ValueChanged<TmdbMediaItem>? onOpenMediaItem;
  final VoidCallback? onBack;
  final ValueChanged<TmdbMediaItem>? onNavigateToMovie;

  const TmdbPersonDialog({
    super.key,
    this.personId,
    required this.personName,
    this.initialRole,
    this.initialProfilePath,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    required this.localItems,
    this.onOpenMediaItem,
    this.onBack,
    this.onNavigateToMovie,
  });

  static Future<void> show({
    required BuildContext context,
    int? personId,
    required String personName,
    String? initialRole,
    String? initialProfilePath,
    required TmdbApiClient apiClient,
    required TmdbConfigService configService,
    required TmdbDatabaseSync syncService,
    required List<TmdbMediaItem> localItems,
    ValueChanged<TmdbMediaItem>? onOpenMediaItem,
  }) {
    return TmdbModalHost.show(
      context,
      initialRoute: TmdbPersonRoute(
        personId: personId,
        personName: personName,
        initialRole: initialRole,
        initialProfilePath: initialProfilePath,
      ),
      apiClient: apiClient,
      configService: configService,
      syncService: syncService,
      localItems: localItems,
    );
  }

  @override
  State<TmdbPersonDialog> createState() => _TmdbPersonDialogState();
}

class _TmdbPersonDialogState extends State<TmdbPersonDialog> {
  int? _resolvedId;
  TmdbPersonDetails? _details;
  List<TmdbMediaItem> _credits = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isBioExpanded = false;

  _MediaTypeFilter _mediaFilter = _MediaTypeFilter.all;
  _PersonSortOption _sortOption = _PersonSortOption.popularity;

  // Track locally added items inside this dialog session
  final Map<int, String> _sessionAddedStatuses = {};
  final _favService = TmdbFavoritePersonsService.instance;

  @override
  void initState() {
    super.initState();
    _favService.init().then((_) {
      if (mounted) setState(() {});
    });
    _resolvedId = widget.personId;
    _fetchPersonData();
  }

  Future<void> _fetchPersonData() async {
    if (!widget.configService.hasApiToken) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Для загрузки фильмографии требуется TMDB токен в настройках.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = widget.configService.apiToken!;

    try {
      int? targetId = _resolvedId;
      targetId ??= await widget.apiClient.findPersonIdByName(
        apiToken: token,
        name: widget.personName,
      );

      if (targetId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Персона «${widget.personName}» не найдена в базе TMDB.';
          });
        }
        return;
      }

      _resolvedId = targetId;

      final results = await Future.wait([
        widget.apiClient.getPersonDetails(apiToken: token, personId: targetId),
        widget.apiClient.getPersonCombinedCredits(apiToken: token, personId: targetId),
      ]);

      if (mounted) {
        setState(() {
          _details = results[0] as TmdbPersonDetails;
          _credits = results[1] as List<TmdbMediaItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка загрузки фильмографии: $e';
        });
      }
    }
  }

  List<TmdbMediaItem> get _filteredCredits {
    List<TmdbMediaItem> list = _credits;
    if (_mediaFilter == _MediaTypeFilter.movies) {
      list = list.where((i) => i.mediaType == 'movie').toList();
    } else if (_mediaFilter == _MediaTypeFilter.tv) {
      list = list.where((i) => i.mediaType == 'tv').toList();
    }

    final sorted = List<TmdbMediaItem>.from(list);
    if (_sortOption == _PersonSortOption.year) {
      sorted.sort((a, b) => b.year.compareTo(a.year));
    } else {
      sorted.sort((a, b) => (b.voteCount ?? 0).compareTo(a.voteCount ?? 0));
    }
    return sorted;
  }

  TmdbMediaItem? _findInLocalLibrary(int tmdbId) {
    return widget.localItems.cast<TmdbMediaItem?>().firstWhere(
          (item) => item?.id == tmdbId,
          orElse: () => null,
        );
  }

  Future<void> _addToLibrary(TmdbMediaItem item, String status) async {
    setState(() {
      _sessionAddedStatuses[item.id] = status;
    });

    try {
      TmdbMediaItem toSave = item.copyWith(status: status);
      if (widget.configService.hasApiToken) {
        try {
          final full = await widget.apiClient.getDetails(
            apiToken: widget.configService.apiToken!,
            id: item.id,
            mediaType: item.mediaType,
          );
          toSave = toSave.copyWith(
            tagline: full.tagline ?? toSave.tagline,
            runtime: full.runtime ?? toSave.runtime,
            director: full.director ?? toSave.director,
            cast: full.cast.isNotEmpty ? full.cast : toSave.cast,
            crew: full.crew.isNotEmpty ? full.crew : toSave.crew,
            trailerKey: full.trailerKey ?? toSave.trailerKey,
            backdropPath: full.backdropPath ?? toSave.backdropPath,
            overview: (full.overview != null && full.overview!.isNotEmpty) ? full.overview : toSave.overview,
            genres: full.genres.isNotEmpty ? full.genres : toSave.genres,
            releaseDate: full.releaseDate ?? toSave.releaseDate,
            originalTitle: full.originalTitle ?? toSave.originalTitle,
          );
        } catch (_) {}
      }

      await widget.syncService.saveMediaItem(
        toSave,
        client: widget.apiClient,
        config: widget.configService,
        syncToTmdb: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${item.title}» добавлен в медиатеку!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionAddedStatuses.remove(item.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка добавления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 920,
          constraints: const BoxConstraints(maxHeight: 740),
          decoration: BoxDecoration(
            color: skin.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: skin.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildTopHeader(skin),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Palette.accent),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Загрузка фильмографии «${widget.personName}»...',
                              style: TextStyle(fontSize: 13, color: skin.muted),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline, size: 40, color: skin.faint),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: skin.muted),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _fetchPersonData,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Повторить'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Palette.accent,
                                      side: BorderSide(color: skin.outline),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildMainContent(skin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(Skin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: skin.surface,
        border: Border(bottom: BorderSide(color: skin.outline)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: skin.hover,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: skin.text),
                    const SizedBox(width: 5),
                    Text('Назад', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: skin.text)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Palette.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_pin_rounded, size: 18, color: Palette.accent),
          ),
          const SizedBox(width: 10),
          Text(
            'Фильмография и досье',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            splashRadius: 18,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(Skin skin) {
    final photoUrl = _details?.profileUrl('w300') ??
        (widget.initialProfilePath != null
            ? 'https://image.tmdb.org/t/p/w300${widget.initialProfilePath}'
            : null);
    final displayedItems = _filteredCredits;

    return CustomScrollView(
      slivers: [
        // Person Profile Hero
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: skin.sidebar.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: skin.outline)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: skin.surface,
                  child: ClipOval(
                    child: photoUrl != null
                        ? TmdbCachedImage(
                            imageUrl: photoUrl,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 92,
                            height: 92,
                            color: skin.sidebar,
                            child: Icon(Icons.person, size: 40, color: skin.faint),
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _details?.name ?? widget.personName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: skin.text,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Palette.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(UiRadius.control),
                              border: Border.all(color: Palette.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              widget.initialRole ?? _details?.localizedDepartment ?? 'Кинематографист',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Palette.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFavoriteButton(skin),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Meta info: birthday / place of birth
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (_details?.birthday != null && _details!.birthday!.isNotEmpty)
                            _metaText(skin, Icons.cake_outlined, 'Дата рождения: ${_details!.birthday!}'),
                          if (_details?.placeOfBirth != null && _details!.placeOfBirth!.isNotEmpty)
                            _metaText(skin, Icons.location_on_outlined, _details!.placeOfBirth!),
                          _metaText(skin, Icons.movie_outlined, 'Проектов: ${_credits.length}'),
                        ],
                      ),
                      if (_details?.biography != null && _details!.biography!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              _details!.biography!,
                              maxLines: _isBioExpanded ? 100 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: skin.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filter and Sort Toolbar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                _filterButton(_MediaTypeFilter.all, 'Все (${_credits.length})'),
                const SizedBox(width: 8),
                _filterButton(
                  _MediaTypeFilter.movies,
                  'Фильмы (${_credits.where((i) => i.mediaType == 'movie').length})',
                ),
                const SizedBox(width: 8),
                _filterButton(
                  _MediaTypeFilter.tv,
                  'Сериалы (${_credits.where((i) => i.mediaType == 'tv').length})',
                ),
                const Spacer(),
                PopupMenuButton<_PersonSortOption>(
                  initialValue: _sortOption,
                  tooltip: 'Сортировка',
                  onSelected: (opt) => setState(() => _sortOption = opt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: skin.sidebar,
                      borderRadius: BorderRadius.circular(UiRadius.control),
                      border: Border.all(color: skin.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded, size: 14, color: skin.muted),
                        const SizedBox(width: 6),
                        Text(
                          _sortOption == _PersonSortOption.popularity ? 'По популярности' : 'По году',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: skin.text),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: _PersonSortOption.popularity,
                      child: Text('По популярности (TMDB)'),
                    ),
                    const PopupMenuItem(
                      value: _PersonSortOption.year,
                      child: Text('По дате выхода (сначала новые)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Filmography Grid
        if (displayedItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text('Проектов в этой категории не найдено.', style: TextStyle(color: skin.muted)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                childAspectRatio: 0.58,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) => _buildCreditCard(skin, displayedItems[idx]),
                childCount: displayedItems.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _metaText(Skin skin, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: skin.muted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: skin.muted)),
      ],
    );
  }

  Widget _filterButton(_MediaTypeFilter filter, String title) {
    final isSelected = _mediaFilter == filter;
    final skin = context.skin;

    return InkWell(
      onTap: () => setState(() => _mediaFilter = filter),
      borderRadius: BorderRadius.circular(UiRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Palette.accent : skin.sidebar,
          borderRadius: BorderRadius.circular(UiRadius.control),
          border: Border.all(color: isSelected ? Palette.accent : skin.outline),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : skin.text,
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCard(Skin skin, TmdbMediaItem item) {
    final localMatch = _findInLocalLibrary(item.id);
    final sessionStatus = _sessionAddedStatuses[item.id];
    final activeStatus = sessionStatus ?? localMatch?.status;
    final posterUrl = item.posterUrl('w342');

    return Container(
      decoration: BoxDecoration(
        color: skin.sidebar,
        borderRadius: BorderRadius.circular(UiRadius.control),
        border: Border.all(color: skin.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster with badges
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (widget.onNavigateToMovie != null) {
                  widget.onNavigateToMovie!(item);
                } else {
                  TmdbDetailDialog.show(
                    context,
                    item: item,
                    apiClient: widget.apiClient,
                    configService: widget.configService,
                    syncService: widget.syncService,
                    localItems: widget.localItems,
                  );
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl != null
                      ? TmdbCachedImage(imageUrl: posterUrl, fit: BoxFit.cover)
                      : Container(
                          color: skin.surface,
                          child: Icon(Icons.movie_outlined, size: 32, color: skin.faint),
                        ),
                  // TMDB Rating Badge top-left
                  if (item.voteAverage != null && item.voteAverage! > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              item.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Media Type Badge top-right
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: (item.mediaType == 'tv' ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6))
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details & Library Status Action
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.onNavigateToMovie != null) {
                      widget.onNavigateToMovie!(item);
                    } else {
                      TmdbDetailDialog.show(
                        context,
                        item: item,
                        apiClient: widget.apiClient,
                        configService: widget.configService,
                        syncService: widget.syncService,
                        localItems: widget.localItems,
                      );
                    }
                  },
                  child: Text(
                    item.title,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: skin.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.year.isNotEmpty ? item.year : '—',
                  style: TextStyle(fontSize: 10, color: skin.muted),
                ),
                const SizedBox(height: 6),

                // In Library Badge or Add Button
                if (activeStatus != null)
                  _buildLibraryStatusBadge(activeStatus)
                else
                  _buildAddButton(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'watched':
        color = const Color(0xFF10B981);
        label = '✓ Просмотрено';
        break;
      case 'watching':
        color = const Color(0xFFF59E0B);
        label = '▶ Смотрю';
        break;
      case 'dropped':
        color = const Color(0xFFEF4444);
        label = '✕ Брошено';
        break;
      case 'watchlist':
      default:
        color = const Color(0xFF6366F1);
        label = '★ В планах';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildAddButton(TmdbMediaItem item) {
    return PopupMenuButton<String>(
      tooltip: 'Добавить в медиатеку',
      onSelected: (status) => _addToLibrary(item, status),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Palette.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.accent.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 12, color: Palette.accent),
              SizedBox(width: 4),
              Text(
                'В список',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Palette.accent),
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'watchlist',
          child: Row(
            children: [
              Icon(Icons.bookmark_border_rounded, size: 16, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text('В планах'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'watching',
          child: Row(
            children: [
              Icon(Icons.play_circle_outline, size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Смотрю сейчас'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'watched',
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Просмотрено'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton(Skin skin) {
    final personId = _resolvedId;
    if (personId == null) return const SizedBox.shrink();

    final isFav = _favService.isFavorite(personId, name: widget.personName);

    return InkWell(
      onTap: () async {
        final nowFav = await _favService.toggleFavorite(
          id: personId,
          name: _details?.name ?? widget.personName,
          profilePath: _details?.profilePath ?? widget.initialProfilePath,
          department: _details?.knownForDepartment ?? widget.initialRole,
        );
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nowFav
                    ? '«${_details?.name ?? widget.personName}» добавлен в любимые персоны!'
                    : '«${_details?.name ?? widget.personName}» удален из любимых.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isFav ? Colors.redAccent.withValues(alpha: 0.12) : skin.hover,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFav ? Colors.redAccent.withValues(alpha: 0.35) : skin.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 13,
              color: isFav ? Colors.redAccent : skin.muted,
            ),
            const SizedBox(width: 5),
            Text(
              isFav ? 'В любимых' : 'В любимые',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isFav ? FontWeight.w600 : FontWeight.w500,
                color: isFav ? Colors.redAccent : skin.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

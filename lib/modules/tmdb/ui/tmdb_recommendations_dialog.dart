import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/tmdb_favorite_persons_service.dart';
import '../services/tmdb_image_cache.dart';
import 'tmdb_detail_dialog.dart';
import 'tmdb_modal_host.dart';

enum _RecCategoryFilter {
  all('Все рекомендации', Icons.all_inclusive_rounded),
  fromFavorites('По любимым фильмам', Icons.favorite_rounded),
  fromGenres('По жанрам', Icons.category_outlined),
  fromDirectors('Любимые режиссёры', Icons.movie_creation_outlined),
  fromFavoritePersons('Любимые персоны', Icons.stars_rounded);

  final String label;
  final IconData icon;
  const _RecCategoryFilter(this.label, this.icon);
}

class _ScoredRecommendation {
  final TmdbMediaItem item;
  final String reason;
  final _RecCategoryFilter category;

  const _ScoredRecommendation({
    required this.item,
    required this.reason,
    required this.category,
  });
}

class TmdbSmartRecommendationsDialog extends StatefulWidget {
  final List<TmdbMediaItem> libraryItems;
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final ValueChanged<String>? onOpenAsPage;
  final VoidCallback? onBack;
  final ValueChanged<TmdbMediaItem>? onNavigateToMovie;

  const TmdbSmartRecommendationsDialog({
    super.key,
    required this.libraryItems,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    this.onOpenAsPage,
    this.onBack,
    this.onNavigateToMovie,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TmdbMediaItem> libraryItems,
    required TmdbApiClient apiClient,
    required TmdbConfigService configService,
    required TmdbDatabaseSync syncService,
    ValueChanged<String>? onOpenAsPage,
  }) {
    return TmdbModalHost.show(
      context,
      initialRoute: TmdbRecommendationsRoute(
        onOpenAsPage: onOpenAsPage,
      ),
      apiClient: apiClient,
      configService: configService,
      syncService: syncService,
      localItems: libraryItems,
      onOpenPage: onOpenAsPage,
    );
  }

  @override
  State<TmdbSmartRecommendationsDialog> createState() => _TmdbSmartRecommendationsDialogState();
}

class _TmdbSmartRecommendationsDialogState extends State<TmdbSmartRecommendationsDialog> {
  bool _isLoading = true;
  String _loadingStatus = 'Анализируем вашу медиатеку...';
  List<_ScoredRecommendation> _recommendations = [];
  _RecCategoryFilter _selectedCategory = _RecCategoryFilter.all;
  final Set<int> _addedItemIds = {};
  late Set<int> _existingLibraryIds;

  @override
  void initState() {
    super.initState();
    _existingLibraryIds = widget.libraryItems.map((i) => i.id).toSet();
    _generateRecommendations();
  }

  Future<void> _generateRecommendations() async {
    if (!widget.configService.hasApiToken) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingStatus = 'Анализируем ваши оценки и предпочтения...';
    });

    final apiToken = widget.configService.apiToken!;
    final List<_ScoredRecommendation> results = [];
    final seenIds = Set<int>.from(_existingLibraryIds);

    try {
      // 1. Identify user's top-rated seeds (rating >= 7.0, isFavorite, or watched)
      final topSeeds = widget.libraryItems.where((i) {
        return (i.userRating != null && i.userRating! >= 7.0) ||
            i.isFavorite ||
            (i.status == 'watched' && i.voteAverage != null && i.voteAverage! >= 7.5);
      }).toList();

      // Sort seeds by rating descending
      topSeeds.sort((a, b) {
        final aScore = a.userRating ?? a.voteAverage ?? 0;
        final bScore = b.userRating ?? b.voteAverage ?? 0;
        return bScore.compareTo(aScore);
      });

      // 2. Recommendations based on top seeds
      final seedsToQuery = topSeeds.take(3).toList();
      for (final seed in seedsToQuery) {
        if (!mounted) return;
        setState(() => _loadingStatus = 'Ищем фильмы, похожие на «${seed.title}»...');

        try {
          var recs = await widget.apiClient.getRecommendations(
            apiToken: apiToken,
            id: seed.id,
            mediaType: seed.mediaType,
          );

          if (recs.length < 4) {
            final similar = await widget.apiClient.getSimilar(
              apiToken: apiToken,
              id: seed.id,
              mediaType: seed.mediaType,
            );
            recs.addAll(similar);
          }

          for (final r in recs) {
            if (seenIds.add(r.id)) {
              results.add(_ScoredRecommendation(
                item: r,
                reason: 'Похоже на «${seed.title}»',
                category: _RecCategoryFilter.fromFavorites,
              ));
            }
          }
        } catch (_) {}
      }

      // 3. Top Genres Discovery
      final genreCounts = <String, int>{};
      for (final item in widget.libraryItems) {
        for (final g in item.genres) {
          genreCounts[g] = (genreCounts[g] ?? 0) + 1;
        }
      }

      final sortedGenres = genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topGenres = sortedGenres.take(2).map((e) => e.key).toList();

      for (final genreName in topGenres) {
        if (!mounted) return;
        setState(() => _loadingStatus = 'Подбираем лучшие проекты в жанре $genreName...');

        int? genreId;
        for (final entry in tmdbGenreMap.entries) {
          if (entry.value.toLowerCase() == genreName.toLowerCase()) {
            genreId = entry.key;
            break;
          }
        }

        if (genreId != null) {
          try {
            final genreHits = await widget.apiClient.discoverMedia(
              apiToken: apiToken,
              withGenres: [genreId],
              voteAverageGte: 7.2,
              voteCountGte: 300,
              sortBy: 'vote_average.desc',
            );

            for (final gItem in genreHits.take(6)) {
              if (seenIds.add(gItem.id)) {
                results.add(_ScoredRecommendation(
                  item: gItem,
                  reason: 'Хит в жанре $genreName',
                  category: _RecCategoryFilter.fromGenres,
                ));
              }
            }
          } catch (_) {}
        }
      }

      // 4. Top Directors Recommendations
      final directorCounts = <String, int>{};
      for (final item in widget.libraryItems) {
        if (item.director != null && item.director!.isNotEmpty) {
          directorCounts[item.director!] = (directorCounts[item.director!] ?? 0) + 1;
        }
      }

      final topDirectors = directorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final directorsToQuery = topDirectors.take(2).map((e) => e.key).toList();

      for (final director in directorsToQuery) {
        if (!mounted) return;
        setState(() => _loadingStatus = 'Ищем работы режиссёра $director...');

        try {
          final personId = await widget.apiClient.findPersonIdByName(
            apiToken: apiToken,
            name: director,
          );

          if (personId != null) {
            final credits = await widget.apiClient.getPersonCombinedCredits(
              apiToken: apiToken,
              personId: personId,
            );

            for (final work in credits.take(5)) {
              if (seenIds.add(work.id)) {
                results.add(_ScoredRecommendation(
                  item: work,
                  reason: 'Режиссёр: $director',
                  category: _RecCategoryFilter.fromDirectors,
                ));
              }
            }
          }
        } catch (_) {}
      }

      // 5. Explicit Favorite Persons (actors & directors)
      await TmdbFavoritePersonsService.instance.init();
      final favPersons = TmdbFavoritePersonsService.instance.favorites;
      for (final person in favPersons.take(4)) {
        if (!mounted) return;
        setState(() => _loadingStatus = 'Ищем проекты: ${person.name}...');
        try {
          final credits = await widget.apiClient.getPersonCombinedCredits(
            apiToken: apiToken,
            personId: person.id,
          );
          for (final work in credits.take(4)) {
            if (seenIds.add(work.id)) {
              results.add(_ScoredRecommendation(
                item: work,
                reason: '${person.localizedRole}: ${person.name}',
                category: _RecCategoryFilter.fromFavoritePersons,
              ));
            }
          }
        } catch (_) {}
      }

      // If library was empty or yielded few results, fallback to general popular top rated
      if (results.length < 6) {
        try {
          final popular = await widget.apiClient.discoverMedia(
            apiToken: apiToken,
            voteAverageGte: 7.8,
            voteCountGte: 500,
            sortBy: 'popularity.desc',
          );
          for (final p in popular) {
            if (seenIds.add(p.id)) {
              results.add(_ScoredRecommendation(
                item: p,
                reason: 'Высокий рейтинг зрителей',
                category: _RecCategoryFilter.all,
              ));
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _recommendations = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating smart recommendations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToWatchlist(TmdbMediaItem item) async {
    final toSave = item.copyWith(status: 'watchlist');
    await widget.syncService.saveMediaItem(
      toSave,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
    if (mounted) {
      setState(() {
        _addedItemIds.add(item.id);
        _existingLibraryIds.add(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${item.title}» добавлен в список «В планах»!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    final filtered = _selectedCategory == _RecCategoryFilter.all
        ? _recommendations
        : _recommendations.where((r) => r.category == _selectedCategory).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 920,
          constraints: const BoxConstraints(
            maxHeight: 740,
          ),
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
              // Top Dialog Header
              _buildDialogHeader(skin),
              Divider(height: 1, color: skin.divider),

              // Category Filter Tabs
              _buildCategoryFilters(skin),
              Divider(height: 1, color: skin.divider),

              // Content Area
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(skin)
                    : (filtered.isEmpty
                        ? _buildEmptyState(skin)
                        : _buildRecommendationsGrid(skin, filtered)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(Skin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: skin.sidebar,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Умные рекомендации',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'AI / TMDB',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Palette.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Персональная подборка на основе ваших оценок, любимых жанров и авторов',
                style: TextStyle(fontSize: 12, color: skin.faint),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: skin.muted),
            tooltip: 'Обновить подборку',
            onPressed: _isLoading ? null : _generateRecommendations,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: skin.muted),
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(Skin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: skin.sidebar.withValues(alpha: 0.5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _RecCategoryFilter.values
              .where((cat) =>
                  cat == _RecCategoryFilter.all ||
                  _recommendations.any((r) => r.category == cat))
              .map((cat) {
            final isSelected = _selectedCategory == cat;
            final count = cat == _RecCategoryFilter.all
                ? _recommendations.length
                : _recommendations.where((r) => r.category == cat).length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                avatar: Icon(
                  cat.icon,
                  size: 14,
                  color: isSelected ? Colors.white : skin.muted,
                ),
                label: Text(
                  '${cat.label} ($count)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : skin.text,
                  ),
                ),
                selectedColor: Palette.accent,
                backgroundColor: skin.surface,
                side: BorderSide(
                  color: isSelected ? Palette.accent : skin.outline,
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Skin skin) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Palette.accent),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _loadingStatus,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Подбираем идеальные совпадения под ваш кинематографический вкус',
            style: TextStyle(fontSize: 12, color: skin.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Skin skin) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter_outlined, size: 48, color: skin.faint),
            const SizedBox(height: 16),
            Text(
              'Не удалось сформировать рекомендации',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: skin.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте больше фильмов в медиатеку или поставьте оценки, чтобы система поняла ваши предпочтения.',
              style: TextStyle(fontSize: 12, color: skin.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generateRecommendations,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsGrid(Skin skin, List<_ScoredRecommendation> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.48,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, idx) {
          final rec = items[idx];
          return _buildItemCard(skin, rec);
        },
      ),
    );
  }

  Widget _buildItemCard(Skin skin, _ScoredRecommendation rec) {
    final item = rec.item;
    final isAdded = _addedItemIds.contains(item.id) || _existingLibraryIds.contains(item.id);

    return Container(
      decoration: BoxDecoration(
        color: skin.sidebar,
        borderRadius: BorderRadius.circular(UiRadius.control),
        border: Border.all(color: skin.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster Image with Badges
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
                  onTap: () {
                    if (widget.onNavigateToMovie != null) {
                      widget.onNavigateToMovie!(item);
                      return;
                    }
                    TmdbDetailDialog.show(
                      context,
                      item: item,
                      apiClient: widget.apiClient,
                      configService: widget.configService,
                      syncService: widget.syncService,
                      onOpenAsPage: widget.onOpenAsPage,
                    );
                  },
                  child: TmdbCachedImage(
                    imageUrl: item.posterUrl('w342') ?? item.posterUrl('w500'),
                    fit: BoxFit.cover,
                  ),
                ),

                // Top gradient
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Rating badge
                if (item.voteAverage != null && item.voteAverage! > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            item.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Media type badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (item.mediaType == 'tv' ? Colors.purple : Palette.accent).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metadata & Recommendation Reason
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reason Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Palette.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 10, color: Palette.accent),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          rec.reason,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Palette.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Title
                Tooltip(
                  message: item.title,
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.year.isNotEmpty ? item.year : '—',
                  style: TextStyle(fontSize: 10, color: skin.muted),
                ),
                const SizedBox(height: 8),

                // Add to Watchlist Button
                if (isAdded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(UiRadius.control),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 13, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'В медиатеке',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: FilledButton.icon(
                      onPressed: () => _addToWatchlist(item),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text(
                        'В планы',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Palette.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(UiRadius.control),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

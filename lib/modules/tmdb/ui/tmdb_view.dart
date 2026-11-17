import 'package:flutter/material.dart';
import '../../../../data/notes_repository.dart';
import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import 'tmdb_card.dart';
import 'tmdb_detail_dialog.dart';
import 'tmdb_random_picker_dialog.dart';
import 'tmdb_search_dialog.dart';
import 'tmdb_stats_dialog.dart';
import 'tmdb_recommendations_dialog.dart';
import 'tmdb_favorite_persons_dialog.dart';
import 'tmdb_filter_popover.dart';

enum TmdbViewMode { grid, kanban }

enum TmdbSortOption {
  dateAddedDesc('Сначала новые в базе', Icons.schedule_rounded),
  dateAddedAsc('Сначала старые в базе', Icons.history_rounded),
  yearDesc('По году (сначала новые)', Icons.calendar_today_rounded),
  yearAsc('По году (сначала старые)', Icons.calendar_today_outlined),
  myRatingDesc('По моей оценке', Icons.star_rounded),
  tmdbRatingDesc('По рейтингу TMDB', Icons.star_outline_rounded),
  kpRatingDesc('По рейтингу Кинопоиска', Icons.local_fire_department_rounded),
  titleAsc('По названию (А–Я)', Icons.sort_by_alpha_rounded),
  titleDesc('По названию (Я–А)', Icons.sort_by_alpha_rounded);

  final String label;
  final IconData icon;
  const TmdbSortOption(this.label, this.icon);
}

class TmdbView extends StatefulWidget {
  final NotesRepository repository;
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final ValueChanged<String> onOpenPage;

  const TmdbView({
    super.key,
    required this.repository,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    required this.onOpenPage,
  });

  @override
  State<TmdbView> createState() => _TmdbViewState();
}

class _TmdbViewState extends State<TmdbView> {
  TmdbViewMode _viewMode = TmdbViewMode.grid;
  String _activeFilter = 'all'; // 'all', 'movie', 'tv', 'watchlist', 'watching', 'watched', 'favorite'
  bool _isSyncing = false;
  late final TextEditingController _searchController;
  TmdbSortOption _sortOption = TmdbSortOption.dateAddedDesc;
  String? _selectedGenre;
  String? _selectedDecade; // '2020s', '2010s', '2000s', '1990s', '1980s', 'classic'
  double? _minRating; // 7.0, 7.5, 8.0, 8.5
  int? _maxRuntime; // 90, 120, 150, 999
  final GlobalKey _filterButtonKey = GlobalKey();

  int get _activeSmartFiltersCount {
    int count = 0;
    if (_selectedGenre != null) count++;
    if (_selectedDecade != null) count++;
    if (_minRating != null) count++;
    if (_maxRuntime != null) count++;
    return count;
  }

  void _resetSmartFilters() {
    setState(() {
      _selectedGenre = null;
      _selectedDecade = null;
      _minRating = null;
      _maxRuntime = null;
    });
  }

  void _openFilterPopover(List<TmdbMediaItem> all, List<TmdbMediaItem> filtered) {
    final allGenres = all
        .expand((i) => i.genres)
        .where((g) => g.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    TmdbFilterPopover.show(
      context: context,
      anchorKey: _filterButtonKey,
      selectedGenre: _selectedGenre,
      allGenres: allGenres,
      selectedDecade: _selectedDecade,
      minRating: _minRating,
      maxRuntime: _maxRuntime,
      totalCount: all.length,
      filteredCount: filtered.length,
      onGenreChanged: (val) => setState(() => _selectedGenre = val),
      onDecadeChanged: (val) => setState(() => _selectedDecade = val),
      onRatingChanged: (val) => setState(() => _minRating = val),
      onRuntimeChanged: (val) => setState(() => _maxRuntime = val),
      onResetAll: _resetSmartFilters,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch([String? initialQuery]) {
    TmdbSearchDialog.show(
      context,
      apiClient: widget.apiClient,
      configService: widget.configService,
      syncService: widget.syncService,
      onPageCreated: (pageId) => widget.onOpenPage(pageId),
      initialQuery: initialQuery,
    );
  }

  void _openDetailDialog(TmdbMediaItem item, [List<TmdbMediaItem>? localItems]) {
    TmdbDetailDialog.show(
      context,
      item: item,
      apiClient: widget.apiClient,
      configService: widget.configService,
      syncService: widget.syncService,
      onOpenAsPage: (pageId) => widget.onOpenPage(pageId),
      localItems: localItems,
    );
  }

  void _openRandomPicker(List<TmdbMediaItem> allItems) {
    TmdbRandomPickerDialog.show(
      context,
      allItems: allItems,
      onSelect: (item) => _openDetailDialog(item),
      onStartWatching: (item) async {
        await _updateItemStatus(item, 'watching');
        _openDetailDialog(item);
      },
    );
  }

  void _openStatsDashboard(List<TmdbMediaItem> allItems) {
    TmdbStatsDialog.show(context, allItems);
  }

  void _openSmartRecommendations(List<TmdbMediaItem> allItems) {
    TmdbSmartRecommendationsDialog.show(
      context,
      libraryItems: allItems,
      apiClient: widget.apiClient,
      configService: widget.configService,
      syncService: widget.syncService,
      onOpenAsPage: (pageId) => widget.onOpenPage(pageId),
    );
  }

  void _openFavoritePersons(List<TmdbMediaItem> allItems) {
    TmdbFavoritePersonsDialog.show(
      context,
      localItems: allItems,
      apiClient: widget.apiClient,
      configService: widget.configService,
      syncService: widget.syncService,
      onFilterByPerson: (personName) {
        _searchController.text = personName;
      },
    );
  }

  Future<void> _syncWithTmdb() async {
    if (!widget.configService.isAccountConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для синхронизации подключите аккаунт TMDB в настройках.'),
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final count = await widget.syncService.syncFromTmdb(
        client: widget.apiClient,
        config: widget.configService,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Синхронизация завершена! Обновлено элементов: $count.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка синхронизации: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _updateItemStatus(TmdbMediaItem item, String newStatus) async {
    final updated = item.copyWith(status: newStatus);
    await widget.syncService.saveMediaItem(
      updated,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
  }

  Future<void> _toggleItemFavorite(TmdbMediaItem item, bool isFav) async {
    final updated = item.copyWith(isFavorite: isFav);
    await widget.syncService.saveMediaItem(
      updated,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
  }

  Future<void> _updateItemRating(TmdbMediaItem item, double? rating) async {
    final updated = item.copyWith(userRating: rating);
    await widget.syncService.saveMediaItem(
      updated,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
  }

  Future<void> _deleteItem(TmdbMediaItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из медиатеки?'),
        content: Text('Фильм «${item.title}» будет перемещен в корзину.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.syncService.deleteMediaItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${item.title}» удален из медиатеки.')),
        );
      }
    }
  }

  void _playTrailer(TmdbMediaItem item) {
    if (item.youtubeTrailerUrl != null) {
      openExternalUrl(item.youtubeTrailerUrl!);
    } else {
      _openDetailDialog(item);
    }
  }

  List<TmdbMediaItem> _filterAndSortItems(List<TmdbMediaItem> items) {
    List<TmdbMediaItem> list;

    // 1. Status / media type filter
    switch (_activeFilter) {
      case 'movie':
        list = items.where((i) => i.mediaType == 'movie').toList();
        break;
      case 'tv':
        list = items.where((i) => i.mediaType == 'tv').toList();
        break;
      case 'watchlist':
        list = items.where((i) => i.status == 'watchlist').toList();
        break;
      case 'watching':
        list = items.where((i) => i.status == 'watching').toList();
        break;
      case 'watched':
        list = items.where((i) => i.status == 'watched').toList();
        break;
      case 'favorite':
        list = items.where((i) => i.isFavorite).toList();
        break;
      default:
        list = List.of(items);
        break;
    }

    // 2. Genre filter
    if (_selectedGenre != null && _selectedGenre!.isNotEmpty) {
      list = list.where((i) => i.genres.contains(_selectedGenre)).toList();
    }

    // 2.1. Decade filter
    if (_selectedDecade != null) {
      list = list.where((i) {
        final year = int.tryParse(i.year) ?? 0;
        if (year <= 0) return false;
        switch (_selectedDecade) {
          case '2020s':
            return year >= 2020;
          case '2010s':
            return year >= 2010 && year < 2020;
          case '2000s':
            return year >= 2000 && year < 2010;
          case '1990s':
            return year >= 1990 && year < 2000;
          case '1980s':
            return year >= 1980 && year < 1990;
          case 'classic':
            return year < 1980;
          default:
            return true;
        }
      }).toList();
    }

    // 2.2. Min rating filter
    if (_minRating != null) {
      list = list.where((i) {
        final score = i.userRating ?? i.voteAverage ?? 0.0;
        return score >= _minRating!;
      }).toList();
    }

    // 2.3. Runtime filter
    if (_maxRuntime != null) {
      list = list.where((i) {
        if (i.runtime == null || i.runtime! <= 0) return true;
        if (_maxRuntime == 90) return i.runtime! <= 90;
        if (_maxRuntime == 120) return i.runtime! <= 120;
        if (_maxRuntime == 150) return i.runtime! <= 150;
        if (_maxRuntime == 999) return i.runtime! > 150;
        return true;
      }).toList();
    }

    // 3. Search query filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((i) {
        final title = i.title.toLowerCase();
        final orig = i.originalTitle?.toLowerCase() ?? '';
        final dir = i.director?.toLowerCase() ?? '';
        final yr = i.year;
        final hasGenre = i.genres.any((g) => g.toLowerCase().contains(query));
        final hasActor = i.cast.any((c) => c.name.toLowerCase().contains(query) || (c.character?.toLowerCase().contains(query) ?? false));
        final hasCrew = i.crew.any((c) => c.name.toLowerCase().contains(query) || c.job.toLowerCase().contains(query));
        return title.contains(query) ||
            orig.contains(query) ||
            dir.contains(query) ||
            yr.contains(query) ||
            hasGenre ||
            hasActor ||
            hasCrew;
      }).toList();
    }

    // 4. Sorting
    switch (_sortOption) {
      case TmdbSortOption.dateAddedAsc:
        list = list.reversed.toList();
        break;
      case TmdbSortOption.yearDesc:
        list.sort((a, b) => b.year.compareTo(a.year));
        break;
      case TmdbSortOption.yearAsc:
        list.sort((a, b) => a.year.compareTo(b.year));
        break;
      case TmdbSortOption.myRatingDesc:
        list.sort((a, b) => (b.userRating ?? -1.0).compareTo(a.userRating ?? -1.0));
        break;
      case TmdbSortOption.tmdbRatingDesc:
        list.sort((a, b) => (b.voteAverage ?? -1.0).compareTo(a.voteAverage ?? -1.0));
        break;
      case TmdbSortOption.kpRatingDesc:
        list.sort((a, b) => (b.kpRating ?? -1.0).compareTo(a.kpRating ?? -1.0));
        break;
      case TmdbSortOption.titleAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case TmdbSortOption.titleDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case TmdbSortOption.dateAddedDesc:
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return StreamBuilder<List<TmdbMediaItem>>(
      stream: widget.syncService.watchLocalItems(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final filteredItems = _filterAndSortItems(allItems);

        return Scaffold(
          backgroundColor: skin.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Toolbar
              _buildHeader(skin, allItems.length, allItems),
              Divider(height: 1, color: skin.divider),

              // Filter Chips, Search & Sort
              _buildFilterChips(skin, allItems, filteredItems),
              Divider(height: 1, color: skin.divider),

              // Main Media Area (Isolated with RepaintBoundary for 60/120fps smooth panel transitions)
              Expanded(
                child: RepaintBoundary(
                  child: allItems.isEmpty
                      ? _buildEmptyState(skin)
                      : (filteredItems.isEmpty
                          ? _buildSearchEmptyState(skin)
                          : (_viewMode == TmdbViewMode.grid
                              ? _buildGridView(filteredItems, skin)
                              : _buildKanbanView(filteredItems, skin))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Skin skin, int totalCount, List<TmdbMediaItem> allItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: skin.sidebar,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_outlined, size: 20, color: Palette.accent),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Фильмы и Сериалы',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: skin.hover,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: skin.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                totalCount > 0
                    ? '$totalCount в базе • ${allItems.where((i) => i.status == 'watched').length} просмотрено'
                    : 'Каталог фильмов и сериалов',
                style: TextStyle(fontSize: 11.5, color: skin.faint),
              ),
            ],
          ),
          const Spacer(),

          // Secondary Tool Actions Group
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Умные рекомендации',
                icon: const Icon(Icons.auto_awesome_rounded, size: 19, color: Palette.accent),
                onPressed: () => _openSmartRecommendations(allItems),
                splashRadius: 18,
              ),
              IconButton(
                tooltip: 'Любимые актёры и режиссёры',
                icon: const Icon(Icons.people_alt_outlined, size: 19),
                onPressed: () => _openFavoritePersons(allItems),
                splashRadius: 18,
              ),
              IconButton(
                tooltip: 'Случайный выбор (Что посмотреть?)',
                icon: const Icon(Icons.casino_outlined, size: 19),
                onPressed: allItems.isEmpty ? null : () => _openRandomPicker(allItems),
                splashRadius: 18,
              ),
              IconButton(
                tooltip: 'Статистика медиатеки',
                icon: const Icon(Icons.bar_chart_rounded, size: 20),
                onPressed: allItems.isEmpty ? null : () => _openStatsDashboard(allItems),
                splashRadius: 18,
              ),
              IconButton(
                tooltip: 'Синхронизировать с TMDB',
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 19),
                onPressed: _isSyncing ? null : _syncWithTmdb,
                splashRadius: 18,
              ),
            ],
          ),

          const SizedBox(width: 8),
          Container(height: 20, width: 1, color: skin.outline),
          const SizedBox(width: 12),

          // View Mode Selector
          SegmentedButton<TmdbViewMode>(
            segments: const [
              ButtonSegment(
                value: TmdbViewMode.grid,
                icon: Icon(Icons.grid_view_rounded, size: 15),
                tooltip: 'Галерея постеров',
              ),
              ButtonSegment(
                value: TmdbViewMode.kanban,
                icon: Icon(Icons.view_column_outlined, size: 15),
                tooltip: 'Канбан-доска',
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) => setState(() => _viewMode = set.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),

          // Primary Search / Add Button
          FilledButton.icon(
            onPressed: _openSearch,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Добавить фильм', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: Palette.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Skin skin, List<TmdbMediaItem> all, List<TmdbMediaItem> filtered) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlBg = isDark ? const Color(0x1FFFFFFF) : const Color(0xFFEFEFF2);

    Widget chip(String key, String label, int count) {
      final isSelected = _activeFilter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: () => setState(() => _activeFilter = key),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? Palette.accent : controlBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : skin.text,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : skin.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final moviesCount = all.where((i) => i.mediaType == 'movie').length;
    final tvCount = all.where((i) => i.mediaType == 'tv').length;
    final watchlistCount = all.where((i) => i.status == 'watchlist').length;
    final watchingCount = all.where((i) => i.status == 'watching').length;
    final watchedCount = all.where((i) => i.status == 'watched').length;
    final favCount = all.where((i) => i.isFavorite).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: skin.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Instant Search + Genre Filter + Sort Dropdown (Apple HIG / Things 3 38px Capsule, Perfectly Centered)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: controlBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 17, color: skin.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (query) {
                            if (query.trim().isNotEmpty) {
                              _openSearch(query.trim());
                            }
                          },
                          style: TextStyle(
                            fontSize: 12.5,
                            color: skin.text,
                            height: 1.25,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Поиск по названию, режиссёру, актёру, жанру или году...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: skin.muted.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _openSearch(_searchController.text.trim()),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Palette.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.travel_explore_rounded, size: 13, color: Palette.accent),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'В TMDB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Palette.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: Icon(Icons.close, size: 15, color: skin.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Smart Filters Popover Trigger Button (Capsule Things 3 Style)
              GestureDetector(
                key: _filterButtonKey,
                onTap: () => _openFilterPopover(all, filtered),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _activeSmartFiltersCount > 0
                          ? Palette.accent.withValues(alpha: 0.14)
                          : controlBg,
                      borderRadius: BorderRadius.circular(20),
                      border: _activeSmartFiltersCount > 0
                          ? Border.all(color: Palette.accent, width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: _activeSmartFiltersCount > 0
                              ? Palette.accent
                              : skin.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Фильтры',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _activeSmartFiltersCount > 0
                                ? Palette.accent
                                : skin.text,
                          ),
                        ),
                        if (_activeSmartFiltersCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Palette.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_activeSmartFiltersCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Menu Dropdown (Capsule style height 38, Bounded Height, Things 3 Popover)
              PopupMenuButton<TmdbSortOption>(
                tooltip: 'Сортировка',
                initialValue: _sortOption,
                constraints: const BoxConstraints(maxHeight: 340, minWidth: 210, maxWidth: 260),
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: skin.divider),
                ),
                color: skin.surface,
                onSelected: (opt) => setState(() => _sortOption = opt),
                itemBuilder: (ctx) => TmdbSortOption.values.map((opt) {
                  final isSelected = _sortOption == opt;
                  return PopupMenuItem<TmdbSortOption>(
                    value: opt,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: _TmdbPopupMenuItem(
                      label: opt.label,
                      isSelected: isSelected,
                      skin: skin,
                      icon: opt.icon,
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: controlBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert_rounded, size: 16, color: skin.muted),
                      const SizedBox(width: 6),
                      Text(
                        _sortOption.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: skin.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Category & Status Filter Chips (Capsule Things 3 Style)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('all', 'Все', all.length),
                chip('movie', 'Фильмы', moviesCount),
                chip('tv', 'Сериалы', tvCount),
                const SizedBox(width: 4),
                Container(height: 16, width: 1, color: skin.divider),
                const SizedBox(width: 8),
                chip('watchlist', 'В планах', watchlistCount),
                chip('watching', 'Смотрю', watchingCount),
                chip('watched', 'Просмотрено', watchedCount),
                chip('favorite', 'Избранное', favCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState(Skin skin) {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Palette.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.travel_explore_rounded, size: 42, color: Palette.accent),
                ),
                const SizedBox(height: 18),
                Text(
                  '«$query» не найден в медиатеке',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: skin.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'В вашей сохраненной коллекции нет такого фильма или сериала. Хотите найти его в онлайн-базе TMDB и добавить в 1 клик?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: skin.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openSearch(query),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: Text(
                        query.length > 20 ? 'Искать в онлайн-базе TMDB' : 'Искать «$query» в TMDB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _searchController.clear(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                      child: Text('Очистить поиск', style: TextStyle(color: skin.muted, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: skin.sidebar,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.filter_alt_off_outlined, size: 40, color: skin.faint),
          ),
          const SizedBox(height: 14),
          Text(
            'Нет фильмов по выбранным фильтрам',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: skin.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуйте выбрать другой жанр или статус',
            style: TextStyle(fontSize: 12, color: skin.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _activeFilter = 'all';
                _resetSmartFilters();
              });
            },
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Сбросить фильтры', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Skin skin) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.movie_filter_outlined, size: 54, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          Text(
            'Ваша медиатека фильмов пуста',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: skin.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Нажмите «Найти в TMDB», чтобы добавить фильмы, или синхронизируйте со своим аккаунтом.',
            style: TextStyle(fontSize: 13, color: skin.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _openSearch,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Найти фильм или сериал'),
              ),
              if (widget.configService.isAccountConnected) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _syncWithTmdb,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Синхронизировать сейчас'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<TmdbMediaItem> items, Skin skin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic column count based on available width
        final crossAxisCount = (constraints.maxWidth / 170).floor().clamp(2, 8);

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55, // Poster ratio + info card
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return TmdbCard(
              item: item,
              onTap: () => _openDetailDialog(item),
              onStatusChanged: (newStatus) => _updateItemStatus(item, newStatus),
              onFavoriteToggled: (fav) => _toggleItemFavorite(item, fav),
              onRatingChanged: (rating) => _updateItemRating(item, rating),
              onDelete: () => _deleteItem(item),
              onPlayTrailer: () => _playTrailer(item),
            );
          },
        );
      },
    );
  }

  Widget _buildKanbanView(List<TmdbMediaItem> allItems, Skin skin) {
    final columns = [
      ('watchlist', 'В планах', Colors.blueGrey, Icons.bookmark_outline),
      ('watching', 'Смотрю', Colors.amber.shade700, Icons.play_circle_outline),
      ('watched', 'Просмотрено', Colors.green.shade600, Icons.check_circle_outline),
      ('dropped', 'Брошено', Colors.red.shade600, Icons.cancel_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      scrollDirection: Axis.horizontal,
      children: columns.map((col) {
        final colKey = col.$1;
        final colLabel = col.$2;
        final colColor = col.$3;
        final colIcon = col.$4;
        final colItems = allItems.where((i) => i.status == colKey).toList();

        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: skin.sidebar.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(UiRadius.card),
            border: Border.all(color: skin.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(colIcon, size: 16, color: colColor),
                    const SizedBox(width: 8),
                    Text(
                      colLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: skin.text,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: skin.hover,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${colItems.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: skin.divider),

              // Cards in Column
              Expanded(
                child: colItems.isEmpty
                    ? Center(
                        child: Text(
                          'Нет записей',
                          style: TextStyle(color: skin.faint, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: colItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = colItems[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              height: 250,
                              child: TmdbCard(
                                item: item,
                                onTap: () => _openDetailDialog(item),
                                onStatusChanged: (newStatus) => _updateItemStatus(item, newStatus),
                                onFavoriteToggled: (fav) => _toggleItemFavorite(item, fav),
                                onRatingChanged: (rating) => _updateItemRating(item, rating),
                                onDelete: () => _deleteItem(item),
                                onPlayTrailer: () => _playTrailer(item),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TmdbPopupMenuItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Skin skin;
  final IconData? icon;

  const _TmdbPopupMenuItem({
    required this.label,
    required this.isSelected,
    required this.skin,
    this.icon,
  });

  @override
  State<_TmdbPopupMenuItem> createState() => _TmdbPopupMenuItemState();
}

class _TmdbPopupMenuItemState extends State<_TmdbPopupMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Palette.accent.withValues(alpha: 0.12)
              : (_isHovered ? widget.skin.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 14, color: widget.isSelected ? Palette.accent : widget.skin.muted),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected ? Palette.accent : widget.skin.text,
                ),
              ),
            ),
            if (widget.isSelected)
              const Icon(Icons.check_rounded, size: 15, color: Palette.accent),
          ],
        ),
      ),
    );
  }
}

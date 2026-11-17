import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/tmdb_favorite_persons_service.dart';
import '../services/tmdb_image_cache.dart';
import 'tmdb_modal_host.dart';
import 'tmdb_person_dialog.dart';

class TmdbFavoritePersonsDialog extends StatefulWidget {
  final List<TmdbMediaItem> localItems;
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final ValueChanged<String>? onFilterByPerson;
  final VoidCallback? onBack;
  final void Function(int? personId, String name, String? role, String? profilePath)? onNavigateToPerson;

  const TmdbFavoritePersonsDialog({
    super.key,
    required this.localItems,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    this.onFilterByPerson,
    this.onBack,
    this.onNavigateToPerson,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TmdbMediaItem> localItems,
    required TmdbApiClient apiClient,
    required TmdbConfigService configService,
    required TmdbDatabaseSync syncService,
    ValueChanged<String>? onFilterByPerson,
  }) {
    return TmdbModalHost.show(
      context,
      initialRoute: TmdbFavoritePersonsRoute(
        onFilterByPerson: onFilterByPerson,
      ),
      apiClient: apiClient,
      configService: configService,
      syncService: syncService,
      localItems: localItems,
    );
  }

  @override
  State<TmdbFavoritePersonsDialog> createState() =>
      _TmdbFavoritePersonsDialogState();
}

class _TmdbFavoritePersonsDialogState extends State<TmdbFavoritePersonsDialog> {
  final _favService = TmdbFavoritePersonsService.instance;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _activeCategory = 'all'; // 'all', 'directors', 'actors'
  bool _isSearchingOnline = false;
  List<Map<String, dynamic>> _onlineResults = [];

  @override
  void initState() {
    super.initState();
    _favService.init().then((_) {
      if (mounted) setState(() {});
    });
    _favService.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _favService.removeListener(_onFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _onlineResults = [];
        _isSearchingOnline = false;
      });
      return;
    }

    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performOnlineSearch(trimmed);
    });
  }

  Future<void> _performOnlineSearch(String query) async {
    if (!widget.configService.hasApiToken) return;

    setState(() => _isSearchingOnline = true);
    try {
      final results = await widget.apiClient.searchPersons(
        apiToken: widget.configService.apiToken!,
        query: query,
      );
      if (mounted) {
        setState(() {
          _onlineResults = results;
          _isSearchingOnline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingOnline = false);
      }
    }
  }

  int _countMediaForPerson(String personName) {
    final lower = personName.toLowerCase().trim();
    return widget.localItems.where((item) {
      if (item.director?.toLowerCase().contains(lower) ?? false) return true;
      if (item.directors.any((d) => d.name.toLowerCase().contains(lower))) {
        return true;
      }
      if (item.cast.any((c) => c.name.toLowerCase().contains(lower))) {
        return true;
      }
      return false;
    }).length;
  }

  List<TmdbFavoritePerson> get _filteredLocalFavorites {
    final query = _searchController.text.trim().toLowerCase();
    return _favService.favorites.where((p) {
      if (_activeCategory == 'directors') {
        final role = p.localizedRole.toLowerCase();
        if (!role.contains('режиссёр')) return false;
      } else if (_activeCategory == 'actors') {
        final role = p.localizedRole.toLowerCase();
        if (!role.contains('актёр')) return false;
      }

      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }

      return true;
    }).toList();
  }

  void _openPersonProfile({
    required int? personId,
    required String name,
    String? role,
    String? profilePath,
  }) {
    if (widget.onNavigateToPerson != null) {
      widget.onNavigateToPerson!(personId, name, role, profilePath);
      return;
    }
    TmdbPersonDialog.show(
      context: context,
      personId: personId,
      personName: name,
      initialRole: role,
      initialProfilePath: profilePath,
      apiClient: widget.apiClient,
      configService: widget.configService,
      syncService: widget.syncService,
      localItems: widget.localItems,
    );
  }

  String _localizeDepartment(String? dept) {
    if (dept == null || dept.isEmpty) return 'Кинематографист';
    final d = dept.toLowerCase();
    if (d.contains('direct')) return 'Режиссёр';
    if (d.contains('act')) return 'Актёр';
    if (d.contains('writ')) return 'Сценарист';
    if (d.contains('produc')) return 'Продюсер';
    if (d.contains('camera') || d.contains('photo')) return 'Оператор';
    if (d.contains('sound') || d.contains('music')) return 'Композитор';
    return dept;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlBg =
        isDark ? const Color(0x1FFFFFFF) : const Color(0xFFEFEFF2);
    final query = _searchController.text.trim();
    final localList = _filteredLocalFavorites;
    final totalFavoritesCount = _favService.favorites.length;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 18, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Любимые актёры и режиссёры',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: skin.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: skin.hover,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalFavoritesCount',
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
                          'Отслеживайте фильмографии и получайте персональные рекомендации',
                          style: TextStyle(fontSize: 12, color: skin.muted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Toolbar: Search + Category Pills
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: skin.sidebar.withValues(alpha: 0.4),
                  border: Border(bottom: BorderSide(color: skin.outline)),
                ),
                child: Row(
                  children: [
                    // Search bar
                    Expanded(
                      flex: 4,
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
                            Icon(Icons.search, size: 16, color: skin.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                onSubmitted: (q) {
                                  if (q.trim().isNotEmpty) {
                                    _performOnlineSearch(q.trim());
                                  }
                                },
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: skin.text,
                                  height: 1.25,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText:
                                      'Поиск актёра или режиссёра (например, Райан Гослинг, Нолан)...',
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: skin.muted.withValues(alpha: 0.85),
                                    height: 1.25,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_isSearchingOnline)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Palette.accent),
                                  ),
                                ),
                              ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                child: Icon(Icons.close,
                                    size: 15, color: skin.muted),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Filter Pills
                    _categoryPill('all', 'Все', totalFavoritesCount, controlBg),
                    const SizedBox(width: 6),
                    _categoryPill(
                      'directors',
                      'Режиссёры',
                      _favService.favorites
                          .where((p) => p.localizedRole
                              .toLowerCase()
                              .contains('режиссёр'))
                          .length,
                      controlBg,
                    ),
                    const SizedBox(width: 6),
                    _categoryPill(
                      'actors',
                      'Актёры',
                      _favService.favorites
                          .where((p) =>
                              p.localizedRole.toLowerCase().contains('актёр'))
                          .length,
                      controlBg,
                    ),
                  ],
                ),
              ),

              // 3. Main Content: Favorites list, Online Search Results, or Empty State
              Expanded(
                child: query.isEmpty && totalFavoritesCount == 0
                    ? _buildInitialEmptyState(skin)
                    : _buildContent(skin, localList, query),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      Skin skin, List<TmdbFavoritePerson> localList, String query) {
    final hasLocal = localList.isNotEmpty;
    final hasOnline = _onlineResults.isNotEmpty;

    if (!hasLocal && !hasOnline && !_isSearchingOnline && query.isNotEmpty) {
      return _buildSearchNotFound(skin, query);
    }

    return CustomScrollView(
      slivers: [
        // Section A: Local Favorites (if any matches)
        if (hasLocal) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      size: 15, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Text(
                    'В ваших любимых (${localList.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 460,
                mainAxisExtent: 96,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final person = localList[idx];
                  final inLibraryCount = _countMediaForPerson(person.name);
                  return _buildLocalPersonCard(skin, person, inLibraryCount);
                },
                childCount: localList.length,
              ),
            ),
          ),
        ],

        // Section B: Online TMDB Results (when searching)
        if (query.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.travel_explore_rounded,
                      size: 16, color: Palette.accent),
                  const SizedBox(width: 6),
                  Text(
                    _isSearchingOnline
                        ? 'Поиск «$query» в базе TMDB...'
                        : 'Результаты в онлайн-каталоге TMDB (${_onlineResults.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                  if (_isSearchingOnline) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Palette.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasOnline)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 460,
                  mainAxisExtent: 96,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final raw = _onlineResults[idx];
                    return _buildOnlinePersonCard(skin, raw);
                  },
                  childCount: _onlineResults.length,
                ),
              ),
            ),
        ],

        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _categoryPill(
      String key, String label, int count, Color controlBg) {
    final isSelected = _activeCategory == key;
    return InkWell(
      onTap: () => setState(() => _activeCategory = key),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Palette.accent : controlBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : context.skin.text,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : context.skin.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPersonCard(
      Skin skin, TmdbFavoritePerson person, int inLibraryCount) {
    return Container(
      decoration: BoxDecoration(
        color: skin.sidebar.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: skin.outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _openPersonProfile(
              personId: person.id,
              name: person.name,
              role: person.department,
              profilePath: person.profilePath,
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: skin.surface,
              child: ClipOval(
                child: person.profileUrl != null
                    ? TmdbCachedImage(
                        imageUrl: person.profileUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: skin.hover,
                        child:
                            Icon(Icons.person, size: 26, color: skin.muted),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _openPersonProfile(
                    personId: person.id,
                    name: person.name,
                    role: person.department,
                    profilePath: person.profilePath,
                  ),
                  child: Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Palette.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        person.localizedRole,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Palette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        inLibraryCount > 0
                            ? '$inLibraryCount в базе'
                            : 'Нет в базе',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: inLibraryCount > 0
                              ? skin.muted
                              : skin.muted.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Фильмография',
                icon: const Icon(Icons.movie_creation_outlined, size: 18),
                splashRadius: 18,
                onPressed: () => _openPersonProfile(
                  personId: person.id,
                  name: person.name,
                  role: person.department,
                  profilePath: person.profilePath,
                ),
              ),
              IconButton(
                tooltip: 'Удалить из любимых',
                icon: const Icon(Icons.favorite_rounded,
                    size: 19, color: Colors.redAccent),
                splashRadius: 18,
                onPressed: () async {
                  await _favService.removeFavorite(person.id);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnlinePersonCard(Skin skin, Map<String, dynamic> raw) {
    final id = (raw['id'] as num?)?.toInt() ?? 0;
    final name = raw['name'] as String? ?? 'Неизвестно';
    final profilePath = raw['profile_path'] as String?;
    final dept = raw['known_for_department'] as String?;
    final localizedRole = _localizeDepartment(dept);
    final isFav = _favService.isFavorite(id, name: name);

    // Known for titles
    final knownForRaw = raw['known_for'] as List<dynamic>? ?? [];
    final knownTitles = knownForRaw
        .whereType<Map<String, dynamic>>()
        .map((m) => (m['title'] ?? m['name'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .take(2)
        .toList();
    final knownStr =
        knownTitles.isNotEmpty ? '«${knownTitles.join('», «')}»' : '';

    final photoUrl = profilePath != null
        ? 'https://image.tmdb.org/t/p/w200$profilePath'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFav
              ? Colors.redAccent.withValues(alpha: 0.35)
              : skin.outline,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _openPersonProfile(
              personId: id,
              name: name,
              role: dept,
              profilePath: profilePath,
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: skin.sidebar,
              child: ClipOval(
                child: photoUrl != null
                    ? TmdbCachedImage(
                        imageUrl: photoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: skin.hover,
                        child:
                            Icon(Icons.person, size: 26, color: skin.muted),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _openPersonProfile(
                    personId: id,
                    name: name,
                    role: dept,
                    profilePath: profilePath,
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Palette.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        localizedRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Palette.accent,
                        ),
                      ),
                    ),
                    if (knownStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          knownStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: skin.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Actions (Unified Icon Buttons)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Фильмография',
                icon: const Icon(Icons.movie_creation_outlined, size: 18),
                splashRadius: 18,
                onPressed: () => _openPersonProfile(
                  personId: id,
                  name: name,
                  role: dept,
                  profilePath: profilePath,
                ),
              ),
              IconButton(
                tooltip: isFav ? 'Удалить из любимых' : 'Добавить в любимые',
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 19,
                  color: isFav ? Colors.redAccent : skin.muted,
                ),
                splashRadius: 18,
                onPressed: () async {
                  final nowFav = await _favService.toggleFavorite(
                    id: id,
                    name: name,
                    profilePath: profilePath,
                    department: dept,
                  );
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nowFav
                              ? '«$name» добавлен в любимые персоны!'
                              : '«$name» удален из любимых.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialEmptyState(Skin skin) {
    const popularExamples = [
      'Райан Гослинг',
      'Кристофер Нолан',
      'Дени Вильнёв',
      'Квентин Тарантино',
      'Леонардо ДиКаприо',
      'Зендея',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border_rounded,
                  size: 46, color: Colors.redAccent),
            ),
            const SizedBox(height: 18),
            Text(
              'Список любимых персон пуст',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: skin.text,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                'Введите имя актёра или режиссёра в строку поиска выше, чтобы найти его в TMDB и добавить в избранное, или выберите из популярных:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: skin.muted, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),

            // Quick suggestion pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: popularExamples.map((name) {
                return InkWell(
                  onTap: () {
                    _searchController.text = name;
                    _onSearchChanged(name);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: skin.sidebar,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: skin.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search,
                            size: 13, color: Palette.accent),
                        const SizedBox(width: 5),
                        Text(
                          name,
                          style: TextStyle(fontSize: 12, color: skin.text),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchNotFound(Skin skin, String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded, size: 44, color: skin.faint),
          const SizedBox(height: 14),
          Text(
            'Персона «$query» не найдена',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: skin.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Проверьте правильность написания имени или фамилии',
            style: TextStyle(fontSize: 12, color: skin.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Сбросить поиск', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

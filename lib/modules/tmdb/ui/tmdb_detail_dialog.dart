import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../ui/design_tokens.dart';
import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/tmdb_image_cache.dart';
import '../services/kinopoisk_service.dart';
import 'detail/tmdb_cast_tab.dart';
import 'detail/tmdb_detail_header.dart';
import 'detail/tmdb_detail_models.dart';
import 'detail/tmdb_detail_sidebar.dart';
import 'detail/tmdb_notes_tab.dart';
import 'detail/tmdb_overview_tab.dart';
import 'detail/tmdb_rating_section.dart';
import 'detail/tmdb_recommendations_tab.dart';
import 'tmdb_settings_view.dart';
import 'tmdb_person_dialog.dart';
import 'tmdb_modal_host.dart';

export 'detail/tmdb_detail_models.dart';

class TmdbDetailDialog extends StatefulWidget {
  final TmdbMediaItem item;
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final ValueChanged<String>? onOpenAsPage;
  final VoidCallback? onBack;
  final void Function(int? personId, String name, String? role, String? profilePath)? onNavigateToPerson;
  final ValueChanged<TmdbMediaItem>? onNavigateToMovie;

  const TmdbDetailDialog({
    super.key,
    required this.item,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    this.onOpenAsPage,
    this.onBack,
    this.onNavigateToPerson,
    this.onNavigateToMovie,
  });

  static Future<void> show(
    BuildContext context, {
    required TmdbMediaItem item,
    required TmdbApiClient apiClient,
    required TmdbConfigService configService,
    required TmdbDatabaseSync syncService,
    ValueChanged<String>? onOpenAsPage,
    List<TmdbMediaItem>? localItems,
  }) async {
    final items = localItems ?? await syncService.loadLocalItems();
    if (!context.mounted) return;
    return TmdbModalHost.show(
      context,
      initialRoute: TmdbMovieDetailRoute(
        item: item,
        onOpenAsPage: onOpenAsPage,
      ),
      apiClient: apiClient,
      configService: configService,
      syncService: syncService,
      localItems: items,
      onOpenPage: onOpenAsPage,
    );
  }

  @override
  State<TmdbDetailDialog> createState() => _TmdbDetailDialogState();
}

class _TmdbDetailDialogState extends State<TmdbDetailDialog> with SingleTickerProviderStateMixin {
  late TmdbMediaItem _item;
  late final TextEditingController _noteController;
  Timer? _noteDebounce;
  bool _isLoadingDetails = false;
  bool _isLoadingKp = false;
  List<TmdbMediaItem>? _recommendations;
  bool _isLoadingRecommendations = false;
  final Set<int> _addedToWatchlist = {};
  Map<int, String> _libraryStatusByTmdbId = {};
  TmdbDetailTab _activeTab = TmdbDetailTab.overview;
  bool _isSavingNote = false;
  late final AnimationController _heartAnim;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _noteController = TextEditingController(text: _item.personalNote ?? '');
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 55),
    ]).animate(_heartAnim);

    _fetchFullDetails();
    if (widget.configService.hasKpToken && _item.kpRating == null) {
      _fetchKinopoiskRatingIfNeeded();
    }
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    _noteController.dispose();
    _heartAnim.dispose();
    super.dispose();
  }

  Future<void> _fetchKinopoiskRatingIfNeeded({bool force = false}) async {
    if (!widget.configService.hasKpToken) return;
    if (!force && _item.kpRating != null) return;

    setState(() => _isLoadingKp = true);
    try {
      final kpService = KinopoiskService();
      final kpData = await kpService.fetchRating(
        token: widget.configService.kpToken!,
        title: _item.title,
        originalTitle: _item.originalTitle,
        year: _item.year,
        mediaType: _item.mediaType,
      );

      if (kpData != null && mounted) {
        final updated = _item.copyWith(
          kpRating: kpData.rating,
          kpVotes: kpData.votes,
          kpId: kpData.filmId != null ? kpData.filmId.toString() : _item.kpId,
          imdbRating: kpData.imdbRating ?? _item.imdbRating,
          imdbId: kpData.imdbId ?? _item.imdbId,
        );

        setState(() {
          _item = updated;
          _isLoadingKp = false;
        });

        await widget.syncService.saveMediaItem(updated, syncToTmdb: false);
      } else {
        if (mounted) setState(() => _isLoadingKp = false);
      }
    } catch (e) {
      debugPrint('TmdbDetailDialog: Kinopoisk fetch error: $e');
      if (mounted) setState(() => _isLoadingKp = false);
    }
  }

  Future<void> _fetchFullDetails({bool force = false}) async {
    if (!widget.configService.hasApiToken) return;
    if (!force && _item.crew.isNotEmpty && _item.cast.isNotEmpty && _item.runtime != null) {
      return;
    }

    setState(() => _isLoadingDetails = true);
    try {
      final detailed = await widget.apiClient.getDetails(
        apiToken: widget.configService.apiToken!,
        id: _item.id,
        mediaType: _item.mediaType,
      );

      if (detailed != null && mounted) {
        final updated = _item.copyWith(
          overview: detailed.overview?.isNotEmpty == true ? detailed.overview : _item.overview,
          tagline: detailed.tagline?.isNotEmpty == true ? detailed.tagline : _item.tagline,
          runtime: detailed.runtime ?? _item.runtime,
          genres: detailed.genres.isNotEmpty ? detailed.genres : _item.genres,
          cast: detailed.cast.isNotEmpty ? detailed.cast : _item.cast,
          crew: detailed.crew.isNotEmpty ? detailed.crew : _item.crew,
          budget: detailed.budget ?? _item.budget,
          revenue: detailed.revenue ?? _item.revenue,
          director: detailed.director?.isNotEmpty == true ? detailed.director : _item.director,
          youtubeTrailerUrl: detailed.youtubeTrailerUrl ?? _item.youtubeTrailerUrl,
          imdbId: detailed.imdbId ?? _item.imdbId,
        );

        setState(() {
          _item = updated;
          _isLoadingDetails = false;
        });

        await widget.syncService.saveMediaItem(updated, syncToTmdb: false);
      } else {
        if (mounted) setState(() => _isLoadingDetails = false);
      }
    } catch (e) {
      debugPrint('TmdbDetailDialog: Error fetching details: $e');
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _openSettingsModal(BuildContext context) async {
    final skin = context.skin;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: skin.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.dialog)),
        child: SizedBox(
          width: 580,
          height: 640,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: skin.outline)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 20),
                    const SizedBox(width: 10),
                    const Text('Настройки TMDB', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TmdbSettingsView(
                  apiClient: widget.apiClient,
                  configService: widget.configService,
                  syncService: widget.syncService,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && widget.configService.hasApiToken) {
      _fetchFullDetails(force: true);
    }
  }

  Future<void> _openPersonDialog({
    int? personId,
    required String name,
    String? role,
    String? profilePath,
  }) async {
    if (widget.onNavigateToPerson != null) {
      widget.onNavigateToPerson!(personId, name, role, profilePath);
      return;
    }
    final localItems = await widget.syncService.loadLocalItems();
    if (!mounted) return;

    await TmdbPersonDialog.show(
      context: context,
      personId: personId,
      personName: name,
      initialRole: role,
      initialProfilePath: profilePath,
      apiClient: widget.apiClient,
      configService: widget.configService,
      syncService: widget.syncService,
      localItems: localItems,
    );
  }

  Future<void> _loadRecommendations() async {
    if (!widget.configService.hasApiToken || _isLoadingRecommendations) return;

    setState(() => _isLoadingRecommendations = true);
    try {
      final localItems = await widget.syncService.loadLocalItems();
      final statusMap = <int, String>{};
      for (final it in localItems) {
        statusMap[it.id] = it.status;
      }

      var recs = await widget.apiClient.getRecommendations(
        apiToken: widget.configService.apiToken!,
        id: _item.id,
        mediaType: _item.mediaType,
      );

      if (recs.length < 6) {
        try {
          final similar = await widget.apiClient.getSimilar(
            apiToken: widget.configService.apiToken!,
            id: _item.id,
            mediaType: _item.mediaType,
          );
          final seen = recs.map((r) => r.id).toSet();
          seen.add(_item.id);
          for (final s in similar) {
            if (seen.add(s.id)) {
              recs.add(s);
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _recommendations = recs;
          _libraryStatusByTmdbId = statusMap;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('TmdbDetailDialog: Error loading recommendations: $e');
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  Future<void> _addToWatchlist(TmdbMediaItem rec) async {
    final toSave = rec.copyWith(status: 'watchlist');
    await widget.syncService.saveMediaItem(
      toSave,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
    if (mounted) {
      setState(() {
        _addedToWatchlist.add(rec.id);
        _libraryStatusByTmdbId[rec.id] = 'watchlist';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${rec.title}» добавлен в список «В планах»!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final updated = _item.copyWith(status: newStatus);
    setState(() => _item = updated);
    await widget.syncService.saveMediaItem(
      updated,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
  }

  Future<void> _toggleFavorite() async {
    _heartAnim.forward(from: 0.0);
    final updated = _item.copyWith(isFavorite: !_item.isFavorite);
    setState(() => _item = updated);
    await widget.syncService.saveMediaItem(
      updated,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
  }

  Future<void> _updateRating(double? rating) async {
    final updated = _item.copyWith(userRating: rating);
    setState(() => _item = updated);
    await widget.syncService.saveMediaItem(
      updated,
      client: widget.apiClient,
      config: widget.configService,
      syncToTmdb: true,
    );
  }

  void _onNoteChanged(String val) {
    setState(() => _isSavingNote = true);
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 600), () async {
      final updated = _item.copyWith(personalNote: val);
      _item = updated;
      await widget.syncService.saveMediaItem(updated, syncToTmdb: false);
      if (mounted) setState(() => _isSavingNote = false);
    });
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из медиатеки?'),
        content: Text('Фильм «${_item.title}» будет перемещен в корзину.'),
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
      await widget.syncService.deleteMediaItem(_item);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${_item.title}» удален из медиатеки.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final backdropUrl = _item.backdropUrl('w1280');

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
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
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Subtle ambient top backdrop image with smooth dissolution into skin.surface
              if (backdropUrl != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 180,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Opacity(
                      opacity: 0.35,
                      child: TmdbCachedImage(
                        imageUrl: backdropUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

              // Main Modal Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation & Action Bar
                  TmdbDetailTopBar(
                    item: _item,
                    isLoadingDetails: _isLoadingDetails,
                    heartScale: _heartScale,
                    onBack: widget.onBack,
                    onToggleFavorite: _toggleFavorite,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  Divider(height: 1, color: skin.divider),

                  // Main Content: Left Column (Poster & Controls) + Right Column (Title & Tabs)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column (Sidebar / Poster)
                        Container(
                          width: 250,
                          decoration: BoxDecoration(
                            color: skin.sidebar,
                            border: Border(right: BorderSide(color: skin.divider)),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: TmdbDetailSidebar(
                              item: _item,
                              isLoadingKp: _isLoadingKp,
                              hasKpToken: widget.configService.hasKpToken,
                              onUpdateStatus: _updateStatus,
                              onUpdateRating: _updateRating,
                              onRefreshKinopoisk: () => _fetchKinopoiskRatingIfNeeded(force: true),
                              onOpenSettings: () => _openSettingsModal(context),
                              onDeleteItem: _deleteItem,
                            ),
                          ),
                        ),

                        // Right Column (Title, Meta & Tabbed Content)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Movie Title & Header Info
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                                child: TmdbDetailRightHeader(item: _item),
                              ),

                              // Tab Bar
                              _buildTabBar(skin),
                              Divider(height: 1, color: skin.divider),

                              // Active Tab Content
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: _buildTabContent(skin),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTabBar(Skin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tabButton(TmdbDetailTab.overview, 'Обзор', Icons.article_outlined),
                  const SizedBox(width: 6),
                  _tabButton(
                    TmdbDetailTab.cast,
                    'Создатели и актёры',
                    Icons.people_outline,
                  ),
                  const SizedBox(width: 6),
                  _tabButton(
                    TmdbDetailTab.recommendations,
                    'Похожие',
                    Icons.auto_awesome,
                  ),
                  const SizedBox(width: 6),
                  _tabButton(TmdbDetailTab.notes, 'Заметки', Icons.edit_note),
                ],
              ),
            ),
          ),
          if (_isSavingNote) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 6),
                Text('Сохранение...', style: TextStyle(fontSize: 10, color: skin.muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(TmdbDetailTab tab, String title, IconData icon) {
    final isSelected = _activeTab == tab;

    return InkWell(
      onTap: () {
        setState(() => _activeTab = tab);
        if (tab == TmdbDetailTab.recommendations && _recommendations == null) {
          _loadRecommendations();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Palette.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Palette.accent.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Palette.accent : context.skin.muted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Palette.accent : context.skin.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(Skin skin) {
    switch (_activeTab) {
      case TmdbDetailTab.overview:
        return TmdbOverviewTab(
          item: _item,
          onShowAllCast: () => setState(() => _activeTab = TmdbDetailTab.cast),
          onPersonTap: (personId, name, role, profilePath) => _openPersonDialog(
            personId: personId,
            name: name,
            role: role,
            profilePath: profilePath,
          ),
        );
      case TmdbDetailTab.cast:
        return TmdbCastTab(
          item: _item,
          isLoading: _isLoadingDetails,
          hasApiToken: widget.configService.hasApiToken,
          onOpenSettings: () => _openSettingsModal(context),
          onRefresh: () => _fetchFullDetails(force: true),
          onPersonTap: (personId, name, role, profilePath) => _openPersonDialog(
            personId: personId,
            name: name,
            role: role,
            profilePath: profilePath,
          ),
        );
      case TmdbDetailTab.recommendations:
        return TmdbRecommendationsTab(
          hasApiToken: widget.configService.hasApiToken,
          isLoading: _isLoadingRecommendations,
          recommendations: _recommendations,
          addedToWatchlist: _addedToWatchlist,
          libraryStatusByTmdbId: _libraryStatusByTmdbId,
          onOpenSettings: () => _openSettingsModal(context),
          onLoadRecommendations: _loadRecommendations,
          onAddToWatchlist: _addToWatchlist,
          onNavigateToMovie: (rec) {
            if (widget.onNavigateToMovie != null) {
              widget.onNavigateToMovie!(rec);
              return;
            }
            TmdbDetailDialog.show(
              context,
              item: rec,
              apiClient: widget.apiClient,
              configService: widget.configService,
              syncService: widget.syncService,
              onOpenAsPage: widget.onOpenAsPage,
            );
          },
        );
      case TmdbDetailTab.notes:
        return TmdbNotesTab(
          item: _item,
          controller: _noteController,
          onNoteChanged: _onNoteChanged,
          onOpenAsPage: widget.onOpenAsPage,
        );
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/tmdb_image_cache.dart';
import '../services/kinopoisk_service.dart';
import 'tmdb_settings_view.dart';
import 'tmdb_person_dialog.dart';
import 'tmdb_modal_host.dart';

enum _DetailTab { overview, cast, recommendations, notes }

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
  _DetailTab _activeTab = _DetailTab.overview;
  double? _hoveredStarRating;
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
        apiKey: widget.configService.kpApiToken!,
        imdbId: _item.imdbId,
        title: _item.title,
        year: int.tryParse(_item.year),
      );

      if (kpData != null && mounted) {
        final updated = _item.copyWith(
          kpRating: kpData.kpRating,
          kpVotes: kpData.kpVotes ?? _item.kpVotes,
          kpId: kpData.kpId,
          imdbRating: kpData.imdbRating ?? _item.imdbRating,
        );
        setState(() {
          _item = updated;
          _isLoadingKp = false;
        });
        await widget.syncService.saveMediaItem(updated, syncToTmdb: false);
      } else if (mounted) {
        setState(() => _isLoadingKp = false);
      }
    } catch (e) {
      debugPrint('TmdbDetailDialog: Kinopoisk fetch error: $e');
      if (mounted) setState(() => _isLoadingKp = false);
    }
  }

  Future<void> _fetchFullDetails({bool force = false}) async {
    if (!widget.configService.hasApiToken) return;

    if (force ||
        _item.cast.isEmpty ||
        _item.crew.isEmpty ||
        _item.tagline == null ||
        _item.trailerKey == null ||
        _item.director == null ||
        _item.runtime == null ||
        _item.genres.isEmpty ||
        _item.imdbId == null) {
      setState(() => _isLoadingDetails = true);
      try {
        final details = await widget.apiClient.getDetails(
          apiToken: widget.configService.apiToken!,
          id: _item.id,
          mediaType: _item.mediaType,
        );
        if (mounted) {
          var updated = _item.copyWith(
            tagline: details.tagline ?? _item.tagline,
            runtime: details.runtime ?? _item.runtime,
            director: details.director ?? _item.director,
            cast: details.cast.isNotEmpty ? details.cast : _item.cast,
            crew: details.crew.isNotEmpty ? details.crew : _item.crew,
            trailerKey: details.trailerKey ?? _item.trailerKey,
            backdropPath: details.backdropPath ?? _item.backdropPath,
            overview: (details.overview != null && details.overview!.isNotEmpty) ? details.overview : _item.overview,
            genres: details.genres.isNotEmpty ? details.genres : _item.genres,
            releaseDate: details.releaseDate ?? _item.releaseDate,
            originalTitle: details.originalTitle ?? _item.originalTitle,
            imdbId: details.imdbId ?? _item.imdbId,
          );

          // If Kinopoisk token is present, also fetch or update KP rating
          if (widget.configService.hasKpToken && (force || updated.kpRating == null)) {
            try {
              final kpService = KinopoiskService();
              final kpData = await kpService.fetchRating(
                apiKey: widget.configService.kpApiToken!,
                imdbId: updated.imdbId,
                title: updated.title,
                year: int.tryParse(updated.year),
              );
              if (kpData != null) {
                updated = updated.copyWith(
                  kpRating: kpData.kpRating,
                  kpVotes: kpData.kpVotes ?? updated.kpVotes,
                  kpId: kpData.kpId,
                  imdbRating: kpData.imdbRating ?? updated.imdbRating,
                );
              }
            } catch (kpErr) {
              debugPrint('Kinopoisk detail fetch error: $kpErr');
            }
          }

          setState(() {
            _item = updated;
            _isLoadingDetails = false;
          });

          await widget.syncService.saveMediaItem(updated, syncToTmdb: false);
        }
      } catch (e) {
        debugPrint('TmdbDetailDialog: Error fetching details: $e');
        if (mounted) setState(() => _isLoadingDetails = false);
      }
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'watching':
        return const Color(0xFFF59E0B);
      case 'watched':
        return const Color(0xFF10B981);
      case 'dropped':
        return const Color(0xFFEF4444);
      case 'watchlist':
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'watching':
        return 'Смотрю сейчас';
      case 'watched':
        return 'Просмотрено';
      case 'dropped':
        return 'Брошено';
      case 'watchlist':
      default:
        return 'В планах';
    }
  }

  String _getRatingFeedbackText(double rating) {
    if (rating <= 1.5) return 'Ужасно';
    if (rating <= 2.5) return 'Очень плохо';
    if (rating <= 3.5) return 'Плохо';
    if (rating <= 4.5) return 'Слабо';
    if (rating <= 5.5) return 'Средне';
    if (rating <= 6.5) return 'Неплохо';
    if (rating <= 7.5) return 'Хорошо';
    if (rating <= 8.5) return 'Очень хорошо';
    if (rating <= 9.5) return 'Великолепно';
    return 'Шедевр! ⭐️';
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
                  _buildTopBar(skin),
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
                            child: _buildLeftColumn(skin),
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
                                child: _buildRightHeader(skin),
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

  Widget _buildTopBar(Skin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: skin.surface.withValues(alpha: 0.85),
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

          // Media Type Badge (Things 3 soft borderless pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: skin.hover,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _item.mediaType == 'tv' ? Icons.tv : Icons.movie_filter_outlined,
                  size: 13,
                  color: _item.mediaType == 'tv' ? Colors.purple : Palette.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  _item.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                ),
                if (_isLoadingDetails) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),

          // Watch Trailer Button (Apple HIG sleek soft button)
          if (_item.youtubeTrailerUrl != null) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: skin.hover,
                foregroundColor: skin.text,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 16, color: Palette.accent),
              label: const Text('Трейлер', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () => openExternalUrl(_item.youtubeTrailerUrl!),
            ),
            const SizedBox(width: 10),
          ],

          // Favorite Button
          ScaleTransition(
            scale: _heartScale,
            child: IconButton(
              tooltip: _item.isFavorite ? 'В избранном' : 'Добавить в избранное',
              iconSize: 20,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                _item.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _item.isFavorite ? Colors.redAccent : skin.muted,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
          const SizedBox(width: 6),

          // Close Button
          IconButton(
            tooltip: 'Закрыть',
            iconSize: 20,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, color: skin.muted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildRightHeader(Skin skin) {
    final metaItems = <String>[];
    if (_item.year.isNotEmpty) metaItems.add(_item.year);
    if (_item.formattedRuntime.isNotEmpty) metaItems.add(_item.formattedRuntime);
    if (_item.director != null && _item.director!.isNotEmpty) {
      metaItems.add('Реж. ${_item.director!}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title in crisp dark theme text
        Text(
          _item.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: skin.text,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (_item.originalTitle != null && _item.originalTitle != _item.title) ...[
          const SizedBox(height: 2),
          Text(
            _item.originalTitle!,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: skin.muted,
            ),
          ),
        ],
        if (_item.tagline != null && _item.tagline!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '«${_item.tagline}»',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Palette.accent,
            ),
          ),
        ],
        const SizedBox(height: 10),

        // Apple HIG Typography-First Metadata Row with Middle Dots
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            if (metaItems.isNotEmpty)
              Text(
                metaItems.join('  •  '),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: skin.muted,
                  letterSpacing: -0.1,
                ),
              ),
            if (metaItems.isNotEmpty && _item.genres.isNotEmpty)
              Text(
                '•',
                style: TextStyle(fontSize: 12, color: skin.faint),
              ),
            for (final genre in _item.genres) _genrePill(skin, genre),
          ],
        ),
      ],
    );
  }

  Widget _buildLeftColumn(Skin skin) {
    final statusColor = _getStatusColor(_item.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Poster Image
        AspectRatio(
          aspectRatio: 0.67,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UiRadius.card),
              border: Border.all(color: skin.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UiRadius.card),
              child: TmdbCachedImage(
                imageUrl: _item.posterUrl('w500'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status Selector Dropdown (Apple HIG Soft Surface)
        PopupMenuButton<String>(
          tooltip: 'Изменить статус',
          initialValue: _item.status,
          onSelected: _updateStatus,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: skin.divider),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusLabel(_item.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Icon(Icons.unfold_more, size: 16, color: statusColor),
              ],
            ),
          ),
          itemBuilder: (ctx) => [
            _buildStatusItem('watchlist', 'В планах', const Color(0xFF6366F1), Icons.bookmark_rounded),
            _buildStatusItem('watching', 'Смотрю сейчас', const Color(0xFFF59E0B), Icons.play_circle_fill_rounded),
            _buildStatusItem('watched', 'Просмотрено', const Color(0xFF10B981), Icons.check_circle_rounded),
            _buildStatusItem('dropped', 'Брошено', const Color(0xFFEF4444), Icons.cancel_rounded),
          ],
        ),
        const SizedBox(height: 14),

        // Interactive Star Rating Widget
        _buildInteractiveRatingPicker(skin),
        const SizedBox(height: 14),

        // Multi-Source Ratings Card (TMDB, Kinopoisk, IMDb)
        _buildRatingsCard(skin),
        const SizedBox(height: 14),

        // TMDB Web Link Button
        OutlinedButton.icon(
          onPressed: () => openExternalUrl(_item.tmdbWebUrl),
          icon: const Icon(Icons.launch, size: 14),
          label: const Text('Открыть на TMDB', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            side: BorderSide(color: skin.outline),
          ),
        ),
        const SizedBox(height: 6),

        // Delete Button
        TextButton.icon(
          onPressed: _deleteItem,
          icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
          label: const Text('Удалить из списка', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
        ),
      ],
    );
  }

  Widget _buildInteractiveRatingPicker(Skin skin) {
    final currentScore = _item.userRating;
    final displayScore = _hoveredStarRating ?? currentScore;
    final hasHalf = displayScore != null && (displayScore % 1 != 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: skin.isDark ? const Color(0x18FFFFFF) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: skin.divider.withValues(alpha: skin.isDark ? 0.3 : 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "МОЯ ОЦЕНКА" + Reset button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    size: 13,
                    color: displayScore != null ? const Color(0xFFFFB300) : skin.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'МОЯ ОЦЕНКА',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: skin.muted,
                    ),
                  ),
                ],
              ),
              if (currentScore != null && currentScore > 0)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _updateRating(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Сбросить',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 5 Large Stars (Letterboxd / Apple style) + .5 Precision Toggle
          MouseRegion(
            onExit: (_) {
              if (mounted) setState(() => _hoveredStarRating = null);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(5, (starIdx) {
                  final leftVal = starIdx * 2.0 + 1.0;
                  final rightVal = (starIdx + 1) * 2.0;

                  double fillFraction = 0.0;
                  if (displayScore != null) {
                    if (displayScore >= rightVal) {
                      fillFraction = 1.0;
                    } else if (displayScore <= starIdx * 2.0) {
                      fillFraction = 0.0;
                    } else {
                      fillFraction = ((displayScore - starIdx * 2.0) / 2.0).clamp(0.0, 1.0);
                    }
                  }

                  final isHoveredThisStar = _hoveredStarRating != null &&
                      (_hoveredStarRating! - 0.5) ~/ 2 == starIdx;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: AnimatedScale(
                      scale: isHoveredThisStar ? 1.18 : 1.0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                      child: SizedBox(
                        width: 27,
                        height: 27,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Base empty star
                            Center(
                              child: Icon(
                                Icons.star_rounded,
                                size: 27,
                                color: skin.isDark
                                    ? const Color(0x2EFFFFFF)
                                    : const Color(0x22000000),
                              ),
                            ),
                            // Filled star (clipped by fillFraction)
                            if (fillFraction > 0)
                              Positioned.fill(
                                child: ClipRect(
                                  clipper: _FractionalClipper(fillFraction),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    size: 27,
                                    color: Color(0xFFFFB300),
                                  ),
                                ),
                              ),
                            // Left-half hitbox (odd rating)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 13.5,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) {
                                  setState(() => _hoveredStarRating = leftVal);
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _updateRating(leftVal),
                                ),
                              ),
                            ),
                            // Right-half hitbox (even rating)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 13.5,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) {
                                  setState(() => _hoveredStarRating = rightVal);
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _updateRating(rightVal),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 5),

                // .5 Precision Toggle Chip
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (currentScore == null) {
                        _updateRating(0.5);
                      } else if (currentScore % 1 != 0) {
                        _updateRating(currentScore.floorToDouble());
                      } else {
                        if (currentScore < 10.0) {
                          _updateRating(currentScore + 0.5);
                        }
                      }
                    },
                    child: Tooltip(
                      message: hasHalf
                          ? 'Убрать +0.5 (сделать целым)'
                          : 'Добавить +0.5 (точная оценка TMDB)',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasHalf
                              ? const Color(0xFFFFB300).withValues(alpha: 0.22)
                              : (skin.isDark ? const Color(0x18FFFFFF) : const Color(0x0E000000)),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: hasHalf
                                ? const Color(0xFFFFB300)
                                : skin.divider.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '.5',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: hasHalf ? const Color(0xFFFFB300) : skin.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Feedback Pill (Things 3 soft badge)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: displayScore != null && displayScore > 0
                    ? const Color(0xFFFFB300).withValues(alpha: 0.14)
                    : (skin.isDark ? const Color(0x10FFFFFF) : const Color(0x0A000000)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: displayScore != null && displayScore > 0
                        ? const Color(0xFFFFB300)
                        : skin.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    displayScore != null && displayScore > 0
                        ? '${displayScore % 1 == 0 ? displayScore.toInt() : displayScore.toStringAsFixed(1)} / 10 • ${_getRatingFeedbackText(displayScore)}'
                        : 'Нажмите для оценки',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: displayScore != null && displayScore > 0
                          ? const Color(0xFFFFB300)
                          : skin.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsCard(Skin skin) {
    final hasTmdb = _item.voteAverage != null && _item.voteAverage! > 0;
    final hasKp = _item.kpRating != null && _item.kpRating! > 0;
    final hasImdb = (_item.imdbRating != null && _item.imdbRating! > 0) || (_item.imdbId != null && _item.imdbId!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Рейтинги',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: skin.muted,
                  letterSpacing: 0.2,
                ),
              ),
              if (_isLoadingKp)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (widget.configService.hasKpToken)
                GestureDetector(
                  onTap: () => _fetchKinopoiskRatingIfNeeded(force: true),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Обновить оценки Кинопоиска',
                      child: Icon(Icons.refresh, size: 14, color: skin.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // TMDB Rating Row
          _buildRatingSourceRow(
            skin: skin,
            iconWidget: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
            ),
            sourceName: 'TMDB',
            score: hasTmdb ? _item.voteAverage!.toStringAsFixed(1) : '—',
            scoreColor: Colors.amber,
            subtext: _item.voteCount != null ? '${_item.voteCount} оценок' : null,
            onOpenUrl: () => openExternalUrl(_item.tmdbWebUrl),
            urlTooltip: 'Открыть страницу фильма на TMDB',
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: skin.divider),
          const SizedBox(height: 8),

          // Kinopoisk Rating Row
          _buildRatingSourceRow(
            skin: skin,
            iconWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5500),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'КП',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            sourceName: 'Кинопоиск',
            score: hasKp ? _item.kpRating!.toStringAsFixed(1) : (widget.configService.hasKpToken ? '—' : 'Нет ключа'),
            scoreColor: hasKp ? const Color(0xFFFF5500) : skin.muted,
            subtext: hasKp && _item.kpVotes != null ? '${_item.kpVotes} оценок' : null,
            onOpenUrl: _item.kinopoiskWebUrl != null
                ? () => openExternalUrl(_item.kinopoiskWebUrl!)
                : (!widget.configService.hasKpToken ? () => _openSettingsModal(context) : null),
            urlTooltip: _item.kinopoiskWebUrl != null
                ? 'Открыть страницу на Кинопоиске'
                : (!widget.configService.hasKpToken ? 'Настроить API Кинопоиска в настройках' : null),
          ),

          // IMDb Rating Row (if available)
          if (hasImdb) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: skin.divider),
            const SizedBox(height: 8),
            _buildRatingSourceRow(
              skin: skin,
              iconWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5C518),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'IMDb',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              sourceName: 'IMDb',
              score: _item.imdbRating != null && _item.imdbRating! > 0
                  ? _item.imdbRating!.toStringAsFixed(1)
                  : (_item.imdbId != null ? '↗' : '—'),
              scoreColor: const Color(0xFFD97706),
              onOpenUrl: _item.imdbWebUrl != null ? () => openExternalUrl(_item.imdbWebUrl!) : null,
              urlTooltip: 'Открыть страницу фильма на IMDb',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSourceRow({
    required Skin skin,
    required Widget iconWidget,
    required String sourceName,
    required String score,
    required Color scoreColor,
    String? subtext,
    VoidCallback? onOpenUrl,
    String? urlTooltip,
  }) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sourceName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: skin.text),
              ),
              if (subtext != null)
                Text(
                  subtext,
                  style: TextStyle(fontSize: 10, color: skin.muted),
                ),
            ],
          ),
        ),
        Text(
          score,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: scoreColor,
          ),
        ),
        if (onOpenUrl != null) ...[
          const SizedBox(width: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onOpenUrl,
              child: Tooltip(
                message: urlTooltip ?? 'Открыть ссылку',
                child: Icon(Icons.open_in_new, size: 13, color: skin.muted),
              ),
            ),
          ),
        ],
      ],
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
                  _tabButton(_DetailTab.overview, 'Обзор', Icons.article_outlined),
                  const SizedBox(width: 6),
                  _tabButton(
                    _DetailTab.cast,
                    'Создатели и актёры',
                    Icons.people_outline,
                  ),
                  const SizedBox(width: 6),
                  _tabButton(
                    _DetailTab.recommendations,
                    'Похожие',
                    Icons.auto_awesome,
                  ),
                  const SizedBox(width: 6),
                  _tabButton(_DetailTab.notes, 'Заметки', Icons.edit_note),
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

  Widget _tabButton(_DetailTab tab, String title, IconData icon) {
    final isSelected = _activeTab == tab;

    return InkWell(
      onTap: () {
        setState(() => _activeTab = tab);
        if (tab == _DetailTab.recommendations && _recommendations == null) {
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
      case _DetailTab.overview:
        return _buildOverviewTab(skin);
      case _DetailTab.cast:
        return _buildCastTab(skin);
      case _DetailTab.recommendations:
        return _buildRecommendationsTab(skin);
      case _DetailTab.notes:
        return _buildNotesTab(skin);
    }
  }

  Widget _buildOverviewTab(Skin skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Synopsis Text
        Text(
          'Описание',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: skin.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _item.overview != null && _item.overview!.isNotEmpty
              ? _item.overview!
              : 'Описание для данного фильма отсутствует.',
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: skin.muted,
          ),
        ),

        // Key Creators & Production Info (Apple HIG Clean Card)
        if (_item.crew.isNotEmpty || (_item.director != null && _item.director!.isNotEmpty)) ...[
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: skin.hover,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_item.directors.isNotEmpty || (_item.director != null && _item.director!.isNotEmpty))
                  _buildCrewInfoRow(
                    skin,
                    icon: Icons.movie_creation_outlined,
                    label: _item.mediaType == 'tv' ? 'Создатели' : 'Режиссёр',
                    members: _item.directors,
                    fallbackName: _item.director,
                    accentColor: skin.muted,
                  ),
                if (_item.writers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCrewInfoRow(
                    skin,
                    icon: Icons.edit_note_rounded,
                    label: 'Сценарий и авторы',
                    members: _item.writers,
                    accentColor: skin.muted,
                  ),
                ],
                if (_item.producers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCrewInfoRow(
                    skin,
                    icon: Icons.business_center_outlined,
                    label: 'Продюсеры',
                    members: _item.producers.take(3).toList(),
                    accentColor: skin.muted,
                  ),
                ],
                if (_item.composers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCrewInfoRow(
                    skin,
                    icon: Icons.music_note_rounded,
                    label: 'Композитор',
                    members: _item.composers,
                    accentColor: skin.muted,
                  ),
                ],
              ],
            ),
          ),
        ] else
          const SizedBox(height: 24),

        // Quick Cast Preview (if available)
        if (_item.cast.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'В главных ролях',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: skin.text,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _activeTab = _DetailTab.cast),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Все создатели и актёры (${_item.crew.length + _item.cast.length}) →',
                    style: TextStyle(fontSize: 11, color: Palette.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _item.cast.take(6).length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (ctx, idx) {
                final actor = _item.cast[idx];
                return _buildActorCard(skin, actor);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCrewInfoRow(
    Skin skin, {
    required IconData icon,
    required String label,
    required List<TmdbCrewMember> members,
    String? fallbackName,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: accentColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: skin.muted,
            ),
          ),
        ),
        Expanded(
          child: members.isNotEmpty
              ? Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: members.map((m) {
                    return InkWell(
                      onTap: () => _openPersonDialog(
                        personId: m.id,
                        name: m.name,
                        role: m.job,
                        profilePath: m.profilePath,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Palette.accent,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              : (fallbackName != null && fallbackName.isNotEmpty)
                  ? InkWell(
                      onTap: () => _openPersonDialog(
                        name: fallbackName,
                        role: label,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          fallbackName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Palette.accent,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCastTab(Skin skin) {
    if (_isLoadingDetails) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Palette.accent),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Загрузка списка актёров с TMDB...',
                style: TextStyle(fontSize: 13, color: skin.muted),
              ),
            ],
          ),
        ),
      );
    }

    if (!widget.configService.hasApiToken) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: skin.sidebar,
            borderRadius: BorderRadius.circular(UiRadius.panel),
            border: Border.all(color: skin.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_outlined, size: 28, color: Palette.accent),
              ),
              const SizedBox(height: 14),
              Text(
                'Требуется TMDB API токен',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: skin.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Для загрузки состава актёров, ролей и съёмочной группы укажите API токен в настройках.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: skin.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openSettingsModal(context),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Открыть настройки TMDB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiRadius.control),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_item.cast.isEmpty && _item.crew.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 40, color: skin.faint),
              const SizedBox(height: 12),
              Text(
                'Информация о создателях и актёрах не найдена',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Возможно, данные ещё не были синхронизированы',
                style: TextStyle(fontSize: 12, color: skin.muted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _fetchFullDetails(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Обновить данные фильма'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.accent,
                  side: BorderSide(color: skin.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiRadius.control),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_item.crew.isNotEmpty) ...[
          _buildCrewSection(skin),
          if (_item.cast.isNotEmpty) const SizedBox(height: 24),
        ],
        if (_item.cast.isNotEmpty)
          _buildCastSection(skin),
      ],
    );
  }

  Widget _buildCrewSection(Skin skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.movie_creation_outlined, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'Съёмочная группа и авторы (${_item.crew.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: skin.text),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, size: 16, color: skin.muted),
                tooltip: 'Обновить данные',
                splashRadius: 16,
                onPressed: () => _fetchFullDetails(force: true),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _item.crew.length,
          itemBuilder: (ctx, idx) {
            final member = _item.crew[idx];
            final roleColor = _getCrewRoleColor(member.job);
            return InkWell(
              onTap: () => _openPersonDialog(
                personId: member.id,
                name: member.name,
                role: member.job,
                profilePath: member.profilePath,
              ),
              borderRadius: BorderRadius.circular(UiRadius.control),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: skin.sidebar,
                  borderRadius: BorderRadius.circular(UiRadius.control),
                  border: Border.all(color: skin.outline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: skin.surface,
                      child: ClipOval(
                        child: member.profilePath != null && member.profilePath!.isNotEmpty
                            ? TmdbCachedImage(
                                imageUrl: member.profileUrl('w185'),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                color: roleColor.withValues(alpha: 0.12),
                                child: Icon(
                                  _getCrewRoleIcon(member.job),
                                  size: 18,
                                  color: roleColor,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            member.name,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: skin.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: roleColor.withValues(alpha: 0.25), width: 0.8),
                            ),
                            child: Text(
                              member.job,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: roleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCastSection(Skin skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.theater_comedy_outlined, size: 16, color: Color(0xFFEC4899)),
                  const SizedBox(width: 8),
                  Text(
                    'В главных ролях (${_item.cast.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: skin.text),
                  ),
                ],
              ),
              if (_item.crew.isEmpty)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 16, color: skin.muted),
                  tooltip: 'Обновить актёров',
                  splashRadius: 16,
                  onPressed: () => _fetchFullDetails(force: true),
                ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _item.cast.length,
          itemBuilder: (ctx, idx) {
            final actor = _item.cast[idx];
            return InkWell(
              onTap: () => _openPersonDialog(
                personId: actor.id,
                name: actor.name,
                role: actor.character != null && actor.character!.isNotEmpty
                    ? 'в роли ${actor.character!}'
                    : 'Актёр',
                profilePath: actor.profilePath,
              ),
              borderRadius: BorderRadius.circular(UiRadius.control),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: skin.sidebar,
                  borderRadius: BorderRadius.circular(UiRadius.control),
                  border: Border.all(color: skin.outline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: skin.surface,
                      child: ClipOval(
                        child: TmdbCachedImage(
                          imageUrl: actor.profileUrl('w185'),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            actor.name,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: skin.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (actor.character != null && actor.character!.isNotEmpty)
                            Text(
                              actor.character!,
                              style: TextStyle(fontSize: 10, color: skin.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getCrewRoleColor(String job) {
    switch (job.toLowerCase()) {
      case 'режиссёр':
      case 'создатель':
        return const Color(0xFF2563EB); // Vibrant Blue
      case 'сценарист':
      case 'автор':
      case 'сюжет':
        return const Color(0xFF7C3AED); // Purple
      case 'композитор':
        return const Color(0xFF059669); // Emerald
      case 'оператор':
        return const Color(0xFFD97706); // Amber
      case 'продюсер':
      case 'исполнительный продюсер':
        return const Color(0xFF0284C7); // Cyan
      case 'художник-постановщик':
      case 'художник по костюмам':
        return const Color(0xFFDB2777); // Pink
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getCrewRoleIcon(String job) {
    switch (job.toLowerCase()) {
      case 'режиссёр':
      case 'создатель':
        return Icons.movie_creation_outlined;
      case 'сценарист':
      case 'автор':
        return Icons.edit_note_rounded;
      case 'композитор':
        return Icons.music_note_rounded;
      case 'оператор':
        return Icons.videocam_outlined;
      case 'продюсер':
      case 'исполнительный продюсер':
        return Icons.business_center_outlined;
      default:
        return Icons.person_outline_rounded;
    }
  }

  Widget _buildRecommendationsTab(Skin skin) {
    if (!widget.configService.hasApiToken) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: skin.sidebar,
            borderRadius: BorderRadius.circular(UiRadius.panel),
            border: Border.all(color: skin.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_outlined, size: 28, color: Palette.accent),
              ),
              const SizedBox(height: 14),
              Text(
                'Требуется TMDB API токен',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: skin.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Для загрузки персональных и похожих рекомендаций укажите API токен в настройках.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: skin.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openSettingsModal(context),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Открыть настройки TMDB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiRadius.control),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingRecommendations) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Palette.accent),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Подбираем похожие фильмы и рекомендации...',
                style: TextStyle(fontSize: 13, color: skin.muted),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendations == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendations());
      return const SizedBox.shrink();
    }

    if (_recommendations!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined, size: 40, color: skin.faint),
              const SizedBox(height: 12),
              Text(
                'Похожих проектов не найдено',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.text),
              ),
              const SizedBox(height: 6),
              Text(
                'В базе TMDB пока нет похожих картин для этого произведения',
                style: TextStyle(fontSize: 12, color: skin.muted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadRecommendations,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Palette.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 16, color: Palette.accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Похожие на «${_item.title}»',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
                    ),
                    Text(
                      '${_recommendations!.length} проектов со схожей атмосферой и сюжетом',
                      style: TextStyle(fontSize: 11, color: skin.muted),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 16, color: skin.muted),
              tooltip: 'Обновить рекомендации',
              onPressed: _loadRecommendations,
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.52,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _recommendations!.length,
          itemBuilder: (ctx, idx) {
            final rec = _recommendations![idx];
            return _buildRecommendationCard(skin, rec);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Skin skin, TmdbMediaItem rec) {
    final existingStatus = _libraryStatusByTmdbId[rec.id];
    final isInWatchlist = existingStatus != null || _addedToWatchlist.contains(rec.id);
    final statusColor = existingStatus != null ? _getStatusColor(existingStatus) : const Color(0xFF10B981);

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
          // Poster with Hover & Badges
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
                  onTap: () {
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
                  child: TmdbCachedImage(
                    imageUrl: rec.posterUrl('w342') ?? rec.posterUrl('w500'),
                    fit: BoxFit.cover,
                  ),
                ),

                // Subtle top gradient
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

                // TMDB Score Badge (Top-Left)
                if (rec.voteAverage != null && rec.voteAverage! > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            rec.voteAverage!.toStringAsFixed(1),
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

                // Media Type Badge (Top-Right)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (rec.mediaType == 'tv' ? Colors.purple : Palette.accent).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rec.mediaType == 'tv' ? 'ТВ' : 'Фильм',
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

          // Details info at bottom
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: rec.title,
                  child: Text(
                    rec.title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rec.year.isNotEmpty ? rec.year : '—',
                  style: TextStyle(fontSize: 10, color: skin.muted),
                ),
                const SizedBox(height: 6),

                // Add to Watchlist Button / In Library Indicator
                if (isInWatchlist)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          existingStatus != null ? _getStatusLabel(existingStatus) : 'В планах',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 26,
                    child: OutlinedButton(
                      onPressed: () => _addToWatchlist(rec),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Palette.accent.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 13, color: Palette.accent),
                          SizedBox(width: 2),
                          Text(
                            'В планы',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.accent,
                            ),
                          ),
                        ],
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

  Widget _buildNotesTab(Skin skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Личные впечатления и рецензия',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
                ),
              ],
            ),
            if (_item.pageId != null && widget.onOpenAsPage != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Открыть редактор страниц', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenAsPage!(_item.pageId!);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 10,
          style: TextStyle(fontSize: 13, height: 1.5, color: skin.text),
          decoration: InputDecoration(
            hintText: 'Запишите здесь свои впечатления, любимые цитаты или мысли о фильме...',
            hintStyle: TextStyle(fontSize: 12, color: skin.faint),
            filled: true,
            fillColor: skin.sidebar,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              borderSide: BorderSide(color: skin.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              borderSide: BorderSide(color: skin.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              borderSide: BorderSide(color: Palette.accent, width: 1.5),
            ),
          ),
          onChanged: _onNoteChanged,
        ),
      ],
    );
  }

  Widget _buildActorCard(Skin skin, TmdbCastMember actor) {
    return InkWell(
      onTap: () => _openPersonDialog(
        personId: actor.id,
        name: actor.name,
        role: actor.character != null && actor.character!.isNotEmpty
            ? 'в роли ${actor.character!}'
            : 'Актёр',
        profilePath: actor.profilePath,
      ),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: skin.hover,
              child: ClipOval(
                child: TmdbCachedImage(
                  imageUrl: actor.profileUrl('w185'),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              actor.name,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: skin.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (actor.character != null && actor.character!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                actor.character!,
                style: TextStyle(fontSize: 9.5, color: skin.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _genrePill(Skin skin, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Palette.accent,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildStatusItem(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    final isSelected = _item.status == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : null,
              ),
            ),
          ),
          if (isSelected) Icon(Icons.check, size: 14, color: color),
        ],
      ),
    );
  }
}

class _FractionalClipper extends CustomClipper<Rect> {
  final double fraction;
  const _FractionalClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(_FractionalClipper oldClipper) => oldClipper.fraction != fraction;
}

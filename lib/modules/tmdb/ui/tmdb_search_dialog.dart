import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/tmdb_image_cache.dart';
import 'tmdb_detail_dialog.dart';
import 'tmdb_modal_host.dart';

class TmdbSearchDialog extends StatefulWidget {
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;
  final ValueChanged<String>? onPageCreated;
  final String? initialQuery;
  final VoidCallback? onBack;
  final ValueChanged<TmdbMediaItem>? onNavigateToMovie;

  const TmdbSearchDialog({
    super.key,
    required this.apiClient,
    required this.configService,
    required this.syncService,
    this.onPageCreated,
    this.initialQuery,
    this.onBack,
    this.onNavigateToMovie,
  });

  static Future<void> show(
    BuildContext context, {
    required TmdbApiClient apiClient,
    required TmdbConfigService configService,
    required TmdbDatabaseSync syncService,
    ValueChanged<String>? onPageCreated,
    String? initialQuery,
    List<TmdbMediaItem>? localItems,
  }) async {
    final items = localItems ?? await syncService.loadLocalItems();
    if (!context.mounted) return;
    return TmdbModalHost.show(
      context,
      initialRoute: TmdbSearchRoute(
        initialQuery: initialQuery,
        onPageCreated: onPageCreated,
      ),
      apiClient: apiClient,
      configService: configService,
      syncService: syncService,
      localItems: items,
      onOpenPage: onPageCreated,
    );
  }

  @override
  State<TmdbSearchDialog> createState() => _TmdbSearchDialogState();
}

class _TmdbSearchDialogState extends State<TmdbSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<TmdbMediaItem> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<int> _addedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performSearch(_controller.text);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (!widget.configService.hasApiToken) {
      setState(() {
        _errorMessage = 'Для поиска укажите TMDB API токен в настройках модуля.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.apiClient.searchMulti(
        apiToken: widget.configService.apiToken!,
        query: query,
      );
      if (mounted) {
        setState(() {
          _results = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка поиска: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addItem(TmdbMediaItem item, String status) async {
    setState(() => _addedIds.add(item.id));
    try {
      TmdbMediaItem fullItem = item.copyWith(status: status);
      if (widget.configService.hasApiToken) {
        try {
          final details = await widget.apiClient.getDetails(
            apiToken: widget.configService.apiToken!,
            id: item.id,
            mediaType: item.mediaType,
          );
          fullItem = fullItem.copyWith(
            tagline: details.tagline ?? fullItem.tagline,
            runtime: details.runtime ?? fullItem.runtime,
            director: details.director ?? fullItem.director,
            cast: details.cast.isNotEmpty ? details.cast : fullItem.cast,
            crew: details.crew.isNotEmpty ? details.crew : fullItem.crew,
            trailerKey: details.trailerKey ?? fullItem.trailerKey,
            backdropPath: details.backdropPath ?? fullItem.backdropPath,
            overview: (details.overview != null && details.overview!.isNotEmpty) ? details.overview : fullItem.overview,
            genres: details.genres.isNotEmpty ? details.genres : fullItem.genres,
            releaseDate: details.releaseDate ?? fullItem.releaseDate,
            originalTitle: details.originalTitle ?? fullItem.originalTitle,
          );
        } catch (_) {}
      }
      final pageId = await widget.syncService.saveMediaItem(
        fullItem,
        client: widget.apiClient,
        config: widget.configService,
        syncToTmdb: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${item.title}» добавлен в список ($status)!'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onPageCreated?.call(pageId);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addedIds.remove(item.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить фильм: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlBg = isDark ? const Color(0x1FFFFFFF) : const Color(0xFFEFEFF2);

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
              // Top Bar
              Container(
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
                      child: const Icon(Icons.movie_filter_outlined, size: 18, color: Palette.accent),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Поиск фильмов и сериалов в TMDB',
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
              ),

              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: controlBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 17, color: skin.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          style: TextStyle(fontSize: 12.5, color: skin.text, height: 1.25),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Введите название фильма или сериала...',
                            hintStyle: TextStyle(fontSize: 12.5, color: skin.muted.withValues(alpha: 0.85), height: 1.25),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Palette.accent),
                            ),
                          ),
                        ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            _onSearchChanged('');
                          },
                          child: Icon(Icons.close, size: 15, color: skin.muted),
                        ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: skin.divider),

              // Results List / Status
              Expanded(
                child: _buildResultsView(skin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView(Skin skin) {
    if (!widget.configService.hasApiToken) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined, size: 48, color: skin.faint),
            const SizedBox(height: 12),
            Text(
              'TMDB API токен не указан',
              style: TextStyle(fontWeight: FontWeight.w600, color: skin.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Перейдите в настройки модуля, чтобы указать свой API Read Access Token.',
              style: TextStyle(color: skin.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 44, color: skin.faint.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Начните ввод, чтобы найти фильм или сериал',
              style: TextStyle(color: skin.muted),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          'Ничего не найдено по запросу «${_controller.text}»',
          style: TextStyle(color: skin.muted),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: skin.divider),
      itemBuilder: (context, index) {
        final item = _results[index];
        final isAdded = _addedIds.contains(item.id);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster thumbnail
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
                    );
                  }
                },
                child: SizedBox(
                  width: 50,
                  height: 75,
                  child: TmdbCachedImage(
                    imageUrl: item.posterUrl('w185'),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                                );
                              }
                            },
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: skin.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (item.voteAverage != null && item.voteAverage! > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 12, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  item.voteAverage!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: item.mediaType == 'tv' ? Colors.purpleAccent : Colors.blueAccent,
                          ),
                        ),
                        if (item.year.isNotEmpty) ...[
                          Text(' • ', style: TextStyle(color: skin.faint)),
                          Text(item.year, style: TextStyle(fontSize: 12, color: skin.muted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (item.overview != null && item.overview!.isNotEmpty)
                      Text(
                        item.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: skin.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Add actions
              PopupMenuButton<String>(
                tooltip: 'Добавить в список',
                enabled: !isAdded,
                onSelected: (status) => _addItem(item, status),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'watchlist',
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_border, size: 18),
                        SizedBox(width: 8),
                        Text('В планах (Watchlist)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'watching',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Смотрю сейчас'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'watched',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Просмотрено'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdded ? Colors.green.withValues(alpha: 0.15) : skin.hover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAdded ? Colors.green : skin.outline,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdded ? Icons.check : Icons.add,
                        size: 16,
                        color: isAdded ? Colors.green : skin.text,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAdded ? 'Добавлено' : 'Добавить',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAdded ? Colors.green : skin.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

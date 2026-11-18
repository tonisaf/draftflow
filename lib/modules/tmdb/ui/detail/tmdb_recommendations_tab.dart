import 'package:flutter/material.dart';

import '../../../../ui/design_tokens.dart';
import '../../../../ui/theme.dart';
import '../../models/tmdb_media_item.dart';
import '../../services/tmdb_image_cache.dart';
import 'tmdb_detail_models.dart';

class TmdbRecommendationsTab extends StatelessWidget {
  final bool hasApiToken;
  final bool isLoading;
  final List<TmdbMediaItem>? recommendations;
  final Set<int> addedToWatchlist;
  final Map<int, String> libraryStatusByTmdbId;
  final VoidCallback onOpenSettings;
  final VoidCallback onLoadRecommendations;
  final ValueChanged<TmdbMediaItem> onAddToWatchlist;
  final ValueChanged<TmdbMediaItem> onNavigateToMovie;

  const TmdbRecommendationsTab({
    super.key,
    required this.hasApiToken,
    required this.isLoading,
    required this.recommendations,
    required this.addedToWatchlist,
    required this.libraryStatusByTmdbId,
    required this.onOpenSettings,
    required this.onLoadRecommendations,
    required this.onAddToWatchlist,
    required this.onNavigateToMovie,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    if (!hasApiToken) {
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
                onPressed: onOpenSettings,
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

    if (isLoading) {
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

    if (recommendations == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoadRecommendations());
      return const SizedBox.shrink();
    }

    if (recommendations!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_outlined, size: 36, color: skin.faint),
              const SizedBox(height: 12),
              Text(
                'Похожие фильмы не найдены',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Для этого тайтла нет рекомендаций на сервере TMDB.',
                style: TextStyle(fontSize: 12, color: skin.muted),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 450) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 650) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.52,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: recommendations!.length,
          itemBuilder: (ctx, idx) {
            final rec = recommendations![idx];
            return TmdbRecommendationCard(
              rec: rec,
              libraryStatusByTmdbId: libraryStatusByTmdbId,
              addedToWatchlist: addedToWatchlist,
              onAddToWatchlist: onAddToWatchlist,
              onNavigateToMovie: onNavigateToMovie,
            );
          },
        );
      },
    );
  }
}

class TmdbRecommendationCard extends StatelessWidget {
  final TmdbMediaItem rec;
  final Map<int, String> libraryStatusByTmdbId;
  final Set<int> addedToWatchlist;
  final ValueChanged<TmdbMediaItem> onAddToWatchlist;
  final ValueChanged<TmdbMediaItem> onNavigateToMovie;

  const TmdbRecommendationCard({
    super.key,
    required this.rec,
    required this.libraryStatusByTmdbId,
    required this.addedToWatchlist,
    required this.onAddToWatchlist,
    required this.onNavigateToMovie,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final existingStatus = libraryStatusByTmdbId[rec.id];
    final isInWatchlist = existingStatus != null || addedToWatchlist.contains(rec.id);
    final statusColor = existingStatus != null ? getTmdbStatusColor(existingStatus) : const Color(0xFF10B981);

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
                  onTap: () => onNavigateToMovie(rec),
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
                          existingStatus != null ? getTmdbStatusLabel(existingStatus) : 'В планах',
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
                      onPressed: () => onAddToWatchlist(rec),
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
}

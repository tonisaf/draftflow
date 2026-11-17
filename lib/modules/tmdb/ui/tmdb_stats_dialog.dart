import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';

class TmdbStatsDialog extends StatelessWidget {
  final List<TmdbMediaItem> items;

  const TmdbStatsDialog({super.key, required this.items});

  static Future<void> show(BuildContext context, List<TmdbMediaItem> items) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TmdbStatsDialog',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => TmdbStatsDialog(items: items),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // 1. Counts
    final total = items.length;
    final moviesCount = items.where((i) => i.mediaType == 'movie').length;
    final tvCount = items.where((i) => i.mediaType == 'tv').length;
    final favCount = items.where((i) => i.isFavorite).length;

    // 2. Statuses
    final watchlist = items.where((i) => i.status == 'watchlist').length;
    final watching = items.where((i) => i.status == 'watching').length;
    final watched = items.where((i) => i.status == 'watched').length;
    final dropped = items.where((i) => i.status == 'dropped').length;

    // 3. Total Watchtime for watched items
    int totalMinutes = 0;
    for (final item in items.where((i) => i.status == 'watched')) {
      if (item.runtime != null && item.runtime! > 0) {
        totalMinutes += item.runtime!;
      } else {
        // Fallback estimate: 105 mins for movie, 300 mins for tv series
        totalMinutes += item.mediaType == 'tv' ? 300 : 105;
      }
    }

    final hours = totalMinutes ~/ 60;
    final days = hours ~/ 24;
    final remHours = hours % 24;
    final remMins = totalMinutes % 60;

    String watchtimeStr;
    if (days > 0) {
      watchtimeStr = '$days д $remHours ч $remMins м';
    } else if (hours > 0) {
      watchtimeStr = '$hours ч $remMins м';
    } else {
      watchtimeStr = '$remMins мин';
    }

    // 4. Ratings
    final ratedItems = items.where((i) => i.userRating != null && i.userRating! > 0).toList();
    double avgUserRating = 0.0;
    if (ratedItems.isNotEmpty) {
      avgUserRating = ratedItems.map((i) => i.userRating!).reduce((a, b) => a + b) / ratedItems.length;
    }

    // Rating distribution (1 to 10)
    final ratingDist = <int, int>{};
    for (int r = 1; r <= 10; r++) {
      ratingDist[r] = 0;
    }
    for (final item in ratedItems) {
      final score = item.userRating!.round().clamp(1, 10);
      ratingDist[score] = (ratingDist[score] ?? 0) + 1;
    }
    final maxRatingCount = ratingDist.values.fold<int>(1, (max, v) => v > max ? v : max);

    // 5. Genres
    final genreFreq = <String, int>{};
    for (final item in items) {
      for (final g in item.genres) {
        if (g.trim().isNotEmpty) {
          genreFreq[g] = (genreFreq[g] ?? 0) + 1;
        }
      }
    }
    final sortedGenres = genreFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(5).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 720),
          decoration: BoxDecoration(
            color: skin.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: skin.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Title Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: skin.sidebar,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Palette.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics_outlined, size: 20, color: Palette.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Аналитика медиатеки',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: skin.text,
                            ),
                          ),
                          Text(
                            'Статистика просмотров, времени, жанров и оценок',
                            style: TextStyle(fontSize: 11, color: skin.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      iconSize: 20,
                      icon: Icon(Icons.close_rounded, color: skin.muted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: skin.divider),

              // Scrollable Dashboard Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KPI Stat Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              skin,
                              title: 'Всего в базе',
                              value: '$total',
                              subtitle: '$moviesCount фильмов, $tvCount сериалов',
                              icon: Icons.movie_filter_outlined,
                              accentColor: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              skin,
                              title: 'Время просмотра',
                              value: watchtimeStr,
                              subtitle: '≈ $watched просмотренных фильмов',
                              icon: Icons.hourglass_top_rounded,
                              accentColor: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              skin,
                              title: 'Средняя оценка',
                              value: avgUserRating > 0 ? avgUserRating.toStringAsFixed(1) : '—',
                              subtitle: ratedItems.isNotEmpty ? '${ratedItems.length} оценок выставлено' : 'Оценок нет',
                              icon: Icons.star_rounded,
                              accentColor: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              skin,
                              title: 'В избранном',
                              value: '$favCount',
                              subtitle: total > 0 ? '${((favCount / total) * 100).round()}% от медиатеки' : '—',
                              icon: Icons.favorite_rounded,
                              accentColor: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Status Funnel (Multi-segment progress bar)
                      Text(
                        'Статусы коллекции',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
                      ),
                      const SizedBox(height: 10),
                      if (total > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 12,
                            child: Row(
                              children: [
                                if (watchlist > 0)
                                  Expanded(
                                    flex: watchlist,
                                    child: Container(color: const Color(0xFF6366F1)),
                                  ),
                                if (watching > 0)
                                  Expanded(
                                    flex: watching,
                                    child: Container(color: const Color(0xFFF59E0B)),
                                  ),
                                if (watched > 0)
                                  Expanded(
                                    flex: watched,
                                    child: Container(color: const Color(0xFF10B981)),
                                  ),
                                if (dropped > 0)
                                  Expanded(
                                    flex: dropped,
                                    child: Container(color: const Color(0xFFEF4444)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _statusLegend('В планах', watchlist, total, const Color(0xFF6366F1), skin),
                            _statusLegend('Смотрю', watching, total, const Color(0xFFF59E0B), skin),
                            _statusLegend('Просмотрено', watched, total, const Color(0xFF10B981), skin),
                            _statusLegend('Брошено', dropped, total, const Color(0xFFEF4444), skin),
                          ],
                        ),
                      ] else ...[
                        Text('Нет данных по статусам', style: TextStyle(color: skin.muted, fontSize: 12)),
                      ],
                      const SizedBox(height: 28),

                      // Two Column Section: Top Genres & Rating Distribution
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Top Genres
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Топ любимых жанров',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
                                ),
                                const SizedBox(height: 12),
                                if (topGenres.isNotEmpty)
                                  ...topGenres.map((e) {
                                    final pct = total > 0 ? (e.value / total) : 0.0;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                e.key,
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: skin.text),
                                              ),
                                              Text(
                                                '${e.value} (${(pct * 100).round()}%)',
                                                style: TextStyle(fontSize: 11, color: skin.muted),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: pct.clamp(0.0, 1.0),
                                              minHeight: 6,
                                              backgroundColor: skin.sidebar,
                                              valueColor: const AlwaysStoppedAnimation(Palette.accent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                else
                                  Text('Жанры пока не определены', style: TextStyle(color: skin.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right: Rating Distribution Chart
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Распределение ваших оценок',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
                                ),
                                const SizedBox(height: 12),
                                if (ratedItems.isNotEmpty)
                                  Container(
                                    height: 140,
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(10, (idx) {
                                        final star = idx + 1;
                                        final count = ratingDist[star] ?? 0;
                                        final heightFactor = maxRatingCount > 0 ? (count / maxRatingCount) : 0.0;

                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                if (count > 0)
                                                  Text(
                                                    '$count',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                const SizedBox(height: 2),
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 300),
                                                  height: (heightFactor * 80).clamp(4.0, 80.0),
                                                  decoration: BoxDecoration(
                                                    color: count > 0 ? Colors.amber : skin.sidebar,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '$star',
                                                  style: TextStyle(fontSize: 10, color: skin.muted),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.star_outline_rounded, size: 36, color: skin.faint),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Вы пока не выставили ни одной оценки',
                                            style: TextStyle(color: skin.muted, fontSize: 12),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(
    Skin skin, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.sidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: skin.muted)),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: skin.text),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: skin.faint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statusLegend(String label, int count, int total, Color color, Skin skin) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count ($pct%)',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: skin.muted),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../../models/tmdb_media_item.dart';
import 'tmdb_detail_models.dart';

class TmdbInteractiveRatingPicker extends StatefulWidget {
  final double? userRating;
  final ValueChanged<double?> onRatingChanged;

  const TmdbInteractiveRatingPicker({
    super.key,
    required this.userRating,
    required this.onRatingChanged,
  });

  @override
  State<TmdbInteractiveRatingPicker> createState() => _TmdbInteractiveRatingPickerState();
}

class _TmdbInteractiveRatingPickerState extends State<TmdbInteractiveRatingPicker> {
  double? _hoveredStarRating;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final currentScore = widget.userRating;
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
                    onTap: () => widget.onRatingChanged(null),
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
                                  clipper: FractionalClipper(fillFraction),
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
                                  onTap: () => widget.onRatingChanged(leftVal),
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
                                  onTap: () => widget.onRatingChanged(rightVal),
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
                        widget.onRatingChanged(0.5);
                      } else if (currentScore % 1 != 0) {
                        widget.onRatingChanged(currentScore.floorToDouble());
                      } else {
                        if (currentScore < 10.0) {
                          widget.onRatingChanged(currentScore + 0.5);
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
                        ? '${displayScore % 1 == 0 ? displayScore.toInt() : displayScore.toStringAsFixed(1)} / 10 • ${getTmdbRatingFeedbackText(displayScore)}'
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
}

class TmdbRatingsCard extends StatelessWidget {
  final TmdbMediaItem item;
  final bool isLoadingKp;
  final bool hasKpToken;
  final VoidCallback onRefreshKinopoisk;
  final VoidCallback? onOpenSettings;

  const TmdbRatingsCard({
    super.key,
    required this.item,
    required this.isLoadingKp,
    required this.hasKpToken,
    required this.onRefreshKinopoisk,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final hasTmdb = item.voteAverage != null && item.voteAverage! > 0;
    final hasKp = item.kpRating != null && item.kpRating! > 0;
    final hasImdb = (item.imdbRating != null && item.imdbRating! > 0) || (item.imdbId != null && item.imdbId!.isNotEmpty);

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
              if (isLoadingKp)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (hasKpToken)
                GestureDetector(
                  onTap: onRefreshKinopoisk,
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
          TmdbRatingSourceRow(
            iconWidget: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
            ),
            sourceName: 'TMDB',
            score: hasTmdb ? item.voteAverage!.toStringAsFixed(1) : '—',
            scoreColor: Colors.amber,
            subtext: item.voteCount != null ? '${item.voteCount} оценок' : null,
            onOpenUrl: () => openExternalUrl(item.tmdbWebUrl),
            urlTooltip: 'Открыть страницу фильма на TMDB',
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: skin.divider),
          const SizedBox(height: 8),

          // Kinopoisk Rating Row
          TmdbRatingSourceRow(
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
            score: hasKp ? item.kpRating!.toStringAsFixed(1) : (hasKpToken ? '—' : 'Нет ключа'),
            scoreColor: hasKp ? const Color(0xFFFF5500) : skin.muted,
            subtext: hasKp && item.kpVotes != null ? '${item.kpVotes} оценок' : null,
            onOpenUrl: item.kinopoiskWebUrl != null
                ? () => openExternalUrl(item.kinopoiskWebUrl!)
                : (!hasKpToken && onOpenSettings != null ? onOpenSettings : null),
            urlTooltip: item.kinopoiskWebUrl != null
                ? 'Открыть страницу на Кинопоиске'
                : (!hasKpToken ? 'Настроить API Кинопоиска в настройках' : null),
          ),

          // IMDb Rating Row (if available)
          if (hasImdb) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: skin.divider),
            const SizedBox(height: 8),
            TmdbRatingSourceRow(
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
              score: item.imdbRating != null && item.imdbRating! > 0
                  ? item.imdbRating!.toStringAsFixed(1)
                  : (item.imdbId != null ? '↗' : '—'),
              scoreColor: const Color(0xFFD97706),
              onOpenUrl: item.imdbWebUrl != null ? () => openExternalUrl(item.imdbWebUrl!) : null,
              urlTooltip: 'Открыть страницу фильма на IMDb',
            ),
          ],
        ],
      ),
    );
  }
}

class TmdbRatingSourceRow extends StatelessWidget {
  final Widget iconWidget;
  final String sourceName;
  final String score;
  final Color scoreColor;
  final String? subtext;
  final VoidCallback? onOpenUrl;
  final String? urlTooltip;

  const TmdbRatingSourceRow({
    super.key,
    required this.iconWidget,
    required this.sourceName,
    required this.score,
    required this.scoreColor,
    this.subtext,
    this.onOpenUrl,
    this.urlTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
                  subtext!,
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
}

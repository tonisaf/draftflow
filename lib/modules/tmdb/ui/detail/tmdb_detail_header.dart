import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../../models/tmdb_media_item.dart';

class TmdbDetailTopBar extends StatelessWidget {
  final TmdbMediaItem item;
  final bool isLoadingDetails;
  final Animation<double> heartScale;
  final VoidCallback? onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onClose;

  const TmdbDetailTopBar({
    super.key,
    required this.item,
    required this.isLoadingDetails,
    required this.heartScale,
    this.onBack,
    required this.onToggleFavorite,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: skin.surface.withValues(alpha: 0.85),
      child: Row(
        children: [
          if (onBack != null) ...[
            InkWell(
              onTap: onBack,
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
                  item.mediaType == 'tv' ? Icons.tv : Icons.movie_filter_outlined,
                  size: 13,
                  color: item.mediaType == 'tv' ? Colors.purple : Palette.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  item.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                ),
                if (isLoadingDetails) ...[
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
          if (item.youtubeTrailerUrl != null) ...[
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
              onPressed: () => openExternalUrl(item.youtubeTrailerUrl!),
            ),
            const SizedBox(width: 10),
          ],

          // Favorite Button
          ScaleTransition(
            scale: heartScale,
            child: IconButton(
              tooltip: item.isFavorite ? 'В избранном' : 'Добавить в избранное',
              iconSize: 20,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                item.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: item.isFavorite ? Colors.redAccent : skin.muted,
              ),
              onPressed: onToggleFavorite,
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
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class TmdbDetailRightHeader extends StatelessWidget {
  final TmdbMediaItem item;

  const TmdbDetailRightHeader({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    final metaItems = <String>[];
    if (item.year.isNotEmpty) metaItems.add(item.year);
    if (item.formattedRuntime.isNotEmpty) metaItems.add(item.formattedRuntime);
    if (item.director != null && item.director!.isNotEmpty) {
      metaItems.add('Реж. ${item.director!}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title in crisp dark theme text
        Text(
          item.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: skin.text,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (item.originalTitle != null && item.originalTitle != item.title) ...[
          const SizedBox(height: 2),
          Text(
            item.originalTitle!,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: skin.muted,
            ),
          ),
        ],
        if (item.tagline != null && item.tagline!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '«${item.tagline}»',
            style: const TextStyle(
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
            if (metaItems.isNotEmpty && item.genres.isNotEmpty)
              Text(
                '•',
                style: TextStyle(fontSize: 12, color: skin.faint),
              ),
            for (final genre in item.genres) GenrePill(label: genre),
          ],
        ),
      ],
    );
  }
}

class GenrePill extends StatelessWidget {
  final String label;

  const GenrePill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Palette.accent,
        ),
      ),
    );
  }
}

PopupMenuItem<String> buildTmdbStatusItem({
  required String currentStatus,
  required String value,
  required String label,
  required Color color,
  required IconData icon,
}) {
  final isSelected = currentStatus == value;
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

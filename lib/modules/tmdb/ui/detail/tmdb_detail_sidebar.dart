import 'package:flutter/material.dart';

import '../../../../ui/design_tokens.dart';
import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../../models/tmdb_media_item.dart';
import '../../services/tmdb_image_cache.dart';
import 'tmdb_detail_header.dart';
import 'tmdb_detail_models.dart';
import 'tmdb_rating_section.dart';

class TmdbDetailSidebar extends StatelessWidget {
  final TmdbMediaItem item;
  final bool isLoadingKp;
  final bool hasKpToken;
  final ValueChanged<String> onUpdateStatus;
  final ValueChanged<double?> onUpdateRating;
  final VoidCallback onRefreshKinopoisk;
  final VoidCallback onOpenSettings;
  final VoidCallback onDeleteItem;

  const TmdbDetailSidebar({
    super.key,
    required this.item,
    required this.isLoadingKp,
    required this.hasKpToken,
    required this.onUpdateStatus,
    required this.onUpdateRating,
    required this.onRefreshKinopoisk,
    required this.onOpenSettings,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final statusColor = getTmdbStatusColor(item.status);

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
                imageUrl: item.posterUrl('w500'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status Selector Dropdown (Apple HIG Soft Surface)
        PopupMenuButton<String>(
          tooltip: 'Изменить статус',
          initialValue: item.status,
          onSelected: onUpdateStatus,
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
                    getTmdbStatusLabel(item.status),
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
            buildTmdbStatusItem(
              currentStatus: item.status,
              value: 'watchlist',
              label: 'В планах',
              color: const Color(0xFF6366F1),
              icon: Icons.bookmark_rounded,
            ),
            buildTmdbStatusItem(
              currentStatus: item.status,
              value: 'watching',
              label: 'Смотрю сейчас',
              color: const Color(0xFFF59E0B),
              icon: Icons.play_circle_fill_rounded,
            ),
            buildTmdbStatusItem(
              currentStatus: item.status,
              value: 'watched',
              label: 'Просмотрено',
              color: const Color(0xFF10B981),
              icon: Icons.check_circle_rounded,
            ),
            buildTmdbStatusItem(
              currentStatus: item.status,
              value: 'dropped',
              label: 'Брошено',
              color: const Color(0xFFEF4444),
              icon: Icons.cancel_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Interactive Star Rating Widget
        TmdbInteractiveRatingPicker(
          userRating: item.userRating,
          onRatingChanged: onUpdateRating,
        ),
        const SizedBox(height: 14),

        // Multi-Source Ratings Card (TMDB, Kinopoisk, IMDb)
        TmdbRatingsCard(
          item: item,
          isLoadingKp: isLoadingKp,
          hasKpToken: hasKpToken,
          onRefreshKinopoisk: onRefreshKinopoisk,
          onOpenSettings: onOpenSettings,
        ),
        const SizedBox(height: 14),

        // TMDB Web Link Button
        OutlinedButton.icon(
          onPressed: () => openExternalUrl(item.tmdbWebUrl),
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
          onPressed: onDeleteItem,
          icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
          label: const Text('Удалить из списка', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
        ),
      ],
    );
  }
}

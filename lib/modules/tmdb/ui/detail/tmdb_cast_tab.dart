import 'package:flutter/material.dart';

import '../../../../ui/design_tokens.dart';
import '../../../../ui/theme.dart';
import '../../models/tmdb_media_item.dart';
import '../../services/tmdb_image_cache.dart';
import 'tmdb_detail_models.dart';

class TmdbCastTab extends StatelessWidget {
  final TmdbMediaItem item;
  final bool isLoading;
  final bool hasApiToken;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;
  final void Function(int? personId, String name, String? role, String? profilePath) onPersonTap;

  const TmdbCastTab({
    super.key,
    required this.item,
    required this.isLoading,
    required this.hasApiToken,
    required this.onOpenSettings,
    required this.onRefresh,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
                'Загрузка списка актёров с TMDB...',
                style: TextStyle(fontSize: 13, color: skin.muted),
              ),
            ],
          ),
        ),
      );
    }

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
                'Для загрузки состава актёров, ролей и съёмочной группы укажите API токен в настройках.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.crew.isNotEmpty) ...[
          _buildCrewSection(skin),
          const SizedBox(height: 24),
        ],
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
                    'Съёмочная группа и авторы (${item.crew.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: skin.text),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, size: 16, color: skin.muted),
                tooltip: 'Обновить данные',
                splashRadius: 16,
                onPressed: onRefresh,
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
          itemCount: item.crew.length,
          itemBuilder: (ctx, idx) {
            final member = item.crew[idx];
            final roleColor = getTmdbCrewRoleColor(member.job);
            return InkWell(
              onTap: () => onPersonTap(
                member.id,
                member.name,
                member.job,
                member.profilePath,
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
                                  getTmdbCrewRoleIcon(member.job),
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
                    'В главных ролях (${item.cast.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: skin.text),
                  ),
                ],
              ),
              if (item.crew.isEmpty)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 16, color: skin.muted),
                  tooltip: 'Обновить актёров',
                  splashRadius: 16,
                  onPressed: onRefresh,
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
          itemCount: item.cast.length,
          itemBuilder: (ctx, idx) {
            final actor = item.cast[idx];
            return InkWell(
              onTap: () => onPersonTap(
                actor.id,
                actor.name,
                actor.character != null && actor.character!.isNotEmpty
                    ? 'в роли ${actor.character!}'
                    : 'Актёр',
                actor.profilePath,
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
}

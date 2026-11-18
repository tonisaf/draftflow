import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../../models/tmdb_media_item.dart';
import 'tmdb_actor_card.dart';

class TmdbOverviewTab extends StatelessWidget {
  final TmdbMediaItem item;
  final VoidCallback onShowAllCast;
  final void Function(int? personId, String name, String? role, String? profilePath) onPersonTap;

  const TmdbOverviewTab({
    super.key,
    required this.item,
    required this.onShowAllCast,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
          item.overview != null && item.overview!.isNotEmpty
              ? item.overview!
              : 'Описание для данного фильма отсутствует.',
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: skin.muted,
          ),
        ),

        // Key Creators & Production Info (Apple HIG Clean Card)
        if (item.crew.isNotEmpty || (item.director != null && item.director!.isNotEmpty)) ...[
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
                if (item.directors.isNotEmpty || (item.director != null && item.director!.isNotEmpty))
                  TmdbCrewInfoRow(
                    icon: Icons.movie_creation_outlined,
                    label: item.mediaType == 'tv' ? 'Создатели' : 'Режиссёр',
                    members: item.directors,
                    fallbackName: item.director,
                    accentColor: skin.muted,
                    onPersonTap: onPersonTap,
                  ),
                if (item.writers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TmdbCrewInfoRow(
                    icon: Icons.edit_note_rounded,
                    label: 'Сценарий и авторы',
                    members: item.writers,
                    accentColor: skin.muted,
                    onPersonTap: onPersonTap,
                  ),
                ],
                if (item.producers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TmdbCrewInfoRow(
                    icon: Icons.business_center_outlined,
                    label: 'Продюсеры',
                    members: item.producers.take(3).toList(),
                    accentColor: skin.muted,
                    onPersonTap: onPersonTap,
                  ),
                ],
                if (item.composers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TmdbCrewInfoRow(
                    icon: Icons.music_note_rounded,
                    label: 'Композитор',
                    members: item.composers,
                    accentColor: skin.muted,
                    onPersonTap: onPersonTap,
                  ),
                ],
              ],
            ),
          ),
        ] else
          const SizedBox(height: 24),

        // Quick Cast Preview (if available)
        if (item.cast.isNotEmpty) ...[
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
                onTap: onShowAllCast,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Все создатели и актёры (${item.crew.length + item.cast.length}) →',
                    style: const TextStyle(fontSize: 11, color: Palette.accent, fontWeight: FontWeight.bold),
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
              itemCount: item.cast.take(6).length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (ctx, idx) {
                final actor = item.cast[idx];
                return TmdbActorCard(actor: actor, onPersonTap: onPersonTap);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class TmdbCrewInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<TmdbCrewMember> members;
  final String? fallbackName;
  final Color accentColor;
  final void Function(int? personId, String name, String? role, String? profilePath) onPersonTap;

  const TmdbCrewInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.members,
    this.fallbackName,
    required this.accentColor,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
                      onTap: () => onPersonTap(
                        m.id,
                        m.name,
                        m.job,
                        m.profilePath,
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
              : (fallbackName != null && fallbackName!.isNotEmpty)
                  ? InkWell(
                      onTap: () => onPersonTap(
                        null,
                        fallbackName!,
                        label,
                        null,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          fallbackName!,
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
}

import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../../models/tmdb_media_item.dart';
import '../../services/tmdb_image_cache.dart';

class TmdbActorCard extends StatelessWidget {
  final TmdbCastMember actor;
  final void Function(int? personId, String name, String? role, String? profilePath) onPersonTap;

  const TmdbActorCard({
    super.key,
    required this.actor,
    required this.onPersonTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return InkWell(
      onTap: () => onPersonTap(
        actor.id,
        actor.name,
        actor.character != null && actor.character!.isNotEmpty
            ? 'в роли ${actor.character!}'
            : 'Актёр',
        actor.profilePath,
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
}

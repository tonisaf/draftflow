import 'package:flutter/material.dart';
import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_image_cache.dart';

class TmdbCard extends StatefulWidget {
  final TmdbMediaItem item;
  final VoidCallback onTap;
  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<bool>? onFavoriteToggled;
  final ValueChanged<double?>? onRatingChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayTrailer;

  const TmdbCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onStatusChanged,
    this.onFavoriteToggled,
    this.onRatingChanged,
    this.onDelete,
    this.onPlayTrailer,
  });

  @override
  State<TmdbCard> createState() => _TmdbCardState();
}

class _TmdbCardState extends State<TmdbCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _heartAnimController;
  late final Animation<double> _heartScaleAnimation;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 55),
    ]).animate(_heartAnimController);
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
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
        return 'Смотрю';
      case 'watched':
        return 'Просмотрено';
      case 'dropped':
        return 'Брошено';
      case 'watchlist':
      default:
        return 'В планах';
    }
  }

  void _triggerHeartAnimation() {
    _heartAnimController.forward(from: 0.0);
    widget.onFavoriteToggled?.call(!widget.item.isFavorite);
  }

  void _showRatingDialog(BuildContext context) {
    final skin = context.skin;
    double? currentRating = widget.item.userRating;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: skin.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiRadius.modal),
              side: BorderSide(color: skin.outline),
            ),
            title: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Оценить «${widget.item.title}»',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: skin.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(10, (index) {
                    final score = index + 1;
                    final isSelected = currentRating != null && currentRating! >= score;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => currentRating = score.toDouble());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isSelected ? Colors.amber : skin.faint,
                            size: 26,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  currentRating != null
                      ? '${currentRating! % 1 == 0 ? currentRating!.toInt() : currentRating!.toStringAsFixed(1)} из 10'
                      : 'Нажмите на звезду для оценки',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: currentRating != null ? Colors.amber : skin.muted,
                  ),
                ),
              ],
            ),
            actions: [
              if (currentRating != null)
                TextButton(
                  onPressed: () {
                    widget.onRatingChanged?.call(null);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Сбросить оценку', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text('Отмена', style: TextStyle(color: skin.muted)),
              ),
              FilledButton(
                onPressed: () {
                  widget.onRatingChanged?.call(currentRating);
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final item = widget.item;
    final statusColor = _getStatusColor(item.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : (_isHovered ? 1.012 : 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: skin.sidebar,
              borderRadius: BorderRadius.circular(UiRadius.card),
              border: Border.all(
                color: _isHovered ? skin.text.withValues(alpha: 0.18) : skin.outline,
                width: 1.0,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Poster Area
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Smooth Zooming Poster Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(UiRadius.card - 1),
                        ),
                        child: AnimatedScale(
                          scale: _isHovered ? 1.025 : 1.0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: TmdbCachedImage(
                            imageUrl: item.posterUrl('w500'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Subtle gradient for badges readability at top and bottom of poster
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                              stops: const [0.0, 0.25, 0.72, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // TOP-LEFT: Ratings (TMDB & User Rating)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TMDB Score Badge
                            if (item.voteAverage != null && item.voteAverage! > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.voteAverage!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Kinopoisk Score Badge (if present)
                            if (item.kpRating != null && item.kpRating! > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5500).withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'КП ',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white70,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      item.kpRating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Personal Rating Badge (if user rated)
                            if (item.userRating != null && item.userRating! > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.grade_rounded, size: 11, color: Colors.white),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.userRating! % 1 == 0
                                          ? item.userRating!.toInt().toString()
                                          : item.userRating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // TOP-RIGHT: Action buttons (Heart & 3-dots Menu)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 3-dots More Actions Menu (Visible on hover)
                            AnimatedOpacity(
                              opacity: _isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 160),
                              child: PopupMenuButton<String>(
                                tooltip: 'Действия',
                                icon: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Icon(Icons.more_vert, size: 16, color: Colors.white),
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(UiRadius.control),
                                  side: BorderSide(color: skin.outline),
                                ),
                                onSelected: (action) {
                                  switch (action) {
                                    case 'rate':
                                      _showRatingDialog(context);
                                      break;
                                    case 'tmdb':
                                      openExternalUrl(item.tmdbWebUrl);
                                      break;
                                    case 'delete':
                                      widget.onDelete?.call();
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'rate',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_border_rounded, size: 16, color: Colors.amber),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.userRating != null ? 'Изменить оценку' : 'Поставить оценку',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'tmdb',
                                    child: Row(
                                      children: [
                                        Icon(Icons.launch, size: 16),
                                        SizedBox(width: 8),
                                        Text('Открыть на TMDB', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Удалить', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Heart Favorite Button
                            AnimatedOpacity(
                              opacity: (_isHovered || item.isFavorite) ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 160),
                              child: ScaleTransition(
                                scale: _heartScaleAnimation,
                                child: GestureDetector(
                                  onTap: _triggerHeartAnimation,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: item.isFavorite
                                            ? Colors.redAccent.withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.2),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Icon(
                                      item.isFavorite ? Icons.favorite : Icons.favorite_border,
                                      size: 16,
                                      color: item.isFavorite ? Colors.redAccent : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BOTTOM-LEFT of Poster: Media Type Badge
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.mediaType == 'tv' ? Icons.tv : Icons.movie_outlined,
                                size: 10,
                                color: item.mediaType == 'tv'
                                    ? Colors.purple.shade200
                                    : Colors.blue.shade200,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: item.mediaType == 'tv'
                                      ? Colors.purple.shade100
                                      : Colors.blue.shade100,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Metadata & Interactive Status
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Movie Title (two lines for full readability)
                      SizedBox(
                        height: 34,
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: -0.2,
                            color: skin.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Year, Rating & Status Row
                      Row(
                        children: [
                          Text(
                            item.year.isNotEmpty ? item.year : '—',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: skin.muted,
                            ),
                          ),
                          if (item.userRating != null && item.userRating! > 0) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                            Text(
                              item.userRating! % 1 == 0
                                  ? item.userRating!.toInt().toString()
                                  : item.userRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                          const Spacer(),

                          // Interactive Status Dropdown Pill (Things 3 soft borderless pill)
                          PopupMenuButton<String>(
                            tooltip: 'Сменить статус',
                            initialValue: item.status,
                            onSelected: (val) => widget.onStatusChanged?.call(val),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: skin.divider),
                            ),
                            itemBuilder: (ctx) => [
                              _buildStatusMenuItem('watchlist', 'В планах', const Color(0xFF6366F1), Icons.bookmark_rounded),
                              _buildStatusMenuItem('watching', 'Смотрю', const Color(0xFFF59E0B), Icons.play_circle_fill_rounded),
                              _buildStatusMenuItem('watched', 'Просмотрено', const Color(0xFF10B981), Icons.check_circle_rounded),
                              _buildStatusMenuItem('dropped', 'Брошено', const Color(0xFFEF4444), Icons.cancel_rounded),
                            ],
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getStatusLabel(item.status),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildStatusMenuItem(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    final isCurrent = widget.item.status == value;

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
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? color : null,
              ),
            ),
          ),
          if (isCurrent)
            Icon(Icons.check, size: 14, color: color),
        ],
      ),
    );
  }
}

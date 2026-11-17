import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../ui/theme.dart';
import '../models/tmdb_media_item.dart';
import '../services/tmdb_image_cache.dart';

class TmdbRandomPickerDialog extends StatefulWidget {
  final List<TmdbMediaItem> candidates;
  final ValueChanged<TmdbMediaItem> onSelect;
  final ValueChanged<TmdbMediaItem>? onStartWatching;

  const TmdbRandomPickerDialog({
    super.key,
    required this.candidates,
    required this.onSelect,
    this.onStartWatching,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TmdbMediaItem> allItems,
    required ValueChanged<TmdbMediaItem> onSelect,
    ValueChanged<TmdbMediaItem>? onStartWatching,
  }) {
    // Prefer items in watchlist, otherwise unwatched, otherwise all
    List<TmdbMediaItem> pool = allItems.where((i) => i.status == 'watchlist').toList();
    if (pool.isEmpty) {
      pool = allItems.where((i) => i.status != 'watched').toList();
    }
    if (pool.isEmpty) {
      pool = List.of(allItems);
    }

    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('В медиатеке пока нет фильмов для выбора. Добавьте фильмы через поиск!'),
        ),
      );
      return Future.value();
    }

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TmdbRandomPickerDialog',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => TmdbRandomPickerDialog(
        candidates: pool,
        onSelect: onSelect,
        onStartWatching: onStartWatching,
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<TmdbRandomPickerDialog> createState() => _TmdbRandomPickerDialogState();
}

class _TmdbRandomPickerDialogState extends State<TmdbRandomPickerDialog> with SingleTickerProviderStateMixin {
  late List<TmdbMediaItem> _pool;
  late TmdbMediaItem _currentItem;
  bool _isSpinning = false;
  Timer? _spinTimer;
  late final AnimationController _diceAnim;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _pool = List.of(widget.candidates);
    _currentItem = _pool[_random.nextInt(_pool.length)];
    _diceAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Auto-spin on dialog open for immediate excitement
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSpin());
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _diceAnim.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;
    setState(() => _isSpinning = true);
    _diceAnim.repeat();

    int step = 0;
    const totalSteps = 22;
    int intervalMs = 45;

    void tick() {
      if (!mounted) return;
      step++;

      setState(() {
        _currentItem = _pool[_random.nextInt(_pool.length)];
      });

      if (step < totalSteps) {
        // Progressively slow down like a real wheel of fortune
        if (step > 12) {
          intervalMs += 25;
        } else if (step > 17) {
          intervalMs += 60;
        }
        _spinTimer = Timer(Duration(milliseconds: intervalMs), tick);
      } else {
        _diceAnim.stop();
        _diceAnim.reset();
        setState(() => _isSpinning = false);
      }
    }

    tick();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 580,
          decoration: BoxDecoration(
            color: skin.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: skin.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: skin.sidebar,
                child: Row(
                  children: [
                    RotationTransition(
                      turns: _diceAnim,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Palette.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.casino_rounded, size: 20, color: Palette.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Что посмотреть сегодня?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: skin.text,
                            ),
                          ),
                          Text(
                            _isSpinning
                                ? 'Крутим рулетку среди ваших планов...'
                                : 'Фильм выбран случайно из списка «В планах»',
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

              // Candidate Card Preview
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Movie Poster with animated scale pulse
                    AnimatedScale(
                      scale: _isSpinning ? 0.96 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: 150,
                        height: 225,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(UiRadius.card),
                          border: Border.all(color: skin.outline),
                          boxShadow: [
                            BoxShadow(
                              color: _isSpinning
                                  ? Palette.accent.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.18),
                              blurRadius: _isSpinning ? 20 : 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(UiRadius.card),
                          child: TmdbCachedImage(
                            imageUrl: _currentItem.posterUrl('w500'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Movie Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type & Rating Badges
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: skin.sidebar,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: skin.outline),
                                ),
                                child: Text(
                                  _currentItem.mediaType == 'tv' ? '📺 Сериал' : '🎬 Фильм',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: skin.text),
                                ),
                              ),
                              if (_currentItem.voteAverage != null && _currentItem.voteAverage! > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                      const SizedBox(width: 3),
                                      Text(
                                        _currentItem.voteAverage!.toStringAsFixed(1),
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
                          const SizedBox(height: 10),

                          // Title
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: Text(
                              _currentItem.title,
                              key: ValueKey(_currentItem.id),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: skin.text,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_currentItem.year.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _currentItem.year,
                              style: TextStyle(fontSize: 12, color: skin.muted),
                            ),
                          ],
                          const SizedBox(height: 10),

                          // Genres
                          if (_currentItem.genres.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _currentItem.genres.take(3).map((g) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Palette.accent.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    g,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Palette.accent,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),

                          // Overview preview
                          Text(
                            _currentItem.overview != null && _currentItem.overview!.isNotEmpty
                                ? _currentItem.overview!
                                : 'Описание отсутствует.',
                            style: TextStyle(fontSize: 12, height: 1.5, color: skin.muted),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: skin.divider),

              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: skin.sidebar,
                child: Row(
                  children: [
                    // Spin Again Button
                    OutlinedButton.icon(
                      onPressed: _isSpinning ? null : _startSpin,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Крутить ещё раз 🎲', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const Spacer(),

                    // Details Card Button
                    TextButton(
                      onPressed: _isSpinning
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onSelect(_currentItem);
                            },
                      child: const Text('Подробнее', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),

                    // Start Watching Button
                    FilledButton.icon(
                      onPressed: _isSpinning
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              if (widget.onStartWatching != null) {
                                widget.onStartWatching!(_currentItem);
                              } else {
                                widget.onSelect(_currentItem);
                              }
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Смотреть этот!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

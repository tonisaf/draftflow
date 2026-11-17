import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/theme.dart';

class TmdbFilterPopover extends StatefulWidget {
  final String? initialGenre;
  final List<String> allGenres;
  final String? initialDecade;
  final double? initialMinRating;
  final int? initialMaxRuntime;
  final int totalCount;
  final int filteredCount;
  final ValueChanged<String?> onGenreChanged;
  final ValueChanged<String?> onDecadeChanged;
  final ValueChanged<double?> onRatingChanged;
  final ValueChanged<int?> onRuntimeChanged;
  final VoidCallback onResetAll;

  const TmdbFilterPopover({
    super.key,
    required this.initialGenre,
    required this.allGenres,
    required this.initialDecade,
    required this.initialMinRating,
    required this.initialMaxRuntime,
    required this.totalCount,
    required this.filteredCount,
    required this.onGenreChanged,
    required this.onDecadeChanged,
    required this.onRatingChanged,
    required this.onRuntimeChanged,
    required this.onResetAll,
  });

  static Future<void> show({
    required BuildContext context,
    required GlobalKey anchorKey,
    required String? selectedGenre,
    required List<String> allGenres,
    required String? selectedDecade,
    required double? minRating,
    required int? maxRuntime,
    required int totalCount,
    required int filteredCount,
    required ValueChanged<String?> onGenreChanged,
    required ValueChanged<String?> onDecadeChanged,
    required ValueChanged<double?> onRatingChanged,
    required ValueChanged<int?> onRuntimeChanged,
    required VoidCallback onResetAll,
  }) {
    final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? const Offset(200, 100);
    final size = renderBox?.size ?? const Size(100, 38);
    final screenSize = MediaQuery.of(context).size;

    const popoverWidth = 380.0;
    double left = offset.dx + (size.width / 2) - (popoverWidth / 2);
    if (left + popoverWidth > screenSize.width - 16) {
      left = screenSize.width - popoverWidth - 16;
    }
    if (left < 16) left = 16;

    final top = offset.dy + size.height + 8;

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.04),
      barrierLabel: 'Закрыть фильтры',
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secAnim) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                type: MaterialType.transparency,
                child: TmdbFilterPopover(
                  initialGenre: selectedGenre,
                  allGenres: allGenres,
                  initialDecade: selectedDecade,
                  initialMinRating: minRating,
                  initialMaxRuntime: maxRuntime,
                  totalCount: totalCount,
                  filteredCount: filteredCount,
                  onGenreChanged: onGenreChanged,
                  onDecadeChanged: onDecadeChanged,
                  onRatingChanged: onRatingChanged,
                  onRuntimeChanged: onRuntimeChanged,
                  onResetAll: onResetAll,
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<TmdbFilterPopover> createState() => _TmdbFilterPopoverState();
}

class _TmdbFilterPopoverState extends State<TmdbFilterPopover> {
  late String? _genre;
  late String? _decade;
  late double? _minRating;
  late int? _maxRuntime;

  @override
  void initState() {
    super.initState();
    _genre = widget.initialGenre;
    _decade = widget.initialDecade;
    _minRating = widget.initialMinRating;
    _maxRuntime = widget.initialMaxRuntime;
  }

  bool get _hasActiveFilters =>
      _genre != null || _decade != null || _minRating != null || _maxRuntime != null;

  void _reset() {
    setState(() {
      _genre = null;
      _decade = null;
      _minRating = null;
      _maxRuntime = null;
    });
    widget.onGenreChanged(null);
    widget.onResetAll();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final screenSize = MediaQuery.of(context).size;

    return Container(
      width: 380,
      constraints: BoxConstraints(
        maxHeight: math.min(540.0, screenSize.height - 120),
      ),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: skin.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title & Reset Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 14, color: Palette.accent),
              ),
              const SizedBox(width: 8),
              Text(
                'Фильтры медиатеки',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: skin.text,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                GestureDetector(
                  onTap: _reset,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Сбросить все',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent.shade200,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: skin.divider.withValues(alpha: 0.5)),
          const SizedBox(height: 10),

          // Scrollable Sections
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 0: Genre
                  if (widget.allGenres.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ЖАНР',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: skin.muted,
                          ),
                        ),
                        if (_genre != null)
                          GestureDetector(
                            onTap: () {
                              setState(() => _genre = null);
                              widget.onGenreChanged(null);
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                'Все жанры',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Palette.accent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final g in widget.allGenres)
                          _buildPill(g, _genre == g, () {
                            final newVal = _genre == g ? null : g;
                            setState(() => _genre = newVal);
                            widget.onGenreChanged(newVal);
                          }, skin),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Section 1: Decades
                  Text(
                    'ЭПОХА',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: skin.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPill('Все годы', _decade == null, () {
                        setState(() => _decade = null);
                        widget.onDecadeChanged(null);
                      }, skin),
                      _buildPill('2020-е', _decade == '2020s', () {
                        setState(() => _decade = '2020s');
                        widget.onDecadeChanged('2020s');
                      }, skin),
                      _buildPill('2010-е', _decade == '2010s', () {
                        setState(() => _decade = '2010s');
                        widget.onDecadeChanged('2010s');
                      }, skin),
                      _buildPill('2000-е', _decade == '2000s', () {
                        setState(() => _decade = '2000s');
                        widget.onDecadeChanged('2000s');
                      }, skin),
                      _buildPill('90-е', _decade == '1990s', () {
                        setState(() => _decade = '1990s');
                        widget.onDecadeChanged('1990s');
                      }, skin),
                      _buildPill('80-е', _decade == '1980s', () {
                        setState(() => _decade = '1980s');
                        widget.onDecadeChanged('1980s');
                      }, skin),
                      _buildPill('< 1980', _decade == 'classic', () {
                        setState(() => _decade = 'classic');
                        widget.onDecadeChanged('classic');
                      }, skin),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 2: Rating
                  Text(
                    'МИНИМАЛЬНЫЙ РЕЙТИНГ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: skin.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPill('Любой', _minRating == null, () {
                        setState(() => _minRating = null);
                        widget.onRatingChanged(null);
                      }, skin),
                      _buildPill('★ 7.0+', _minRating == 7.0, () {
                        setState(() => _minRating = 7.0);
                        widget.onRatingChanged(7.0);
                      }, skin),
                      _buildPill('★ 7.5+', _minRating == 7.5, () {
                        setState(() => _minRating = 7.5);
                        widget.onRatingChanged(7.5);
                      }, skin),
                      _buildPill('★ 8.0+', _minRating == 8.0, () {
                        setState(() => _minRating = 8.0);
                        widget.onRatingChanged(8.0);
                      }, skin),
                      _buildPill('★ 8.5+', _minRating == 8.5, () {
                        setState(() => _minRating = 8.5);
                        widget.onRatingChanged(8.5);
                      }, skin),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 3: Runtime
                  Text(
                    'ХРОНОМЕТРАЖ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: skin.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPill('Любой', _maxRuntime == null, () {
                        setState(() => _maxRuntime = null);
                        widget.onRuntimeChanged(null);
                      }, skin),
                      _buildPill('< 90 мин', _maxRuntime == 90, () {
                        setState(() => _maxRuntime = 90);
                        widget.onRuntimeChanged(90);
                      }, skin),
                      _buildPill('< 120 мин', _maxRuntime == 120, () {
                        setState(() => _maxRuntime = 120);
                        widget.onRuntimeChanged(120);
                      }, skin),
                      _buildPill('< 150 мин', _maxRuntime == 150, () {
                        setState(() => _maxRuntime = 150);
                        widget.onRuntimeChanged(150);
                      }, skin),
                      _buildPill('150+ мин', _maxRuntime == 999, () {
                        setState(() => _maxRuntime = 999);
                        widget.onRuntimeChanged(999);
                      }, skin),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: skin.divider.withValues(alpha: 0.5)),
          const SizedBox(height: 10),

          // Footer: Done button & count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Найдено: ${widget.filteredCount} из ${widget.totalCount}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: skin.muted,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Готово', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, bool isSelected, VoidCallback onTap, Skin skin) {
    return _PopoverPill(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      skin: skin,
    );
  }
}

class _PopoverPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Skin skin;

  const _PopoverPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.skin,
  });

  @override
  State<_PopoverPill> createState() => _PopoverPillState();
}

class _PopoverPillState extends State<_PopoverPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final skin = widget.skin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? Palette.accent
                : (_isHovered
                    ? (skin.isDark ? const Color(0x32FFFFFF) : const Color(0x18000000))
                    : (skin.isDark ? const Color(0x16FFFFFF) : const Color(0x0C000000))),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Palette.accent
                  : (_isHovered
                      ? skin.muted.withValues(alpha: 0.6)
                      : skin.divider.withValues(alpha: 0.5)),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : skin.text,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme.dart';

/// Кинематографичный плавный переход контента при смене страниц и заметок.
/// Сочетает растворение прозрачности и мягкое доведение слоя по вертикали.
class PageEntrance extends StatefulWidget {
  const PageEntrance({
    super.key,
    required this.child,
    this.enableSlide = true,
  });

  final Widget child;
  final bool enableSlide;

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.panel,
    value: 0,
  );
  late final _fadeProgress = _controller.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  // Stagger: vertical motion finishes at 70% of duration (182ms) so the content
  // settles cleanly at Offset.zero well before the final frame, eliminating subpixel
  // snapping and text hinting pops.
  late final _slideProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeProgress,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _slideProgress,
            child: widget.child,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                widget.enableSlide
                    ? UiSpace.s8 * (1 - _slideProgress.value)
                    : 0,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

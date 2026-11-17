import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Tracks navigation without painting or resizing the whole pane.
class SectionTransition extends StatefulWidget {
  const SectionTransition({
    super.key,
    required this.section,
    required this.child,
  });

  final Object section;
  final Widget child;

  @override
  State<SectionTransition> createState() => _SectionTransitionState();
}

class _SectionTransitionState extends State<SectionTransition> {
  bool _navigated = false;

  @override
  void didUpdateWidget(SectionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != oldWidget.section) _navigated = true;
  }

  @override
  Widget build(BuildContext context) => _SectionNavigation(
    section: widget.section,
    animate: _navigated,
    child: RepaintBoundary(child: SectionContent(child: widget.child)),
  );
}

class _SectionNavigation extends InheritedWidget {
  const _SectionNavigation({
    required this.section,
    required this.animate,
    required super.child,
  });
  final Object section;
  final bool animate;

  @override
  bool updateShouldNotify(_SectionNavigation oldWidget) =>
      section != oldWidget.section || animate != oldWidget.animate;
}

const _staggerLimit = Duration(milliseconds: 180);

/// Mount after the first data result, so a slow query cannot consume the
/// entrance while rows are absent. Later stream updates keep this timeline.
class SectionContent extends StatefulWidget {
  const SectionContent({
    super.key,
    required this.child,
    this.animateOnMount = true,
  });
  final Widget child;
  final bool animateOnMount;

  @override
  State<SectionContent> createState() => _SectionContentState();
}

class _SectionContentState extends State<SectionContent>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.popover + _staggerLimit,
    value: 1,
  );
  Object? _section;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = context
        .dependOnInheritedWidgetOfExactType<_SectionNavigation>();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _controller.value = 1;
      return;
    }
    if (navigation != null) {
      if (navigation.section == _section) return;
      _section = navigation.section;
      if (navigation.animate) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    } else if (widget.animateOnMount && _section == null) {
      _section = Object();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SectionTimeline(controller: _controller, child: widget.child);
}

class _SectionTimeline extends InheritedWidget {
  const _SectionTimeline({required this.controller, required super.child});
  final AnimationController controller;

  @override
  bool updateShouldNotify(_SectionTimeline oldWidget) =>
      controller != oldWidget.controller;
}

/// Successive headings/rows move on isolated layers. Their layout stays fixed.
class SectionItem extends StatelessWidget {
  const SectionItem({
    super.key,
    required this.index,
    required this.child,
    this.fade = true,
    this.slide = true,
  });
  final int index;
  final Widget child;

  /// Large grids slide on a cached layer without full-pane opacity.
  final bool fade;
  final bool slide;

  @override
  Widget build(BuildContext context) {
    final timeline = context
        .dependOnInheritedWidgetOfExactType<_SectionTimeline>();
    if (timeline == null || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final delay = math.min(
      math.max(index, 0) * 36,
      _staggerLimit.inMilliseconds,
    );
    final total = (Motion.popover + _staggerLimit).inMilliseconds;
    final progress = timeline.controller.drive(
      CurveTween(
        curve: Interval(
          delay / total,
          (delay + Motion.popover.inMilliseconds) / total,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    final content = RepaintBoundary(child: child);
    final entrance = fade
        ? FadeTransition(opacity: progress, child: content)
        : content;
    if (!slide) return entrance;
    return AnimatedBuilder(
      animation: progress,
      child: entrance,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, Motion.sectionRise * (1 - progress.value)),
        child: child,
      ),
    );
  }
}

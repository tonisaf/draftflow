import 'package:flutter/material.dart';

import '../theme.dart';

/// Springs [child] into view with a subtle scale and optional translation from
/// [alignment]. Mid-flight reversals preserve both position and velocity.
/// Reduced motion snaps immediately without transform layers.
class GrowIn extends StatefulWidget {
  const GrowIn({
    super.key,
    required this.alignment,
    required this.child,
    this.distance = 0,
    this.open = true,
    this.onClosed,
  });

  /// The corner or edge the panel springs from, facing its anchor.
  final Alignment alignment;
  final double distance;
  final bool open;
  final Widget child;
  final VoidCallback? onClosed;

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.popover,
    reverseDuration: const Duration(milliseconds: 140),
    value: widget.open ? 1.0 : 0.0,
  )..addStatusListener((status) {
      if (!widget.open &&
          (status == AnimationStatus.dismissed ||
              status == AnimationStatus.completed) &&
          _c.value == 0) {
        _notifyClosed();
      }
    });

  late final _fadeAnimation = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInQuad,
  );

  // Stagger: the vertical glide reaches its resting point at 70% of duration (154ms),
  // leaving the remaining 66ms completely stationary while opacity softly settles.
  // Glyphs remain at constant 1:1 scale with zero text hinting snap or subpixel pop.
  late final _slideAnimation = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
  );

  bool? _reduced;
  bool _closeQueued = false;
  bool _closeNotified = false;

  void _notifyClosed() {
    if (widget.open || _closeQueued || _closeNotified) return;
    _closeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeQueued = false;
      if (!mounted || widget.open || _c.isAnimating || _c.value != 0) return;
      _closeNotified = true;
      widget.onClosed?.call();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _sync() {
    _reduced = MediaQuery.disableAnimationsOf(context);
    final target = widget.open ? 1.0 : 0.0;
    if (widget.open) _closeNotified = false;
    if (_reduced!) {
      _c.value = target;
      _notifyClosed();
      return;
    }
    if (!_c.isAnimating && _c.value == target) {
      _notifyClosed();
      return;
    }
    widget.open ? _c.forward() : _c.reverse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    _sync();
  }

  @override
  void didUpdateWidget(GrowIn old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      _sync();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          final t = _fadeAnimation.value.clamp(0.0, 1.0);
          final slideT = _slideAnimation.value.clamp(0.0, 1.0);
          Widget current = child!;
          if (!_reduced!) {
            final distance = widget.distance != 0 ? widget.distance : 6.0;
            // Direction: slide down if below anchor (y <= 0), slide up if above anchor (y > 0)
            final ySign = widget.alignment.y > 0 ? 1.0 : -1.0;
            // On exit (closing), stay stationary in place so content doesn't slide under cursor.
            // On enter (opening), glide smoothly into resting position.
            final isClosing =
                !widget.open || _c.status == AnimationStatus.reverse;
            final slide = isClosing ? 0.0 : (1.0 - slideT) * distance;
            current = Transform.translate(
              offset: Offset(0, slide * ySign),
              child: current,
            );
          }
          return Opacity(opacity: t, child: current);
        },
      ),
    );
  }
}

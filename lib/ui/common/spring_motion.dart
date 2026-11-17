import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme.dart';

/// Evaluates a [SpringSimulation] over normalized `0..1` progress so routes
/// and `CurvedAnimation` gain spring settling while keeping `[0, 1]` bounds.
class SpringCurve extends Curve {
  const SpringCurve([this.spring = Motion.spatialSpring]);
  final SpringDescription spring;

  @override
  double transformInternal(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final sim = SpringSimulation(spring, 0, 1, 0, snapToEnd: true);
    return sim.x(t * 0.35);
  }
}

/// Tactile spring scale-down on press, settling back cleanly when released.
class SpringPress extends StatelessWidget {
  const SpringPress({
    super.key,
    required this.pressed,
    required this.child,
    this.scale = 0.97,
  });

  final bool pressed;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return AnimatedScale(
        scale: pressed ? scale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: child,
      );
    }
    return SpringValue(
      value: pressed ? scale : 1.0,
      spring: Motion.spatialSpring,
      child: child,
      builder: (context, value, child) => value == 1.0
          ? child!
          : Transform.scale(scale: value, child: child),
    );
  }
}

/// A ticker clock that stops only when every physical component has settled.
class SpringClock extends Simulation {
  SpringClock(this.springs);
  final List<Simulation> springs;
  @override
  double x(double time) => time;
  @override
  double dx(double time) => 1;
  @override
  bool isDone(double time) => springs.every((s) => s.isDone(time));
}

/// Independent springs retain each component's presentation value and velocity
/// when retargeted. Geometry does not inherit a duration from a fade animation.
class SpringValues extends StatefulWidget {
  const SpringValues({
    super.key,
    required this.values,
    required this.builder,
    this.from,
    this.spring,
    this.child,
  });
  final List<double> values;
  final List<double>? from;
  final SpringDescription? spring;
  final Widget Function(BuildContext, List<double>, Widget?) builder;
  final Widget? child;
  @override
  State<SpringValues> createState() => _SpringValuesState();
}

class _SpringValuesState extends State<SpringValues>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController.unbounded(vsync: this);
  late List<double> _rest = widget.from ?? widget.values;
  List<SpringSimulation>? _springs;
  bool? _reduced;
  List<double> get _value =>
      _springs == null ? _rest : [for (final s in _springs!) s.x(_clock.value)];

  void _sync() {
    final at = _value;
    final velocity = _springs == null || !_clock.isAnimating
        ? List.filled(at.length, 0.0)
        : [for (final s in _springs!) s.dx(_clock.value)];
    _clock.stop();
    if (_reduced! || listEquals(at, widget.values)) {
      _springs = null;
      _rest = widget.values;
      return;
    }
    assert(at.length == widget.values.length);
    _springs = [
      for (var i = 0; i < at.length; i++)
        SpringSimulation(
          widget.spring ?? Motion.spring,
          at[i],
          widget.values[i],
          velocity[i],
          snapToEnd: true,
        ),
    ];
    _clock.value = 0;
    _clock.animateWith(SpringClock(_springs!));
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
  void didUpdateWidget(SpringValues oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values)) _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _value, child),
  );
}

class SpringValue extends StatelessWidget {
  const SpringValue({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.spring,
    this.child,
  });
  final double value;
  final double? from;
  final SpringDescription? spring;
  final Widget? child;
  final Widget Function(BuildContext, double, Widget?) builder;
  @override
  Widget build(BuildContext context) => SpringValues(
    values: [value],
    from: from == null ? null : [from!],
    spring: spring,
    child: child,
    builder: (context, values, child) => builder(context, values.single, child),
  );
}

class SpringRotation extends StatelessWidget {
  const SpringRotation({super.key, required this.turns, required this.child});
  final double turns;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return AnimatedRotation(
        turns: turns,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: child,
      );
    }
    return SpringValue(
      value: turns,
      child: child,
      builder: (context, value, child) =>
          RotationTransition(turns: AlwaysStoppedAnimation(value), child: child),
    );
  }
}

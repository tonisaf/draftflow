import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_scroll_behavior.dart';
import '../theme.dart';

/// Place inside a viewport so the pointer-signal resolver can select the
/// innermost scrollable before Flutter's immediate wheel handler runs.
class SmoothWheelRegion extends StatefulWidget {
  const SmoothWheelRegion({super.key, required this.child});

  final Widget child;

  @override
  State<SmoothWheelRegion> createState() => _SmoothWheelRegionState();
}

class _SmoothWheelRegionState extends State<SmoothWheelRegion> {
  static final _motions = Expando<_WheelMotion>();
  static final _active = <ScrollPosition, _WheelMotion>{};
  static bool _finishQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) &&
        !_finishQueued &&
        _active.isNotEmpty) {
      _finishQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishQueued = false;
        // The originating list item may already have been virtualized away.
        for (final entry in _active.entries.toList()) {
          _active.remove(entry.key);
          if (entry.key.context.storageContext.mounted) {
            entry.value.finish(entry.key);
          }
        }
      });
    }
  }

  void _onSignal(BuildContext context, PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        defaultTargetPlatform == TargetPlatform.windows ||
        !isDesktopPlatform(
          ScrollConfiguration.of(context).getPlatform(context),
        ) ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final flip = HardwareKeyboard.instance.logicalKeysPressed.any(
      ScrollConfiguration.of(context).pointerAxisModifiers.contains,
    );
    ScrollPosition? selected;
    double delta = 0;
    // Walk past exhausted inner viewports, matching native nested-wheel
    // propagation. Horizontal wheel / Shift+wheel stay on their own axis.
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        final position = scrollable.position;
        final axis = axisDirectionToAxis(position.axisDirection);
        var change = (axis == Axis.horizontal) != flip
            ? event.scrollDelta.dx
            : event.scrollDelta.dy;
        if (axisDirectionIsReversed(position.axisDirection)) change = -change;
        if (change != 0 &&
            position.hasContentDimensions &&
            position.physics.shouldAcceptUserOffset(position) &&
            (position.pixels + change).clamp(
                  position.minScrollExtent,
                  position.maxScrollExtent,
                ) !=
                position.pixels) {
          selected = position;
          delta = change;
          return false;
        }
      }
      return true;
    });
    if (selected == null) return;
    final position = selected!;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final motion = _motions[position] ??= _WheelMotion();
      _active[position] = motion;
      motion.scroll(position, delta, () => _active.remove(position));
      event.respond(allowPlatformDefault: false);
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerSignal: (event) => _onSignal(context, event),
    child: widget.child,
  );
}

class _WheelMotion {
  double? _target;
  double _direction = 0;
  int _generation = 0;

  void finish(ScrollPosition position) {
    final target = _target;
    if (target == null) return;
    ++_generation;
    _target = null;
    _direction = 0;
    position.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void scroll(ScrollPosition position, double delta, VoidCallback onSettled) {
    // Reversing cancels the untravelled distance immediately. Consecutive
    // notches accumulate instead of losing distance to restarted animations.
    final base =
        _target != null &&
            _direction == delta.sign &&
            position.isScrollingNotifier.value
        ? _target!
        : position.pixels;
    final target = (base + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _target = target;
    _direction = delta.sign;
    final generation = ++_generation;
    unawaited(
      position
          .animateTo(target, duration: Motion.wheel, curve: Motion.curve)
          .whenComplete(() {
            if (_generation == generation) {
              _target = null;
              onSettled();
            }
          }),
    );
    // Unlike a programmatic scroll-to, wheel motion must keep content hit
    // testable: otherwise the next notch misses this region and jumps natively.
    position.context.setIgnorePointer(false);
  }
}

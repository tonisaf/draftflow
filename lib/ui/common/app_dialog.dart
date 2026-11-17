import 'package:flutter/material.dart';

import '../theme.dart';
import 'spring_motion.dart';

export 'neo_surface.dart';

/// App dialog routes also react when Reduce Motion changes while they are open.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  AnimationStyle? animationStyle,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(
    _AppDialogRoute<T>(
      context: context,
      preferenceContext: context,
      builder: builder,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? context.skin.scrim,
      animationStyle: animationStyle ?? Motion.dialogStyle(context),
    ),
  );
}

class _AppDialogRoute<T> extends DialogRoute<T> {
  _AppDialogRoute({
    required this.preferenceContext,
    required super.context,
    required super.builder,
    required super.themes,
    required super.barrierDismissible,
    required super.barrierColor,
    required super.animationStyle,
  });

  final BuildContext preferenceContext;

  bool _reduced = false;
  bool _snapQueued = false;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    bool disabled = false;
    try {
      disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!disabled && preferenceContext.mounted) {
        disabled =
            MediaQuery.maybeOf(preferenceContext)?.disableAnimations ?? false;
      }
    } catch (_) {}
    _reduced = disabled;
    final duration = _reduced ? Duration.zero : Motion.popover;
    controller?.duration = duration;
    controller?.reverseDuration = duration;
    if (!_reduced) {
      const springCurve = SpringCurve();
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final opacity = Curves.easeOutCubic.transform(
            animation.value.clamp(0.0, 1.0),
          );
          final progress = springCurve.transform(animation.value);
          return FadeTransition(
            opacity: AlwaysStoppedAnimation(opacity),
            child: Transform.scale(
              scale: 0.96 + 0.04 * progress,
              child: Transform.translate(
                offset: Offset(0, UiSpace.s6 * (1 - progress)),
                child: child,
              ),
            ),
          );
        },
      );
    }
    // Return the final visual state now; finish the route/barrier after layout.
    if (controller?.isAnimating == true && !_snapQueued) {
      _snapQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _snapQueued = false;
        final current = controller;
        if (!_reduced || current == null || !current.isAnimating) return;
        current.value = current.status == AnimationStatus.reverse ? 0 : 1;
      });
    }
    return child;
  }
}

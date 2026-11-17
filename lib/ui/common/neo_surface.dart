import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme.dart';

/// Builds a Neo-HIG squircle outline with an optional hairline [borderColor].
RoundedSuperellipseBorder squircleShape(
  double radius, {
  Color? borderColor,
  double borderWidth = 1,
}) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: borderColor == null
      ? BorderSide.none
      : BorderSide(color: borderColor, width: borderWidth),
);

/// Translucent frosted-glass container with squircle clipping, a subtle
/// translucent hairline border and multi-layered diffuse shadows.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = UiRadius.panel,
    this.blur = 20,
    this.color,
    this.borderColor,
    this.shadows,
    this.padding,
    this.width,
    this.constraints,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final fill = color ?? (radius >= UiRadius.modal ? skin.glassStrong : skin.glassSurface);
    final edge = borderColor ?? skin.hairlineBorder;
    final radiusGeometry = BorderRadius.circular(radius);

    Widget inner = DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: squircleShape(radius, borderColor: edge),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    final shouldBlur = blur > 0 && defaultTargetPlatform != TargetPlatform.windows;
    if (shouldBlur) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: inner,
      );
    }

    final defaultShadows = radius >= UiRadius.modal
        ? skin.modalShadows
        : (radius >= UiRadius.card ? skin.popoverShadows : skin.cardShadows);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: squircleShape(radius),
        shadows: shadows ?? defaultShadows,
      ),
      child: Container(
        width: width,
        constraints: constraints,
        child: ClipRSuperellipse(borderRadius: radiusGeometry, child: inner),
      ),
    );
  }
}

/// Presents a modal dialog with spring scale physics (`0.95 -> 1.0`) and a
/// fast opacity fade, falling back cleanly when reduced motion is enabled.
Future<T?> showSpringDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color? barrierColor,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final reduced = MediaQuery.disableAnimationsOf(context);
  final scrim = barrierColor ?? context.skin.scrim;
  return navigator.push<T>(
    _SpringDialogRoute<T>(
      builder: builder,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: scrim,
      reduced: reduced,
    ),
  );
}

class _SpringDialogRoute<T> extends PopupRoute<T> {
  _SpringDialogRoute({
    required this.builder,
    required this.themes,
    required this.barrierDismissible,
    required this.barrierLabel,
    required this.barrierColor,
    required this.reduced,
  });

  final WidgetBuilder builder;
  final CapturedThemes themes;
  @override
  final bool barrierDismissible;
  @override
  final String barrierLabel;
  @override
  final Color barrierColor;
  final bool reduced;

  @override
  Duration get transitionDuration =>
      reduced ? Motion.micro : const Duration(milliseconds: 340);

  @override
  Duration get reverseTransitionDuration =>
      reduced ? Motion.micro : Motion.micro;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => SafeArea(child: themes.wrap(Builder(builder: builder)));

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduced) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _SpringDialogTransition(animation: animation, child: child);
  }
}

class _SpringDialogTransition extends StatefulWidget {
  const _SpringDialogTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<_SpringDialogTransition> createState() =>
      _SpringDialogTransitionState();
}

class _SpringDialogTransitionState extends State<_SpringDialogTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 0.95,
  );
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _sync(widget.animation.status);
    widget.animation.addStatusListener(_sync);
  }

  void _sync(AnimationStatus status) {
    final closing = status == AnimationStatus.reverse;
    final target = closing ? 0.96 : 1.0;
    _scale.animateWith(
      SpringSimulation(
        Motion.spatialSpring,
        _scale.value,
        target,
        _scale.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_sync);
    _fade.dispose();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: AnimatedBuilder(
      animation: _scale,
      child: widget.child,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
    ),
  );
}

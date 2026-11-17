import 'package:flutter/material.dart';

import '../theme.dart';

enum StatusTone { warning, danger, success }

/// Soft pastel status banner/pill with matching foreground color, keeping alerts
/// legible without harsh saturated fills.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: UiSpace.s10,
      vertical: UiSpace.s6,
    ),
    this.radius = UiRadius.control,
  });

  final StatusTone tone;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  static (Color bg, Color fg) colorsFor(Skin skin, StatusTone tone) =>
      switch (tone) {
        StatusTone.warning => (skin.warningBg, skin.warningText),
        StatusTone.danger => (skin.dangerBg, skin.dangerText),
        StatusTone.success => (skin.successBg, skin.successText),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(context.skin, tone);
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: bg,
        shape: UiRadius.squircle(radius),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontSize: UiType.body),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: child,
        ),
      ),
    );
  }
}

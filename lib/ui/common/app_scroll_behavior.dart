import 'package:flutter/material.dart';

bool isDesktopPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS => true,
  _ => false,
};

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = getPlatform(context);
    switch (platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return const ClampingScrollPhysics();
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => isDesktopPlatform(getPlatform(context))
      ? child
      : super.buildOverscrollIndicator(context, child, details);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }
    return Scrollbar(
      controller: details.controller,
      interactive: true,
      child: child,
    );
  }
}

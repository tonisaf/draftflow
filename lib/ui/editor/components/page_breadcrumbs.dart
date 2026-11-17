import 'package:flutter/material.dart' hide Page;

import '../../../data/db/app_database.dart';
import '../../../l10n/locale_controller.dart';
import '../../common/app_icons.dart';
import '../../common/quiet_button.dart';
import '../../theme.dart';

class PageBreadcrumbsBar extends StatelessWidget {
  final List<Page> breadcrumbs;
  final ValueChanged<String>? onNavigateToPage;
  final String? currentTitle;
  final bool onCover;

  const PageBreadcrumbsBar({
    super.key,
    required this.breadcrumbs,
    this.onNavigateToPage,
    this.currentTitle,
    this.onCover = false,
  });

  @override
  Widget build(BuildContext context) {
    if (breadcrumbs.isEmpty || (breadcrumbs.length == 1 && onCover)) {
      return const Spacer();
    }
    final skin = context.skin;

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < breadcrumbs.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.s3),
                  child: Icon(
                    AppIcons.chevronRight,
                    size: UiSpace.s12,
                    color: skin.hint,
                  ),
                ),
              Builder(
                builder: (context) {
                  final isCurrent = i == breadcrumbs.length - 1;
                  final rawTitle = isCurrent && currentTitle != null
                      ? currentTitle!
                      : breadcrumbs[i].title;
                  final displayTitle = rawTitle.trim().isEmpty
                      ? context.l10n.untitled
                      : rawTitle;
                  return BreadcrumbItem(
                    title: displayTitle,
                    icon: breadcrumbs[i].icon,
                    isCurrent: isCurrent,
                    onTap: !isCurrent && onNavigateToPage != null
                        ? () => onNavigateToPage!(breadcrumbs[i].id)
                        : null,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BreadcrumbItem extends StatelessWidget {
  final String title;
  final String? icon;
  final bool isCurrent;
  final VoidCallback? onTap;

  const BreadcrumbItem({
    super.key,
    required this.title,
    this.icon,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final color = isCurrent ? skin.text : skin.hint;

    Widget content({required bool hover, required bool focus}) => DecoratedBox(
      decoration: ShapeDecoration(
        color: hover || focus ? skin.hover : Palette.transparent,
        shape: UiRadius.squircle(
          UiRadius.small,
          side: focus
              ? BorderSide(color: skin.outline)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s6,
          vertical: UiSpace.s5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null && icon!.isNotEmpty) ...[
              SizedBox.square(
                dimension: UiSpace.s16,
                child: Center(
                  child: Text(
                    icon!,
                    style: const TextStyle(
                      fontSize: UiType.caption,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: UiSpace.s4),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: UiType.caption,
                height: 1,
                fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content(hover: false, focus: false);
    }

    return QuietButton(
      label: title,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          content(hover: hover, focus: focus),
    );
  }
}

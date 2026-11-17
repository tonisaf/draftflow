import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../common/app_icons.dart';
import '../common/quiet_button.dart';
import '../theme.dart';

class WindowNavToolbar extends StatelessWidget {
  const WindowNavToolbar({
    super.key,
    required this.onToggleSidebar,
    required this.isSidebarVisible,
    this.onNavigateBack,
    this.canNavigateBack = false,
    this.onNavigateForward,
    this.canNavigateForward = false,
    required this.onOpenSearch,
    this.keyPrefix = '',
  });

  final VoidCallback onToggleSidebar;
  final bool isSidebarVisible;
  final VoidCallback? onNavigateBack;
  final bool canNavigateBack;
  final VoidCallback? onNavigateForward;
  final bool canNavigateForward;
  final VoidCallback onOpenSearch;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Кнопка сворачивания/разворачивания сайдбара с иконкой как в Notion/ChatGPT
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_sidebar_toggle'),
          customIcon: (color) => SidebarToggleIcon(
            color: color,
            isSidebarVisible: isSidebarVisible,
          ),
          tooltip: isSidebarVisible
              ? '${l10n.hideSidebar} (⌘\\)'
              : '${l10n.showSidebar} (⌘\\)',
          onTap: onToggleSidebar,
        ),
        // Расстояние между переключателем сайдбара и историей навигации
        const SizedBox(width: 14.0),
        // Стрелка «Назад»
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_back'),
          icon: AppIcons.arrowLeft,
          tooltip: '${l10n.navBack} (⌘[)',
          onTap: onNavigateBack,
          enabled: canNavigateBack,
        ),
        // Минимальное расстояние в паре «Назад / Вперёд»
        const SizedBox(width: 6.0),
        // Стрелка «Вперёд»
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_forward'),
          icon: AppIcons.arrowRight,
          tooltip: '${l10n.navForward} (⌘])',
          onTap: onNavigateForward,
          enabled: canNavigateForward,
        ),
        // Расстояние перед кнопкой глобального поиска
        const SizedBox(width: 14.0),
        // Поиск
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_search'),
          icon: AppIcons.search,
          tooltip: '${l10n.search} (⌘K)',
          onTap: onOpenSearch,
        ),
      ],
    );
  }
}

class SidebarToggleIcon extends StatelessWidget {
  const SidebarToggleIcon({
    super.key,
    required this.color,
    this.isSidebarVisible = true,
  });

  final Color color;
  final bool isSidebarVisible;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 14),
      painter: _SidebarToggleIconPainter(
        color: color,
        isFilled: isSidebarVisible,
      ),
    );
  }
}

class _SidebarToggleIconPainter extends CustomPainter {
  const _SidebarToggleIconPainter({
    required this.color,
    required this.isFilled,
  });

  final Color color;
  final bool isFilled;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.35;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    const cornerRadius = 2.8;
    final outerRect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(cornerRadius),
    );

    // Внешняя аккуратная скругленная рамка
    canvas.drawRRect(outerRRect, strokePaint);

    final splitX = outerRect.left + outerRect.width * 0.38;

    // Вертикальная разделительная черта сайдбара
    canvas.drawLine(
      Offset(splitX, outerRect.top),
      Offset(splitX, outerRect.bottom),
      strokePaint,
    );

    // Заливка левой колонки, если сайдбар открыт (как на эталонном скриншоте)
    if (isFilled) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final leftPaneRRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          outerRect.left,
          outerRect.top,
          splitX - outerRect.left,
          outerRect.height,
        ),
        topLeft: const Radius.circular(cornerRadius),
        bottomLeft: const Radius.circular(cornerRadius),
      );
      canvas.drawRRect(leftPaneRRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SidebarToggleIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isFilled != isFilled;
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    super.key,
    this.icon,
    this.customIcon,
    required this.tooltip,
    this.onTap,
    this.enabled = true,
  }) : assert(icon != null || customIcon != null);

  final IconData? icon;
  final Widget Function(Color color)? customIcon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Tooltip(
      message: tooltip,
      waitDuration: Motion.tooltipDelay,
      preferBelow: true,
      verticalOffset: UiSpace.s12,
      child: QuietButton(
        label: tooltip,
        onTap: enabled ? onTap : null,
        builder: (context, {required hover, required focus, required pressed}) {
          final color = enabled
              ? (hover ? skin.text : skin.muted)
              : skin.faint;
          return Container(
            width: UiSpace.s28,
            height: UiSpace.s28,
            decoration: ShapeDecoration(
              color: enabled && (hover || focus)
                  ? skin.hover
                  : Palette.transparent,
              shape: UiRadius.squircle(
                UiRadius.small,
                side: focus ? BorderSide(color: skin.outline) : BorderSide.none,
              ),
            ),
            child: Center(
              child: customIcon != null
                  ? customIcon!(color)
                  : Icon(
                      icon,
                      size: UiSpace.s16,
                      color: color,
                    ),
            ),
          );
        },
      ),
    );
  }
}

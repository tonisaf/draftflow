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
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;
    final gap = isWindows ? 4.0 : 14.0;
    final arrowGap = isWindows ? 4.0 : 6.0;
    final mod = isWindows ? 'Ctrl' : '⌘';

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
              ? '${l10n.hideSidebar} ($mod\\)'
              : '${l10n.showSidebar} ($mod\\)',
          onTap: onToggleSidebar,
        ),
        // Расстояние между переключателем сайдбара и историей навигации
        SizedBox(width: gap),
        // Стрелка «Назад»
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_back'),
          icon: AppIcons.arrowLeft,
          tooltip: '${l10n.navBack} ($mod[)',
          onTap: onNavigateBack,
          enabled: canNavigateBack,
        ),
        // Минимальное расстояние в паре «Назад / Вперёд»
        SizedBox(width: arrowGap),
        // Стрелка «Вперёд»
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_forward'),
          icon: AppIcons.arrowRight,
          tooltip: '${l10n.navForward} ($mod])',
          onTap: onNavigateForward,
          enabled: canNavigateForward,
        ),
        // Расстояние перед кнопкой глобального поиска
        SizedBox(width: gap),
        // Поиск
        _NavIconButton(
          key: ValueKey('${keyPrefix}nav_search'),
          icon: AppIcons.search,
          tooltip: isWindows
              ? '${l10n.search} (Ctrl+K)'
              : '${l10n.search} (⌘K)',
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
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;
    final disabledColor = isWindows
        ? (skin.isDark
            ? Colors.white.withValues(alpha: 0.24)
            : Colors.black.withValues(alpha: 0.24))
        : skin.faint;
    final normalColor = isWindows && !skin.isDark
        ? const Color(0xFF4B5563)
        : skin.muted;

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
              ? (hover ? skin.text : normalColor)
              : disabledColor;
          return Container(
            width: UiSpace.s28,
            height: UiSpace.s28,
            decoration: isWindows
                ? BoxDecoration(
                    color: enabled && (hover || focus)
                        ? skin.hover
                        : Palette.transparent,
                    borderRadius: BorderRadius.circular(6.0),
                    border: focus ? Border.all(color: skin.outline) : null,
                  )
                : ShapeDecoration(
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

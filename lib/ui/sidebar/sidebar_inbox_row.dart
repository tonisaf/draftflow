import 'package:flutter/material.dart';

import '../common/app_icons.dart';
import '../common/spring_motion.dart';
import '../theme.dart';

class SidebarInboxRow extends StatefulWidget {
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;

  const SidebarInboxRow({
    super.key,
    required this.isSelected,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  State<SidebarInboxRow> createState() => _SidebarInboxRowState();
}

class _SidebarInboxRowState extends State<SidebarInboxRow> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final fill = widget.isSelected
        ? skin.sidebarSelected
        : (_hover ? skin.hover : Palette.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: SpringPress(
          pressed: _pressed,
          scale: 0.985,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: DesktopUx.sidebarRowHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s8,
              vertical: UiSpace.s4,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: UiSpace.s18,
                  child: Center(
                    child: Icon(
                      widget.unreadCount > 0 || widget.isSelected
                          ? AppIcons.trayFill
                          : AppIcons.tray,
                      size: UiSpace.s16,
                      color: widget.isSelected
                          ? Palette.accent
                          : (skin.isDark ? skin.muted : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
                const SizedBox(width: UiSpace.s8),
                Expanded(
                  child: Text(
                    'Входящие',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: widget.isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      letterSpacing: -0.1,
                      color: widget.isSelected
                          ? skin.text
                          : (skin.isDark ? skin.muted : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
                if (widget.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? Palette.accent.withValues(alpha: 0.15)
                          : (skin.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0x0F000000)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.unreadCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? Palette.accent
                            : (skin.isDark ? skin.muted : const Color(0xFF6B7280)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

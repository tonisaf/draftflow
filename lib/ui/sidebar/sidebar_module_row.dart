import 'package:flutter/material.dart';
import '../../modules/core/app_module.dart';
import '../common/spring_motion.dart';
import '../theme.dart';

class SidebarModuleRow extends StatefulWidget {
  final AppModule module;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarModuleRow({
    super.key,
    required this.module,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<SidebarModuleRow> createState() => _SidebarModuleRowState();
}

class _SidebarModuleRowState extends State<SidebarModuleRow> {
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
              vertical: UiSpace.s6,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
            ),
            child: Row(
              children: [
                Icon(
                  widget.module.icon,
                  size: UiSpace.s16,
                  color: widget.isSelected ? Palette.accent : skin.muted,
                ),
                const SizedBox(width: UiSpace.s8),
                Expanded(
                  child: Text(
                    widget.module.title,
                    style: TextStyle(
                      fontSize: UiType.body,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: widget.isSelected ? Palette.accent : skin.text,
                    ),
                    overflow: TextOverflow.ellipsis,
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

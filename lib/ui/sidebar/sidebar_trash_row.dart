import '../common/app_icons.dart';

import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../common/spring_motion.dart';
import '../theme.dart';

class SidebarTrashRow extends StatefulWidget {
  final bool isSelected;
  final int trashedCount;
  final VoidCallback onTap;

  const SidebarTrashRow({
    super.key,
    required this.isSelected,
    this.trashedCount = 0,
    required this.onTap,
  });

  @override
  State<SidebarTrashRow> createState() => _SidebarTrashRowState();
}

class _SidebarTrashRowState extends State<SidebarTrashRow> {
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
                    AppIcons.trash,
                    size: UiSpace.s16,
                    color: widget.isSelected ? skin.text : skin.muted,
                  ),
                ),
              ),
              const SizedBox(width: UiSpace.s8),
              Expanded(
                child: Text(
                  context.l10n.trash,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: widget.isSelected
                        ? FontWeight.w500
                        : FontWeight.w400,
                    letterSpacing: -0.1,
                    color: widget.isSelected ? skin.text : skin.muted,
                  ),
                ),
              ),
              if (widget.trashedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UiSpace.s6,
                    vertical: UiSpace.s1_5,
                  ),
                  decoration: BoxDecoration(
                    color: skin.hover,
                    borderRadius: BorderRadius.circular(UiRadius.badge),
                  ),
                  child: Text(
                    '${widget.trashedCount}',
                    style: TextStyle(
                      fontSize: UiType.small,
                      fontWeight: FontWeight.w600,
                      color: skin.muted,
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

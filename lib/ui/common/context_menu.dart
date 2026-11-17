import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'menu.dart';

class MenuEntry {
  const MenuEntry(
    this.icon,
    this.label,
    this.onTap, {
    this.destructive = false,
    this.separated = false,
    this.shortcut,
  });

  /// An icon glyph.
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Drawn in the destructive colour, always below a divider.
  final bool destructive;

  /// A divider above this entry (implied for [destructive]).
  final bool separated;

  final String? shortcut;

  bool get _divided => destructive || separated;
}

/// A context menu at a pointer position, in the same style as native macOS menus.
/// Closes on a click elsewhere, on Esc, or when an entry is chosen.
void showContextMenu(
  BuildContext context,
  Offset at,
  List<MenuEntry> entries, {
  VoidCallback? onClosed,
  double width = DesktopUx.popoverWidth,
}) {
  late final OverlayEntry overlay;
  final opener = FocusManager.instance.primaryFocus;
  final dividers = [
    for (final (i, e) in entries.indexed)
      if (i > 0 && e._divided) i,
  ].length;
  var open = true;
  void close() {
    if (!open) return;
    open = false;
    overlay.remove();
    overlay.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (opener?.context != null &&
          opener!.context!.mounted &&
          opener.canRequestFocus) {
        opener.requestFocus();
      }
    });
    onClosed?.call();
  }

  overlay = OverlayEntry(
    builder: (context) {
      final screen = MediaQuery.sizeOf(context);
      final height =
          UiSpace.s8 + DesktopUx.sidebarRowHeight * entries.length + 7.0 * dividers;
      final fitsLeft = at.dx < screen.width / 2;
      final double left =
          at.dx.clamp(8.0, math.max(8.0, screen.width - width - 8.0)).toDouble();
      final double top =
          at.dy.clamp(8.0, math.max(8.0, screen.height - height - 8.0)).toDouble();

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              onSecondaryTap: close,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): close,
              },
              child: MenuCard(
                alignment: fitsLeft ? Alignment.topLeft : Alignment.topRight,
                width: width,
                children: [
                  for (final (i, e) in entries.indexed) ...[
                    if (i > 0 && e._divided) const MenuDivider(),
                    MenuRow(
                      autofocus: i == 0,
                      glyph: e.icon,
                      destructive: e.destructive,
                      label: e.label,
                      shortcut: e.shortcut,
                      onTap: () {
                        e.onTap();
                        close();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  Overlay.of(context).insert(overlay);
}

import 'package:flutter/material.dart';

import '../theme.dart';
import 'spring_motion.dart';

/// One accessible press target for quiet icon and text buttons: keyboard
/// focus, hover and pressed state, a button role with a name, and activation
/// on release (a press that slides off is cancelled).
///
/// [builder] draws the content for the current interaction state.
class QuietButton extends StatefulWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.builder,
    this.onSecondaryTapDown,
    this.selected,
    this.checked,
    this.expanded,
    this.tooltip,
    this.autofocus = false,
    this.pressScale = 0.97,
  });

  /// The accessible name.
  final String label;

  /// Null disables the button.
  final VoidCallback? onTap;

  /// Secondary tap (right-click / context menu).
  final GestureTapDownCallback? onSecondaryTapDown;

  /// Marks a toggled-on button for assistive technology.
  final bool? selected;
  final bool? checked;
  final bool? expanded;

  /// Shown on hover and long-press when set.
  final String? tooltip;
  final bool autofocus;

  /// Tactile spring scale while pressed. Set to `1.0` when the child handles
  /// its own press compression (or when scale is disabled).
  final double pressScale;

  final Widget Function(
    BuildContext context, {
    required bool hover,
    required bool focus,
    required bool pressed,
  })
  builder;

  @override
  State<QuietButton> createState() => _QuietButtonState();
}

class _QuietButtonState extends State<QuietButton> {
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget button = Semantics(
      button: widget.checked == null,
      checked: widget.checked,
      expanded: widget.expanded,
      focusable: enabled,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: widget.pressScale == 1.0
              ? widget.builder(
                  context,
                  hover: _hover && enabled,
                  focus: _focus,
                  pressed: _pressed,
                )
              : SpringPress(
                  pressed: _pressed && enabled,
                  scale: widget.pressScale,
                  child: widget.builder(
                    context,
                    hover: _hover && enabled,
                    focus: _focus,
                    pressed: _pressed,
                  ),
                ),
        ),
      ),
    );
    final tip = widget.tooltip;
    if (tip != null) button = Tooltip(message: tip, child: button);
    return button;
  }
}

/// The close cross: muted, lit up with tactile feedback under the pointer.
class CloseCross extends StatelessWidget {
  const CloseCross({
    super.key,
    required this.onTap,
    this.tooltip = 'Close',
    this.size = UiSpace.s28,
    this.icon = Icons.close_rounded,
    this.iconSize = 17.0,
  });

  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: tooltip,
      tooltip: tooltip,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              color: pressed
                  ? skin.sidebarSelected
                  : hover
                  ? skin.hover
                  : Colors.transparent,
              shape: UiRadius.squircle(
                UiRadius.sidebarRow,
                side: focus
                    ? BorderSide(color: Palette.accent, width: UiSpace.s1_5)
                    : BorderSide.none,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: hover || pressed ? skin.text : skin.muted,
              ),
            ),
          ),
    );
  }
}

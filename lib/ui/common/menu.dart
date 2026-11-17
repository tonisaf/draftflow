import 'dart:ui' show ImageFilter;

import 'app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';

import '../theme.dart';
import 'grow_in.dart';
import 'spring_motion.dart';

/// Matches the primary modifiers registered by HomeScreen.
String menuShortcut(String key, {bool alt = false}) {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return '${alt ? '⌥' : ''}⌘$key';
  }
  return 'Ctrl+${alt ? 'Alt+' : ''}$key';
}

/// Shared desktop row height for all menu implementations.
const double kMenuRowHeight = DesktopUx.menuRowHeight;

/// Taps inside popups opened from the open document / cells (pick lists, dialogs)
/// must not count as "outside" the editor and close it: they share this group.
final Object editorTapGroup = Object();

/// The menu card. It grows out of its bottom-left corner, where the button is.
class MenuCard extends StatefulWidget {
  const MenuCard({
    super.key,
    required this.children,
    this.alignment = Alignment.bottomLeft,
    this.width = DesktopUx.menuWidth,
    this.open = true,
    this.onClosed,
    this.padding = const EdgeInsets.symmetric(vertical: UiSpace.s4),
    this.radius,
    this.frosted = true,
    this.shadows,
  }) : content = null,
       height = null,
       constraints = null,
       color = null,
       clipBehavior = Clip.antiAlias;

  /// Shared popup surface for forms. Keeps their layout and route animation.
  const MenuCard.surface({
    super.key,
    required Widget child,
    this.width,
    this.height,
    this.constraints,
    this.color,
    this.padding = EdgeInsets.zero,
    this.clipBehavior = Clip.antiAlias,
    this.radius,
    this.frosted = true,
    this.shadows,
  }) : content = child,
       children = const [],
       alignment = Alignment.topLeft,
       open = true,
       onClosed = null;

  final List<Widget> children;
  final Alignment alignment;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Color? color;
  final Clip clipBehavior;
  final Widget? content;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final bool frosted;
  final List<BoxShadow>? shadows;

  /// False plays the closing animation.
  final bool open;
  final VoidCallback? onClosed;

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  /// Flips on at the first arrow key; until then only hover highlights.
  final _arrows = ValueNotifier(false);

  @override
  void dispose() {
    _arrows.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.tab)) {
      _arrows.value = true;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final alignment = widget.alignment;
    if (widget.content != null) return _card(skin, alignment);
    return _KeyboardNav(
      notifier: _arrows,
      // A scope of its own keeps the arrow keys inside the menu.
      child: FocusScope(onKeyEvent: _onKey, child: _card(skin, alignment)),
    );
  }

  Widget _card(Skin skin, Alignment alignment) {
    final isSurface = widget.content != null;
    final effectiveRadius =
        widget.radius ?? (isSurface ? UiRadius.modal : UiRadius.dialog);
    final shape = UiRadius.squircle(effectiveRadius);
    final borderedShape = UiRadius.squircle(
      effectiveRadius,
      side: BorderSide(color: skin.hairlineBorder, width: UiRadius.hairline),
    );
    final shadows =
        widget.shadows ?? (isSurface ? skin.modalShadows : skin.popoverShadows);
    final useFrosted = widget.frosted &&
        defaultTargetPlatform != TargetPlatform.windows;
    final bg = useFrosted
        ? (widget.color != null
              ? widget.color!.withValues(alpha: isSurface ? 0.90 : 0.92)
              : (isSurface ? skin.glassStrong : skin.glassSurface))
        : (widget.color ?? (isSurface ? skin.surface : skin.card));

    Widget surface = Material(
      color: bg,
      shape: shape,
      child: Container(
        width: widget.width,
        height: widget.height,
        constraints: widget.constraints,
        padding: widget.padding,
        // Paint the edge without adding implicit content padding.
        foregroundDecoration: ShapeDecoration(shape: borderedShape),
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.left,
          child:
              widget.content ??
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
        ),
      ),
    );

    if (useFrosted) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: surface,
      );
    }

    final card = DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: shadows),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.all(Radius.circular(effectiveRadius)),
        clipBehavior: widget.clipBehavior,
        child: surface,
      ),
    );
    return isSurface
        ? card
        : GrowIn(
            alignment: alignment,
            open: widget.open,
            onClosed: widget.onClosed,
            child: card,
          );
  }
}

/// Whether the user has started navigating a menu with the arrow keys.
class _KeyboardNav extends InheritedNotifier<ValueNotifier<bool>> {
  const _KeyboardNav({
    required ValueNotifier<bool> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_KeyboardNav>()
          ?.notifier
          ?.value ??
      false;
}

/// The hairline between groups of rows, e.g. above a destructive action.
class MenuDivider extends StatelessWidget {
  const MenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: UiSpace.s3),
    child: Divider(
      height: 1,
      thickness: UiSpace.s1,
      color: context.skin.hairlineBorder,
    ),
  );
}

/// Quiet caption for Notes-specific action groups.
class MenuSectionHeader extends StatelessWidget {
  const MenuSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UiSpace.s12,
        UiSpace.s8,
        UiSpace.s12,
        UiSpace.s3,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: UiType.caption,
          fontWeight: FontWeight.w400,
          color: skin.hint,
        ),
      ),
    );
  }
}

class MenuRow extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.glyph,
    this.destructive = false,
    this.selected = false,
    this.highlighted = false,
    this.autofocus = false,
    this.reserveIconSpace = false,
    this.iconExtent = 18,
    this.iconSpacing = 10,
    this.shortcut,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DesktopUx.menuHorizontalPadding,
    ),
  });

  final Widget? icon;
  final String? shortcut;
  final Widget? trailing;

  /// A monochrome outline glyph: [Skin.hint] at rest, [Skin.text] on hover.
  /// Wins over [icon].
  final IconData? glyph;

  /// Text and glyph in [Skin.destructive]. Put a [MenuDivider] above it.
  final bool destructive;

  /// Keep action labels aligned when some rows have no icon.
  final bool reserveIconSpace;
  final double iconExtent;
  final double iconSpacing;
  final EdgeInsetsGeometry padding;

  /// The current value in a list of choices; drawn in the accent colour.
  final bool selected;

  /// Forced highlight, for lists that track their own keyboard position.
  final bool highlighted;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  final _node = FocusNode();
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final active =
        _hover || widget.highlighted || (_focus && _KeyboardNav.of(context));
    final tone = widget.destructive ? skin.destructive : skin.text;
    final glyph = widget.glyph;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        focusNode: _node,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: MouseRegion(
          // Instant, so a fast pass over the rows leaves no fading trail.
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
              scale: 0.98,
              child: Container(
                height: kMenuRowHeight,
                alignment: Alignment.centerLeft,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: active ? skin.hover : skin.hover.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(DesktopUx.menuRadius),
                ),
              child: Row(
                children: [
                  if (glyph != null ||
                      widget.icon != null ||
                      widget.reserveIconSpace) ...[
                    SizedBox.square(
                      dimension: widget.iconExtent,
                      child: Center(
                        child: glyph == null
                            ? IconTheme.merge(
                                data: IconThemeData(
                                  size: UiSpace.s15,
                                  color: widget.destructive
                                      ? skin.destructive
                                      : active
                                      ? skin.text
                                      : skin.hint,
                                ),
                                child: widget.icon ?? const SizedBox.shrink(),
                              )
                            : Icon(
                                glyph,
                                size: UiSpace.s15,
                                color: widget.destructive
                                    ? skin.destructive
                                    : active
                                    ? skin.text
                                    : skin.hint,
                              ),
                      ),
                    ),
                    SizedBox(width: widget.iconSpacing),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesktopUx.menuTextSize,
                        color: widget.destructive
                            ? skin.destructive
                            : widget.selected
                            ? skin.accentText
                            : tone,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (widget.shortcut != null) ...[
                    const SizedBox(width: UiSpace.s8),
                    Text(
                      widget.shortcut!,
                      style: TextStyle(
                        fontSize: UiType.small,
                        color: skin.hint,
                      ),
                    ),
                  ],
                  if (widget.selected && widget.trailing == null) ...[
                    const SizedBox(width: UiSpace.s8),
                    Icon(
                      AppIcons.checkMark,
                      size: UiSpace.s16,
                      color: widget.destructive
                          ? skin.destructive
                          : skin.accentText,
                    ),
                  ],
                  if (widget.trailing != null) ...[
                    const SizedBox(width: UiSpace.s6),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// A menu row with an on/off toggle switch (e.g. Small text, Full width).
class MenuToggleRow extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? glyph;
  final Key? switchKey;

  const MenuToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.glyph,
    this.switchKey,
  });

  @override
  State<MenuToggleRow> createState() => _MenuToggleRowState();
}

class _MenuToggleRowState extends State<MenuToggleRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      toggled: widget.value,
      label: widget.label,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!widget.value),
          child: Container(
            height: kMenuRowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
            decoration: ShapeDecoration(
              color: _hover ? skin.hover : Palette.transparent,
              shape: UiRadius.squircle(UiRadius.inner),
            ),
            child: Row(
              children: [
                if (widget.glyph != null) ...[
                  SizedBox.square(
                    dimension: UiSpace.s16,
                    child: Center(
                      child: Icon(
                        widget.glyph,
                        size: UiSpace.s15,
                        color: _hover ? skin.text : skin.hint,
                      ),
                    ),
                  ),
                  const SizedBox(width: UiSpace.s10),
                ],
                Expanded(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesktopUx.menuTextSize,
                      color: skin.text,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.72,
                  alignment: Alignment.centerRight,
                  child: Switch(
                    key: widget.switchKey,
                    value: widget.value,
                    onChanged: widget.onChanged,
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

/// The right-click menu of text fields (Cut, Copy, Paste, Select all),
/// drawn with native desktop MenuCard and icons instead of Material toolbar.
Widget appTextMenu(BuildContext context, EditableTextState state) {
  final items = [
    for (final item in state.contextMenuButtonItems)
      if (item.onPressed != null) item,
  ];
  if (items.isEmpty) return const SizedBox.shrink();

  IconData? glyphForType(ContextMenuButtonType type) {
    switch (type) {
      case ContextMenuButtonType.cut:
        return AppIcons.scissors;
      case ContextMenuButtonType.copy:
        return AppIcons.docOnDoc;
      case ContextMenuButtonType.paste:
        return AppIcons.docOnClipboard;
      case ContextMenuButtonType.selectAll:
        return AppIcons.selectionPinInOut;
      case ContextMenuButtonType.delete:
        return AppIcons.trash;
      default:
        return null;
    }
  }

  return TapRegion(
    groupId: editorTapGroup,
    child: TextFieldTapRegion(
      child: CustomSingleChildLayout(
        delegate: DesktopTextSelectionToolbarLayoutDelegate(
          anchor: state.contextMenuAnchors.primaryAnchor,
        ),
        child: MenuCard(
          alignment: Alignment.topLeft,
          width: UiLayout.textSelectionMenuWidth,
          children: [
            for (final item in items) ...[
              if (item.type == ContextMenuButtonType.delete)
                const MenuDivider(),
              MenuRow(
                label: AdaptiveTextSelectionToolbar.getButtonLabel(
                  context,
                  item,
                ),
                glyph: glyphForType(item.type),
                destructive: item.type == ContextMenuButtonType.delete,
                onTap: () {
                  item.onPressed!();
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

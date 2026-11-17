import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'menu.dart';

/// A small floating panel next to [anchor], in the app's menu style. It opens
/// above or below the anchor depending on room, lines up with its left or right edge,
/// and closes on Esc, a click elsewhere or [close]. Completes when closed.
Future<void> showPopover(
  BuildContext context, {
  required Rect anchor,
  required Widget Function(BuildContext context, VoidCallback close) builder,
  double width = DesktopUx.popoverWidth,
  EdgeInsetsGeometry menuPadding = const EdgeInsets.all(UiSpace.s4),
  AlignmentGeometry? alignment,
}) {
  final done = Completer<void>();
  late final OverlayEntry entry;
  final open = ValueNotifier(true);
  // Which side faces the anchor, reported by the layout that places the panel
  // so the grow origin and the position always agree. Initialized from screen space
  // so it doesn't need to flip orientation on the second frame.
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenHeight = mediaQuery?.size.height ?? 800.0;
  final screenWidth = mediaQuery?.size.width ?? 1200.0;
  final spaceBelow = screenHeight - anchor.bottom;
  final spaceAbove = anchor.top;
  final initialBelow = spaceBelow >= 240 || spaceBelow >= spaceAbove;
  final below = ValueNotifier(initialBelow);
  final initialAlignLeft = anchor.center.dx < screenWidth / 2;
  final alignLeft = ValueNotifier(initialAlignLeft);
  // Focus goes back to whatever opened the popover, so the keyboard user
  // carries on from the same button.
  final opener = FocusManager.instance.primaryFocus;
  var closing = false;
  void remove() {
    if (done.isCompleted) return;
    entry.remove();
    entry.dispose();
    open.dispose();
    below.dispose();
    alignLeft.dispose();
    done.complete();
  }

  void close() {
    if (closing) return;
    closing = true;
    open.value = false;
    if (opener != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (opener.context != null && opener.context!.mounted && opener.canRequestFocus) {
          opener.requestFocus();
        }
      });
    }
  }

  entry = OverlayEntry(
    builder: (context) => TapRegion(
      groupId: editorTapGroup,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              onSecondaryTap: close,
            ),
          ),
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _PopoverLayout(
                anchor,
                below,
                alignLeft,
                forcedAlignment: alignment,
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: below,
                builder: (context, isBelow, _) => ValueListenableBuilder<bool>(
                  valueListenable: alignLeft,
                  builder: (context, isLeft, _) => ValueListenableBuilder<bool>(
                    valueListenable: open,
                    builder: (context, isOpen, _) => _PopoverShell(
                      // Grows from the side that faces the anchor.
                      alignment: alignment?.resolve(TextDirection.ltr) ??
                          (isBelow
                              ? (isLeft ? Alignment.topLeft : Alignment.topRight)
                              : (isLeft ? Alignment.bottomLeft : Alignment.bottomRight)),
                      width: width,
                      menuPadding: menuPadding,
                      open: isOpen,
                      onClose: close,
                      onClosed: remove,
                      child: builder(context, close),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  return done.future;
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout(
    this.anchor,
    this.below,
    this.alignLeft, {
    this.forcedAlignment,
  });

  final Rect anchor;
  final ValueNotifier<bool> below;
  final ValueNotifier<bool> alignLeft;
  final AlignmentGeometry? forcedAlignment;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: (constraints.maxHeight - 16).clamp(0.0, double.infinity),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final forced = forcedAlignment?.resolve(TextDirection.ltr);
    final fitsLeft = forced != null
        ? forced.x < 0
        : (anchor.center.dx < size.width / 2);

    final double x;
    if (fitsLeft) {
      final left = anchor.left;
      x = left.clamp(
        8.0,
        (size.width - childSize.width - 8.0).clamp(8.0, double.infinity),
      );
    } else {
      final right = anchor.right - childSize.width;
      x = right.clamp(
        8.0,
        (size.width - childSize.width - 8.0).clamp(8.0, double.infinity),
      );
    }

    final top = anchor.bottom + 6;
    final fitsBelow = forced != null
        ? forced.y <= 0
        : (top + childSize.height <= size.height - 8);
    final y = fitsBelow
        ? top
        : (anchor.top - 6 - childSize.height).clamp(8.0, double.infinity);

    if (below.value != fitsBelow || alignLeft.value != fitsLeft) {
      // Layout must not notify mid-frame; the origin follows right after.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          below.value = fitsBelow;
          alignLeft.value = fitsLeft;
        } on FlutterError {
          // Closed and disposed in the meantime.
        }
      });
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.forcedAlignment != forcedAlignment;
}

class _PopoverShell extends StatefulWidget {
  const _PopoverShell({
    required this.alignment,
    required this.width,
    required this.menuPadding,
    required this.open,
    required this.onClose,
    required this.onClosed,
    required this.child,
  });

  final Alignment alignment;
  final double width;
  final EdgeInsetsGeometry menuPadding;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onClosed;
  final Widget child;

  @override
  State<_PopoverShell> createState() => _PopoverShellState();
}

class _PopoverShellState extends State<_PopoverShell> {
  // Focus lives in a scope of its own: Tab and the arrows cycle through the
  // popover's items and never reach the page behind it.
  final _scope = FocusScopeNode(debugLabel: 'popover');

  @override
  void initState() {
    super.initState();
    // Two frames: an item that asks for focus itself (autofocus) goes first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _scope.focusedChild != null) return;
        final first = FocusTraversalGroup.of(context)
            .findFirstFocus(_scope, ignoreCurrentFocus: true);
        (first?.ancestors.contains(_scope) ?? false ? first! : _scope)
            .requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      ignoring: !widget.open,
      child: ExcludeFocus(
        excluding: !widget.open,
        child: FocusScope(
          node: _scope,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MenuCard(
            alignment: widget.alignment,
            width: widget.width,
            padding: widget.menuPadding,
            open: widget.open,
            onClosed: widget.onClosed,
            children: [
              Flexible(child: SingleChildScrollView(child: widget.child)),
            ],
          ),
        ),
      ),
    ),
  );
}

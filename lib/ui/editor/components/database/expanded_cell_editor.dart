import 'database_grid_navigation.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/menu.dart';
import '../../../common/app_icons.dart';
import '../../../theme.dart';

class _CellEditorMetrics extends WidgetsBindingObserver {
  _CellEditorMetrics(this.close);
  final VoidCallback close;
  @override
  void didChangeMetrics() => close();
}

/// A full-cell anchor and overlay-local coordinates preserve row/text alignment.
/// Scroll/resize commits and closes rather than leaving an editor floating away.
Future<String?> showExpandedCellEditor(
  BuildContext context,
  String initialValue, {
  bool title = false,
  BuildContext? anchorContext,
  bool multiline = true,
  bool selectAll = false,
  TextInputType? keyboardType,
  double minWidth = UiLayout.cellEditorMinWidth,
  String? Function(String)? validationMessage,
  Widget Function(BuildContext, TextEditingController, VoidCallback)?
  accessoryBuilder,
  ValueChanged<VoidCallback>? onCloseReady,
  ValueChanged<String>? onSave,
}) {
  final navigation = DatabaseGridScope.maybeOf(context);
  final anchor = anchorContext ?? context;
  final box = anchor.findRenderObject() as RenderBox;
  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  final screen = overlayBox.size;
  final margin = math.min(UiSpace.s8, screen.width / 4);
  final width = math.min(
    math.max(box.size.width, minWidth),
    screen.width - margin * 2,
  );
  final left = origin.dx.clamp(
    margin,
    math.max(margin, screen.width - width - margin),
  );
  final below = screen.height - origin.dy - margin;
  final upwards = below < DesktopUx.databaseRowHeight && origin.dy > below;
  final height = math.min(
    UiLayout.cellEditorMaxHeight,
    upwards ? origin.dy + box.size.height - margin : below,
  );
  final controller = TextEditingController(text: initialValue);
  if (selectAll) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialValue.length,
    );
  }
  final result = Completer<String?>();
  final focus = FocusNode();
  final opener = FocusManager.instance.primaryFocus;
  var hadFocus = false, closed = false;
  late OverlayEntry entry;
  late _CellEditorMetrics metrics;
  final positions = <ScrollPosition>{};
  void close({bool cancel = false, bool keyboard = false, bool? reverseTab}) {
    if (closed) return;
    closed = true;
    WidgetsBinding.instance.removeObserver(metrics);
    for (final position in positions) {
      position.removeListener(close);
    }
    final value = controller.text;
    if (!cancel && value != initialValue) onSave?.call(value);
    entry.remove();
    entry.dispose();
    result.complete(cancel || value == initialValue ? null : value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      focus.dispose();
      if (navigation != null && keyboard) {
        if (reverseTab != null) {
          navigation.tab(reverseTab);
        } else {
          navigation.focus();
        }
      } else if (keyboard && opener?.context != null) {
        opener!.requestFocus();
      }
    });
  }

  metrics = _CellEditorMetrics(close);
  anchor.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      positions.add((element.state as ScrollableState).position);
    }
    return true;
  });
  for (final position in positions) {
    position.addListener(close);
  }
  WidgetsBinding.instance.addObserver(metrics);
  focus.addListener(() {
    if (focus.hasFocus) {
      hadFocus = true;
    } else if (hadFocus) {
      close();
    }
  });
  final skin = context.skin;
  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned(
          left: left.toDouble(),
          width: width,
          top: upwards
              ? null
              : origin.dy.clamp(
                  margin,
                  math.max(
                    margin,
                    screen.height - DesktopUx.databaseRowHeight - margin,
                  ),
                ),
          bottom: upwards ? screen.height - origin.dy - box.size.height : null,
          child: TapRegion(
            groupId: editorTapGroup,
            consumeOutsideTaps: false,
            onTapOutside: (_) => close(),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    close(cancel: true, keyboard: true),
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): () =>
                    close(keyboard: true),
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: true,
                ): () =>
                    close(keyboard: true),
                const SingleActivator(LogicalKeyboardKey.tab): () =>
                    close(keyboard: true, reverseTab: false),
                const SingleActivator(
                  LogicalKeyboardKey.tab,
                  shift: true,
                ): () =>
                    close(keyboard: true, reverseTab: true),
                if (!multiline)
                  const SingleActivator(LogicalKeyboardKey.enter): () =>
                      close(keyboard: true),
                if (!multiline)
                  const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                      close(keyboard: true),
              },
              child: MenuCard.surface(
                key: const Key('database_cell_editor_surface'),
                color: skin.card,
                radius: UiRadius.control,
                frosted: false,
                shadows: skin.popoverShadows,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: DesktopUx.databaseRowHeight,
                    maxHeight: math.max(DesktopUx.databaseRowHeight, height),
                  ),
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final error = validationMessage?.call(value.text);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const Key('expanded_database_cell'),
                                    focusNode: focus,
                                    autofocus: true,
                                    controller: controller,
                                    minLines: 1,
                                    maxLines: null,
                                    keyboardType:
                                        keyboardType ?? TextInputType.multiline,
                                    textInputAction: multiline
                                        ? TextInputAction.newline
                                        : TextInputAction.done,
                                    onSubmitted: multiline
                                        ? null
                                        : (_) => close(keyboard: true),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: title
                                              ? UiType.editorTitle
                                              : UiType.body,
                                          height: 1.4,
                                          fontWeight: title
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: skin.text,
                                        ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      visualDensity: VisualDensity.standard,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(
                                        UiSpace.s8,
                                      ),
                                    ),
                                  ),
                                ),
                                if (accessoryBuilder != null)
                                  accessoryBuilder(context, controller, close),
                              ],
                            ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  UiSpace.s8,
                                  0,
                                  UiSpace.s8,
                                  UiSpace.s8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Tooltip(
                                      message: error,
                                      child: Icon(
                                        AppIcons.exclamationmarkCircle,
                                        size: UiSpace.s14,
                                        color: skin.destructive,
                                      ),
                                    ),
                                    const SizedBox(width: UiSpace.s4),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          fontSize: UiType.caption,
                                          color: skin.destructive,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  onCloseReady?.call(close);
  overlay.insert(entry);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!closed) focus.requestFocus();
  });
  return result.future;
}

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:notes_here/ui/theme.dart';
import 'editor_link_popover.dart';

/// Crisp Retina-native typography and Cupertino glyphs for the editor floating bubble toolbar.
/// Replaces low-res 16x16 SVGs that suffer from aliasing / scaling artifacts.

class _RetinaToolbarButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _RetinaToolbarButton({
    required this.child,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(child: child),
      ),
    );
  }
}

ToolbarItem _buildFormatItem({
  required String id,
  required String attribute,
  required Widget Function(bool isHighlight, Color color) iconBuilder,
}) {
  return ToolbarItem(
    id: 'editor.$id',
    group: 2,
    isActive: onlyShowInTextType,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final selection = editorState.selection!;
      final nodes = editorState.getNodesInSelection(selection);
      final isHighlight = nodes.allSatisfyInSelection(
        selection,
        (delta) =>
            delta.isNotEmpty &&
            delta.everyAttributes((attr) => attr[attribute] == true),
      );

      final color = isHighlight ? highlightColor : (iconColor ?? context.skin.text);
      final child = _RetinaToolbarButton(
        onPressed: () => editorState.toggleAttribute(attribute),
        child: iconBuilder(isHighlight, color),
      );

      if (tooltipBuilder != null) {
        return tooltipBuilder(context, 'editor.$id', id, child);
      }
      return child;
    },
  );
}

final retinaBoldItem = _buildFormatItem(
  id: 'bold',
  attribute: 'bold',
  iconBuilder: (isHighlight, color) => Icon(
    CupertinoIcons.bold,
    size: 15.5,
    color: color,
  ),
);

final retinaItalicItem = _buildFormatItem(
  id: 'italic',
  attribute: 'italic',
  iconBuilder: (isHighlight, color) => Icon(
    CupertinoIcons.italic,
    size: 15.5,
    color: color,
  ),
);

final retinaStrikethroughItem = _buildFormatItem(
  id: 'strikethrough',
  attribute: 'strikethrough',
  iconBuilder: (isHighlight, color) => Icon(
    CupertinoIcons.strikethrough,
    size: 15.5,
    color: color,
  ),
);

final retinaCodeItem = _buildFormatItem(
  id: 'code',
  attribute: 'code',
  iconBuilder: (isHighlight, color) => Icon(
    CupertinoIcons.chevron_left_slash_chevron_right,
    size: 14.0,
    color: color,
  ),
);

final retinaUnderlineItem = _buildFormatItem(
  id: 'underline',
  attribute: 'underline',
  iconBuilder: (isHighlight, color) => Icon(
    CupertinoIcons.underline,
    size: 15.5,
    color: color,
  ),
);

final retinaLinkItem = ToolbarItem(
  id: 'editor.link',
  group: 4,
  isActive: onlyShowInSingleSelectionAndTextType,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection!;
    final nodes = editorState.getNodesInSelection(selection);
    final isHref = nodes.allSatisfyInSelection(selection, (delta) {
      return delta.everyAttributes(
        (attributes) => attributes[AppFlowyRichTextKeys.href] != null,
      );
    });

    final color = isHref ? highlightColor : (iconColor ?? context.skin.text);
    final child = _RetinaToolbarButton(
      onPressed: () =>
          showModernLinkPopover(context, editorState, selection, isHref),
      child: Icon(
        CupertinoIcons.link,
        size: 15.0,
        color: color,
      ),
    );

    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.link', 'link', child);
    }
    return child;
  },
);

ToolbarItem buildRetinaHighlightColorItem({List<ColorOption>? colorOptions}) {
  return ToolbarItem(
    id: 'editor.highlightColor',
    group: 4,
    isActive: onlyShowInTextType,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      String? highlightColorHex;
      final selection = editorState.selection!;
      final nodes = editorState.getNodesInSelection(selection);
      final isHighlight = nodes.allSatisfyInSelection(selection, (delta) {
        if (delta.everyAttributes((attr) => attr.isEmpty)) {
          return false;
        }
        return delta.everyAttributes((attributes) {
          highlightColorHex = attributes[AppFlowyRichTextKeys.backgroundColor];
          return highlightColorHex != null;
        });
      });

      final color = isHighlight ? highlightColor : (iconColor ?? context.skin.text);
      final child = _RetinaToolbarButton(
        onPressed: () {
          bool showClearButton = false;
          nodes.allSatisfyInSelection(selection, (delta) {
            if (!showClearButton) {
              showClearButton = delta.whereType<TextInsert>().any(
                (element) =>
                    element.attributes?[AppFlowyRichTextKeys.backgroundColor] != null,
              );
            }
            return true;
          });
          showColorMenu(
            context,
            editorState,
            selection,
            currentColorHex: highlightColorHex,
            isTextColor: false,
            highlightColorOptions: colorOptions,
            showClearButton: showClearButton,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.pencil,
              size: 14.0,
              color: color,
            ),
            const SizedBox(height: 1.5),
            Container(
              width: 13,
              height: 2.2,
              decoration: BoxDecoration(
                color: isHighlight
                    ? color
                    : (highlightColorHex != null
                        ? _parseHexColor(highlightColorHex)
                        : const Color(0xFFF59E0B)),
                borderRadius: BorderRadius.circular(1.0),
              ),
            ),
          ],
        ),
      );

      if (tooltipBuilder != null) {
        return tooltipBuilder(context, 'editor.highlightColor', 'highlightColor', child);
      }
      return child;
    },
  );
}

ToolbarItem buildRetinaTextColorItem({List<ColorOption>? colorOptions}) {
  return ToolbarItem(
    id: 'editor.textColor',
    group: 4,
    isActive: onlyShowInTextType,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      String? textColorHex;
      final selection = editorState.selection!;
      final nodes = editorState.getNodesInSelection(selection);
      final isHighlight = nodes.allSatisfyInSelection(selection, (delta) {
        if (delta.everyAttributes((attr) => attr.isEmpty)) {
          return false;
        }
        return delta.everyAttributes((attr) {
          textColorHex = attr[AppFlowyRichTextKeys.textColor];
          return textColorHex != null;
        });
      });

      final color = isHighlight ? highlightColor : (iconColor ?? context.skin.text);
      final child = _RetinaToolbarButton(
        onPressed: () {
          bool showClearButton = false;
          nodes.allSatisfyInSelection(
            selection,
            (delta) {
              if (!showClearButton) {
                showClearButton = delta.whereType<TextInsert>().any(
                  (element) =>
                      element.attributes?[AppFlowyRichTextKeys.textColor] != null,
                );
              }
              return true;
            },
          );
          showColorMenu(
            context,
            editorState,
            selection,
            currentColorHex: textColorHex,
            isTextColor: true,
            textColorOptions: colorOptions,
            showClearButton: showClearButton,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'A',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2.0),
            Container(
              width: 12,
              height: 2.2,
              decoration: BoxDecoration(
                color: isHighlight
                    ? color
                    : (textColorHex != null
                        ? _parseHexColor(textColorHex)
                        : Palette.accent),
                borderRadius: BorderRadius.circular(1.0),
              ),
            ),
          ],
        ),
      );

      if (tooltipBuilder != null) {
        return tooltipBuilder(context, 'editor.textColor', 'textColor', child);
      }
      return child;
    },
  );
}

Color _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return Palette.accent;
  try {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return Palette.accent;
}

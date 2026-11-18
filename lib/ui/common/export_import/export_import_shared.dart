import 'package:flutter/material.dart';

import '../../../ui/design_tokens.dart';
import '../../../ui/theme.dart';
import '../app_icons.dart';
import '../quiet_button.dart';

enum ExportImportMode { page, markdownImport, notionCsv, workspace }

ShapeDecoration panelDecoration(
  Skin skin, {
  double radius = UiRadius.dialog,
}) => ShapeDecoration(
  color: skin.card,
  shape: UiRadius.squircle(
    radius,
    side: BorderSide(color: skin.hairlineBorder),
  ),
);

InputDecoration dialogInputDecoration(
  Skin skin, {
  required String hintText,
  bool isTextArea = false,
}) {
  final radius = isTextArea ? UiRadius.dialog : UiRadius.pill;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(fontSize: UiType.caption, color: skin.hint),
    alignLabelWithHint: isTextArea,
    isDense: !isTextArea,
    filled: true,
    fillColor: isTextArea ? skin.card : skin.hover,
    contentPadding: isTextArea
        ? const EdgeInsets.all(UiSpace.s12)
        : const EdgeInsets.symmetric(
            horizontal: UiSpace.s12,
            vertical: UiSpace.s8,
          ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: skin.hairlineBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: Palette.accent),
    ),
  );
}

class ExportImportModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const ExportImportModePill({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      selected: isSelected,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s10,
              vertical: UiSpace.s5,
            ),
            decoration: ShapeDecoration(
              color: isSelected
                  ? Palette.accent.withValues(alpha: 0.12)
                  : hover
                  ? skin.sidebarSelected
                  : skin.hover,
              shape: StadiumBorder(
                side: BorderSide(
                  color: focus
                      ? skin.accentText
                      : isSelected
                      ? Palette.accent.withValues(alpha: 0.35)
                      : skin.hairlineBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: UiSpace.s14,
                  color: isSelected ? skin.accentText : skin.muted,
                ),
                const SizedBox(width: UiSpace.s5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: UiType.small,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.accentText : skin.muted,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class ExportImportTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const ExportImportTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      selected: isSelected,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s10,
              vertical: UiSpace.s6,
            ),
            decoration: ShapeDecoration(
              color: isSelected
                  ? skin.sidebarSelected
                  : hover
                  ? skin.hover
                  : Palette.transparent,
              shape: UiRadius.squircle(
                UiRadius.small,
                side: focus
                    ? BorderSide(color: skin.accentText)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: UiSpace.s15,
                  color: isSelected ? skin.text : skin.muted,
                ),
                const SizedBox(width: UiSpace.s6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: UiType.caption,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.text : skin.muted,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class ExportImportActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isAccent;
  final VoidCallback? onTap;

  const ExportImportActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.isAccent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final disabled = onTap == null;
    final bg = isAccent
        ? (disabled ? Palette.accent.withValues(alpha: 0.35) : Palette.accent)
        : skin.hover;
    final fg = isAccent
        ? (disabled
              ? Palette.onAccent.withValues(alpha: 0.7)
              : Palette.onAccent)
        : (disabled ? skin.muted : skin.text);
    return QuietButton(
      label: label,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s14,
              vertical: UiSpace.s8,
            ),
            decoration: ShapeDecoration(
              color: !disabled && hover && !isAccent
                  ? skin.sidebarSelected
                  : bg,
              shape: StadiumBorder(
                side: focus
                    ? BorderSide(color: skin.accentText, width: 1.5)
                    : isAccent
                    ? BorderSide.none
                    : BorderSide(color: skin.hairlineBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: UiSpace.s14, color: fg),
                const SizedBox(width: UiSpace.s6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: UiType.caption,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

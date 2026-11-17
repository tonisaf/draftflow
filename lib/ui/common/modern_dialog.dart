import 'menu.dart';
import 'quiet_button.dart';

import 'package:flutter/material.dart';
import 'package:notes_here/ui/theme.dart';

InputDecoration modernInputDecoration({required Skin skin, String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(fontSize: UiType.body, color: skin.hint),
    filled: true,
    fillColor: skin.surfaceSubtle,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: UiSpace.s11,
      vertical: UiSpace.s9,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UiRadius.control),
      borderSide: BorderSide(color: skin.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UiRadius.control),
      borderSide: BorderSide(color: skin.divider),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(UiRadius.control)),
      borderSide: BorderSide(color: Palette.accent, width: UiSpace.s1_5),
    ),
  );
}

class ModernDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final bool allowClose;

  const ModernDialog({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    required this.content,
    this.actions,
    this.maxWidth = DesktopUx.dialogWidth,
    this.allowClose = true,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Dialog(
      insetAnimationDuration: Motion.of(context, Motion.micro),
      insetAnimationCurve: Motion.curve,
      backgroundColor: Palette.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s20,
        vertical: UiSpace.s24,
      ),
      child: MenuCard.surface(
        constraints: BoxConstraints(maxWidth: maxWidth),
        color: skin.surface,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.s20,
                UiSpace.s18,
                UiSpace.s14,
                UiSpace.s8,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: UiSpace.s16,
                    color: iconColor ?? skin.muted,
                  ),
                  const SizedBox(width: UiSpace.s8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.title,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: UiSpace.s8),
                  CloseCross(
                    onTap: allowClose ? () => Navigator.of(context).pop() : null,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  UiSpace.s20,
                  UiSpace.s8,
                  UiSpace.s20,
                  UiSpace.s18,
                ),
                child: content,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: skin.surfaceSubtle,
                  border: Border(top: BorderSide(color: skin.divider)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s16,
                  vertical: UiSpace.s12,
                ),
                child:
                    actions!.any(
                      (action) => action is Spacer || action is Flexible,
                    )
                    ? Row(children: actions!)
                    : Wrap(
                        alignment: WrapAlignment.end,
                        spacing: UiSpace.s6,
                        runSpacing: UiSpace.s6,
                        children: actions!,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

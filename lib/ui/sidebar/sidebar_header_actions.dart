import '../common/app_icons.dart';

import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../main.dart' show ThemeScope;
import '../theme.dart';

class SidebarSearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const SidebarSearchButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SizedBox(
      height: DesktopUx.sidebarSearchHeight,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: skin.hover,
          foregroundColor: skin.text,
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.s12),
          shape: StadiumBorder(side: BorderSide(color: skin.hairlineBorder)),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.search,
              size: DesktopUx.sidebarIconSize,
              color: skin.muted,
            ),
            const SizedBox(width: DesktopUx.sidebarIconGap),
            Expanded(
              child: Text(
                context.l10n.search,
                style: TextStyle(fontSize: UiType.title, color: skin.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const HeaderIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<HeaderIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: UiSpace.s26,
            height: UiSpace.s26,
            decoration: BoxDecoration(
              color: _hover ? skin.hover : Palette.transparent,
              borderRadius: BorderRadius.circular(UiRadius.small),
            ),
            child: Icon(widget.icon, size: UiSpace.s16, color: skin.muted),
          ),
        ),
      ),
    );
  }
}

class LanguageToggleButton extends StatefulWidget {
  const LanguageToggleButton({super.key});

  @override
  State<LanguageToggleButton> createState() => _LanguageToggleButtonState();
}

class _LanguageToggleButtonState extends State<LanguageToggleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final controller = LocaleScope.of(context);
    final currentCode = controller.locale?.languageCode;

    final String label = switch (currentCode) {
      'en' => 'EN',
      'ru' => 'RU',
      _ => 'AUTO',
    };

    final String langName = switch (currentCode) {
      'en' => context.l10n.languageEn,
      'ru' => context.l10n.languageRu,
      _ => context.l10n.languageSystem,
    };

    return Tooltip(
      message:
          '${context.l10n.language}: $langName (${context.l10n.themeCycleTooltip})',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.cycleNext,
          child: Container(
            height: UiSpace.s30,
            constraints: const BoxConstraints(minWidth: UiSpace.s30),
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s4),
            decoration: BoxDecoration(
              color: _hover ? skin.hover : Palette.transparent,
              borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: UiType.caption,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: skin.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key});

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final controller = ThemeScope.of(context);
    final mode = controller.mode;

    final IconData icon = switch (mode) {
      ThemeMode.system => AppIcons.circleLefthalfFill,
      ThemeMode.light => AppIcons.sunMax,
      ThemeMode.dark => AppIcons.moon,
    };

    final String tooltip = switch (mode) {
      ThemeMode.system => context.l10n.themeSystem,
      ThemeMode.light => context.l10n.themeLight,
      ThemeMode.dark => context.l10n.themeDark,
    };

    return Tooltip(
      message: '$tooltip (${context.l10n.themeCycleTooltip})',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.cycleNext,
          child: Container(
            width: UiSpace.s30,
            height: UiSpace.s30,
            decoration: BoxDecoration(
              color: _hover ? skin.hover : Palette.transparent,
              borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
            ),
            child: Icon(icon, size: UiSpace.s16, color: skin.muted),
          ),
        ),
      ),
    );
  }
}

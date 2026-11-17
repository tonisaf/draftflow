import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

export 'design_tokens.dart';
import 'design_tokens.dart';

abstract final class Palette {
  static const accent = Color(0xFF1A73E8);
  static const onAccent = Colors.white;
  static const transparent = Colors.transparent;
  static const success = Color(0xFF34C759);
  static const coverOverlay = Color(0xA6000000);
  static const coverShadow = Color(0x33000000);
  static const coverIconShadow = Color(0x1F000000);
  static const coverHover = Colors.white24;
  static const coverOutline = Colors.white70;
  static const coverIdleOutline = Colors.black12;
  static const coverSwatchShadow = Colors.black26;
  static const tagOutline = Color(0x4D000000);
  static int get defaultTagArgb => accent.toARGB32();
  static Color stored(int argb) => Color(argb);
  static const scrim = Color(0x4D000000);
}

@immutable
class Skin extends ThemeExtension<Skin> {
  const Skin({
    required this.text,
    required this.muted,
    required this.faint,
    required this.hint,
    required this.outline,
    required this.divider,
    required this.hairlineBorder,
    required this.sidebar,
    required this.sidebarSelected,
    required this.surface,
    required this.surfaceSubtle,
    required this.card,
    required this.glassSurface,
    required this.glassStrong,
    required this.rowSelected,
    required this.dropTarget,
    required this.shadow,
    required this.cardShadows,
    required this.popoverShadows,
    required this.modalShadows,
    required this.hover,
    required this.destructive,
    required this.warningBg,
    required this.warningText,
    required this.dangerBg,
    required this.dangerText,
    required this.successBg,
    required this.successText,
    required this.scrim,
    required this.accentText,
    required this.toast,
    required this.toastText,
  });

  factory Skin.of(Brightness brightness, {bool mica = false}) {
    final transparentSidebar =
        mica || defaultTargetPlatform == TargetPlatform.macOS;
    return switch ((brightness, transparentSidebar)) {
      (Brightness.light, false) => _light,
      (Brightness.light, true) => _light.copyWith(
        sidebar: const Color(0x00FFFFFF),
        sidebarSelected: const Color(0x1F000000),
      ),
      (Brightness.dark, false) => _dark,
      (Brightness.dark, true) => _dark.copyWith(
        sidebar: const Color(0x00000000),
        sidebarSelected: const Color(0x26FFFFFF),
      ),
    };
  }

  static const _light = Skin(
    text: Color(0xFF1D1F23),
    muted: Color(0xFF6B717B),
    faint: Color(0xFFC4C8CE),
    hint: Color(0xFF6F747C),
    outline: Color(0xFF8A9099),
    divider: Color(0xFFE7E9EC),
    hairlineBorder: Color(0x0D000000),
    sidebar: Color(0xFFF3F4F6),
    sidebarSelected: Color(0xFFE1E4E9),
    surface: Colors.white,
    surfaceSubtle: Color(0xFFF7F8FA),
    card: Colors.white,
    glassSurface: Color(0xD9FFFFFF),
    glassStrong: Color(0xEBFFFFFF),
    rowSelected: Color(0xFFDCE7FB),
    dropTarget: Color(0xFFCFE0FB),
    shadow: Color(0x14000000),
    cardShadows: [
      BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3)),
      BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    popoverShadows: [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 24,
        spreadRadius: -2,
        offset: Offset(0, 8),
      ),
      BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 1,
        offset: Offset(0, 0.5),
      ),
    ],
    modalShadows: [
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 48,
        spreadRadius: -4,
        offset: Offset(0, 18),
      ),
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 16,
        spreadRadius: -2,
        offset: Offset(0, 6),
      ),
      BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    hover: Color(0x0A000000),
    destructive: Color(0xFFC62828),
    warningBg: Color(0x1AF59E0B),
    warningText: Color(0xFFB45309),
    dangerBg: Color(0x17DC2626),
    dangerText: Color(0xFFB91C1C),
    successBg: Color(0x1710B981),
    successText: Color(0xFF047857),
    scrim: Color(0x24000000),
    accentText: Palette.accent,
    toast: Color(0xFF1E1E1E),
    toastText: Colors.white,
  );

  static const _dark = Skin(
    text: Color(0xFFE8EAED),
    muted: Color(0xFF9AA0A6),
    faint: Color(0xFF5F6368),
    hint: Color(0xFF90969C),
    outline: Color(0xFF80868D),
    divider: Color(0xFF34373C),
    hairlineBorder: Color(0x1AFFFFFF),
    sidebar: Color(0xFF26282C),
    sidebarSelected: Color(0xFF383B41),
    surface: Color(0xFF1F2023),
    surfaceSubtle: Color(0xFF25272B),
    card: Color(0xFF2B2D31),
    glassSurface: Color(0xD626282C),
    glassStrong: Color(0xEA2B2D31),
    rowSelected: Color(0xFF223A63),
    dropTarget: Color(0xFF2A4A7C),
    shadow: Color(0x66000000),
    cardShadows: [
      BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x28000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    popoverShadows: [
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 28,
        spreadRadius: -2,
        offset: Offset(0, 10),
      ),
      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    modalShadows: [
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 56,
        spreadRadius: -4,
        offset: Offset(0, 20),
      ),
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 18,
        spreadRadius: -2,
        offset: Offset(0, 6),
      ),
    ],
    hover: Color(0x14FFFFFF),
    destructive: Color(0xFFFF8A8A),
    warningBg: Color(0x24FBBF24),
    warningText: Color(0xFFFCD34D),
    dangerBg: Color(0x24EF4444),
    dangerText: Color(0xFFFCA5A5),
    successBg: Color(0x2434D399),
    successText: Color(0xFF6EE7B7),
    scrim: Color(0x38000000),
    accentText: Color(0xFF8AB4F8),
    toast: Color(0xFF3A3C41),
    toastText: Color(0xFFE8EAED),
  );

  final Color text;
  final Color muted;
  final Color faint;
  final Color hint;
  final Color outline;
  final Color divider;
  final Color hairlineBorder;
  final Color sidebar;
  final Color sidebarSelected;
  final Color surface;
  final Color surfaceSubtle;
  final Color card;
  final Color glassSurface;
  final Color glassStrong;

  // Backwards-compatible aliases:
  Color get frostedSurface => glassStrong;
  Color get frostedPopover => glassSurface;
  final Color rowSelected;
  final Color dropTarget;
  final Color shadow;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> popoverShadows;
  final List<BoxShadow> modalShadows;
  final Color hover;
  final Color destructive;
  final Color warningBg;
  final Color warningText;
  final Color dangerBg;
  final Color dangerText;
  final Color successBg;
  final Color successText;
  final Color scrim;
  final Color accentText;
  final Color toast;
  final Color toastText;

  bool get isDark => text.computeLuminance() > 0.5;
  Color get controlHover =>
      isDark ? const Color(0x28FFFFFF) : const Color(0x18000000);
  Color get controlBorder => outline;
  Color get tableDivider => divider.withValues(alpha: 0.85);
  Color get tableControlActive => accentText.withValues(alpha: 0.10);
  Color get tablePrimaryTint => Palette.accent.withValues(alpha: 0.12);
  // Content surfaces must stay opaque even when Mica clears the sidebar.
  Color get codeSurface => isDark ? _dark.sidebar : _light.sidebar;
  Color get codeBorder => divider;
  Color get codeText => text;
  Color get codeBadge => hover;
  Color get toolbar => text;
  Color get onToolbar => surface;
  Color get inlineCode =>
      isDark ? const Color(0xFF93B4E2) : const Color(0xFF344E6E);
  Color get inlineCodeSurface => codeSurface;
  Color get surfaceVariant => hover;
  Color get editorOutline => Color.lerp(divider, outline, 0.3)!;
  Color get popoverShadow => shadow.withValues(alpha: 0.08);

  @override
  Skin copyWith({
    Color? sidebar,
    Color? sidebarSelected,
    Color? surface,
    Color? surfaceSubtle,
    Color? glassSurface,
    Color? glassStrong,
    Color? hover,
    Color? destructive,
    Color? toast,
    Color? toastText,
  }) => Skin(
    text: text,
    muted: muted,
    faint: faint,
    hint: hint,
    outline: outline,
    divider: divider,
    hairlineBorder: hairlineBorder,
    sidebar: sidebar ?? this.sidebar,
    sidebarSelected: sidebarSelected ?? this.sidebarSelected,
    surface: surface ?? this.surface,
    surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    card: card,
    glassSurface: glassSurface ?? this.glassSurface,
    glassStrong: glassStrong ?? this.glassStrong,
    rowSelected: rowSelected,
    dropTarget: dropTarget,
    shadow: shadow,
    cardShadows: cardShadows,
    popoverShadows: popoverShadows,
    modalShadows: modalShadows,
    hover: hover ?? this.hover,
    destructive: destructive ?? this.destructive,
    warningBg: warningBg,
    warningText: warningText,
    dangerBg: dangerBg,
    dangerText: dangerText,
    successBg: successBg,
    successText: successText,
    scrim: scrim,
    accentText: accentText,
    toast: toast ?? this.toast,
    toastText: toastText ?? this.toastText,
  );

  @override
  Skin lerp(Skin? other, double t) => t < 0.5 ? this : other ?? this;
}

extension SkinOf on BuildContext {
  Skin get skin =>
      Theme.of(this).extension<Skin>() ?? Skin.of(Theme.of(this).brightness);
}

abstract final class Motion {
  static const micro = Duration(milliseconds: 80);
  static const strike = Duration(milliseconds: 170);
  static const press = Duration(milliseconds: 80);
  static const popover = Duration(milliseconds: 220);
  static const panel = Duration(milliseconds: 260);
  static const foldSize = Duration(milliseconds: 160);
  static const foldContent = Duration(milliseconds: 100);

  static const wheel = Duration(milliseconds: 140);
  // Interaction delays and feedback lifetimes are never reduced to zero.
  static const linkSearchDebounce = Duration(milliseconds: 100);
  static const quickSearchDebounce = Duration(milliseconds: 120);
  static const dragExpandDelay = Duration(milliseconds: 650);
  static const copiedFeedback = Duration(milliseconds: 1500);
  static const exportCopiedFeedback = Duration(seconds: 2);
  static const tooltipDelay = Duration(milliseconds: 400);
  static const doubleTapWindow = Duration(milliseconds: 300);
  static const notice = Duration(seconds: 2);
  static const savedNotice = Duration(seconds: 3);
  static const curve = Curves.easeOutCubic;
  static const sectionRise = 8.0;

  static final spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 1,
  );

  static const spatialSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 25,
  );

  static const panelCurve = Curves.easeOutCubic;

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

  static AnimationStyle dialogStyle(BuildContext context) => AnimationStyle(
    duration: of(context, popover),
    reverseDuration: of(context, popover),
    curve: curve,
    reverseCurve: curve,
  );
}

abstract final class DesktopUx {
  static const sidebarRowHeight = 34.0;
  static const sidebarSearchHeight = 32.0;
  static const sidebarIconSize = UiSpace.s16;
  static const sidebarIconGap = 10.0;
  static const rowModalBreakpoint = 700.0;
  static const rowPeekCompactHeaderWidth = 500.0;
  static const rowModalWidth = 820.0;
  static const rowModalMinHeight = 500.0;
  static const rowModalMaxHeight = 900.0;
  static const menuRowHeight = 34.0;
  static const menuWidth = 200.0;
  static const popoverWidth = 280.0;
  static const dialogWidth = 420.0;
  static const treeIndent = 14.0;
  static const searchRowHeight = 44.0;
  static const linkRowHeight = 40.0;
  static const databaseRowHeight = 36.0;
  static const databaseSummaryHeight = 30.0;
  static const databaseVisibleRows = 8;
  static const databaseLoadingHeight =
      databaseVisibleRows * databaseRowHeight + 120.0;
  static const databaseMaxVisibleHeight = 480.0;
  static const databaseToolbarExtent = 28.0;
  static const databaseHeaderHeight = 34.0;
  static const databaseTitleSize = UiType.heading;
  static const databaseNarrowToolbar = 480.0;
  static const databaseGutterWidth = 28.0;
  static const databaseActionWidth = 36.0;
  static const conflictDialogWidth = 820.0;
  static const conflictPreviewHeight = 240.0;
  static const conflictStackWidth = 600.0;
  static const menuRadius = UiRadius.control;
  static const menuTextSize = UiType.body;
  static const menuHorizontalPadding = 12.0;
  static const menuMinWidth = 180.0;
  static const menuMaxWidth = 220.0;
  static const menuIconSize = UiSpace.s16;
  static const radius = 6.0;
  static const spacing = 6.0;
  static const inset = 4.0;
  static const captionSize = 12.0;
}

ThemeData buildTheme(Brightness brightness, {bool mica = false}) {
  final skin = Skin.of(brightness, mica: mica);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.accent,
      brightness: brightness,
      surface: skin.card,
    ),
    scaffoldBackgroundColor: mica ? Palette.transparent : skin.surface,
    canvasColor: skin.card,
    shadowColor: skin.shadow,
    splashFactory: NoSplash.splashFactory,
    splashColor: Palette.transparent,
    highlightColor: Palette.transparent,
    hoverColor: Palette.transparent,
    visualDensity: VisualDensity.compact,
    extensions: [skin],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: skin.text,
      displayColor: skin.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Palette.accent,
      selectionColor: Palette.accent.withValues(alpha: 0.25),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: skin.hint),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Palette.onAccent;
        }
        return skin.isDark ? const Color(0xFFC4C8CE) : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Palette.accent;
        }
        return skin.isDark ? const Color(0xFF383B41) : const Color(0xFFE1E4E9);
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(
        UiSpace.s16,
        UiSpace.s5,
        UiSpace.s16,
        UiSpace.s24,
      ),
      backgroundColor: skin.toast,
      elevation: UiSpace.s8,
      actionTextColor: const Color(0xFF8AB4F8),
      contentTextStyle: TextStyle(fontSize: UiType.title, color: skin.toastText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.notice),
        side: BorderSide(color: skin.hairlineBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.accent,
        foregroundColor: Palette.onAccent,
        disabledBackgroundColor: Palette.accent.withValues(alpha: 0.35),
        disabledForegroundColor: Palette.onAccent.withValues(alpha: 0.7),
        minimumSize: const Size(0, UiSpace.s34),
        padding: const EdgeInsets.symmetric(horizontal: UiSpace.s18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiRadius.control),
        ),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged)) {
          return true;
        }
        return false;
      }),
      thickness: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged)) {
          return 9.0;
        }
        return 5.0;
      }),
      radius: const Radius.circular(10.0),
      crossAxisMargin: 2.5,
      mainAxisMargin: 4.0,
      minThumbLength: 36.0,
      interactive: true,
      trackVisibility: const WidgetStatePropertyAll(false),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        final isDark = skin.isDark;
        if (states.contains(WidgetState.dragged)) {
          return isDark
              ? Colors.white.withValues(alpha: 0.65)
              : Colors.black.withValues(alpha: 0.58);
        }
        if (states.contains(WidgetState.hovered)) {
          return isDark
              ? Colors.white.withValues(alpha: 0.48)
              : Colors.black.withValues(alpha: 0.42);
        }
        return isDark
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.24);
      }),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: skin.card,
      shadowColor: skin.shadow,
      elevation: UiSpace.s8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopUx.menuRadius),
        side: BorderSide(color: skin.divider),
      ),
      textStyle: TextStyle(fontSize: DesktopUx.menuTextSize, color: skin.text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: skin.card,
      shadowColor: skin.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopUx.menuRadius),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: ShapeDecoration(
        color: skin.isDark ? const Color(0xFF1E2024) : const Color(0xFF2C2E33),
        shape: UiRadius.squircle(UiRadius.badge),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      waitDuration: Motion.tooltipDelay,
    ),
  );
}

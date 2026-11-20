import 'package:flutter/material.dart';

/// Shared logical-pixel scale. sN denotes N logical pixels, not a role.
/// Use DesktopUx for interaction-specific dimensions; ratios stay at call sites.
abstract final class UiSpace {
  static const s0_6 = 0.6;
  static const s0_8 = 0.8;
  static const s1 = 1.0;
  static const s1_3 = 1.3;
  static const s1_5 = 1.5;
  static const s2 = 2.0;
  static const s2_5 = 2.5;
  static const s3 = 3.0;
  static const s3_5 = 3.5;
  static const s4 = 4.0;
  static const s5 = 5.0;
  static const s6 = 6.0;
  static const s7 = 7.0;
  static const s8 = 8.0;
  static const s9 = 9.0;
  static const s10 = 10.0;
  static const s11 = 11.0;
  static const s11_5 = 11.5;
  static const s12 = 12.0;
  static const s13 = 13.0;
  static const s13_5 = 13.5;
  static const s14 = 14.0;
  static const s15 = 15.0;
  static const s16 = 16.0;
  static const s17 = 17.0;
  static const s18 = 18.0;
  static const s20 = 20.0;
  static const s22 = 22.0;
  static const s24 = 24.0;
  static const s26 = 26.0;
  static const s28 = 28.0;
  static const s30 = 30.0;
  static const s32 = 32.0;
  static const s33 = 33.0;
  static const s34 = 34.0;
  static const s36 = 36.0;
  static const s38 = 38.0;
  static const s40 = 40.0;
  static const s44 = 44.0;
  static const s52 = 52.0;
  static const s60 = 60.0;
  static const s64 = 64.0;
}

abstract final class UiType {
  static const micro = 10.0;
  static const small = 11.0;
  static const caption = 12.0;
  static const body = 13.0;
  static const title = 14.0;
  static const listItem = 15.0;
  static const sectionTitle = 26.0;
  static const editorBody = 14.0;
  static const code = 12.0;
  static const editorLineHeight = 1.48;
  static const codeLineHeight = 1.4;
  static const editorTitle = 16.0;
  static const heading = 20.0;
  static const hero = 22.0;
  static const emptyIcon = 32.0;
  static const pageTitle = 34.0;
  static const peekTitle = 28.0;
  static const pageIcon = 46.0;

  /// Monospaced tabular digits font feature to prevent horizontal layout shift
  /// when numbers, prices, counters, or dates update.
  static const tabular = [FontFeature.tabularFigures()];
}

abstract final class UiRadius {
  // Concentric squircle radius scale across elevation levels:
  /// Outer modal dialogs and windows (Внешний контейнер / модалка): 20px
  static const modal = 20.0;
  static const sheet = 20.0;

  /// Floating popovers and panels (Внутренняя панель / попап): 14–16px
  static const popover = 16.0;
  static const panel = 14.0;
  static const notice = 14.0;

  /// Content cards, callouts, and page links (Карточка / плашка): 12px
  static const card = 12.0;
  static const dialog = 12.0;

  /// Interactive controls, buttons, input fields (Кнопка / инпут / селектор): 8px
  static const control = 8.0;

  /// Inner nested elements, chips, tags (Вложенный элемент / бейдж): 6px
  static const inner = 6.0;
  static const small = 6.0;

  /// Pill badge / counter radius: 10px
  static const badge = 10.0;

  /// Sidebar items: 6px (Antigravity / modern desktop standard)
  static const sidebarRow = 6.0;

  /// Micro actions and compact affordances: 4px
  static const action = 4.0;
  static const compact = 4.0;

  /// Hairline borders, scrollbars, handles
  static const scrollbar = 3.0;
  static const handle = 1.25;
  static const hairline = 1.0;

  /// Fully rounded pill
  static const pill = 999.0;

  /// Continuous-curvature squircle shape (Neo-HIG / macOS aesthetic).
  static ContinuousRectangleBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: side,
  );
}

/// Language highlighting is content, shared by every code renderer.
class SyntaxColors {
  const SyntaxColors({required this.dark});
  final bool dark;
  Color get text => dark ? const Color(0xFFABB2BF) : const Color(0xFF24292F);
  Color get keyword => dark ? const Color(0xFFC678DD) : const Color(0xFFCF222E);
  Color get string => dark ? const Color(0xFF98C379) : const Color(0xFF22863A);
  Color get comment => dark ? const Color(0xFF5C6370) : const Color(0xFF6E7781);
  Color get number => dark ? const Color(0xFFD19A66) : const Color(0xFF0550AE);
  Color get type => dark ? const Color(0xFFE5C07B) : const Color(0xFF953800);
  Color get annotation =>
      dark ? const Color(0xFF61AFEF) : const Color(0xFF8250DF);
}

const List<Map<String, dynamic>> tagColorPresets = [
  {'name': 'Blue', 'color': 0xFF3B82F6},
  {'name': 'Green', 'color': 0xFF10B981},
  {'name': 'Orange', 'color': 0xFFF59E0B},
  {'name': 'Red', 'color': 0xFFEF4444},
  {'name': 'Purple', 'color': 0xFF8B5CF6},
  {'name': 'Pink', 'color': 0xFFEC4899},
  {'name': 'Teal', 'color': 0xFF14B8A6},
  {'name': 'Gray', 'color': 0xFF6B7280},
];

/// Feature extents stay independent from the shared spacing scale.
abstract final class UiLayout {
  static const subpageCardsBreakpoint = 520.0;
  static const subpageCardHeight = 76.0;
  static const coverPickerWidth = 440.0;
  static const coverPickerHeight = 400.0;
  static const emojiPickerWidth = 380.0;
  static const emojiPickerHeight = 440.0;
  static const exportMenuWidth = 200.0;
  static const transferDialogWidth = 720.0;
  static const transferDialogMaxHeight = 600.0;
  static const textSelectionMenuWidth = 170.0;
  static const linkPickerWidth = 460.0;
  static const linkPickerMaxHeight = 380.0;
  static const linkNoticeWidth = 320.0;
  static const searchWidth = 580.0;
  static const searchMaxHeight = 460.0;
  static const editorMaxWidth = 820.0;
  static const editorWideMaxWidth = 1200.0;
  static const pageMenuWidth = 280.0;
  static const trashNoticeWidth = 400.0;
  static const trashContentWidth = 720.0;
  static const trashEmptyStateWidth = 320.0;
  static const codeCollapsedHeight = 130.0;
  static const tableMinWidth = 400.0;
  static const editorContextMenuWidth = 175.0;
  static const coverHeight = 148.0;
  static const pageToolbarHeight = 48.0;
  static const pageActionsMenuWidth = 320.0;
  static const cellMenuWidth = 190.0;
  static const cellEditorMinWidth = 240.0;
  static const cellUrlEditorMinWidth = 480.0;
  static const cellEditorMaxHeight = 420.0;
  static const columnDialogWidth = 360.0;
  static const columnDeleteDialogWidth = 340.0;
  static const columnMenuWidth = 175.0;
  static const columnPropertiesWidth = 440.0;
  static const tagDialogWidth = 400.0;
  static const databaseMenuWidth = 195.0;
  static const databaseControlMinWidth = 100.0;
  static const databaseFilterWidth = 140.0;
  static const fallbackColumnWidth = 100.0;
  static const rowPropertyLabelWidth = 144.0;
  static const rowPeekIconOnlyWidth = 350.0;
  static const rowPropertyValueWidth = 220.0;
}

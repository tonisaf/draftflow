import 'package:flutter/material.dart';

import '../theme.dart';

class QuickNoteColors {
  static const defaultColor = 'default';
  static const coral = 'coral';
  static const peach = 'peach';
  static const sand = 'sand';
  static const mint = 'mint';
  static const fog = 'fog';
  static const blossom = 'blossom';

  static const List<String> all = [
    defaultColor,
    coral,
    peach,
    sand,
    mint,
    fog,
    blossom,
  ];

  static Color getBackground(String? colorName, Skin skin) {
    if (colorName == null || colorName == defaultColor) {
      return skin.card;
    }
    if (skin.isDark) {
      return switch (colorName) {
        coral => const Color(0xFF3B2020),
        peach => const Color(0xFF3C2817),
        sand => const Color(0xFF38321B),
        mint => const Color(0xFF1B362A),
        fog => const Color(0xFF1B2C46),
        blossom => const Color(0xFF381D32),
        _ => skin.card,
      };
    } else {
      return switch (colorName) {
        coral => const Color(0xFFFAECEB),
        peach => const Color(0xFFFEF0E1),
        sand => const Color(0xFFFEF8D8),
        mint => const Color(0xFFE6F4EA),
        fog => const Color(0xFFE8F0FE),
        blossom => const Color(0xFFFCE8E6),
        _ => skin.card,
      };
    }
  }

  static Color getSwatch(String colorName) {
    return switch (colorName) {
      coral => const Color(0xFFF28B82),
      peach => const Color(0xFFFBBC04),
      sand => const Color(0xFFFFF475),
      mint => const Color(0xFFCCFF90),
      fog => const Color(0xFFAECBFA),
      blossom => const Color(0xFFFDCFE8),
      _ => Colors.white,
    };
  }
}

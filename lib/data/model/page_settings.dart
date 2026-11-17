import 'dart:convert';

enum SubpageLayout { list, cards }

/// Normal page metadata shares the existing synced properties envelope. The
/// namespace is separate from database column IDs; no schema migration is needed.
const pageSettingsKey = '_notes_here_page';

class PageSettings {
  final SubpageLayout subpageLayout;
  final bool fullWidth;
  final bool smallText;
  final bool coverToTop;
  final double coverY;
  final bool isPinned;
  final String? cardColor;
  final bool isQuickNote;
  final String? tag;

  const PageSettings({
    this.subpageLayout = SubpageLayout.list,
    this.fullWidth = false,
    this.smallText = false,
    this.coverToTop = false,
    this.coverY = 0.5,
    this.isPinned = false,
    this.cardColor,
    this.isQuickNote = false,
    this.tag,
  });

  PageSettings copyWith({
    SubpageLayout? subpageLayout,
    bool? fullWidth,
    bool? smallText,
    bool? coverToTop,
    double? coverY,
    bool? isPinned,
    String? cardColor,
    bool? isQuickNote,
    String? tag,
  }) => PageSettings(
    subpageLayout: subpageLayout ?? this.subpageLayout,
    fullWidth: fullWidth ?? this.fullWidth,
    smallText: smallText ?? this.smallText,
    coverToTop: coverToTop ?? this.coverToTop,
    coverY: coverY ?? this.coverY,
    isPinned: isPinned ?? this.isPinned,
    cardColor: cardColor ?? this.cardColor,
    isQuickNote: isQuickNote ?? this.isQuickNote,
    tag: tag ?? this.tag,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageSettings &&
          runtimeType == other.runtimeType &&
          subpageLayout == other.subpageLayout &&
          fullWidth == other.fullWidth &&
          smallText == other.smallText &&
          coverToTop == other.coverToTop &&
          coverY == other.coverY &&
          isPinned == other.isPinned &&
          cardColor == other.cardColor &&
          isQuickNote == other.isQuickNote &&
          tag == other.tag;

  @override
  int get hashCode =>
      Object.hash(subpageLayout, fullWidth, smallText, coverToTop, coverY, isPinned, cardColor, isQuickNote, tag);
}

PageSettings pageSettingsFromProperties(String? properties) {
  try {
    final data = jsonDecode(properties ?? '{}');
    if (data is Map && data[pageSettingsKey] is Map) {
      final map = data[pageSettingsKey] as Map;
      return PageSettings(
        subpageLayout: map['subpageLayout'] == 'cards'
            ? SubpageLayout.cards
            : SubpageLayout.list,
        fullWidth: map['fullWidth'] == true,
        smallText: map['smallText'] == true,
        coverToTop: map['coverToTop'] == true,
        coverY: (map['coverY'] is num) ? (map['coverY'] as num).toDouble() : 0.5,
        isPinned: map['isPinned'] == true,
        cardColor: map['cardColor'] as String?,
        isQuickNote: map['isQuickNote'] == true,
        tag: map['tag'] as String?,
      );
    }
    return const PageSettings();
  } on FormatException {
    return const PageSettings();
  }
}

SubpageLayout subpageLayoutFromProperties(String? properties) =>
    pageSettingsFromProperties(properties).subpageLayout;

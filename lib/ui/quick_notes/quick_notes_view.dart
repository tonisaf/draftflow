import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Page;

import '../../data/db/app_database.dart';
import '../../data/model/page_settings.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../common/app_icons.dart';
import '../common/section_transition.dart';
import '../theme.dart';
import 'quick_note_card.dart';
import 'quick_note_colors.dart';
import 'quick_note_modal_dialog.dart';
import 'quick_note_models.dart';

enum QuickNoteFilter { all, pinned, code, checklists }

class QuickNotesView extends StatefulWidget {
  final NotesRepository repository;
  final ValueChanged<String> onNavigateToPage;

  const QuickNotesView({
    super.key,
    required this.repository,
    required this.onNavigateToPage,
  });

  @override
  State<QuickNotesView> createState() => _QuickNotesViewState();
}

class _QuickNotesViewState extends State<QuickNotesView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  QuickNoteFilter _activeFilter = QuickNoteFilter.all;
  String _searchQuery = '';
  String? _selectedTag;
  String? _selectedFilterTag;
  String? _selectedColor;
  bool _createAsPinned = false;
  bool _createAsCode = false;

  bool _isPinnedExpanded = true;
  bool _isOtherExpanded = true;

  static final Map<String, List<Block>> _blocksCache = {};
  static List<QuickNoteCardData>? _globalCardsCache;

  List<QuickNoteCardData>? _loadedCards;
  StreamSubscription<List<Page>>? _subscription;
  int _loadGeneration = 0;
  String? _newNoteColor;

  @override
  void initState() {
    super.initState();
    _loadedCards = _globalCardsCache;
    _inputController.addListener(_handleInputChange);
    _inputFocusNode.addListener(_handleFocusChange);
    _subscribeToPages();
  }

  void _handleInputChange() {
    if (mounted) setState(() {});
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(QuickNotesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _subscribeToPages();
    }
  }

  void _subscribeToPages() {
    _subscription?.cancel();
    _subscription = widget.repository.watchActivePages().listen((pages) {
      final quickNotePages = pages
          .where((p) => pageSettingsFromProperties(p.properties).isQuickNote)
          .toList();
      _reloadCards(quickNotePages);
    });
  }

  Future<void> _reloadCards(List<Page> pages) async {
    final generation = ++_loadGeneration;
    final list = <QuickNoteCardData>[];

    for (final page in pages) {
      if (page.trashedAt != null || page.databaseId != null) continue;

      List<Block>? blocks = _blocksCache[page.id];
      if (blocks == null) {
        try {
          final snapshot = await widget.repository.db.getPageBlocksSnapshot(page.id);
          blocks = snapshot.blocks;
          _blocksCache[page.id] = blocks;
        } catch (_) {
          blocks = const [];
        }
      }

      list.add(QuickNoteCardData.fromPageAndBlocks(page, blocks));
    }

    if (!mounted || generation != _loadGeneration) return;
    _globalCardsCache = list;
    setState(() {
      _loadedCards = list;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _inputController.removeListener(_handleInputChange);
    _inputFocusNode.removeListener(_handleFocusChange);
    _searchController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSaveQuickNote() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final String title;
    final String? body;

    if (_createAsCode) {
      if (lines.length > 1) {
        title = lines.first.trim();
        body = lines.sublist(1).join('\n').trim();
      } else {
        // Для однострочного кода заголовок оставляем пустым, чтобы не дублировать команду
        title = '';
        body = text;
      }
    } else {
      title = lines.first.trim();
      body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : null;
    }

    try {
      await widget.repository.createQuickNote(
        title: title,
        body: body,
        isCode: _createAsCode,
        isPinned: _createAsPinned,
        tag: _selectedTag ?? (_createAsCode ? 'Код' : null),
        cardColor: _newNoteColor,
      );

      if (mounted) {
        setState(() {
          _inputController.clear();
          _selectedTag = null;
          _newNoteColor = null;
          _createAsPinned = false;
          _createAsCode = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.failedToCreatePage)),
        );
      }
    }
  }

  void _handleOpenQuickNoteModal(QuickNoteCardData item, [BuildContext? cardContext]) {
    Rect? originRect;
    if (cardContext != null) {
      final box = cardContext.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        originRect = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    QuickNoteModalDialog.show(
      context,
      cardData: item,
      repository: widget.repository,
      originRect: originRect,
      onSaved: () {
        _blocksCache.remove(item.page.id);
        setState(() {});
      },
    );
  }

  Widget _buildMasonryGrid(List<QuickNoteCardData> cardsList, double maxWidth) {
    if (cardsList.isEmpty) return const SizedBox.shrink();

    final colCount = (maxWidth / 320).floor().clamp(1, 4);
    final columns = List.generate(colCount, (_) => <QuickNoteCardData>[]);

    for (int i = 0; i < cardsList.length; i++) {
      columns[i % colCount].add(cardsList[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int c = 0; c < colCount; c++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in columns[c])
                  SectionItem(
                    key: ValueKey(('section-item', item.page.id)),
                    index: cardsList.indexOf(item),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: UiSpace.s14),
                      child: Builder(
                        builder: (cardContext) => QuickNoteCard(
                          key: ValueKey(item.page.id),
                          cardData: item,
                          onOpenPage: (_) => _handleOpenQuickNoteModal(item, cardContext),
                          onTogglePin: () => widget.repository.togglePagePinned(item.page.id),
                          onTrashPage: (id) => widget.repository.trashPage(id),
                          onTagTap: (tag) {
                            setState(() {
                              _selectedFilterTag = _selectedFilterTag == tag ? null : tag;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (c < colCount - 1) const SizedBox(width: UiSpace.s14),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isLoading = _loadedCards == null;
    final allCards = _loadedCards ?? const <QuickNoteCardData>[];

    // Извлечение всех уникальных тегов карточек
    final allTags = <String>{};
    for (final c in allCards) {
      for (final t in c.extractedTags) {
        allTags.add(t);
      }
    }
    final sortedTags = allTags.toList()..sort();

            // Фильтрация карточек
            final filteredCards = allCards.where((c) {
              final query = _searchQuery.toLowerCase().trim();
              final matchesQuery = query.isEmpty ||
                  c.page.title.toLowerCase().contains(query) ||
                  c.textSnippet.toLowerCase().contains(query) ||
                  c.extractedTags.any((t) => t.toLowerCase().contains(query)) ||
                  (c.codeSnippet != null && c.codeSnippet!.toLowerCase().contains(query));

              if (!matchesQuery) return false;

              if (_selectedFilterTag != null && !c.hasTag(_selectedFilterTag!)) {
                return false;
              }

              if (_selectedColor != null) {
                final cardColor = c.settings.cardColor ?? QuickNoteColors.defaultColor;
                if (cardColor != _selectedColor) {
                  return false;
                }
              }

              switch (_activeFilter) {
                case QuickNoteFilter.all:
                  return true;
                case QuickNoteFilter.pinned:
                  return c.settings.isPinned;
                case QuickNoteFilter.code:
                  return c.codeSnippet != null;
                case QuickNoteFilter.checklists:
                  return c.todoItems.isNotEmpty;
              }
            }).toList();

            final pinnedCards = filteredCards.where((c) => c.settings.isPinned).toList();
            final otherCards = filteredCards.where((c) => !c.settings.isPinned).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 700;
                final horizontalPadding = compact
                    ? UiSpace.s16
                    : math.max(
                        UiSpace.s24,
                        (constraints.maxWidth - 960.0) / 2,
                      );
                final gridWidth = constraints.maxWidth - (horizontalPadding * 2);

                return SectionContent(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: UiSpace.s24,
                    ),
                  children: [
                    // Заголовок и поиск в реальном времени
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.quickNotes,
                                style: TextStyle(
                                  fontSize: UiType.pageTitle,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: skin.text,
                                ),
                              ),
                              const SizedBox(height: UiSpace.s4),
                              Text(
                                'Быстрые заметки, списки и идеи',
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  color: skin.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: UiSpace.s16),
                        // Поле поиска со StadiumBorder
                        Container(
                          width: UiSpace.s60 * 4,
                          height: DesktopUx.sidebarSearchHeight,
                          decoration: ShapeDecoration(
                            color: skin.hover,
                            shape: StadiumBorder(side: BorderSide(color: skin.hairlineBorder)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.search,
                                size: DesktopUx.sidebarIconSize,
                                color: skin.muted,
                              ),
                              const SizedBox(width: DesktopUx.sidebarIconGap),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  selectAllOnFocus: false,
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  style: TextStyle(fontSize: UiType.title, color: skin.text),
                                  decoration: InputDecoration(
                                    hintText: '${context.l10n.search}…',
                                    hintStyle: TextStyle(fontSize: UiType.title, color: skin.muted),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Icon(AppIcons.xmark, size: UiSpace.s12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: UiSpace.s16),

                    // Фильтр-таблетки и палитра цветов на одной линии (Apple HIG / Linear)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  'Все',
                                  allCards.length,
                                  QuickNoteFilter.all,
                                ),
                                const SizedBox(width: 4),
                                _buildFilterChip(
                                  context.l10n.pinned,
                                  allCards.where((c) => c.settings.isPinned).length,
                                  QuickNoteFilter.pinned,
                                  icon: AppIcons.pin,
                                ),
                                const SizedBox(width: 4),
                                _buildFilterChip(
                                  'Код & Пресеты',
                                  allCards.where((c) => c.codeSnippet != null).length,
                                  QuickNoteFilter.code,
                                  icon: AppIcons.bolt,
                                ),
                                const SizedBox(width: 4),
                                _buildFilterChip(
                                  'Чек-листы',
                                  allCards.where((c) => c.todoItems.isNotEmpty).length,
                                  QuickNoteFilter.checklists,
                                  icon: AppIcons.checkmarkSquare,
                                ),

                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: skin.divider,
                                ),
                                const SizedBox(width: 8),

                                _buildColorFilterDots(skin),

                                if (_hasActiveFilters) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _clearAllFilters,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: skin.hover,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(AppIcons.xmark, size: 10, color: skin.muted),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Сбросить',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: skin.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Строка фильтрации по тегам
                    if (sortedTags.isNotEmpty || _selectedFilterTag != null) ...[
                      const SizedBox(height: UiSpace.s8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tag in sortedTags) ...[
                              _buildTagChip(
                                tag,
                                allCards.where((c) => c.hasTag(tag)).length,
                                _selectedFilterTag == tag,
                                skin,
                              ),
                              const SizedBox(width: UiSpace.s6),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: UiSpace.s16),

                    // Панель быстрого добавления заметки (Smart Input)
                    _buildQuickCaptureBar(skin),

                    const SizedBox(height: UiSpace.s20),

                    // Секция 1: Закрепленные
                    if (pinnedCards.isNotEmpty) ...[
                      _buildSectionHeader(
                        context.l10n.pinned,
                        pinnedCards.length,
                        _isPinnedExpanded,
                        () => setState(() => _isPinnedExpanded = !_isPinnedExpanded),
                        skin,
                      ),
                      const SizedBox(height: UiSpace.s10),
                      if (_isPinnedExpanded) _buildMasonryGrid(pinnedCards, gridWidth),
                      const SizedBox(height: UiSpace.s20),
                    ],

                    // Секция 2: Другие
                    if (otherCards.isNotEmpty) ...[
                      _buildSectionHeader(
                        context.l10n.otherNotes,
                        otherCards.length,
                        _isOtherExpanded,
                        () => setState(() => _isOtherExpanded = !_isOtherExpanded),
                        skin,
                      ),
                      const SizedBox(height: UiSpace.s10),
                      if (_isOtherExpanded) _buildMasonryGrid(otherCards, gridWidth),
                    ],

                    if (isLoading && filteredCards.isEmpty) ...[
                      const SizedBox(height: UiSpace.s60),
                      Center(
                        child: SizedBox(
                          width: UiSpace.s20,
                          height: UiSpace.s20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: skin.muted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ] else if (filteredCards.isEmpty) ...[
                      _buildEmptyState(skin),
                    ],
                  ],
                ),
              );
            },
          );
  }

  bool get _hasActiveFilters =>
      _activeFilter != QuickNoteFilter.all ||
      _selectedFilterTag != null ||
      _selectedColor != null ||
      _searchQuery.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _activeFilter = QuickNoteFilter.all;
      _selectedFilterTag = null;
      _selectedColor = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _buildTagChip(String tag, int count, bool isSelected, Skin skin) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterTag = isSelected ? null : tag;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10, vertical: UiSpace.s4),
        decoration: ShapeDecoration(
          color: isSelected ? Palette.accent.withValues(alpha: 0.16) : skin.hover,
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected ? Palette.accent : skin.hairlineBorder,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.tag,
              size: UiSpace.s11,
              color: isSelected ? skin.accentText : skin.muted,
            ),
            const SizedBox(width: UiSpace.s4),
            Text(
              tag.startsWith('#') ? tag : '#$tag',
              style: TextStyle(
                fontSize: UiType.small,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? skin.accentText : skin.text,
              ),
            ),
            const SizedBox(width: UiSpace.s4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: UiType.small - 1,
                color: isSelected ? skin.accentText.withValues(alpha: 0.8) : skin.muted,
                fontFeatures: UiType.tabular,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: UiSpace.s4),
              Icon(
                AppIcons.xmark,
                size: UiSpace.s10,
                color: skin.accentText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorFilterDots(Skin skin) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in QuickNoteColors.all) ...[
          if (color != QuickNoteColors.defaultColor) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = _selectedColor == color ? null : color;
                });
              },
              child: Tooltip(
                message: _selectedColor == color ? 'Снять фильтр цвета' : 'Фильтр по цвету: $color',
                preferBelow: false,
                verticalOffset: 14,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.only(right: 5),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: QuickNoteColors.getSwatch(color),
                    border: Border.all(
                      color: _selectedColor == color
                          ? Palette.accent
                          : skin.hairlineBorder,
                      width: _selectedColor == color ? 2.5 : 1.0,
                    ),
                    boxShadow: _selectedColor == color
                        ? [
                            BoxShadow(
                              color: Palette.accent.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: _selectedColor == color
                      ? const Center(
                          child: Icon(
                            AppIcons.checkMark,
                            size: 9,
                            color: Colors.black87,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    int count,
    QuickNoteFilter filter, {
    IconData? icon,
  }) {
    final skin = context.skin;
    final isSelected = _activeFilter == filter;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: ShapeDecoration(
            color: isSelected
                ? Palette.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected
                    ? Palette.accent.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? Palette.accent : skin.muted,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: UiType.caption,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Palette.accent : skin.muted,
                ),
              ),
              if (count > 0 || isSelected) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Palette.accent.withValues(alpha: 0.16)
                        : (skin.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFeatures: UiType.tabular,
                      color: isSelected ? Palette.accent : skin.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    bool isExpanded,
    VoidCallback onToggle,
    Skin skin,
  ) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UiSpace.s6),
        child: Row(
          children: [
            Icon(
              isExpanded ? AppIcons.chevronDown : AppIcons.chevronRight,
              size: UiSpace.s12,
              color: skin.muted,
            ),
            const SizedBox(width: UiSpace.s6),
            Text(
              title,
              style: TextStyle(
                fontSize: UiType.caption,
                fontWeight: FontWeight.w600,
                color: skin.muted,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: UiSpace.s6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s6, vertical: 1),
              decoration: ShapeDecoration(
                color: skin.hover,
                shape: const StadiumBorder(),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: UiType.small,
                  fontWeight: FontWeight.w600,
                  color: skin.muted,
                  fontFeatures: UiType.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Skin skin) {
    final isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: skin.isDark
                    ? const Color(0xFF26282C)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: skin.hairlineBorder),
              ),
              child: Center(
                child: Icon(
                  isSearching ? AppIcons.search : AppIcons.docText,
                  size: 24,
                  color: skin.muted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isSearching ? 'Ничего не найдено' : 'Здесь пока нет заметок',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: skin.text,
              ),
            ),
            const SizedBox(height: 6),
            if (isSearching)
              Text(
                'По запросу "$_searchQuery" ничего не найдено',
                style: TextStyle(
                  fontSize: 12,
                  color: skin.muted,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Введите текст выше и нажмите ',
                    style: TextStyle(
                      fontSize: 12,
                      color: skin.muted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: skin.isDark
                          ? const Color(0xFF2D3035)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: skin.hairlineBorder),
                    ),
                    child: Text(
                      '↵ Enter',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ),
                  Text(
                    ', чтобы сохранить',
                    style: TextStyle(
                      fontSize: 12,
                      color: skin.muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCaptureBar(Skin skin) {
    final hasFocus = _inputFocusNode.hasFocus;
    final hasText = _inputController.text.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 48,
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus
              ? Palette.accent.withValues(alpha: 0.45)
              : skin.hairlineBorder,
          width: hasFocus ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasFocus
                ? Palette.accent.withValues(alpha: 0.12)
                : skin.shadow.withValues(alpha: 0.04),
            blurRadius: hasFocus ? 12 : 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: skin.shadow.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Левая нейтральная иконка пера с меню опций
          PopupMenuButton<String>(
            tooltip: 'Опции заметки',
            offset: const Offset(0, 36),
            color: skin.glassSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              side: BorderSide(color: skin.divider),
            ),
            onSelected: (val) {
              setState(() {
                if (val == 'pin') {
                  _createAsPinned = !_createAsPinned;
                } else if (val == 'code') {
                  _createAsCode = !_createAsCode;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                      _createAsPinned ? AppIcons.pinFill : AppIcons.pin,
                      size: 14,
                      color: _createAsPinned ? Palette.accent : skin.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _createAsPinned ? 'Закрепить (вкл)' : 'Закрепить сразу',
                      style: TextStyle(fontSize: UiType.caption, color: skin.text),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'code',
                child: Row(
                  children: [
                    Icon(
                      AppIcons.bolt,
                      size: 14,
                      color: _createAsCode ? Palette.accent : skin.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _createAsCode ? 'Формат: Код (вкл)' : 'Формат: Код / Пресет',
                      style: TextStyle(fontSize: UiType.caption, color: skin.text),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _createAsPinned
                    ? AppIcons.pinFill
                    : (_createAsCode ? AppIcons.bolt : AppIcons.pencil),
                size: 18,
                color: (_createAsPinned || _createAsCode) ? Palette.accent : skin.muted,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Индикаторы активных режимов
          if (_createAsCode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 6),
              decoration: ShapeDecoration(
                color: Palette.accent.withValues(alpha: 0.15),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.bolt, size: 11, color: Palette.accent),
                  const SizedBox(width: 4),
                  const Text(
                    'Код',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _createAsCode = false),
                    child: const Icon(AppIcons.xmark, size: 10, color: Palette.accent),
                  ),
                ],
              ),
            ),
          ],
          if (_createAsPinned) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 6),
              decoration: ShapeDecoration(
                color: Palette.accent.withValues(alpha: 0.15),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.pinFill, size: 11, color: Palette.accent),
                  const SizedBox(width: 4),
                  const Text(
                    'Закрепить',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _createAsPinned = false),
                    child: const Icon(AppIcons.xmark, size: 10, color: Palette.accent),
                  ),
                ],
              ),
            ),
          ],

          // Поле ввода текста заметки
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              selectAllOnFocus: false,
              style: TextStyle(
                fontSize: UiType.title,
                fontFamily: _createAsCode ? 'Consolas' : null,
                color: skin.text,
              ),
              decoration: InputDecoration(
                hintText: _createAsCode
                    ? 'Скрипт, пресет или конфигурация…'
                    : context.l10n.quickNotePlaceholder,
                hintStyle: TextStyle(
                  fontSize: UiType.title,
                  color: skin.muted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSaveQuickNote(),
            ),
          ),

          // Выбранный тег
          if (_selectedTag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 6),
              decoration: ShapeDecoration(
                color: Palette.accent.withValues(alpha: 0.12),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$_selectedTag',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _selectedTag = null),
                    child: const Icon(AppIcons.xmark, size: 10, color: Palette.accent),
                  ),
                ],
              ),
            ),
          ],

          // Палитра выбора цвета для новой заметки
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in QuickNoteColors.all) ...[
                if (color != QuickNoteColors.defaultColor) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _newNoteColor = _newNoteColor == color ? null : color;
                      });
                    },
                    child: Tooltip(
                      message: _newNoteColor == color
                          ? 'Сбросить цвет заметки'
                          : 'Цвет заметки: $color',
                      preferBelow: false,
                      verticalOffset: 14,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: QuickNoteColors.getSwatch(color),
                          border: Border.all(
                            color: _newNoteColor == color
                                ? Palette.accent
                                : skin.hairlineBorder,
                            width: _newNoteColor == color ? 2.0 : 1.0,
                          ),
                          boxShadow: _newNoteColor == color
                              ? [
                                  BoxShadow(
                                    color: Palette.accent.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: _newNoteColor == color
                            ? const Center(
                                child: Icon(
                                  AppIcons.checkMark,
                                  size: 8,
                                  color: Colors.black87,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),

          const SizedBox(width: 6),

          // Иконка тега (🏷)
          PopupMenuButton<String>(
            tooltip: 'Выбрать тег',
            offset: const Offset(0, 36),
            color: skin.glassSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              side: BorderSide(color: skin.divider),
            ),
            onSelected: (tag) => setState(() => _selectedTag = tag),
            itemBuilder: (context) => [
              for (final t in ['Работа', 'Личное', 'Идея', 'Важно', 'Код', 'Срочно'])
                PopupMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(AppIcons.tag, size: 12, color: skin.muted),
                      const SizedBox(width: 8),
                      Text(t, style: TextStyle(fontSize: UiType.caption, color: skin.text)),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                AppIcons.tag,
                size: 18,
                color: _selectedTag != null ? Palette.accent : skin.muted,
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Акцентная кнопка сохранения заметки
          _QuickCaptureAddButton(
            isEnabled: hasText,
            onTap: _handleSaveQuickNote,
          ),
        ],
      ),
    );
  }
}

class _QuickCaptureAddButton extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const _QuickCaptureAddButton({
    required this.isEnabled,
    required this.onTap,
  });

  @override
  State<_QuickCaptureAddButton> createState() => _QuickCaptureAddButtonState();
}

class _QuickCaptureAddButtonState extends State<_QuickCaptureAddButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isEnabled = widget.isEnabled;

    final bgColor = isEnabled
        ? Palette.accent
        : (skin.isDark
            ? (_hover ? const Color(0xFF383B41) : const Color(0xFF26282C))
            : (_hover ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6)));

    final borderColor = isEnabled
        ? Palette.accent
        : (skin.isDark ? const Color(0xFF42464D) : const Color(0xFFE5E7EB));

    final iconColor = isEnabled ? Colors.white : skin.muted;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : (_hover && isEnabled ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 100),
          child: Tooltip(
            message: isEnabled ? 'Сохранить заметку (Enter)' : 'Новая заметка',
            preferBelow: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: borderColor),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: Palette.accent.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  isEnabled ? AppIcons.arrowUp : AppIcons.plus,
                  size: 16,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

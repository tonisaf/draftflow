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

  @override
  void initState() {
    super.initState();
    _loadedCards = _globalCardsCache;
    _subscribeToPages();
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
      );

      if (mounted) {
        setState(() {
          _inputController.clear();
          _selectedTag = null;
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
                        (constraints.maxWidth - UiLayout.editorWideMaxWidth) / 2,
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

                    // Фильтр-таблетки и палитра цветов
                    Wrap(
                      spacing: UiSpace.s6,
                      runSpacing: UiSpace.s6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildFilterChip('Все (${allCards.length})', QuickNoteFilter.all),
                        _buildFilterChip(
                          '${context.l10n.pinned} (${allCards.where((c) => c.settings.isPinned).length})',
                          QuickNoteFilter.pinned,
                          icon: AppIcons.pin,
                        ),
                        _buildFilterChip(
                          'Код & Пресеты (${allCards.where((c) => c.codeSnippet != null).length})',
                          QuickNoteFilter.code,
                          icon: AppIcons.bolt,
                        ),
                        _buildFilterChip(
                          'Чек-листы (${allCards.where((c) => c.todoItems.isNotEmpty).length})',
                          QuickNoteFilter.checklists,
                          icon: AppIcons.checkmarkSquare,
                        ),
                        if (_hasActiveFilters)
                          GestureDetector(
                            onTap: _clearAllFilters,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UiSpace.s10,
                                vertical: UiSpace.s5,
                              ),
                              decoration: ShapeDecoration(
                                color: skin.hover,
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.xmark, size: UiSpace.s11, color: skin.muted),
                                  const SizedBox(width: UiSpace.s4),
                                  Text(
                                    'Сбросить фильтры',
                                    style: TextStyle(
                                      fontSize: UiType.caption,
                                      color: skin.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Строка фильтрации по тегам и цветам
                    if (sortedTags.isNotEmpty || _selectedFilterTag != null) ...[
                      const SizedBox(height: UiSpace.s10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
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
                          ),
                          const SizedBox(width: UiSpace.s12),
                          _buildColorFilterDots(skin),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: UiSpace.s8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildColorFilterDots(skin),
                        ],
                      ),
                    ],

                    const SizedBox(height: UiSpace.s16),

                    // Панель быстрого добавления заметки в точном стиле скриншота пользователя
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
                      const SizedBox(height: UiSpace.s60),
                      Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Ничего не найдено по запросу "$_searchQuery"'
                              : 'Здесь пока нет заметок.\nВведите текст в строке выше и нажмите +, чтобы сохранить.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: UiType.body,
                            color: skin.muted,
                            height: 1.5,
                          ),
                        ),
                      ),
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
                verticalOffset: UiSpace.s14,
                child: Container(
                  margin: const EdgeInsets.only(right: UiSpace.s6),
                  width: UiSpace.s20,
                  height: UiSpace.s20,
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
                            size: UiSpace.s10,
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

  Widget _buildFilterChip(String label, QuickNoteFilter filter, {IconData? icon}) {
    final skin = context.skin;
    final isSelected = _activeFilter == filter;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UiSpace.s12, vertical: UiSpace.s5),
        decoration: ShapeDecoration(
          color: isSelected ? Palette.accent.withValues(alpha: 0.12) : skin.hover,
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected ? Palette.accent.withValues(alpha: 0.35) : skin.hairlineBorder,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: UiSpace.s12,
                color: isSelected ? skin.accentText : skin.muted,
              ),
              const SizedBox(width: UiSpace.s4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: UiType.caption,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? skin.accentText : skin.muted,
              ),
            ),
          ],
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

  Widget _buildQuickCaptureBar(Skin skin) {
    return Container(
      decoration: ShapeDecoration(
        color: skin.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: skin.hairlineBorder,
          ),
        ),
        shadows: [
          BoxShadow(
            color: skin.shadow.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: skin.shadow.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(UiSpace.s14, UiSpace.s5, UiSpace.s6, UiSpace.s5),
      child: Row(
        children: [
          // Левая иконка с плюсом в круге (⊕)
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
                      size: UiSpace.s14,
                      color: _createAsPinned ? Palette.accent : skin.muted,
                    ),
                    const SizedBox(width: UiSpace.s8),
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
                      size: UiSpace.s14,
                      color: _createAsCode ? Palette.accent : skin.muted,
                    ),
                    const SizedBox(width: UiSpace.s8),
                    Text(
                      _createAsCode ? 'Формат: Код (вкл)' : 'Формат: Код / Пресет',
                      style: TextStyle(fontSize: UiType.caption, color: skin.text),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(UiSpace.s4),
              child: Icon(
                _createAsPinned
                    ? AppIcons.pinFill
                    : (_createAsCode ? AppIcons.bolt : AppIcons.plusCircle),
                size: 20,
                color: (_createAsPinned || _createAsCode) ? Palette.accent : skin.muted,
              ),
            ),
          ),

          const SizedBox(width: UiSpace.s10),

          // Индикаторы активных режимов
          if (_createAsCode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8, vertical: UiSpace.s3),
              margin: const EdgeInsets.only(right: UiSpace.s6),
              decoration: ShapeDecoration(
                color: Palette.accent.withValues(alpha: 0.15),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.bolt, size: UiSpace.s12, color: Palette.accent),
                  const SizedBox(width: UiSpace.s4),
                  const Text(
                    'Код',
                    style: TextStyle(
                      fontSize: UiType.caption,
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                  const SizedBox(width: UiSpace.s4),
                  GestureDetector(
                    onTap: () => setState(() => _createAsCode = false),
                    child: const Icon(AppIcons.xmark, size: UiSpace.s10, color: Palette.accent),
                  ),
                ],
              ),
            ),
          ],
          if (_createAsPinned) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8, vertical: UiSpace.s3),
              margin: const EdgeInsets.only(right: UiSpace.s6),
              decoration: ShapeDecoration(
                color: Palette.accent.withValues(alpha: 0.15),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.pinFill, size: UiSpace.s12, color: Palette.accent),
                  const SizedBox(width: UiSpace.s4),
                  const Text(
                    'Закрепить',
                    style: TextStyle(
                      fontSize: UiType.caption,
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                  const SizedBox(width: UiSpace.s4),
                  GestureDetector(
                    onTap: () => setState(() => _createAsPinned = false),
                    child: const Icon(AppIcons.xmark, size: UiSpace.s10, color: Palette.accent),
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
                contentPadding: const EdgeInsets.symmetric(vertical: UiSpace.s8),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSaveQuickNote(),
            ),
          ),

          // Выбранный тег
          if (_selectedTag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8, vertical: UiSpace.s3),
              margin: const EdgeInsets.only(right: UiSpace.s6),
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
                      fontSize: UiType.caption,
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                  const SizedBox(width: UiSpace.s4),
                  GestureDetector(
                    onTap: () => setState(() => _selectedTag = null),
                    child: const Icon(AppIcons.xmark, size: UiSpace.s10, color: Palette.accent),
                  ),
                ],
              ),
            ),
          ],

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
                      Icon(AppIcons.tag, size: UiSpace.s12, color: skin.muted),
                      const SizedBox(width: UiSpace.s8),
                      Text(t, style: TextStyle(fontSize: UiType.caption, color: skin.text)),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(UiSpace.s6),
              child: Icon(
                AppIcons.tag,
                size: 20,
                color: _selectedTag != null ? Palette.accent : skin.muted,
              ),
            ),
          ),

          const SizedBox(width: UiSpace.s6),

          // Круглая кнопка с плюсом (+) в точном стиле скриншота
          _QuickCaptureAddButton(onTap: _handleSaveQuickNote),
        ],
      ),
    );
  }
}

class _QuickCaptureAddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _QuickCaptureAddButton({required this.onTap});

  @override
  State<_QuickCaptureAddButton> createState() => _QuickCaptureAddButtonState();
}

class _QuickCaptureAddButtonState extends State<_QuickCaptureAddButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    final bgColor = skin.isDark
        ? (_hover ? const Color(0xFF383B41) : const Color(0xFF26282C))
        : (_hover ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6));

    final borderColor = skin.isDark
        ? const Color(0xFF42464D)
        : const Color(0xFFE5E7EB);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Icon(
                AppIcons.plus,
                size: 18,
                color: skin.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

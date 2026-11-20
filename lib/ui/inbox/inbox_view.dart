import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Page;

import '../../data/db/app_database.dart';
import '../../data/notes_repository.dart';
import '../common/app_icons.dart';
import '../common/section_transition.dart';
import '../theme.dart';
import 'inbox_card.dart';
import 'inbox_models.dart';
import 'inbox_smart_input.dart';
import 'inbox_triage_modal.dart';

class InboxView extends StatefulWidget {
  final NotesRepository repository;
  final ValueChanged<String>? onNavigateToPage;

  const InboxView({
    super.key,
    required this.repository,
    this.onNavigateToPage,
  });

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  bool _isArchiveTab = false;
  InboxItemType? _selectedTypeFilter;
  String? _selectedDomainFilter;
  String _searchQuery = '';
  bool _sortByDomain = false;

  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<Page>>? _subscription;
  List<InboxCardData> _allCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscribeToPages();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeToPages() {
    _subscription?.cancel();
    _subscription = widget.repository.watchActivePages().listen((pages) async {
      final inboxPages = pages
          .where((p) => inboxItemFromProperties(p.properties).isInboxItem)
          .toList();

      final cards = <InboxCardData>[];
      for (final p in inboxPages) {
        final blocks = await widget.repository.getPageBlocks(p.id);
        cards.add(InboxCardData.fromPageAndBlocks(p, blocks));
      }

      if (mounted) {
        setState(() {
          _allCards = cards;
          _isLoading = false;
        });
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedTypeFilter = null;
      _selectedDomainFilter = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    // Разделение на активные (неразобранные) и архив
    final tabCards = _allCards.where((c) => c.metadata.isArchived == _isArchiveTab).toList();
    final activeCount = _allCards.where((c) => !c.metadata.isArchived).length;
    final archiveCount = _allCards.where((c) => c.metadata.isArchived).length;

    // Сбор уникальных доменов для фильтра
    final domainCounts = <String, int>{};
    for (final c in tabCards) {
      final d = c.metadata.domain;
      if (d != null && d.isNotEmpty) {
        domainCounts[d] = (domainCounts[d] ?? 0) + 1;
      }
    }
    final sortedDomains = domainCounts.keys.toList()
      ..sort((a, b) => domainCounts[b]!.compareTo(domainCounts[a]!));

    // Подсчет количества по типам
    final typeCounts = <InboxItemType, int>{};
    for (final t in InboxItemType.values) {
      typeCounts[t] = tabCards.where((c) => c.metadata.type == t).length;
    }

    // Применение фильтров
    var filteredCards = tabCards.where((c) {
      if (_selectedTypeFilter != null && c.metadata.type != _selectedTypeFilter) {
        return false;
      }
      if (_selectedDomainFilter != null && c.metadata.domain != _selectedDomainFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = c.page.title.toLowerCase().contains(q);
        final matchDomain = (c.metadata.domain ?? '').toLowerCase().contains(q);
        final matchSnippet = c.textSnippet.toLowerCase().contains(q);
        if (!matchTitle && !matchDomain && !matchSnippet) {
          return false;
        }
      }
      return true;
    }).toList();

    // Сортировка
    if (_sortByDomain) {
      filteredCards.sort((a, b) {
        final domA = a.metadata.domain ?? '';
        final domB = b.metadata.domain ?? '';
        return domA.compareTo(domB);
      });
    } else {
      // Сначала новые
      filteredCards.sort((a, b) {
        final dtA = a.metadata.savedAt ?? a.page.createdAt;
        final dtB = b.metadata.savedAt ?? b.page.createdAt;
        return dtB.compareTo(dtA);
      });
    }

    final hasActiveFilters = _selectedTypeFilter != null ||
        _selectedDomainFilter != null ||
        _searchQuery.isNotEmpty;

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
              // Заголовок страницы и строка поиска (Apple HIG / Linear)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Входящие',
                                style: TextStyle(
                                  fontSize: UiType.pageTitle,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: skin.text,
                                ),
                              ),
                              const SizedBox(height: UiSpace.s4),
                              Text(
                                'Веб-клипы, статьи, ссылки и цитаты для разбора',
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  color: skin.muted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: UiSpace.s16),

                        // Строка поиска в правом верхнем углу (как в Заметках)
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
                                  style: TextStyle(
                                    fontSize: UiType.title,
                                    color: skin.text,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Поиск…',
                                    hintStyle: TextStyle(
                                      fontSize: UiType.title,
                                      color: skin.muted,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
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

                    const SizedBox(height: 16),

                    // Панель фильтров: Категории слева, Домен/Сортировка справа (ml-auto)
                    Row(
                      children: [
                        // Вкладки типов контента + Архив слева
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  'Все',
                                  activeCount,
                                  !_isArchiveTab && _selectedTypeFilter == null,
                                  () => setState(() {
                                    _isArchiveTab = false;
                                    _selectedTypeFilter = null;
                                  }),
                                ),
                                const SizedBox(width: 4),
                                for (final t in InboxItemType.values) ...[
                                  _buildFilterChip(
                                    t.label,
                                    typeCounts[t] ?? 0,
                                    !_isArchiveTab && _selectedTypeFilter == t,
                                    () => setState(() {
                                      _isArchiveTab = false;
                                      _selectedTypeFilter =
                                          _selectedTypeFilter == t ? null : t;
                                    }),
                                    icon: t.icon,
                                    iconSize: t == InboxItemType.quote ? 14.0 : 13.0,
                                  ),
                                  const SizedBox(width: 4),
                                ],

                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 16,
                                  color: skin.isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : const Color(0x14000000), // bg-black/[0.08]
                                ),
                                const SizedBox(width: 8),

                                // Архив как фильтр-таблетка
                                _buildFilterChip(
                                  'Архив',
                                  archiveCount,
                                  _isArchiveTab,
                                  () => setState(() {
                                    _isArchiveTab = !_isArchiveTab;
                                    _selectedTypeFilter = null;
                                  }),
                                  icon: AppIcons.archivebox,
                                ),

                                if (hasActiveFilters) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _resetFilters,
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

                        const SizedBox(width: 8),

                        // Контролы домена и сортировки справа (ml-auto flex items-center gap-1.5)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDomainDropdown(sortedDomains, domainCounts, skin),
                            const SizedBox(width: 6),
                            _buildSortButton(skin),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Поле умного захвата (Smart Input) прямо над карточками
                    if (!_isArchiveTab) ...[
                      InboxSmartInput(
                        onSubmit: ({
                          required title,
                          required type,
                          url,
                          domain,
                          faviconUrl,
                          previewImageUrl,
                          excerpt,
                          body,
                        }) async {
                          await widget.repository.createInboxItem(
                            title: title,
                            type: type,
                            url: url,
                            domain: domain,
                            faviconUrl: faviconUrl,
                            previewImageUrl: previewImageUrl,
                            excerpt: excerpt,
                            body: body,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Сетка карточек или состояние пустого экрана
                    if (_isLoading && _allCards.isEmpty) ...[
                      const SizedBox(height: 60),
                      Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: skin.muted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ] else if (filteredCards.isEmpty) ...[
                      const SizedBox(height: 48),
                      Center(
                        child: hasActiveFilters
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Icon(AppIcons.search, size: 22, color: skin.muted),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'По выбранным фильтрам ничего не найдено',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: skin.text,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: _resetFilters,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Сбросить фильтры',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: skin.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _isArchiveTab ? AppIcons.archivebox : AppIcons.tray,
                                        size: 26,
                                        color: skin.muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isArchiveTab
                                        ? 'Архив пуст'
                                        : 'Здесь пока нет входящих материалов',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: skin.text,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isArchiveTab
                                        ? 'Разобранные материалы будут храниться здесь'
                                        : 'Вставляйте ссылки в строку выше или отправляйте из браузера',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: skin.muted,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ] else ...[
                      _buildMasonryGrid(filteredCards, gridWidth),
                    ],
                  ],
                ),
              );
            },
          );
  }

  Widget _buildFilterChip(
    String label,
    int count,
    bool isSelected,
    VoidCallback onTap, {
    IconData? icon,
    double iconSize = 13.0,
  }) {
    final skin = context.skin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: ShapeDecoration(
            color: isSelected
                ? Palette.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected
                    ? Palette.accent.withValues(alpha: 0.25)
                    : Colors.transparent,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? Palette.accent : skin.muted,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Palette.accent : skin.text,
                ),
              ),
              if (count > 0 || isSelected) ...[
                const SizedBox(width: 6),
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

  Widget _buildDomainDropdown(
    List<String> sortedDomains,
    Map<String, int> domainCounts,
    Skin skin,
  ) {
    final hasSelection = _selectedDomainFilter != null;
    final triggerTextColor = hasSelection
        ? Palette.accent
        : (skin.isDark ? skin.muted : const Color(0xFF4B5563));

    return PopupMenuButton<String?>(
      tooltip: 'Источник / Домен',
      offset: const Offset(0, 32),
      color: skin.glassSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.control),
        side: BorderSide(color: skin.divider),
      ),
      onSelected: (val) => setState(() => _selectedDomainFilter = val),
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(AppIcons.globe, size: 14, color: !hasSelection ? Palette.accent : skin.muted),
              const SizedBox(width: 8),
              Text(
                'Все сайты',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: !hasSelection ? FontWeight.w600 : FontWeight.normal,
                  color: !hasSelection ? Palette.accent : skin.text,
                ),
              ),
            ],
          ),
        ),
        for (final domain in sortedDomains)
          PopupMenuItem<String?>(
            value: domain,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.link,
                      size: 13,
                      color: _selectedDomainFilter == domain ? Palette.accent : skin.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      domain,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            _selectedDomainFilter == domain ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedDomainFilter == domain ? Palette.accent : skin.text,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${domainCounts[domain]}',
                  style: TextStyle(fontSize: 11, color: skin.muted),
                ),
              ],
            ),
          ),
      ],
      child: _SecondaryTriggerButton(
        isActive: hasSelection,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.globe,
              size: 13,
              color: triggerTextColor,
            ),
            const SizedBox(width: 5),
            Text(
              _selectedDomainFilter ?? 'Все сайты',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: triggerTextColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(AppIcons.chevronDown, size: 10, color: triggerTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(Skin skin) {
    final triggerTextColor = _sortByDomain
        ? Palette.accent
        : (skin.isDark ? skin.muted : const Color(0xFF4B5563));

    return _SecondaryTriggerButton(
      isActive: _sortByDomain,
      onTap: () => setState(() => _sortByDomain = !_sortByDomain),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.lineHorizontal3Decrease,
            size: 13,
            color: triggerTextColor,
          ),
          const SizedBox(width: 5),
          Text(
            _sortByDomain ? 'По сайту (A-Z)' : 'Сначала новые',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: triggerTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasonryGrid(List<InboxCardData> cards, double containerWidth) {
    int colCount = 2;
    if (containerWidth >= 800) {
      colCount = 3;
    } else if (containerWidth < 500) {
      colCount = 1;
    }

    const gap = 14.0;
    final colWidth = (containerWidth - (colCount - 1) * gap) / colCount;

    final columns = List.generate(colCount, (_) => <Widget>[]);

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final colIndex = i % colCount;

      columns[colIndex].add(
        Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: SizedBox(
            width: colWidth,
            child: InboxCard(
              cardData: card,
              onTap: () => InboxTriageModal.show(
                context,
                cardData: card,
                repository: widget.repository,
                onOpenInEditor: widget.onNavigateToPage,
              ),
              onToggleArchive: () async {
                await widget.repository.updateInboxItemStatus(
                  card.page.id,
                  isArchived: !card.metadata.isArchived,
                );
              },
              onConvertToDoc: () async {
                await widget.repository.convertInboxItemToPage(card.page.id);
              },
              onDelete: () async {
                await widget.repository.deleteInboxItem(card.page.id);
              },
              onSelectDomain: (dom) => setState(() => _selectedDomainFilter = dom),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < colCount; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columns[i],
            ),
          ),
        ],
      ],
    );
  }
}

class _SecondaryTriggerButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isActive;

  const _SecondaryTriggerButton({
    required this.child,
    this.onTap,
    this.isActive = false,
  });

  @override
  State<_SecondaryTriggerButton> createState() => _SecondaryTriggerButtonState();
}

class _SecondaryTriggerButtonState extends State<_SecondaryTriggerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    // h-7 px-2.5 rounded-lg bg-black/[0.03] hover:bg-black/[0.06] text-[12px] font-medium text-[#4B5563] transition-colors
    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0x08000000); // bg-black/[0.03]
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0x0F000000); // hover:bg-black/[0.06]
    final activeBg = Palette.accent.withValues(alpha: 0.12);

    final bg = widget.isActive ? activeBg : (_hovered ? hoverBg : defaultBg);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 28, // h-7
          padding: const EdgeInsets.symmetric(horizontal: 10), // px-2.5
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8), // rounded-lg
            border: widget.isActive
                ? Border.all(color: Palette.accent.withValues(alpha: 0.25), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}


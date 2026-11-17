import 'app_dialog.dart';
import 'menu.dart';
import 'app_icons.dart';
import 'page_icon_view.dart';

import 'dart:async';

import 'package:flutter/cupertino.dart' hide Page;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../theme.dart';

sealed class QuickSearchResult {
  const QuickSearchResult();
}

class OpenPageResult extends QuickSearchResult {
  final String pageId;
  const OpenPageResult(this.pageId);
}

class CreatePageResult extends QuickSearchResult {
  final String title;
  const CreatePageResult(this.title);
}

class ExecuteCommandResult extends QuickSearchResult {
  final QuickCommand command;
  const ExecuteCommandResult(this.command);
}

enum QuickCommand {
  newRootPage,
  newQuickNote,
  toggleSidebar,
  openQuickNotes,
  openTrash,
  openBackup,
  toggleTheme,
  toggleLanguage,
}

enum SearchScope {
  all,
  pages,
  quickNotes,
  commands,
}

class CommandDefinition {
  final QuickCommand command;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? shortcut;
  final List<String> keywords;

  const CommandDefinition({
    required this.command,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.shortcut,
    this.keywords = const [],
  });
}

const List<CommandDefinition> appCommands = [
  CommandDefinition(
    command: QuickCommand.newRootPage,
    title: 'Создать новую страницу',
    subtitle: 'Добавить чистый документ в корень',
    icon: AppIcons.plusCircle,
    shortcut: '⌘N',
    keywords: ['создать', 'новая', 'страница', 'документ', 'new', 'page', 'create'],
  ),
  CommandDefinition(
    command: QuickCommand.newQuickNote,
    title: 'Создать быструю заметку',
    subtitle: 'Мгновенная карточка с тегом и цветом',
    icon: CupertinoIcons.bolt,
    shortcut: '⌘⇧N',
    keywords: ['заметка', 'быстрая', 'карточка', 'quick', 'note', 'memo'],
  ),
  CommandDefinition(
    command: QuickCommand.toggleSidebar,
    title: 'Скрыть / Показать боковую панель',
    subtitle: 'Переключить видимость сайдбара',
    icon: CupertinoIcons.sidebar_left,
    shortcut: '⌘\\',
    keywords: ['сайдбар', 'панель', 'боковая', 'sidebar', 'toggle', 'hide'],
  ),
  CommandDefinition(
    command: QuickCommand.openQuickNotes,
    title: 'Открыть «Быстрые заметки»',
    subtitle: 'Перейти к доске карточек и идей',
    icon: CupertinoIcons.square_grid_2x2,
    keywords: ['заметки', 'быстрые', 'карточки', 'доска', 'board', 'quick'],
  ),
  CommandDefinition(
    command: QuickCommand.openTrash,
    title: 'Открыть Корзину',
    subtitle: 'Просмотр и восстановление удаленных заметок',
    icon: CupertinoIcons.trash,
    keywords: ['корзина', 'удаленные', 'мусорка', 'trash', 'bin', 'restore'],
  ),
  CommandDefinition(
    command: QuickCommand.openBackup,
    title: 'Резервное копирование и экспорт',
    subtitle: 'Экспорт в Markdown/JSON, импорт из Notion',
    icon: CupertinoIcons.arrow_down_doc,
    keywords: ['бэкап', 'резервная', 'экспорт', 'импорт', 'notion', 'backup', 'export', 'import'],
  ),
  CommandDefinition(
    command: QuickCommand.toggleTheme,
    title: 'Переключить тему оформления',
    subtitle: 'Светлая / Тёмная / Системная',
    icon: CupertinoIcons.circle_righthalf_fill,
    keywords: ['тема', 'тёмная', 'светлая', 'темная', 'оформление', 'theme', 'dark', 'light'],
  ),
  CommandDefinition(
    command: QuickCommand.toggleLanguage,
    title: 'Переключить язык интерфейса',
    subtitle: 'Русский / English',
    icon: CupertinoIcons.globe,
    keywords: ['язык', 'перевод', 'локализация', 'language', 'locale', 'english', 'русский'],
  ),
];

Future<QuickSearchResult?> showQuickSearchDialog(
  BuildContext context, {
  required NotesRepository repository,
}) {
  return showAppDialog<QuickSearchResult?>(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (context) => _QuickSearchModal(repository: repository),
  );
}

class _QuickSearchModal extends StatefulWidget {
  final NotesRepository repository;

  const _QuickSearchModal({required this.repository});

  @override
  State<_QuickSearchModal> createState() => _QuickSearchModalState();
}

class _QuickSearchModalState extends State<_QuickSearchModal> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<SearchResultItem> _rawResults = const [];
  List<SearchResultItem> _filteredResults = const [];
  List<CommandDefinition> _matchingCommands = const [];
  List<String> _recentQueries = const [];
  Set<String> _availableTags = const {};
  SearchScope _selectedScope = SearchScope.all;
  String? _selectedTag;

  bool _isLoading = true;
  int _selectedIndex = 0;
  Timer? _debounceTimer;

  bool get _isCommandMode => _queryController.text.trim().startsWith('>');

  bool get _hasCreateOption =>
      !_isCommandMode &&
      _selectedScope != SearchScope.commands &&
      _queryController.text.trim().isNotEmpty &&
      !_filteredResults.any(
        (r) =>
            r.page.title.trim().toLowerCase() ==
            _queryController.text.trim().toLowerCase(),
      );

  int get _totalItems =>
      _matchingCommands.length +
      _filteredResults.length +
      (_hasCreateOption ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _loadRecentQueries();
    _loadResults('');
  }

  Future<void> _loadRecentQueries() async {
    final list = await widget.repository.getRecentSearchQueries();
    if (mounted) {
      setState(() => _recentQueries = list);
    }
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Motion.quickSearchDebounce, () {
      _loadResults(query);
    });
  }

  Future<void> _loadResults(String query) async {
    setState(() => _isLoading = true);
    final results = await widget.repository.searchPages(query);
    if (!mounted) return;

    final tags = <String>{};
    for (final r in results) {
      if (r.matchedTag != null && r.matchedTag!.isNotEmpty) {
        tags.add(r.matchedTag!);
      }
    }

    setState(() {
      _rawResults = results;
      _availableTags = tags;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final rawText = _queryController.text.trim();
    final isCommandMode = rawText.startsWith('>');
    final cmdQuery = isCommandMode
        ? rawText.substring(1).trim().toLowerCase()
        : rawText.toLowerCase();

    // 1. Filter commands
    final matchingCmds = <CommandDefinition>[];
    if (isCommandMode) {
      for (final cmd in appCommands) {
        if (cmdQuery.isEmpty ||
            cmd.title.toLowerCase().contains(cmdQuery) ||
            cmd.subtitle.toLowerCase().contains(cmdQuery) ||
            cmd.keywords.any((k) => k.toLowerCase().contains(cmdQuery))) {
          matchingCmds.add(cmd);
        }
      }
    } else if (_selectedScope == SearchScope.commands) {
      for (final cmd in appCommands) {
        if (cmdQuery.isEmpty ||
            cmd.title.toLowerCase().contains(cmdQuery) ||
            cmd.subtitle.toLowerCase().contains(cmdQuery) ||
            cmd.keywords.any((k) => k.toLowerCase().contains(cmdQuery))) {
          matchingCmds.add(cmd);
        }
      }
    } else if (_selectedScope == SearchScope.all && rawText.isNotEmpty) {
      for (final cmd in appCommands) {
        if (cmd.title.toLowerCase().contains(cmdQuery) ||
            cmd.keywords.any((k) => k.toLowerCase().contains(cmdQuery))) {
          matchingCmds.add(cmd);
        }
      }
    }

    // 2. Filter pages & notes (hidden in command mode)
    final filteredPages = isCommandMode || _selectedScope == SearchScope.commands
        ? <SearchResultItem>[]
        : _rawResults.where((item) {
            if (_selectedScope == SearchScope.pages && item.isQuickNote) {
              return false;
            }
            if (_selectedScope == SearchScope.quickNotes && !item.isQuickNote) {
              return false;
            }
            String? explicitTag = _selectedTag;
            if (rawText.startsWith('#') && rawText.length > 1) {
              explicitTag = rawText.substring(1).trim();
            }
            if (explicitTag != null && explicitTag.isNotEmpty) {
              final itemTag = item.matchedTag?.toLowerCase();
              if (itemTag == null || !itemTag.contains(explicitTag.toLowerCase())) {
                return false;
              }
            }
            return true;
          }).toList();

    setState(() {
      _matchingCommands = matchingCmds;
      _filteredResults = filteredPages;
      _selectedIndex = 0;
    });
  }

  void _setScope(SearchScope scope, String? tag) {
    setState(() {
      _selectedScope = scope;
      _selectedTag = tag;
      _applyFilter();
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_totalItems > 0) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _totalItems;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_totalItems > 0) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _totalItems) % _totalItems;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _activateCurrent();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final targetOffset = (_selectedIndex * 52.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
    );
  }

  void _activateCurrent() {
    final text = _queryController.text.trim();
    if (text.isNotEmpty && !text.startsWith('>')) {
      widget.repository.addRecentSearchQuery(text);
    }
    if (_selectedIndex < _matchingCommands.length) {
      Navigator.of(context).pop(ExecuteCommandResult(_matchingCommands[_selectedIndex].command));
    } else if (_selectedIndex < _matchingCommands.length + _filteredResults.length) {
      final pageIndex = _selectedIndex - _matchingCommands.length;
      Navigator.of(context).pop(OpenPageResult(_filteredResults[pageIndex].page.id));
    } else if (_hasCreateOption) {
      Navigator.of(context).pop(CreatePageResult(_queryController.text.trim()));
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isQueryEmpty = _queryController.text.trim().isEmpty;
    final currentQuery = _queryController.text.trim();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        insetAnimationDuration: Motion.of(context, Motion.micro),
        insetAnimationCurve: Motion.curve,
        alignment: const Alignment(0, -0.65),
        backgroundColor: Palette.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: UiSpace.s20),
        child: MenuCard.surface(
          width: UiLayout.searchWidth + 40,
          constraints: const BoxConstraints(
            maxHeight: 520,
          ),
          color: skin.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Search Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UiSpace.s16,
                  UiSpace.s12,
                  UiSpace.s14,
                  UiSpace.s10,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.search,
                      size: UiSpace.s18,
                      color: skin.muted,
                    ),
                    const SizedBox(width: UiSpace.s12),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onChanged: _onQueryChanged,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: UiType.title,
                          fontWeight: FontWeight.w500,
                          color: skin.text,
                        ),
                        decoration: InputDecoration(
                          hintText: _isCommandMode
                              ? 'Введите команду (тема, сайдбар, корзина)...'
                              : 'Поиск по страницам, заметкам или > для команд...',
                          hintStyle: TextStyle(
                            fontSize: UiType.title,
                            fontWeight: FontWeight.w400,
                            color: skin.hint,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_isLoading) ...[
                      SizedBox(
                        width: UiSpace.s14,
                        height: UiSpace.s14,
                        child: TickerMode(
                          enabled: !MediaQuery.disableAnimationsOf(context),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: skin.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: UiSpace.s8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UiSpace.s6,
                        vertical: UiSpace.s3,
                      ),
                      decoration: BoxDecoration(
                        color: skin.hover,
                        borderRadius: BorderRadius.circular(UiRadius.compact),
                        border: Border.all(
                          color: skin.hairlineBorder,
                        ),
                      ),
                      child: Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: UiType.small,
                          fontWeight: FontWeight.w600,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Scope Filter Chips (Все / Страницы / Заметки / #Теги)
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: UiSpace.s12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ScopeFilterChip(
                      label: 'Все',
                      icon: AppIcons.docTextSearch,
                      count: _rawResults.length,
                      isSelected: _selectedScope == SearchScope.all && _selectedTag == null,
                      onTap: () => _setScope(SearchScope.all, null),
                    ),
                    const SizedBox(width: UiSpace.s6),
                    _ScopeFilterChip(
                      label: 'Страницы',
                      icon: AppIcons.docText,
                      isSelected: _selectedScope == SearchScope.pages && _selectedTag == null,
                      onTap: () => _setScope(SearchScope.pages, null),
                    ),
                    const SizedBox(width: UiSpace.s6),
                    _ScopeFilterChip(
                      label: 'Заметки',
                      icon: AppIcons.bolt,
                      isSelected: _selectedScope == SearchScope.quickNotes && _selectedTag == null,
                      onTap: () => _setScope(SearchScope.quickNotes, null),
                    ),
                    const SizedBox(width: UiSpace.s6),
                    _ScopeFilterChip(
                      label: '⚡ Команды',
                      icon: CupertinoIcons.command,
                      isSelected: _selectedScope == SearchScope.commands,
                      onTap: () => _setScope(SearchScope.commands, null),
                    ),
                    for (final t in _availableTags) ...[
                      const SizedBox(width: UiSpace.s6),
                      _ScopeFilterChip(
                        label: '#$t',
                        icon: AppIcons.tag,
                        isSelected: _selectedTag == t,
                        onTap: () => _setScope(
                          SearchScope.all,
                          _selectedTag == t ? null : t,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: UiSpace.s4),

              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.hairlineBorder,
              ),

              // Recent Search Queries (Phase 2)
              if (isQueryEmpty && _recentQueries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UiSpace.s16,
                    UiSpace.s8,
                    UiSpace.s16,
                    UiSpace.s4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.clock, size: 10, color: skin.hint),
                          const SizedBox(width: 4),
                          Text(
                            'НЕДАВНИЕ ЗАПРОСЫ',
                            style: TextStyle(
                              fontSize: UiType.micro,
                              fontWeight: FontWeight.w700,
                              color: skin.hint,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          await widget.repository.clearRecentSearchQueries();
                          _loadRecentQueries();
                        },
                        child: Text(
                          'Очистить',
                          style: TextStyle(
                            fontSize: UiType.micro,
                            color: skin.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.s12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentQueries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final q = _recentQueries[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: skin.hover,
                          borderRadius: BorderRadius.circular(UiRadius.compact),
                          border: Border.all(color: skin.hairlineBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _queryController.text = q;
                                _queryController.selection =
                                    TextSelection.collapsed(offset: q.length);
                                _onQueryChanged(q);
                              },
                              child: Text(
                                q,
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  fontWeight: FontWeight.w500,
                                  color: skin.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () async {
                                await widget.repository.removeRecentSearchQuery(q);
                                _loadRecentQueries();
                              },
                              child: Icon(
                                CupertinoIcons.clear,
                                size: 10,
                                color: skin.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: UiSpace.s6),
                Divider(
                  height: 1,
                  thickness: UiSpace.s1,
                  color: skin.hairlineBorder,
                ),
              ],

              // 3. Category Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UiSpace.s16,
                  UiSpace.s8,
                  UiSpace.s16,
                  UiSpace.s4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCommandMode || _selectedScope == SearchScope.commands
                          ? 'КОМАНДЫ И ДЕЙСТВИЯ'
                          : (isQueryEmpty
                              ? context.l10n.recentPages.toUpperCase()
                              : 'РЕЗУЛЬТАТЫ ПОИСКА'),
                      style: TextStyle(
                        fontSize: UiType.micro,
                        fontWeight: FontWeight.w700,
                        color: skin.hint,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (!isQueryEmpty || _isCommandMode || _selectedScope == SearchScope.commands)
                      Text(
                        'Найдено ${_matchingCommands.length + _filteredResults.length}',
                        style: TextStyle(
                          fontSize: UiType.micro,
                          color: skin.hint,
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Results List
              Flexible(
                child: _totalItems == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: UiSpace.s36,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCommandMode ? CupertinoIcons.command : AppIcons.docTextSearch,
                                size: UiSpace.s28,
                                color: skin.muted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: UiSpace.s8),
                              Text(
                                _isCommandMode ? 'Команда не найдена' : context.l10n.noMatchingNotes,
                                style: TextStyle(
                                  fontSize: UiType.body,
                                  color: skin.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s8,
                          vertical: UiSpace.s4,
                        ),
                        shrinkWrap: true,
                        itemCount: _totalItems,
                        itemBuilder: (context, index) {
                          if (index < _matchingCommands.length) {
                            final cmd = _matchingCommands[index];
                            final isSelected = index == _selectedIndex;
                            return _CommandResultTile(
                              command: cmd,
                              query: _isCommandMode
                                  ? _queryController.text.substring(1).trim()
                                  : _queryController.text.trim(),
                              isSelected: isSelected,
                              onTap: () {
                                Navigator.of(context).pop(ExecuteCommandResult(cmd.command));
                              },
                            );
                          } else if (index < _matchingCommands.length + _filteredResults.length) {
                            final pageIndex = index - _matchingCommands.length;
                            final item = _filteredResults[pageIndex];
                            final isSelected = index == _selectedIndex;
                            return _SearchResultTile(
                              item: item,
                              query: currentQuery,
                              isSelected: isSelected,
                              onTap: () {
                                final text = _queryController.text.trim();
                                if (text.isNotEmpty && !text.startsWith('>')) {
                                  widget.repository.addRecentSearchQuery(text);
                                }
                                Navigator.of(context)
                                    .pop(OpenPageResult(item.page.id));
                              },
                            );
                          } else {
                            final isSelected = index == _selectedIndex;
                            final query = _queryController.text.trim();
                            return _CreatePageTile(
                              title: query,
                              isSelected: isSelected,
                              onTap: () {
                                final text = _queryController.text.trim();
                                if (text.isNotEmpty && !text.startsWith('>')) {
                                  widget.repository.addRecentSearchQuery(text);
                                }
                                Navigator.of(context)
                                    .pop(CreatePageResult(query));
                              },
                            );
                          }
                        },
                      ),
              ),

              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.5),
              ),

              // 5. Bottom Shortcuts Legend
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s14,
                  vertical: UiSpace.s8,
                ),
                child: Row(
                  children: [
                    _ShortcutHint(
                      keys: const ['↑', '↓'],
                      label: context.l10n.navigateShortcut,
                    ),
                    const SizedBox(width: UiSpace.s14),
                    _ShortcutHint(
                      keys: const ['↵'],
                      label: context.l10n.openShortcut,
                    ),
                    const SizedBox(width: UiSpace.s14),
                    _ShortcutHint(
                      keys: const ['ESC'],
                      label: context.l10n.closeShortcut,
                    ),
                    const Spacer(),
                    Text(
                      'Умный поиск с контекстом',
                      style: TextStyle(
                        fontSize: UiType.micro,
                        color: skin.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeFilterChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScopeFilterChip({
    required this.label,
    required this.icon,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ScopeFilterChip> createState() => _ScopeFilterChipState();
}

class _ScopeFilterChipState extends State<_ScopeFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final activeBg = Palette.accent.withValues(alpha: 0.14);
    final hoverBg = skin.controlHover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8, vertical: 3),
          decoration: ShapeDecoration(
            color: widget.isSelected
                ? activeBg
                : (_hovered ? hoverBg : Palette.transparent),
            shape: UiRadius.squircle(
              UiRadius.compact,
              side: BorderSide(
                color: widget.isSelected
                    ? Palette.accent.withValues(alpha: 0.5)
                    : skin.hairlineBorder.withValues(alpha: 0.6),
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 11,
                color: widget.isSelected ? Palette.accent : skin.muted,
              ),
              const SizedBox(width: UiSpace.s4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: UiType.small,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? Palette.accent : skin.text,
                ),
              ),
              if (widget.count != null && widget.count! > 0) ...[
                const SizedBox(width: UiSpace.s4),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: UiType.micro,
                    color: widget.isSelected
                        ? Palette.accent.withValues(alpha: 0.8)
                        : skin.hint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final SearchResultItem item;
  final String query;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.item,
    required this.query,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final item = widget.item;
    final page = item.page;
    final title = page.title.trim().isEmpty
        ? context.l10n.untitled
        : page.title;

    final hasSnippet = item.snippet != null && item.snippet!.isNotEmpty;

    final fill = widget.isSelected
        ? Palette.accent.withValues(alpha: 0.12)
        : (_hovered ? skin.controlHover : Palette.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpace.s10,
            vertical: UiSpace.s6,
          ),
          decoration: ShapeDecoration(
            color: fill,
            shape: UiRadius.squircle(UiRadius.control),
          ),
          child: Row(
            crossAxisAlignment: hasSnippet ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              // Page Icon
              Padding(
                padding: EdgeInsets.only(top: hasSnippet ? 2.0 : 0.0),
                child: page.icon != null && page.icon!.isNotEmpty
                    ? PageIconView(
                        icon: page.icon!,
                        size: UiType.editorBody,
                      )
                    : Icon(
                        item.isQuickNote ? AppIcons.bolt : AppIcons.docText,
                        size: UiSpace.s16,
                        color: widget.isSelected
                            ? Palette.accent
                            : (item.isQuickNote ? const Color(0xFFF59E0B) : skin.muted),
                      ),
              ),
              const SizedBox(width: UiSpace.s10),

              // Title, Path and Snippet
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Row 1: Title + Path
                    Row(
                      children: [
                        Flexible(
                          child: _HighlightText(
                            text: title,
                            query: widget.query,
                            secondaryQuery: item.matchedTerm,
                            baseStyle: TextStyle(
                              fontSize: UiType.title,
                              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: skin.text,
                            ),
                            highlightStyle: TextStyle(
                              fontSize: UiType.title,
                              fontWeight: FontWeight.w700,
                              color: Palette.accent,
                            ),
                          ),
                        ),
                        if (item.path.isNotEmpty) ...[
                          const SizedBox(width: UiSpace.s6),
                          Text(
                            '•  ${item.path}',
                            style: TextStyle(
                              fontSize: UiType.caption,
                              color: skin.hint,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Row 2: Contextual Snippet with Highlight
                    if (hasSnippet) ...[
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            AppIcons.docTextSearch,
                            size: 11,
                            color: skin.muted.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _HighlightText(
                              text: item.snippet!,
                              query: widget.query,
                              secondaryQuery: item.matchedTerm,
                              baseStyle: TextStyle(
                                fontSize: UiType.caption,
                                color: skin.muted,
                                height: 1.25,
                              ),
                              highlightStyle: TextStyle(
                                fontSize: UiType.caption,
                                fontWeight: FontWeight.w700,
                                color: Palette.accent,
                                height: 1.25,
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: UiSpace.s8),

              // Badges
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.isFuzzyMatch) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Palette.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(UiRadius.compact),
                        border: Border.all(color: Palette.accent.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        item.matchedTerm != null ? '~ ${item.matchedTerm}' : '~ опечатка',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.accent,
                        ),
                      ),
                    ),
                  ],
                  if (item.isQuickNote) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(UiRadius.compact),
                      ),
                      child: Text(
                        'Заметка',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                  if (item.matchedTag != null && item.matchedTag!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: skin.hover,
                        borderRadius: BorderRadius.circular(UiRadius.compact),
                        border: Border.all(color: skin.hairlineBorder),
                      ),
                      child: Text(
                        '#${item.matchedTag}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ] else if (item.isContentMatch && !hasSnippet) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: skin.hover,
                        borderRadius: BorderRadius.circular(UiRadius.compact),
                      ),
                      child: Text(
                        'в тексте',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ],
                  if (widget.isSelected) ...[
                    const SizedBox(width: 4),
                    Text(
                      '↵',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Palette.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final String? secondaryQuery;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;
  final int maxLines;

  const _HighlightText({
    required this.text,
    required this.query,
    this.secondaryQuery,
    required this.baseStyle,
    required this.highlightStyle,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final clean = query.trim().toLowerCase();
    final lowerText = text.toLowerCase();
    final needles = <String>[];
    if (clean.isNotEmpty) {
      needles.add(clean);
      final words = clean.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
      if (words.length > 1) {
        needles.addAll(words);
      }
    }
    if (secondaryQuery != null && secondaryQuery!.trim().isNotEmpty) {
      final sec = secondaryQuery!.trim().toLowerCase();
      if (!needles.contains(sec)) needles.add(sec);
    }

    if (needles.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final matchedIntervals = <(int, int)>[];
    for (final needle in needles) {
      int pos = 0;
      while (pos < lowerText.length) {
        final idx = lowerText.indexOf(needle, pos);
        if (idx == -1) break;
        matchedIntervals.add((idx, idx + needle.length));
        pos = idx + needle.length;
      }
    }

    if (matchedIntervals.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    matchedIntervals.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final interval in matchedIntervals) {
      if (merged.isEmpty || interval.$1 > merged.last.$2) {
        merged.add(interval);
      } else if (interval.$2 > merged.last.$2) {
        merged[merged.length - 1] = (merged.last.$1, interval.$2);
      }
    }

    final spans = <TextSpan>[];
    int current = 0;
    for (final (start, end) in merged) {
      if (start > current) {
        spans.add(TextSpan(text: text.substring(current, start), style: baseStyle));
      }
      spans.add(TextSpan(text: text.substring(start, end), style: highlightStyle));
      current = end;
    }
    if (current < text.length) {
      spans.add(TextSpan(text: text.substring(current), style: baseStyle));
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}

class _CommandResultTile extends StatefulWidget {
  final CommandDefinition command;
  final String query;
  final bool isSelected;
  final VoidCallback onTap;

  const _CommandResultTile({
    required this.command,
    required this.query,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CommandResultTile> createState() => _CommandResultTileState();
}

class _CommandResultTileState extends State<_CommandResultTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final cmd = widget.command;

    final fill = widget.isSelected
        ? Palette.accent.withValues(alpha: 0.12)
        : (_hovered ? skin.controlHover : Palette.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpace.s10,
            vertical: UiSpace.s6,
          ),
          decoration: ShapeDecoration(
            color: fill,
            shape: UiRadius.squircle(UiRadius.control),
          ),
          child: Row(
            children: [
              // Command Icon badge
              Container(
                width: 24,
                height: 24,
                decoration: ShapeDecoration(
                  color: Palette.accent.withValues(alpha: 0.12),
                  shape: UiRadius.squircle(UiRadius.compact),
                ),
                child: Icon(
                  cmd.icon,
                  size: 13,
                  color: Palette.accent,
                ),
              ),
              const SizedBox(width: UiSpace.s10),

              // Title and Subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HighlightText(
                      text: cmd.title,
                      query: widget.query,
                      baseStyle: TextStyle(
                        fontSize: UiType.title,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: skin.text,
                      ),
                      highlightStyle: TextStyle(
                        fontSize: UiType.title,
                        fontWeight: FontWeight.w700,
                        color: Palette.accent,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      cmd.subtitle,
                      style: TextStyle(
                        fontSize: UiType.caption,
                        color: skin.muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: UiSpace.s8),

              // Action Badge and optional Shortcut Badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Palette.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(UiRadius.compact),
                    ),
                    child: Text(
                      'Команда',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.accent,
                      ),
                    ),
                  ),
                  if (cmd.shortcut != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: skin.hover,
                        borderRadius: BorderRadius.circular(UiRadius.compact),
                        border: Border.all(color: skin.hairlineBorder),
                      ),
                      child: Text(
                        cmd.shortcut!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: skin.muted,
                        ),
                      ),
                    ),
                  ],
                  if (widget.isSelected) ...[
                    const SizedBox(width: 4),
                    Text(
                      '↵',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Palette.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePageTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CreatePageTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final fill = isSelected
        ? Palette.accent.withValues(alpha: 0.12)
        : Palette.transparent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: UiSpace.s38,
        margin: const EdgeInsets.symmetric(vertical: UiSpace.s1),
        padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(UiRadius.control),
        ),
        child: Row(
          children: [
            Icon(AppIcons.plusCircle, size: UiSpace.s16, color: Palette.accent),
            const SizedBox(width: UiSpace.s10),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: UiType.title, color: skin.text),
                children: [
                  TextSpan(text: context.l10n.createPageAction),
                  TextSpan(
                    text: '"$title"',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Palette.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  final List<String> keys;
  final String label;

  const _ShortcutHint({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s4,
              vertical: UiSpace.s1_5,
            ),
            margin: const EdgeInsets.only(right: UiSpace.s3),
            decoration: BoxDecoration(
              color: skin.hover,
              borderRadius: BorderRadius.circular(UiRadius.action),
              border: Border.all(color: skin.divider.withValues(alpha: 0.4)),
            ),
            child: Text(
              k,
              style: TextStyle(
                fontSize: UiType.micro,
                fontWeight: FontWeight.w600,
                color: skin.muted,
              ),
            ),
          ),
        ],
        const SizedBox(width: UiSpace.s4),
        Text(
          label,
          style: TextStyle(fontSize: UiType.small, color: skin.muted),
        ),
      ],
    );
  }
}

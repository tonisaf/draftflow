import 'app_dialog.dart';
import 'menu.dart';
import 'app_icons.dart';
import 'quiet_button.dart';

import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../data/db/app_database.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../theme.dart';

Future<Page?> showPageLinkPickerDialog(
  BuildContext context, {
  required NotesRepository repository,
  String? excludePageId,
}) {
  return showAppDialog<Page?>(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (context) => _PageLinkPickerModal(
      repository: repository,
      excludePageId: excludePageId,
    ),
  );
}

class _PageLinkPickerModal extends StatefulWidget {
  final NotesRepository repository;
  final String? excludePageId;

  const _PageLinkPickerModal({required this.repository, this.excludePageId});

  @override
  State<_PageLinkPickerModal> createState() => _PageLinkPickerModalState();
}

class _PageLinkPickerModalState extends State<_PageLinkPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<SearchResultItem> _results = const [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPages('');
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Motion.linkSearchDebounce, () {
      _loadPages(query);
    });
  }

  Future<void> _loadPages(String query) async {
    setState(() => _isLoading = true);
    final results = await widget.repository.searchPages(query);
    if (!mounted) return;
    final filtered = results
        .where((r) => r.page.id != widget.excludePageId)
        .toList();

    setState(() {
      _results = filtered;
      _isLoading = false;
      _selectedIndex = 0;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _results.length;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _results.length) % _results.length;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_results.isNotEmpty && _selectedIndex < _results.length) {
        Navigator.of(context).pop(_results[_selectedIndex].page);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final targetOffset = (_selectedIndex * DesktopUx.linkRowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(targetOffset);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        insetAnimationDuration: Motion.of(context, Motion.micro),
        insetAnimationCurve: Motion.curve,
        alignment: const Alignment(0, -0.4),
        backgroundColor: Palette.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s24,
          vertical: UiSpace.s24,
        ),
        child: MenuCard.surface(
          width: UiLayout.linkPickerWidth,
          constraints: const BoxConstraints(
            maxHeight: UiLayout.linkPickerMaxHeight,
          ),
          color: skin.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Search Field
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UiSpace.s14,
                  UiSpace.s10,
                  UiSpace.s12,
                  UiSpace.s10,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.link,
                      size: UiSpace.s16,
                      color: Palette.accent,
                    ),
                    const SizedBox(width: UiSpace.s10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onQueryChanged,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: UiType.title,
                          color: skin.text,
                        ),
                        decoration: InputDecoration(
                          hintText: context.l10n.linkToPageHint,
                          hintStyle: TextStyle(
                            fontSize: UiType.title,
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
                    CloseCross(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.4),
              ),

              // Pages List
              Flexible(
                child: _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: UiSpace.s32,
                        ),
                        child: Center(
                          child: Text(
                            _isLoading
                                ? context.l10n.loading
                                : context.l10n.noPagesFound,
                            style: TextStyle(
                              fontSize: UiType.body,
                              color: skin.muted,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s8,
                          vertical: UiSpace.s6,
                        ),
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final isSelected = index == _selectedIndex;
                          final page = item.page;
                          final title = page.title.trim().isEmpty
                              ? context.l10n.untitled
                              : page.title;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(page),
                            child: Container(
                              height: UiSpace.s36,
                              margin: const EdgeInsets.symmetric(
                                vertical: UiSpace.s1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: UiSpace.s10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Palette.accent.withValues(alpha: 0.12)
                                    : Palette.transparent,
                                borderRadius: BorderRadius.circular(
                                  UiRadius.control,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (page.icon != null &&
                                      page.icon!.isNotEmpty) ...[
                                    Text(
                                      page.icon!,
                                      style: const TextStyle(
                                        fontSize: UiType.title,
                                      ),
                                    ),
                                    const SizedBox(width: UiSpace.s8),
                                  ] else ...[
                                    Icon(
                                      AppIcons.docText,
                                      size: UiSpace.s15,
                                      color: isSelected
                                          ? Palette.accent
                                          : skin.muted,
                                    ),
                                    const SizedBox(width: UiSpace.s8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: UiType.body,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: skin.text,
                                      ),
                                    ),
                                  ),
                                  if (item.path.isNotEmpty)
                                    Text(
                                      item.path,
                                      style: TextStyle(
                                        fontSize: UiType.small,
                                        color: skin.hint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.4),
              ),

              // Footer hints
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s14,
                  vertical: UiSpace.s6,
                ),
                child: Row(
                  children: [
                    Text(
                      '↑↓ ${context.l10n.navigateShortcut}',
                      style: TextStyle(
                        fontSize: UiType.small,
                        color: skin.muted,
                      ),
                    ),
                    const SizedBox(width: UiSpace.s10),
                    Text(
                      '↵ ${context.l10n.selectShortcut}',
                      style: TextStyle(
                        fontSize: UiType.small,
                        color: skin.muted,
                      ),
                    ),
                    const SizedBox(width: UiSpace.s10),
                    Text(
                      'Esc ${context.l10n.cancelShortcut}',
                      style: TextStyle(
                        fontSize: UiType.small,
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

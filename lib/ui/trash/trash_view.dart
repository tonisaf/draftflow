import 'dart:math' as math;

import 'package:flutter/material.dart' hide Page;

import '../../data/model/trash_entry.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../common/app_dialog.dart';
import '../common/app_icons.dart';
import '../common/modern_dialog.dart';
import '../common/section_transition.dart';
import '../theme.dart';

class TrashView extends StatefulWidget {
  final NotesRepository repository;

  const TrashView({super.key, required this.repository});

  @override
  State<TrashView> createState() => _TrashViewState();
}

class _TrashViewState extends State<TrashView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: context.skin.scrim,
      builder: (ctx) {
        final skin = ctx.skin;
        return ModernDialog(
          title: ctx.l10n.emptyTrashConfirmTitle,
          icon: AppIcons.trash,
          iconColor: skin.destructive,
          maxWidth: UiLayout.trashNoticeWidth,
          content: Text(
            ctx.l10n.emptyTrashConfirmContent,
            style: TextStyle(
              fontSize: UiType.title,
              color: skin.muted,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: skin.muted,
                splashFactory: NoSplash.splashFactory,
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.cancel),
            ),
            const SizedBox(width: UiSpace.s8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: skin.destructive,
                foregroundColor: Palette.onAccent,
                splashFactory: NoSplash.splashFactory,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UiRadius.control),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.l10n.emptyTrash),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _runAction(context, widget.repository.emptyTrash);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TrashEntry>>(
      stream: widget.repository.watchTrashEntries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.l10n.trashLoadFailed,
              style: TextStyle(color: context.skin.muted),
            ),
          );
        }
        if (!snapshot.hasData) return const SizedBox.expand();
        final allEntries = snapshot.data!;

        final query = _searchQuery.trim().toLowerCase();
        final entries = query.isEmpty
            ? allEntries
            : allEntries.where((e) {
                final matchTitle = e.title.toLowerCase().contains(query);
                final matchParent =
                    e.parentTitle?.toLowerCase().contains(query) ?? false;
                return matchTitle || matchParent;
              }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final side = compact
                ? UiSpace.s8
                : math.max(
                    UiSpace.s32,
                    (constraints.maxWidth - UiLayout.trashContentWidth) / 2,
                  );

            final hasItems = entries.isNotEmpty;
            final hasSearch = _searchQuery.trim().isNotEmpty;
            final totalCount = allEntries.isEmpty
                ? 2
                : (entries.isEmpty ? 2 : entries.length * 2);

            return SectionContent(
              child: ListView.builder(
                key: const Key('trash_list'),
                padding: EdgeInsets.fromLTRB(
                  side,
                  compact ? UiSpace.s16 : UiSpace.s40,
                  side,
                  UiSpace.s40,
                ),
                itemCount: totalCount,
                itemBuilder: (context, index) {
                  // Index 0 is always the Header
                  if (index == 0) {
                    return SectionItem(
                      index: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          UiSpace.s10,
                          0,
                          UiSpace.s10,
                          UiSpace.s20,
                        ),
                        child: _TrashHeader(
                          showEmpty: allEntries.isNotEmpty,
                          onEmpty: () => _confirmEmptyTrash(context),
                          searchController: _searchController,
                          searchQuery: _searchQuery,
                          onSearchChanged: (val) {
                            setState(() => _searchQuery = val);
                          },
                          showSearch: allEntries.isNotEmpty,
                        ),
                      ),
                    );
                  }

                  // Empty state when trash has no items at all
                  if (allEntries.isEmpty) {
                    return const SectionItem(
                      index: 1,
                      child: _TrashEmptyState(),
                    );
                  }

                  // Empty search state when search returns nothing
                  if (entries.isEmpty && hasSearch) {
                    return SectionItem(
                      index: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.search,
                                size: 32.0,
                                color: context.skin.faint,
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                'Ничего не найдено',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: context.skin.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Items & subtle dividers
                  final itemIndex = (index - 1) ~/ 2;
                  final isDivider = (index - 1).isOdd;

                  if (isDivider) {
                    return Container(
                      height: 1.0,
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      color: context.skin.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                    );
                  }

                  final entry = entries[itemIndex];
                  return SectionItem(
                    key: ValueKey(('section-item', entry.key)),
                    index: itemIndex + 1,
                    child: _TrashItemTile(
                      key: ValueKey(entry.key),
                      entry: entry,
                      onRestore: () => _runAction(
                        context,
                        () => entry.isDatabase
                            ? widget.repository.restoreDatabase(entry.id)
                            : widget.repository.restorePage(entry.id),
                      ),
                      onDeletePermanently: () => _runAction(
                        context,
                        () => entry.isDatabase
                            ? widget.repository.deleteDatabasePermanently(entry.id)
                            : widget.repository.permanentlyDeletePage(entry.id),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _TrashHeader extends StatelessWidget {
  final bool showEmpty;
  final VoidCallback onEmpty;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool showSearch;

  const _TrashHeader({
    required this.showEmpty,
    required this.onEmpty,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showSearch,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // 2. Aligned Header with "Заметки" & "Входящие":
    // Removed large trash icon, added muted subtitle below title
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.trashTitle,
          key: const Key('trash_heading'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: UiType.sectionTitle,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: skin.text,
          ),
        ),
        const SizedBox(height: UiSpace.s4),
        Text(
          'Удалённые страницы и веб-клипы',
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w400,
            color: skin.isDark ? skin.muted : const Color(0xFF6B7280),
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSearch) ...[
          Container(
            width: 210.0,
            height: 36.0,
            decoration: BoxDecoration(
              color: skin.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: skin.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                Icon(
                  AppIcons.search,
                  size: 14.0,
                  color: skin.isDark ? skin.muted : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(
                      fontSize: 13.0,
                      color: skin.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск…',
                      hintStyle: TextStyle(
                        fontSize: 13.0,
                        color:
                            skin.isDark ? skin.muted : const Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14.0,
                        color: skin.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
        ],
        if (showEmpty)
          _EmptyTrashButton(
            onPressed: onEmpty,
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 540) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              if (showEmpty || showSearch) ...[
                const SizedBox(height: UiSpace.s12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleBlock),
            actions,
          ],
        );
      },
    );
  }
}

class _EmptyTrashButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _EmptyTrashButton({required this.onPressed});

  @override
  State<_EmptyTrashButton> createState() => _EmptyTrashButtonState();
}

class _EmptyTrashButtonState extends State<_EmptyTrashButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    final bg = _hover
        ? (isDark ? const Color(0x33EF4444) : const Color(0x24EF4444))
        : (isDark ? const Color(0x1FEF4444) : const Color(0x14EF4444));
    final fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const Key('trash_empty_button'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            height: 36.0,
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.trash, size: 15.0, color: fg),
                const SizedBox(width: 6.0),
                Text(
                  context.l10n.emptyTrash,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState();
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(top: 110),
      child: Column(
        children: [
          Icon(AppIcons.trash, size: UiSpace.s36, color: skin.faint),
          const SizedBox(height: UiSpace.s14),
          Text(
            context.l10n.trashEmptyState,
            style: TextStyle(fontSize: UiType.title, color: skin.muted),
          ),
          const SizedBox(height: UiSpace.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: UiLayout.trashEmptyStateWidth,
            ),
            child: Text(
              context.l10n.trashEmptyDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: UiType.body,
                height: 1.4,
                color: skin.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.trashActionFailed),
      ),
    );
  }
}

/// Deduplicates leading emoji from title if rendered as custom icon
String _cleanTrashTitle(String rawTitle, String? icon, BuildContext context) {
  String cleanTitle = rawTitle.trim();
  if (cleanTitle.isEmpty) {
    return context.l10n.untitled;
  }
  if (icon != null && icon.trim().isNotEmpty) {
    final ic = icon.trim();
    while (ic.isNotEmpty && cleanTitle.startsWith(ic)) {
      cleanTitle = cleanTitle.substring(ic.length).trimLeft();
    }
    final normIcon = ic.replaceAll(RegExp(r'[\uFE0E\uFE0F]'), '');
    if (normIcon.isNotEmpty) {
      while (cleanTitle
          .replaceAll(RegExp(r'[\uFE0E\uFE0F]'), '')
          .startsWith(normIcon)) {
        final runes = cleanTitle.runes.toList();
        final iconRunes = normIcon.runes.toSet();
        int idx = 0;
        while (idx < runes.length &&
            (iconRunes.contains(runes[idx]) ||
                runes[idx] == 0xFE0F ||
                runes[idx] == 0xFE0E ||
                runes[idx] == 0x20)) {
          idx++;
        }
        if (idx > 0) {
          cleanTitle = String.fromCharCodes(runes.sublist(idx)).trimLeft();
        } else {
          break;
        }
      }
    }
    if (cleanTitle.isEmpty) {
      cleanTitle = rawTitle.trim();
    }
  }
  return cleanTitle;
}

class _TrashItemTile extends StatefulWidget {
  const _TrashItemTile({
    super.key,
    required this.entry,
    required this.onRestore,
    required this.onDeletePermanently,
  });
  final TrashEntry entry;
  final VoidCallback onRestore;
  final VoidCallback onDeletePermanently;

  @override
  State<_TrashItemTile> createState() => _TrashItemTileState();
}

class _TrashItemTileState extends State<_TrashItemTile> {
  bool _hover = false;
  bool _hasButtonFocus = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final entry = widget.entry;
    final title = _cleanTrashTitle(entry.title, entry.icon, context);
    final parent = entry.parentTitle?.trim();

    final showActions = _hover || _hasButtonFocus;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: ValueKey('trash_row_${entry.key}'),
        constraints: const BoxConstraints(minHeight: 48.0),
        padding: EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: parent != null && parent.isNotEmpty ? 6.0 : 9.0,
        ),
        decoration: BoxDecoration(
          color: _hover
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.black.withValues(alpha: 0.035))
              : Palette.transparent,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: [
            // 1. Fixed 24x24 aligned box for icon / emoji
            SizedBox.square(
              dimension: 24.0,
              child: Center(
                child: entry.icon?.isNotEmpty == true
                    ? Text(
                        entry.icon!,
                        style: const TextStyle(
                          fontSize: 16.0,
                          height: 1.1,
                        ),
                      )
                    : Icon(
                        entry.isDatabase ? AppIcons.table : AppIcons.docText,
                        size: 16.0,
                        color: isDark ? skin.muted : const Color(0xFF9CA3AF),
                      ),
              ),
            ),
            const SizedBox(width: 12.0),

            // Title & optional parent context
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: title,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color:
                            entry.title.trim().isEmpty ? skin.muted : skin.text,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (parent != null && parent.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      parent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark ? skin.muted : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),

            // 3. Calm action buttons: hover-revealed, semantic hover
            AnimatedOpacity(
              opacity: showActions ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrashActionButton(
                    buttonKey: ValueKey('trash_restore_${entry.key}'),
                    tooltip: context.l10n.restore,
                    icon: AppIcons.arrowCounterclockwise,
                    destructive: false,
                    onFocusChanged: (focused) {
                      setState(() => _hasButtonFocus = focused);
                    },
                    onPressed: widget.onRestore,
                  ),
                  const SizedBox(width: 6.0),
                  _TrashActionButton(
                    buttonKey: ValueKey('trash_delete_${entry.key}'),
                    tooltip: context.l10n.deletePermanently,
                    icon: AppIcons.trash,
                    destructive: true,
                    onFocusChanged: (focused) {
                      setState(() => _hasButtonFocus = focused);
                    },
                    onPressed: widget.onDeletePermanently,
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

class _TrashActionButton extends StatelessWidget {
  const _TrashActionButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.onFocusChanged,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    return Focus(
      onFocusChange: onFocusChanged,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: 28.0,
          height: 28.0,
        ),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) {
              final isHovered = states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused);
              if (isHovered) {
                if (destructive) {
                  return isDark
                      ? const Color(0xFFF87171)
                      : const Color(0xFFDC2626);
                }
                return isDark
                    ? const Color(0xFFF9FAFB)
                    : const Color(0xFF111827);
              }
              return isDark ? skin.muted : const Color(0xFF9CA3AF);
            },
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) {
              final isHovered = states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused);
              if (isHovered) {
                if (destructive) {
                  return isDark
                      ? const Color(0x24EF4444)
                      : const Color(0x14EF4444);
                }
                return isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06);
              }
              return Palette.transparent;
            },
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7.0),
            ),
          ),
        ),
        icon: Icon(icon, size: 15.0),
      ),
    );
  }
}

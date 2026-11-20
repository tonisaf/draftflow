import 'package:flutter/material.dart' hide Page;

import '../common/app_icons.dart';
import '../../data/db/app_database.dart';
import '../../data/model/page_tree_node.dart';
import '../../l10n/locale_controller.dart';
import '../../platform/desktop_services.dart' show macosSidebarWidth;
import '../settings/settings_dialog.dart';
import '../theme.dart';
import 'sidebar_inbox_row.dart';
import 'sidebar_item.dart';
import 'sidebar_module_row.dart';
import 'sidebar_quick_notes_row.dart';
import 'sidebar_trash_row.dart';
import '../../modules/core/module_scope.dart';

export 'sidebar_drop_indicator.dart';
export 'sidebar_header_actions.dart';
export 'sidebar_inbox_row.dart';
export 'sidebar_item.dart';
export 'sidebar_module_row.dart';
export 'sidebar_quick_notes_row.dart';
export 'sidebar_trash_row.dart';
export 'window_nav_toolbar.dart';

typedef MovePageCallback = void Function(
  String pageId, {
  String? targetParentId,
  String? prevOrderKey,
  String? nextOrderKey,
});

class Sidebar extends StatefulWidget {
  final List<Page> pages;
  final String? selectedPageId;
  final ValueChanged<String> onSelectPage;
  final VoidCallback onNewRootPage;
  final ValueChanged<String> onNewSubpage;
  final ValueChanged<String> onTrashPage;
  final VoidCallback onOpenSearch;
  final MovePageCallback onMovePage;
  final VoidCallback? onToggleSidebar;
  final bool isSidebarVisible;
  final VoidCallback? onNavigateBack;
  final bool canNavigateBack;
  final VoidCallback? onNavigateForward;
  final bool canNavigateForward;
  final bool isShowingTrash;
  final int trashedCount;
  final VoidCallback onToggleTrash;
  final bool isShowingInbox;
  final int inboxCount;
  final VoidCallback? onToggleInbox;
  final bool isShowingQuickNotes;
  final int pinnedCount;
  final VoidCallback? onToggleQuickNotes;
  final String? selectedModuleId;
  final ValueChanged<String>? onSelectModule;
  final VoidCallback? onOpenBackup;
  final VoidCallback? onOpenSettings;
  final ValueChanged<String>? onExportPage;
  final ValueChanged<String>? onImportNotionCsv;

  const Sidebar({
    super.key,
    required this.pages,
    required this.selectedPageId,
    required this.onSelectPage,
    required this.onNewRootPage,
    required this.onNewSubpage,
    required this.onTrashPage,
    required this.onOpenSearch,
    required this.onMovePage,
    this.onToggleSidebar,
    this.isSidebarVisible = true,
    this.onNavigateBack,
    this.canNavigateBack = false,
    this.onNavigateForward,
    this.canNavigateForward = false,
    this.isShowingTrash = false,
    this.trashedCount = 0,
    required this.onToggleTrash,
    this.isShowingInbox = false,
    this.inboxCount = 0,
    this.onToggleInbox,
    this.isShowingQuickNotes = false,
    this.pinnedCount = 0,
    this.onToggleQuickNotes,
    this.selectedModuleId,
    this.onSelectModule,
    this.onOpenBackup,
    this.onOpenSettings,
    this.onExportPage,
    this.onImportNotionCsv,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final Set<String> _expandedPageIds = <String>{};

  @override
  void initState() {
    super.initState();
    _autoExpandAncestors();
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPageId != widget.selectedPageId ||
        oldWidget.pages.length != widget.pages.length) {
      _autoExpandAncestors();
    }
  }

  void _autoExpandAncestors() {
    if (widget.selectedPageId == null) return;
    String? currentId = widget.selectedPageId;
    while (currentId != null) {
      final match = widget.pages.where((p) => p.id == currentId).firstOrNull;
      if (match?.parentId != null) {
        _expandedPageIds.add(match!.parentId!);
      }
      currentId = match?.parentId;
    }
  }

  void _toggleExpand(String pageId) {
    setState(() {
      if (_expandedPageIds.contains(pageId)) {
        _expandedPageIds.remove(pageId);
      } else {
        _expandedPageIds.add(pageId);
      }
    });
  }

  bool _isDescendant(String potentialDescendantId, String ancestorId) {
    if (potentialDescendantId == ancestorId) return true;
    String? current = potentialDescendantId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      final p = widget.pages.where((page) => page.id == current).firstOrNull;
      if (p?.parentId == ancestorId) return true;
      current = p?.parentId;
    }
    return false;
  }

  List<Widget> _buildTreeRows(List<PageTreeNode> nodes) {
    final widgets = <Widget>[];

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final prevSibling = (i > 0) ? nodes[i - 1] : null;
      final nextSibling = (i < nodes.length - 1) ? nodes[i + 1] : null;
      final isExpanded = _expandedPageIds.contains(node.page.id);
      final isSelected =
          node.page.id == widget.selectedPageId &&
          !widget.isShowingTrash &&
          !widget.isShowingQuickNotes;

      final parentTitle = node.page.parentId != null
          ? widget.pages.where((p) => p.id == node.page.parentId).firstOrNull?.title
          : null;

      widgets.add(
        SidebarItem(
          key: ValueKey(node.page.id),
          node: node,
          parentTitle: parentTitle,
          prevSibling: prevSibling,
          nextSibling: nextSibling,
          isExpanded: isExpanded,
          isSelected: isSelected,
          canAcceptDrop: (draggedId) {
            if (draggedId == node.page.id) return false;
            if (_isDescendant(node.page.id, draggedId)) return false;
            return true;
          },
          onTap: () => widget.onSelectPage(node.page.id),
          onToggleExpand: () => _toggleExpand(node.page.id),
          onAddSubpage: () {
            _expandedPageIds.add(node.page.id);
            widget.onNewSubpage(node.page.id);
          },
          onDelete: () => widget.onTrashPage(node.page.id),
          onExport: widget.onExportPage != null
              ? () => widget.onExportPage!(node.page.id)
              : null,
          onImportNotionCsv: widget.onImportNotionCsv != null
              ? () => widget.onImportNotionCsv!(node.page.id)
              : null,
          onDropAbove: (draggedId) {
            widget.onMovePage(
              draggedId,
              targetParentId: node.page.parentId,
              prevOrderKey: prevSibling?.page.orderKey,
              nextOrderKey: node.page.orderKey,
            );
          },
          onDropBelow: (draggedId) {
            widget.onMovePage(
              draggedId,
              targetParentId: node.page.parentId,
              prevOrderKey: node.page.orderKey,
              nextOrderKey: nextSibling?.page.orderKey,
            );
          },
          onDropInside: (draggedId) {
            setState(() => _expandedPageIds.add(node.page.id));
            final lastChildKey = node.children.isNotEmpty
                ? node.children.last.page.orderKey
                : null;
            widget.onMovePage(
              draggedId,
              targetParentId: node.page.id,
              prevOrderKey: lastChildKey,
              nextOrderKey: null,
            );
          },
          onRequestAutoExpand: () {
            if (!_expandedPageIds.contains(node.page.id)) {
              setState(() => _expandedPageIds.add(node.page.id));
            }
          },
        ),
      );

      if (node.hasChildren && isExpanded) {
        widgets.addAll(_buildTreeRows(node.children));
      }
    }

    return widgets;
  }

  Widget _buildRootDropTarget(List<PageTreeNode> rootNodes) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final match = widget.pages
            .where((p) => p.id == details.data)
            .firstOrNull;
        return match != null && match.parentId != null;
      },
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        final lastRootKey = rootNodes.isNotEmpty
            ? rootNodes.last.page.orderKey
            : null;
        widget.onMovePage(
          draggedId,
          targetParentId: null,
          prevOrderKey: lastRootKey,
          nextOrderKey: null,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          curve: Motion.curve,
          duration: Motion.of(context, Motion.micro),
          margin: const EdgeInsets.symmetric(
            horizontal: UiSpace.s10,
            vertical: UiSpace.s4,
          ),
          height: isHovered ? 36 : 24,
          decoration: BoxDecoration(
            color: isHovered
                ? Palette.accent.withValues(alpha: 0.12)
                : Palette.transparent,
            borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
            border: isHovered
                ? Border.all(color: Palette.accent, width: UiSpace.s1_5)
                : null,
          ),
          alignment: Alignment.center,
          child: isHovered
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.arrowUp,
                        size: UiSpace.s14,
                        color: Palette.accent,
                      ),
                      const SizedBox(width: UiSpace.s6),
                      Text(
                        context.l10n.moveToRoot,
                        style: TextStyle(
                          fontSize: UiType.caption,
                          fontWeight: FontWeight.w600,
                          color: Palette.accent,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final tree = buildPageTree(widget.pages);

    return Container(
      width: macosSidebarWidth,
      color: skin.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: UiSpace.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
            child: SidebarInboxRow(
              isSelected: widget.isShowingInbox,
              unreadCount: widget.inboxCount,
              onTap: widget.onToggleInbox ?? () {},
            ),
          ),
          const SizedBox(height: UiSpace.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
            child: SidebarQuickNotesRow(
              isSelected: widget.isShowingQuickNotes,
              pinnedCount: widget.pinnedCount,
              onTap: widget.onToggleQuickNotes ?? () {},
            ),
          ),
          const SizedBox(height: UiSpace.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
            child: SidebarTrashRow(
              isSelected: widget.isShowingTrash,
              trashedCount: widget.trashedCount,
              onTap: widget.onToggleTrash,
            ),
          ),
          // Pluggable Modules (TMDB, etc.)
          ...() {
            final moduleManager = AppModuleScope.maybeOf(context);
            if (moduleManager == null || moduleManager.enabledModules.isEmpty) {
              return const <Widget>[const SizedBox(height: UiSpace.s16)];
            }
            final divider = Container(
              height: 1.0,
              margin: const EdgeInsets.symmetric(
                horizontal: UiSpace.s12,
                vertical: UiSpace.s6,
              ),
              color: skin.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            );
            return [
              const SizedBox(height: UiSpace.s2),
              divider,
              for (final mod in moduleManager.enabledModules) ...[
                const SizedBox(height: UiSpace.s4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
                  child: SidebarModuleRow(
                    module: mod,
                    isSelected: widget.selectedModuleId == mod.id,
                    onTap: () => widget.onSelectModule?.call(mod.id),
                  ),
                ),
              ],
              divider,
              const SizedBox(height: UiSpace.s8),
            ];
          }(),

          // Pages list tree
          Expanded(
            child: widget.pages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(UiSpace.s24),
                      child: Text(
                        context.l10n.noNotesYet,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: UiType.body,
                          color: skin.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: UiSpace.s4),
                    children: [
                      ..._buildTreeRows(tree),
                      _buildRootDropTarget(tree),
                    ],
                  ),
          ),

          // Sticky sidebar footer: New page & settings with hairline border
          ...() {
            final isWindows =
                Theme.of(context).platform == TargetPlatform.windows;
            final secondaryFooterColor = skin.isDark
                ? skin.muted
                : (isWindows
                    ? const Color(0xFF4B5563)
                    : const Color(0xFF6B7280));
            return [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: skin.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0x0F000000), // border-black/[0.06]
                      width: 1.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  UiSpace.s12,
                  UiSpace.s8,
                  UiSpace.s12,
                  UiSpace.s12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: widget.onNewRootPage,
                        style: TextButton.styleFrom(
                          foregroundColor: secondaryFooterColor,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiSpace.s8,
                            vertical: UiSpace.s6,
                          ),
                          minimumSize: const Size(0, DesktopUx.sidebarSearchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(UiRadius.small),
                          ),
                        ),
                        icon: Icon(
                          AppIcons.plus,
                          size: DesktopUx.sidebarIconSize,
                          color: secondaryFooterColor,
                        ),
                        label: Text(
                          context.l10n.newPage,
                          style: TextStyle(
                            fontSize: UiType.title,
                            fontWeight: FontWeight.w500,
                            color: secondaryFooterColor,
                          ),
                        ),
                      ),
                    ),
                    _SidebarSettingsButton(
                      tooltip: context.l10n.settings,
                      onTap: widget.onOpenSettings ??
                          () => showSettings(
                                context,
                                onOpenBackup: widget.onOpenBackup,
                              ),
                    ),
                  ],
                ),
              ),
            ];
          }(),
        ],
      ),
    );
  }
}

class _SidebarSettingsButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _SidebarSettingsButton({
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_SidebarSettingsButton> createState() => _SidebarSettingsButtonState();
}

class _SidebarSettingsButtonState extends State<_SidebarSettingsButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;

    final Color iconColor = _hovered
        ? (isDark ? skin.text : const Color(0xFF111827))
        : (isDark
            ? skin.muted
            : (isWindows ? const Color(0xFF4B5563) : const Color(0xFF6B7280)));

    final Color bgColor = _hovered
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x0D000000)) // bg-black/[0.05]
        : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28.0, // w-7
              height: 28.0, // h-7
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8.0), // rounded-lg
              ),
              child: Center(
                child: Icon(
                  Icons.settings_outlined,
                  size: 17.5,
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

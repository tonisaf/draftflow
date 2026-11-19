import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/app_dialog.dart';
import 'package:notes_here/ui/common/app_icons.dart';
import 'package:notes_here/ui/common/menu.dart';
import 'package:notes_here/ui/common/modern_dialog.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/theme.dart';
import 'database_models.dart';
import 'database_views.dart';

class DatabaseViewTabs extends StatelessWidget {
  final List<DatabaseViewConfig> views;
  final String activeViewId;
  final List<DatabaseColumn> columns;
  final ValueChanged<DatabaseViewConfig> onSelectView;
  final ValueChanged<DatabaseViewType> onAddView;
  final void Function(DatabaseViewConfig view, String newName) onRenameView;
  final ValueChanged<DatabaseViewConfig> onDuplicateView;
  final ValueChanged<DatabaseViewConfig> onDeleteView;
  final void Function(DatabaseViewConfig view, List<String> visibleCols)
      onUpdateColumnVisibility;

  const DatabaseViewTabs({
    super.key,
    required this.views,
    required this.activeViewId,
    required this.columns,
    required this.onSelectView,
    required this.onAddView,
    required this.onRenameView,
    required this.onDuplicateView,
    required this.onDeleteView,
    required this.onUpdateColumnVisibility,
  });

  void _showAddViewMenu(BuildContext context, BuildContext anchorContext) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    showPopover(
      context,
      anchor: anchor,
      width: 180,
      builder: (popCtx, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuSectionHeader(title: context.l10n.addView),
          MenuRow(
            label: context.l10n.viewTypeTable,
            glyph: AppIcons.table,
            onTap: () {
              close();
              onAddView(DatabaseViewType.table);
            },
          ),
          MenuRow(
            label: context.l10n.viewTypeBoard,
            glyph: AppIcons.rectangleSplit3x1,
            onTap: () {
              close();
              onAddView(DatabaseViewType.board);
            },
          ),
          MenuRow(
            label: context.l10n.viewTypeGallery,
            glyph: AppIcons.squareGrid2x2,
            onTap: () {
              close();
              onAddView(DatabaseViewType.gallery);
            },
          ),
          MenuRow(
            label: context.l10n.viewTypeList,
            glyph: AppIcons.listBullet,
            onTap: () {
              close();
              onAddView(DatabaseViewType.list);
            },
          ),
        ],
      ),
    );
  }

  void _showTabMenu(
    BuildContext context,
    BuildContext anchorContext,
    DatabaseViewConfig view,
  ) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    showPopover(
      context,
      anchor: anchor,
      width: 220,
      builder: (popCtx, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuRow(
            label: context.l10n.renameView,
            glyph: AppIcons.pencil,
            onTap: () {
              close();
              _showRenameDialog(context, view);
            },
          ),
          MenuRow(
            label: context.l10n.duplicateView,
            glyph: AppIcons.plus,
            onTap: () {
              close();
              onDuplicateView(view);
            },
          ),
          MenuRow(
            label: context.l10n.propertiesVisibility,
            glyph: AppIcons.eye,
            onTap: () {
              close();
              _showPropertiesVisibilityDialog(context, view);
            },
          ),
          if (views.length > 1) ...[
            const MenuDivider(),
            MenuRow(
              label: context.l10n.deleteView,
              glyph: AppIcons.trash,
              destructive: true,
              onTap: () {
                close();
                onDeleteView(view);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, DatabaseViewConfig view) {
    final controller = TextEditingController(text: view.name);
    final skin = context.skin;

    showAppDialog(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: skin.scrim,
      barrierDismissible: true,
      builder: (dlgCtx) => ModernDialog(
        title: context.l10n.renameView,
        icon: AppIcons.pencil,
        maxWidth: 360,
        content: Padding(
          padding: const EdgeInsets.only(top: UiSpace.s8),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: UiType.body),
            decoration: modernInputDecoration(
              skin: skin,
              hintText: view.name,
            ),
            onSubmitted: (val) {
              final trimmed = val.trim();
              if (trimmed.isNotEmpty) {
                onRenameView(view, trimmed);
              }
              Navigator.of(dlgCtx).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                onRenameView(view, trimmed);
              }
              Navigator.of(dlgCtx).pop();
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }

  void _showPropertiesVisibilityDialog(
    BuildContext context,
    DatabaseViewConfig view,
  ) {
    final skin = context.skin;
    // Current visible set: if empty, all columns are visible
    final currentVisible = view.visibleColumnIds.isEmpty
        ? columns.map((c) => c.id).toSet()
        : view.visibleColumnIds.toSet();

    showAppDialog(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: skin.scrim,
      barrierDismissible: true,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return ModernDialog(
              title: context.l10n.propertiesVisibility,
              icon: AppIcons.eye,
              maxWidth: 380,
              content: SizedBox(
                height: (columns.length * 42.0).clamp(100.0, 360.0),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: columns.length,
                  itemBuilder: (ctx, i) {
                    final col = columns[i];
                    final isTitle = col.type == 'title';
                    final isVisible = currentVisible.contains(col.id);

                    return InkWell(
                      borderRadius: BorderRadius.circular(UiRadius.control),
                      onTap: isTitle
                          ? null
                          : () {
                              setDlgState(() {
                                if (isVisible) {
                                  currentVisible.remove(col.id);
                                } else {
                                  currentVisible.add(col.id);
                                }
                              });
                              onUpdateColumnVisibility(
                                view,
                                currentVisible.toList(),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s8,
                          vertical: UiSpace.s6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iconForColumnType(col.type),
                              size: UiSpace.s16,
                              color: isVisible ? skin.text : skin.muted,
                            ),
                            const SizedBox(width: UiSpace.s10),
                            Expanded(
                              child: Text(
                                col.name,
                                style: TextStyle(
                                  fontSize: UiType.body,
                                  color: isVisible ? skin.text : skin.muted,
                                  fontWeight: isVisible
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isTitle)
                              Icon(
                                AppIcons.lock,
                                size: UiSpace.s14,
                                color: skin.muted,
                              )
                            else
                              Icon(
                                isVisible
                                    ? AppIcons.checkmarkSquare
                                    : AppIcons.square,
                                size: UiSpace.s16,
                                color: isVisible
                                    ? Palette.accent
                                    : skin.muted,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                  child: Text(context.l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            )
          : const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final view in views) ...[
            Builder(
              builder: (tabCtx) {
                final isActive = view.id == activeViewId;
                return Padding(
                  padding: const EdgeInsets.only(right: UiSpace.s4),
                  child: Material(
                    color: isActive
                        ? skin.tableControlActive
                        : Palette.transparent,
                    borderRadius: BorderRadius.circular(UiRadius.control),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(UiRadius.control),
                      onTap: () => onSelectView(view),
                      onSecondaryTapDown: (details) =>
                          _showTabMenu(context, tabCtx, view),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s8,
                          vertical: UiSpace.s4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              view.type.icon,
                              size: UiSpace.s14,
                              color: isActive
                                  ? (skin.isDark
                                      ? skin.accentText
                                      : Palette.accent)
                                  : skin.muted,
                            ),
                            const SizedBox(width: UiSpace.s6),
                            Text(
                              view.name,
                              style: TextStyle(
                                fontSize: UiType.body,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isActive ? skin.text : skin.muted,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: UiSpace.s2),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showTabMenu(context, tabCtx, view),
                                child: Padding(
                                  padding: const EdgeInsets.all(UiSpace.s2),
                                  child: Icon(
                                    AppIcons.ellipsis,
                                    size: UiSpace.s12,
                                    color: skin.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          // Add View '+' button
          Builder(
            builder: (addCtx) => Tooltip(
              message: context.l10n.addView,
              child: InkWell(
                borderRadius: BorderRadius.circular(UiRadius.control),
                onTap: () => _showAddViewMenu(context, addCtx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UiSpace.s6,
                    vertical: UiSpace.s4,
                  ),
                  child: Icon(
                    AppIcons.plus,
                    size: UiSpace.s14,
                    color: skin.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

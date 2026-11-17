import '../common/app_dialog.dart';

import 'dart:math' as math;

import '../common/app_icons.dart';

import 'package:flutter/material.dart' hide Page;

import '../../data/model/trash_entry.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../common/modern_dialog.dart';
import '../common/section_transition.dart';
import '../theme.dart';

class TrashView extends StatelessWidget {
  final NotesRepository repository;

  const TrashView({super.key, required this.repository});

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

    if (confirmed == true) {
      if (context.mounted) await _runAction(context, repository.emptyTrash);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TrashEntry>>(
    stream: repository.watchTrashEntries(),
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
      final entries = snapshot.data!;
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final side = compact
              ? UiSpace.s8
              : math.max(
                  UiSpace.s32,
                  (constraints.maxWidth - UiLayout.trashContentWidth) / 2,
                );
          return SectionContent(
            child: ListView.builder(
              key: const Key('trash_list'),
              padding: EdgeInsets.fromLTRB(
                side,
                compact ? UiSpace.s16 : UiSpace.s40,
                side,
                UiSpace.s40,
              ),
              itemCount: entries.isEmpty ? 2 : entries.length + 1,
              itemBuilder: (context, index) {
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
                        showEmpty: entries.isNotEmpty,
                        onEmpty: () => _confirmEmptyTrash(context),
                      ),
                    ),
                  );
                }
                if (entries.isEmpty) {
                  return const SectionItem(
                    index: 1,
                    child: _TrashEmptyState(),
                  );
                }
                final entry = entries[index - 1];
                return SectionItem(
                  key: ValueKey(('section-item', entry.key)),
                  index: index,
                  child: _TrashItemTile(
                    key: ValueKey(entry.key),
                    entry: entry,
                    onRestore: () => _runAction(
                      context,
                      () => entry.isDatabase
                          ? repository.restoreDatabase(entry.id)
                          : repository.restorePage(entry.id),
                    ),
                    onDeletePermanently: () => _runAction(
                      context,
                      () => entry.isDatabase
                          ? repository.deleteDatabasePermanently(entry.id)
                          : repository.permanentlyDeletePage(entry.id),
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

class _TrashHeader extends StatelessWidget {
  const _TrashHeader({required this.showEmpty, required this.onEmpty});
  final bool showEmpty;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final title = Row(
      children: [
        SizedBox.square(
          dimension: UiSpace.s30,
          child: Icon(AppIcons.trash, size: UiSpace.s28, color: skin.muted),
        ),
        const SizedBox(width: UiSpace.s12),
        Expanded(
          child: Text(
            context.l10n.trashTitle,
            key: const Key('trash_heading'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: UiType.sectionTitle,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
        ),
      ],
    );
    final empty = TextButton.icon(
      key: const Key('trash_empty_button'),
      onPressed: onEmpty,
      style: TextButton.styleFrom(
        foregroundColor: skin.destructive,
        backgroundColor: skin.destructive.withValues(alpha: 0.12),
        padding: const EdgeInsets.fromLTRB(
          UiSpace.s12,
          UiSpace.s8,
          UiSpace.s16,
          UiSpace.s8,
        ),
        minimumSize: const Size(0, UiSpace.s40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge!
            .copyWith(fontSize: UiType.title, fontWeight: FontWeight.w500),
      ),
      icon: const Icon(AppIcons.trash, size: UiSpace.s16),
      label: Text(context.l10n.emptyTrash),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(26) > 36) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              if (showEmpty) ...[
                const SizedBox(height: UiSpace.s12),
                Align(alignment: Alignment.centerRight, child: empty),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            if (showEmpty) empty,
          ],
        );
      },
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
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final entry = widget.entry;
    final title = entry.title.trim().isEmpty
        ? context.l10n.untitled
        : entry.title;
    final parent = entry.parentTitle?.trim();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: ValueKey('trash_row_${entry.key}'),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s10,
          vertical: UiSpace.s4,
        ),
        decoration: BoxDecoration(
          color: _hover
              ? skin.hover.withValues(alpha: 0.5)
              : Palette.transparent,
          borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: UiSpace.s22,
              child: Center(
                child: entry.icon?.isNotEmpty == true
                    ? Text(
                        entry.icon!,
                        style: const TextStyle(fontSize: UiType.editorTitle),
                      )
                    : Icon(
                        entry.isDatabase ? AppIcons.table : AppIcons.docText,
                        size: UiSpace.s16,
                        color: skin.muted,
                      ),
              ),
            ),
            const SizedBox(width: UiSpace.s12),
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
                        fontSize: UiType.listItem,
                        fontWeight: FontWeight.w400,
                        color: entry.title.trim().isEmpty
                            ? skin.muted
                            : skin.text,
                      ),
                    ),
                  ),
                  if (parent != null && parent.isNotEmpty)
                    Text(
                      parent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.caption,
                        color: skin.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: UiSpace.s8),
            _TrashActionButton(
              buttonKey: ValueKey('trash_restore_${entry.key}'),
              tooltip: context.l10n.restore,
              icon: AppIcons.arrowCounterclockwise,
              onPressed: widget.onRestore,
            ),
            const SizedBox(width: UiSpace.s8),
            _TrashActionButton(
              buttonKey: ValueKey('trash_delete_${entry.key}'),
              tooltip: context.l10n.deletePermanently,
              icon: AppIcons.trash,
              destructive: true,
              onPressed: widget.onDeletePermanently,
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
  });
  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: UiSpace.s32,
        height: UiSpace.s32,
      ),
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? (destructive ? skin.destructive : skin.text)
              : (destructive ? skin.destructive : skin.muted),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? (destructive
                    ? skin.destructive.withValues(alpha: 0.12)
                    : skin.hover)
              : Palette.transparent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiRadius.small),
          ),
        ),
      ),
      icon: Icon(icon, size: UiSpace.s16),
    );
  }
}

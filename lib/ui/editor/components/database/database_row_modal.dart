import '../../../common/menu.dart';
import '../../../common/quiet_button.dart';
import '../../../../services/database_cell_saves.dart';
import 'database_save_status.dart';
import '../../../common/app_icons.dart';

import 'dart:convert';

import 'package:flutter/material.dart' hide Page, DataCell;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_cells.dart';
import 'database_models.dart';

// ----------------------------------------------------------------------------
// Database Row Detail Modal (Center Peek)
// ----------------------------------------------------------------------------

class DatabaseRowModal extends StatelessWidget {
  final NotesRepository repository;
  final String databaseId;
  final Page page;
  final List<DatabaseColumn> columns;
  final ValueChanged<String>? onNavigateToPage;

  const DatabaseRowModal({
    super.key,
    required this.repository,
    required this.databaseId,
    required this.page,
    required this.columns,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < DesktopUx.rowModalBreakpoint;
    final dialogWidth = isNarrow ? size.width * 0.95 : DesktopUx.rowModalWidth;
    final dialogHeight = isNarrow
        ? size.height * 0.95
        : (size.height * 0.85).clamp(
            DesktopUx.rowModalMinHeight,
            DesktopUx.rowModalMaxHeight,
          );
    final skin = context.skin;

    return Dialog(
      insetAnimationDuration: Motion.of(context, Motion.micro),
      insetAnimationCurve: Motion.curve,
      backgroundColor: Palette.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? UiSpace.s10 : UiSpace.s40,
        vertical: isNarrow ? UiSpace.s10 : UiSpace.s30,
      ),
      child: MenuCard.surface(
        width: dialogWidth,
        height: dialogHeight,
        color: skin.surface,
        clipBehavior: Clip.antiAlias,
        child: PageEditorView(
          repository: repository,
          pageId: page.id,
          title: page.title,
          initialIcon: page.icon,
          initialCover: page.cover,
          compactHeader: true,
          onNavigateToPage: (targetId) {
            Navigator.of(context).pop();
            onNavigateToPage?.call(targetId);
          },
          frameBuilder: (context, body, actions) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar with database title, Open full page button, and Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UiSpace.s16,
                  UiSpace.s10,
                  UiSpace.s12,
                  UiSpace.s10,
                ),
                child: LayoutBuilder(
                  builder: (context, barConstraints) => Row(
                    children: [
                      Icon(
                        AppIcons.table,
                        size: UiSpace.s15,
                        color: skin.muted,
                      ),
                      const SizedBox(width: UiSpace.s8),
                      Expanded(
                        child: StreamBuilder<Database?>(
                          stream: repository.watchDatabase(databaseId),
                          builder: (context, snap) {
                            final title = snap.data?.title ?? 'Database';
                            return Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: UiType.caption,
                                fontWeight: FontWeight.w500,
                                color: skin.muted,
                              ),
                            );
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: barConstraints.maxWidth * 0.35,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: actions,
                        ),
                      ),
                      const SizedBox(width: UiSpace.s8),
                      // 'Open full page' button
                      Tooltip(
                        message: context.l10n.rowOpenFullPage,
                        child: TextButton.icon(
                          key: const ValueKey('row_peek_open_full'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onNavigateToPage?.call(page.id);
                          },
                          icon: const Icon(
                            AppIcons.arrowUpLeftArrowDownRight,
                            size: UiSpace.s14,
                          ),
                          label:
                              barConstraints.maxWidth <
                                  UiLayout.rowPeekIconOnlyWidth
                              ? const SizedBox.shrink()
                              : Text(
                                  barConstraints.maxWidth <
                                          DesktopUx.rowPeekCompactHeaderWidth
                                      ? context.l10n.openShortcut
                                      : context.l10n.rowOpenFullPage,
                                  style: const TextStyle(
                                    fontSize: UiType.caption,
                                  ),
                                ),
                          style: TextButton.styleFrom(
                            foregroundColor: skin.accentText,
                            backgroundColor: skin.tablePrimaryTint,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                UiRadius.small,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: UiSpace.s10,
                              vertical: UiSpace.s6,
                            ),
                            minimumSize: const Size(0, UiSpace.s28),
                            visualDensity: VisualDensity.standard,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: UiSpace.s6),
                      CloseCross(
                        key: const ValueKey('row_peek_close'),
                        tooltip: context.l10n.close,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: UiSpace.s1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.5),
              ),

              // Properties Inspector Section
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: dialogHeight * 0.35),
                child: SingleChildScrollView(
                  child: ModalPropertiesSection(
                    repository: repository,
                    pageId: page.id,
                    columns: columns,
                  ),
                ),
              ),
              Divider(
                height: UiSpace.s1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.5),
              ),

              // Embedded PageEditorView for the full page document
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(DesktopUx.menuRadius),
                  ),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Modal Properties Inspector
// ----------------------------------------------------------------------------

class ModalPropertiesSection extends StatelessWidget {
  final NotesRepository repository;
  final String pageId;
  final List<DatabaseColumn> columns;

  const ModalPropertiesSection({
    super.key,
    required this.repository,
    required this.pageId,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final nonTitleCols = columns.where((c) => c.type != 'title').toList();

    if (nonTitleCols.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Page?>(
      stream: repository.watchPage(pageId),
      builder: (context, snap) {
        final page = snap.data;
        if (page == null) return const SizedBox.shrink();

        Map<String, dynamic> properties = {};
        if (page.properties != null && page.properties!.isNotEmpty) {
          try {
            properties = jsonDecode(page.properties!) as Map<String, dynamic>;
          } catch (_) {}
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpace.s40,
            vertical: UiSpace.s12,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelWidth = UiLayout.rowPropertyLabelWidth.clamp(
                0.0,
                constraints.maxWidth * 0.45,
              );
              return Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: FixedColumnWidth(labelWidth),
                  1: const FlexColumnWidth(),
                },
                children: [
                  for (final col in nonTitleCols)
                    TableRow(
                      children: [
                        SizedBox(
                          height: DesktopUx.databaseRowHeight,
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: UiSpace.s16,
                                child: Icon(
                                  iconForColumnType(col.type),
                                  size: UiSpace.s16,
                                  color: skin.muted,
                                ),
                              ),
                              const SizedBox(width: UiSpace.s10),
                              Expanded(
                                child: Tooltip(
                                  message: col.name,
                                  child: Text(
                                    col.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: UiType.body,
                                      color: skin.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: UiSpace.s16),
                          child: LayoutBuilder(
                            builder: (context, valueConstraints) => DataCell(
                              saves: DatabaseCellSaves.forRepository(
                                repository,
                              ),
                              rowId: page.id,
                              key: ValueKey('row_property_${col.id}'),
                              column: col,
                              width: valueConstraints.maxWidth,
                              contentPadding: EdgeInsets.zero,
                              borderColor: Palette.transparent,
                              pageTitle: page.title,
                              cellValue: properties[col.id],
                              repository: repository,
                              onUpdateTitle: (title) =>
                                  repository.updateRowTitle(page.id, title),
                              onUpdateValue: (value) =>
                                  patchRowPropertiesFromCell(
                                    context,
                                    repository,
                                    page.id,
                                    {col.id: value},
                                  ),
                              onOpenPage: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (page.databaseId != null)
                    TableRow(
                      children: [
                        const SizedBox.shrink(),
                        DatabaseSaveStatus(
                          saves: DatabaseCellSaves.forRepository(repository),
                          databaseId: page.databaseId!,
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

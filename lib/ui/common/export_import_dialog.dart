import 'package:flutter/material.dart' hide Page;

import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../../services/export_import_service.dart';
import '../theme.dart';
import 'app_dialog.dart';
import 'app_icons.dart';
import 'export_import/export_import_shared.dart';
import 'export_import/markdown_import_tab.dart';
import 'export_import/notion_csv_tab.dart';
import 'export_import/page_export_tab.dart';
import 'export_import/workspace_backup_tab.dart';
import 'menu.dart';
import 'quiet_button.dart';

export 'export_import/export_import_shared.dart' show ExportImportMode;

Future<void> showExportImportDialog(
  BuildContext context, {
  required NotesRepository repository,
  String? currentPageId,
  String? currentPageTitle,
  ExportImportMode initialMode = ExportImportMode.page,
  ValueChanged<String>? onNavigateToPage,
}) {
  return showAppDialog<void>(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (ctx) => _ExportImportModal(
      repository: repository,
      currentPageId: currentPageId,
      currentPageTitle: currentPageTitle,
      initialMode: initialMode,
      onNavigateToPage: onNavigateToPage,
    ),
  );
}

class _ExportImportModal extends StatefulWidget {
  final NotesRepository repository;
  final String? currentPageId;
  final String? currentPageTitle;
  final ExportImportMode initialMode;
  final ValueChanged<String>? onNavigateToPage;

  const _ExportImportModal({
    required this.repository,
    this.currentPageId,
    this.currentPageTitle,
    required this.initialMode,
    this.onNavigateToPage,
  });

  @override
  State<_ExportImportModal> createState() => _ExportImportModalState();
}

class _ExportImportModalState extends State<_ExportImportModal> {
  late final ExportImportService _service = ExportImportService(
    repository: widget.repository,
  );

  late int _selectedTab; // 0: Export, 1: Import, 2: Notion CSV, 3: Workspace Backup

  @override
  void initState() {
    super.initState();
    switch (widget.initialMode) {
      case ExportImportMode.page:
        _selectedTab = 0;
        break;
      case ExportImportMode.markdownImport:
        _selectedTab = 1;
        break;
      case ExportImportMode.notionCsv:
        _selectedTab = 2;
        break;
      case ExportImportMode.workspace:
        _selectedTab = 3;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Dialog(
      insetAnimationDuration: Motion.of(context, Motion.micro),
      insetAnimationCurve: Motion.curve,
      alignment: const Alignment(0, -0.3),
      backgroundColor: Palette.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s24,
        vertical: UiSpace.s24,
      ),
      child: MenuCard.surface(
        width: UiLayout.transferDialogWidth,
        constraints: const BoxConstraints(
          maxHeight: UiLayout.transferDialogMaxHeight,
        ),
        color: skin.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Tabs & Close
            Container(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.s16,
                UiSpace.s12,
                UiSpace.s12,
                UiSpace.s12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: skin.hairlineBorder,
                    width: UiSpace.s1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExportImportTabButton(
                            label: context.l10n.tabExportMd,
                            icon: AppIcons.squareArrowUp,
                            isSelected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          ExportImportTabButton(
                            label: context.l10n.tabImportMd,
                            icon: AppIcons.arrowDownToLine,
                            isSelected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          ExportImportTabButton(
                            label: context.l10n.tabNotionCsv,
                            icon: AppIcons.table,
                            isSelected: _selectedTab == 2,
                            onTap: () => setState(() => _selectedTab = 2),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          ExportImportTabButton(
                            label: context.l10n.tabBackupJson,
                            icon: AppIcons.archivebox,
                            isSelected: _selectedTab == 3,
                            onTap: () => setState(() => _selectedTab = 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: UiSpace.s8),
                  CloseCross(
                    tooltip: context.l10n.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: MediaQuery.disableAnimationsOf(context)
                  ? _tabContent()
                  : AnimatedSwitcher(
                      duration: Motion.of(context, Motion.micro),
                      switchInCurve: Motion.curve,
                      switchOutCurve: Motion.curve,
                      child: _tabContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabContent() => switch (_selectedTab) {
    0 => PageExportTab(
        service: _service,
        currentPageId: widget.currentPageId,
        currentPageTitle: widget.currentPageTitle,
      ),
    1 => MarkdownImportTab(
        service: _service,
        onNavigateToPage: widget.onNavigateToPage,
        onClose: () => Navigator.of(context).pop(),
      ),
    2 => NotionCsvTab(
        service: _service,
        currentPageId: widget.currentPageId,
        onNavigateToPage: widget.onNavigateToPage,
        onClose: () => Navigator.of(context).pop(),
      ),
    _ => WorkspaceBackupTab(
        service: _service,
      ),
  };
}

import 'app_dialog.dart';
import 'app_icons.dart';

import 'dart:io';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../../platform/desktop_services.dart';
import '../../services/export_import_service.dart';
import '../editor/components/database/database_models.dart';
import '../theme.dart';
import 'menu.dart';
import 'popover.dart';
import 'quiet_button.dart';
import 'status_pill.dart';

ShapeDecoration _panelDecoration(
  Skin skin, {
  double radius = UiRadius.dialog,
}) => ShapeDecoration(
  color: skin.card,
  shape: UiRadius.squircle(
    radius,
    side: BorderSide(color: skin.hairlineBorder),
  ),
);

InputDecoration _dialogInputDecoration(
  Skin skin, {
  required String hintText,
  bool isTextArea = false,
}) {
  final radius = isTextArea ? UiRadius.dialog : UiRadius.pill;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(fontSize: UiType.caption, color: skin.hint),
    alignLabelWithHint: isTextArea,
    isDense: !isTextArea,
    filled: true,
    fillColor: isTextArea ? skin.card : skin.hover,
    contentPadding: isTextArea
        ? const EdgeInsets.all(UiSpace.s12)
        : const EdgeInsets.symmetric(
            horizontal: UiSpace.s12,
            vertical: UiSpace.s8,
          ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: skin.hairlineBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: Palette.accent),
    ),
  );
}

enum ExportImportMode { page, markdownImport, notionCsv, workspace }

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

  late int _selectedTab; // 0: Export, 1: Import, 2: Workspace Backup

  // Export state
  String _exportedMarkdown = '';
  bool _isLoadingExport = false;
  bool _isCopied = false;
  String? _savedFilePath;

  // Import state
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _filePathController = TextEditingController();
  bool _isImporting = false;
  String? _importError;

  // Workspace state
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _wipeExisting = false;
  final TextEditingController _restoreJsonController = TextEditingController();
  String? _workspaceStatusMessage;

  // Notion / CSV state
  final TextEditingController _csvController = TextEditingController();
  final TextEditingController _csvFilePathController = TextEditingController();
  final TextEditingController _csvTitleController = TextEditingController();
  ParsedCsvDatabase? _parsedCsv;
  bool _isImportingCsv = false;
  String? _csvError;
  bool _showTablePreview = true;
  final ScrollController _tableHorizController = ScrollController();
  final ScrollController _tableVertController = ScrollController();

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
    if (widget.currentPageId != null) {
      _loadPageExport();
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    _filePathController.dispose();
    _restoreJsonController.dispose();
    _csvController.dispose();
    _csvFilePathController.dispose();
    _csvTitleController.dispose();
    _tableHorizController.dispose();
    _tableVertController.dispose();
    super.dispose();
  }

  Future<void> _loadPageExport() async {
    if (widget.currentPageId == null) return;
    setState(() => _isLoadingExport = true);
    try {
      final md = await _service.exportPageToMarkdown(widget.currentPageId!);
      if (mounted) {
        setState(() {
          _exportedMarkdown = md;
          _isLoadingExport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportedMarkdown = 'Error generating markdown: $e';
          _isLoadingExport = false;
        });
      }
    }
  }

  Future<void> _copyMarkdownToClipboard() async {
    if (_exportedMarkdown.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _exportedMarkdown));
    if (mounted) {
      setState(() => _isCopied = true);
      Future.delayed(Motion.exportCopiedFeedback, () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  Future<void> _saveMarkdownToFile() async {
    if (_exportedMarkdown.isEmpty) return;
    final pageTitle = widget.currentPageTitle?.trim().isNotEmpty == true
        ? widget.currentPageTitle!.trim()
        : 'untitled';
    final filename =
        '${pageTitle.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}.md';

    try {
      final file = await ExportImportService.saveExportToFile(
        _exportedMarkdown,
        filename,
      );
      if (mounted) {
        setState(() => _savedFilePath = file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savedFilePath = 'Error saving file: $e');
      }
    }
  }

  Future<void> _handleImportMarkdown() async {
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      setState(() => _importError = 'Please paste markdown content to import');
      return;
    }

    setState(() {
      _isImporting = true;
      _importError = null;
    });

    try {
      final newPageId = await _service.importMarkdownAsNewPage(
        raw,
        fallbackTitle: 'Imported Markdown Note',
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onNavigateToPage?.call(newPageId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importError = 'Import error: $e';
        });
      }
    }
  }

  Future<void> _handleLoadFileForImport() async {
    final path = _filePathController.text.trim();
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _importController.text = content;
        setState(() => _importError = null);
      } else {
        setState(() => _importError = 'File does not exist: $path');
      }
    } catch (e) {
      setState(() => _importError = 'Could not read file: $e');
    }
  }

  void _parseCsvInput([String? customFilename]) {
    final raw = _csvController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _parsedCsv = null;
        _csvError = null;
      });
      return;
    }

    try {
      final parsed = _service.parseNotionCsv(
        raw,
        filename:
            customFilename ??
            (_csvTitleController.text.isNotEmpty
                ? _csvTitleController.text
                : null),
      );
      setState(() {
        _parsedCsv = parsed;
        _csvTitleController.text = parsed.title;
        _csvError = null;
        _showTablePreview = true;
      });
    } catch (e) {
      setState(() {
        _parsedCsv = null;
        _csvError = 'CSV parse error: $e';
      });
    }
  }

  void _showColumnTypeMenu(BuildContext chipContext, int colIndex) {
    if (_parsedCsv == null || colIndex >= _parsedCsv!.columns.length) return;
    final box = chipContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    final currentCol = _parsedCsv!.columns[colIndex];

    final types = const [
      ('title', 'Title (Primary)', AppIcons.textformat),
      ('text', 'Text', AppIcons.textAlignleft),
      ('number', 'Number', AppIcons.number),
      ('select', 'Select (Tags)', AppIcons.tag),
      ('multi_select', 'Multi-select', AppIcons.tag),
      ('status', 'Status', AppIcons.circleLefthalfFill),
      ('date', 'Date', AppIcons.calendar),
      ('checkbox', 'Checkbox', AppIcons.checkmarkSquare),
      ('url', 'URL Link', AppIcons.link),
    ];

    showPopover(
      chipContext,
      anchor: anchor,
      width: UiLayout.exportMenuWidth,
      builder: (popContext, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuSectionHeader(title: 'Column: ${currentCol.name}'),
          for (final (typeKey, typeLabel, typeIcon) in types)
            MenuRow(
              label: typeLabel,
              icon: Icon(typeIcon, size: UiSpace.s14),
              selected: currentCol.type == typeKey,
              onTap: () {
                close();
                _changeColumnType(colIndex, typeKey);
              },
            ),
        ],
      ),
    );
  }

  void _changeColumnType(int colIndex, String newType) {
    if (_parsedCsv == null || colIndex >= _parsedCsv!.columns.length) return;
    final columns = List<NotionCsvColumnInfo>.from(_parsedCsv!.columns);
    int newTitleIndex = _parsedCsv!.titleColumnIndex;

    if (newType == 'title') {
      for (var i = 0; i < columns.length; i++) {
        if (columns[i].type == 'title') {
          columns[i] = columns[i].copyWith(type: 'text');
        }
      }
      columns[colIndex] = columns[colIndex].copyWith(type: 'title');
      newTitleIndex = colIndex;
    } else {
      if (colIndex == newTitleIndex) {
        int fallbackTitleIndex = 0;
        if (colIndex == 0 && columns.length > 1) {
          fallbackTitleIndex = 1;
        }
        columns[fallbackTitleIndex] = columns[fallbackTitleIndex].copyWith(
          type: 'title',
        );
        newTitleIndex = fallbackTitleIndex;
      }
      columns[colIndex] = columns[colIndex].copyWith(type: newType);
    }

    setState(() {
      _parsedCsv = _parsedCsv!.copyWith(
        columns: columns,
        titleColumnIndex: newTitleIndex,
      );
    });
  }

  Future<void> _handleLoadCsvFile() async {
    final path = _csvFilePathController.text.trim();
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _csvController.text = content;
        _parseCsvInput(file.path);
      } else {
        setState(() => _csvError = 'File does not exist: $path');
      }
    } catch (e) {
      setState(() => _csvError = 'Could not read file: $e');
    }
  }

  Future<void> _handleImportCsvAsNewPage() async {
    if (_parsedCsv == null) {
      final raw = _csvController.text.trim();
      if (raw.isEmpty) {
        setState(() => _csvError = 'Please provide CSV content to import');
        return;
      }
      _parseCsvInput();
      if (_parsedCsv == null) return;
    }

    setState(() {
      _isImportingCsv = true;
      _csvError = null;
    });

    try {
      final title = _csvTitleController.text.trim();
      final toImport = title.isNotEmpty
          ? _parsedCsv!.copyWith(title: title)
          : _parsedCsv!;
      final newPageId = await _service.importParsedCsvDatabaseAsPage(
        toImport,
        parentPageId: widget.currentPageId,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onNavigateToPage?.call(newPageId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImportingCsv = false;
          _csvError = 'Import error: $e';
        });
      }
    }
  }

  Future<void> _handleInsertCsvIntoCurrentPage() async {
    if (widget.currentPageId == null) return;
    if (_parsedCsv == null) {
      final raw = _csvController.text.trim();
      if (raw.isEmpty) {
        setState(() => _csvError = 'Please provide CSV content to import');
        return;
      }
      _parseCsvInput();
      if (_parsedCsv == null) return;
    }

    setState(() {
      _isImportingCsv = true;
      _csvError = null;
    });

    try {
      final title = _csvTitleController.text.trim();
      final toImport = title.isNotEmpty
          ? _parsedCsv!.copyWith(title: title)
          : _parsedCsv!;
      await _service.importParsedCsvDatabaseIntoPage(
        widget.currentPageId!,
        toImport,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onNavigateToPage?.call(widget.currentPageId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImportingCsv = false;
          _csvError = 'Insert error: $e';
        });
      }
    }
  }

  Future<void> _handleExportWorkspaceBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final jsonStr = await _service.exportWorkspaceJson();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'notes_here_backup_$timestamp.json';
      final file = await ExportImportService.saveExportToFile(
        jsonStr,
        filename,
      );

      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _workspaceStatusMessage = 'Backup saved to:\n${file.path}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _workspaceStatusMessage = 'Backup failed: $e';
        });
      }
    }
  }

  Future<void> _handleCopyWorkspaceJson() async {
    setState(() => _isBackingUp = true);
    try {
      final jsonStr = await _service.exportWorkspaceJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _workspaceStatusMessage = 'Backup JSON copied to clipboard!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _workspaceStatusMessage = 'Failed to generate backup: $e';
        });
      }
    }
  }

  Future<void> _handleRestoreWorkspace() async {
    final raw = _restoreJsonController.text.trim();
    if (raw.isEmpty) {
      setState(
        () => _workspaceStatusMessage = 'Please paste backup JSON to restore',
      );
      return;
    }

    setState(() {
      _isRestoring = true;
      _workspaceStatusMessage = null;
    });

    try {
      final summary = await _service.restoreWorkspaceJson(
        raw,
        wipeExisting: _wipeExisting,
      );
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _workspaceStatusMessage =
              'Workspace restored successfully!\n${summary.pagesCount} pages, ${summary.databasesCount} databases, ${summary.blocksCount} blocks.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _workspaceStatusMessage = 'Restore failed: $e';
        });
      }
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
                          _TabButton(
                            label: context.l10n.tabExportMd,
                            icon: AppIcons.squareArrowUp,
                            isSelected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          _TabButton(
                            label: context.l10n.tabImportMd,
                            icon: AppIcons.arrowDownToLine,
                            isSelected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          _TabButton(
                            label: context.l10n.tabNotionCsv,
                            icon: AppIcons.table,
                            isSelected: _selectedTab == 2,
                            onTap: () => setState(() => _selectedTab = 2),
                          ),
                          const SizedBox(width: UiSpace.s8),
                          _TabButton(
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
                  ? _tabContent(skin)
                  : AnimatedSwitcher(
                      duration: Motion.of(context, Motion.micro),
                      switchInCurve: Motion.curve,
                      switchOutCurve: Motion.curve,
                      child: _tabContent(skin),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Export Markdown
  // ---------------------------------------------------------------------------

  Widget _tabContent(Skin skin) => switch (_selectedTab) {
    0 => _buildExportTab(skin),
    1 => _buildImportTab(skin),
    2 => _buildNotionCsvTab(skin),
    _ => _buildWorkspaceTab(skin),
  };

  Widget _buildExportTab(Skin skin) {
    if (widget.currentPageId == null) {
      return Center(
        child: Text(
          context.l10n.selectPageToExport,
          style: TextStyle(color: skin.muted, fontSize: UiType.body),
        ),
      );
    }

    if (_isLoadingExport) {
      return Center(
        child: SizedBox(
          width: UiSpace.s24,
          height: UiSpace.s24,
          child: TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: CircularProgressIndicator(strokeWidth: 2, color: skin.muted),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(UiSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Page: ',
                style: TextStyle(fontSize: UiType.caption, color: skin.muted),
              ),
              Text(
                widget.currentPageTitle ?? context.l10n.untitled,
                style: TextStyle(
                  fontSize: UiType.body,
                  fontWeight: FontWeight.w600,
                  color: skin.text,
                ),
              ),
              const Spacer(),
              if (_savedFilePath != null)
                Expanded(
                  child: Text(
                    _savedFilePath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: UiType.small, color: skin.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: UiSpace.s10),

          // Markdown Preview Box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(UiSpace.s12),
              decoration: _panelDecoration(skin),
              child: SingleChildScrollView(
                child: SelectableText(
                  _exportedMarkdown,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: UiType.caption,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: UiSpace.s12),

          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: UiSpace.s8,
            runSpacing: UiSpace.s8,
            children: [
              _ActionButton(
                label: _isCopied
                    ? context.l10n.copied
                    : context.l10n.copyToClipboard,
                icon: _isCopied ? AppIcons.checkMark : AppIcons.docOnDoc,
                isAccent: _isCopied,
                onTap: _copyMarkdownToClipboard,
              ),
              _ActionButton(
                label: context.l10n.saveMdToDownloads,
                icon: AppIcons.arrowDownToLine,
                isAccent: true,
                onTap: _saveMarkdownToFile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Import Markdown
  // ---------------------------------------------------------------------------

  Widget _buildImportTab(Skin skin) {
    return Padding(
      padding: const EdgeInsets.all(UiSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filePathController,
                  selectAllOnFocus: false,
                  style: TextStyle(fontSize: UiType.caption, color: skin.text),
                  decoration: _dialogInputDecoration(
                    skin,
                    hintText: Platform.isWindows
                        ? r'Or enter local file path (e.g. C:\Users\User\notes.md)'
                        : 'Or enter local file path (e.g. /Users/user/notes.md)',
                  ),
                ),
              ),
              const SizedBox(width: UiSpace.s8),
              _ActionButton(
                label: context.l10n.browse,
                icon: AppIcons.folder,
                onTap: () async {
                  final path = await DesktopFilePicker.pickFile(
                    allowedExtensions: ['md', 'markdown', 'txt'],
                    prompt: 'Select Markdown File to Import',
                  );
                  if (path != null) {
                    _filePathController.text = path;
                    await _handleLoadFileForImport();
                  }
                },
              ),
              const SizedBox(width: UiSpace.s6),
              _ActionButton(
                label: context.l10n.loadFile,
                icon: AppIcons.docTextSearch,
                onTap: _handleLoadFileForImport,
              ),
            ],
          ),
          const SizedBox(height: UiSpace.s10),

          // Paste Area
          Expanded(
            child: TextField(
              controller: _importController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: UiType.caption,
                height: 1.4,
              ),
              decoration: _dialogInputDecoration(
                skin,
                isTextArea: true,
                hintText:
                    'Paste raw Markdown text or frontmatter here...\n\n---\ntitle: Sample Note\n---\n# Heading\nContent goes here...',
              ),
            ),
          ),

          if (_importError != null) ...[
            const SizedBox(height: UiSpace.s8),
            StatusPill(
              tone: StatusTone.danger,
              child: Text(
                _importError!,
                style: const TextStyle(fontSize: UiType.caption),
              ),
            ),
          ],
          const SizedBox(height: UiSpace.s12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionButton(
                label: _isImporting
                    ? context.l10n.loading
                    : context.l10n.importAsNewPage,
                icon: AppIcons.plusCircle,
                isAccent: true,
                onTap: _isImporting ? null : _handleImportMarkdown,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Notion / CSV Database Import
  // ---------------------------------------------------------------------------

  Widget _buildNotionCsvTab(Skin skin) {
    return Padding(
      padding: const EdgeInsets.all(UiSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File path loader row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _csvFilePathController,
                  selectAllOnFocus: false,
                  style: TextStyle(fontSize: UiType.caption, color: skin.text),
                  decoration: _dialogInputDecoration(
                    skin,
                    hintText: Platform.isWindows
                        ? r'Enter Notion CSV file path (e.g. C:\Users\User\Downloads\Export.csv)'
                        : 'Enter Notion CSV file path (e.g. /Users/user/Downloads/.../Export.csv)',
                  ),
                ),
              ),
              const SizedBox(width: UiSpace.s8),
              _ActionButton(
                label: context.l10n.browse,
                icon: AppIcons.folder,
                onTap: () async {
                  final path = await DesktopFilePicker.pickFile(
                    allowedExtensions: ['csv'],
                    prompt: 'Select Notion CSV File to Import',
                  );
                  if (path != null) {
                    _csvFilePathController.text = path;
                    await _handleLoadCsvFile();
                  }
                },
              ),
              const SizedBox(width: UiSpace.s6),
              _ActionButton(
                label: context.l10n.loadFile,
                icon: AppIcons.docTextSearch,
                onTap: _handleLoadCsvFile,
              ),
            ],
          ),
          const SizedBox(height: UiSpace.s10),

          // Title & Stats row
          if (_parsedCsv != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UiSpace.s12,
                vertical: UiSpace.s8,
              ),
              decoration: _panelDecoration(skin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.table, size: UiSpace.s16, color: skin.hint),
                      const SizedBox(width: UiSpace.s6),
                      Expanded(
                        child: TextField(
                          controller: _csvTitleController,
                          selectAllOnFocus: false,
                          style: TextStyle(
                            fontSize: UiType.body,
                            fontWeight: FontWeight.w600,
                            color: skin.text,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'Table Title',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s6,
                          vertical: UiSpace.s2,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiRadius.action),
                        ),
                        child: Text(
                          '${_parsedCsv!.rows.length} rows • ${_parsedCsv!.columns.length} columns',
                          style: const TextStyle(
                            fontSize: UiType.small,
                            fontWeight: FontWeight.w500,
                            color: Palette.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UiSpace.s8),
                  // Column types chips with interactive popover type selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var colIdx = 0;
                          colIdx < _parsedCsv!.columns.length;
                          colIdx++
                        ) ...[
                          Builder(
                            builder: (chipContext) {
                              final col = _parsedCsv!.columns[colIdx];
                              final isTitle =
                                  colIdx == _parsedCsv!.titleColumnIndex;
                              return GestureDetector(
                                onTap: () =>
                                    _showColumnTypeMenu(chipContext, colIdx),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      right: UiSpace.s6,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: UiSpace.s7,
                                      vertical: UiSpace.s3,
                                    ),
                                    decoration: ShapeDecoration(
                                      color: skin.hover,
                                      shape: UiRadius.squircle(
                                        UiRadius.small,
                                        side: BorderSide(
                                          color: isTitle
                                              ? Palette.accent.withValues(
                                                  alpha: 0.45,
                                                )
                                              : skin.hairlineBorder,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          iconForColumnType(col.type),
                                          size: UiSpace.s14,
                                          color: isTitle
                                              ? Palette.accent
                                              : skin.muted,
                                        ),
                                        const SizedBox(width: UiSpace.s4),
                                        Text(
                                          col.name,
                                          style: TextStyle(
                                            fontSize: UiType.small,
                                            fontWeight: isTitle
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: skin.text,
                                          ),
                                        ),
                                        const SizedBox(width: UiSpace.s4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: UiSpace.s4,
                                            vertical: UiSpace.s1,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (isTitle
                                                        ? Palette.accent
                                                        : skin.hint)
                                                    .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              UiRadius.scrollbar,
                                            ),
                                          ),
                                          child: Text(
                                            '(${col.type})',
                                            style: TextStyle(
                                              fontSize: UiType.micro,
                                              fontWeight: FontWeight.w500,
                                              color: isTitle
                                                  ? Palette.accent
                                                  : skin.muted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: UiSpace.s2),
                                        Icon(
                                          AppIcons.chevronDown,
                                          size: UiSpace.s14,
                                          color: skin.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UiSpace.s10),
          ],

          // View toggle: Table Preview vs Raw CSV
          Row(
            children: [
              _ModePill(
                label: context.l10n.tablePreview,
                icon: AppIcons.table,
                isSelected: _showTablePreview && _parsedCsv != null,
                onTap: _parsedCsv != null
                    ? () => setState(() => _showTablePreview = true)
                    : null,
              ),
              const SizedBox(width: UiSpace.s6),
              _ModePill(
                label: context.l10n.rawCsv,
                icon: AppIcons.chevronLeftSlashChevronRight,
                isSelected: !_showTablePreview || _parsedCsv == null,
                onTap: () => setState(() => _showTablePreview = false),
              ),
            ],
          ),
          const SizedBox(height: UiSpace.s8),

          // CSV Raw or Table Preview Area
          Expanded(
            child: (_showTablePreview && _parsedCsv != null)
                ? _buildTableGridPreview(skin)
                : TextField(
                    controller: _csvController,
                    maxLines: null,
                    expands: true,
                    onChanged: (_) => _parseCsvInput(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: UiType.caption,
                      height: 1.4,
                    ),
                    decoration: _dialogInputDecoration(
                      skin,
                      isTextArea: true,
                      hintText:
                          'Paste raw CSV from Notion database here...\n\nДата,Время,описание,Select,Запрос\n05/11/2026,1.5,Task Name,Category,https://...',
                    ),
                  ),
          ),

          if (_csvError != null) ...[
            const SizedBox(height: UiSpace.s8),
            StatusPill(
              tone: StatusTone.danger,
              child: Text(
                _csvError!,
                style: const TextStyle(fontSize: UiType.caption),
              ),
            ),
          ],
          const SizedBox(height: UiSpace.s12),

          Wrap(
            alignment: WrapAlignment.end,
            spacing: UiSpace.s8,
            runSpacing: UiSpace.s8,
            children: [
              if (widget.currentPageId != null)
                _ActionButton(
                  label: _isImportingCsv
                      ? 'Inserting...'
                      : 'Insert into Current Page',
                  icon: AppIcons.table,
                  onTap: _isImportingCsv
                      ? null
                      : _handleInsertCsvIntoCurrentPage,
                ),
              _ActionButton(
                label: _isImportingCsv
                    ? context.l10n.loading
                    : context.l10n.importAsNewDatabasePage,
                icon: AppIcons.docOnDoc,
                isAccent: true,
                onTap: _isImportingCsv ? null : _handleImportCsvAsNewPage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Workspace Backup & Restore
  // ---------------------------------------------------------------------------

  Widget _buildWorkspaceTab(Skin skin) {
    return Padding(
      padding: const EdgeInsets.all(UiSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Backup
          Container(
            padding: const EdgeInsets.all(UiSpace.s16),
            decoration: _panelDecoration(skin, radius: UiRadius.popover),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.cloudDownload,
                      size: UiSpace.s16,
                      color: skin.muted,
                    ),
                    const SizedBox(width: UiSpace.s8),
                    Text(
                      context.l10n.exportWorkspaceBackup,
                      style: TextStyle(
                        fontSize: UiType.body,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiSpace.s6),
                Text(
                  'Create an archive of all pages, database tables, properties, and blocks in a single JSON file.',
                  style: TextStyle(fontSize: UiType.caption, color: skin.muted),
                ),
                const SizedBox(height: UiSpace.s10),
                Wrap(
                  spacing: UiSpace.s8,
                  runSpacing: UiSpace.s8,
                  children: [
                    _ActionButton(
                      label: _isBackingUp
                          ? context.l10n.loading
                          : context.l10n.saveBackupToDownloads,
                      icon: AppIcons.arrowDownToLine,
                      isAccent: true,
                      onTap: _isBackingUp ? null : _handleExportWorkspaceBackup,
                    ),
                    _ActionButton(
                      label: 'Copy JSON',
                      icon: AppIcons.docOnDoc,
                      onTap: _isBackingUp ? null : _handleCopyWorkspaceJson,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: UiSpace.s12),

          // Section 2: Restore
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(UiSpace.s16),
              decoration: _panelDecoration(skin, radius: UiRadius.popover),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.arrowCounterclockwise,
                        size: UiSpace.s16,
                        color: skin.muted,
                      ),
                      const SizedBox(width: UiSpace.s8),
                      Text(
                        context.l10n.restoreWorkspaceFromJson,
                        style: TextStyle(
                          fontSize: UiType.body,
                          fontWeight: FontWeight.w600,
                          color: skin.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UiSpace.s8),
                  Expanded(
                    child: TextField(
                      controller: _restoreJsonController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: UiType.caption,
                      ),
                      decoration: _dialogInputDecoration(
                        skin,
                        isTextArea: true,
                        hintText: 'Paste backup JSON content here to restore...',
                      ),
                    ),
                  ),
                  const SizedBox(height: UiSpace.s8),
                  Row(
                    children: [
                      Checkbox(
                        value: _wipeExisting,
                        onChanged: (v) =>
                            setState(() => _wipeExisting = v ?? false),
                        activeColor: skin.destructive,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: UiSpace.s4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _wipeExisting = !_wipeExisting),
                          child: Text(
                            'Clear existing workspace before restore',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: UiType.caption,
                              color: _wipeExisting
                                  ? skin.destructive
                                  : skin.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: UiSpace.s8),
                      _ActionButton(
                        label: _isRestoring
                            ? context.l10n.loading
                            : context.l10n.restoreWorkspace,
                        icon: AppIcons.arrowCounterclockwise,
                        isAccent: true,
                        onTap: _isRestoring ? null : _handleRestoreWorkspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_workspaceStatusMessage != null) ...[
            const SizedBox(height: UiSpace.s8),
            StatusPill(
              tone:
                  _workspaceStatusMessage!.contains('failed') ||
                      _workspaceStatusMessage!.contains('Error')
                  ? StatusTone.danger
                  : StatusTone.success,
              child: Text(
                _workspaceStatusMessage!,
                style: const TextStyle(fontSize: UiType.caption),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableGridPreview(Skin skin) {
    if (_parsedCsv == null || _parsedCsv!.columns.isEmpty) {
      return Center(
        child: Text(
          'No CSV data parsed',
          style: TextStyle(fontSize: UiType.caption, color: skin.muted),
        ),
      );
    }

    final columns = _parsedCsv!.columns;
    final rows = _parsedCsv!.rows;
    const maxPreviewRows = 50;
    final previewRows = rows.take(maxPreviewRows).toList();

    return Container(
      decoration: _panelDecoration(skin),
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: UiRadius.squircle(UiRadius.dialog),
        ),
        child: Scrollbar(
          controller: _tableHorizController,
          child: SingleChildScrollView(
            controller: _tableHorizController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (columns.length * 150.0 + 44.0).clamp(650.0, 3000.0),
              child: Scrollbar(
                controller: _tableVertController,
                child: SingleChildScrollView(
                  controller: _tableVertController,
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Container(
                        height: UiSpace.s32,
                        decoration: BoxDecoration(
                          color: skin.hover,
                          border: Border(
                            bottom: BorderSide(
                              color: skin.hairlineBorder,
                              width: UiSpace.s1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: UiSpace.s44,
                              alignment: Alignment.center,
                              child: Text(
                                '#',
                                style: TextStyle(
                                  fontSize: UiType.small,
                                  fontWeight: FontWeight.w600,
                                  color: skin.muted,
                                ),
                              ),
                            ),
                            for (
                              var colIdx = 0;
                              colIdx < columns.length;
                              colIdx++
                            ) ...[
                              Container(
                                width: UiSpace.s1,
                                height: UiSpace.s18,
                                color: skin.hairlineBorder,
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: UiSpace.s8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        iconForColumnType(columns[colIdx].type),
                                        size: UiSpace.s14,
                                        color: columns[colIdx].type == 'title'
                                            ? skin.text
                                            : skin.muted,
                                      ),
                                      const SizedBox(width: UiSpace.s5),
                                      Expanded(
                                        child: Text(
                                          columns[colIdx].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: UiType.caption,
                                            fontWeight:
                                                columns[colIdx].type == 'title'
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color:
                                                columns[colIdx].type == 'title'
                                                ? skin.text
                                                : skin.muted,
                                          ),
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
                      // Data Rows
                      for (var r = 0; r < previewRows.length; r++)
                        Container(
                          height: UiSpace.s28,
                          decoration: BoxDecoration(
                            color: r.isOdd
                                ? skin.hover.withValues(
                                    alpha: skin.hover.a * 0.5,
                                  )
                                : Palette.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: skin.hairlineBorder,
                                width: UiSpace.s1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: UiSpace.s44,
                                alignment: Alignment.center,
                                child: Text(
                                  '${r + 1}',
                                  style: TextStyle(
                                    fontSize: UiType.small,
                                    color: skin.hint,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              for (
                                var colIdx = 0;
                                colIdx < columns.length;
                                colIdx++
                              ) ...[
                                Container(
                                  width: UiSpace.s1,
                                  height: UiSpace.s16,
                                  color: skin.hairlineBorder,
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: UiSpace.s8,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: _buildCellContent(
                                      skin,
                                      columns[colIdx].type,
                                      colIdx < previewRows[r].length
                                          ? previewRows[r][colIdx]
                                          : '',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(Skin skin, String colType, String value) {
    if (value.isEmpty) {
      return Text(
        '-',
        style: TextStyle(fontSize: UiType.small, color: skin.hint),
      );
    }

    if (colType == 'select' || colType == 'status') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s6,
          vertical: UiSpace.s1_5,
        ),
        decoration: BoxDecoration(
          color: Palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(UiRadius.action),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: UiType.small,
            fontWeight: FontWeight.w500,
            color: Palette.accent,
          ),
        ),
      );
    }

    if (colType == 'multi_select') {
      final tags =
          value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
      return Wrap(
        spacing: UiSpace.s4,
        runSpacing: UiSpace.s2,
        children: [
          for (final tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UiSpace.s6,
                vertical: UiSpace.s1_5,
              ),
              decoration: BoxDecoration(
                color: Palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(UiRadius.action),
              ),
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: UiType.small,
                  fontWeight: FontWeight.w500,
                  color: Palette.accent,
                ),
              ),
            ),
        ],
      );
    }

    if (colType == 'checkbox') {
      final isChecked =
          value.toLowerCase() == 'true' ||
          value.toLowerCase() == 'yes' ||
          value == '1' ||
          value == '✓';
      return Icon(
        isChecked ? AppIcons.checkmarkSquare : AppIcons.square,
        size: UiSpace.s14,
        color: isChecked ? Palette.accent : skin.muted,
      );
    }

    if (colType == 'url') {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: UiType.small,
          color: Palette.accent,
          decoration: TextDecoration.underline,
        ),
      );
    }

    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: UiType.caption,
        color: colType == 'title' ? skin.text : skin.muted,
        fontWeight: colType == 'title' ? FontWeight.w500 : FontWeight.w400,
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      selected: isSelected,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s10,
              vertical: UiSpace.s5,
            ),
            decoration: ShapeDecoration(
              color: isSelected
                  ? Palette.accent.withValues(alpha: 0.12)
                  : hover
                  ? skin.sidebarSelected
                  : skin.hover,
              shape: StadiumBorder(
                side: BorderSide(
                  color: focus
                      ? skin.accentText
                      : isSelected
                      ? Palette.accent.withValues(alpha: 0.35)
                      : skin.hairlineBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: UiSpace.s14,
                  color: isSelected ? skin.accentText : skin.muted,
                ),
                const SizedBox(width: UiSpace.s5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: UiType.small,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.accentText : skin.muted,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      selected: isSelected,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s10,
              vertical: UiSpace.s6,
            ),
            decoration: ShapeDecoration(
              color: isSelected
                  ? skin.sidebarSelected
                  : hover
                  ? skin.hover
                  : Palette.transparent,
              shape: UiRadius.squircle(
                UiRadius.small,
                side: focus
                    ? BorderSide(color: skin.accentText)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: UiSpace.s15,
                  color: isSelected ? skin.text : skin.muted,
                ),
                const SizedBox(width: UiSpace.s6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: UiType.caption,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.text : skin.muted,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isAccent;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.isAccent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final disabled = onTap == null;
    final bg = isAccent
        ? (disabled ? Palette.accent.withValues(alpha: 0.35) : Palette.accent)
        : skin.hover;
    final fg = isAccent
        ? (disabled
              ? Palette.onAccent.withValues(alpha: 0.7)
              : Palette.onAccent)
        : (disabled ? skin.muted : skin.text);
    return QuietButton(
      label: label,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s14,
              vertical: UiSpace.s8,
            ),
            decoration: ShapeDecoration(
              color: !disabled && hover && !isAccent
                  ? skin.sidebarSelected
                  : bg,
              shape: StadiumBorder(
                side: focus
                    ? BorderSide(color: skin.accentText, width: 1.5)
                    : isAccent
                    ? BorderSide.none
                    : BorderSide(color: skin.hairlineBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: UiSpace.s14, color: fg),
                const SizedBox(width: UiSpace.s6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: UiType.caption,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

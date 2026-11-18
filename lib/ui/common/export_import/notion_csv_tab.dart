import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/locale_controller.dart';
import '../../../platform/desktop_services.dart';
import '../../../services/export_import_service.dart';
import '../../editor/components/database/database_models.dart';
import '../../theme.dart';
import '../app_icons.dart';
import '../menu.dart';
import '../popover.dart';
import '../status_pill.dart';
import 'export_import_shared.dart';
import 'notion_csv_preview_table.dart';

class NotionCsvTab extends StatefulWidget {
  final ExportImportService service;
  final String? currentPageId;
  final ValueChanged<String>? onNavigateToPage;
  final VoidCallback? onClose;

  const NotionCsvTab({
    super.key,
    required this.service,
    this.currentPageId,
    this.onNavigateToPage,
    this.onClose,
  });

  @override
  State<NotionCsvTab> createState() => _NotionCsvTabState();
}

class _NotionCsvTabState extends State<NotionCsvTab> {
  final TextEditingController _csvController = TextEditingController();
  final TextEditingController _csvFilePathController = TextEditingController();
  final TextEditingController _csvTitleController = TextEditingController();
  ParsedCsvDatabase? _parsedCsv;
  bool _isImportingCsv = false;
  String? _csvError;
  bool _showTablePreview = true;

  @override
  void dispose() {
    _csvController.dispose();
    _csvFilePathController.dispose();
    _csvTitleController.dispose();
    super.dispose();
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
      final parsed = widget.service.parseNotionCsv(
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
      final newPageId = await widget.service.importParsedCsvDatabaseAsPage(
        toImport,
        parentPageId: widget.currentPageId,
      );
      if (mounted) {
        widget.onClose?.call();
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
      await widget.service.importParsedCsvDatabaseIntoPage(
        widget.currentPageId!,
        toImport,
      );
      if (mounted) {
        widget.onClose?.call();
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
                  decoration: dialogInputDecoration(
                    skin,
                    hintText: Platform.isWindows
                        ? r'Enter Notion CSV file path (e.g. C:\Users\User\Downloads\Export.csv)'
                        : 'Enter Notion CSV file path (e.g. /Users/user/Downloads/.../Export.csv)',
                  ),
                ),
              ),
              const SizedBox(width: UiSpace.s8),
              ExportImportActionButton(
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
              ExportImportActionButton(
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
              decoration: panelDecoration(skin),
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
              ExportImportModePill(
                label: context.l10n.tablePreview,
                icon: AppIcons.table,
                isSelected: _showTablePreview && _parsedCsv != null,
                onTap: _parsedCsv != null
                    ? () => setState(() => _showTablePreview = true)
                    : null,
              ),
              const SizedBox(width: UiSpace.s6),
              ExportImportModePill(
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
                ? NotionCsvPreviewTable(parsedCsv: _parsedCsv)
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
                    decoration: dialogInputDecoration(
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
                ExportImportActionButton(
                  label: _isImportingCsv
                      ? 'Inserting...'
                      : 'Insert into Current Page',
                  icon: AppIcons.table,
                  onTap: _isImportingCsv
                      ? null
                      : _handleInsertCsvIntoCurrentPage,
                ),
              ExportImportActionButton(
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/notes_repository.dart';
import '../../../l10n/locale_controller.dart';
import '../../../services/export_import_service.dart';
import '../../../ui/design_tokens.dart';
import '../../../ui/theme.dart';
import '../app_icons.dart';
import 'export_import_shared.dart';

class PageExportTab extends StatefulWidget {
  final NotesRepository repository;
  final String? currentPageId;
  final String? currentPageTitle;

  const PageExportTab({
    super.key,
    required this.repository,
    this.currentPageId,
    this.currentPageTitle,
  });

  @override
  State<PageExportTab> createState() => _PageExportTabState();
}

class _PageExportTabState extends State<PageExportTab> {
  late final ExportImportService _service;
  bool _isLoadingExport = false;
  String _exportedMarkdown = '';
  bool _isCopied = false;
  String? _savedFilePath;

  @override
  void initState() {
    super.initState();
    _service = ExportImportService(repository: widget.repository);
    _loadPageExport();
  }

  @override
  void didUpdateWidget(PageExportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageId != widget.currentPageId) {
      _loadPageExport();
    }
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
              decoration: panelDecoration(skin),
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
              ExportImportActionButton(
                label: _isCopied
                    ? context.l10n.copied
                    : context.l10n.copyToClipboard,
                icon: _isCopied ? AppIcons.checkMark : AppIcons.docOnDoc,
                isAccent: _isCopied,
                onTap: _copyMarkdownToClipboard,
              ),
              ExportImportActionButton(
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
}

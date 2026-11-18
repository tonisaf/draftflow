import 'dart:io';
import 'package:flutter/material.dart';

import '../../../data/notes_repository.dart';
import '../../../l10n/locale_controller.dart';
import '../../../platform/desktop_services.dart';
import '../../../services/export_import_service.dart';
import '../../../ui/design_tokens.dart';
import '../../../ui/theme.dart';
import '../app_icons.dart';
import '../status_pill.dart';
import 'export_import_shared.dart';

class MarkdownImportTab extends StatefulWidget {
  final NotesRepository repository;
  final ValueChanged<String>? onNavigateToPage;
  final VoidCallback onDismiss;

  const MarkdownImportTab({
    super.key,
    required this.repository,
    this.onNavigateToPage,
    required this.onDismiss,
  });

  @override
  State<MarkdownImportTab> createState() => _MarkdownImportTabState();
}

class _MarkdownImportTabState extends State<MarkdownImportTab> {
  late final ExportImportService _service;
  final _importController = TextEditingController();
  final _filePathController = TextEditingController();
  bool _isImporting = false;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _service = ExportImportService(repository: widget.repository);
  }

  @override
  void dispose() {
    _importController.dispose();
    _filePathController.dispose();
    super.dispose();
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
        widget.onDismiss();
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

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
                  decoration: dialogInputDecoration(
                    skin,
                    hintText: Platform.isWindows
                        ? r'Or enter local file path (e.g. C:\Users\User\notes.md)'
                        : 'Or enter local file path (e.g. /Users/user/notes.md)',
                  ),
                ),
              ),
              const SizedBox(width: UiSpace.s8),
              ExportImportActionButton(
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
              ExportImportActionButton(
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
              decoration: dialogInputDecoration(
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
              ExportImportActionButton(
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
}

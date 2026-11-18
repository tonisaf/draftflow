import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/locale_controller.dart';
import '../../../services/export_import_service.dart';
import '../../theme.dart';
import '../app_icons.dart';
import '../status_pill.dart';
import 'export_import_shared.dart';

class WorkspaceBackupTab extends StatefulWidget {
  final ExportImportService service;

  const WorkspaceBackupTab({
    super.key,
    required this.service,
  });

  @override
  State<WorkspaceBackupTab> createState() => _WorkspaceBackupTabState();
}

class _WorkspaceBackupTabState extends State<WorkspaceBackupTab> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _wipeExisting = false;
  final TextEditingController _restoreJsonController = TextEditingController();
  String? _workspaceStatusMessage;

  @override
  void dispose() {
    _restoreJsonController.dispose();
    super.dispose();
  }

  Future<void> _handleExportWorkspaceBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final jsonStr = await widget.service.exportWorkspaceJson();
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
      final jsonStr = await widget.service.exportWorkspaceJson();
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
      final summary = await widget.service.restoreWorkspaceJson(
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

    return Padding(
      padding: const EdgeInsets.all(UiSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Backup
          Container(
            padding: const EdgeInsets.all(UiSpace.s16),
            decoration: panelDecoration(skin, radius: UiRadius.popover),
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
                    ExportImportActionButton(
                      label: _isBackingUp
                          ? context.l10n.loading
                          : context.l10n.saveBackupToDownloads,
                      icon: AppIcons.arrowDownToLine,
                      isAccent: true,
                      onTap: _isBackingUp ? null : _handleExportWorkspaceBackup,
                    ),
                    ExportImportActionButton(
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
              decoration: panelDecoration(skin, radius: UiRadius.popover),
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
                      decoration: dialogInputDecoration(
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
                      ExportImportActionButton(
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
}

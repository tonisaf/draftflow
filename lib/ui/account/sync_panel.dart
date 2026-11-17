import '../common/app_dialog.dart';
import '../common/app_icons.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../account/account_controller.dart';
import '../../l10n/locale_controller.dart';
import '../../platform/desktop_services.dart';
import '../../sync/sync_engine.dart';
import '../../sync/sync_store.dart';
import '../common/modern_dialog.dart';
import '../theme.dart';

String syncLabel(BuildContext context, AccountController c) {
  final l10n = context.l10n;
  final engine = c.syncEngine;
  if (c.account == null) return l10n.localNotes;
  if (engine == null) return l10n.reauthNotice;
  return switch (engine.phase) {
    NotesSyncPhase.ready => l10n.syncReady,
    NotesSyncPhase.syncing => l10n.syncing,
    NotesSyncPhase.synced => l10n.synced,
    NotesSyncPhase.offline => l10n.syncOffline,
    NotesSyncPhase.conflict => l10n.syncConflict,
    NotesSyncPhase.setupRequired => l10n.syncSetupRequired,
    NotesSyncPhase.authRequired => l10n.syncAuthRequired,
    NotesSyncPhase.error => l10n.syncError,
  };
}

Future<void> showSyncConflictsDialog(
  BuildContext context,
  AccountController controller,
) async {
  final repo = controller.repository;
  final conflicts = await SyncStore(repo.db).conflicts();
  if (!context.mounted || repo != controller.repository) return;
  await showAppDialog<void>(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (_) => _ConflictDialog(controller: controller, conflicts: conflicts),
  );
}

Future<String> saveSyncRecoveryBackup(
  BuildContext context,
  AccountController controller,
) async {
  final l10n = context.l10n;
  try {
    final json = await SyncStore(controller.repository.db)
        .lastRecoveryBackup();
    if (json == null) return l10n.noBackupsYet;
    final saved = await saveRecoveryBackup(json);
    return saved ? l10n.backupSavedSuccess : '';
  } catch (_) {
    return l10n.failedToSaveBackup;
  }
}

class SyncPanel extends StatefulWidget {
  const SyncPanel({super.key, required this.controller});
  final AccountController controller;
  @override
  State<SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends State<SyncPanel> {
  String? _message;
  Future<void> _conflicts() async {
    await showSyncConflictsDialog(context, widget.controller);
    if (mounted) setState(() {});
  }

  Future<void> _backup() async {
    final result = await saveSyncRecoveryBackup(context, widget.controller);
    if (!mounted || result.isEmpty) return;
    setState(() => _message = result);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, engine = c.syncEngine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          syncLabel(context, c),
          style: TextStyle(fontSize: UiType.body, color: context.skin.text),
        ),
        if (engine?.message != null)
          Text(
            engine!.message!,
            style: TextStyle(
              fontSize: UiType.caption,
              color: context.skin.muted,
            ),
          ),
        if (engine != null)
          Text(
            context.l10n.waitingToSend(engine.pending),
            style: TextStyle(
              fontSize: UiType.caption,
              color: context.skin.muted,
            ),
          ),
        const SizedBox(height: UiSpace.s8),
        Wrap(
          spacing: UiSpace.s8,
          runSpacing: UiSpace.s4,
          children: [
            TextButton(
              onPressed:
                  c.busy ||
                      engine == null ||
                      engine.phase == NotesSyncPhase.syncing
                  ? null
                  : engine.sync,
              child: Text(context.l10n.syncNow),
            ),
            if ((engine?.conflictCount ?? 0) > 0)
              TextButton(
                onPressed: c.busy ? null : _conflicts,
                child: Text(context.l10n.resolveConflicts),
              ),
            TextButton(
              onPressed: c.busy ? null : _backup,
              child: Text(context.l10n.backupBeforeConflict),
            ),
          ],
        ),
        if (_message != null)
          Text(
            _message!,
            style: TextStyle(
              fontSize: UiType.caption,
              color: context.skin.muted,
            ),
          ),
      ],
    );
  }
}

class _ConflictDialog extends StatefulWidget {
  const _ConflictDialog({required this.controller, required this.conflicts});
  final AccountController controller;
  final List<SyncConflict> conflicts;
  @override
  State<_ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<_ConflictDialog> {
  int _index = 0;
  late List<SyncConflict> _items = widget.conflicts;
  bool _busy = false;
  String? _error;
  late final _repository = widget.controller.repository;
  String preview(Map<String, dynamic>? data, {bool deleted = false}) {
    if (deleted || data == null) return 'Удалено';
    if (data['title'] is String) {
      final title = data['title'] as String;
      final props = data['properties'];
      if (props is String && props.isNotEmpty) {
        try {
          return '$title\n${(jsonDecode(props) as Map).values.map((v) => v.toString()).join(' · ')}';
        } catch (_) {
          return title;
        }
      }
      return title;
    }
    if (data['name'] is String) return data['name'] as String;
    try {
      final content = jsonDecode(data['content'] as String) as Map;
      final attributes =
          (content['data'] ?? content['attributes'] ?? content) as Map;
      final delta = attributes['delta'] as List?;
      if (delta != null) {
        return delta
            .map((op) => op['insert'] is String ? op['insert'] : '')
            .join();
      }
    } catch (_) {
      /* Non-text blocks have a descriptive fallback. */
    }
    return 'Изменения содержимого страницы';
  }

  Future<void> resolve(bool local) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_repository != widget.controller.repository) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await widget.controller.resolveSyncConflict(
      _items[_index],
      useLocal: local,
    );
    if (!mounted) return;
    if (ok) {
      final remaining = await SyncStore(_repository.db).conflicts();
      if (!mounted) return;
      if (remaining.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _items = remaining;
        _index = 0;
        _busy = false;
      });
    } else {
      setState(() {
        _busy = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    return PopScope(
      canPop: !_busy,
      child: ModernDialog(
        title: context.l10n.conflictDialogTitle,
        icon: AppIcons.arrowRightArrowLeft,
        allowClose: !_busy,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.conflictDialogSubtitle),
            const SizedBox(height: UiSpace.s12),
            Text(
              context.l10n.onThisDevice,
              style: TextStyle(
                fontSize: UiType.title,
                color: context.skin.text,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: DesktopUx.conflictPreviewHeight,
              ),
              child: SingleChildScrollView(
                child: SelectableText(preview(item.local)),
              ),
            ),
            const SizedBox(height: UiSpace.s12),
            Text(
              context.l10n.inCloud,
              style: TextStyle(
                fontSize: UiType.title,
                color: context.skin.text,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: DesktopUx.conflictPreviewHeight,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview(item.remote, deleted: item.remoteAction == 'DELETE'),
                ),
              ),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: context.skin.destructive)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => resolve(false),
            child: Text(context.l10n.acceptCloud),
          ),
          FilledButton(
            onPressed: _busy ? null : () => resolve(true),
            child: Text(context.l10n.keepLocal),
          ),
        ],
      ),
    );
  }
}

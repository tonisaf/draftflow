import '../../../common/app_dialog.dart';
import '../../../common/modern_dialog.dart';
import 'numeric_input_message.dart';

import 'dart:convert';

import 'database_models.dart';

import 'package:flutter/material.dart';

import '../../../../services/database_cell_saves.dart';
import '../../../../l10n/locale_controller.dart';
import '../../../theme.dart';
import '../../../common/app_icons.dart';
import '../../../common/status_pill.dart';

class DatabaseSaveStatus extends StatelessWidget {
  const DatabaseSaveStatus({
    super.key,
    required this.saves,
    required this.databaseId,
  });
  final DatabaseCellSaves saves;
  final String databaseId;

  String _valueText(BuildContext context, CellSaveEntry entry, dynamic value) {
    if (value == null || value == '') return '—';
    if (entry.columnType == 'checkbox') {
      return (value == true || value == 'true' || value == 1)
          ? context.l10n.calcChecked
          : context.l10n.calcUnchecked;
    }
    if (entry.columnType == 'number' && value is num && value.isFinite) {
      return formatNumberValue(
        value,
        NumberColumnConfig.fromOptions(entry.columnOptions),
      );
    }
    if (entry.columnType == 'select' ||
        entry.columnType == 'multi_select' ||
        entry.columnType == 'status') {
      try {
        final options = jsonDecode(entry.columnOptions ?? '[]') as List;
        String label(dynamic id) =>
            options
                .cast<Map>()
                .where((option) => option['id'].toString() == id.toString())
                .map((option) => option['label'].toString())
                .firstOrNull ??
            context.l10n.databaseUnknownTag;
        return value is List ? value.map(label).join(', ') : label(value);
      } catch (_) {
        return context.l10n.databaseUnknownTag;
      }
    }
    return value.toString();
  }

  Future<void> _resolve(BuildContext context) async {
    final entry = saves
        .forDatabase(databaseId)
        .where((entry) => entry.phase == CellSavePhase.conflict)
        .firstOrNull;
    if (entry == null) return;
    await showAppDialog<void>(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: context.skin.scrim,
      builder: (context) => ListenableBuilder(
        listenable: entry,
        builder: (context, _) {
          final reviewedRemote = entry.remoteValue;
          return ModernDialog(
            title: context.l10n.databaseCellConflictTitle,
            icon: AppIcons.exclamationmarkCircle,
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [entry.rowLabel, entry.columnLabel]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                    ),
                    if (entry.conflictAttempts > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: UiSpace.s8),
                        child: Text(
                          context.l10n.databaseCellChangedAgain,
                          style: TextStyle(color: context.skin.destructive),
                        ),
                      ),
                    if (entry.validationIssue != null)
                      Text(
                        numericInputMessage(context, entry.validationIssue!),
                        style: TextStyle(color: context.skin.destructive),
                      ),
                    for (final version in [
                      (
                        context.l10n.databaseCellConflictBase,
                        entry.conflictBase,
                      ),
                      (
                        context.l10n.databaseCellConflictRemote,
                        entry.remoteValue,
                      ),
                      (context.l10n.databaseCellConflictLocal, entry.desired),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(top: UiSpace.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              version.$1,
                              style: const TextStyle(
                                fontSize: UiType.caption,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SelectableText(
                              _valueText(context, entry, version.$2),
                              maxLines: 8,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () async {
                  await saves.resolveConflict(entry.key, keepLocal: false);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(context.l10n.databaseCellUseRemote),
              ),
              TextButton(
                onPressed: entry.validationIssue != null
                    ? null
                    : () async {
                        await saves.resolveConflict(
                          entry.key,
                          keepLocal: true,
                          compareReviewed: true,
                          reviewedRemote: reviewedRemote,
                        );
                        if (context.mounted &&
                            entry.phase != CellSavePhase.conflict) {
                          Navigator.pop(context);
                        }
                      },
                child: Text(context.l10n.databaseCellKeepLocal),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _recover(BuildContext context) async {
    final failed = saves
        .forDatabase(databaseId)
        .where(
          (entry) =>
              entry.phase == CellSavePhase.failed ||
              entry.phase == CellSavePhase.invalid,
        )
        .toList();
    final discard = await showAppDialog<bool>(
      context: context,
      animationStyle: Motion.dialogStyle(context),
      barrierColor: context.skin.scrim,
      builder: (context) => ModernDialog(
        title: context.l10n.databaseUnsavedCellsTitle,
        icon: AppIcons.exclamationmarkCircle,
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.databaseUnsavedCellsHelp),
                for (final entry in failed)
                  Padding(
                    padding: const EdgeInsets.only(top: UiSpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [entry.rowLabel, entry.columnLabel]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                            fontSize: UiType.caption,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (entry.validationIssue != null)
                          Text(
                            numericInputMessage(
                              context,
                              entry.validationIssue!,
                            ),
                            style: TextStyle(color: context.skin.destructive),
                          ),
                        SelectableText(
                          _valueText(context, entry, entry.desired),
                          maxLines: 8,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.skin.destructive,
            ),
            child: Text(context.l10n.useSavedVersion),
          ),
        ],
      ),
    );
    if (discard == true) saves.discardFailed(databaseId);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: saves,
    builder: (context, _) {
      final entries = saves
          .forDatabase(databaseId)
          .where((entry) => entry.submitted)
          .toList();
      final invalid = entries
          .where((entry) => entry.phase == CellSavePhase.invalid)
          .length;
      final failures = entries
          .where((entry) => entry.phase == CellSavePhase.failed)
          .length;
      final pending = entries
          .where((entry) => entry.phase == CellSavePhase.saving)
          .length;
      final conflicts = entries
          .where((entry) => entry.phase == CellSavePhase.conflict)
          .length;
      final attention = failures > 0 || conflicts > 0 || invalid > 0;
      if (entries.isEmpty) return const SizedBox.shrink();
      final skin = context.skin;
      final message = conflicts > 0
          ? context.l10n.databaseCellConflicts(conflicts)
          : invalid > 0
          ? context.l10n.numericInvalidStatus
          : failures > 0
          ? context.l10n.databaseCellSavesFailed(failures)
          : pending > 0
          ? context.l10n.databaseCellSavesPending(pending)
          : context.l10n.savedStatus;
      final tone = conflicts > 0 ? StatusTone.warning : StatusTone.danger;
      final (_, attentionFg) = StatusPill.colorsFor(skin, tone);
      final status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending > 0 && !attention)
            SizedBox.square(
              dimension: UiSpace.s12,
              child: TickerMode(
                enabled: !MediaQuery.disableAnimationsOf(context),
                child: CircularProgressIndicator(
                  strokeWidth: UiSpace.s1_5,
                  color: skin.muted,
                ),
              ),
            )
          else
            Icon(
              attention ? AppIcons.exclamationmarkCircle : AppIcons.checkMark,
              size: UiSpace.s14,
              color: attention ? attentionFg : skin.muted,
            ),
          const SizedBox(width: UiSpace.s6),
          Flexible(
            child: Text(
              message,
              key: const Key('database_save_status'),
              maxLines: 2,
              style: TextStyle(
                fontSize: UiType.caption,
                fontWeight: attention ? FontWeight.w500 : FontWeight.w400,
                color: attention ? attentionFg : skin.muted,
              ),
            ),
          ),
        ],
      );
      if (!attention) return status;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(
            tone: tone,
            radius: UiRadius.pill,
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s8,
              vertical: UiSpace.s4,
            ),
            child: status,
          ),
          Wrap(
            children: [
              if (conflicts > 0)
                TextButton(
                  key: const Key('database_resolve_conflicts'),
                  onPressed: () => _resolve(context),
                  child: Text(context.l10n.databaseCellConflictTitle),
                ),
              if (failures > 0)
                TextButton(
                  key: const Key('database_retry_saves'),
                  onPressed: () => saves.retryDatabase(databaseId),
                  child: Text(context.l10n.retry),
                ),
              if (failures > 0 || invalid > 0)
                IconButton(
                  key: const Key('database_recover_saves'),
                  tooltip: context.l10n.databaseUnsavedCellsTitle,
                  onPressed: () => _recover(context),
                  icon: const Icon(
                    AppIcons.arrowCounterclockwise,
                    size: UiSpace.s16,
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

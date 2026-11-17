import '../data/model/database_paste.dart';
import '../data/model/numeric_cell_input.dart';
import '../data/model/database_cell_conflict.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/notes_repository.dart';

enum CellSavePhase { saved, saving, failed, conflict, invalid }

typedef CellSaveKey = ({
  String databaseId,
  String rowId,
  String columnId,
  bool title,
});
typedef GuardedCellWriter = Future<void> Function(
  CellSaveKey key,
  dynamic value,
  dynamic expected,
);

typedef CellWriter = Future<void> Function(CellSaveKey key, dynamic value);

bool _equal(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);

/// A session draft survives row virtualization, paging and reopening a table.
/// Acknowledgement advances only after the writer succeeds, never on enqueue.
class CellSaveEntry extends ChangeNotifier {
  CellSaveEntry(this.key);
  final CellSaveKey key;
  CellSavePhase phase = CellSavePhase.saved;
  dynamic acknowledged;
  dynamic desired;
  NumericInputIssue? validationIssue;
  dynamic remoteValue;
  dynamic conflictBase;
  bool _hasConflictBase = false;
  int conflictAttempts = 0;
  dynamic _observedRemote;
  bool editing = false;
  String? columnLabel;
  String? columnType;
  String? columnOptions;
  String? rowLabel;
  bool _hasRemote = false;
  bool hasDraft = false;
  bool submitted = false;
  bool _releaseRequested = false;
  bool get observed => hasListeners;
  int _revision = 0;
  Future<void>? _running;

  void changed() => notifyListeners();

  dynamic display(dynamic remote) {
    if (!_hasRemote || !_equal(remote, _observedRemote)) {
      _observedRemote = remote;
      remoteValue = remote;
    }
    if (!_hasRemote) {
      _hasRemote = true;
      if (!hasDraft) acknowledged = remote;
    }
    if (hasDraft) {
      if (phase == CellSavePhase.saved && _equal(remote, acknowledged)) {
        hasDraft = false;
      } else {
        return desired;
      }
    }
    if (editing) return acknowledged;
    acknowledged = remote;
    return remote;
  }
}

class DatabaseCellSaves extends ChangeNotifier {
  DatabaseCellSaves(this._write, {this.guardedWrite});
  final GuardedCellWriter? guardedWrite;
  final CellWriter _write;
  final Map<CellSaveKey, CellSaveEntry> _entries = {};
  Future<void>? _batch;
  static final _sessions = Expando<DatabaseCellSaves>();

  static DatabaseCellSaves forRepository(NotesRepository repository) =>
      _sessions[repository] ??= DatabaseCellSaves(
        (key, value) => key.title
            ? repository.updateRowTitle(key.rowId, value as String)
            : repository.patchRowProperties(key.rowId, {key.columnId: value}),
        guardedWrite: (key, value, expected) =>
            repository.compareAndSetDatabaseCell(
              key.rowId,
              key.columnId,
              value,
              expected,
              title: key.title,
            ),
      );

  CellSaveEntry? lookup(CellSaveKey key) => _entries[key];

  CellSaveEntry entry(CellSaveKey key) =>
      _entries.putIfAbsent(key, () => CellSaveEntry(key));
  Iterable<CellSaveEntry> forDatabase(String databaseId) =>
      _entries.values.where((entry) => entry.key.databaseId == databaseId);

  void editingChanged(CellSaveKey key, bool editing) {
    final item = entry(key);
    if (item.editing == editing) return;
    item.editing = editing;
    if (!editing && !item.hasDraft && item._hasRemote) {
      item.acknowledged = item.remoteValue;
    }
    _changed(item);
  }

  Future<void> resolveConflict(
    CellSaveKey key, {
    required bool keepLocal,
    bool compareReviewed = false,
    dynamic reviewedRemote,
  }) {
    final item = entry(key);
    if (item.phase != CellSavePhase.conflict) return Future.value();
    if (keepLocal && item.validationIssue != null) return Future.value();
    item.acknowledged = item.remoteValue;
    if (!keepLocal) {
      item._hasConflictBase = false;
      item.validationIssue = null;
      item.conflictAttempts = 0;
      item.hasDraft = false;
      item.desired = item.remoteValue;
      item.phase = CellSavePhase.saved;
      _changed(item);
      return Future.value();
    }
    if (compareReviewed) item.acknowledged = reviewedRemote;
    item.phase = CellSavePhase.saving;
    _changed(item);
    return _start(item);
  }

  /// Clean unmounted cells do not accumulate as users scroll through a large table.
  /// Failed/pending drafts remain attached to the repository session.
  void release(CellSaveKey key) {
    final item = _entries[key];
    if (item == null) return;
    item._releaseRequested = true;
    scheduleMicrotask(() {
      if (identical(_entries[key], item) &&
          !item.observed &&
          item.phase == CellSavePhase.saved) {
        _entries.remove(key);
        notifyListeners();
      }
    });
  }

  void _changed(CellSaveEntry entry) {
    scheduleMicrotask(() {
      entry.changed();
      notifyListeners();
    });
  }

  Future<void> submit(CellSaveKey key, dynamic value) {
    final item = entry(key);
    // Detach mutable lists/maps before any asynchronous write.
    item.submitted = true;
    item.desired = value is List || value is Map
        ? jsonDecode(jsonEncode(value))
        : value;
    item.hasDraft = true;
    item._revision++;
    item.validationIssue = null;
    if (item.columnType == 'number') {
      final parsed = parseNumericCellInput(
        value,
        format: numericColumnFormat(item.columnOptions),
      );
      if (!parsed.valid) {
        item.validationIssue = parsed.issue;
        item.desired = value?.toString() ?? '';
        if (item.phase != CellSavePhase.conflict) {
          item.phase = CellSavePhase.invalid;
        }
        _changed(item);
        return Future.value();
      }
      item.desired = parsed.value;
    }
    if (item.phase == CellSavePhase.conflict) {
      _changed(item);
      return Future.value();
    }
    item.phase = CellSavePhase.saving;
    _changed(item);
    return _start(item);
  }

  Future<void> retry(CellSaveKey key) {
    final item = entry(key);
    if (!item.hasDraft || item.phase != CellSavePhase.failed) {
      return Future.value();
    }
    item.phase = CellSavePhase.saving;
    _changed(item);
    return _start(item);
  }

  void discardFailed(String databaseId) {
    for (final item in forDatabase(databaseId).toList()) {
      if (item.phase != CellSavePhase.failed &&
          item.phase != CellSavePhase.invalid) {
        continue;
      }
      item.validationIssue = null;
      item.hasDraft = false;
      item.desired = item.acknowledged;
      item.phase = CellSavePhase.saved;
      _changed(item);
      if (item._releaseRequested) release(item.key);
    }
  }

  /// Reserve a range while the transactional writer runs. New typed edits queue
  /// behind it; existing unsaved target drafts are never silently replaced.
  Future<void> applyBatch(
    List<DatabaseCellChange> changes,
    Future<void> Function() write, {
    bool undo = false,
  }) async {
    if (_batch != null) {
      throw const DatabasePasteException(DatabasePasteIssue.busy);
    }
    CellSaveKey keyFor(DatabaseCellChange c) => (
      databaseId: c.databaseId,
      rowId: c.rowId,
      columnId: c.column.id,
      title: c.column.type == 'title',
    );
    final revisions = <CellSaveKey, int>{};
    for (final change in changes) {
      final key = keyFor(change), item = _entries[key];
      if (item != null &&
          (item._running != null ||
              item.editing ||
              item.phase != CellSavePhase.saved)) {
        throw const DatabasePasteException(DatabasePasteIssue.drafts);
      }
      revisions[key] = item?._revision ?? 0;
    }
    final done = Completer<void>();
    _batch = done.future;
    try {
      await write();
      for (final change in changes) {
        final key = keyFor(change), item = entry(key);
        final value = undo ? change.before : change.after;
        item.acknowledged = value;
        item._hasRemote = true;
        item.columnType = change.column.type;
        item.columnOptions = change.column.options;
        item.columnLabel = change.column.name;
        if (item._revision == revisions[key]) {
          item.desired = value;
          item.hasDraft = true;
          item.submitted = true;
          item.phase = CellSavePhase.saved;
          item.validationIssue = null;
        }
        _changed(item);
      }
    } finally {
      _batch = null;
      done.complete();
    }
  }

  Future<bool> flush() async {
    while (true) {
      final writes = [
        ?_batch,
        for (final item in _entries.values)
          if (item._running != null) item._running!,
      ];
      if (writes.isEmpty) break;
      await Future.wait(writes);
    }
    return !_entries.values.any(
      (item) =>
          item.phase == CellSavePhase.failed ||
          item.phase == CellSavePhase.conflict ||
          item.phase == CellSavePhase.invalid,
    );
  }

  Future<void> retryDatabase(String databaseId) => Future.wait([
    for (final item in forDatabase(databaseId).toList())
      if (item.phase == CellSavePhase.failed) retry(item.key),
  ]);

  Future<void> _start(CellSaveEntry item) {
    if (item._running != null) return item._running!;
    final task = _drain(item);
    item._running = task;
    return task;
  }

  Future<void> _drain(CellSaveEntry item) async {
    // Yield once so _running is installed even if the writer throws synchronously.
    await Future<void>.value();
    try {
      while (true) {
        if (_batch != null) await _batch;
        if (!item.hasDraft || item.validationIssue != null) return;
        final revision = item._revision;
        final value = item.desired;
        try {
          final guarded = guardedWrite;
          if (guarded != null && item._hasRemote) {
            await guarded(item.key, value, item.acknowledged);
          } else {
            await _write(item.key, value);
          }
          item.acknowledged = value;
        } on NumericCellValidationException catch (invalid) {
          if (revision != item._revision) continue;
          item.validationIssue = invalid.issue;
          item.desired = value?.toString() ?? '';
          item.phase = CellSavePhase.invalid;
          _changed(item);
          return;
        } on DatabaseCellConflict catch (conflict) {
          if (!item._hasConflictBase) {
            item.conflictBase = item.acknowledged;
            item._hasConflictBase = true;
          }
          item.conflictAttempts++;
          item.remoteValue = conflict.current;
          item.phase = CellSavePhase.conflict;
          _changed(item);
          return;
        } catch (_) {
          if (revision != item._revision) continue;
          item.phase = CellSavePhase.failed;
          _changed(item);
          return;
        }
        if (revision != item._revision) continue;
        item.phase = CellSavePhase.saved;
        item._hasConflictBase = false;
        item.conflictAttempts = 0;
        _changed(item);
        return;
      }
    } finally {
      item._running = null;
      if (item._releaseRequested) release(item.key);
    }
  }
}

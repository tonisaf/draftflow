import 'package:flutter/foundation.dart';

import '../data/model/database_paste.dart';
import '../data/notes_repository.dart';
import 'database_cell_saves.dart';

/// Range-only history is session scoped, independent of document block undo.
class DatabaseRangeEdits extends ChangeNotifier {
  DatabaseRangeEdits(this.repository)
    : saves = DatabaseCellSaves.forRepository(repository);
  final NotesRepository repository;
  final DatabaseCellSaves saves;
  static final _sessions = Expando<DatabaseRangeEdits>();
  static DatabaseRangeEdits forRepository(NotesRepository repository) =>
      _sessions[repository] ??= DatabaseRangeEdits(repository);
  final _undo = <String, List<List<DatabaseCellChange>>>{};
  final _redo = <String, List<List<DatabaseCellChange>>>{};
  bool busy = false;
  bool canUndo(String id) => _undo[id]?.isNotEmpty ?? false;
  bool canRedo(String id) => _redo[id]?.isNotEmpty ?? false;

  Future<int> paste(List<DatabaseCellChange> changes) => _run(() async {
    if (changes.isEmpty) return 0;
    final snapshot = [
      for (final c in changes)
        DatabaseCellChange(
          databaseId: c.databaseId,
          rowId: c.rowId,
          column: c.column,
          before: c.before,
          after: c.after,
        ),
    ];
    await _write(snapshot, undo: false);
    final id = snapshot.first.databaseId;
    final history = _undo.putIfAbsent(id, () => []);
    history.add(snapshot);
    if (history.length > 20) history.removeAt(0);
    _redo.remove(id);
    notifyListeners();
    return snapshot.length;
  });

  Future<int> undo(String databaseId) => _replay(databaseId, undo: true);
  Future<int> redo(String databaseId) => _replay(databaseId, undo: false);
  Future<int> _replay(String id, {required bool undo}) => _run(() async {
    final source = (undo ? _undo : _redo)[id];
    if (source == null || source.isEmpty) return 0;
    final changes = source.last;
    await _write(changes, undo: undo);
    source.removeLast();
    (undo ? _redo : _undo).putIfAbsent(id, () => []).add(changes);
    notifyListeners();
    return changes.length;
  });

  Future<void> _write(List<DatabaseCellChange> changes, {required bool undo}) =>
      saves.applyBatch(
        changes,
        () => repository.applyDatabaseCellChanges(changes, undo: undo),
        undo: undo,
      );

  Future<int> _run(Future<int> Function() action) async {
    if (busy) throw const DatabasePasteException(DatabasePasteIssue.busy);
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

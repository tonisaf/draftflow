import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/db/app_database.dart';
import '../data/notes_repository.dart';
import '../data/model/block_codec.dart';

enum SaveStatus { saved, saving, error, conflict }

class AutoSaveService {
  final NotesRepository repository;
  final String pageId;
  final EditorState editorState;
  final Duration debounceDuration;
  String _version;
  final String draftId;
  final EditorDraft? recoveredDraft;

  final ValueNotifier<SaveStatus> statusNotifier = ValueNotifier<SaveStatus>(
    SaveStatus.saved,
  );

  StreamSubscription<EditorTransactionValue>? _subscription;
  Timer? _debounceTimer;
  Future<void>? _saving;
  ({List<Node> nodes, int generation})? _pending;
  int _generation = 0;
  int _savedGeneration = 0;
  bool _isDisposed = false;
  bool _hasConflict = false;
  bool _resolved = false;

  AutoSaveService({
    required this.repository,
    required this.pageId,
    required this.editorState,
    required String initialVersion,
    String? draftId,
    this.recoveredDraft,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : _version = initialVersion,
       draftId = draftId ?? const Uuid().v4() {
    if (recoveredDraft != null) {
      _generation = 1;
      _hasConflict = true;
      statusNotifier.value = SaveStatus.conflict;
    }
    _subscription = editorState.transactionStream.listen((event) {
      if (_isDisposed || _resolved) return;
      final (time, transaction, _) = event;
      if (time == TransactionTime.after && transaction.operations.isNotEmpty) {
        _generation++;
        if (!_hasConflict) _setStatus(SaveStatus.saving);
        _debounceTimer?.cancel();
        _debounceTimer = Timer(debounceDuration, forceSave);
      }
    });
  }

  void _setStatus(SaveStatus status) {
    if (!_isDisposed) statusNotifier.value = status;
  }

  Future<void> forceSave() {
    _debounceTimer?.cancel();
    if (_isDisposed || _resolved) return _saving ?? Future.value();
    if (_generation == _savedGeneration) return _saving ?? Future.value();

    // Capture an independent snapshot before any await; EditorState stays mutable.
    final nodes = editorState.document.root.children.map((node) {
      final json = jsonDecode(jsonEncode(encodeNodeWithIds(node))) as Map;
      return decodeNodeWithIds(json.cast<String, Object>());
    }).toList();
    _pending = (nodes: nodes, generation: _generation);
    if (!_hasConflict) _setStatus(SaveStatus.saving);
    return _saving ??= _drain().whenComplete(() => _saving = null);
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final snapshot = _pending!;
      _pending = null;
      // Concurrent flush requests can enqueue the same generation.
      if (snapshot.generation <= _savedGeneration) continue;
      try {
        await repository.saveDraft(draftId, pageId, _version, snapshot.nodes);
        if (_hasConflict) {
          _setStatus(SaveStatus.conflict);
          continue;
        }
        _version = await repository.savePageNodes(
          pageId,
          snapshot.nodes,
          expectedVersion: _version,
        );
        await repository.deleteDraft(draftId, recoveredDraft: recoveredDraft);
        _savedGeneration = snapshot.generation;
        _setStatus(
          _savedGeneration == _generation
              ? SaveStatus.saved
              : SaveStatus.saving,
        );
      } on DocumentConflictException {
        _hasConflict = true;
        _setStatus(SaveStatus.conflict);
      } catch (_) {
        // Keep the draft dirty; a later edit or explicit flush can retry it.
        _pending = null;
        _setStatus(SaveStatus.error);
        return;
      }
    }
  }

  /// Retry the local draft only against the version the user reviewed.
  Future<bool> useLocalVersion(String reviewedVersion) async {
    await forceSave();
    if (_isDisposed) return false;
    _version = reviewedVersion;
    _hasConflict = false;
    _savedGeneration = -1;
    await forceSave();
    _resolved = statusNotifier.value == SaveStatus.saved;
    return _resolved;
  }

  Future<void> useSavedVersion(String reviewedVersion) async {
    await forceSave();
    await repository.discardDraft(
      draftId,
      pageId,
      reviewedVersion,
      recoveredDraft: recoveredDraft,
    );
    _resolved = true;
  }

  void dispose() {
    // A flush already requested by the owner drains its captured snapshots even
    // after disposal, without reading EditorState or notifying disposed widgets.
    _isDisposed = true;
    _debounceTimer?.cancel();
    _subscription?.cancel();
    statusNotifier.dispose();
  }
}

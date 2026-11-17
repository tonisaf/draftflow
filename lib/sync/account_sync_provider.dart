import '../data/notes_repository.dart';
import 'sync_engine.dart';

abstract interface class AccountSyncProvider {
  bool canSync(String userId);
  NotesSyncEngine createSync(
    NotesRepository repository,
    String userId,
    void Function() onRemoteApplied,
    Future<bool> Function(Future<bool> Function()) applyRemote,
  );
}

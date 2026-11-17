import '../sync/account_sync_provider.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_store.dart';
import '../sync/supabase_notes_transport.dart';
import '../data/notes_repository.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

import 'account_controller.dart';
import 'session_store.dart';

class SupabaseAccountAuth implements AccountAuth, AccountSyncProvider {
  SupabaseAccountAuth({required this.client, required this.store}) {
    _subscription = client.auth.onAuthStateChange.listen(
      (event) {
        if (_allowPersistence &&
            event.event == AuthChangeEvent.tokenRefreshed &&
            event.session != null) {
          unawaited(
            _persist(event.session!).catchError((Object _) {
              _report(
                const AccountFailure(
                  'Не удалось сохранить сессию в защищённом хранилище.',
                ),
              );
            }),
          );
        } else if (event.event == AuthChangeEvent.signedOut &&
            !_explicitSignOut) {
          unawaited(_forget());
        }
      },
      onError: (Object _) {
        _report(const AccountFailure('Сессия требует повторной проверки.'));
      },
    );
  }
  static SupabaseAccountAuth? fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || key.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const AccountFailure('Неверная конфигурация сервера аккаунтов.');
    }
    return SupabaseAccountAuth(
      client: SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      ),
      store: SecureSessionStore(uri.host),
    );
  }

  final SupabaseClient client;
  final SessionStore store;
  final _changes = StreamController<NotesIdentity?>.broadcast();
  StreamSubscription<AuthState>? _subscription;
  Future<void> _writes = Future.value();
  bool _explicitSignOut = false;
  bool _allowPersistence = true;
  bool _closing = false;
  void _report(AccountFailure failure) {
    if (!_closing) {
      _changes.addError(failure);
    }
  }

  @override
  Stream<NotesIdentity?> get changes => _changes.stream;
  NotesIdentity _identity(Session session, {bool requiresSignIn = false}) =>
      NotesIdentity(
        session.user.id,
        session.user.email ?? '',
        requiresSignIn: requiresSignIn,
      );
  Future<void> _save(String? value) {
    final write = _writes.then((_) => store.write(value));
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> _persist(Session session) => _save(jsonEncode(session.toJson()));
  Future<void> _forget() async {
    try {
      await _save(null);
      if (!_closing) _changes.add(null);
    } catch (_) {
      _report(const AccountFailure('Не удалось удалить сохранённую сессию.'));
    }
  }

  @override
  Future<NotesIdentity?> restore() async {
    String? saved;
    try {
      saved = await store.read();
    } catch (_) {
      throw const AccountFailure(
        'Защищённое хранилище недоступно. Повторите вход позже.',
      );
    }
    if (saved == null) return null;
    late Session cached;
    try {
      cached = Session.fromJson(jsonDecode(saved) as Map<String, dynamic>)!;
    } catch (_) {
      await _save(null);
      return null;
    }
    try {
      if (cached.isExpired) return _identity(cached, requiresSignIn: true);
      final response = await client.auth.recoverSession(saved);
      final session = response.session;
      if (session == null) return null;
      await _persist(session);
      return _identity(session);
    } on SocketException {
      return _identity(cached, requiresSignIn: true);
    } on TimeoutException {
      return _identity(cached, requiresSignIn: true);
    } on AuthException catch (e) {
      final status = int.tryParse(e.statusCode ?? '');
      if (status != null && status >= 400 && status < 500 && status != 429) {
        await _save(null);
        return null;
      }
      return _identity(cached, requiresSignIn: true);
    }
  }

  Future<NotesIdentity> _accept(Session session) async {
    _allowPersistence = true;
    try {
      await _persist(session);
    } catch (_) {
      _allowPersistence = false;
      _explicitSignOut = true;
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        /* The SDK clears local credentials before server revocation. */
      } finally {
        _explicitSignOut = false;
      }
      throw const AccountFailure(
        'Не удалось сохранить вход в защищённом хранилище.',
      );
    }
    return _identity(session);
  }

  @override
  Future<NotesIdentity> signIn(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        throw const AccountFailure('Подтвердите email перед входом.');
      }
      return await _accept(session);
    } on AuthException {
      throw const AccountFailure(
        'Не удалось войти. Проверьте email, пароль и подтверждение почты.',
      );
    }
  }

  @override
  Future<NotesIdentity?> signUp(String email, String password) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      return response.session == null ? null : await _accept(response.session!);
    } on AuthException {
      throw const AccountFailure(
        'Не удалось создать аккаунт. Проверьте данные или попробуйте войти.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    // Delete the persistent credential before presenting a successful sign-out.
    _allowPersistence = false;
    _explicitSignOut = true;
    try {
      await _save(null);
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        if (client.auth.currentSession != null) rethrow;
        // Server revocation may fail offline; the local credential is gone.
      }
    } catch (_) {
      _allowPersistence = true;
      rethrow;
    } finally {
      _explicitSignOut = false;
    }
  }

  @override
  bool canSync(String userId) => client.auth.currentUser?.id == userId;
  @override
  NotesSyncEngine createSync(
    NotesRepository repository,
    String userId,
    void Function() onRemoteApplied,
    Future<bool> Function(Future<bool> Function()) applyRemote,
  ) => NotesSyncEngine(
    store: SyncStore(repository.db),
    transport: SupabaseNotesTransport(client, userId),
    onRemoteApplied: onRemoteApplied,
    applyRemote: applyRemote,
  );

  @override
  Future<void> dispose() async {
    _allowPersistence = false;
    _closing = true;
    await _subscription?.cancel();
    await _writes;
    await client.dispose();
    await _changes.close();
  }
}

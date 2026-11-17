import 'dart:async';

import 'package:notes_here/account/account_controller.dart';

class FakeAccountAuth implements AccountAuth {
  final events = StreamController<NotesIdentity?>.broadcast();
  NotesIdentity? identity;
  bool confirmation = false;
  int signIns = 0;
  int signOuts = 0;
  @override
  Stream<NotesIdentity?> get changes => events.stream;
  @override
  Future<NotesIdentity?> restore() async => identity;
  @override
  Future<NotesIdentity> signIn(String email, String password) async {
    signIns++;
    return identity!;
  }

  @override
  Future<NotesIdentity?> signUp(String email, String password) async =>
      confirmation ? null : identity;
  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  Future<void> dispose() => events.close();
}

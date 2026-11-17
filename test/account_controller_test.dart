import 'package:notes_here/services/database_cell_saves.dart';

import 'support/fake_account_auth.dart';

import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/account/account_controller.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';

void main() {
  late FakeAccountAuth auth;
  late AccountController accounts;
  late NotesRepository guest;
  late List<AppDatabase> databases;
  var opened = <String>[];
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    databases = [];
    NotesRepository makeRepository() {
      final db = AppDatabase(NativeDatabase.memory());
      databases.add(db);
      return NotesRepository(db);
    }

    guest = makeRepository();
    auth = FakeAccountAuth();
    opened = [];
    accounts = AccountController(
      guest: guest,
      auth: auth,
      openAccount: (id) async {
        opened.add(id);
        return makeRepository();
      },
    );
  });
  tearDown(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    accounts.dispose();
    for (final db in databases) {
      await db.close();
    }
  });
  test(
    'guest and two accounts retain independent notes across sign-in/out',
    () async {
      await guest.createPage(title: 'Guest note');
      auth.identity = const NotesIdentity('a', 'a@example.com');
      expect(await accounts.signIn('a@example.com', 'password'), isTrue);
      final first = accounts.repository;
      expect(await first.db.getAllPages(), isEmpty);
      await first.createPage(title: 'Account A');
      await accounts.signOut();
      expect(accounts.repository, same(guest));
      expect((await guest.db.getAllPages()).single.title, 'Guest note');
      auth.identity = const NotesIdentity('b', 'b@example.com');
      await accounts.signIn('b@example.com', 'password');
      expect(await accounts.repository.db.getAllPages(), isEmpty);
      await accounts.signOut();
      auth.identity = const NotesIdentity('a', 'a@example.com');
      await accounts.signIn('a@example.com', 'password');
      expect(accounts.repository, same(first));
      expect(
        (await accounts.repository.db.getAllPages()).single.title,
        'Account A',
      );
      expect(opened, ['a', 'b']);
    },
  );
  test(
    'failed cell drafts block account switching even without an open editor',
    () async {
      auth.identity = const NotesIdentity('a', 'a@example.com');
      expect(await accounts.signIn('a@example.com', 'password'), isTrue);
      final repository = accounts.repository;
      final saves = DatabaseCellSaves.forRepository(repository);
      await saves.submit((
        databaseId: 'missing',
        rowId: 'missing',
        columnId: 'c',
        title: false,
      ), 'draft');
      expect(await accounts.signOut(), isFalse);
      expect(accounts.repository, same(repository));
      expect(accounts.account?.id, 'a');
      expect(saves.forDatabase('missing').single.desired, 'draft');
      saves.discardFailed('missing');
      expect(await accounts.signOut(), isTrue);
    },
  );

  test('save barrier completes before auth or workspace changes; concurrent commands rejected', () async {
    auth.identity = const NotesIdentity('a', 'a@example.com');
    final barrier = Completer<void>();
    var flushCalls = 0;
    Future<void> save() async {
      if (++flushCalls == 1) await barrier.future;
    }

    accounts.registerSaver(save);
    final signingIn = accounts.signIn('a@example.com', 'password');
    expect(accounts.busy, isTrue);
    expect(auth.signIns, 0);
    expect(accounts.repository, same(guest));
    expect(await accounts.signOut(), isFalse);
    barrier.complete();
    expect(await signingIn, isTrue);
    accounts.unregisterSaver(save);
    expect(auth.signIns, 1);
  });
  test('save failure blocks signout and retains workspace', () async {
    auth.identity = const NotesIdentity('a', 'a@example.com');
    await accounts.signIn('a@example.com', 'password');
    final current = accounts.repository;
    accounts.registerSaver(() async {
      throw const AccountFailure('Save failed');
    });
    expect(await accounts.signOut(), isFalse);
    expect(accounts.repository, same(current));
    expect(accounts.account?.id, 'a');
    expect(auth.signOuts, 0);
    expect(accounts.error, 'Save failed');
  });
  test(
    'email confirmation keeps guest workspace and explains next step',
    () async {
      auth.confirmation = true;
      expect(await accounts.signUp('a@example.com', 'password'), isTrue);
      expect(accounts.repository, same(guest));
      expect(accounts.account, isNull);
      expect(accounts.notice, contains('Подтвердите email'));
      expect(opened, isEmpty);
    },
  );
  test('restore selects cached account without moving guest data', () async {
    auth.identity = const NotesIdentity('a', 'a@example.com');
    expect(await accounts.restore(), isTrue);
    expect(accounts.account?.id, 'a');
    expect(accounts.repository, isNot(same(guest)));
  });
}

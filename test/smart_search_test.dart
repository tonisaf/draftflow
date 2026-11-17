import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('smart search: extracts snippet and ranks title matches over content matches', () async {
    final page1 = await repo.createPage(title: 'Flutter Guide');
    final page2 = await repo.createPage(title: 'Setup Environment');

    await repo.savePageNodes(page2, [
      paragraphNode(text: 'In this step we install the flutter development tools and engine'),
    ]);

    final results = await repo.searchPages('flutter');

    expect(results.length, 2);
    // Title match has higher score than content match
    expect(results[0].page.id, page1);
    expect(results[0].score, greaterThan(results[1].score));
    expect(results[0].isContentMatch, false);

    // Content match has snippet
    expect(results[1].page.id, page2);
    expect(results[1].isContentMatch, true);
    expect(results[1].snippet, isNotNull);
    expect(results[1].snippet!.toLowerCase(), contains('flutter'));
  });

  test('smart search: detects Quick Notes and tags in search results', () async {
    final noteId = await repo.createPage(title: 'Idea for Startup');
    await repo.updatePageSettings(noteId, isQuickNote: true, tag: 'Идея');

    final results = await repo.searchPages('Startup');
    expect(results.length, 1);
    expect(results.first.isQuickNote, isTrue);
    expect(results.first.matchedTag, 'Идея');
  });

  test('smart search: finds Cyrillic content case-insensitively and extracts snippet', () async {
    final pageId = await repo.createPage(title: 'Скиллы агентов');

    await repo.savePageNodes(pageId, [
      bulletedListNode(
        text: 'Как работает: агент читает информацию о проекте и передаёт задачу видеогенератору Hyperframes',
      ),
    ]);

    // Test with lowercase query
    final resultsLower = await repo.searchPages('как работает');
    expect(resultsLower.length, 1);
    expect(resultsLower.first.page.id, pageId);
    expect(resultsLower.first.isContentMatch, isTrue);
    expect(resultsLower.first.snippet, isNotNull);
    expect(resultsLower.first.snippet, contains('Как работает: агент читает информацию'));

    // Test with title case query matching user's screenshot
    final resultsTitleCase = await repo.searchPages('Как работает');
    expect(resultsTitleCase.length, 1);
    expect(resultsTitleCase.first.page.id, pageId);
    expect(resultsTitleCase.first.snippet, isNotNull);

    // Test with single word
    final resultsWord = await repo.searchPages('видеогенератору');
    expect(resultsWord.length, 1);
    expect(resultsWord.first.page.id, pageId);
  });

  test('smart search: Phase 2 Fuzzy search finds pages despite typos', () async {
    final pageId = await repo.createPage(title: 'Скиллы агентов');
    await repo.savePageNodes(pageId, [
      paragraphNode(text: 'Инструкция по настройке видеогенератора и скриптов проекта'),
    ]);

    // Typo in title: 'скилы' (missing double 'л')
    final typoTitleResults = await repo.searchPages('скилы');
    expect(typoTitleResults.isNotEmpty, isTrue);
    expect(typoTitleResults.first.page.id, pageId);
    expect(typoTitleResults.first.isFuzzyMatch, isTrue);

    // Typo in content: 'скриптв' instead of 'скриптов'
    final typoContentResults = await repo.searchPages('скриптв');
    expect(typoContentResults.isNotEmpty, isTrue);
    expect(typoContentResults.first.page.id, pageId);
    expect(typoContentResults.first.isFuzzyMatch, isTrue);
  });

  test('smart search: Phase 2 Recent search queries management', () async {
    await repo.clearRecentSearchQueries();
    expect(await repo.getRecentSearchQueries(), isEmpty);

    await repo.addRecentSearchQuery('Как работает');
    await repo.addRecentSearchQuery('Flutter');
    var list = await repo.getRecentSearchQueries();
    expect(list, ['Flutter', 'Как работает']);

    await repo.removeRecentSearchQuery('Flutter');
    list = await repo.getRecentSearchQueries();
    expect(list, ['Как работает']);

    await repo.clearRecentSearchQueries();
    expect(await repo.getRecentSearchQueries(), isEmpty);
  });
}

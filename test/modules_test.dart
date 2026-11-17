import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/modules/core/app_module.dart';
import 'package:notes_here/modules/core/module_manager.dart';
import 'package:notes_here/modules/tmdb/models/tmdb_media_item.dart';
import 'package:notes_here/modules/tmdb/services/tmdb_api_client.dart';
import 'package:notes_here/modules/tmdb/services/tmdb_database_sync.dart';
import 'package:notes_here/modules/tmdb/services/kinopoisk_service.dart';
import 'package:notes_here/modules/tmdb/tmdb_module.dart';

class MockModule implements AppModule {
  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final IconData icon;
  @override
  bool isConfigured;

  MockModule({
    required this.id,
    required this.title,
    this.description = 'Test module',
    this.icon = Icons.extension,
    this.isConfigured = true,
  });

  @override
  Widget buildSettings(BuildContext context, {required NotesRepository repository}) =>
      const SizedBox();

  @override
  Widget buildView(
    BuildContext context, {
    required NotesRepository repository,
    required ValueChanged<String> onOpenPage,
  }) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppModuleManager', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('registers modules and toggles enabled state', () async {
      final manager = AppModuleManager();
      final mod1 = MockModule(id: 'test_mod', title: 'Test Module');
      manager.register(mod1);

      expect(manager.allModules.length, 1);
      expect(manager.enabledModules, isEmpty);
      expect(manager.isEnabled('test_mod'), isFalse);

      bool notified = false;
      manager.addListener(() => notified = true);

      await manager.setEnabled('test_mod', true);

      expect(manager.isEnabled('test_mod'), isTrue);
      expect(manager.enabledModules.length, 1);
      expect(manager.enabledModules.first.id, 'test_mod');
      expect(notified, isTrue);

      // Disable
      notified = false;
      await manager.setEnabled('test_mod', false);
      expect(manager.isEnabled('test_mod'), isFalse);
      expect(manager.enabledModules, isEmpty);
      expect(notified, isTrue);
    });

    test('persists enabled modules to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'module_enabled_persisted_mod': true});

      final manager = AppModuleManager();
      final mod = MockModule(id: 'persisted_mod', title: 'Persisted Module');
      manager.register(mod);

      await manager.loadPreferences();

      expect(manager.isLoaded, isTrue);
      expect(manager.isEnabled('persisted_mod'), isTrue);
      expect(manager.enabledModules.length, 1);
    });
  });

  group('TmdbMediaItem', () {
    test('parses movie JSON correctly', () {
      final json = {
        'id': 550,
        'media_type': 'movie',
        'title': 'Fight Club',
        'original_title': 'Fight Club',
        'overview': 'An insomniac office worker...',
        'poster_path': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
        'backdrop_path': '/hZkgoQYus5vegHoetLkCJzb17zJ.jpg',
        'release_date': '1999-10-15',
        'vote_average': 8.433,
        'vote_count': 26000,
        'genres': [
          {'id': 18, 'name': 'Drama'},
        ],
      };

      final item = TmdbMediaItem.fromJson(json);

      expect(item.id, 550);
      expect(item.mediaType, 'movie');
      expect(item.title, 'Fight Club');
      expect(item.year, '1999');
      expect(item.voteAverage, closeTo(8.43, 0.01));
      expect(item.posterUrl('w500'), 'https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg');
      expect(item.genres, contains('Drama'));
    });

    test('parses TV show JSON correctly', () {
      final json = {
        'id': 1396,
        'media_type': 'tv',
        'name': 'Breaking Bad',
        'original_name': 'Breaking Bad',
        'first_air_date': '2008-01-20',
        'vote_average': 8.9,
      };

      final item = TmdbMediaItem.fromJson(json);

      expect(item.id, 1396);
      expect(item.mediaType, 'tv');
      expect(item.title, 'Breaking Bad');
      expect(item.year, '2008');
    });

    test('parses movie crew and cast with key roles correctly', () {
      final json = {
        'id': 206487,
        'title': 'Predestination',
        'credits': {
          'crew': [
            {'name': 'Michael Spierig', 'job': 'Director'},
            {'name': 'Peter Spierig', 'job': 'Director'},
            {'name': 'Robert A. Heinlein', 'job': 'Author'},
            {'name': 'Peter Spierig', 'job': 'Original Music Composer'},
          ],
          'cast': [
            {'name': 'Ethan Hawke', 'character': 'The Bartender', 'profile_path': '/ethan.jpg'},
            {'name': 'Sarah Snook', 'character': 'The Unmarried Mother', 'profile_path': '/sarah.jpg'},
          ],
        },
      };

      final item = TmdbMediaItem.fromJson(json);

      expect(item.directors.length, 2);
      expect(item.directors.first.name, 'Michael Spierig');
      expect(item.directors.first.job, 'Режиссёр');
      expect(item.writers.length, 1);
      expect(item.writers.first.name, 'Robert A. Heinlein');
      expect(item.writers.first.job, 'Сценарист');
      expect(item.composers.length, 1);
      expect(item.composers.first.name, 'Peter Spierig');
      expect(item.composers.first.job, 'Композитор');
      expect(item.cast.length, 2);
      expect(item.cast.first.name, 'Ethan Hawke');
      expect(item.cast.first.character, 'The Bartender');
    });

    test('parses TV show created_by correctly into crew', () {
      final json = {
        'id': 1396,
        'media_type': 'tv',
        'name': 'Breaking Bad',
        'created_by': [
          {'name': 'Vince Gilligan', 'profile_path': '/vince.jpg'},
        ],
      };

      final item = TmdbMediaItem.fromJson(json);

      expect(item.directors.length, 1);
      expect(item.directors.first.name, 'Vince Gilligan');
      expect(item.directors.first.job, 'Создатель');
      expect(item.director, 'Vince Gilligan');
    });

    test('parses external IDs and Kinopoisk ratings correctly', () {
      final json = {
        'id': 206487,
        'title': 'Predestination',
        'external_ids': {
          'imdb_id': 'tt206487',
        },
        'kp_rating': 7.7,
        'kp_votes': 150000,
        'kp_id': 679828,
        'imdb_rating': 7.4,
      };

      final item = TmdbMediaItem.fromJson(json);

      expect(item.imdbId, 'tt206487');
      expect(item.kpRating, 7.7);
      expect(item.kpVotes, 150000);
      expect(item.kpId, 679828);
      expect(item.imdbRating, 7.4);
      expect(item.kinopoiskWebUrl, 'https://www.kinopoisk.ru/film/679828/');
      expect(item.imdbWebUrl, 'https://www.imdb.com/title/tt206487/');
    });
  });

  group('KinopoiskService', () {
    test('fetches rating successfully from kinopoisk.dev API', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('api.kinopoisk.dev')) {
          expect(request.headers['X-API-KEY'], 'mock_token');
          return http.Response(
            jsonEncode({
              'docs': [
                {
                  'id': 679828,
                  'rating': {'kp': 7.72, 'imdb': 7.4},
                  'votes': {'kp': 185000, 'imdb': 290000},
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = KinopoiskService(client: mockClient);
      final data = await service.fetchRating(
        apiKey: 'mock_token',
        imdbId: 'tt206487',
        title: 'Predestination',
      );

      expect(data, isNotNull);
      expect(data!.kpId, 679828);
      expect(data.kpRating, closeTo(7.7, 0.05));
      expect(data.kpVotes, 185000);
      expect(data.imdbRating, 7.4);
      expect(data.webUrl, 'https://www.kinopoisk.ru/film/679828/');
    });
  });

  group('TmdbApiClient', () {
    test('searchMulti sends query and parses results', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/3/search/multi');
        expect(request.url.queryParameters['query'], 'Inception');
        expect(request.headers['Authorization'], 'Bearer fake_read_access_token_which_is_long_enough_to_be_jwt');

        final responseBody = {
          'page': 1,
          'results': [
            {
              'id': 27205,
              'media_type': 'movie',
              'title': 'Inception',
              'release_date': '2010-07-15',
              'vote_average': 8.4,
            },
          ],
        };
        return http.Response(jsonEncode(responseBody), 200);
      });

      final client = TmdbApiClient(client: mockClient);
      final results = await client.searchMulti(
        apiToken: 'fake_read_access_token_which_is_long_enough_to_be_jwt',
        query: 'Inception',
      );

      expect(results.length, 1);
      expect(results.first.title, 'Inception');
      expect(results.first.year, '2010');
    });

    test('getRecommendations parses movie recommendations', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/3/movie/27205/recommendations');
        return http.Response(
          jsonEncode({
            'page': 1,
            'results': [
              {
                'id': 157336,
                'media_type': 'movie',
                'title': 'Interstellar',
                'release_date': '2014-11-05',
                'vote_average': 8.6,
              },
            ],
          }),
          200,
        );
      });

      final client = TmdbApiClient(client: mockClient);
      final results = await client.getRecommendations(
        apiToken: 'fake_jwt_token_for_testing_recommendations_flow_123',
        id: 27205,
        mediaType: 'movie',
      );

      expect(results.length, 1);
      expect(results.first.id, 157336);
      expect(results.first.title, 'Interstellar');
      expect(results.first.year, '2014');
    });

    test('discoverMedia queries by genres and minimum rating', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/3/discover/movie');
        expect(request.url.queryParameters['with_genres'], '878');
        expect(request.url.queryParameters['vote_average.gte'], '7.5');
        return http.Response(
          jsonEncode({
            'page': 1,
            'results': [
              {
                'id': 603,
                'title': 'The Matrix',
                'release_date': '1999-03-30',
                'vote_average': 8.2,
              },
            ],
          }),
          200,
        );
      });

      final client = TmdbApiClient(client: mockClient);
      final results = await client.discoverMedia(
        apiToken: 'fake_jwt_token_for_testing_recommendations_flow_123',
        withGenres: [878],
        voteAverageGte: 7.5,
      );

      expect(results.length, 1);
      expect(results.first.id, 603);
      expect(results.first.title, 'The Matrix');
    });

    test('OAuth authentication flow methods', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/3/authentication/token/new') {
          return http.Response(jsonEncode({'success': true, 'request_token': 'req_tok_123'}), 200);
        }
        if (request.url.path == '/3/authentication/session/new') {
          return http.Response(jsonEncode({'success': true, 'session_id': 'sess_id_456'}), 200);
        }
        if (request.url.path == '/3/account') {
          return http.Response(
            jsonEncode({
              'id': 999,
              'username': 'cinephile',
              'name': 'Movie Fan',
              'avatar': {
                'tmdb': {'avatar_path': '/avatar.jpg'},
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = TmdbApiClient(client: mockClient);
      const token = 'fake_api_token_very_long_so_it_qualifies_as_jwt_string';

      final reqToken = await client.createRequestToken(apiToken: token);
      expect(reqToken, 'req_tok_123');

      final authUrl = client.buildAuthUrl(reqToken);
      expect(authUrl, 'https://www.themoviedb.org/authenticate/req_tok_123');

      final sessionId = await client.createSession(apiToken: token, requestToken: reqToken);
      expect(sessionId, 'sess_id_456');

      final account = await client.getAccountDetails(apiToken: token, sessionId: sessionId);
      expect(account.id, 999);
      expect(account.username, 'cinephile');
      expect(account.avatarUrl(), contains('avatar.jpg'));
    });
  });

  group('TmdbDatabaseSync', () {
    late AppDatabase db;
    late NotesRepository repository;
    late TmdbDatabaseSync sync;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = NotesRepository(db);
      sync = TmdbDatabaseSync(repository: repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates TMDB database with standard columns on first call', () async {
      final database = await sync.getOrCreateDatabase();

      expect(database.title, TmdbDatabaseSync.dbTitle);
      expect(database.icon, '🎬');

      final columns = await db.getColumnsForDatabase(database.id);
      final columnNames = columns.map((c) => c.name).toList();

      expect(columnNames, contains('Name'));
      expect(columnNames, contains('Type'));
      expect(columnNames, contains('TMDB ID'));
      expect(columnNames, contains('Status'));
      expect(columnNames, contains('Year'));
      expect(columnNames, contains('TMDB Rating'));
      expect(columnNames, contains('Favorite'));
      expect(columnNames, contains('Poster'));
    });

    test('saves and watches media items reactively as database rows', () async {
      const movie = TmdbMediaItem(
        id: 550,
        mediaType: 'movie',
        title: 'Fight Club',
        releaseDate: '1999-10-15',
        voteAverage: 8.4,
        status: 'watchlist',
        isFavorite: true,
        kpRating: 8.7,
        kpVotes: 950000,
        kpId: 361,
        imdbId: 'tt0137523',
        imdbRating: 8.8,
      );

      final pageId = await sync.saveMediaItem(movie, syncToTmdb: false);
      expect(pageId, isNotEmpty);

      // Verify page was created in database
      final page = await repository.getPage(pageId);
      expect(page, isNotNull);
      expect(page!.title, 'Fight Club');
      expect(page.icon, '🎬');

      // Verify mapped back to TmdbMediaItem
      final loaded = await sync.loadLocalItems();
      expect(loaded.length, 1);
      expect(loaded.first.id, 550);
      expect(loaded.first.title, 'Fight Club');
      expect(loaded.first.status, 'watchlist');
      expect(loaded.first.isFavorite, isTrue);
      expect(loaded.first.kpRating, 8.7);
      expect(loaded.first.kpVotes, 950000);
      expect(loaded.first.kpId, 361);
      expect(loaded.first.imdbId, 'tt0137523');
      expect(loaded.first.imdbRating, 8.8);

      // Update existing item status
      final updated = movie.copyWith(status: 'watched', userRating: 9.5);
      await sync.saveMediaItem(updated, syncToTmdb: false);

      final reloaded = await sync.loadLocalItems();
      expect(reloaded.length, 1);
      expect(reloaded.first.status, 'watched');
      expect(reloaded.first.userRating, 9.5);
    });
  });

  group('TmdbModule integration', () {
    test('implements AppModule contract', () async {
      final module = TmdbModule();
      expect(module.id, 'tmdb');
      expect(module.title, 'Фильмы и Сериалы');
      expect(module.icon, Icons.movie_outlined);
      expect(module.isConfigured, isFalse);
    });
  });
}

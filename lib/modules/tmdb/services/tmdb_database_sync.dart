import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/db/app_database.dart';
import '../../../data/notes_repository.dart';
import '../models/tmdb_media_item.dart';
import 'tmdb_api_client.dart';
import 'tmdb_config_service.dart';

class TmdbDatabaseSync {
  static const _prefDbId = 'tmdb_database_id';
  static const dbTitle = 'Фильмы и Сериалы (TMDB)';

  final NotesRepository repository;

  TmdbDatabaseSync({required this.repository});

  /// Finds or creates the dedicated TMDB database in Notes Here.
  Future<Database> getOrCreateDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefDbId);

    if (savedId != null) {
      final existing = await repository.db.getDatabaseById(savedId);
      if (existing != null && existing.trashedAt == null) {
        return existing;
      }
    }

    // Check if one already exists by title
    final allDbs = await repository.db.getAllDatabases();
    final match = allDbs.cast<Database?>().firstWhere(
      (d) => d?.title == dbTitle && d?.trashedAt == null,
      orElse: () => null,
    );
    if (match != null) {
      await prefs.setString(_prefDbId, match.id);
      return match;
    }

    // Create a new database with columns
    final newDbId = await repository.createDatabase(
      title: dbTitle,
      icon: '🎬',
      initialColumns: [
        (name: 'Name', type: 'title', options: null, width: 220.0),
        (
          name: 'Type',
          type: 'select',
          options: jsonEncode([
            {'id': 'movie', 'label': 'Фильм', 'color': '0xFF3B82F6'},
            {'id': 'tv', 'label': 'Сериал', 'color': '0xFF8B5CF6'},
          ]),
          width: 110.0,
        ),
        (name: 'TMDB ID', type: 'text', options: null, width: 90.0),
        (
          name: 'Status',
          type: 'status',
          options: jsonEncode([
            {'id': 'watchlist', 'label': 'В планах', 'color': '0xFF64748B'},
            {'id': 'watching', 'label': 'Смотрю', 'color': '0xFFEAB308'},
            {'id': 'watched', 'label': 'Просмотрено', 'color': '0xFF22C55E'},
            {'id': 'dropped', 'label': 'Брошено', 'color': '0xFFEF4444'},
          ]),
          width: 140.0,
        ),
        (name: 'Year', type: 'text', options: null, width: 80.0),
        (name: 'TMDB Rating', type: 'number', options: null, width: 100.0),
        (name: 'My Rating', type: 'number', options: null, width: 100.0),
        (name: 'Favorite', type: 'checkbox', options: null, width: 80.0),
        (name: 'Poster', type: 'url', options: null, width: 150.0),
        (name: 'Overview', type: 'text', options: null, width: 260.0),
      ],
    );

    await prefs.setString(_prefDbId, newDbId);
    final created = await repository.db.getDatabaseById(newDbId);
    return created!;
  }

  /// Maps a database row [Page] to a [TmdbMediaItem].
  Future<TmdbMediaItem?> pageToMediaItem(Page page, List<DatabaseColumn> columns) async {
    if (page.properties == null || page.properties!.isEmpty) return null;

    Map<String, dynamic> props = {};
    try {
      props = jsonDecode(page.properties!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    // Helper to find value by column name
    dynamic getColVal(String name) {
      final col = columns.cast<DatabaseColumn?>().firstWhere(
        (c) => c?.name.toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (col == null) return null;
      return props[col.id];
    }

    final rawId = getColVal('TMDB ID');
    final tmdbId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (tmdbId == null) return null;

    final mediaType = (getColVal('Type') as String?) ?? 'movie';
    final status = (getColVal('Status') as String?) ?? 'watchlist';
    final year = getColVal('Year')?.toString();
    final tmdbRating = (getColVal('TMDB Rating') as num?)?.toDouble();
    final myRating = (getColVal('My Rating') as num?)?.toDouble();
    final isFavorite = (getColVal('Favorite') as bool?) ?? false;
    final poster = (getColVal('Poster') as String?) ?? page.cover;
    final overview = getColVal('Overview')?.toString();
    final personalNote = props['personal_note']?.toString();
    final originalTitle = props['original_title']?.toString();
    final tagline = props['tagline']?.toString();
    final backdropPath = props['backdrop_path']?.toString();
    final director = props['director']?.toString();
    final trailerKey = props['trailer_key']?.toString();
    final rawRuntime = props['runtime'];
    final runtime = rawRuntime is int ? rawRuntime : int.tryParse(rawRuntime?.toString() ?? '');

    List<String> genres = [];
    if (props['genres'] is List) {
      genres = (props['genres'] as List).map((g) => g.toString()).toList();
    }

    List<TmdbCastMember> cast = [];
    if (props['cast'] is List) {
      cast = (props['cast'] as List)
          .whereType<Map>()
          .map((c) => TmdbCastMember.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    List<TmdbCrewMember> crew = [];
    if (props['crew'] is List) {
      crew = (props['crew'] as List)
          .whereType<Map>()
          .map((c) => TmdbCrewMember.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    String? releaseDate = props['release_date']?.toString() ?? year;
    if (releaseDate != null && releaseDate.isNotEmpty && !releaseDate.contains('-')) {
      releaseDate = '$releaseDate-01-01';
    }

    final rawKpRating = props['kp_rating'];
    final kpRating = rawKpRating is num ? rawKpRating.toDouble() : double.tryParse(rawKpRating?.toString() ?? '');
    final rawKpVotes = props['kp_votes'];
    final kpVotes = rawKpVotes is num ? rawKpVotes.toInt() : int.tryParse(rawKpVotes?.toString() ?? '');
    final rawKpId = props['kp_id'];
    final kpId = rawKpId is num ? rawKpId.toInt() : int.tryParse(rawKpId?.toString() ?? '');
    final imdbId = props['imdb_id']?.toString();
    final rawImdbRating = props['imdb_rating'];
    final imdbRating = rawImdbRating is num ? rawImdbRating.toDouble() : double.tryParse(rawImdbRating?.toString() ?? '');

    return TmdbMediaItem(
      id: tmdbId,
      mediaType: mediaType,
      title: page.title.isNotEmpty ? page.title : 'Без названия',
      originalTitle: originalTitle,
      tagline: tagline,
      overview: overview,
      posterPath: poster,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      runtime: runtime,
      director: director,
      voteAverage: tmdbRating,
      userRating: myRating,
      status: status,
      isFavorite: isFavorite,
      genres: genres,
      cast: cast,
      crew: crew,
      trailerKey: trailerKey,
      pageId: page.id,
      personalNote: personalNote,
      imdbId: imdbId,
      imdbRating: imdbRating,
      kpRating: kpRating,
      kpVotes: kpVotes,
      kpId: kpId,
    );
  }

  /// Loads all local media items stored in the TMDB database.
  Future<List<TmdbMediaItem>> loadLocalItems() async {
    final database = await getOrCreateDatabase();
    final columns = await repository.db.getColumnsForDatabase(database.id);
    final rows = await repository.getDatabaseRows(database.id);

    final List<TmdbMediaItem> items = [];
    for (final row in rows) {
      final item = await pageToMediaItem(row, columns);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  /// Watches all local media items reactively.
  Stream<List<TmdbMediaItem>> watchLocalItems() async* {
    final database = await getOrCreateDatabase();
    await for (final rows in repository.watchDatabaseRows(database.id)) {
      final columns = await repository.db.getColumnsForDatabase(database.id);
      final List<TmdbMediaItem> items = [];
      for (final row in rows) {
        final item = await pageToMediaItem(row, columns);
        if (item != null) {
          items.add(item);
        }
      }
      yield items;
    }
  }

  /// Adds a new media item or updates an existing one in the database.
  Future<String> saveMediaItem(
    TmdbMediaItem item, {
    TmdbApiClient? client,
    TmdbConfigService? config,
    bool syncToTmdb = true,
  }) async {
    final database = await getOrCreateDatabase();
    final columns = await repository.db.getColumnsForDatabase(database.id);
    final rows = await repository.getDatabaseRows(database.id);

    // Find column IDs
    String? getColId(String name) => columns
        .cast<DatabaseColumn?>()
        .firstWhere((c) => c?.name.toLowerCase() == name.toLowerCase(), orElse: () => null)
        ?.id;

    final typeColId = getColId('Type');
    final tmdbIdColId = getColId('TMDB ID');
    final statusColId = getColId('Status');
    final yearColId = getColId('Year');
    final tmdbRatingColId = getColId('TMDB Rating');
    final myRatingColId = getColId('My Rating');
    final favColId = getColId('Favorite');
    final posterColId = getColId('Poster');
    final overviewColId = getColId('Overview');

    // Check if already in database
    Page? existingPage;
    for (final r in rows) {
      if (r.properties != null && tmdbIdColId != null) {
        try {
          final p = jsonDecode(r.properties!) as Map<String, dynamic>;
          final idVal = p[tmdbIdColId];
          if (idVal?.toString() == item.id.toString()) {
            existingPage = r;
            break;
          }
        } catch (_) {}
      }
    }

    final posterUrl = item.posterUrl('w500') ?? item.posterPath;
    final props = <String, dynamic>{};
    if (typeColId != null) props[typeColId] = item.mediaType;
    if (tmdbIdColId != null) props[tmdbIdColId] = item.id.toString();
    if (statusColId != null) props[statusColId] = item.status;
    if (yearColId != null) props[yearColId] = item.year;
    if (tmdbRatingColId != null) props[tmdbRatingColId] = item.voteAverage;
    if (myRatingColId != null) props[myRatingColId] = item.userRating;
    if (favColId != null) props[favColId] = item.isFavorite;
    if (posterColId != null && posterUrl != null) props[posterColId] = posterUrl;
    if (overviewColId != null && item.overview != null) props[overviewColId] = item.overview;
    if (item.personalNote != null) props['personal_note'] = item.personalNote;
    if (item.originalTitle != null) props['original_title'] = item.originalTitle;
    if (item.tagline != null) props['tagline'] = item.tagline;
    if (item.backdropPath != null) props['backdrop_path'] = item.backdropPath;
    if (item.director != null) props['director'] = item.director;
    if (item.trailerKey != null) props['trailer_key'] = item.trailerKey;
    if (item.runtime != null) props['runtime'] = item.runtime;
    if (item.releaseDate != null) props['release_date'] = item.releaseDate;
    if (item.genres.isNotEmpty) props['genres'] = item.genres;
    if (item.cast.isNotEmpty) props['cast'] = item.cast.map((c) => c.toJson()).toList();
    if (item.crew.isNotEmpty) props['crew'] = item.crew.map((c) => c.toJson()).toList();
    if (item.imdbId != null) props['imdb_id'] = item.imdbId;
    if (item.imdbRating != null) props['imdb_rating'] = item.imdbRating;
    if (item.kpRating != null) props['kp_rating'] = item.kpRating;
    if (item.kpVotes != null) props['kp_votes'] = item.kpVotes;
    if (item.kpId != null) props['kp_id'] = item.kpId;

    String pageId;
    if (existingPage != null) {
      pageId = existingPage.id;
      // Merge properties
      Map<String, dynamic> merged = {};
      if (existingPage.properties != null) {
        try {
          merged = jsonDecode(existingPage.properties!) as Map<String, dynamic>;
        } catch (_) {}
      }
      merged.addAll(props);

      await repository.db.upsertPage(
        existingPage
            .toCompanion(true)
            .copyWith(
              title: drift.Value(item.title),
              properties: drift.Value(jsonEncode(merged)),
              cover: posterUrl != null ? drift.Value(posterUrl) : const drift.Value.absent(),
            ),
      );
    } else {
      pageId = await repository.createDatabaseRow(
        database.id,
        title: item.title,
        properties: props,
      );

      // Set cover and icon for the new page
      final created = await repository.getPage(pageId);
      if (created != null) {
        await repository.db.upsertPage(
          created.toCompanion(true).copyWith(
                icon: drift.Value(item.mediaType == 'tv' ? '📺' : '🎬'),
                cover: posterUrl != null ? drift.Value(posterUrl) : const drift.Value.absent(),
              ),
        );
      }
    }

    // Push changes to TMDB if user is connected
    if (syncToTmdb && client != null && config != null && config.isAccountConnected && config.hasApiToken) {
      try {
        final token = config.apiToken!;
        final sessionId = config.sessionId!;
        final accountId = config.accountInfo!.id;

        // Sync Watchlist
        final inWatchlist = item.status == 'watchlist';
        await client.setWatchlist(
          apiToken: token,
          sessionId: sessionId,
          accountId: accountId,
          mediaId: item.id,
          mediaType: item.mediaType,
          inWatchlist: inWatchlist,
        );

        // Sync Favorite
        await client.setFavorite(
          apiToken: token,
          sessionId: sessionId,
          accountId: accountId,
          mediaId: item.id,
          mediaType: item.mediaType,
          isFavorite: item.isFavorite,
        );

        // Sync Rating
        if (item.userRating != null) {
          await client.setRating(
            apiToken: token,
            sessionId: sessionId,
            mediaId: item.id,
            mediaType: item.mediaType,
            rating: item.userRating,
          );
        }
      } catch (e) {
        debugPrint('TmdbDatabaseSync: Failed to push to TMDB: $e');
      }
    }

    return pageId;
  }

  /// Removes the movie page by moving it to trash.
  Future<void> deleteMediaItem(TmdbMediaItem item) async {
    if (item.pageId != null) {
      await repository.trashPage(item.pageId!);
    }
  }

  /// Pulls Watchlist, Favorites, and Rated items from TMDB and merges them locally.
  Future<int> syncFromTmdb({
    required TmdbApiClient client,
    required TmdbConfigService config,
  }) async {
    if (!config.hasApiToken || !config.isAccountConnected || config.accountInfo == null) {
      return 0;
    }

    final token = config.apiToken!;
    final session = config.sessionId!;
    final accountId = config.accountInfo!.id;

    final watchlist = await client.fetchWatchlist(
      apiToken: token,
      sessionId: session,
      accountId: accountId,
    );
    final favorites = await client.fetchFavorites(
      apiToken: token,
      sessionId: session,
      accountId: accountId,
    );
    final rated = await client.fetchRated(
      apiToken: token,
      sessionId: session,
      accountId: accountId,
    );

    // Merge by TMDB ID
    final Map<int, TmdbMediaItem> merged = {};
    for (final item in watchlist) {
      merged[item.id] = item.copyWith(status: 'watchlist');
    }
    for (final item in rated) {
      final existing = merged[item.id];
      if (existing != null) {
        merged[item.id] = existing.copyWith(
          status: 'watched',
          userRating: item.userRating,
        );
      } else {
        merged[item.id] = item.copyWith(status: 'watched');
      }
    }
    for (final item in favorites) {
      final existing = merged[item.id];
      if (existing != null) {
        merged[item.id] = existing.copyWith(isFavorite: true);
      } else {
        merged[item.id] = item.copyWith(isFavorite: true);
      }
    }

    int syncedCount = 0;
    for (final item in merged.values) {
      await saveMediaItem(
        item,
        syncToTmdb: false, // Don't echo back to TMDB during pull
      );
      syncedCount++;
    }

    return syncedCount;
  }
}

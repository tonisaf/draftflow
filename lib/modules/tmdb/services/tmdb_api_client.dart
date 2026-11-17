import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tmdb_media_item.dart';
import 'tmdb_config_service.dart';

class TmdbApiClient {
  static const _baseUrl = 'https://api.themoviedb.org/3';
  final http.Client _client;

  TmdbApiClient({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _buildHeaders(String apiToken) {
    final cleanToken = apiToken.trim();
    final headers = <String, String>{
      'Content-Type': 'application/json;charset=utf-8',
      'Accept': 'application/json',
    };
    if (cleanToken.length > 40) {
      // v4 Bearer token
      headers['Authorization'] = 'Bearer $cleanToken';
    }
    return headers;
  }

  Uri _buildUri(String path, String apiToken, [Map<String, dynamic>? queryParams]) {
    final cleanToken = apiToken.trim();
    final params = <String, String>{
      'language': 'ru-RU', // Default localization, can also fallback
    };
    if (cleanToken.length <= 40) {
      // Standard v3 API key
      params['api_key'] = cleanToken;
    }
    if (queryParams != null) {
      queryParams.forEach((key, value) {
        if (value != null) {
          params[key] = value.toString();
        }
      });
    }
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params);
  }

  /// Search movies and tv shows matching [query].
  Future<List<TmdbMediaItem>> searchMulti({
    required String apiToken,
    required String query,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = _buildUri('/search/multi', apiToken, {
      'query': query,
      'page': page,
      'include_adult': false,
    });

    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('TMDB Search error (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final mediaType = item['media_type'];
          return mediaType == 'movie' || mediaType == 'tv';
        })
        .map((item) => TmdbMediaItem.fromJson(item))
        .toList();
  }

  /// Get detailed info for movie or tv show.
  Future<TmdbMediaItem> getDetails({
    required String apiToken,
    required int id,
    required String mediaType, // 'movie' or 'tv'
  }) async {
    final uri = _buildUri('/$mediaType/$id', apiToken, {
      'append_to_response': 'credits,keywords,videos,external_ids',
    });

    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('TMDB details error (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    // Fallback: If credits or cast list was not returned by append_to_response, fetch credits directly
    final credits = data['credits'] ?? data['aggregate_credits'];
    final castList = credits is Map ? credits['cast'] : null;
    if (castList == null || (castList is List && castList.isEmpty)) {
      try {
        final creditsUri = _buildUri(
          mediaType == 'tv' ? '/tv/$id/aggregate_credits' : '/movie/$id/credits',
          apiToken,
        );
        final creditsRes = await _client.get(creditsUri, headers: _buildHeaders(apiToken));
        if (creditsRes.statusCode == 200) {
          final creditsData = jsonDecode(creditsRes.body);
          if (creditsData is Map<String, dynamic>) {
            data['credits'] = creditsData;
          }
        }
      } catch (_) {
        // Fallback silently if credits endpoint fails
      }
    }

    return TmdbMediaItem.fromJson(data, mediaTypeOverride: mediaType);
  }

  /// Get person details (bio, birthday, department, profile image).
  Future<TmdbPersonDetails> getPersonDetails({
    required String apiToken,
    required int personId,
  }) async {
    final uri = _buildUri('/person/$personId', apiToken);
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to get person details (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TmdbPersonDetails.fromJson(data);
  }

  /// Get full filmography of a person (movies & TV shows where they participated).
  Future<List<TmdbMediaItem>> getPersonCombinedCredits({
    required String apiToken,
    required int personId,
  }) async {
    final uri = _buildUri('/person/$personId/combined_credits', apiToken);
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to get person credits (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final List<TmdbMediaItem> items = [];
    final seen = <int>{};

    final castList = data['cast'] as List<dynamic>? ?? [];
    for (final c in castList.whereType<Map>()) {
      try {
        final itemMap = Map<String, dynamic>.from(c);
        final id = (itemMap['id'] as num?)?.toInt();
        if (id != null && seen.add(id)) {
          items.add(TmdbMediaItem.fromJson(itemMap));
        }
      } catch (_) {}
    }

    final crewList = data['crew'] as List<dynamic>? ?? [];
    for (final cr in crewList.whereType<Map>()) {
      try {
        final itemMap = Map<String, dynamic>.from(cr);
        final id = (itemMap['id'] as num?)?.toInt();
        if (id != null && seen.add(id)) {
          items.add(TmdbMediaItem.fromJson(itemMap));
        }
      } catch (_) {}
    }

    // Sort by vote_count (popularity) descending so famous works appear first
    items.sort((a, b) {
      final aVotes = a.voteCount ?? 0;
      final bVotes = b.voteCount ?? 0;
      return bVotes.compareTo(aVotes);
    });

    return items;
  }

  /// Search persons (actors, directors, writers, crew) in TMDB.
  Future<List<Map<String, dynamic>>> searchPersons({
    required String apiToken,
    required String query,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];
    final uri = _buildUri('/search/person', apiToken, {
      'query': query.trim(),
      'page': page,
      'include_adult': false,
    });
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results.whereType<Map<String, dynamic>>().toList();
  }

  /// Find person ID by search query name (useful fallback if ID was not cached).
  Future<int?> findPersonIdByName({
    required String apiToken,
    required String name,
  }) async {
    if (name.trim().isEmpty) return null;
    final uri = _buildUri('/search/person', apiToken, {'query': name.trim()});
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return null;
    final first = results.first;
    if (first is Map && first['id'] is num) {
      return (first['id'] as num).toInt();
    }
    return null;
  }

  /// Get list of recommended movies or TV shows based on a specific title.
  Future<List<TmdbMediaItem>> getRecommendations({
    required String apiToken,
    required int id,
    required String mediaType,
    int page = 1,
  }) async {
    final endpoint = mediaType == 'tv' ? '/tv/$id/recommendations' : '/movie/$id/recommendations';
    final uri = _buildUri(endpoint, apiToken, {'page': page.toString()});
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to get recommendations (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map((m) => TmdbMediaItem.fromJson(m, mediaTypeOverride: mediaType))
        .toList();
  }

  /// Get list of similar movies or TV shows.
  Future<List<TmdbMediaItem>> getSimilar({
    required String apiToken,
    required int id,
    required String mediaType,
    int page = 1,
  }) async {
    final endpoint = mediaType == 'tv' ? '/tv/$id/similar' : '/movie/$id/similar';
    final uri = _buildUri(endpoint, apiToken, {'page': page.toString()});
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to get similar titles (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map((m) => TmdbMediaItem.fromJson(m, mediaTypeOverride: mediaType))
        .toList();
  }

  /// Discover movies or TV shows by genres, rating, or popularity.
  Future<List<TmdbMediaItem>> discoverMedia({
    required String apiToken,
    String mediaType = 'movie',
    List<int>? withGenres,
    double? voteAverageGte,
    int? voteCountGte = 200,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) async {
    final endpoint = mediaType == 'tv' ? '/discover/tv' : '/discover/movie';
    final queryParams = <String, String>{
      'sort_by': sortBy,
      'page': page.toString(),
    };
    if (withGenres != null && withGenres.isNotEmpty) {
      queryParams['with_genres'] = withGenres.join(',');
    }
    if (voteAverageGte != null) {
      queryParams['vote_average.gte'] = voteAverageGte.toString();
    }
    if (voteCountGte != null) {
      queryParams['vote_count.gte'] = voteCountGte.toString();
    }

    final uri = _buildUri(endpoint, apiToken, queryParams);
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to discover media (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map((m) => TmdbMediaItem.fromJson(m, mediaTypeOverride: mediaType))
        .toList();
  }

  // --- TMDB Account Authorization Flow ---

  /// Step 1: Create request token for user authentication.
  Future<String> createRequestToken({required String apiToken}) async {
    final uri = _buildUri('/authentication/token/new', apiToken);
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to create request token (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] != true || data['request_token'] == null) {
      throw Exception('Invalid token response: ${res.body}');
    }
    return data['request_token'] as String;
  }

  /// Step 2 url helper: Web URL for user approval in browser.
  String buildAuthUrl(String requestToken) {
    return 'https://www.themoviedb.org/authenticate/$requestToken';
  }

  /// Step 3: Exchange authorized request token for a session ID.
  Future<String> createSession({
    required String apiToken,
    required String requestToken,
  }) async {
    final uri = _buildUri('/authentication/session/new', apiToken);
    final res = await _client.post(
      uri,
      headers: _buildHeaders(apiToken),
      body: jsonEncode({'request_token': requestToken}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to create session (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] != true || data['session_id'] == null) {
      throw Exception('Invalid session response: ${res.body}');
    }
    return data['session_id'] as String;
  }

  /// Get authenticated user's account details.
  Future<TmdbAccountInfo> getAccountDetails({
    required String apiToken,
    required String sessionId,
  }) async {
    final uri = _buildUri('/account', apiToken, {'session_id': sessionId});
    final res = await _client.get(uri, headers: _buildHeaders(apiToken));
    if (res.statusCode != 200) {
      throw Exception('Failed to get account (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final id = data['id'] as int;
    final username = data['username'] as String? ?? 'User';
    final name = data['name'] as String?;
    final avatarObj = data['avatar'] as Map<String, dynamic>?;
    final tmdbAvatar = avatarObj?['tmdb'] as Map<String, dynamic>?;
    final avatarPath = tmdbAvatar?['avatar_path'] as String?;

    return TmdbAccountInfo(
      id: id,
      username: username,
      name: name,
      avatarPath: avatarPath,
    );
  }

  // --- Watchlist, Favorites & Ratings Sync ---

  /// Fetch user's watchlist (movies and tv).
  Future<List<TmdbMediaItem>> fetchWatchlist({
    required String apiToken,
    required String sessionId,
    required int accountId,
  }) async {
    final movies = await _fetchAllPages(
      apiToken: apiToken,
      path: '/account/$accountId/watchlist/movies',
      sessionId: sessionId,
      mediaType: 'movie',
    );
    final tvs = await _fetchAllPages(
      apiToken: apiToken,
      path: '/account/$accountId/watchlist/tv',
      sessionId: sessionId,
      mediaType: 'tv',
    );
    return [...movies, ...tvs];
  }

  /// Fetch user's favorites (movies and tv).
  Future<List<TmdbMediaItem>> fetchFavorites({
    required String apiToken,
    required String sessionId,
    required int accountId,
  }) async {
    final movies = await _fetchAllPages(
      apiToken: apiToken,
      path: '/account/$accountId/favorite/movies',
      sessionId: sessionId,
      mediaType: 'movie',
      isFavorite: true,
    );
    final tvs = await _fetchAllPages(
      apiToken: apiToken,
      path: '/account/$accountId/favorite/tv',
      sessionId: sessionId,
      mediaType: 'tv',
      isFavorite: true,
    );
    return [...movies, ...tvs];
  }

  /// Fetch user's rated items (movies and tv).
  Future<List<TmdbMediaItem>> fetchRated({
    required String apiToken,
    required String sessionId,
    required int accountId,
  }) async {
    final movies = await _fetchAllPages(
      apiToken: apiToken,
      path: '/account/$accountId/rated/movies',
      sessionId: sessionId,
      mediaType: 'movie',
      statusOverride: 'watched',
    );
    final tvs = await _fetchAllPages(
      apiToken: apiToken,
      path: '/account/$accountId/rated/tv',
      sessionId: sessionId,
      mediaType: 'tv',
      statusOverride: 'watched',
    );
    return [...movies, ...tvs];
  }

  Future<List<TmdbMediaItem>> _fetchAllPages({
    required String apiToken,
    required String path,
    required String sessionId,
    required String mediaType,
    bool isFavorite = false,
    String? statusOverride,
  }) async {
    final List<TmdbMediaItem> all = [];
    int page = 1;
    int totalPages = 1;

    while (page <= totalPages && page <= 10) {
      final uri = _buildUri(path, apiToken, {
        'session_id': sessionId,
        'page': page,
        'sort_by': 'created_at.desc',
      });
      final res = await _client.get(uri, headers: _buildHeaders(apiToken));
      if (res.statusCode != 200) break;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
      final results = data['results'] as List<dynamic>? ?? [];

      for (final r in results.whereType<Map<String, dynamic>>()) {
        final item = TmdbMediaItem.fromJson(r, mediaTypeOverride: mediaType).copyWith(
          isFavorite: isFavorite,
          status: statusOverride,
        );
        all.add(item);
      }
      page++;
    }
    return all;
  }

  /// Update item in TMDB watchlist.
  Future<void> setWatchlist({
    required String apiToken,
    required String sessionId,
    required int accountId,
    required int mediaId,
    required String mediaType,
    required bool inWatchlist,
  }) async {
    final uri = _buildUri('/account/$accountId/watchlist', apiToken, {
      'session_id': sessionId,
    });
    final res = await _client.post(
      uri,
      headers: _buildHeaders(apiToken),
      body: jsonEncode({
        'media_type': mediaType,
        'media_id': mediaId,
        'watchlist': inWatchlist,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to update watchlist (${res.statusCode}): ${res.body}');
    }
  }

  /// Update item favorite status.
  Future<void> setFavorite({
    required String apiToken,
    required String sessionId,
    required int accountId,
    required int mediaId,
    required String mediaType,
    required bool isFavorite,
  }) async {
    final uri = _buildUri('/account/$accountId/favorite', apiToken, {
      'session_id': sessionId,
    });
    final res = await _client.post(
      uri,
      headers: _buildHeaders(apiToken),
      body: jsonEncode({
        'media_type': mediaType,
        'media_id': mediaId,
        'favorite': isFavorite,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to update favorite (${res.statusCode}): ${res.body}');
    }
  }

  /// Post rating (0.5 to 10.0) or delete rating if rating == null or <= 0.
  Future<void> setRating({
    required String apiToken,
    required String sessionId,
    required int mediaId,
    required String mediaType,
    required double? rating,
  }) async {
    if (rating == null || rating <= 0) {
      final uri = _buildUri('/$mediaType/$mediaId/rating', apiToken, {
        'session_id': sessionId,
      });
      await _client.delete(uri, headers: _buildHeaders(apiToken));
    } else {
      final uri = _buildUri('/$mediaType/$mediaId/rating', apiToken, {
        'session_id': sessionId,
      });
      await _client.post(
        uri,
        headers: _buildHeaders(apiToken),
        body: jsonEncode({'value': rating}),
      );
    }
  }
}

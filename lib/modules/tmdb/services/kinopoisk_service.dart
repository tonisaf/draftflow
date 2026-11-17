import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class KinopoiskRatingData {
  final int kpId;
  final double kpRating;
  final int? kpVotes;
  final double? imdbRating;
  final String? webUrl;

  const KinopoiskRatingData({
    required this.kpId,
    required this.kpRating,
    this.kpVotes,
    this.imdbRating,
    this.webUrl,
  });
}

class KinopoiskService {
  final http.Client _client;

  KinopoiskService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches Kinopoisk rating for a movie by IMDb ID or by Russian/original title & year.
  Future<KinopoiskRatingData?> fetchRating({
    required String apiKey,
    String? imdbId,
    required String title,
    int? year,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return null;

    // 1. Try kinopoisk.dev API (v1.4)
    try {
      final data = await _fetchFromKinopoiskDev(cleanKey, imdbId: imdbId, title: title, year: year);
      if (data != null) return data;
    } catch (e) {
      debugPrint('KinopoiskService: kinopoisk.dev error: $e');
    }

    // 2. Try kinopoiskapiunofficial.tech API
    try {
      final data = await _fetchFromUnofficial(cleanKey, imdbId: imdbId, title: title);
      if (data != null) return data;
    } catch (e) {
      debugPrint('KinopoiskService: unofficial api error: $e');
    }

    return null;
  }

  Future<KinopoiskRatingData?> _fetchFromKinopoiskDev(
    String apiKey, {
    String? imdbId,
    required String title,
    int? year,
  }) async {
    Uri uri;
    if (imdbId != null && imdbId.isNotEmpty) {
      uri = Uri.parse('https://api.kinopoisk.dev/v1.4/movie?externalId.imdb=$imdbId');
    } else {
      final encodedTitle = Uri.encodeComponent(title.trim());
      var urlStr = 'https://api.kinopoisk.dev/v1.4/movie/search?query=$encodedTitle';
      if (year != null && year > 1900) {
        urlStr += '&year=$year';
      }
      uri = Uri.parse(urlStr);
    }

    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-API-KEY': apiKey,
      },
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final docs = json['docs'] as List<dynamic>? ?? [];
      if (docs.isNotEmpty) {
        final doc = docs.first as Map<String, dynamic>;
        final id = (doc['id'] as num?)?.toInt();
        final ratingObj = doc['rating'] as Map<String, dynamic>?;
        final votesObj = doc['votes'] as Map<String, dynamic>?;
        final kpRating = (ratingObj?['kp'] as num?)?.toDouble();
        final imdbRating = (ratingObj?['imdb'] as num?)?.toDouble();
        final kpVotes = (votesObj?['kp'] as num?)?.toInt();

        if (id != null && kpRating != null && kpRating > 0) {
          return KinopoiskRatingData(
            kpId: id,
            kpRating: kpRating,
            kpVotes: kpVotes,
            imdbRating: imdbRating != null && imdbRating > 0 ? imdbRating : null,
            webUrl: 'https://www.kinopoisk.ru/film/$id/',
          );
        }
      }
    }
    return null;
  }

  Future<KinopoiskRatingData?> _fetchFromUnofficial(
    String apiKey, {
    String? imdbId,
    required String title,
  }) async {
    Uri uri;
    if (imdbId != null && imdbId.isNotEmpty) {
      uri = Uri.parse('https://kinopoiskapiunofficial.tech/api/v2.2/films?imdbId=$imdbId');
    } else {
      uri = Uri.parse(
        'https://kinopoiskapiunofficial.tech/api/v2.1/films/search-by-keyword?keyword=${Uri.encodeComponent(title)}',
      );
    }

    final res = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-API-KEY': apiKey,
      },
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final items = (json['items'] ?? json['films']) as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final item = items.first as Map<String, dynamic>;
        final id = (item['kinopoiskId'] ?? item['filmId'] as num?)?.toInt();
        final rawKp = item['ratingKinopoisk'] ?? item['rating'];
        final kpRating = rawKp is num ? rawKp.toDouble() : double.tryParse(rawKp?.toString() ?? '');
        final rawImdb = item['ratingImdb'];
        final imdbRating = rawImdb is num ? rawImdb.toDouble() : double.tryParse(rawImdb?.toString() ?? '');
        final rawVotes = item['ratingVoteCount'] ?? item['votesKinopoisk'];
        final kpVotes = rawVotes is num ? rawVotes.toInt() : int.tryParse(rawVotes?.toString() ?? '');

        if (id != null && kpRating != null && kpRating > 0) {
          return KinopoiskRatingData(
            kpId: id,
            kpRating: kpRating,
            kpVotes: kpVotes,
            imdbRating: imdbRating,
            webUrl: 'https://www.kinopoisk.ru/film/$id/',
          );
        }
      }
    }
    return null;
  }
}

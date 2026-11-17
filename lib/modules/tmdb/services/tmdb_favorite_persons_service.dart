import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TmdbFavoritePerson {
  final int id;
  final String name;
  final String? profilePath;
  final String? department; // e.g. "Directing", "Acting", "Writing"
  final DateTime addedAt;

  const TmdbFavoritePerson({
    required this.id,
    required this.name,
    this.profilePath,
    this.department,
    required this.addedAt,
  });

  String? get profileUrl {
    if (profilePath == null || profilePath!.isEmpty) return null;
    if (profilePath!.startsWith('http')) return profilePath;
    return 'https://image.tmdb.org/t/p/w200$profilePath';
  }

  String get localizedRole {
    if (department == null || department!.isEmpty) return 'Кинематографист';
    final d = department!.toLowerCase();
    if (d.contains('direct')) return 'Режиссёр';
    if (d.contains('act')) return 'Актёр / Актриса';
    if (d.contains('writ')) return 'Сценарист';
    if (d.contains('produc')) return 'Продюсер';
    if (d.contains('camera') || d.contains('photo')) return 'Оператор';
    if (d.contains('sound') || d.contains('music')) return 'Композитор';
    return department!;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profile_path': profilePath,
        'department': department,
        'added_at': addedAt.toIso8601String(),
      };

  factory TmdbFavoritePerson.fromJson(Map<String, dynamic> json) =>
      TmdbFavoritePerson(
        id: json['id'] as int,
        name: json['name'] as String,
        profilePath: json['profile_path'] as String?,
        department: json['department'] as String?,
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class TmdbFavoritePersonsService extends ChangeNotifier {
  static const _storageKey = 'tmdb_favorite_persons_list_v1';
  static final TmdbFavoritePersonsService instance =
      TmdbFavoritePersonsService._internal();

  TmdbFavoritePersonsService._internal();

  List<TmdbFavoritePerson> _favorites = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<TmdbFavoritePerson> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(int id, {String? name}) {
    return _favorites.any((f) =>
        f.id == id ||
        (name != null && f.name.toLowerCase() == name.toLowerCase()));
  }

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _favorites = decoded
              .whereType<Map>()
              .map((e) =>
                  TmdbFavoritePerson.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('TmdbFavoritePersonsService: Error loading favorites: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite({
    required int id,
    required String name,
    String? profilePath,
    String? department,
  }) async {
    await init();
    final idx = _favorites.indexWhere((f) =>
        f.id == id || f.name.toLowerCase() == name.toLowerCase());
    final bool nowFavorite;
    if (idx >= 0) {
      _favorites.removeAt(idx);
      nowFavorite = false;
    } else {
      _favorites.add(TmdbFavoritePerson(
        id: id,
        name: name,
        profilePath: profilePath,
        department: department,
        addedAt: DateTime.now(),
      ));
      nowFavorite = true;
    }
    notifyListeners();
    await _save();
    return nowFavorite;
  }

  Future<void> removeFavorite(int id) async {
    await init();
    _favorites.removeWhere((f) => f.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_favorites.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('TmdbFavoritePersonsService: Error saving favorites: $e');
    }
  }
}

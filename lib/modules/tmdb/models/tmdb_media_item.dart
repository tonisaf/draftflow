const Map<int, String> tmdbGenreMap = {
  28: 'Боевик',
  12: 'Приключения',
  16: 'Мультфильм',
  35: 'Комедия',
  80: 'Криминал',
  99: 'Документальный',
  18: 'Драма',
  10751: 'Семейный',
  14: 'Фэнтези',
  36: 'История',
  27: 'Ужасы',
  10402: 'Музыка',
  9648: 'Детектив',
  10749: 'Мелодрама',
  878: 'Фантастика',
  10770: 'Телефильм',
  53: 'Триллер',
  10752: 'Военный',
  37: 'Вестерн',
  10759: 'Боевик и Приключения',
  10762: 'Детский',
  10763: 'Новости',
  10764: 'Реалити-шоу',
  10765: 'Фантастика и Фэнтези',
  10766: 'Мыльная опера',
  10767: 'Ток-шоу',
  10768: 'Война и Политика',
};

class TmdbCastMember {
  final int? id;
  final String name;
  final String? character;
  final String? profilePath;

  const TmdbCastMember({
    this.id,
    required this.name,
    this.character,
    this.profilePath,
  });

  String? profileUrl([String size = 'w185']) {
    if (profilePath == null || profilePath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$profilePath';
  }

  factory TmdbCastMember.fromJson(Map<String, dynamic> json) {
    String? char = json['character']?.toString();
    if ((char == null || char.isEmpty) && json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      final firstRole = (json['roles'] as List).first;
      if (firstRole is Map && firstRole['character'] != null) {
        char = firstRole['character']?.toString();
      }
    }
    return TmdbCastMember(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name']?.toString() ?? ''),
      character: char,
      profilePath: json['profile_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'character': character,
    'profile_path': profilePath,
  };
}

class TmdbCrewMember {
  final int? id;
  final String name;
  final String job;
  final String? originalJob;
  final String? department;
  final String? profilePath;

  const TmdbCrewMember({
    this.id,
    required this.name,
    required this.job,
    this.originalJob,
    this.department,
    this.profilePath,
  });

  String? profileUrl([String size = 'w185']) {
    if (profilePath == null || profilePath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$profilePath';
  }

  factory TmdbCrewMember.fromJson(Map<String, dynamic> json) {
    final rawJob = (json['job']?.toString() ?? json['original_job']?.toString() ?? '').trim();
    final translated = json['translated_job']?.toString() ?? _translateJob(rawJob);
    return TmdbCrewMember(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name']?.toString() ?? ''),
      job: translated.isNotEmpty ? translated : (rawJob.isNotEmpty ? rawJob : 'Создатель'),
      originalJob: rawJob,
      department: json['department']?.toString(),
      profilePath: json['profile_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'job': job,
    'original_job': originalJob,
    'department': department,
    'profile_path': profilePath,
  };

  static String _translateJob(String job) {
    final lower = job.toLowerCase().trim();
    if (lower == 'director') return 'Режиссёр';
    if (lower == 'screenplay' || lower == 'writer' || lower == 'story' || lower == 'author' || lower == 'teleplay') {
      return 'Сценарист';
    }
    if (lower == 'creator' || lower == 'created by') return 'Создатель';
    if (lower == 'producer') return 'Продюсер';
    if (lower == 'executive producer') return 'Исполнительный продюсер';
    if (lower.contains('composer') || lower == 'music' || lower == 'original music composer') {
      return 'Композитор';
    }
    if (lower == 'director of photography' || lower == 'cinematography' || lower == 'cinematographer') {
      return 'Оператор';
    }
    if (lower == 'editor') return 'Монтажёр';
    if (lower == 'production design' || lower == 'art direction') return 'Художник-постановщик';
    if (lower == 'costume design') return 'Художник по костюмам';
    return job;
  }
}

class TmdbPersonDetails {
  final int id;
  final String name;
  final String? profilePath;
  final String? biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? knownForDepartment;
  final double? popularity;

  const TmdbPersonDetails({
    required this.id,
    required this.name,
    this.profilePath,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.knownForDepartment,
    this.popularity,
  });

  String? profileUrl([String size = 'w300']) {
    if (profilePath == null || profilePath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$profilePath';
  }

  factory TmdbPersonDetails.fromJson(Map<String, dynamic> json) {
    return TmdbPersonDetails(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      profilePath: json['profile_path'] as String?,
      biography: json['biography'] as String?,
      birthday: json['birthday'] as String?,
      deathday: json['deathday'] as String?,
      placeOfBirth: json['place_of_birth'] as String?,
      knownForDepartment: json['known_for_department'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
    );
  }

  String get localizedDepartment {
    switch (knownForDepartment?.toLowerCase()) {
      case 'acting':
        return 'Актёр';
      case 'directing':
        return 'Режиссёр';
      case 'writing':
        return 'Сценарист';
      case 'production':
        return 'Продюсер';
      case 'sound':
        return 'Композитор / Звук';
      case 'camera':
        return 'Оператор';
      default:
        return knownForDepartment ?? 'Кинематографист';
    }
  }
}

class TmdbMediaItem {
  final int id;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? originalTitle;
  final String? tagline;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate; // 'YYYY-MM-DD'
  final int? runtime; // minutes
  final String? director;
  final double? voteAverage;
  final int? voteCount;
  final List<String> genres;
  final List<TmdbCastMember> cast;
  final List<TmdbCrewMember> crew;
  final String? trailerKey;
  final String status; // 'watchlist', 'watching', 'watched', 'dropped'
  final double? userRating; // 1.0 - 10.0
  final bool isFavorite;
  final String? pageId; // Linked Page ID in Notes Here database
  final String? personalNote;
  final String? imdbId;
  final double? imdbRating;
  final double? kpRating;
  final int? kpVotes;
  final int? kpId;

  const TmdbMediaItem({
    required this.id,
    required this.mediaType,
    required this.title,
    this.originalTitle,
    this.tagline,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtime,
    this.director,
    this.voteAverage,
    this.voteCount,
    this.genres = const [],
    this.cast = const [],
    this.crew = const [],
    this.trailerKey,
    this.status = 'watchlist',
    this.userRating,
    this.isFavorite = false,
    this.pageId,
    this.personalNote,
    this.imdbId,
    this.imdbRating,
    this.kpRating,
    this.kpVotes,
    this.kpId,
  });

  String get year {
    if (releaseDate == null || releaseDate!.isEmpty) return '';
    final parts = releaseDate!.split('-');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String get formattedRuntime {
    if (runtime == null || runtime! <= 0) return '';
    final hours = runtime! ~/ 60;
    final mins = runtime! % 60;
    if (hours > 0 && mins > 0) return '$hours ч $mins мин';
    if (hours > 0) return '$hours ч';
    return '$mins мин';
  }

  String? get kinopoiskWebUrl => kpId != null ? 'https://www.kinopoisk.ru/film/$kpId/' : null;

  String? get imdbWebUrl => (imdbId != null && imdbId!.isNotEmpty) ? 'https://www.imdb.com/title/$imdbId/' : null;

  List<TmdbCrewMember> get directors =>
      crew.where((c) => c.job == 'Режиссёр' || c.job == 'Создатель').toList();

  List<TmdbCrewMember> get writers =>
      crew.where((c) => c.job == 'Сценарист').toList();

  List<TmdbCrewMember> get producers =>
      crew.where((c) => c.job == 'Продюсер' || c.job == 'Исполнительный продюсер').toList();

  List<TmdbCrewMember> get composers =>
      crew.where((c) => c.job == 'Композитор').toList();

  List<TmdbCrewMember> get cinematographers =>
      crew.where((c) => c.job == 'Оператор').toList();

  String? posterUrl([String size = 'w500']) {
    if (posterPath == null || posterPath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$posterPath';
  }

  String? backdropUrl([String size = 'w1280']) {
    if (backdropPath == null || backdropPath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$backdropPath';
  }

  String? get youtubeTrailerUrl {
    if (trailerKey == null || trailerKey!.isEmpty) return null;
    return 'https://www.youtube.com/watch?v=$trailerKey';
  }

  String get tmdbWebUrl {
    return 'https://www.themoviedb.org/$mediaType/$id';
  }

  TmdbMediaItem copyWith({
    int? id,
    String? mediaType,
    String? title,
    String? originalTitle,
    String? tagline,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    int? runtime,
    String? director,
    double? voteAverage,
    int? voteCount,
    List<String>? genres,
    List<TmdbCastMember>? cast,
    List<TmdbCrewMember>? crew,
    String? trailerKey,
    String? status,
    double? userRating,
    bool? isFavorite,
    String? pageId,
    String? personalNote,
    String? imdbId,
    double? imdbRating,
    double? kpRating,
    int? kpVotes,
    int? kpId,
  }) {
    return TmdbMediaItem(
      id: id ?? this.id,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      tagline: tagline ?? this.tagline,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      runtime: runtime ?? this.runtime,
      director: director ?? this.director,
      voteAverage: voteAverage ?? this.voteAverage,
      voteCount: voteCount ?? this.voteCount,
      genres: genres ?? this.genres,
      cast: cast ?? this.cast,
      crew: crew ?? this.crew,
      trailerKey: trailerKey ?? this.trailerKey,
      status: status ?? this.status,
      userRating: userRating ?? this.userRating,
      isFavorite: isFavorite ?? this.isFavorite,
      pageId: pageId ?? this.pageId,
      personalNote: personalNote ?? this.personalNote,
      imdbId: imdbId ?? this.imdbId,
      imdbRating: imdbRating ?? this.imdbRating,
      kpRating: kpRating ?? this.kpRating,
      kpVotes: kpVotes ?? this.kpVotes,
      kpId: kpId ?? this.kpId,
    );
  }

  factory TmdbMediaItem.fromJson(Map<String, dynamic> json, {String? mediaTypeOverride}) {
    final type = mediaTypeOverride ?? (json['media_type'] as String?) ?? 'movie';
    final name = (json['title'] ?? json['name'] ?? '') as String;
    final orig = (json['original_title'] ?? json['original_name']) as String?;
    final date = (json['release_date'] ?? json['first_air_date']) as String?;
    final vote = (json['vote_average'] as num?)?.toDouble();
    final count = (json['vote_count'] as num?)?.toInt();
    final rating = (json['rating'] as num?)?.toDouble();

    // Runtime
    int? run = (json['runtime'] as num?)?.toInt();
    if (run == null && json['episode_run_time'] is List && (json['episode_run_time'] as List).isNotEmpty) {
      run = ((json['episode_run_time'] as List).first as num?)?.toInt();
    }

    // Genres
    List<String> parsedGenres = [];
    if (json['genres'] is List) {
      parsedGenres = (json['genres'] as List)
          .map((g) => g is Map ? (g['name'] as String? ?? '') : g.toString())
          .where((g) => g.isNotEmpty)
          .toList();
    } else if (json['genre_ids'] is List) {
      parsedGenres = (json['genre_ids'] as List)
          .whereType<int>()
          .map((id) => tmdbGenreMap[id])
          .whereType<String>()
          .toList();
    }

    // Credits: Director, Crew & Cast
    String? dir;
    List<TmdbCastMember> parsedCast = [];
    List<TmdbCrewMember> parsedCrew = [];

    if (json['crew'] is List) {
      parsedCrew = (json['crew'] as List)
          .whereType<Map>()
          .map((c) => TmdbCrewMember.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    final seenCrew = <String>{};

    // TV show creators (from created_by)
    if (json['created_by'] is List) {
      for (final cr in json['created_by'] as List) {
        if (cr is Map && cr['name'] != null) {
          final cName = cr['name'].toString().trim();
          if (cName.isNotEmpty && seenCrew.add('Создатель:$cName')) {
            parsedCrew.add(TmdbCrewMember(
              id: (cr['id'] as num?)?.toInt(),
              name: cName,
              job: 'Создатель',
              originalJob: 'Creator',
              department: 'Directing',
              profilePath: cr['profile_path']?.toString(),
            ));
          }
        }
      }
    }

    final credits = json['credits'] ?? json['aggregate_credits'];
    if (credits is Map) {
      if (credits['crew'] is List) {
        final crewList = credits['crew'] as List;
        const priorityJobs = [
          'Director',
          'Screenplay',
          'Writer',
          'Story',
          'Characters',
          'Author',
          'Teleplay',
          'Original Music Composer',
          'Music',
          'Director of Photography',
          'Producer',
          'Executive Producer',
        ];

        for (final pJob in priorityJobs) {
          for (final member in crewList) {
            if (member is Map) {
              final job = member['job']?.toString() ?? '';
              final mName = member['name']?.toString() ?? '';
              if (mName.isNotEmpty && job.toLowerCase() == pJob.toLowerCase()) {
                final translatedJob = TmdbCrewMember._translateJob(job);
                final key = '$translatedJob:$mName';
                if (seenCrew.add(key)) {
                  parsedCrew.add(TmdbCrewMember(
                    id: (member['id'] as num?)?.toInt(),
                    name: mName,
                    job: translatedJob,
                    originalJob: job,
                    department: member['department']?.toString(),
                    profilePath: member['profile_path']?.toString(),
                  ));
                }
              }
            }
          }
        }
      }

      final castList = credits['cast'];
      if (castList is List) {
        parsedCast = castList
            .whereType<Map>()
            .take(24)
            .map((c) => TmdbCastMember.fromJson(Map<String, dynamic>.from(c)))
            .toList();
      }
    } else if (json['cast'] is List) {
      parsedCast = (json['cast'] as List)
          .whereType<Map>()
          .take(24)
          .map((c) => TmdbCastMember.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    for (final c in parsedCrew) {
      if (c.job == 'Режиссёр' || c.job == 'Создатель') {
        dir = c.name;
        break;
      }
    }

    if (dir == null && json['created_by'] is List && (json['created_by'] as List).isNotEmpty) {
      final creator = (json['created_by'] as List).first;
      if (creator is Map) {
        dir = creator['name']?.toString();
      }
    }

    // Videos: YouTube Trailer
    String? trailer;
    final videosObj = json['videos'];
    if (videosObj is Map) {
      final videos = videosObj['results'] as List<dynamic>?;
      if (videos != null) {
        for (final v in videos) {
          if (v is Map && v['site'] == 'YouTube' && (v['type'] == 'Trailer' || v['type'] == 'Teaser')) {
            trailer = v['key']?.toString();
            break;
          }
        }
      }
    }

    // External IDs (IMDb)
    String? imdb;
    final ext = json['external_ids'];
    if (ext is Map && ext['imdb_id'] != null) {
      imdb = ext['imdb_id']?.toString();
    } else {
      imdb = json['imdb_id']?.toString();
    }

    // Kinopoisk & IMDb Ratings
    final kpR = (json['kp_rating'] as num?)?.toDouble() ?? (json['ratingKinopoisk'] as num?)?.toDouble();
    final kpV = (json['kp_votes'] as num?)?.toInt() ?? (json['votesKinopoisk'] as num?)?.toInt();
    final kpI = (json['kp_id'] as num?)?.toInt() ?? (json['kinopoiskId'] as num?)?.toInt();
    final imdbR = (json['imdb_rating'] as num?)?.toDouble() ?? (json['ratingImdb'] as num?)?.toDouble();

    return TmdbMediaItem(
      id: json['id'] as int,
      mediaType: type,
      title: name,
      originalTitle: orig,
      tagline: json['tagline'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: date,
      runtime: run,
      director: dir ?? json['director'] as String?,
      voteAverage: vote,
      voteCount: count,
      genres: parsedGenres,
      cast: parsedCast,
      crew: parsedCrew,
      trailerKey: trailer ?? json['trailer_key'] as String?,
      status: (json['custom_status'] as String?) ?? 'watchlist',
      userRating: rating,
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      pageId: json['page_id'] as String?,
      personalNote: json['personal_note'] as String?,
      imdbId: imdb,
      imdbRating: imdbR,
      kpRating: kpR,
      kpVotes: kpV,
      kpId: kpI,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'media_type': mediaType,
    'title': title,
    'original_title': originalTitle,
    'tagline': tagline,
    'overview': overview,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'release_date': releaseDate,
    'runtime': runtime,
    'director': director,
    'vote_average': voteAverage,
    'vote_count': voteCount,
    'genres': genres,
    'cast': cast.map((c) => c.toJson()).toList(),
    'crew': crew.map((c) => c.toJson()).toList(),
    'trailer_key': trailerKey,
    'custom_status': status,
    'rating': userRating,
    'is_favorite': isFavorite,
    'page_id': pageId,
    'personal_note': personalNote,
    'imdb_id': imdbId,
    'imdb_rating': imdbRating,
    'kp_rating': kpRating,
    'kp_votes': kpVotes,
    'kp_id': kpId,
  };
}

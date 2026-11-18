import 'package:flutter/material.dart';

enum TmdbDetailTab { overview, cast, recommendations, notes }

Color getTmdbStatusColor(String status) {
  switch (status) {
    case 'watching':
      return const Color(0xFFF59E0B);
    case 'watched':
      return const Color(0xFF10B981);
    case 'dropped':
      return const Color(0xFFEF4444);
    case 'watchlist':
    default:
      return const Color(0xFF6366F1);
  }
}

String getTmdbStatusLabel(String status) {
  switch (status) {
    case 'watching':
      return 'Смотрю сейчас';
    case 'watched':
      return 'Просмотрено';
    case 'dropped':
      return 'Брошено';
    case 'watchlist':
    default:
      return 'В планах';
  }
}

String getTmdbRatingFeedbackText(double rating) {
  if (rating <= 1.5) return 'Ужасно';
  if (rating <= 2.5) return 'Очень плохо';
  if (rating <= 3.5) return 'Плохо';
  if (rating <= 4.5) return 'Слабо';
  if (rating <= 5.5) return 'Средне';
  if (rating <= 6.5) return 'Неплохо';
  if (rating <= 7.5) return 'Хорошо';
  if (rating <= 8.5) return 'Очень хорошо';
  if (rating <= 9.5) return 'Великолепно';
  return 'Шедевр';
}

Color getTmdbCrewRoleColor(String job) {
  switch (job.toLowerCase()) {
    case 'режиссёр':
    case 'создатель':
      return const Color(0xFF2563EB); // Vibrant Blue
    case 'сценарист':
    case 'автор':
    case 'сюжет':
      return const Color(0xFF7C3AED); // Purple
    case 'композитор':
      return const Color(0xFF059669); // Emerald
    case 'оператор':
      return const Color(0xFFD97706); // Amber
    case 'продюсер':
    case 'исполнительный продюсер':
      return const Color(0xFF0284C7); // Cyan
    case 'художник-постановщик':
    case 'художник по костюмам':
      return const Color(0xFFDB2777); // Pink
    default:
      return const Color(0xFF64748B); // Slate
  }
}

IconData getTmdbCrewRoleIcon(String job) {
  switch (job.toLowerCase()) {
    case 'режиссёр':
    case 'создатель':
      return Icons.movie_creation_outlined;
    case 'сценарист':
    case 'автор':
      return Icons.edit_note_rounded;
    case 'композитор':
      return Icons.music_note_rounded;
    case 'оператор':
      return Icons.videocam_outlined;
    case 'продюсер':
    case 'исполнительный продюсер':
      return Icons.business_center_outlined;
    default:
      return Icons.person_outline_rounded;
  }
}

class FractionalClipper extends CustomClipper<Rect> {
  final double fraction;
  const FractionalClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(FractionalClipper oldClipper) => oldClipper.fraction != fraction;
}

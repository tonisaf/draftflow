import 'package:flutter/cupertino.dart';

class CupertinoIconPreset {
  final String id;
  final String label;
  final IconData icon;

  const CupertinoIconPreset({
    required this.id,
    required this.label,
    required this.icon,
  });
}

const List<CupertinoIconPreset> kCupertinoIconPresets = [
  CupertinoIconPreset(id: 'star', label: 'Звезда', icon: CupertinoIcons.star_fill),
  CupertinoIconPreset(id: 'folder', label: 'Папка', icon: CupertinoIcons.folder_fill),
  CupertinoIconPreset(id: 'doc', label: 'Документ', icon: CupertinoIcons.doc_text_fill),
  CupertinoIconPreset(id: 'bolt', label: 'Молния', icon: CupertinoIcons.bolt_fill),
  CupertinoIconPreset(id: 'flame', label: 'Огонь', icon: CupertinoIcons.flame_fill),
  CupertinoIconPreset(id: 'heart', label: 'Сердце', icon: CupertinoIcons.heart_fill),
  CupertinoIconPreset(id: 'tag', label: 'Тег', icon: CupertinoIcons.tag_fill),
  CupertinoIconPreset(id: 'bookmark', label: 'Закладка', icon: CupertinoIcons.bookmark_fill),
  CupertinoIconPreset(id: 'flag', label: 'Флаг', icon: CupertinoIcons.flag_fill),
  CupertinoIconPreset(id: 'lightbulb', label: 'Идея', icon: CupertinoIcons.lightbulb_fill),
  CupertinoIconPreset(id: 'gear', label: 'Шестерёнка', icon: CupertinoIcons.gear_alt_fill),
  CupertinoIconPreset(id: 'terminal', label: 'Терминал', icon: CupertinoIcons.command),
  CupertinoIconPreset(id: 'globe', label: 'Глобус', icon: CupertinoIcons.globe),
  CupertinoIconPreset(id: 'cube', label: 'Проект', icon: CupertinoIcons.cube_box_fill),
  CupertinoIconPreset(id: 'chart', label: 'Аналитика', icon: CupertinoIcons.chart_bar_fill),
  CupertinoIconPreset(id: 'calendar', label: 'Календарь', icon: CupertinoIcons.calendar),
  CupertinoIconPreset(id: 'pin', label: 'Пин', icon: CupertinoIcons.pin_fill),
  CupertinoIconPreset(id: 'bell', label: 'Уведомление', icon: CupertinoIcons.bell_fill),
  CupertinoIconPreset(id: 'lock', label: 'Безопасность', icon: CupertinoIcons.lock_fill),
  CupertinoIconPreset(id: 'shield', label: 'Щит', icon: CupertinoIcons.shield_fill),
  CupertinoIconPreset(id: 'wrench', label: 'Инструмент', icon: CupertinoIcons.wrench_fill),
  CupertinoIconPreset(id: 'paintbrush', label: 'Дизайн', icon: CupertinoIcons.paintbrush_fill),
  CupertinoIconPreset(id: 'music', label: 'Музыка', icon: CupertinoIcons.music_note_2),
  CupertinoIconPreset(id: 'camera', label: 'Медиа', icon: CupertinoIcons.camera_fill),
];

const List<Color> kIconPalette = [
  Color(0xFF3B82F6), // Blue
  Color(0xFF8B5CF6), // Purple
  Color(0xFFEC4899), // Pink
  Color(0xFFEF4444), // Red
  Color(0xFFF59E0B), // Amber
  Color(0xFF10B981), // Emerald
  Color(0xFF06B6D4), // Cyan
  Color(0xFF64748B), // Slate
];

String formatCupertinoIcon(String id, Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return 'icon:$id:#$hex';
}

(IconData, Color)? parseCupertinoIcon(String iconString) {
  if (!iconString.startsWith('icon:')) return null;
  final parts = iconString.split(':');
  if (parts.length < 3) return null;
  final id = parts[1];
  final hex = parts[2].replaceAll('#', '');
  final colorVal = int.tryParse(hex, radix: 16);
  final color = colorVal != null ? Color(0xFF000000 | colorVal) : const Color(0xFF3B82F6);

  final preset = kCupertinoIconPresets.firstWhere(
    (p) => p.id == id,
    orElse: () => kCupertinoIconPresets.first,
  );
  return (preset.icon, color);
}

/// Универсальный виджет отображения иконки страницы (поддерживает как эмодзи, так и цветные Cupertino-иконки).
class PageIconView extends StatelessWidget {
  final String? icon;
  final double size;
  final Color? color;
  final Widget? fallback;

  const PageIconView({
    super.key,
    required this.icon,
    this.size = 14.0,
    this.color,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null || icon!.isEmpty) {
      return fallback ?? SizedBox.shrink();
    }

    final parsed = parseCupertinoIcon(icon!);
    if (parsed != null) {
      return Icon(
        parsed.$1,
        size: size,
        color: color ?? parsed.$2,
      );
    }

    return Text(
      icon!,
      style: TextStyle(
        fontSize: size,
        height: 1.1,
      ),
    );
  }
}

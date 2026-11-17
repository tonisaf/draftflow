import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CoverPreset {
  final String id;
  final String label;
  final BoxDecoration decoration;

  const CoverPreset({
    required this.id,
    required this.label,
    required this.decoration,
  });
}

/// Mesh-палитра в стиле Apple macOS Sequoia & Sonoma
class MeshPalette {
  final String id;
  final String label;
  final Color baseColor;
  final List<Color> orbs;

  const MeshPalette({
    required this.id,
    required this.label,
    required this.baseColor,
    required this.orbs,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshPalette &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Apple Mesh-градиенты (Sonoma & Sequoia)
const List<MeshPalette> kAppleMeshCovers = [
  MeshPalette(
    id: 'mesh:sequoia_sunrise',
    label: 'Sequoia Sunrise',
    baseColor: Color(0xFF0D3B37),
    orbs: [
      Color(0xFFE07A5F),
      Color(0xFFF4A261),
      Color(0xFF2A9D8F),
      Color(0xFFE76F51),
    ],
  ),
  MeshPalette(
    id: 'mesh:sequoia_forest',
    label: 'Sequoia Forest',
    baseColor: Color(0xFF06281E),
    orbs: [
      Color(0xFF0F766E),
      Color(0xFF14B8A6),
      Color(0xFF047857),
      Color(0xFF38BDF8),
    ],
  ),
  MeshPalette(
    id: 'mesh:sonoma_horizon',
    label: 'Sonoma Horizon',
    baseColor: Color(0xFF4C1D95),
    orbs: [
      Color(0xFFF97316),
      Color(0xFFFB923C),
      Color(0xFFA855F7),
      Color(0xFFFDE047),
    ],
  ),
  MeshPalette(
    id: 'mesh:sonoma_evening',
    label: 'Sonoma Evening',
    baseColor: Color(0xFF0F172A),
    orbs: [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ],
  ),
  MeshPalette(
    id: 'mesh:ventura_citrus',
    label: 'Ventura Citrus',
    baseColor: Color(0xFF7C2D12),
    orbs: [
      Color(0xFFEA580C),
      Color(0xFFF59E0B),
      Color(0xFFFBBF24),
      Color(0xFFF43F5E),
    ],
  ),
  MeshPalette(
    id: 'mesh:monterey_purple',
    label: 'Monterey Velvet',
    baseColor: Color(0xFF1E1B4B),
    orbs: [
      Color(0xFF7C3AED),
      Color(0xFFC084FC),
      Color(0xFF4F46E5),
      Color(0xFFE879F9),
    ],
  ),
  MeshPalette(
    id: 'mesh:catalina_azure',
    label: 'Catalina Azure',
    baseColor: Color(0xFF082F49),
    orbs: [
      Color(0xFF0284C7),
      Color(0xFF38BDF8),
      Color(0xFF06B6D4),
      Color(0xFFE0F2FE),
    ],
  ),
  MeshPalette(
    id: 'mesh:quartz_pastel',
    label: 'Neon Quartz',
    baseColor: Color(0xFF3B0764),
    orbs: [
      Color(0xFFE879F9),
      Color(0xFFF472B6),
      Color(0xFF38BDF8),
      Color(0xFFA7F3D0),
    ],
  ),
  MeshPalette(
    id: 'mesh:solaris_flare',
    label: 'Solaris Flare',
    baseColor: Color(0xFF451A03),
    orbs: [
      Color(0xFFD97706),
      Color(0xFFF59E0B),
      Color(0xFFFBBF24),
      Color(0xFFEF4444),
    ],
  ),
  MeshPalette(
    id: 'mesh:obsidian_aurora',
    label: 'Obsidian Aurora',
    baseColor: Color(0xFF090D16),
    orbs: [
      Color(0xFF0D9488),
      Color(0xFF10B981),
      Color(0xFF6366F1),
      Color(0xFF22C55E),
    ],
  ),
];

/// Современные градиенты в стиле Apple & Linear
const List<CoverPreset> kGradientCovers = [
  CoverPreset(
    id: 'gradient:aurora',
    label: 'Aurora',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:sunset',
    label: 'Sunset',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:emerald',
    label: 'Emerald',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0BA360), Color(0xFF3CBA92)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:midnight',
    label: 'Midnight',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF18181B), Color(0xFF3F3F46)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:linear_purple',
    label: 'Linear Violet',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFC084FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:cosmic',
    label: 'Cosmic Void',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF6366F1), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:cyberpunk',
    label: 'Cyberpunk',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFF007A), Color(0xFF7928CA), Color(0xFF4338CA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:warm_amber',
    label: 'Warm Amber',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:sage',
    label: 'Sage Calm',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:nordic',
    label: 'Nordic Frost',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:rose',
    label: 'Rose Peach',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEE9CA7), Color(0xFFFFDDE1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  CoverPreset(
    id: 'gradient:monochrome',
    label: 'Titanium',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF475569)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
];

/// Минималистичные текстуры и радиальные студийные подсветки
const List<CoverPreset> kPatternCovers = [
  CoverPreset(
    id: 'pattern:studio_spotlight',
    label: 'Studio Glow',
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 1.2,
        colors: [Color(0xFF3B82F6), Color(0xFF0F172A)],
      ),
    ),
  ),
  CoverPreset(
    id: 'pattern:dark_mesh',
    label: 'Dark Ambient',
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.6, -0.4),
        radius: 1.4,
        colors: [Color(0xFF4338CA), Color(0xFF090D16)],
      ),
    ),
  ),
  CoverPreset(
    id: 'pattern:deep_space',
    label: 'Deep Space',
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.6, 0.4),
        radius: 1.3,
        colors: [Color(0xFF6D28D9), Color(0xFF030712)],
      ),
    ),
  ),
  CoverPreset(
    id: 'pattern:sunset_radial',
    label: 'Solar Flare',
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.0, 0.6),
        radius: 1.1,
        colors: [Color(0xFFEA580C), Color(0xFF18181B)],
      ),
    ),
  ),
  CoverPreset(
    id: 'pattern:aurora_borealis',
    label: 'Northern Lights',
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.2, -0.8),
        radius: 1.5,
        colors: [Color(0xFF0D9488), Color(0xFF022C22), Color(0xFF050B14)],
      ),
    ),
  ),
  CoverPreset(
    id: 'pattern:cyber_mesh',
    label: 'Neon Mesh',
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.4, -0.3),
        radius: 1.3,
        colors: [Color(0xFFD946EF), Color(0xFF312E81), Color(0xFF09090B)],
      ),
    ),
  ),
];

/// Палитра плоских цветов (Solid Colors)
const List<CoverPreset> kColorCovers = [
  CoverPreset(
    id: 'color:blue',
    label: 'Blue',
    decoration: BoxDecoration(color: Color(0xFF1A73E8)),
  ),
  CoverPreset(
    id: 'color:indigo',
    label: 'Indigo',
    decoration: BoxDecoration(color: Color(0xFF5C6BC0)),
  ),
  CoverPreset(
    id: 'color:teal',
    label: 'Teal',
    decoration: BoxDecoration(color: Color(0xFF00897B)),
  ),
  CoverPreset(
    id: 'color:green',
    label: 'Green',
    decoration: BoxDecoration(color: Color(0xFF43A047)),
  ),
  CoverPreset(
    id: 'color:amber',
    label: 'Amber',
    decoration: BoxDecoration(color: Color(0xFFFB8C00)),
  ),
  CoverPreset(
    id: 'color:red',
    label: 'Red',
    decoration: BoxDecoration(color: Color(0xFFE53935)),
  ),
  CoverPreset(
    id: 'color:purple',
    label: 'Purple',
    decoration: BoxDecoration(color: Color(0xFF8E24AA)),
  ),
  CoverPreset(
    id: 'color:graphite',
    label: 'Graphite',
    decoration: BoxDecoration(color: Color(0xFF374151)),
  ),
];

String _colorToHex(Color c) =>
    (c.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

Color? _hexToColor(String hex) {
  final val = int.tryParse(hex, radix: 16);
  if (val == null) return null;
  return Color(val);
}

/// Распознавание идентификатора mesh-обложки (предустановленной или сгенерированной)
MeshPalette? parseMeshCoverId(String coverId) {
  if (!coverId.startsWith('mesh:')) return null;

  for (final p in kAppleMeshCovers) {
    if (p.id == coverId) return p;
  }

  // Format: mesh:custom:baseHex_c1Hex_c2Hex_c3Hex_c4Hex
  if (coverId.startsWith('mesh:custom:')) {
    final parts = coverId.substring('mesh:custom:'.length).split('_');
    if (parts.length >= 4) {
      final base = _hexToColor(parts[0]);
      final orbs = <Color>[];
      for (int i = 1; i < parts.length; i++) {
        final c = _hexToColor(parts[i]);
        if (c != null) orbs.add(c);
      }
      if (base != null && orbs.length >= 3) {
        return MeshPalette(
          id: coverId,
          label: 'В тон иконке',
          baseColor: base,
          orbs: orbs,
        );
      }
    }
  }

  return kAppleMeshCovers.first;
}

/// Генерация палитры Apple Mesh-градиента в тон выбранному эмодзи или иконке
MeshPalette generateMeshFromIcon(String? icon) {
  if (icon == null || icon.trim().isEmpty) {
    return kAppleMeshCovers.first;
  }

  final clean = icon.trim();

  // 1. Природа, растения, зелень
  const nature = {'🌿', '🌱', '🌲', '🍀', '🌴', '🥑', '🍏', '🥗', '🌳', '🍃', '🌾'};
  if (nature.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Sequoia Sage',
      const Color(0xFF06281E),
      const [Color(0xFF0F766E), Color(0xFF10B981), Color(0xFF34D399), Color(0xFF047857)],
    );
  }

  // 2. Огонь, тепло, еда, закат
  const warm = {'🔥', '🍊', '🍕', '🍔', '🥐', '🦊', '🎃', '🥕', '☀️', '🌅', '🌶️'};
  if (warm.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Sonoma Amber',
      const Color(0xFF431407),
      const [Color(0xFFEA580C), Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFE11D48)],
    );
  }

  // 3. Вода, океан, лёд, снег
  const water = {'🌊', '💧', '❄️', '🐬', '🐳', '🧊', '💎', '🌧️', '⚓', '🏊'};
  if (water.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Pacific Cyan',
      const Color(0xFF082F49),
      const [Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF06B6D4), Color(0xFF0EA5E9)],
    );
  }

  // 4. Космос, магия, кибер, фиолетовый
  const cosmic = {'🔮', '🚀', '💜', '👾', '🌌', '🪐', '🦄', '✨', '🛸', '🛰️'};
  if (cosmic.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Cosmic Violet',
      const Color(0xFF1E1B4B),
      const [Color(0xFF7C3AED), Color(0xFFC084FC), Color(0xFFEC4899), Color(0xFF6366F1)],
    );
  }

  // 5. Цветы, любовь, розовый, персик
  const love = {'❤️', '💖', '🌸', '🌷', '🍓', '🍑', '🎀', '🍣', '🌺', '🌹'};
  if (love.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Sakura Blush',
      const Color(0xFF4C0519),
      const [Color(0xFFE11D48), Color(0xFFFB7185), Color(0xFFFDA4AF), Color(0xFFF43F5E)],
    );
  }

  // 6. Молния, золото, идеи, солнце
  const gold = {'⚡', '💡', '⭐', '🏆', '🔑', '🟡', '🌕', '🧀'};
  if (gold.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Solaris Gold',
      const Color(0xFF3F2005),
      const [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFEAB308), Color(0xFFFDE047)],
    );
  }

  // 7. Работа, код, металл, минимализм
  const titanium = {'💼', '💻', '⚙️', '🖥️', '📁', '🛠️', '🕶️', '☕', '🖤', '📓'};
  if (titanium.any(clean.contains)) {
    return _buildGeneratedPalette(
      'Obsidian Gray',
      const Color(0xFF0F172A),
      const [Color(0xFF334155), Color(0xFF475569), Color(0xFF64748B), Color(0xFF1E293B)],
    );
  }

  // 8. Универсальный гармонический генератор по хэшу символов
  int seed = 0;
  for (final rune in clean.runes) {
    seed = (seed * 37 + rune) & 0xFFFFFFFF;
  }
  final hue = (seed % 360).toDouble();

  final baseColor = HSLColor.fromAHSL(1.0, hue, 0.60, 0.16).toColor();
  final c1 = HSLColor.fromAHSL(1.0, (hue + 20) % 360, 0.85, 0.52).toColor();
  final c2 = HSLColor.fromAHSL(1.0, (hue + 55) % 360, 0.80, 0.58).toColor();
  final c3 = HSLColor.fromAHSL(1.0, (hue - 35 + 360) % 360, 0.75, 0.46).toColor();
  final c4 = HSLColor.fromAHSL(1.0, (hue + 130) % 360, 0.90, 0.62).toColor();

  return _buildGeneratedPalette('В тон иконке $clean', baseColor, [c1, c2, c3, c4]);
}

MeshPalette _buildGeneratedPalette(String label, Color base, List<Color> orbs) {
  final parts = [
    _colorToHex(base),
    ...orbs.map(_colorToHex),
  ];
  return MeshPalette(
    id: 'mesh:custom:${parts.join('_')}',
    label: label,
    baseColor: base,
    orbs: orbs,
  );
}

/// Отрисовка органических цветовых орбов Apple Mesh
class AppleMeshPainter extends CustomPainter {
  final MeshPalette palette;
  final double coverY;

  const AppleMeshPainter({
    required this.palette,
    this.coverY = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()..color = palette.baseColor;
    canvas.drawRect(rect, basePaint);

    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Смещение орбов по вертикали (coverY от 0.0 до 1.0, 0.5 нейтральный)
    final shiftY = (coverY - 0.5) * (h * 0.75);

    final orbs = palette.orbs;
    if (orbs.isEmpty) return;

    // 1. Верхний левый орб
    _drawRadialBlob(
      canvas: canvas,
      center: Offset(w * 0.15, (h * 0.20) - shiftY),
      radius: math.max(w * 0.55, h * 1.1),
      color: orbs[0],
    );

    // 2. Верхний правый орб
    if (orbs.length > 1) {
      _drawRadialBlob(
        canvas: canvas,
        center: Offset(w * 0.85, (h * 0.15) - shiftY),
        radius: math.max(w * 0.52, h * 1.05),
        color: orbs[1],
      );
    }

    // 3. Нижний левый орб
    if (orbs.length > 2) {
      _drawRadialBlob(
        canvas: canvas,
        center: Offset(w * 0.28, (h * 0.82) - shiftY),
        radius: math.max(w * 0.48, h * 0.95),
        color: orbs[2],
      );
    }

    // 4. Нижний правый орб
    if (orbs.length > 3) {
      _drawRadialBlob(
        canvas: canvas,
        center: Offset(w * 0.78, (h * 0.82) - shiftY),
        radius: math.max(w * 0.50, h * 1.0),
        color: orbs[3],
      );
    }
  }

  void _drawRadialBlob({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: 0.88),
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant AppleMeshPainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.coverY != coverY;
}

/// Виджет для рендеринга Apple Mesh-градиента с мягким размытием
class AppleMeshCoverWidget extends StatelessWidget {
  final MeshPalette palette;
  final double coverY;
  final BorderRadius? borderRadius;

  const AppleMeshCoverWidget({
    super.key,
    required this.palette,
    this.coverY = 0.5,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: CustomPaint(
          painter: AppleMeshPainter(
            palette: palette,
            coverY: coverY,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Универсальный баннер для любой обложки (Mesh, Gradient, Pattern, Color) с поддержкой coverY
class CoverBannerWidget extends StatelessWidget {
  final String? cover;
  final double coverY;
  final BorderRadius? borderRadius;

  const CoverBannerWidget({
    super.key,
    required this.cover,
    this.coverY = 0.5,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (cover == null || cover!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (cover!.startsWith('mesh:')) {
      final palette = parseMeshCoverId(cover!);
      if (palette != null) {
        return AppleMeshCoverWidget(
          palette: palette,
          coverY: coverY,
          borderRadius: borderRadius,
        );
      }
    }

    final alignY = ((coverY - 0.5) * 2.0).clamp(-1.0, 1.0);
    final decor = getCoverDecoration(cover, borderRadius: borderRadius, alignmentY: alignY);
    return Container(
      decoration: decor,
    );
  }
}

BoxDecoration? getCoverDecoration(
  String? coverId, {
  BorderRadius? borderRadius,
  double alignmentY = 0.0,
}) {
  if (coverId == null || coverId.isEmpty) return null;

  if (coverId.startsWith('mesh:')) {
    final mesh = parseMeshCoverId(coverId);
    if (mesh != null) {
      final orbs = mesh.orbs;
      return BoxDecoration(
        color: mesh.baseColor,
        gradient: LinearGradient(
          begin: Alignment(-0.8, -0.8 + (alignmentY * 0.3)),
          end: Alignment(0.8, 0.8 + (alignmentY * 0.3)),
          colors: [
            orbs.isNotEmpty ? orbs[0] : mesh.baseColor,
            if (orbs.length > 1) orbs[1],
            if (orbs.length > 2) orbs[2],
            if (orbs.length > 3) orbs[3] else mesh.baseColor,
          ],
        ),
        borderRadius: borderRadius,
      );
    }
  }

  for (final p in kGradientCovers) {
    if (p.id == coverId) {
      final grad = p.decoration.gradient as LinearGradient?;
      if (grad != null) {
        return BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: grad.colors,
            begin: Alignment(-1.0, -1.0 + (alignmentY * 0.4)),
            end: Alignment(1.0, 1.0 + (alignmentY * 0.4)),
          ),
        );
      }
      return p.decoration.copyWith(borderRadius: borderRadius);
    }
  }

  for (final p in kPatternCovers) {
    if (p.id == coverId) {
      final rad = p.decoration.gradient as RadialGradient?;
      if (rad != null) {
        final origCenter = rad.center as Alignment;
        return BoxDecoration(
          borderRadius: borderRadius,
          gradient: RadialGradient(
            center: Alignment(origCenter.x, origCenter.y + (alignmentY * 0.4)),
            radius: rad.radius,
            colors: rad.colors,
          ),
        );
      }
      return p.decoration.copyWith(borderRadius: borderRadius);
    }
  }

  for (final p in kColorCovers) {
    if (p.id == coverId) {
      return p.decoration.copyWith(borderRadius: borderRadius);
    }
  }

  // Fallback for hex color string: "color:#RRGGBB"
  if (coverId.startsWith('color:#')) {
    final hex = coverId.substring(7);
    final val = int.tryParse(hex, radix: 16);
    if (val != null) {
      return BoxDecoration(
        color: Color(0xFF000000 | val),
        borderRadius: borderRadius,
      );
    }
  }

  // Default fallback gradient
  return kGradientCovers.first.decoration.copyWith(borderRadius: borderRadius);
}

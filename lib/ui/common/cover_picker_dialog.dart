import 'app_dialog.dart';
import 'menu.dart';
import 'app_icons.dart';
import 'quiet_button.dart';

import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../editor/cover_presets.dart';
import '../theme.dart';

Future<String?> showCoverPickerDialog(
  BuildContext context, {
  String? currentCover,
  String? pageIcon,
}) {
  return showAppDialog<String?>(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (context) => _CoverPickerModal(
      currentCover: currentCover,
      pageIcon: pageIcon,
    ),
  );
}

class _CoverPickerModal extends StatefulWidget {
  final String? currentCover;
  final String? pageIcon;

  const _CoverPickerModal({
    this.currentCover,
    this.pageIcon,
  });

  @override
  State<_CoverPickerModal> createState() => _CoverPickerModalState();
}

class _CoverPickerModalState extends State<_CoverPickerModal> {
  int _selectedTab = 0; // 0 = Apple Mesh, 1 = Gradients, 2 = Textures, 3 = Colors

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final generatedMesh = generateMeshFromIcon(widget.pageIcon);
    final hasIcon = widget.pageIcon != null && widget.pageIcon!.trim().isNotEmpty;

    return Dialog(
      insetAnimationDuration: Motion.of(context, Motion.micro),
      insetAnimationCurve: Motion.curve,
      backgroundColor: Palette.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s24,
        vertical: UiSpace.s24,
      ),
      child: MenuCard.surface(
        width: UiLayout.coverPickerWidth + 24,
        height: UiLayout.coverPickerHeight + 40,
        color: skin.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.s18,
                UiSpace.s14,
                UiSpace.s12,
                UiSpace.s10,
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.pageCoverTitle,
                    style: TextStyle(
                      fontSize: UiType.title,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                  const Spacer(),
                  CloseCross(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Smart Match: В тон иконке
            if (hasIcon)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s16,
                  vertical: UiSpace.s4,
                ),
                child: _IconMatchBanner(
                  palette: generatedMesh,
                  icon: widget.pageIcon!,
                  isSelected: widget.currentCover == generatedMesh.id,
                  onTap: () => Navigator.of(context).pop(generatedMesh.id),
                ),
              ),

            const SizedBox(height: UiSpace.s6),

            // Tab Switcher (Apple Mesh vs Gradients vs Textures vs Colors)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Apple Mesh',
                      badge: 'Sequoia',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: UiSpace.s8),
                    _TabButton(
                      label: context.l10n.tabGradients,
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                    const SizedBox(width: UiSpace.s8),
                    _TabButton(
                      label: 'Текстуры',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                    const SizedBox(width: UiSpace.s8),
                    _TabButton(
                      label: context.l10n.tabSolidColors,
                      isSelected: _selectedTab == 3,
                      onTap: () => setState(() => _selectedTab = 3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UiSpace.s10),
            Divider(
              height: 1,
              thickness: UiSpace.s1,
              color: skin.divider.withValues(alpha: 0.4),
            ),

            // Presets Grid
            Expanded(
              child: _selectedTab == 0
                  ? GridView.builder(
                      padding: const EdgeInsets.all(UiSpace.s16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.55,
                      ),
                      itemCount: kAppleMeshCovers.length,
                      itemBuilder: (context, index) {
                        final mesh = kAppleMeshCovers[index];
                        final isSelected = mesh.id == widget.currentCover;
                        return _MeshPresetCard(
                          palette: mesh,
                          isSelected: isSelected,
                          onTap: () => Navigator.of(context).pop(mesh.id),
                        );
                      },
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(UiSpace.s16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: _selectedTab == 1
                          ? kGradientCovers.length
                          : (_selectedTab == 2
                              ? kPatternCovers.length
                              : kColorCovers.length),
                      itemBuilder: (context, index) {
                        final preset = _selectedTab == 1
                            ? kGradientCovers[index]
                            : (_selectedTab == 2
                                ? kPatternCovers[index]
                                : kColorCovers[index]);
                        final isSelected = preset.id == widget.currentCover;
                        return _CoverPresetCard(
                          preset: preset,
                          isSelected: isSelected,
                          onTap: () => Navigator.of(context).pop(preset.id),
                        );
                      },
                    ),
            ),

            // Bottom Bar
            if (widget.currentCover != null &&
                widget.currentCover!.isNotEmpty) ...[
              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.4),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s16,
                  vertical: UiSpace.s8,
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(''),
                      icon: Icon(
                        AppIcons.trash,
                        size: UiSpace.s15,
                        color: skin.destructive,
                      ),
                      label: Text(
                        context.l10n.removeCover,
                        style: TextStyle(
                          fontSize: UiType.caption,
                          fontWeight: FontWeight.w500,
                          color: skin.destructive,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s10,
                          vertical: UiSpace.s6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return InkWell(
      borderRadius: BorderRadius.circular(UiRadius.small),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s12,
          vertical: UiSpace.s6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Palette.accent.withValues(alpha: 0.14)
              : Palette.transparent,
          borderRadius: BorderRadius.circular(UiRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: UiType.caption,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Palette.accent : skin.muted,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Palette.accent : skin.hover,
                  borderRadius: BorderRadius.circular(UiRadius.badge),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Palette.onAccent : skin.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Плашка генерации обложки в тон выбранной иконке страницы
class _IconMatchBanner extends StatefulWidget {
  final MeshPalette palette;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconMatchBanner({
    required this.palette,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_IconMatchBanner> createState() => _IconMatchBannerState();
}

class _IconMatchBannerState extends State<_IconMatchBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            shape: UiRadius.squircle(
              UiRadius.control,
              side: BorderSide(
                color: widget.isSelected
                    ? Palette.accent
                    : (_hovered ? Palette.coverOutline : Palette.coverIdleOutline),
                width: widget.isSelected ? 2.0 : 1.0,
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppleMeshCoverWidget(
                palette: widget.palette,
                borderRadius: BorderRadius.circular(UiRadius.control),
              ),
              Container(
                color: Colors.black.withValues(alpha: 0.18),
                padding: const EdgeInsets.symmetric(horizontal: UiSpace.s12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: UiSpace.s10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(AppIcons.sparkles, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'В тон иконке страницы',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Гармоничный Apple Mesh на основе ${widget.icon}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.isSelected)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Palette.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          AppIcons.checkMark,
                          color: Palette.onAccent,
                          size: 12,
                        ),
                      )
                    else if (_hovered)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(UiRadius.badge),
                        ),
                        child: const Text(
                          'Применить',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка Apple Mesh-пресета
class _MeshPresetCard extends StatefulWidget {
  final MeshPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _MeshPresetCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MeshPresetCard> createState() => _MeshPresetCardState();
}

class _MeshPresetCardState extends State<_MeshPresetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          curve: Motion.curve,
          duration: Motion.of(context, Motion.micro),
          decoration: ShapeDecoration(
            shape: UiRadius.squircle(
              UiRadius.control,
              side: BorderSide(
                color: widget.isSelected
                    ? Palette.onAccent
                    : (_hovered
                          ? Palette.coverOutline
                          : Palette.coverIdleOutline),
                width: widget.isSelected ? 2.5 : (_hovered ? 1.5 : 1.0),
              ),
            ),
            shadows: widget.isSelected || _hovered
                ? [
                    BoxShadow(
                      color: skin.shadow,
                      blurRadius: UiSpace.s6,
                      offset: const Offset(0, UiSpace.s2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppleMeshCoverWidget(
                palette: widget.palette,
                borderRadius: BorderRadius.circular(UiRadius.control),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(UiRadius.control),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                alignment: Alignment.bottomLeft,
                child: Text(
                  widget.palette.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isSelected)
                const Center(
                  child: Icon(
                    AppIcons.checkMark,
                    color: Palette.onAccent,
                    size: UiSpace.s18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPresetCard extends StatefulWidget {
  final CoverPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _CoverPresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CoverPresetCard> createState() => _CoverPresetCardState();
}

class _CoverPresetCardState extends State<_CoverPresetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          curve: Motion.curve,
          duration: Motion.of(context, Motion.micro),
          decoration: widget.preset.decoration.copyWith(
            borderRadius: BorderRadius.circular(UiRadius.control),
            border: Border.all(
              color: widget.isSelected
                  ? Palette.onAccent
                  : (_hovered
                        ? Palette.coverOutline
                        : Palette.coverIdleOutline),
              width: widget.isSelected ? 2.5 : (_hovered ? 1.5 : 1.0),
            ),
            boxShadow: widget.isSelected || _hovered
                ? [
                    BoxShadow(
                      color: skin.shadow,
                      blurRadius: UiSpace.s6,
                      offset: const Offset(0, UiSpace.s2),
                    ),
                  ]
                : null,
          ),
          child: widget.isSelected
              ? const Center(
                  child: Icon(
                    AppIcons.checkMark,
                    color: Palette.onAccent,
                    size: UiSpace.s16,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

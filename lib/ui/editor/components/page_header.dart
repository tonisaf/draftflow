import 'dart:math' as math;

import '../../common/app_icons.dart';

import 'package:flutter/material.dart';

import '../../../l10n/locale_controller.dart';
import '../../common/menu.dart';
import '../../common/page_icon_view.dart';
import '../../common/quiet_button.dart';
import '../../theme.dart';
import '../cover_presets.dart';

class PageHeader extends StatefulWidget {
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final FocusNode? titleFocusNode;
  final VoidCallback? onTitleSubmitted;
  final String? icon;
  final String? cover;
  final VoidCallback onAddOrChangeIcon;
  final VoidCallback onRemoveIcon;
  final VoidCallback onAddOrChangeCover;
  final VoidCallback onRemoveCover;
  final bool compact;
  final Widget? belowTitle;
  final bool fullWidth;
  final bool coverToTop;
  final double coverY;
  final VoidCallback? onToggleCoverToTop;
  final ValueChanged<double>? onUpdateCoverY;

  const PageHeader({
    super.key,
    required this.titleController,
    required this.onTitleChanged,
    this.titleFocusNode,
    this.onTitleSubmitted,
    required this.icon,
    required this.cover,
    required this.onAddOrChangeIcon,
    required this.onRemoveIcon,
    required this.onAddOrChangeCover,
    required this.onRemoveCover,
    this.compact = false,
    this.belowTitle,
    this.fullWidth = false,
    this.coverToTop = false,
    this.coverY = 0.5,
    this.onToggleCoverToTop,
    this.onUpdateCoverY,
  });

  @override
  State<PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<PageHeader> {
  bool _isHovering = false;
  bool _isCoverHovering = false;
  bool _isRepositioning = false;
  double _tempCoverY = 0.5;

  @override
  void initState() {
    super.initState();
    _tempCoverY = widget.coverY;
  }

  @override
  void didUpdateWidget(covariant PageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coverY != oldWidget.coverY && !_isRepositioning) {
      _tempCoverY = widget.coverY;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final hasCover = widget.cover != null && widget.cover!.isNotEmpty;
    final hasIcon = widget.icon != null && widget.icon!.isNotEmpty;

    final iconTile = QuietButton(
      key: const Key('page_icon_button'),
      label: context.l10n.changeIcon,
      tooltip: context.l10n.changeIcon,
      onTap: widget.onAddOrChangeIcon,
      builder: (context, {required hover, required focus, required pressed}) =>
          Container(
            width: UiSpace.s64,
            height: UiSpace.s64,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: hasCover
                  ? skin.surface
                  : (hover || focus ? skin.hover : Palette.transparent),
              shape: UiRadius.squircle(
                UiRadius.dialog,
                side: focus
                    ? BorderSide(color: skin.outline)
                    : (hasCover
                          ? BorderSide(color: skin.hairlineBorder)
                          : BorderSide.none),
              ),
              shadows: hasCover
                  ? [
                      BoxShadow(
                        color: skin.shadow,
                        blurRadius: UiSpace.s8,
                        offset: const Offset(0, UiSpace.s2),
                      ),
                    ]
                  : null,
            ),
            // Segoe UI Emoji's visible artwork sits below the center of its
            // typographic line box. Correct the artwork, not the tile geometry.
            child: widget.icon != null && widget.icon!.startsWith('icon:')
                ? PageIconView(
                    icon: widget.icon,
                    size: 38.0,
                  )
                : Transform.translate(
                    offset: Theme.of(context).platform == TargetPlatform.windows
                        ? const Offset(0, -3.5)
                        : Offset.zero,
                    child: Text(
                      widget.icon ?? '',
                      key: const Key('page_icon_glyph'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: UiType.pageIcon,
                        height: 1,
                        fontFamilyFallback: [
                          'Segoe UI Emoji',
                          'Apple Color Emoji',
                          'Noto Color Emoji',
                        ],
                      ),
                    ),
                  ),
          ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = widget.fullWidth
              ? constraints.maxWidth
              : math.min(constraints.maxWidth, UiLayout.editorMaxWidth);
          final iconLeft =
              (constraints.maxWidth - contentWidth) / 2 + UiSpace.s40;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasCover)
                SizedBox(
                  height: UiLayout.coverHeight + (hasIcon ? UiSpace.s32 : 0),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: UiLayout.coverHeight,
                        child: MouseRegion(
                          cursor: _isRepositioning
                              ? SystemMouseCursors.resizeUpDown
                              : SystemMouseCursors.basic,
                          onEnter: (_) =>
                              setState(() => _isCoverHovering = true),
                          onExit: (_) =>
                              setState(() => _isCoverHovering = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: _isRepositioning
                                ? (details) {
                                    setState(() {
                                      final delta = details.primaryDelta! /
                                          (UiLayout.coverHeight * 0.7);
                                      _tempCoverY =
                                          (_tempCoverY - delta).clamp(0.0, 1.0);
                                    });
                                  }
                                : null,
                            child: SizedBox(
                              key: const Key('page_cover_banner'),
                              height: UiLayout.coverHeight,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CoverBannerWidget(
                                    cover: widget.cover,
                                    coverY: _isRepositioning
                                        ? _tempCoverY
                                        : widget.coverY,
                                  ),
                                  if (_isRepositioning) ...[
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: Palette.coverOverlay,
                                          shape: UiRadius.squircle(
                                            UiRadius.control,
                                          ),
                                          shadows: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              AppIcons.arrowUpDown,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Потяните для настройки положения',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            InkWell(
                                              onTap: () {
                                                final newY = _tempCoverY;
                                                setState(
                                                  () =>
                                                      _isRepositioning = false,
                                                );
                                                widget.onUpdateCoverY?.call(
                                                  newY,
                                                );
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(
                                                UiRadius.small,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Palette.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    UiRadius.small,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Сохранить',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Palette.onAccent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _tempCoverY = widget.coverY;
                                                  _isRepositioning = false;
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(
                                                UiRadius.small,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                child: Text(
                                                  'Отмена',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    AnimatedPositioned(
                                      duration: Motion.of(context, Motion.micro),
                                      curve: Motion.curve,
                                      top: UiSpace.s10 +
                                          (widget.coverToTop
                                              ? UiLayout.pageToolbarHeight
                                              : 0),
                                      right: UiSpace.s16,
                                      child: IgnorePointer(
                                        ignoring: !_isCoverHovering,
                                        child: ExcludeSemantics(
                                          excluding: !_isCoverHovering,
                                          child: Focus(
                                            descendantsAreFocusable:
                                                _isCoverHovering,
                                            child: AnimatedOpacity(
                                              curve: Motion.curve,
                                              key: const Key(
                                                'cover_actions_visibility',
                                              ),
                                              opacity: _isCoverHovering ? 1 : 0,
                                              duration: Motion.of(
                                                context,
                                                Motion.micro,
                                              ),
                                              child: DecoratedBox(
                                                decoration: ShapeDecoration(
                                                  color: Palette.coverOverlay,
                                                  shape: UiRadius.squircle(
                                                    UiRadius.control,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CoverActionButton(
                                                      icon: AppIcons.photo,
                                                      label: context
                                                          .l10n.changeCover,
                                                      onTap: widget
                                                          .onAddOrChangeCover,
                                                    ),
                                                    if (widget.onUpdateCoverY !=
                                                        null)
                                                      CoverActionButton(
                                                        buttonKey: const Key(
                                                          'cover_reposition_button',
                                                        ),
                                                        icon:
                                                            AppIcons.arrowUpDown,
                                                        label: 'Сдвинуть',
                                                        onTap: () {
                                                          setState(() {
                                                            _tempCoverY =
                                                                widget.coverY;
                                                            _isRepositioning =
                                                                true;
                                                          });
                                                        },
                                                      ),
                                                    if (widget
                                                            .onToggleCoverToTop !=
                                                        null)
                                                      CoverActionButton(
                                                        buttonKey: const Key(
                                                          'cover_to_top_button',
                                                        ),
                                                        icon: widget.coverToTop
                                                            ? AppIcons.arrowDown
                                                            : AppIcons.arrowUp,
                                                        label: widget.coverToTop
                                                            ? context.l10n
                                                                .coverBelowToolbar
                                                            : context.l10n
                                                                .coverToPanelTop,
                                                        onTap: widget
                                                            .onToggleCoverToTop!,
                                                      ),
                                                    CoverActionButton(
                                                      icon: AppIcons.trash,
                                                      label: context
                                                          .l10n.removeCover,
                                                      onTap: widget
                                                          .onRemoveCover,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasIcon)
                        Positioned(
                          left: iconLeft,
                          top: UiLayout.coverHeight - UiSpace.s32,
                          child: iconTile,
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.fullWidth
                        ? double.infinity
                        : UiLayout.editorMaxWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      UiSpace.s40,
                      hasCover
                          ? (hasIcon ? UiSpace.s16 : UiSpace.s20)
                          : UiSpace.s12,
                      UiSpace.s40,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasIcon && !hasCover) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: iconTile,
                          ),
                          const SizedBox(height: UiSpace.s16),
                        ],
                        if (!hasIcon || !hasCover)
                          Padding(
                            padding: const EdgeInsets.only(bottom: UiSpace.s6),
                            child: AnimatedOpacity(
                              curve: Motion.curve,
                              opacity: _isHovering ? 1 : 0,
                              duration: Motion.of(context, Motion.micro),
                              child: Wrap(
                                spacing: UiSpace.s6,
                                runSpacing: UiSpace.s4,
                                children: [
                                  if (!hasIcon)
                                    HeaderPillButton(
                                      icon: AppIcons.smiley,
                                      label: context.l10n.addIcon,
                                      onTap: widget.onAddOrChangeIcon,
                                    ),
                                  if (!hasCover)
                                    HeaderPillButton(
                                      icon: AppIcons.photo,
                                      label: context.l10n.addCover,
                                      onTap: widget.onAddOrChangeCover,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        TextField(
                          key: const Key('page_title_input'),
                          controller: widget.titleController,
                          focusNode: widget.titleFocusNode,
                          selectAllOnFocus: false,
                          onSubmitted: (_) => widget.onTitleSubmitted?.call(),
                          onChanged: widget.onTitleChanged,
                          contextMenuBuilder: (context, state) =>
                              appTextMenu(context, state),
                          style: TextStyle(
                            fontSize: widget.compact
                                ? UiType.peekTitle
                                : UiType.pageTitle,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6,
                            color: skin.text,
                          ),
                          decoration: InputDecoration(
                            hintText: context.l10n.untitled,
                            hintStyle: TextStyle(
                              color: skin.hint,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: UiSpace.s14),
                        if (widget.belowTitle != null) widget.belowTitle!,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HeaderPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HeaderPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) =>
          DecoratedBox(
            decoration: ShapeDecoration(
              color: hover || focus ? skin.hover : Palette.transparent,
              shape: UiRadius.squircle(
                UiRadius.small,
                side: focus
                    ? BorderSide(color: skin.outline)
                    : BorderSide.none,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UiSpace.s8,
                vertical: UiSpace.s4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: UiSpace.s14,
                    color: hover ? skin.text : skin.muted,
                  ),
                  const SizedBox(width: UiSpace.s5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.caption,
                        fontWeight: FontWeight.w500,
                        color: hover ? skin.text : skin.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class CoverActionButton extends StatelessWidget {
  const CoverActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.buttonKey,
  });
  final Key? buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => QuietButton(
    key: buttonKey,
    label: label,
    tooltip: label,
    onTap: onTap,
    builder: (context, {required hover, required focus, required pressed}) =>
        Container(
          width: UiSpace.s32,
          height: UiSpace.s32,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: hover || focus ? Palette.coverHover : Palette.transparent,
            shape: UiRadius.squircle(
              UiRadius.control,
              side: focus
                  ? const BorderSide(color: Palette.coverOutline)
                  : BorderSide.none,
            ),
          ),
          child: Icon(icon, size: UiSpace.s16, color: Palette.onAccent),
        ),
  );
}

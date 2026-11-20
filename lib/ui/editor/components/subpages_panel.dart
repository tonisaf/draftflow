import '../../common/app_icons.dart';

import 'package:flutter/material.dart' hide Page;

import '../../../data/db/app_database.dart';
import '../../../data/model/page_settings.dart';
import '../../../data/notes_repository.dart';
import '../../../l10n/locale_controller.dart';
import '../../common/quiet_button.dart';
import '../../common/section_transition.dart';
import '../../theme.dart';

class SubpagesPanel extends StatefulWidget {
  const SubpagesPanel({
    super.key,
    required this.repository,
    required this.pageId,
    this.onOpenPage,
    this.initialPage,
    this.initialChildren,
  });
  final NotesRepository repository;
  final String pageId;
  final Page? initialPage;
  final List<Page>? initialChildren;
  final ValueChanged<String>? onOpenPage;
  @override
  State<SubpagesPanel> createState() => _SubpagesPanelState();
}

class _SubpagesPanelState extends State<SubpagesPanel> {
  late Stream<List<Page>> _children;
  late Stream<Page?> _page;
  bool _expanded = true;
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _children = widget.repository.watchChildPages(widget.pageId);
    _page = widget.repository.watchPage(widget.pageId);
  }

  @override
  void didUpdateWidget(SubpagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId ||
        oldWidget.repository != widget.repository) {
      _expanded = true;
      _bind();
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final id = await widget.repository.createPage(
        parentId: widget.pageId,
        title: '',
      );
      if (mounted) {
        setState(() => _expanded = true);
        widget.onOpenPage?.call(id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.failedToCreatePage)),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Page?>(
    initialData: widget.initialPage,
    key: ValueKey(widget.pageId),
    stream: _page,
    builder: (context, pageSnapshot) {
      final parent = pageSnapshot.data;
      if (parent == null ||
          parent.trashedAt != null ||
          parent.databaseId != null) {
        return const SizedBox.shrink();
      }
      final layout = subpageLayoutFromProperties(parent.properties);
      return StreamBuilder<List<Page>>(
        initialData: widget.initialChildren,
        stream: _children,
        builder: (context, snapshot) {
          final children = snapshot.data ?? const <Page>[];
          if (children.isEmpty) return const SizedBox.shrink();
          final skin = context.skin;
          return Padding(
            key: ValueKey('subpages_${layout.name}'),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: UiSpace.s8,
                  runSpacing: UiSpace.s4,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: -8.0),
                      child: _SubpagesHeaderAction(
                        label: context.l10n.subpagesCount(children.length),
                        icon: _expanded
                            ? AppIcons.chevronDown
                            : AppIcons.chevronRight,
                        expanded: _expanded,
                        onTap: () => setState(() => _expanded = !_expanded),
                      ),
                    ),
                    _SubpagesNewPageButton(
                      label: _creating
                          ? context.l10n.creating
                          : context.l10n.newPage,
                      onTap: _creating ? null : _create,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: UiSpace.s6),
                  SectionContent(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (layout == SubpageLayout.list) {
                          return Column(
                            children: [
                              for (final (index, page) in children.indexed)
                                SectionItem(
                                  key: ValueKey(('subpage-item', page.id)),
                                  index: index,
                                  child: _SubpageLink(
                                    page: page,
                                    cards: false,
                                    onTap: widget.onOpenPage == null
                                        ? null
                                        : () => widget.onOpenPage!(page.id),
                                  ),
                                ),
                            ],
                          );
                        }
                        final width =
                            children.length == 1 ||
                                constraints.maxWidth <
                                    UiLayout.subpageCardsBreakpoint
                            ? constraints.maxWidth
                            : (constraints.maxWidth - UiSpace.s10) / 2;
                        return Wrap(
                          spacing: UiSpace.s10,
                          runSpacing: UiSpace.s10,
                          children: [
                            for (final (index, page) in children.indexed)
                              SizedBox(
                                width: width,
                                child: SectionItem(
                                  key: ValueKey(('subpage-item', page.id)),
                                  index: index,
                                  child: _SubpageLink(
                                    page: page,
                                    cards: true,
                                    onTap: widget.onOpenPage == null
                                        ? null
                                        : () => widget.onOpenPage!(page.id),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: skin.isDark
                      ? skin.hairlineBorder
                      : const Color(0x0F000000),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    },
  );
}

class _SubpagesHeaderAction extends StatelessWidget {
  const _SubpagesHeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.expanded,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return QuietButton(
      label: label,
      expanded: expanded,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) {
        final foreground = hover ? skin.text : skin.muted;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: hover || focus ? skin.hover : Palette.transparent,
            shape: UiRadius.squircle(
              UiRadius.small,
              side: focus ? BorderSide(color: skin.outline) : BorderSide.none,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s8,
              vertical: UiSpace.s5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: UiSpace.s14, color: foreground),
                const SizedBox(width: UiSpace.s5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: UiType.caption,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                      fontFeatures: UiType.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubpagesNewPageButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _SubpagesNewPageButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_SubpagesNewPageButton> createState() => _SubpagesNewPageButtonState();
}

class _SubpagesNewPageButtonState extends State<_SubpagesNewPageButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final enabled = widget.onTap != null;
    final foreground = _hover ? skin.text : skin.muted;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: ShapeDecoration(
              color: _hover
                  ? (skin.isDark ? skin.hover : const Color(0x0D000000))
                  : Palette.transparent,
              shape: UiRadius.squircle(UiRadius.small),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.plus, size: 12.0, color: foreground),
                const SizedBox(width: 4.0),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubpageLink extends StatefulWidget {
  const _SubpageLink({
    required this.page,
    required this.cards,
    required this.onTap,
  });
  final Page page;
  final bool cards;
  final VoidCallback? onTap;

  @override
  State<_SubpageLink> createState() => _SubpageLinkState();
}

class _SubpageLinkState extends State<_SubpageLink> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final title = widget.page.title.trim().isEmpty
        ? context.l10n.untitled
        : widget.page.title;

    if (widget.cards) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: QuietButton(
          key: ValueKey('subpage_${widget.page.id}'),
          label: title,
          onTap: widget.onTap,
          builder: (context, {required hover, required focus, required pressed}) =>
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: hover
                      ? skin.sidebarSelected
                      : skin.hover,
                  shape: UiRadius.squircle(
                    UiRadius.card,
                    side: BorderSide(
                      color: focus ? skin.outline : skin.hairlineBorder,
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: UiLayout.subpageCardHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(UiSpace.s14),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: UiSpace.s24,
                          child: Center(
                            child: widget.page.icon?.isNotEmpty == true
                                ? Text(
                                    widget.page.icon!,
                                    style: const TextStyle(
                                      fontSize: UiType.editorBody,
                                    ),
                                  )
                                : Icon(
                                    AppIcons.docText,
                                    size: UiSpace.s16,
                                    color: skin.muted,
                                  ),
                          ),
                        ),
                        const SizedBox(width: UiSpace.s10),
                        Expanded(
                          child: Tooltip(
                            message: title,
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: UiType.title,
                                fontWeight: FontWeight.w400,
                                color: skin.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: UiSpace.s8),
                        Icon(
                          AppIcons.chevronRight,
                          size: UiSpace.s16,
                          color: skin.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      );
    }

    // List view: px-2.5 py-2 -mx-2.5 rounded-xl hover:bg-black/[0.035] active:scale-[0.995]
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: ValueKey('subpage_${widget.page.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.995 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: -10.0, vertical: 1.0),
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: ShapeDecoration(
              color: _hover
                  ? (skin.isDark ? skin.hover : const Color(0x09000000))
                  : Palette.transparent,
              shape: UiRadius.squircle(UiRadius.control),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18.0,
                  child: Center(
                    child: widget.page.icon?.isNotEmpty == true
                        ? Text(
                            widget.page.icon!,
                            style: const TextStyle(
                              fontSize: UiType.title,
                              height: 1,
                            ),
                          )
                        : Icon(
                            AppIcons.docText,
                            size: 15.0,
                            color: _hover ? skin.text : skin.muted,
                          ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Tooltip(
                    message: title,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.title,
                        fontWeight: FontWeight.w400,
                        color: skin.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  offset: Offset(_hover ? 0.15 : 0.0, 0),
                  child: Icon(
                    AppIcons.chevronRight,
                    size: 14.0,
                    color: _hover ? skin.muted : skin.hint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

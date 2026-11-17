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
            padding: const EdgeInsets.only(bottom: UiSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: UiSpace.s8,
                  runSpacing: UiSpace.s4,
                  children: [
                    _SubpagesHeaderAction(
                      label: context.l10n.subpagesCount(children.length),
                      icon: _expanded
                          ? AppIcons.chevronDown
                          : AppIcons.chevronRight,
                      expanded: _expanded,
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                    _SubpagesHeaderAction(
                      label: _creating
                          ? context.l10n.creating
                          : context.l10n.newPage,
                      icon: AppIcons.plus,
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
                Padding(
                  padding: const EdgeInsets.only(top: UiSpace.s14),
                  child: Divider(
                    height: 1,
                    thickness: UiSpace.s1,
                    color: skin.hairlineBorder,
                  ),
                ),
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

class _SubpageLink extends StatelessWidget {
  const _SubpageLink({
    required this.page,
    required this.cards,
    required this.onTap,
  });
  final Page page;
  final bool cards;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final title = page.title.trim().isEmpty
        ? context.l10n.untitled
        : page.title;
    return Padding(
      padding: EdgeInsets.only(bottom: cards ? 0 : UiSpace.s2),
      child: QuietButton(
        key: ValueKey('subpage_${page.id}'),
        label: title,
        onTap: onTap,
        builder: (context, {required hover, required focus, required pressed}) =>
            DecoratedBox(
              decoration: ShapeDecoration(
                color: hover
                    ? skin.sidebarSelected
                    : (cards ? skin.hover : Palette.transparent),
                shape: UiRadius.squircle(
                  cards ? UiRadius.card : UiRadius.small,
                  side: focus
                      ? BorderSide(color: skin.outline)
                      : (cards
                            ? BorderSide(color: skin.hairlineBorder)
                            : BorderSide.none),
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: cards
                      ? UiLayout.subpageCardHeight
                      : DesktopUx.sidebarRowHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.all(cards ? UiSpace.s14 : UiSpace.s10),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: cards ? UiSpace.s24 : UiSpace.s18,
                        child: Center(
                          child: page.icon?.isNotEmpty == true
                              ? Text(
                                  page.icon!,
                                  style: TextStyle(
                                    fontSize: cards
                                        ? UiType.editorBody
                                        : UiType.title,
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
                            maxLines: cards ? 2 : 1,
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
}

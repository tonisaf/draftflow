import 'package:flutter/material.dart' hide Page;

import '../../../data/db/app_database.dart';
import '../../../l10n/locale_controller.dart';
import '../../common/app_icons.dart';
import '../../common/quiet_button.dart';
import '../../common/section_transition.dart';
import '../../theme.dart';

class BacklinksSection extends StatefulWidget {
  final List<Page> backlinks;
  final ValueChanged<String>? onNavigateToPage;

  const BacklinksSection({
    super.key,
    required this.backlinks,
    this.onNavigateToPage,
  });

  @override
  State<BacklinksSection> createState() => _BacklinksSectionState();
}

class _BacklinksSectionState extends State<BacklinksSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UiSpace.s40,
        UiSpace.s12,
        UiSpace.s40,
        UiSpace.s24,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: skin.hover,
          shape: UiRadius.squircle(
            UiRadius.card,
            side: BorderSide(color: skin.hairlineBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuietButton(
              label: '${context.l10n.backlinks} (${widget.backlinks.length})',
              expanded: _isExpanded,
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              builder: (context, {required hover, required focus, required pressed}) {
                return DecoratedBox(
                  decoration: ShapeDecoration(
                    color: hover || focus ? skin.hover : Palette.transparent,
                    shape: UiRadius.squircle(UiRadius.card),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiSpace.s14,
                      vertical: UiSpace.s10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.link,
                          size: UiSpace.s14,
                          color: skin.muted,
                        ),
                        const SizedBox(width: UiSpace.s8),
                        Text(
                          '${context.l10n.backlinks} (${widget.backlinks.length})',
                          style: TextStyle(
                            fontSize: UiType.caption,
                            fontWeight: FontWeight.w500,
                            color: skin.muted,
                            fontFeatures: UiType.tabular,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _isExpanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                          size: UiSpace.s14,
                          color: skin.muted,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_isExpanded) ...[
              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.hairlineBorder,
              ),
              SectionContent(
                child: Padding(
                  padding: const EdgeInsets.all(UiSpace.s10),
                  child: Wrap(
                    spacing: UiSpace.s8,
                    runSpacing: UiSpace.s6,
                    children: [
                      for (final (index, page) in widget.backlinks.indexed)
                        SectionItem(
                          key: ValueKey(('backlink-item', page.id)),
                          index: index,
                          child: BacklinkChip(
                            page: page,
                            onTap: widget.onNavigateToPage != null
                                ? () => widget.onNavigateToPage!(page.id)
                                : null,
                          ),
                        ),
                    ],
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

class BacklinkChip extends StatelessWidget {
  final Page page;
  final VoidCallback? onTap;

  const BacklinkChip({super.key, required this.page, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final title = page.title.trim().isEmpty
        ? context.l10n.untitled
        : page.title;

    return QuietButton(
      label: title,
      onTap: onTap,
      builder: (context, {required hover, required focus, required pressed}) {
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: hover ? skin.sidebarSelected : skin.card,
            shape: UiRadius.squircle(
              UiRadius.control,
              side: BorderSide(
                color: focus ? skin.outline : skin.hairlineBorder,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UiSpace.s10,
              vertical: UiSpace.s5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (page.icon != null && page.icon!.isNotEmpty) ...[
                  Text(
                    page.icon!,
                    style: const TextStyle(fontSize: UiType.body),
                  ),
                  const SizedBox(width: UiSpace.s6),
                ] else ...[
                  Icon(
                    AppIcons.docText,
                    size: UiSpace.s14,
                    color: skin.muted,
                  ),
                  const SizedBox(width: UiSpace.s6),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: UiType.caption,
                    fontWeight: FontWeight.w500,
                    color: skin.text,
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

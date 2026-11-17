import '../../common/app_icons.dart';

import 'package:flutter/material.dart';

import '../../../data/model/page_settings.dart';
import '../../../l10n/locale_controller.dart';
import '../../common/menu.dart';
import '../../common/popover.dart';
import '../../theme.dart';
import 'page_stats.dart';

class PageMoreActionsButton extends StatefulWidget {
  final VoidCallback onCopyPageLink;
  final VoidCallback onExportMarkdown;
  final VoidCallback onImportNotionCsv;
  final VoidCallback onImportMarkdown;
  final VoidCallback onCopyMarkdown;
  final VoidCallback onSaveMarkdownToFile;
  final VoidCallback onOpenBackup;
  final PageSettings pageSettings;
  final Color? iconColor;
  final ValueChanged<PageSettings>? onPageSettingsChanged;
  final SubpageLayout subpageLayout;
  final ValueChanged<SubpageLayout>? onSubpageLayoutChanged;
  final PageStats? pageStats;

  const PageMoreActionsButton({
    super.key,
    required this.onCopyPageLink,
    required this.onExportMarkdown,
    required this.onImportNotionCsv,
    required this.onImportMarkdown,
    required this.onCopyMarkdown,
    required this.onSaveMarkdownToFile,
    required this.onOpenBackup,
    this.pageSettings = const PageSettings(),
    this.iconColor,
    this.onPageSettingsChanged,
    this.subpageLayout = SubpageLayout.list,
    this.onSubpageLayoutChanged,
    this.pageStats,
  });

  @override
  State<PageMoreActionsButton> createState() => _PageMoreActionsButtonState();
}

class _PageMoreActionsButtonState extends State<PageMoreActionsButton> {
  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    var currentSettings = widget.pageSettings;
    var currentSubpageLayout = widget.subpageLayout;

    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.pageActionsMenuWidth,
      builder: (popContext, close) => StatefulBuilder(
        builder: (popContext, setMenuState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onPageSettingsChanged != null) ...[
              MenuSectionHeader(title: context.l10n.styleSection),
              MenuToggleRow(
                switchKey: const Key('page_style_small_text_switch'),
                label: context.l10n.smallText,
                glyph: AppIcons.textformatSize,
                value: currentSettings.smallText,
                onChanged: (val) {
                  setMenuState(() {
                    currentSettings = currentSettings.copyWith(smallText: val);
                  });
                  widget.onPageSettingsChanged!(currentSettings);
                },
              ),
              MenuToggleRow(
                switchKey: const Key('page_style_full_width_switch'),
                label: context.l10n.fullWidth,
                glyph: AppIcons.arrowLeftRight,
                value: currentSettings.fullWidth,
                onChanged: (val) {
                  setMenuState(() {
                    currentSettings = currentSettings.copyWith(fullWidth: val);
                  });
                  widget.onPageSettingsChanged!(currentSettings);
                },
              ),
              const MenuDivider(),
            ],
            MenuSectionHeader(title: context.l10n.pageSection),
            MenuRow(
              label: context.l10n.copyLinkToPage,
              shortcut: menuShortcut('L', alt: true),
              glyph: AppIcons.link,
              onTap: () {
                close();
                widget.onCopyPageLink();
              },
            ),
            const MenuDivider(),
            if (widget.onSubpageLayoutChanged != null) ...[
              MenuSectionHeader(title: context.l10n.subpagesSection),
              MenuRow(
                label: context.l10n.layoutList,
                glyph: AppIcons.listBullet,
                selected: currentSubpageLayout == SubpageLayout.list,
                onTap: () {
                  setMenuState(() {
                    currentSubpageLayout = SubpageLayout.list;
                  });
                  widget.onSubpageLayoutChanged!(SubpageLayout.list);
                },
              ),
              MenuRow(
                label: context.l10n.layoutCards,
                glyph: AppIcons.squareGrid2x2,
                selected: currentSubpageLayout == SubpageLayout.cards,
                onTap: () {
                  setMenuState(() {
                    currentSubpageLayout = SubpageLayout.cards;
                  });
                  widget.onSubpageLayoutChanged!(SubpageLayout.cards);
                },
              ),
              const MenuDivider(),
            ],
            MenuSectionHeader(title: context.l10n.exportSection),
            MenuRow(
              label: context.l10n.exportMarkdownEllipsis,
              shortcut: menuShortcut('E'),
              glyph: AppIcons.squareArrowUp,
              onTap: () {
                close();
                widget.onExportMarkdown();
              },
            ),
            MenuRow(
              label: context.l10n.copyMarkdown,
              glyph: AppIcons.docOnDoc,
              onTap: () {
                close();
                widget.onCopyMarkdown();
              },
            ),
            MenuRow(
              label: context.l10n.saveMdToDownloads,
              glyph: AppIcons.arrowDownToLine,
              onTap: () {
                close();
                widget.onSaveMarkdownToFile();
              },
            ),
            const MenuDivider(),
            MenuSectionHeader(title: context.l10n.importSection),
            MenuRow(
              label: context.l10n.importNotionCsvEllipsis,
              shortcut: menuShortcut('I'),
              glyph: AppIcons.table,
              onTap: () {
                close();
                widget.onImportNotionCsv();
              },
            ),
            MenuRow(
              label: context.l10n.importMarkdownEllipsis,
              glyph: AppIcons.docTextSearch,
              onTap: () {
                close();
                widget.onImportMarkdown();
              },
            ),
            const MenuDivider(),
            MenuSectionHeader(title: context.l10n.workspaceSection),
            MenuRow(
              label: context.l10n.backupRestoreEllipsis,
              glyph: AppIcons.archivebox,
              onTap: () {
                close();
                widget.onOpenBackup();
              },
            ),
            if (widget.pageStats != null) ...[
              const MenuDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s14,
                  vertical: UiSpace.s10,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.docText,
                      size: UiSpace.s14,
                      color: context.skin.muted,
                    ),
                    const SizedBox(width: UiSpace.s8),
                    Expanded(
                      child: Text(
                        widget.pageStats!.summary,
                        style: TextStyle(
                          fontSize: UiType.caption,
                          fontWeight: FontWeight.w500,
                          color: context.skin.muted,
                          fontFeatures: UiType.tabular,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return IconButton(
      key: const Key('page_more_actions_button'),
      tooltip: context.l10n.pageOptions,
      onPressed: () => _showMenu(context),
      icon: Icon(
        AppIcons.ellipsis,
        size: UiSpace.s16,
        color: widget.iconColor ?? skin.hint,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: UiSpace.s32,
        height: UiSpace.s32,
      ),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiRadius.compact),
        ),
      ),
    );
  }
}

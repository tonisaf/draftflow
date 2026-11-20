import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/app_icons.dart';
import '../theme.dart';
import 'inbox_models.dart';

class InboxCard extends StatefulWidget {
  final InboxCardData cardData;
  final VoidCallback onTap;
  final VoidCallback? onToggleArchive;
  final VoidCallback? onConvertToDoc;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onSelectDomain;

  const InboxCard({
    super.key,
    required this.cardData,
    required this.onTap,
    this.onToggleArchive,
    this.onConvertToDoc,
    this.onDelete,
    this.onSelectDomain,
  });

  @override
  State<InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<InboxCard> {
  bool _hovered = false;

  void _handleOpenLink() async {
    final urlStr = widget.cardData.metadata.url;
    if (urlStr == null || urlStr.isEmpty) return;
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0 && now.day == date.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays <= 1 || (now.day - date.day == 1 && difference.inDays < 2)) {
      return 'Вчера';
    } else {
      return '${date.day}.${date.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final meta = widget.cardData.metadata;
    final page = widget.cardData.page;
    final type = meta.type;
    final domain = meta.domain ?? '';

    final rawTitle = page.title.trim();
    String cleanTitle = rawTitle;
    for (final prefix in ['📄', '📌', '🔖', '💬', '📸', '📝', '🔗', '🌐']) {
      if (cleanTitle.startsWith(prefix)) {
        cleanTitle = cleanTitle.substring(prefix.length).trim();
        break;
      }
    }
    // Clean any rogue lone surrogates or replacement characters
    cleanTitle = cleanTitle.replaceAll(RegExp(r'[\uD800-\uDFFF\uFFFD]'), '').trim();
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : (meta.url ?? 'Без названия');

    final borderColor = _hovered
        ? (skin.isDark
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.12))
        : skin.hairlineBorder;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(UiRadius.card),
      side: BorderSide(
        color: borderColor,
        width: 1.0,
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -1.0 : 0.0, 0),
          decoration: ShapeDecoration(
            color: skin.card,
            shape: shape,
            shadows: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: skin.isDark ? 0.30 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : skin.cardShadows,
          ),
          padding: const EdgeInsets.all(UiSpace.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Верхняя полоса: Домен / Источник и Бейдж типа
              Padding(
                padding: const EdgeInsets.only(bottom: UiSpace.s4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (domain.isNotEmpty)
                      GestureDetector(
                        onTap: widget.onSelectDomain != null
                            ? () => widget.onSelectDomain!(domain)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (meta.faviconUrl != null && meta.faviconUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Image.network(
                                  meta.faviconUrl!,
                                  width: 12,
                                  height: 12,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(AppIcons.globe, size: 11, color: skin.muted),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              domain,
                              style: TextStyle(
                                fontSize: UiType.small,
                                fontWeight: FontWeight.w600,
                                color: skin.muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: UiType.small,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: type == InboxItemType.article ? Palette.accent : skin.muted,
                        ),
                      ),

                    if (domain.isNotEmpty)
                      Text(
                        type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: UiType.small,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: type == InboxItemType.article ? Palette.accent : skin.muted,
                        ),
                      ),
                  ],
                ),
              ),

              // Заголовок карточки
              if (displayTitle.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s6),
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UiType.title,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: skin.text,
                  ),
                ),
              ],

              // Сниппет / Текст цитаты
              if (widget.cardData.textSnippet.isNotEmpty &&
                  widget.cardData.textSnippet != displayTitle) ...[
                const SizedBox(height: UiSpace.s6),
                Text(
                  widget.cardData.textSnippet,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UiType.body,
                    height: 1.35,
                    color: skin.text.withValues(alpha: 0.85),
                  ),
                ),
              ],

              // Превью-изображение (если есть)
              if (meta.previewImageUrl != null && meta.previewImageUrl!.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      meta.previewImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: UiSpace.s10),

              // Подвал карточки: Hover-действия слева, Дата справа (как в Quick Notes)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IgnorePointer(
                    ignoring: !_hovered,
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 140),
                      child: Row(
                        children: [
                          if (meta.url != null && meta.url!.isNotEmpty) ...[
                            _CardIconButton(
                              icon: AppIcons.link,
                              tooltip: 'Перейти на сайт',
                              onTap: _handleOpenLink,
                            ),
                            const SizedBox(width: UiSpace.s4),
                          ],
                          _CardIconButton(
                            icon: meta.isArchived ? AppIcons.tray : AppIcons.checkmark,
                            tooltip: meta.isArchived ? 'Во входящие' : 'В архив',
                            onTap: () => widget.onToggleArchive?.call(),
                          ),
                          if (widget.onConvertToDoc != null) ...[
                            const SizedBox(width: UiSpace.s4),
                            _CardIconButton(
                              icon: AppIcons.folder,
                              tooltip: 'Преобразовать в проект',
                              onTap: () => widget.onConvertToDoc?.call(),
                            ),
                          ],
                          if (widget.onDelete != null) ...[
                            const SizedBox(width: UiSpace.s4),
                            _CardIconButton(
                              icon: AppIcons.trash,
                              tooltip: 'Удалить',
                              onTap: () => widget.onDelete?.call(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(meta.savedAt ?? page.createdAt),
                    style: TextStyle(
                      fontSize: UiType.small,
                      color: skin.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<_CardIconButton> createState() => _CardIconButtonState();
}

class _CardIconButtonState extends State<_CardIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      verticalOffset: UiSpace.s12,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: UiSpace.s24,
            height: UiSpace.s24,
            decoration: ShapeDecoration(
              color: _hovered ? skin.controlHover : Palette.transparent,
              shape: UiRadius.squircle(UiRadius.control),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: UiSpace.s14,
                color: widget.iconColor ?? (_hovered ? skin.text : skin.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

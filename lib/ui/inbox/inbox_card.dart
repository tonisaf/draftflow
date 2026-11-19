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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final meta = widget.cardData.metadata;
    final page = widget.cardData.page;
    final type = meta.type;
    final domain = meta.domain ?? '';

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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Превью-изображение (OG Image или скриншот)
              if (meta.previewImageUrl != null && meta.previewImageUrl!.isNotEmpty)
                _buildPreviewImage(meta.previewImageUrl!),

              Padding(
                padding: const EdgeInsets.all(UiSpace.s14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Верхняя полоса: Домен + Фавиконка и Бейдж типа
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (domain.isNotEmpty)
                          _buildDomainChip(domain, meta.faviconUrl, skin)
                        else
                          const SizedBox.shrink(),

                        _buildTypeBadge(type, skin),
                      ],
                    ),

                    const SizedBox(height: UiSpace.s10),

                    // Заголовок карточки
                    Text(
                      page.title.isNotEmpty ? page.title : (meta.url ?? 'Без названия'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                        height: 1.3,
                        letterSpacing: -0.1,
                      ),
                    ),

                    // Сниппет / Текст цитаты
                    if (widget.cardData.textSnippet.isNotEmpty) ...[
                      const SizedBox(height: UiSpace.s6),
                      if (type == InboxItemType.quote)
                        Container(
                          padding: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Palette.accent.withValues(alpha: 0.6),
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            widget.cardData.textSnippet,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: skin.muted,
                              height: 1.4,
                            ),
                          ),
                        )
                      else
                        Text(
                          widget.cardData.textSnippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: skin.muted,
                            height: 1.4,
                          ),
                        ),
                    ],

                    const SizedBox(height: UiSpace.s12),

                    // Нижний тулбар: Дата и Быстрые hover-действия
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(meta.savedAt ?? page.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: skin.muted.withValues(alpha: 0.7),
                          ),
                        ),

                        // Кнопки действий при ховере
                        AnimatedOpacity(
                          opacity: _hovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 140),
                          child: IgnorePointer(
                            ignoring: !_hovered,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (meta.url != null && meta.url!.isNotEmpty)
                                  _CardActionButton(
                                    icon: AppIcons.arrowUpRight,
                                    tooltip: 'Открыть в браузере',
                                    onTap: _handleOpenLink,
                                  ),
                                if (widget.onConvertToDoc != null)
                                  _CardActionButton(
                                    icon: AppIcons.folder,
                                    tooltip: 'Преобразовать в документ',
                                    onTap: widget.onConvertToDoc,
                                  ),
                                if (widget.onToggleArchive != null)
                                  _CardActionButton(
                                    icon: meta.isArchived
                                        ? AppIcons.tray
                                        : AppIcons.checkmark,
                                    tooltip: meta.isArchived
                                        ? 'Вернуть во входящие'
                                        : 'Обработано (В архив)',
                                    iconColor: meta.isArchived
                                        ? null
                                        : const Color(0xFF16A34A),
                                    onTap: widget.onToggleArchive,
                                  ),
                                if (widget.onDelete != null)
                                  _CardActionButton(
                                    icon: AppIcons.trash,
                                    tooltip: 'Удалить',
                                    isDestructive: true,
                                    onTap: widget.onDelete,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildPreviewImage(String imageUrl) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildDomainChip(String domain, String? faviconUrl, AppSkin skin) {
    return GestureDetector(
      onTap: widget.onSelectDomain != null ? () => widget.onSelectDomain!(domain) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: skin.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faviconUrl != null && faviconUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.network(
                  faviconUrl,
                  width: 12,
                  height: 12,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    AppIcons.globe,
                    size: 11,
                    color: skin.muted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ] else ...[
              Icon(AppIcons.globe, size: 11, color: skin.muted),
              const SizedBox(width: 4),
            ],
            Text(
              domain,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: skin.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(InboxItemType type, AppSkin skin) {
    Color bg;
    Color fg;

    switch (type) {
      case InboxItemType.article:
        bg = Palette.accent.withValues(alpha: 0.10);
        fg = Palette.accent;
        break;
      case InboxItemType.link:
        bg = skin.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05);
        fg = skin.muted;
        break;
      case InboxItemType.quote:
        bg = const Color(0xFFD97706).withValues(alpha: 0.12);
        fg = const Color(0xFFD97706);
        break;
      case InboxItemType.screenshot:
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        fg = const Color(0xFF8B5CF6);
        break;
      case InboxItemType.note:
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: fg),
          const SizedBox(width: 3.5),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays == 0) {
      return 'Сегодня, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Вчера';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }
}

class _CardActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDestructive;

  const _CardActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  State<_CardActionButton> createState() => _CardActionButtonState();
}

class _CardActionButtonState extends State<_CardActionButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    Color bg;
    Color fg;

    if (widget.isDestructive) {
      bg = _hover ? Colors.red.withValues(alpha: 0.12) : Colors.transparent;
      fg = _hover ? const Color(0xFFDC2626) : skin.muted;
    } else {
      bg = _hover
          ? (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06))
          : Colors.transparent;
      fg = widget.iconColor ?? (_hover ? skin.text : skin.muted);
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 26,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 14,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

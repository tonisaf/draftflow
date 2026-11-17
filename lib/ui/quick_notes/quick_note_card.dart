import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../l10n/locale_controller.dart';
import '../common/app_icons.dart';
import '../common/page_icon_view.dart';
import '../theme.dart';
import 'quick_note_colors.dart';
import 'quick_note_models.dart';

class QuickNoteCard extends StatefulWidget {
  final QuickNoteCardData cardData;
  final ValueChanged<String> onOpenPage;
  final VoidCallback onTogglePin;
  final ValueChanged<String>? onTrashPage;
  final ValueChanged<String>? onTagTap;

  const QuickNoteCard({
    super.key,
    required this.cardData,
    required this.onOpenPage,
    required this.onTogglePin,
    this.onTrashPage,
    this.onTagTap,
  });

  @override
  State<QuickNoteCard> createState() => _QuickNoteCardState();
}

class _QuickNoteCardState extends State<QuickNoteCard> {
  bool _hovered = false;

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(AppIcons.checkMark, size: UiSpace.s16, color: Palette.onAccent),
            const SizedBox(width: UiSpace.s8),
            Text(message),
          ],
        ),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiRadius.control),
        ),
      ),
    );
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
    final cardData = widget.cardData;
    final page = cardData.page;
    final isPinned = cardData.settings.isPinned;
    final rawTitle = page.title.trim();
    final bool hasExplicitTitle = rawTitle.isNotEmpty &&
        rawTitle != 'Untitled' &&
        rawTitle != cardData.codeSnippet?.trim() &&
        rawTitle != cardData.textSnippet.trim();
    final String title = hasExplicitTitle
        ? rawTitle
        : (cardData.codeSnippet == null &&
                cardData.textSnippet.isEmpty &&
                cardData.todoItems.isEmpty &&
                cardData.listItems.isEmpty
            ? context.l10n.untitled
            : '');

    String? categoryTag;
    Color? tagColor;
    if (cardData.codeSnippet != null) {
      categoryTag = '⚡ ${cardData.codeLanguage ?? 'CODE'}';
      tagColor = Palette.accent;
    } else if (cardData.todoItems.isNotEmpty) {
      categoryTag = '☑ ЧЕК-ЛИСТ';
      tagColor = Palette.success;
    } else if (cardData.listItems.isNotEmpty) {
      categoryTag = '≡ СПИСОК';
      tagColor = Palette.accent;
    }

    final shape = UiRadius.squircle(
      UiRadius.card,
      side: BorderSide(
        color: _hovered
            ? (isPinned ? Palette.accent.withValues(alpha: 0.55) : skin.outline.withValues(alpha: 0.35))
            : skin.hairlineBorder,
        width: UiSpace.s1,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onOpenPage(page.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            color: QuickNoteColors.getBackground(cardData.settings.cardColor, skin),
            shape: shape,
            shadows: _hovered
                ? [
                    BoxShadow(
                      color: skin.shadow.withValues(alpha: 0.09),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: skin.shadow.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : skin.cardShadows,
          ),
          padding: const EdgeInsets.all(UiSpace.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Верхняя полоса: Категория или иконка и Кнопка закрепления (Pin)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (categoryTag != null)
                    Row(
                      children: [
                        Text(
                          categoryTag,
                          style: TextStyle(
                            fontSize: UiType.small,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: tagColor,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        if (page.icon?.isNotEmpty == true)
                          PageIconView(icon: page.icon!, size: UiType.caption)
                        else
                          Icon(AppIcons.docText, size: UiSpace.s13, color: skin.muted),
                      ],
                    ),
                  AnimatedOpacity(
                    opacity: (isPinned || _hovered) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 140),
                    child: IgnorePointer(
                      ignoring: !isPinned && !_hovered,
                      child: _CardIconButton(
                        icon: isPinned ? AppIcons.pinFill : AppIcons.pin,
                        tooltip: isPinned ? 'Открепить' : 'Закрепить',
                        iconColor: isPinned ? Palette.accent : null,
                        onTap: widget.onTogglePin,
                      ),
                    ),
                  ),
                ],
              ),
              // Заголовок карточки (если есть отдельный заголовок)
              if (title.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s6),
                Text(
                  title,
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

              // Текстовый сниппет
              if (cardData.textSnippet.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s6),
                Text(
                  cardData.textSnippet,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UiType.body,
                    height: 1.35,
                    color: skin.text.withValues(alpha: 0.85),
                  ),
                ),
              ],

              // Чек-лист
              if (cardData.todoItems.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < cardData.todoItems.length.clamp(0, 4); i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: UiSpace.s3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: UiSpace.s2),
                              child: Icon(
                                cardData.todoItems[i].isChecked
                                    ? AppIcons.checkmarkSquare
                                    : AppIcons.square,
                                size: UiSpace.s14,
                                color: cardData.todoItems[i].isChecked
                                    ? Palette.accent
                                    : skin.muted,
                              ),
                            ),
                            const SizedBox(width: UiSpace.s6),
                            Expanded(
                              child: Text(
                                cardData.todoItems[i].text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  decoration: cardData.todoItems[i].isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: cardData.todoItems[i].isChecked
                                      ? skin.muted
                                      : skin.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (cardData.todoItems.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(left: UiSpace.s20, top: UiSpace.s2),
                        child: Text(
                          '+ ещё ${cardData.todoItems.length - 4} пунктов',
                          style: TextStyle(
                            fontSize: UiType.small,
                            color: skin.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // Маркированные и нумерованные списки
              if (cardData.listItems.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < cardData.listItems.length.clamp(0, 4); i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: UiSpace.s3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: UiSpace.s14,
                              child: Text(
                                cardData.listItems[i].isNumbered
                                    ? '${cardData.listItems[i].number}.'
                                    : '•',
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  fontWeight: FontWeight.w600,
                                  color: skin.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: UiSpace.s4),
                            Expanded(
                              child: Text(
                                cardData.listItems[i].text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  color: skin.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (cardData.listItems.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(left: UiSpace.s18, top: UiSpace.s2),
                        child: Text(
                          '+ ещё ${cardData.listItems.length - 4} пунктов',
                          style: TextStyle(
                            fontSize: UiType.small,
                            color: skin.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // Блок кода в стиле Google Keep / терминала
              if (cardData.codeSnippet != null) ...[
                const SizedBox(height: UiSpace.s8),
                Container(
                  decoration: BoxDecoration(
                    color: skin.codeSurface,
                    borderRadius: BorderRadius.circular(UiRadius.control),
                    border: Border.all(color: skin.hairlineBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Шапка блока кода
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s10,
                          vertical: UiSpace.s6,
                        ),
                        decoration: BoxDecoration(
                          color: skin.codeBadge,
                          border: Border(bottom: BorderSide(color: skin.hairlineBorder)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.chevronLeftSlashChevronRight,
                                    size: UiSpace.s12,
                                    color: Palette.accent,
                                  ),
                                  const SizedBox(width: UiSpace.s6),
                                  Text(
                                    cardData.codeLanguage ?? 'BASH',
                                    style: TextStyle(
                                      fontSize: UiType.small,
                                      fontFamily: 'Consolas',
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: Palette.accent,
                                    ),
                                  ),
                                  if (cardData.codeTitle != null) ...[
                                    const SizedBox(width: UiSpace.s8),
                                    Expanded(
                                      child: Text(
                                        cardData.codeTitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: UiType.small,
                                          color: skin.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                context,
                                cardData.codeSnippet!,
                                context.l10n.copiedToClipboard,
                              ),
                              child: Tooltip(
                                message: context.l10n.copiedToClipboard,
                                child: Icon(
                                  AppIcons.docOnDoc,
                                  size: UiSpace.s13,
                                  color: skin.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Тело кода
                      Padding(
                        padding: const EdgeInsets.all(UiSpace.s8),
                        child: Text(
                          cardData.codeSnippet!,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: UiType.code,
                            height: UiType.codeLineHeight,
                            color: skin.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Интерактивные теги заметки
              if (cardData.extractedTags.isNotEmpty) ...[
                const SizedBox(height: UiSpace.s8),
                Wrap(
                  spacing: UiSpace.s4,
                  runSpacing: UiSpace.s4,
                  children: [
                    for (final tag in cardData.extractedTags)
                      GestureDetector(
                        onTap: widget.onTagTap != null
                            ? () => widget.onTagTap!(tag)
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiSpace.s6,
                            vertical: 1.5,
                          ),
                          decoration: ShapeDecoration(
                            color: skin.hover,
                            shape: const StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.tag, size: UiSpace.s10, color: skin.muted),
                              const SizedBox(width: UiSpace.s3),
                              Text(
                                tag.startsWith('#') ? tag : '#$tag',
                                style: TextStyle(
                                  fontSize: UiType.small,
                                  fontWeight: FontWeight.w500,
                                  color: skin.text.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: UiSpace.s10),

              // Подвал карточки: Дата и быстрые действия
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
                          _CardIconButton(
                            icon: AppIcons.docOnDoc,
                            tooltip: 'Копировать',
                            onTap: () {
                              final fullText = StringBuffer()
                                ..writeln(title)
                                ..writeln()
                                ..writeln(cardData.textSnippet);
                              if (cardData.codeSnippet != null) {
                                fullText.writeln(cardData.codeSnippet);
                              }
                              _copyToClipboard(
                                context,
                                fullText.toString().trim(),
                                context.l10n.copiedToClipboard,
                              );
                            },
                          ),
                          const SizedBox(width: UiSpace.s4),
                          if (widget.onTrashPage != null)
                            _CardIconButton(
                              icon: AppIcons.trash,
                              tooltip: 'В корзину',
                              onTap: () => widget.onTrashPage!(page.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(page.createdAt),
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
      waitDuration: Motion.tooltipDelay,
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

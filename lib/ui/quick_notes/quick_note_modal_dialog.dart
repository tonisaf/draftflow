import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../common/app_icons.dart';
import '../theme.dart';
import 'quick_note_colors.dart';
import 'quick_note_models.dart';

class QuickNoteModalDialog extends StatefulWidget {
  final QuickNoteCardData cardData;
  final NotesRepository repository;
  final VoidCallback? onSaved;

  const QuickNoteModalDialog({
    super.key,
    required this.cardData,
    required this.repository,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required QuickNoteCardData cardData,
    required NotesRepository repository,
    Rect? originRect,
    VoidCallback? onSaved,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    final alignment = originRect != null && screenSize.width > 0 && screenSize.height > 0
        ? Alignment(
            ((originRect.center.dx / screenSize.width) * 2 - 1).clamp(-1.0, 1.0),
            ((originRect.center.dy / screenSize.height) * 2 - 1).clamp(-1.0, 1.0),
          )
        : Alignment.center;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close note',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, secondaryAnim) => QuickNoteModalDialog(
        cardData: cardData,
        repository: repository,
        onSaved: onSaved,
      ),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 2.0 * animation.value,
            sigmaY: 2.0 * animation.value,
          ),
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              alignment: alignment,
              scale: Tween<double>(begin: 0.65, end: 1.0).animate(curve),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<QuickNoteModalDialog> createState() => _QuickNoteModalDialogState();
}

class _QuickNoteModalDialogState extends State<QuickNoteModalDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  late bool _isPinned;
  late String? _cardColor;
  late String? _tag;
  late bool _isCode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final rawTitle = widget.cardData.page.title.trim();
    final initialBody = (widget.cardData.codeSnippet != null && widget.cardData.codeSnippet!.isNotEmpty)
        ? widget.cardData.codeSnippet!
        : widget.cardData.textSnippet;
    final initialTitle = (rawTitle == 'Untitled' || rawTitle == initialBody.trim())
        ? ''
        : rawTitle;
    _titleController = TextEditingController(text: initialTitle);
    _bodyController = TextEditingController(text: initialBody);
    _isPinned = widget.cardData.settings.isPinned;
    _cardColor = widget.cardData.settings.cardColor;
    _tag = widget.cardData.settings.tag;
    _isCode = widget.cardData.codeSnippet != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      await widget.repository.updateQuickNote(
        pageId: widget.cardData.page.id,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        isPinned: _isPinned,
        cardColor: _cardColor,
        tag: _tag,
        isCode: _isCode,
      );
      widget.onSaved?.call();
    } catch (_) {
      // Ignored
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _handleDelete() async {
    final pageId = widget.cardData.page.id;
    Navigator.of(context, rootNavigator: true).pop();
    await widget.repository.trashPage(pageId);
    widget.onSaved?.call();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && now.day == date.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Сегодня, $hour:$minute';
    } else if (difference.inDays <= 1 || (now.day - date.day == 1 && difference.inDays < 2)) {
      return 'Вчера';
    } else {
      return '${date.day}.${date.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final backgroundColor = QuickNoteColors.getBackground(_cardColor, skin);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_isSaving) {
          _isSaving = true;
          widget.repository.updateQuickNote(
            pageId: widget.cardData.page.id,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            isPinned: _isPinned,
            cardColor: _cardColor,
            tag: _tag,
            isCode: _isCode,
          ).then((_) => widget.onSaved?.call());
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _saveAndClose,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  minWidth: 360,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(UiRadius.dialog),
                    border: Border.all(
                      color: skin.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: skin.isDark ? 0.35 : 0.12),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: skin.isDark ? 0.15 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Шапка: Заголовок и булавка закрепления
                      Padding(
                        padding: const EdgeInsets.fromLTRB(UiSpace.s20, UiSpace.s16, UiSpace.s12, UiSpace.s6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _titleController,
                                selectAllOnFocus: false,
                                style: TextStyle(
                                  fontSize: UiType.pageTitle * 0.75,
                                  fontWeight: FontWeight.w700,
                                  color: skin.text,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Заголовок',
                                  hintStyle: TextStyle(
                                    fontSize: UiType.pageTitle * 0.75,
                                    fontWeight: FontWeight.w700,
                                    color: skin.muted.withValues(alpha: 0.6),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            _ModalIconButton(
                              tooltip: _isPinned ? context.l10n.unpin : context.l10n.pin,
                              onTap: () => setState(() => _isPinned = !_isPinned),
                              icon: _isPinned ? AppIcons.pinFill : AppIcons.pin,
                              iconColor: _isPinned ? Palette.accent : null,
                            ),
                          ],
                        ),
                      ),

                  // Выбранный тег (если есть)
                  if (_tag != null && _tag!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UiSpace.s20, vertical: UiSpace.s4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8, vertical: UiSpace.s2),
                          decoration: ShapeDecoration(
                            color: skin.hover,
                            shape: const StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.tag, size: UiSpace.s12, color: skin.muted),
                              const SizedBox(width: UiSpace.s4),
                              Text(
                                '#$_tag',
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  fontWeight: FontWeight.w600,
                                  color: skin.text,
                                ),
                              ),
                              const SizedBox(width: UiSpace.s4),
                              GestureDetector(
                                onTap: () => setState(() => _tag = null),
                                child: const Icon(AppIcons.xmark, size: UiSpace.s10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Тело заметки: редактируемый текст
                  Padding(
                    padding: const EdgeInsets.fromLTRB(UiSpace.s20, UiSpace.s8, UiSpace.s20, UiSpace.s16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 120,
                        maxHeight: 380,
                      ),
                      child: _isCode
                          ? Container(
                              decoration: BoxDecoration(
                                color: skin.codeSurface,
                                borderRadius: BorderRadius.circular(UiRadius.control),
                                border: Border.all(color: skin.hairlineBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: UiSpace.s10,
                                      vertical: UiSpace.s6,
                                    ),
                                    color: skin.codeBadge,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(AppIcons.chevronLeftSlashChevronRight, size: UiSpace.s12, color: Palette.accent),
                                            const SizedBox(width: UiSpace.s6),
                                            Text(
                                              widget.cardData.codeLanguage ?? 'BASH',
                                              style: TextStyle(
                                                fontSize: UiType.small,
                                                fontFamily: 'Consolas',
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                color: Palette.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: _bodyController.text));
                                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                              SnackBar(
                                                content: Text(context.l10n.copiedToClipboard),
                                                duration: const Duration(milliseconds: 1200),
                                              ),
                                            );
                                          },
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
                                  Flexible(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(UiSpace.s12),
                                      child: TextField(
                                        controller: _bodyController,
                                        maxLines: null,
                                        minLines: 5,
                                        style: TextStyle(
                                          fontSize: UiType.code,
                                          fontFamily: 'Consolas',
                                          height: 1.4,
                                          color: skin.codeText,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Скрипт, пресет или код…',
                                          hintStyle: TextStyle(
                                            fontSize: UiType.code,
                                            color: skin.muted.withValues(alpha: 0.6),
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: TextField(
                                controller: _bodyController,
                                maxLines: null,
                                minLines: 5,
                                style: TextStyle(
                                  fontSize: UiType.body,
                                  height: 1.45,
                                  color: skin.text,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Заметка…',
                                  hintStyle: TextStyle(
                                    fontSize: UiType.body,
                                    color: skin.muted.withValues(alpha: 0.6),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Нижняя панель действий (в точности как в Google Keep)
                  Container(
                    padding: const EdgeInsets.fromLTRB(UiSpace.s14, UiSpace.s8, UiSpace.s16, UiSpace.s12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: skin.divider.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Инструменты: Код, Цвет, Тег, Разделитель, Удалить
                        Row(
                          children: [
                            // Переключатель Код / Текст
                            _ModalIconButton(
                              icon: AppIcons.bolt,
                              tooltip: _isCode ? 'Обычный текст' : 'Формат: Код / Пресет',
                              iconColor: _isCode ? Palette.accent : null,
                              onTap: () => setState(() => _isCode = !_isCode),
                            ),
                            const SizedBox(width: UiSpace.s4),

                            // Выбор цвета
                            PopupMenuButton<String>(
                              tooltip: '',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              offset: const Offset(0, 36),
                              color: skin.glassSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(UiRadius.control),
                                side: BorderSide(color: skin.divider),
                              ),
                              onSelected: (color) => setState(() => _cardColor = color),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  enabled: false,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final c in QuickNoteColors.all)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() => _cardColor = c);
                                            Navigator.of(context).pop();
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: QuickNoteColors.getSwatch(c),
                                              border: Border.all(
                                                color: _cardColor == c ? Palette.accent : skin.hairlineBorder,
                                                width: _cardColor == c ? 2 : 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              child: _ModalIconButton(
                                tooltip: 'Цвет заметки',
                                child: (_cardColor != null && _cardColor != QuickNoteColors.defaultColor)
                                    ? Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: QuickNoteColors.getSwatch(_cardColor!),
                                          border: Border.all(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            width: 1.0,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        AppIcons.palette,
                                        size: 16,
                                      ),
                              ),
                            ),
                            const SizedBox(width: UiSpace.s4),

                            // Выбор тега
                            PopupMenuButton<String>(
                              tooltip: '',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              offset: const Offset(0, 36),
                              color: skin.glassSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(UiRadius.control),
                                side: BorderSide(color: skin.divider),
                              ),
                              onSelected: (t) => setState(() => _tag = t),
                              itemBuilder: (context) => [
                                for (final t in ['Работа', 'Личное', 'Идея', 'Важно', 'Код', 'Срочно'])
                                  PopupMenuItem(
                                    value: t,
                                    child: Row(
                                      children: [
                                        Icon(AppIcons.tag, size: UiSpace.s12, color: skin.muted),
                                        const SizedBox(width: UiSpace.s8),
                                        Text(t, style: TextStyle(fontSize: UiType.caption, color: skin.text)),
                                      ],
                                    ),
                                  ),
                              ],
                              child: _ModalIconButton(
                                icon: AppIcons.tag,
                                tooltip: 'Тег',
                                iconColor: _tag != null ? Palette.accent : null,
                              ),
                            ),

                            // Вертикальный волосяной разделитель
                            Container(
                              width: 1,
                              height: 16,
                              margin: const EdgeInsets.symmetric(horizontal: UiSpace.s4),
                              color: skin.isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),

                            // Кнопка удаления (деструктивное действие)
                            _ModalIconButton(
                              icon: AppIcons.trash,
                              tooltip: 'Удалить заметку',
                              isDestructive: true,
                              onTap: _handleDelete,
                            ),

                            const SizedBox(width: UiSpace.s16),

                            Text(
                              'Изменено ${_formatDate(widget.cardData.page.createdAt)}',
                              style: TextStyle(
                                fontSize: UiType.small,
                                color: skin.muted,
                              ),
                            ),
                          ],
                        ),

                        // Кнопка "Закрыть"
                        _ModalCloseButton(
                          onPressed: _saveAndClose,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}

class _ModalIconButton extends StatefulWidget {
  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDestructive;

  const _ModalIconButton({
    this.icon,
    this.child,
    required this.tooltip,
    this.onTap,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  State<_ModalIconButton> createState() => _ModalIconButtonState();
}

class _ModalIconButtonState extends State<_ModalIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    Color bg;
    Color? iconColor;

    if (widget.isDestructive) {
      bg = _hovered
          ? Colors.red.withValues(alpha: isDark ? 0.20 : 0.10)
          : Colors.transparent;
      iconColor = _hovered
          ? const Color(0xFFDC2626)
          : (widget.iconColor ?? skin.muted);
    } else {
      bg = _hovered
          ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
      iconColor = widget.iconColor ?? (_hovered ? skin.text : skin.muted);
    }

    final content = AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: widget.child ??
              Icon(
                widget.icon,
                size: 16,
                color: iconColor,
              ),
        ),
      ),
    );

    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      verticalOffset: UiSpace.s16,
      waitDuration: Motion.tooltipDelay,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: widget.onTap != null
            ? GestureDetector(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                behavior: HitTestBehavior.opaque,
                child: content,
              )
            : Listener(
                onPointerDown: (_) => setState(() => _pressed = true),
                onPointerUp: (_) => setState(() => _pressed = false),
                onPointerCancel: (_) => setState(() => _pressed = false),
                child: content,
              ),
      ),
    );
  }
}

class _ModalCloseButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ModalCloseButton({required this.onPressed});

  @override
  State<_ModalCloseButton> createState() => _ModalCloseButtonState();
}

class _ModalCloseButtonState extends State<_ModalCloseButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    final bgColor = _hovered
        ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04));

    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Закрыть',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

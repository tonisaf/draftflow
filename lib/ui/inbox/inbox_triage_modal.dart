import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/notes_repository.dart';
import '../common/app_icons.dart';
import '../theme.dart';
import 'inbox_models.dart';

class InboxTriageModal extends StatelessWidget {
  final InboxCardData cardData;
  final NotesRepository repository;
  final VoidCallback? onUpdated;

  const InboxTriageModal({
    super.key,
    required this.cardData,
    required this.repository,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required InboxCardData cardData,
    required NotesRepository repository,
    VoidCallback? onUpdated,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close triage',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim, secondaryAnim) => InboxTriageModal(
        cardData: cardData,
        repository: repository,
        onUpdated: onUpdated,
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
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _openExternalUrl(String? urlStr) async {
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
    final isDark = skin.isDark;
    final meta = cardData.metadata;
    final page = cardData.page;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          minWidth: 380,
          maxHeight: 700,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: skin.card,
            borderRadius: BorderRadius.circular(UiRadius.dialog),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.16),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Шапка окна: Домен + Тип + Кнопка закрытия
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (meta.domain != null && meta.domain!.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () => _openExternalUrl(meta.url),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    if (meta.faviconUrl != null) ...[
                                      Image.network(
                                        meta.faviconUrl!,
                                        width: 14,
                                        height: 14,
                                        errorBuilder: (_, __, ___) =>
                                            Icon(AppIcons.globe, size: 13, color: skin.muted),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      meta.domain!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: skin.text,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(AppIcons.arrowUpRight, size: 11, color: skin.muted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Palette.accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(meta.type.icon, size: 12, color: Palette.accent),
                                const SizedBox(width: 4),
                                Text(
                                  meta.type.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Palette.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(AppIcons.xmark, size: 16, color: skin.muted),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Основное содержимое
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Обложка (если есть)
                        if (meta.previewImageUrl != null && meta.previewImageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              meta.previewImageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Заголовок
                        SelectableText(
                          page.title.isNotEmpty ? page.title : 'Без названия',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: skin.text,
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                        ),

                        if (meta.url != null && meta.url!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _openExternalUrl(meta.url),
                            child: Text(
                              meta.url!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Palette.accent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Содержимое / Сниппет / Текст цитаты
                        if (cardData.textSnippet.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: SelectableText(
                              cardData.textSnippet,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.6,
                                color: skin.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Нижняя панель действий (Triage actions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Кнопка: Преобразовать в документ проекта
                          _TriageActionButton(
                            icon: AppIcons.folder,
                            label: 'В проект',
                            tooltip: 'Преобразовать в документ сайдбара',
                            onTap: () async {
                              await repository.convertInboxItemToPage(page.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                onUpdated?.call();
                              }
                            },
                          ),

                          const SizedBox(width: 8),

                          // Кнопка: В архив / Обработано
                          _TriageActionButton(
                            icon: meta.isArchived ? AppIcons.tray : AppIcons.checkmark,
                            label: meta.isArchived ? 'Во входящие' : 'В архив',
                            tooltip: meta.isArchived
                                ? 'Вернуть в активные входящие'
                                : 'Пометить как разобранное',
                            onTap: () async {
                              await repository.updateInboxItemStatus(
                                page.id,
                                isArchived: !meta.isArchived,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                onUpdated?.call();
                              }
                            },
                          ),

                          const SizedBox(width: 8),

                          // Разделитель
                          Container(
                            width: 1,
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.08),
                          ),

                          // Кнопка: Удалить
                          _TriageActionButton(
                            icon: AppIcons.trash,
                            label: 'Удалить',
                            tooltip: 'Отправить в корзину',
                            isDestructive: true,
                            onTap: () async {
                              await repository.deleteInboxItem(page.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                onUpdated?.call();
                              }
                            },
                          ),
                        ],
                      ),

                      // Кнопка "Закрыть"
                      _TriageCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
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

class _TriageActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDestructive;

  const _TriageActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_TriageActionButton> createState() => _TriageActionButtonState();
}

class _TriageActionButtonState extends State<_TriageActionButton> {
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
          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03));
      fg = _hover ? skin.text : skin.muted;
    }

    return Tooltip(
      message: widget.tooltip,
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
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
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

class _TriageCloseButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _TriageCloseButton({required this.onPressed});

  @override
  State<_TriageCloseButton> createState() => _TriageCloseButtonState();
}

class _TriageCloseButtonState extends State<_TriageCloseButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    final bg = _hover
        ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Закрыть',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

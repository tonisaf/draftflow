import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:url_launcher/url_launcher.dart';

import '../../data/db/app_database.dart';
import '../../data/notes_repository.dart';
import '../common/app_icons.dart';
import '../theme.dart';
import 'inbox_models.dart';

class InboxTriageModal extends StatelessWidget {
  final InboxCardData cardData;
  final NotesRepository repository;
  final VoidCallback? onUpdated;
  final ValueChanged<String>? onOpenInEditor;

  const InboxTriageModal({
    super.key,
    required this.cardData,
    required this.repository,
    this.onUpdated,
    this.onOpenInEditor,
  });

  static Future<void> show(
    BuildContext context, {
    required InboxCardData cardData,
    required NotesRepository repository,
    VoidCallback? onUpdated,
    ValueChanged<String>? onOpenInEditor,
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
        onOpenInEditor: onOpenInEditor,
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

    final rawTitle = page.title.trim();
    String cleanTitle = rawTitle;
    for (final prefix in ['📄', '📌', '🔖', '💬', '📸', '📝', '🔗', '🌐']) {
      if (cleanTitle.startsWith(prefix)) {
        cleanTitle = cleanTitle.substring(prefix.length).trim();
        break;
      }
    }
    cleanTitle = cleanTitle.replaceAll(RegExp(r'[\uD800-\uDFFF\uFFFD]'), '').trim();
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : (meta.url ?? 'Без названия');

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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onOpenInEditor != null) ...[
                            Tooltip(
                              message: 'Открыть в редакторе',
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onOpenInEditor?.call(page.id);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Palette.accent.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(AppIcons.pencil, size: 12, color: Palette.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Открыть в редакторе',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Palette.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(AppIcons.xmark, size: 16, color: skin.muted),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Основное содержимое
                Expanded(
                  child: RawScrollbar(
                    thumbVisibility: false,
                    thickness: 4.0,
                    radius: const Radius.circular(4),
                    thumbColor: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.18),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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

                          // Заголовок (без системных эмодзи)
                          SelectableText(
                            displayTitle,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: skin.text,
                              height: 1.3,
                              letterSpacing: -0.2,
                            ),
                          ),

                          // Тонкая однострочная ссылка на источник под заголовком
                          if (meta.url != null && meta.url!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _SubtleUrlLink(
                              url: meta.url!,
                              onTap: () => _openExternalUrl(meta.url),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Содержимое / Статья со всеми блоками
                          _buildBodyContent(skin, isDark),
                        ],
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Нижняя панель действий (Triage actions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
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

                          // Кнопка: В архив / Во входящие
                          _TriageActionButton(
                            icon: meta.isArchived ? AppIcons.tray : AppIcons.archivebox,
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

                          const SizedBox(width: 4),

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

  Widget _buildBodyContent(Skin skin, bool isDark) {
    final displayBlocks = _filterDisplayBlocks(cardData.blocks);

    if (displayBlocks.isEmpty) {
      if (cardData.textSnippet.isEmpty) return const SizedBox.shrink();
      return Container(
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: displayBlocks.map((b) => _buildBlockItem(b, skin, isDark)).toList(),
    );
  }

  List<Block> _filterDisplayBlocks(List<Block> blocks) {
    if (blocks.isEmpty) return blocks;

    int startIndex = 0;
    while (startIndex < blocks.length) {
      final b = blocks[startIndex];
      if (_isMetadataBlock(b)) {
        startIndex++;
        continue;
      }
      if (b.type == 'divider' && startIndex > 0) {
        startIndex++;
        continue;
      }
      break;
    }

    return blocks.sublist(startIndex);
  }

  bool _isMetadataBlock(Block b) {
    if (b.type == 'quote' || b.type == 'callout' || b.type == 'paragraph' || b.type == 'text') {
      try {
        final decoded = jsonDecode(b.content);
        if (decoded is Map && decoded['data'] is Map) {
          final delta = decoded['data']['delta'];
          if (delta is List) {
            final text = delta.map((op) => op['insert']?.toString() ?? '').join().trim();
            final lower = text.toLowerCase();
            if (lower.startsWith('🔗 источник:') ||
                lower.startsWith('источник:') ||
                lower.startsWith('source:') ||
                lower.startsWith('🌐 http') ||
                (lower.startsWith('🌐') && lower.contains('http')) ||
                lower.startsWith('http://') ||
                lower.startsWith('https://')) {
              return true;
            }
          }
        }
      } catch (_) {}
    }
    return false;
  }

  Widget _buildBlockItem(Block b, Skin skin, bool isDark) {
    Map<String, dynamic> dataMap = {};
    try {
      final decoded = jsonDecode(b.content);
      if (decoded is Map && decoded['data'] is Map) {
        dataMap = Map<String, dynamic>.from(decoded['data'] as Map);
      }
    } catch (_) {}

    final spans = _parseDeltaSpans(dataMap['delta'], skin);

    switch (b.type) {
      case 'divider':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        );

      case 'image':
        final imageUrl = dataMap['url'] as String? ?? '';
        if (imageUrl.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );
        }
        return const SizedBox.shrink();

      case 'quote':
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            border: Border(
              left: BorderSide(
                color: Palette.accent,
                width: 3.5,
              ),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: SelectableText.rich(
            TextSpan(children: spans),
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              fontStyle: FontStyle.italic,
              color: skin.text,
            ),
          ),
        );

      case 'bulleted_list':
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(
                  '•',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Palette.accent,
                    height: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(children: spans),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: skin.text,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'numbered_list':
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(
                  '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Palette.accent,
                    height: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(children: spans),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: skin.text,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'heading':
      case 'h1':
      case 'h2':
      case 'h3':
        final level = dataMap['level'] as int? ?? 1;
        final fontSize = level == 1 ? 18.0 : (level == 2 ? 16.0 : 15.0);
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: SelectableText.rich(
            TextSpan(children: spans),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: skin.text,
            ),
          ),
        );

      case 'code':
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: skin.hairlineBorder),
          ),
          child: SelectableText.rich(
            TextSpan(children: spans),
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              height: 1.5,
              color: skin.text,
            ),
          ),
        );

      case 'paragraph':
      case 'text':
      default:
        if (spans.isEmpty) return const SizedBox(height: 6);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SelectableText.rich(
            TextSpan(children: spans),
            style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: skin.text,
            ),
          ),
        );
    }
  }

  List<InlineSpan> _parseDeltaSpans(dynamic rawDelta, Skin skin) {
    if (rawDelta is! List) return [];
    final spans = <InlineSpan>[];
    for (final op in rawDelta) {
      if (op is Map && op['insert'] is String) {
        final text = op['insert'] as String;
        final attrs = op['attributes'] as Map?;
        final isBold = attrs?['bold'] == true;
        final isItalic = attrs?['italic'] == true;
        final isUnderline = attrs?['underline'] == true;
        final isStrike = attrs?['strike'] == true;
        final href = attrs?['href'] as String?;

        final isLink = href != null && href.isNotEmpty;
        spans.add(
          TextSpan(
            text: text,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: isLink ? Palette.accent : skin.text,
              decoration: isStrike
                  ? TextDecoration.lineThrough
                  : (isLink || isUnderline ? TextDecoration.underline : TextDecoration.none),
            ),
            recognizer: isLink
                ? (TapGestureRecognizer()..onTap = () => _openExternalUrl(href))
                : null,
          ),
        );
      }
    }
    return spans;
  }
}

class _SubtleUrlLink extends StatefulWidget {
  final String url;
  final VoidCallback onTap;

  const _SubtleUrlLink({
    required this.url,
    required this.onTap,
  });

  @override
  State<_SubtleUrlLink> createState() => _SubtleUrlLinkState();
}

class _SubtleUrlLinkState extends State<_SubtleUrlLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    // text-[12.5px] text-[#6B7280] hover:text-[#1A73E8] truncate
    final defaultColor = isDark ? skin.muted : const Color(0xFF6B7280);
    final hoverColor = isDark ? Palette.accent : const Color(0xFF1A73E8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: _hovered ? hoverColor : defaultColor,
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
      // text-[#6B7280] hover:bg-red-500/10 hover:text-red-600
      bg = _hover
          ? Colors.red.withValues(alpha: isDark ? 0.20 : 0.10)
          : Colors.transparent;
      fg = _hover
          ? const Color(0xFFDC2626)
          : (isDark ? skin.muted : const Color(0xFF6B7280));
    } else {
      bg = _hover
          ? (isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.06))
          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03));
      fg = _hover
          ? (isDark ? skin.text : const Color(0xFF111827))
          : (isDark ? skin.muted : const Color(0xFF6B7280));
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
            scale: _pressed ? 0.98 : 1.0, // active:scale-[0.98]
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 32, // h-8
              padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8), // rounded-lg
              ),
              alignment: Alignment.center,
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
          scale: _pressed ? 0.98 : 1.0, // active:scale-[0.98]
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 32, // h-8
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8), // rounded-lg
            ),
            alignment: Alignment.center,
            child: Text(
              'Закрыть',
              style: TextStyle(
                fontSize: 12.5,
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

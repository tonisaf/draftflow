import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/url_metadata_service.dart';
import '../common/app_icons.dart';
import '../theme.dart';
import 'inbox_models.dart';

class InboxSmartInput extends StatefulWidget {
  final Future<void> Function({
    required String title,
    required InboxItemType type,
    String? url,
    String? domain,
    String? faviconUrl,
    String? previewImageUrl,
    String? excerpt,
    String? body,
  }) onSubmit;

  const InboxSmartInput({
    super.key,
    required this.onSubmit,
  });

  @override
  State<InboxSmartInput> createState() => _InboxSmartInputState();
}

class _InboxSmartInputState extends State<InboxSmartInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isFocused = false;
  bool _isLoadingMetadata = false;
  InboxItemType _selectedType = InboxItemType.link;
  InboxUrlMetadata? _extractedMetadata;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final text = _controller.text.trim();
    if (UrlMetadataService.isUrl(text)) {
      if (_extractedMetadata == null && !_isLoadingMetadata) {
        _fetchUrlMetadata(text);
      }
    } else {
      if (_extractedMetadata != null) {
        setState(() {
          _extractedMetadata = null;
          _isLoadingMetadata = false;
        });
      }
    }
  }

  Future<void> _fetchUrlMetadata(String url) async {
    setState(() => _isLoadingMetadata = true);
    final meta = await UrlMetadataService.fetchMetadata(url);
    if (!mounted) return;
    setState(() {
      _isLoadingMetadata = false;
      _extractedMetadata = meta;
      if (_selectedType == InboxItemType.note) {
        _selectedType = InboxItemType.link;
      }
    });
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _extractedMetadata == null) return;

    final meta = _extractedMetadata;
    String title;
    String? url;
    String? domain;
    String? faviconUrl;
    String? previewImageUrl;
    String? excerpt;
    String? body;
    InboxItemType type = _selectedType;

    if (meta != null) {
      url = meta.url;
      domain = meta.domain;
      title = meta.title.isNotEmpty ? meta.title : meta.domain;
      faviconUrl = meta.faviconUrl;
      previewImageUrl = meta.imageUrl;
      excerpt = meta.description;
    } else if (UrlMetadataService.isUrl(text)) {
      url = UrlMetadataService.normalizeUrl(text);
      domain = UrlMetadataService.extractDomain(url);
      title = domain;
      faviconUrl = UrlMetadataService.getFaviconUrl(domain);
    } else {
      title = text;
      body = text;
      type = InboxItemType.note;
    }

    _controller.clear();
    setState(() {
      _extractedMetadata = null;
      _isLoadingMetadata = false;
    });

    await widget.onSubmit(
      title: title,
      type: type,
      url: url,
      domain: domain,
      faviconUrl: faviconUrl,
      previewImageUrl: previewImageUrl,
      excerpt: excerpt,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          if (!HardwareKeyboard.instance.isShiftPressed) {
            _handleSubmit();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: skin.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused
                ? Palette.accent.withValues(alpha: 0.45)
                : skin.hairlineBorder,
            width: _isFocused ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isFocused
                  ? Palette.accent.withValues(alpha: 0.12)
                  : skin.shadow.withValues(alpha: 0.04),
              blurRadius: _isFocused ? 12 : 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: skin.shadow.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _extractedMetadata != null
                          ? AppIcons.link
                          : AppIcons.pencil,
                      size: 18,
                      color: _isFocused ? Palette.accent : skin.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(
                        fontSize: 14,
                        color: skin.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Новая ссылка или заметка…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: skin.muted.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_isLoadingMetadata) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (_extractedMetadata != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Palette.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.link, size: 10, color: Palette.accent),
                          const SizedBox(width: 4),
                          Text(
                            _extractedMetadata!.domain,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Выбор типа входящего
                  _buildTypePicker(skin),

                  const SizedBox(width: 6),

                  // Кнопка сохранения
                  _buildSubmitButton(skin),
                ],
              ),
            ),

            // Распознанная плашка метаданных
            if (_extractedMetadata != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (_extractedMetadata!.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _extractedMetadata!.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Palette.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Icon(AppIcons.globe, size: 18, color: Palette.accent),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _extractedMetadata!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: skin.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _extractedMetadata!.domain,
                            style: TextStyle(
                              fontSize: 11,
                              color: skin.muted,
                            ),
                          ),
                        ],
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

  Widget _buildTypePicker(Skin skin) {
    return PopupMenuButton<InboxItemType>(
      tooltip: 'Тип материала',
      offset: const Offset(0, 36),
      color: skin.glassSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.control),
        side: BorderSide(color: skin.divider),
      ),
      onSelected: (t) => setState(() => _selectedType = t),
      itemBuilder: (context) => [
        for (final t in InboxItemType.values)
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                Icon(t.icon, size: 14, color: _selectedType == t ? Palette.accent : skin.muted),
                const SizedBox(width: 8),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _selectedType == t ? FontWeight.w600 : FontWeight.normal,
                    color: _selectedType == t ? Palette.accent : skin.text,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: skin.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_selectedType.icon, size: 13, color: skin.muted),
            const SizedBox(width: 5),
            Text(
              _selectedType.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: skin.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Skin skin) {
    final hasText = _controller.text.trim().isNotEmpty || _extractedMetadata != null;

    return GestureDetector(
      onTap: _handleSubmit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: hasText
              ? Palette.accent
              : (skin.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            AppIcons.plus,
            size: 16,
            color: hasText ? Colors.white : skin.muted,
          ),
        ),
      ),
    );
  }
}

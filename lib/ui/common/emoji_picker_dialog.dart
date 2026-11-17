import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../theme.dart';
import 'app_dialog.dart';
import 'app_icons.dart';
import 'menu.dart';
import 'page_icon_view.dart';
import 'quiet_button.dart';

class EmojiCategory {
  final String title;
  final List<String> emojis;

  const EmojiCategory(this.title, this.emojis);
}

const List<EmojiCategory> kEmojiCategories = [
  EmojiCategory('Идеи и работа', [
    '💡', '⚡', '🚀', '📝', '🎯', '📌', '📚', '📋', '📊', '📈',
    '🗓️', '⏰', '📁', '📂', '✉️', '🔍', '🏷️', '💼', '🛠️', '🧭',
  ]),
  EmojiCategory('IT и код', [
    '💻', '🖥️', '📱', '⚙️', '🔧', '🤖', '🔒', '🔑', '🌐', '📦',
    '🧪', '💾', '🕹️', '📡', '☁️', '🗄️', '🔌', '💎', '🛡️', '👾',
  ]),
  EmojiCategory('Творчество', [
    '🎨', '✍️', '📖', '🎬', '🎧', '📷', '🧠', '💬', '💭', '🧩',
    '🪄', '✨', '🌟', '🎭', '🎤', '🎹', '🎸', '✏️', '✒️', '🎞️',
  ]),
  EmojiCategory('Природа и отдых', [
    '🌿', '🪴', '☕', '🍵', '🏠', '☀️', '🌙', '🌸', '🥑', '🚴',
    '✈️', '🏔️', '🌊', '🌲', '🏖️', '⛺', '🍕', '🍎', '🔥', '🐾',
  ]),
  EmojiCategory('Символы и знаки', [
    '⭐', '❤️', '✅', '❌', '❗', '❓', '🏆', '🥇', '🎉', '🎁',
    '⚠️', '🔔', '💬', '👀', '💯', '🔥', '🟢', '🔵', '🟣', '🟠',
  ]),
];

/// Словарь ключевых слов для умного поиска эмодзи на русском и английском языках
const Map<String, List<String>> kEmojiKeywords = {
  '💡': ['идея', 'лампа', 'мысль', 'свет', 'idea', 'light', 'bulb'],
  '⚡': ['молния', 'энергия', 'ток', 'быстро', 'flash', 'bolt', 'lightning', 'fast', 'speed'],
  '🚀': ['ракета', 'запуск', 'старт', 'проект', 'rocket', 'launch', 'startup'],
  '📝': ['заметка', 'текст', 'писать', 'документ', 'note', 'memo', 'write', 'doc'],
  '🎯': ['цель', 'таргет', 'план', 'мишень', 'target', 'goal', 'plan'],
  '📌': ['пин', 'закрепить', 'важно', 'pin', 'pinned'],
  '📚': ['книги', 'учеба', 'конспект', 'чтение', 'books', 'read', 'study'],
  '📋': ['список', 'план', 'буфер', 'clipboard', 'todo', 'checklist'],
  '📊': ['график', 'диаграмма', 'отчет', 'статистика', 'chart', 'stats', 'analytics'],
  '📈': ['рост', 'тренд', 'график', 'growth', 'trend'],
  '🗓️': ['календарь', 'дата', 'планы', 'calendar', 'date', 'schedule'],
  '⏰': ['будильник', 'время', 'дедлайн', 'часы', 'clock', 'alarm', 'time'],
  '📁': ['папка', 'каталог', 'folder', 'dir'],
  '📂': ['папка', 'открыть', 'folder', 'open'],
  '✉️': ['почта', 'письмо', 'email', 'mail', 'message'],
  '🔍': ['поиск', 'найти', 'лупа', 'search', 'find'],
  '🏷️': ['тег', 'метка', 'ярлык', 'tag', 'label'],
  '💼': ['работа', 'бизнес', 'портфель', 'work', 'job', 'business'],
  '🛠️': ['инструмент', 'ремонт', 'настройки', 'tools', 'repair'],
  '🧭': ['компас', 'направление', 'навигация', 'compass', 'guide'],
  '💻': ['комп', 'ноутбук', 'код', 'программирование', 'dev', 'code', 'laptop', 'mac'],
  '🖥️': ['монитор', 'экран', 'компьютер', 'pc', 'desktop', 'screen'],
  '📱': ['телефон', 'смартфон', 'айфон', 'phone', 'mobile', 'iphone'],
  '⚙️': ['шестеренка', 'настройки', 'опции', 'gear', 'settings', 'config'],
  '🔧': ['ключ', 'гаечный', 'фикс', 'wrench', 'fix'],
  '🤖': ['робот', 'ии', 'нейросеть', 'бот', 'ai', 'robot', 'bot'],
  '🔒': ['замок', 'безопасность', 'пароль', 'lock', 'security'],
  '🔑': ['ключ', 'доступ', 'пароль', 'key', 'access'],
  '🌐': ['сеть', 'интернет', 'мир', 'глобус', 'web', 'internet', 'globe'],
  '📦': ['пакет', 'бокс', 'коробка', 'репозиторий', 'package', 'box'],
  '🧪': ['тест', 'лаборатория', 'колба', 'наука', 'test', 'lab', 'science'],
  '💾': ['дискета', 'сохранить', 'save', 'disk'],
  '🕹️': ['игра', 'джойстик', 'гейм', 'game', 'play'],
  '📡': ['спутник', 'связь', 'сигнал', 'satellite', 'signal'],
  '☁️': ['облако', 'cloud', 'sync'],
  '🗄️': ['база', 'архив', 'шкаф', 'database', 'archive'],
  '🔌': ['плагин', 'провод', 'питание', 'plugin', 'plug'],
  '💎': ['алмаз', 'премиум', 'кристалл', 'diamond', 'gem', 'premium'],
  '🛡️': ['щит', 'защита', 'безопасность', 'shield', 'protect'],
  '🎨': ['дизайн', 'арт', 'краски', 'design', 'art', 'palette', 'ui'],
  '✍️': ['перо', 'писать', 'автор', 'write', 'draw', 'author'],
  '📖': ['книга', 'читать', 'book', 'read'],
  '🎬': ['кино', 'видео', 'фильм', 'movie', 'film', 'cinema'],
  '🎧': ['наушники', 'музыка', 'звук', 'headphones', 'music', 'audio'],
  '📷': ['фото', 'камера', 'photo', 'camera'],
  '🧠': ['мозг', 'ум', 'мысли', 'психология', 'brain', 'mind'],
  '💬': ['чат', 'сообщение', 'диалог', 'chat', 'comment'],
  '💭': ['мысль', 'облачко', 'thought'],
  '🧩': ['пазл', 'модуль', 'кусочек', 'puzzle', 'plugin'],
  '🪄': ['магия', 'палочка', 'magic', 'wand'],
  '✨': ['звездочки', 'магия', 'новое', 'sparkles', 'magic', 'new'],
  '🌟': ['звезда', 'сияние', 'star', 'glow'],
  '🎭': ['театр', 'маски', 'роли', 'theater', 'drama'],
  '🎤': ['микрофон', 'голос', 'аудио', 'mic', 'voice'],
  '🎹': ['пианино', 'клавиши', 'piano'],
  '🎸': ['гитара', 'рок', 'guitar'],
  '🌿': ['лист', 'природа', 'растение', 'зелень', 'leaf', 'nature', 'plant'],
  '🪴': ['цветок', 'горшок', 'уют', 'plant', 'home'],
  '☕': ['кофе', 'утро', 'отдых', 'перерыв', 'coffee', 'break', 'cafe'],
  '🍵': ['чай', 'матча', 'tea', 'matcha'],
  '🏠': ['дом', 'главная', 'домашняя', 'home', 'house'],
  '☀️': ['солнце', 'день', 'погода', 'sun', 'day', 'light'],
  '🌙': ['луна', 'ночь', 'темная', 'moon', 'night', 'dark'],
  '🌸': ['сакура', 'весна', 'цветок', 'flower', 'sakura'],
  '🥑': ['авокадо', 'еда', 'пп', 'avocado', 'food'],
  '🚴': ['спорт', 'велосипед', 'bike', 'sport'],
  '✈️': ['самолет', 'путешествие', 'полет', 'отпуск', 'plane', 'travel', 'trip'],
  '🏔️': ['горы', 'пик', 'хайкинг', 'mountain', 'peak'],
  '🌊': ['волна', 'море', 'океан', 'вода', 'wave', 'sea', 'ocean'],
  '🌲': ['лес', 'елка', 'дерево', 'tree', 'forest'],
  '🏖️': ['пляж', 'отпуск', 'лето', 'beach', 'summer'],
  '⛺': ['кемпинг', 'палатка', 'поход', 'camp', 'tent'],
  '🍕': ['пицца', 'еда', 'pizza', 'food'],
  '🍎': ['яблоко', 'фрукт', 'apple', 'fruit'],
  '🔥': ['огонь', 'пламя', 'топ', 'популярное', 'fire', 'hot', 'flame'],
  '🐾': ['лапки', 'животные', 'питомец', 'pets', 'paws'],
  '⭐': ['звезда', 'избранное', 'важно', 'star', 'favorite', 'fav'],
  '❤️': ['сердце', 'любовь', 'лайк', 'heart', 'love', 'like'],
  '✅': ['готово', 'галочка', 'выполнено', 'done', 'check', 'ok'],
  '❌': ['ошибка', 'крестик', 'отмена', 'cancel', 'error', 'no'],
  '❗': ['внимание', 'важно', 'восклицание', 'important', 'alert'],
  '❓': ['вопрос', 'помощь', 'справка', 'question', 'help'],
  '🏆': ['кубок', 'награда', 'победа', 'trophy', 'winner', 'cup'],
  '🥇': ['медаль', 'первое', 'золото', 'gold', 'first', 'medal'],
  '🎉': ['праздник', 'вечеринка', 'party', 'celebrate'],
  '🎁': ['подарок', 'сюрприз', 'gift', 'present'],
  '⚠️': ['предупреждение', 'опасность', 'warning'],
  '🔔': ['колокольчик', 'уведомления', 'bell', 'alert'],
};

Future<String?> showEmojiPickerDialog(
  BuildContext context, {
  String? currentEmoji,
}) {
  return showAppDialog<String?>(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (context) => _EmojiPickerModal(currentEmoji: currentEmoji),
  );
}

class _EmojiPickerModal extends StatefulWidget {
  final String? currentEmoji;

  const _EmojiPickerModal({this.currentEmoji});

  @override
  State<_EmojiPickerModal> createState() => _EmojiPickerModalState();
}

class _EmojiPickerModalState extends State<_EmojiPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  int _mainTab = 0; // 0 = Emoji, 1 = Cupertino Icons
  int _selectedCategoryIndex = 0; // 0 = All
  String _filter = '';
  Color _selectedIconColor = kIconPalette.first;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pickRandom() {
    final all = [for (final cat in kEmojiCategories) ...cat.emojis];
    final random = Random();
    final chosen = all[random.nextInt(all.length)];
    Navigator.of(context).pop(chosen);
  }

  bool _matchesEmoji(String emoji, String query) {
    if (emoji.contains(query)) return true;
    final keywords = kEmojiKeywords[emoji];
    if (keywords != null) {
      for (final kw in keywords) {
        if (kw.toLowerCase().contains(query)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // Collect emojis based on category and search query
    List<String> displayedEmojis;
    if (_filter.isNotEmpty) {
      final all = [for (final cat in kEmojiCategories) ...cat.emojis];
      displayedEmojis = all.where((e) => _matchesEmoji(e, _filter)).toList();
    } else if (_selectedCategoryIndex == 0) {
      displayedEmojis = [for (final cat in kEmojiCategories) ...cat.emojis];
    } else {
      displayedEmojis = kEmojiCategories[_selectedCategoryIndex - 1].emojis;
    }

    // Filter Cupertino icons based on search query
    List<CupertinoIconPreset> displayedIcons;
    if (_filter.isNotEmpty) {
      displayedIcons = kCupertinoIconPresets.where((p) {
        return p.label.toLowerCase().contains(_filter) ||
            p.id.toLowerCase().contains(_filter);
      }).toList();
    } else {
      displayedIcons = kCupertinoIconPresets;
    }

    return Dialog(
      insetAnimationDuration: Motion.of(context, Motion.micro),
      insetAnimationCurve: Motion.curve,
      backgroundColor: Palette.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s24,
        vertical: UiSpace.s24,
      ),
      child: MenuCard.surface(
        width: UiLayout.emojiPickerWidth,
        height: UiLayout.emojiPickerHeight + 20,
        color: skin.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.s16,
                UiSpace.s12,
                UiSpace.s12,
                UiSpace.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.selectIconTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.title,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ),
                  if (_mainTab == 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(UiRadius.small),
                      onTap: _pickRandom,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s8,
                          vertical: UiSpace.s4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎲', style: TextStyle(fontSize: UiType.body)),
                            const SizedBox(width: UiSpace.s4),
                            Text(
                              context.l10n.randomIcon,
                              style: TextStyle(
                                fontSize: UiType.caption,
                                fontWeight: FontWeight.w500,
                                color: skin.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: UiSpace.s4),
                  CloseCross(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Main Tab Switcher (Эмодзи vs Иконки)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MainTabButton(
                      label: 'Эмодзи',
                      icon: '😀',
                      isSelected: _mainTab == 0,
                      onTap: () => setState(() => _mainTab = 0),
                    ),
                    const SizedBox(width: UiSpace.s8),
                    _MainTabButton(
                      label: 'Иконки Cupertino',
                      iconWidget: const Icon(CupertinoIcons.star_fill, size: 14),
                      isSelected: _mainTab == 1,
                      onTap: () => setState(() => _mainTab = 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UiSpace.s8),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.s14),
              child: Container(
                height: UiSpace.s34,
                decoration: BoxDecoration(
                  color: skin.hover,
                  borderRadius: BorderRadius.circular(UiRadius.control),
                  border: Border.all(
                    color: skin.divider.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: UiSpace.s10),
                child: Row(
                  children: [
                    Icon(AppIcons.search, size: UiSpace.s16, color: skin.hint),
                    const SizedBox(width: UiSpace.s8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        selectAllOnFocus: false,
                        style: TextStyle(
                          fontSize: UiType.body,
                          color: skin.text,
                        ),
                        decoration: InputDecoration(
                          hintText: _mainTab == 0
                              ? 'Поиск эмодзи (например: огонь, код, звезда)'
                              : 'Поиск иконки (папка, звезда, терминал...)',
                          hintStyle: TextStyle(
                            fontSize: UiType.caption,
                            color: skin.hint,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            Navigator.of(context).pop(val.trim());
                          }
                        },
                      ),
                    ),
                    if (_filter.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(
                          AppIcons.xmarkCircle,
                          size: UiSpace.s14,
                          color: skin.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UiSpace.s8),

            // Sub-bar: Category Chips for Emoji OR Color Palette for Icons
            if (_mainTab == 0) ...[
              if (_filter.isEmpty)
                SizedBox(
                  height: UiSpace.s28,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: UiSpace.s14),
                    children: [
                      _CategoryChip(
                        label: context.l10n.categoryAll,
                        isSelected: _selectedCategoryIndex == 0,
                        onTap: () => setState(() => _selectedCategoryIndex = 0),
                      ),
                      for (int i = 0; i < kEmojiCategories.length; i++)
                        _CategoryChip(
                          label: kEmojiCategories[i].title,
                          isSelected: _selectedCategoryIndex == i + 1,
                          onTap: () =>
                              setState(() => _selectedCategoryIndex = i + 1),
                        ),
                    ],
                  ),
                ),
            ] else ...[
              // Color selection swatches for Cupertino Icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: UiSpace.s14),
                child: Row(
                  children: [
                    Text(
                      'Цвет:',
                      style: TextStyle(
                        fontSize: UiType.caption,
                        fontWeight: FontWeight.w600,
                        color: skin.muted,
                      ),
                    ),
                    const SizedBox(width: UiSpace.s10),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final color in kIconPalette)
                            GestureDetector(
                              onTap: () => setState(() => _selectedIconColor = color),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedIconColor == color
                                        ? Palette.onAccent
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: _selectedIconColor == color
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: _selectedIconColor == color
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: UiSpace.s8),
            Divider(
              height: 1,
              thickness: UiSpace.s1,
              color: skin.divider.withValues(alpha: 0.4),
            ),

            // Content Grid (Emoji or Cupertino Icons)
            Expanded(
              child: _mainTab == 0
                  ? (displayedEmojis.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _filter,
                                style: const TextStyle(fontSize: UiType.emptyIcon),
                              ),
                              const SizedBox(height: UiSpace.s8),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(_filter),
                                child: Text(
                                  'Использовать "$_filter" как иконку',
                                  style: const TextStyle(
                                    fontSize: UiType.body,
                                    fontWeight: FontWeight.w600,
                                    color: Palette.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(UiSpace.s12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: displayedEmojis.length,
                          itemBuilder: (context, index) {
                            final emoji = displayedEmojis[index];
                            final isSelected = emoji == widget.currentEmoji;
                            return _EmojiGridButton(
                              emoji: emoji,
                              isSelected: isSelected,
                              onTap: () => Navigator.of(context).pop(emoji),
                            );
                          },
                        ))
                  : GridView.builder(
                      padding: const EdgeInsets.all(UiSpace.s12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: displayedIcons.length,
                      itemBuilder: (context, index) {
                        final preset = displayedIcons[index];
                        final formattedId =
                            formatCupertinoIcon(preset.id, _selectedIconColor);
                        final isSelected =
                            widget.currentEmoji == formattedId ||
                                widget.currentEmoji?.startsWith('icon:${preset.id}:') == true;

                        return _CupertinoIconGridButton(
                          preset: preset,
                          color: _selectedIconColor,
                          isSelected: isSelected,
                          onTap: () => Navigator.of(context).pop(formattedId),
                        );
                      },
                    ),
            ),

            // Bottom Bar: Remove Icon button
            if (widget.currentEmoji != null &&
                widget.currentEmoji!.isNotEmpty) ...[
              Divider(
                height: 1,
                thickness: UiSpace.s1,
                color: skin.divider.withValues(alpha: 0.4),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s14,
                  vertical: UiSpace.s8,
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(''),
                      icon: Icon(
                        AppIcons.trash,
                        size: UiSpace.s15,
                        color: skin.destructive,
                      ),
                      label: Text(
                        context.l10n.removeIcon,
                        style: TextStyle(
                          fontSize: UiType.caption,
                          fontWeight: FontWeight.w500,
                          color: skin.destructive,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s10,
                          vertical: UiSpace.s6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
}

class _MainTabButton extends StatelessWidget {
  final String label;
  final String? icon;
  final Widget? iconWidget;
  final bool isSelected;
  final VoidCallback onTap;

  const _MainTabButton({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return InkWell(
      borderRadius: BorderRadius.circular(UiRadius.small),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UiSpace.s12, vertical: UiSpace.s6),
        decoration: BoxDecoration(
          color: isSelected
              ? Palette.accent.withValues(alpha: 0.14)
              : Palette.transparent,
          borderRadius: BorderRadius.circular(UiRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(icon!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
            ] else if (iconWidget != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: isSelected ? Palette.accent : skin.muted,
                  size: 13,
                ),
                child: iconWidget!,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: UiType.caption,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Palette.accent : skin.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(right: UiSpace.s6),
      child: InkWell(
        borderRadius: BorderRadius.circular(UiRadius.control),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpace.s10,
            vertical: UiSpace.s4,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Palette.accent.withValues(alpha: 0.14)
                : Palette.transparent,
            borderRadius: BorderRadius.circular(UiRadius.control),
            border: Border.all(
              color: isSelected
                  ? Palette.accent.withValues(alpha: 0.5)
                  : skin.divider.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: UiType.caption,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Palette.accent : skin.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiGridButton extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmojiGridButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EmojiGridButton> createState() => _EmojiGridButtonState();
}

class _EmojiGridButtonState extends State<_EmojiGridButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Palette.accent.withValues(alpha: 0.20)
                : (_hovered ? skin.hover : Palette.transparent),
            borderRadius: BorderRadius.circular(UiRadius.control),
            border: widget.isSelected
                ? Border.all(color: Palette.accent, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 24.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _CupertinoIconGridButton extends StatefulWidget {
  final CupertinoIconPreset preset;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CupertinoIconGridButton({
    required this.preset,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CupertinoIconGridButton> createState() =>
      _CupertinoIconGridButtonState();
}

class _CupertinoIconGridButtonState extends State<_CupertinoIconGridButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Tooltip(
      message: widget.preset.label,
      preferBelow: false,
      waitDuration: Motion.tooltipDelay,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.16)
                  : (_hovered ? skin.hover : Palette.transparent),
              borderRadius: BorderRadius.circular(UiRadius.control),
              border: widget.isSelected
                  ? Border.all(color: widget.color, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Icon(
                widget.preset.icon,
                color: widget.color,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

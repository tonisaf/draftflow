import 'package:flutter/material.dart';

import '../../../../ui/design_tokens.dart';
import '../../../../ui/theme.dart';
import '../../models/tmdb_media_item.dart';

class TmdbNotesTab extends StatelessWidget {
  final TmdbMediaItem item;
  final TextEditingController controller;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<String>? onOpenAsPage;

  const TmdbNotesTab({
    super.key,
    required this.item,
    required this.controller,
    required this.onNoteChanged,
    this.onOpenAsPage,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Личные впечатления и рецензия',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: skin.text),
                ),
              ],
            ),
            if (item.pageId != null && onOpenAsPage != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Открыть редактор страниц', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenAsPage!(item.pageId!);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 10,
          style: TextStyle(fontSize: 13, height: 1.5, color: skin.text),
          decoration: InputDecoration(
            hintText: 'Запишите здесь свои впечатления, любимые цитаты или мысли о фильме...',
            hintStyle: TextStyle(fontSize: 12, color: skin.faint),
            filled: true,
            fillColor: skin.sidebar,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              borderSide: BorderSide(color: skin.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              borderSide: BorderSide(color: skin.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UiRadius.control),
              borderSide: BorderSide(color: Palette.accent, width: 1.5),
            ),
          ),
          onChanged: onNoteChanged,
        ),
      ],
    );
  }
}

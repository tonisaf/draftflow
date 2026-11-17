import 'package:flutter/material.dart';

import '../theme.dart';

enum DropPosition { above, inside, below }

/// Тонкий синий индикатор-маркер для Drag-and-Drop в сайдбаре.
/// Показывает точное место (линию и точку), куда опустится страница в дереве.
class DropLineIndicator extends StatelessWidget {
  const DropLineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7.0,
          height: 7.0,
          decoration: BoxDecoration(
            color: Palette.accent,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Palette.accent.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 2.5,
            decoration: BoxDecoration(
              color: Palette.accent,
              borderRadius: BorderRadius.circular(UiRadius.hairline),
              boxShadow: [
                BoxShadow(
                  color: Palette.accent.withValues(alpha: 0.4),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

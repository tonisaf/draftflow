import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';

import '../common/quiet_button.dart';
export '../common/quiet_button.dart' show CloseCross;
import '../theme.dart';

/// A pill-shaped choice with an anchored, keyboard-accessible menu. The menu
/// uses the overlay so scrolling cards never clip its options.
class SettingsChoice<T> extends StatefulWidget {
  const SettingsChoice({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T> onChanged;

  @override
  State<SettingsChoice<T>> createState() => _SettingsChoiceState<T>();
}

class _SettingsChoiceState<T> extends State<SettingsChoice<T>> {
  final _focus = FocusNode();
  bool _open = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final label = widget.choices[widget.value]!;
    return MenuAnchor(
      childFocusNode: _focus,
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, 6),
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        backgroundColor: WidgetStatePropertyAll(skin.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(skin.shadow),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
        shape: WidgetStatePropertyAll(
          UiRadius.squircle(
            UiRadius.dialog,
            side: BorderSide(color: skin.hairlineBorder),
          ),
        ),
      ),
      menuChildren: [
        for (final entry in widget.choices.entries)
          Semantics(
            selected: entry.key == widget.value,
            child: MenuItemButton(
              onPressed: () => widget.onChanged(entry.key),
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(skin.text),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      entry.key == widget.value ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? skin.hover
                      : Colors.transparent,
                ),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                ),
                minimumSize: const WidgetStatePropertyAll(Size(138, 36)),
                textStyle: WidgetStatePropertyAll(
                  Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontSize: 13),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              trailingIcon: SizedBox.square(
                dimension: 16,
                child: entry.key == widget.value
                    ? const Icon(CupertinoIcons.checkmark, size: 14)
                    : null,
              ),
              child: Text(entry.value),
            ),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        expanded: _open,
        child: TextButton(
          focusNode: _focus,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style: TextButton.styleFrom(
            foregroundColor: skin.text,
            backgroundColor: Color.alphaBlend(
              skin.surfaceVariant,
              skin.surface,
            ),
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 13, fontWeight: FontWeight.w400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(color: skin.hairlineBorder),
            ),
          ),
          child: Semantics(
            label: '${widget.label}: $label',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label)),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 13,
                  color: skin.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field with its caption above it and a soft focus ring, instead of
/// Material's floating outlined label.
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.controller,
    required this.label,
    this.secret = false,
    this.enabled = true,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool secret;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: TextStyle(fontSize: 12, color: skin.muted)),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: Motion.of(context, Motion.micro),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: skin.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _focused ? Palette.accent : skin.divider,
              ),
              boxShadow: [
                if (_focused)
                  BoxShadow(
                    color: Palette.accent.withValues(alpha: 0.22),
                    spreadRadius: 3,
                  ),
              ],
            ),
            child: Focus(
              onFocusChange: (f) => setState(() => _focused = f),
              child: TextField(
                controller: widget.controller,
                selectAllOnFocus: false,
                enabled: widget.enabled,
                obscureText: widget.secret,
                enableSuggestions: !widget.secret,
                autocorrect: !widget.secret,
                keyboardType: widget.keyboardType,
                autofillHints: widget.autofillHints,
                style: const TextStyle(fontSize: 14),
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet text button for secondary actions.
class QuietLink extends StatelessWidget {
  const QuietLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => QuietButton(
    label: label,
    onTap: onTap,
    builder: (context, {required hover, required focus, required pressed}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: focus ? Border.all(color: Palette.accent) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: onTap == null
                  ? context.skin.hint
                  : hover || pressed
                  ? Palette.accent
                  : context.skin.muted,
            ),
          ),
        ),
  );
}



/// Exclusive tabs in a pill using Apple sliding segmented control physics.
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: index,
      backgroundColor: skin.divider.withValues(alpha: 0.5),
      thumbColor: skin.card,
      children: {
        for (final (i, label) in labels.indexed)
          i: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                color: i == index ? skin.text : skin.muted,
              ),
            ),
          ),
      },
      onValueChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}

/// A quiet group of related settings with hairlines between the rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: skin.surfaceSubtle,
        shape: UiRadius.squircle(
          UiRadius.card,
          side: BorderSide(color: skin.hairlineBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: skin.hairlineBorder,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

/// A title with an optional caption and a control: beside them, or below
/// when [stacked] (wide controls, narrow screens).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.subtitleStyle,
    this.trailing,
    this.stacked = false,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        ),
        if (subtitleWidget != null) ...[
          const SizedBox(height: 2),
          subtitleWidget!,
        ] else if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style:
                subtitleStyle ??
                TextStyle(fontSize: 12, color: skin.muted, height: 1.5),
          ),
        ],
      ],
    );
    if (trailing == null) return text;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 10), trailing!],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: text),
        const SizedBox(width: 16),
        trailing!,
      ],
    );
  }
}

/// Crisp macOS-proportioned toggle switch: 40px × 24px track (w-10 h-6),
/// 20px × 20px thumb (w-5 h-5), with smooth 200ms cubic-bezier(0.2, 0.8, 0.2, 1) slide.
class MacOSToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  const MacOSToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  @override
  State<MacOSToggleSwitch> createState() => _MacOSToggleSwitchState();
}

class _MacOSToggleSwitchState extends State<MacOSToggleSwitch> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final on = widget.value;

    final trackColor = on
        ? Palette.accent
        : (isDark ? const Color(0xFF373A40) : const Color(0xFFD1D5DB));

    return Semantics(
      key: widget.switchKey,
      toggled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: const Cubic(0.2, 0.8, 0.2, 1.0),
          width: 40.0,
          height: 24.0,
          padding: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: const Cubic(0.2, 0.8, 0.2, 1.0),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20.0,
              height: 20.0,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
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

/// A setting row with a title, optional subtitle, and an inline switch toggle.
class SettingToggleRow extends StatelessWidget {
  const SettingToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      subtitle: subtitle,
      trailing: MacOSToggleSwitch(
        switchKey: switchKey,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// A pill-shaped action button for dialog actions (e.g. Open, Change, Check).
/// Follows Antigravity's Modern Desktop aesthetic with crisp hovers and no focus rings.
class ActionPill extends StatefulWidget {
  const ActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;
  final IconData? icon;

  @override
  State<ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<ActionPill> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final enabled = widget.onTap != null;
    final isPrimary = widget.primary;
    final isDestructive = widget.destructive;

    Color bg;
    Color fg;
    BorderSide? border;

    if (isPrimary) {
      bg = enabled
          ? (_hovered ? Palette.accent.withValues(alpha: 0.9) : Palette.accent)
          : Palette.accent.withValues(alpha: 0.4);
      fg = Colors.white;
      border = null;
    } else if (isDestructive && enabled && _hovered) {
      bg = isDark ? const Color(0x1FDC2626) : const Color(0x14EF4444); // hover:bg-red-500/[0.08]
      fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626); // hover:text-red-600
      border = BorderSide(
        color: isDark ? const Color(0x33EF4444) : const Color(0x33DC2626), // hover:border-red-500/20
        width: 1,
      );
    } else {
      bg = enabled
          ? (_hovered
              ? (isDark ? const Color(0xFF2C2F36) : const Color(0xFFE8EAED))
              : (isDark ? const Color(0xFF26282D) : const Color(0xFFF1F3F5)))
          : (isDark ? const Color(0xFF222428) : const Color(0xFFF7F8FA));
      fg = enabled ? skin.text : skin.muted;
      border = BorderSide(
        color: _hovered
            ? (isDark ? const Color(0xFF3E434D) : const Color(0xFFD0D3D8))
            : (isDark ? const Color(0xFF33373E) : const Color(0xFFE2E4E8)),
        width: 1,
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            constraints: const BoxConstraints(minHeight: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(UiRadius.control),
              border: border == null ? null : Border.fromBorderSide(border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fg,
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

/// A selectable card for choosing options visually (inspired by Antigravity's Interface Layout cards).
/// Displays an icon, bold title, and description, with an active accent border and soft tint.
class SelectableOptionCard extends StatefulWidget {
  const SelectableOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<SelectableOptionCard> createState() => _SelectableOptionCardState();
}

class _SelectableOptionCardState extends State<SelectableOptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final isSelected = widget.selected;

    // Solid, harmonious colors that never flash dark in light theme:
    final Color bg = isSelected
        ? (isDark ? const Color(0xFF1E2A3B) : const Color(0xFFEFF5FE))
        : (_hovered
            ? (isDark ? const Color(0xFF282B31) : const Color(0xFFF6F8FB))
            : (isDark ? const Color(0xFF222428) : Colors.white));

    final Color borderColor = isSelected
        ? Palette.accent
        : (_hovered
            ? Palette.accent.withValues(alpha: 0.4)
            : (isDark ? const Color(0xFF33373E) : const Color(0xFFE2E4E8)));

    final double borderWidth = isSelected ? 1.5 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: isSelected
                    ? Palette.accent
                    : (isDark ? const Color(0xFFC4C8CE) : const Color(0xFF4B515B)),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (isDark ? const Color(0xFF93C5FD) : Palette.accent)
                      : skin.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: 11.5,
                  color: skin.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


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
                    ? const Icon(Icons.check_rounded, size: 16)
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
            minimumSize: const Size(138, 34),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 13, fontWeight: FontWeight.w400),
            shape: const StadiumBorder(),
          ),
          child: Semantics(
            label: '${widget.label}: $label',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label)),
                const SizedBox(width: 16),
                Icon(Icons.expand_more_rounded, size: 16, color: skin.muted),
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



/// Exclusive tabs in a pill.
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: skin.divider.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: label,
                excludeSemantics: true,
                onTap: () => onChanged(i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Container(
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == index ? skin.card : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == index
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i == index ? skin.text : skin.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    this.subtitleStyle,
    this.trailing,
    this.stacked = false,
  });

  final String title;
  final String? subtitle;
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
        if (subtitle != null) ...[
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
      children: [
        Expanded(child: text),
        const SizedBox(width: 12),
        trailing!,
      ],
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
      trailing: Transform.scale(
        scale: 0.8,
        alignment: Alignment.centerRight,
        child: Switch(
          key: switchKey,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

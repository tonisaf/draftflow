import 'expanded_cell_editor.dart';

import 'package:flutter/services.dart';

import 'database_grid_navigation.dart';
import '../../../../data/model/numeric_cell_input.dart';
import 'numeric_input_message.dart';
import '../../../common/app_icons.dart';

import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/modern_dialog.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_models.dart';

class DatabaseNumberCell extends StatefulWidget {
  final DatabaseCellEditor? editor;
  final ValueChanged<bool>? onEditingChanged;
  final DatabaseColumn column;
  final dynamic cellValue;
  final bool isCellHovered;
  final ValueChanged<dynamic> onChanged;

  const DatabaseNumberCell({
    this.editor,
    super.key,
    this.onEditingChanged,
    required this.column,
    required this.cellValue,
    this.isCellHovered = false,
    required this.onChanged,
  });

  @override
  State<DatabaseNumberCell> createState() => _DatabaseNumberCellState();
}

class _DatabaseNumberCellState extends State<DatabaseNumberCell> {
  late final TextEditingController _controller;
  VoidCallback? _closeEditor;
  bool _pickerOpen = false;
  bool _isEditing = false;
  dynamic _lastSubmittedValue;

  @override
  void initState() {
    super.initState();
    final rawText = _extractRawNumberText(widget.cellValue);
    _controller = TextEditingController(text: rawText);
    _lastSubmittedValue = _parseValue(rawText);
  }

  String _extractRawNumberText(dynamic val) {
    if (val == null) return '';
    if (val is num && !val.isFinite) return val.toString();
    final config = NumberColumnConfig.fromOptions(widget.column.options);
    if (val is num &&
        config.format.startsWith('duration') &&
        parseNumericCellInput(val, format: config.format).valid) {
      if (val != val.truncateToDouble()) return val.toString();
      if (config.format == 'duration_hms') {
        return formatDurationHms(val);
      } else if (config.format == 'duration_ms') {
        return formatDurationMs(val);
      } else {
        return formatDurationHuman(val);
      }
    }
    if (val is num) {
      return val.abs() >= 1e21
          ? val.toString()
          : val == val.toInt()
          ? val.toInt().toString()
          : val.toString();
    }
    final s = val.toString().trim();
    final parsed = num.tryParse(s);
    if (parsed != null && parsed.isFinite) {
      return parsed == parsed.toInt()
          ? parsed.toInt().toString()
          : parsed.toString();
    }
    return s;
  }

  dynamic _parseValue(String raw) {
    final parsed = parseNumericCellInput(
      raw,
      format: NumberColumnConfig.fromOptions(widget.column.options).format,
    );
    return parsed.valid ? parsed.value : raw;
  }

  void _commit() {
    final val = _parseValue(_controller.text);
    if (val != _lastSubmittedValue) {
      _lastSubmittedValue = val;
      widget.onChanged(val);
    }
  }

  @override
  void didUpdateWidget(DatabaseNumberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cellValue != widget.cellValue && !_isEditing) {
      final rawText = _extractRawNumberText(widget.cellValue);
      _controller.text = rawText;
      _lastSubmittedValue = _parseValue(rawText);
    }
  }

  @override
  void dispose() {
    _closeEditor?.call();
    _commit();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startEditing() async {
    if (_isEditing || HardwareKeyboard.instance.isShiftPressed) return;
    setState(() => _isEditing = true);
    widget.onEditingChanged?.call(true);
    final format = NumberColumnConfig.fromOptions(widget.column.options).format;
    await showExpandedCellEditor(
      context,
      _controller.text,
      anchorContext: widget.editor?.anchorContext?.call(),
      multiline: false,
      selectAll: true,
      keyboardType: format.startsWith('duration')
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true, signed: true),
      validationMessage: (text) {
        final issue = parseNumericCellInput(text, format: format).issue;
        return issue == null ? null : numericInputMessage(context, issue);
      },
      accessoryBuilder: format.startsWith('duration')
          ? (context, text, close) => SizedBox(
              height: DesktopUx.databaseRowHeight,
              child: IconButton(
                key: const ValueKey('open_duration_picker_btn'),
                padding: const EdgeInsets.all(UiSpace.s8),
                icon: Icon(
                  AppIcons.clock,
                  size: UiSpace.s14,
                  color: context.skin.muted,
                ),
                onPressed: () {
                  final raw = text.text;
                  _openDurationPicker(context, raw: raw);
                  close();
                },
              ),
            )
          : null,
      onCloseReady: (close) => _closeEditor = close,
      onSave: (value) {
        _controller.text = value;
        _commit();
      },
    );
    if (!mounted) return;
    _closeEditor = null;
    setState(() => _isEditing = false);
    if (!_pickerOpen) widget.onEditingChanged?.call(false);
  }

  void _openDurationPicker(BuildContext ctx, {String? raw}) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    final val = raw ?? widget.cellValue;
    final currentSeconds = parseNumericCellInput(
      val,
      format: 'duration_human',
    ).value;

    var applied = false;
    _pickerOpen = true;
    widget.onEditingChanged?.call(true);
    showPopover(
      context,
      anchor: anchor,
      width: 270.0,
      builder: (popContext, closePicker) => DurationPickerContent(
        initialSeconds: currentSeconds ?? 0,
        onApply: (newSeconds) {
          applied = true;
          _lastSubmittedValue = newSeconds;
          widget.onChanged(newSeconds);
          final rawText = _extractRawNumberText(newSeconds);
          _controller.text = rawText;
          if (mounted) {
            setState(() => _isEditing = false);
          }
        },
        onClose: closePicker,
      ),
    ).whenComplete(() {
      _pickerOpen = false;
      if (mounted && !_isEditing) {
        widget.onEditingChanged?.call(false);
        if (applied || FocusManager.instance.primaryFocus is FocusScopeNode) {
          DatabaseGridScope.maybeOf(context)?.focus();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    widget.editor?.open = _startEditing;
    widget.editor?.cancel = () {
      _controller.text = _extractRawNumberText(widget.cellValue);
    };
    final skin = context.skin;
    final config = NumberColumnConfig.fromOptions(widget.column.options);
    final isDuration = config.format.startsWith('duration');

    final issue = parseNumericCellInput(
      _isEditing ? _controller.text : widget.cellValue,
      format: config.format,
    ).issue;
    final val = widget.cellValue;
    final numeric = parseNumericCellInput(val, format: config.format).value;

    if (numeric == null || !numeric.isFinite) {
      final text = val?.toString().trim() ?? '';
      return MouseRegion(
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _startEditing,
          child: Container(
            alignment: Alignment.centerLeft,
            child: text.isNotEmpty
                ? Tooltip(
                    message: issue == null
                        ? text
                        : numericInputMessage(context, issue),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UiType.body,
                        color: issue == null ? skin.text : skin.destructive,
                        fontFeatures: UiType.tabular,
                      ),
                    ),
                  )
                : (widget.isCellHovered
                      ? Row(
                          children: [
                            Text(
                              isDuration ? '0s' : '0',
                              style: TextStyle(
                                fontSize: UiType.body,
                                color: skin.hint,
                                fontFeatures: UiType.tabular,
                              ),
                            ),
                            if (isDuration) ...[
                              const SizedBox(width: 4),
                              Builder(
                                builder: (btnContext) => InkWell(
                                  key: const ValueKey(
                                    'open_duration_picker_btn',
                                  ),
                                  onTap: () => _openDurationPicker(btnContext),
                                  child: Icon(
                                    AppIcons.clock,
                                    size: UiSpace.s14,
                                    color: skin.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.expand()),
          ),
        ),
      );
    }

    final formatted = formatNumberValue(numeric, config);
    final max = config.maxValue <= 0 ? 100.0 : config.maxValue;
    final progress = (numeric / max).clamp(0.0, 1.0);
    final primaryColor = config.color != null
        ? Palette.stored(config.color!)
        : Palette.accent;

    Widget content;
    if (config.showAs == 'bar') {
      content = Row(
        children: [
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: skin.controlBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: UiSpace.s8),
          Text(
            formatted,
            style: TextStyle(
              fontSize: UiType.body,
              color: skin.text,
              fontFeatures: UiType.tabular,
            ),
          ),
        ],
      );
    } else if (config.showAs == 'ring') {
      content = Row(
        children: [
          CustomPaint(
            size: const Size(16, 16),
            painter: ProgressRingPainter(
              progress: progress,
              color: primaryColor,
              trackColor: skin.controlBorder.withValues(alpha: 0.4),
              strokeWidth: 2.2,
            ),
          ),
          const SizedBox(width: UiSpace.s8),
          Text(
            formatted,
            style: TextStyle(
              fontSize: UiType.body,
              color: skin.text,
              fontFeatures: UiType.tabular,
            ),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(
            child: Text(
              formatted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: UiType.body,
                color: skin.text,
                fontFeatures: UiType.tabular,
              ),
            ),
          ),
          if (isDuration && widget.isCellHovered)
            Builder(
              builder: (btnContext) => InkWell(
                key: const ValueKey('open_duration_picker_btn'),
                onTap: () => _openDurationPicker(btnContext),
                child: Icon(
                  AppIcons.clock,
                  size: UiSpace.s14,
                  color: skin.muted,
                ),
              ),
            ),
        ],
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startEditing,
        child: Container(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }
}

class DurationPickerContent extends StatefulWidget {
  final num initialSeconds;
  final ValueChanged<num> onApply;
  final VoidCallback onClose;

  const DurationPickerContent({
    super.key,
    required this.initialSeconds,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<DurationPickerContent> createState() => _DurationPickerContentState();
}

class _DurationPickerContentState extends State<DurationPickerContent> {
  bool _negative = false;
  bool _invalid = false;
  late final TextEditingController _daysController;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    final initial =
        parseNumericCellInput(
          widget.initialSeconds,
          format: 'duration_human',
        ).value ??
        0;
    _negative = initial < 0;
    var s = initial.abs();
    final d = s ~/ 86400;
    s %= 86400;
    final h = s ~/ 3600;
    s %= 3600;
    final m = s ~/ 60;
    final raw = initial.abs().toString();
    final fraction = initial == initial.truncateToDouble() || !raw.contains('.')
        ? ''
        : raw.substring(raw.indexOf('.'));
    final sec = raw.contains('e')
        ? initial.abs().toString()
        : '${s.truncate() % 60}$fraction';

    _daysController = TextEditingController(text: d == 0 ? '' : d.toString());
    _hoursController = TextEditingController(text: h == 0 ? '' : h.toString());
    _minutesController = TextEditingController(
      text: m == 0 ? '' : m.toString(),
    );
    _secondsController = TextEditingController(text: sec == '0' ? '' : sec);
  }

  @override
  void dispose() {
    _daysController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _apply() {
    final values = [
      _daysController,
      _hoursController,
      _minutesController,
      _secondsController,
    ].map((c) => parseNumericCellInput(c.text)).toList();
    final numbers = values.map((v) => v.value ?? 0).toList();
    if (values.any((v) => !v.valid) ||
        numbers.any((v) => v < 0) ||
        numbers.take(3).any((v) => v != v.truncateToDouble()) ||
        numbers[1] >= 24 ||
        numbers[2] >= 60 ||
        numbers[3] >= 60) {
      setState(() => _invalid = true);
      return;
    }
    final total =
        (numbers[0] * 86400 +
            numbers[1] * 3600 +
            numbers[2] * 60 +
            numbers[3]) *
        (_negative ? -1 : 1);
    if (!parseNumericCellInput(total, format: 'duration_human').valid) {
      setState(() => _invalid = true);
      return;
    }
    widget.onApply(total);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    Widget buildUnitField(
      TextEditingController controller,
      String label,
      String unit,
      Key key,
    ) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: UiType.caption, color: skin.muted),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  height: 32,
                  child: TextField(
                    key: key,
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: UiType.body, color: skin.text),
                    decoration: modernInputDecoration(
                      skin: skin,
                      hintText: '0',
                    ),
                    onChanged: (_) => setState(() => _invalid = false),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(fontSize: UiType.caption, color: skin.muted),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(UiSpace.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.clock, size: UiSpace.s16, color: skin.muted),
              const SizedBox(width: 6),
              Text(
                context.l10n.durationTitle,
                style: TextStyle(
                  fontSize: UiType.body,
                  fontWeight: FontWeight.w600,
                  color: skin.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              buildUnitField(
                _daysController,
                context.l10n.durationDays,
                'd',
                const ValueKey('duration_days_input'),
              ),
              buildUnitField(
                _hoursController,
                context.l10n.durationHours,
                'h',
                const ValueKey('duration_hours_input'),
              ),
              buildUnitField(
                _minutesController,
                context.l10n.durationMins,
                'm',
                const ValueKey('duration_mins_input'),
              ),
              buildUnitField(
                _secondsController,
                context.l10n.durationSecs,
                's',
                const ValueKey('duration_secs_input'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              context.l10n.durationNegative,
              style: const TextStyle(fontSize: UiType.caption),
            ),
            value: _negative,
            onChanged: (value) => setState(() => _negative = value ?? false),
          ),
          if (_invalid)
            Text(
              context.l10n.durationInvalidFields,
              style: TextStyle(
                fontSize: UiType.caption,
                color: skin.destructive,
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('apply_duration_btn'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.accent,
                foregroundColor: Palette.onAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UiRadius.control),
                ),
              ),
              onPressed: _apply,
              child: Text(context.l10n.apply),
            ),
          ),
        ],
      ),
    );
  }
}

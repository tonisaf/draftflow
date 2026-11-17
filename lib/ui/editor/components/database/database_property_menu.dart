import 'dart:convert';

import '../../../common/app_icons.dart';

import 'package:flutter/material.dart';

import '../../../common/menu.dart';
import '../../../common/modern_dialog.dart';
import '../../../common/popover.dart';

import 'package:notes_here/l10n/locale_controller.dart';

import '../../../theme.dart';
import 'database_dialogs.dart' show ModernSelectPicker, SelectPickerItem;
import 'database_models.dart';

const databasePropertyTypes = [
  (value: 'text', label: 'Text'),
  (value: 'number', label: 'Number'),
  (value: 'select', label: 'Select (Tags)'),
  (value: 'multi_select', label: 'Multi-select'),
  (value: 'status', label: 'Status'),
  (value: 'checkbox', label: 'Checkbox'),
  (value: 'date', label: 'Date'),
  (value: 'url', label: 'URL Link'),
];

/// Property editing stays next to the column; nested type selection uses the
/// same popover system, so it never replaces the page with a modal dialog.
Future<void> showDatabasePropertyMenu(
  BuildContext context, {
  required Rect anchor,
  required String name,
  required String type,
  String? options,
  ValueChanged<String>? onRename,
  ValueChanged<String>? onChangeType,
  ValueChanged<String>? onOptionsChange,
  Function? onAdd,
  List<Widget> Function(VoidCallback close)? actions,
  bool Function()? canCommit,
}) async {
  final controller = TextEditingController(text: name);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: name.length,
  );
  var selectedType = type;
  var numberConfig = NumberColumnConfig.fromOptions(options);
  var committedName = name;
  var busy = false;
  String? error;
  void commitName() {
    final value = controller.text.trim();
    if (value.isNotEmpty &&
        value != committedName &&
        (canCommit?.call() ?? true)) {
      onRename?.call(value);
      committedName = value;
    }
  }

  void openNumberFormatPicker(
    BuildContext rowContext, {
    required String currentFormat,
    required ValueChanged<String> onSelect,
  }) {
    final box = rowContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    showPopover(
      context,
      anchor: anchor,
      width: DesktopUx.popoverWidth,
      builder: (popContext, closePicker) => _NumberFormatPicker(
        currentFormat: currentFormat,
        onSelect: (selectedId) {
          closePicker();
          onSelect(selectedId);
        },
      ),
    );
  }

  void openDecimalPlacesPicker(
    BuildContext rowContext, {
    required int? currentPlaces,
    required ValueChanged<int?> onSelect,
  }) {
    final box = rowContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    final optionsList = [
      (value: null, label: context.l10n.propertyDefault),
      (value: 0, label: '0'),
      (value: 1, label: '1'),
      (value: 2, label: '2'),
      (value: 3, label: '3'),
      (value: 4, label: '4'),
      (value: 5, label: '5'),
    ];

    showPopover(
      context,
      anchor: anchor,
      width: 160.0,
      builder: (popContext, closePicker) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final opt in optionsList)
            MenuRow(
              label: opt.label,
              selected: currentPlaces == opt.value,
              onTap: () {
                closePicker();
                onSelect(opt.value);
              },
            ),
        ],
      ),
    );
  }

  try {
    await showPopover(
      context,
      anchor: anchor,
      width: DesktopUx.popoverWidth,
      builder: (menuContext, close) => StatefulBuilder(
        builder: (context, setMenuState) {
          final skin = context.skin;
          Future<void> submit() async {
            if (busy) return;
            if (onAdd == null) {
              commitName();
              close();
              return;
            }
            final value = controller.text.trim();
            if (value.isEmpty) return;
            setMenuState(() {
              busy = true;
              error = null;
            });
            try {
              final opts = selectedType == 'number'
                  ? numberConfig.toOptions()
                  : selectedType == 'status'
                      ? jsonEncode([
                          {
                            'id': 'not_started',
                            'label': context.l10n.statusNotStarted,
                            'color': '0xFF9E9E9E',
                          },
                          {
                            'id': 'in_progress',
                            'label': context.l10n.statusInProgress,
                            'color': '0xFF2196F3',
                          },
                          {
                            'id': 'done',
                            'label': context.l10n.statusDone,
                            'color': '0xFF4CAF50',
                          },
                        ])
                      : null;
              if (onAdd
                  is Future<void> Function(String, String, {String? options})) {
                await onAdd(value, selectedType, options: opts);
              } else if (onAdd
                  is Future<void> Function(String, String, String?)) {
                await onAdd(value, selectedType, opts);
              } else if (onAdd is Future<void> Function(String, String)) {
                await onAdd(value, selectedType);
              } else {
                try {
                  await Function.apply(
                    onAdd,
                    [value, selectedType],
                    {#options: opts},
                  );
                } catch (_) {
                  await Function.apply(onAdd, [value, selectedType]);
                }
              }
              close();
            } catch (_) {
              if (context.mounted) {
                setMenuState(() {
                  busy = false;
                  error = context.l10n.propertyError;
                });
              }
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(UiSpace.s8),
                child: TextField(
                  key: const ValueKey('database_property_name'),
                  controller: controller,
                  autofocus: true,
                  selectAllOnFocus: false,
                  enabled: !busy,
                  style: TextStyle(fontSize: UiType.body, color: skin.text),
                  decoration: modernInputDecoration(
                    skin: skin,
                    hintText: context.l10n.propertyNameHint,
                  ),
                  onSubmitted: (_) => submit(),
                  onTapOutside: (_) => commitName(),
                ),
              ),
              if (type != 'title' && (onAdd != null || onChangeType != null))
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UiSpace.s8,
                    0,
                    UiSpace.s8,
                    UiSpace.s8,
                  ),
                  child: ModernSelectPicker<String>(
                    value: selectedType,
                    items: <SelectPickerItem<String>>[
                      for (final item in databasePropertyTypes)
                        (
                          value: item.value,
                          label: switch (item.value) {
                            'number' => context.l10n.propTypeNumber,
                            'select' => context.l10n.propTypeSelect,
                            'multi_select' => context.l10n.propTypeMultiSelect,
                            'status' => context.l10n.propTypeStatus,
                            'checkbox' => context.l10n.propTypeCheckbox,
                            'date' => context.l10n.propTypeDate,
                            'url' => context.l10n.propTypeUrl,
                            _ => context.l10n.propTypeText,
                          },
                          icon: iconForColumnType(item.value),
                          leading: null,
                        ),
                    ],
                    onChanged: (value) {
                      if (busy || value == selectedType) return;
                      commitName();
                      setMenuState(() => selectedType = value);
                      onChangeType?.call(value);
                      if (value == 'status' &&
                          (options == null || options.isEmpty)) {
                        final defaultOpts = jsonEncode([
                          {
                            'id': 'not_started',
                            'label': context.l10n.statusNotStarted,
                            'color': '0xFF9E9E9E',
                          },
                          {
                            'id': 'in_progress',
                            'label': context.l10n.statusInProgress,
                            'color': '0xFF2196F3',
                          },
                          {
                            'id': 'done',
                            'label': context.l10n.statusDone,
                            'color': '0xFF4CAF50',
                          },
                        ]);
                        onOptionsChange?.call(defaultOpts);
                      }
                    },
                  ),
                ),
              if (selectedType == 'number') ...[
                const MenuDivider(),
                _PropertyNavigationRow(
                  key: const ValueKey('number_format_row'),
                  label: context.l10n.propertyNumberFormat,
                  value: kNumberFormats
                      .firstWhere(
                        (f) => f.id == numberConfig.format,
                        orElse: () => kNumberFormats.first,
                      )
                      .label,
                  onTap: (rowContext) => openNumberFormatPicker(
                    rowContext,
                    currentFormat: numberConfig.format,
                    onSelect: (newFormat) {
                      final updated = numberConfig.copyWith(format: newFormat);
                      setMenuState(() => numberConfig = updated);
                      onOptionsChange?.call(updated.toOptions());
                    },
                  ),
                ),
                _PropertyNavigationRow(
                  key: const ValueKey('number_decimal_places_row'),
                  label: context.l10n.propertyDecimalPlaces,
                  value: numberConfig.decimalPlaces == null
                      ? context.l10n.propertyDefault
                      : numberConfig.decimalPlaces.toString(),
                  onTap: (rowContext) => openDecimalPlacesPicker(
                    rowContext,
                    currentPlaces: numberConfig.decimalPlaces,
                    onSelect: (newPlaces) {
                      final updated = numberConfig.copyWith(
                        decimalPlaces: () => newPlaces,
                      );
                      setMenuState(() => numberConfig = updated);
                      onOptionsChange?.call(updated.toOptions());
                    },
                  ),
                ),
                const SizedBox(height: UiSpace.s12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8),
                  child: Text(
                    context.l10n.propertyShowAs,
                    style: TextStyle(
                      fontSize: UiType.caption,
                      fontWeight: FontWeight.w600,
                      color: skin.muted,
                    ),
                  ),
                ),
                const SizedBox(height: UiSpace.s8),
                for (final option in [
                  (value: 'number', label: context.l10n.propertyShowAsNumber),
                  (value: 'bar', label: context.l10n.propertyShowAsBar),
                  (value: 'ring', label: context.l10n.propertyShowAsRing),
                ])
                  MenuRow(
                    key: ValueKey('show_as_${option.value}'),
                    label: option.label,
                    selected: numberConfig.showAs == option.value,
                    onTap: () {
                      final updated = numberConfig.copyWith(
                        showAs: option.value,
                      );
                      setMenuState(() => numberConfig = updated);
                      onOptionsChange?.call(updated.toOptions());
                    },
                  ),
                if (numberConfig.showAs == 'bar' ||
                    numberConfig.showAs == 'ring') ...[
                  const SizedBox(height: UiSpace.s8),
                  _DivideByRow(
                    value: numberConfig.maxValue,
                    onChanged: (newMax) {
                      final updated = numberConfig.copyWith(maxValue: newMax);
                      setMenuState(() => numberConfig = updated);
                      onOptionsChange?.call(updated.toOptions());
                    },
                  ),
                ],
                const SizedBox(height: UiSpace.s10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8),
                  child: Text(
                    context.l10n.propertyScopeHint,
                    style: TextStyle(
                      fontSize: UiType.caption,
                      color: skin.hint,
                    ),
                  ),
                ),
                const SizedBox(height: UiSpace.s4),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(UiSpace.s8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: skin.destructive,
                      fontSize: UiType.caption,
                    ),
                  ),
                ),
              if (onAdd != null)
                MenuRow(
                  label: busy
                      ? context.l10n.propertyAdding
                      : context.l10n.databaseAddProperty,
                  glyph: AppIcons.plus,
                  onTap: () {
                    if (!busy) submit();
                  },
                ),
              if (actions != null) ...[const MenuDivider(), ...actions(close)],
            ],
          );
        },
      ),
    );
  } finally {
    if (onAdd == null) commitName();
    controller.dispose();
  }
}

class _PropertyNavigationRow extends StatelessWidget {
  final String label;
  final String value;
  final void Function(BuildContext rowContext) onTap;

  const _PropertyNavigationRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => MenuRow(
    label: label,
    onTap: () => onTap(context),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: DesktopUx.popoverWidth / 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: UiType.body, color: context.skin.hint),
            ),
          ),
          const SizedBox(width: UiSpace.s2),
          Icon(
            AppIcons.chevronRight,
            size: UiSpace.s16,
            color: context.skin.hint,
          ),
        ],
      ),
    ),
  );
}

class _DivideByRow extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DivideByRow({required this.value, required this.onChanged});

  @override
  State<_DivideByRow> createState() => _DivideByRowState();
}

class _DivideByRowState extends State<_DivideByRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _controller = TextEditingController(
      text: v == v.toInt() ? v.toInt().toString() : v.toString(),
    );
  }

  @override
  void didUpdateWidget(_DivideByRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final v = widget.value;
      final text = v == v.toInt() ? v.toInt().toString() : v.toString();
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed != null && parsed > 0 && parsed != widget.value) {
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8),
      child: Row(
        children: [
          Text(
            context.l10n.propertyDivideBy,
            style: TextStyle(fontSize: UiType.body, color: skin.text),
          ),
          const Spacer(),
          SizedBox(
            width: 72,
            height: 28,
            child: TextField(
              controller: _controller,
              selectAllOnFocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: UiType.body, color: skin.text),
              decoration: modernInputDecoration(skin: skin, hintText: '100'),
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberFormatPicker extends StatefulWidget {
  final String currentFormat;
  final ValueChanged<String> onSelect;

  const _NumberFormatPicker({
    required this.currentFormat,
    required this.onSelect,
  });

  @override
  State<_NumberFormatPicker> createState() => _NumberFormatPickerState();
}

class _NumberFormatPickerState extends State<_NumberFormatPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final filtered = kNumberFormats.where((f) {
      if (_query.isEmpty) return true;
      return f.label.toLowerCase().contains(_query) ||
          f.id.toLowerCase().contains(_query) ||
          (f.symbol != null && f.symbol!.toLowerCase().contains(_query)) ||
          f.searchKeywords.any((k) => k.toLowerCase().contains(_query));
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(UiSpace.s8),
          child: TextField(
            key: const ValueKey('number_format_filter_input'),
            controller: _searchController,
            autofocus: true,
            selectAllOnFocus: false,
            style: TextStyle(fontSize: UiType.body, color: skin.text),
            decoration: modernInputDecoration(
              skin: skin,
              hintText: context.l10n.propertyFilterFormats,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in filtered)
                  MenuRow(
                    key: ValueKey('number_format_${item.id}'),
                    label: item.label,
                    selected: item.id == widget.currentFormat,
                    onTap: () => widget.onSelect(item.id),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(UiSpace.s12),
                    child: Text(
                      'No matches found',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: UiType.caption,
                        color: skin.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

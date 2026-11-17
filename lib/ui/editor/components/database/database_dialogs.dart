import '../../../common/app_dialog.dart';
import '../../../common/app_icons.dart';

import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/menu.dart';
import 'package:notes_here/ui/common/modern_dialog.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_models.dart';

export 'package:notes_here/ui/common/modern_dialog.dart';

// ----------------------------------------------------------------------------
// Desktop Modern Select Picker (Native Popover replacement for Material Dropdown)
// ----------------------------------------------------------------------------

typedef SelectPickerItem<T> = ({
  T value,
  String label,
  IconData? icon,
  Widget? leading,
});

class ModernSelectPicker<T> extends StatelessWidget {
  final T value;
  final List<SelectPickerItem<T>> items;
  final ValueChanged<T> onChanged;
  final double? width;

  const ModernSelectPicker({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
  });

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    showPopover(
      context,
      anchor: anchor,
      width: (box.size.width).clamp(
        DesktopUx.menuMinWidth,
        UiLayout.columnDialogWidth,
      ),
      builder: (popContext, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            MenuRow(
              label: item.label,
              glyph: item.icon,
              icon: item.leading,
              selected: item.value == value,
              onTap: () {
                close();
                onChanged(item.value);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    SelectPickerItem<T> currentItem = items.first;
    for (final item in items) {
      if (item.value == value) {
        currentItem = item;
        break;
      }
    }

    return Builder(
      builder: (pickerCtx) => InkWell(
        borderRadius: BorderRadius.circular(UiRadius.control),
        onTap: () => _open(pickerCtx),
        child: Container(
          width: width,
          height: UiSpace.s36,
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.s11),
          decoration: BoxDecoration(
            color: skin.surfaceSubtle,
            borderRadius: BorderRadius.circular(UiRadius.control),
            border: Border.all(color: skin.divider),
          ),
          child: Row(
            children: [
              if (currentItem.leading != null) ...[
                currentItem.leading!,
                const SizedBox(width: UiSpace.s8),
              ] else if (currentItem.icon != null) ...[
                Icon(currentItem.icon, size: UiSpace.s14, color: skin.muted),
                const SizedBox(width: UiSpace.s8),
              ],
              Expanded(
                child: Text(
                  currentItem.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: UiType.body, color: skin.text),
                ),
              ),
              Icon(
                AppIcons.arrowLeftRight,
                size: UiSpace.s15,
                color: skin.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Filter Dialog
// ----------------------------------------------------------------------------

void showFilterDialog({
  required BuildContext context,
  required List<DatabaseColumn> columns,
  required List<DatabaseFilterRule> filterRules,
  required ValueChanged<DatabaseFilterRule> onAddFilter,
  required ValueChanged<String> onRemoveFilter,
  required VoidCallback onClearFilters,
}) {
  if (columns.isEmpty) return;

  DatabaseColumn selectedCol = columns.first;
  String selectedOperator = selectedCol.type == 'checkbox'
      ? 'is_true'
      : (selectedCol.type == 'select' ? 'equals' : 'contains');
  String textValue = '';
  String? selectValue;

  showAppDialog(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final skin = ctx.skin;
        return ModernDialog(
          title: ctx.l10n.filterDialogTitle,
          icon: AppIcons.lineHorizontal3Decrease,
          maxWidth: UiLayout.columnPropertiesWidth,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active filters list
              if (filterRules.isNotEmpty) ...[
                Text(
                  ctx.l10n.filterActiveRules,
                  style: TextStyle(
                    fontSize: UiType.caption,
                    fontWeight: FontWeight.w600,
                    color: skin.muted,
                  ),
                ),
                const SizedBox(height: UiSpace.s6),
                Wrap(
                  spacing: UiSpace.s6,
                  runSpacing: UiSpace.s6,
                  children: [
                    for (final rule in filterRules) ...[
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s4,
                        ),
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          ruleLabel(rule, columns),
                          style: const TextStyle(fontSize: UiType.caption),
                        ),
                        onDeleted: () {
                          onRemoveFilter(rule.columnId);
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: UiSpace.s14),
                const Divider(height: 1),
                const SizedBox(height: UiSpace.s12),
              ],

              Text(
                ctx.l10n.filterAddFilter,
                style: TextStyle(
                  fontSize: UiType.caption,
                  fontWeight: FontWeight.w600,
                  color: skin.muted,
                ),
              ),
              const SizedBox(height: UiSpace.s8),

              // Column selector
              ModernSelectPicker<String>(
                value: selectedCol.id,
                items: <SelectPickerItem<String>>[
                  for (final c in columns)
                    (
                      value: c.id,
                      label: c.name,
                      icon: iconForColumnType(c.type),
                      leading: null,
                    ),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    selectedCol = columns.firstWhere((c) => c.id == val);
                    if (selectedCol.type == 'checkbox') {
                      selectedOperator = 'is_true';
                    } else if (selectedCol.type == 'date') {
                      selectedOperator = 'is_not_empty';
                    } else if (selectedCol.type == 'select' ||
                        selectedCol.type == 'status') {
                      selectedOperator = 'equals';
                    } else if (selectedCol.type == 'multi_select') {
                      selectedOperator = 'contains';
                    } else {
                      selectedOperator = 'contains';
                    }
                  });
                },
              ),
              const SizedBox(height: UiSpace.s10),

              // Condition / Value input based on column type
              if (selectedCol.type == 'checkbox') ...[
                ModernSelectPicker<String>(
                  value: selectedOperator,
                  items: <SelectPickerItem<String>>[
                    (
                      value: 'is_true',
                      label: ctx.l10n.filterCheckedOnly,
                      icon: AppIcons.checkmarkSquare,
                      leading: null,
                    ),
                    (
                      value: 'is_false',
                      label: ctx.l10n.filterUncheckedOnly,
                      icon: AppIcons.square,
                      leading: null,
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedOperator = val);
                  },
                ),
              ] else if (selectedCol.type == 'date') ...[
                ModernSelectPicker<String>(
                  value: selectedOperator,
                  items: <SelectPickerItem<String>>[
                    (
                      value: 'is_not_empty',
                      label: ctx.l10n.filterHasDate,
                      icon: AppIcons.calendar,
                      leading: null,
                    ),
                    (
                      value: 'is_empty',
                      label: ctx.l10n.filterNoDate,
                      icon: AppIcons.calendarBadgeMinus,
                      leading: null,
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedOperator = val);
                  },
                ),
              ] else if (selectedCol.type == 'select' ||
                  selectedCol.type == 'multi_select' ||
                  selectedCol.type == 'status') ...[
                Builder(
                  builder: (ctx) {
                    List<dynamic> options = [];
                    if (selectedCol.options != null &&
                        selectedCol.options!.isNotEmpty) {
                      try {
                        options =
                            jsonDecode(selectedCol.options!) as List<dynamic>;
                      } catch (_) {}
                    }
                    final selectPickerItems = <SelectPickerItem<String>>[
                      for (final opt in options)
                        (
                          value: opt['id'].toString(),
                          label: opt['label'].toString(),
                          icon: null,
                          leading: Container(
                            width: UiSpace.s8,
                            height: UiSpace.s8,
                            decoration: BoxDecoration(
                              color: Palette.stored(
                                int.tryParse(opt['color'].toString()) ??
                                    Palette.defaultTagArgb,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      (
                        value: '__is_not_empty__',
                        label: ctx.l10n.filterHasTag,
                        icon: AppIcons.checkmarkCircle,
                        leading: null,
                      ),
                      (
                        value: '__is_empty__',
                        label: ctx.l10n.filterNoTag,
                        icon: AppIcons.xmarkCircle,
                        leading: null,
                      ),
                    ];
                    return ModernSelectPicker<String>(
                      value: selectValue ?? selectPickerItems.first.value,
                      items: selectPickerItems,
                      onChanged: (val) {
                        setDialogState(() {
                          selectValue = val;
                          if (val == '__is_empty__') {
                            selectedOperator = 'is_empty';
                          } else if (val == '__is_not_empty__') {
                            selectedOperator = 'is_not_empty';
                          } else {
                            selectedOperator =
                                selectedCol.type == 'multi_select'
                                    ? 'contains'
                                    : 'equals';
                          }
                        });
                      },
                    );
                  },
                ),
              ] else if (selectedCol.type == 'url') ...[
                ModernSelectPicker<String>(
                  value: selectedOperator,
                  items: <SelectPickerItem<String>>[
                    (
                      value: 'contains',
                      label: ctx.l10n.filterContainsUrl,
                      icon: AppIcons.lineHorizontal3Decrease,
                      leading: null,
                    ),
                    (
                      value: 'is_not_empty',
                      label: 'Has URL (Not empty)',
                      icon: AppIcons.link,
                      leading: null,
                    ),
                    (
                      value: 'is_empty',
                      label: 'No URL (Empty)',
                      icon: AppIcons.link,
                      leading: null,
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedOperator = val);
                  },
                ),
                if (selectedOperator == 'contains') ...[
                  const SizedBox(height: UiSpace.s10),
                  TextField(
                    autofocus: true,
                    selectAllOnFocus: false,
                    style: TextStyle(fontSize: UiType.body, color: skin.text),
                    decoration: modernInputDecoration(
                      skin: skin,
                      hintText: 'e.g. github.com or https://...',
                    ),
                    onChanged: (val) => textValue = val,
                  ),
                ],
              ] else ...[
                TextField(
                  autofocus: true,
                  selectAllOnFocus: false,
                  style: TextStyle(fontSize: UiType.body, color: skin.text),
                  decoration: modernInputDecoration(
                    skin: skin,
                    hintText: 'Contains text...',
                  ),
                  onChanged: (val) => textValue = val,
                ),
              ],
            ],
          ),
          actions: [
            if (filterRules.isNotEmpty) ...[
              TextButton(
                onPressed: () {
                  onClearFilters();
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: skin.muted),
                child: Text(ctx.l10n.clearAll),
              ),
              const Spacer(),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: skin.muted),
              child: Text(ctx.l10n.cancel),
            ),
            const SizedBox(width: UiSpace.s8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.accent,
                foregroundColor: Palette.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UiRadius.control),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s16,
                  vertical: UiSpace.s8,
                ),
              ),
              onPressed: () {
                dynamic ruleVal;
                if (selectedCol.type == 'select' ||
                    selectedCol.type == 'status' ||
                    selectedCol.type == 'multi_select') {
                  if (selectedOperator == 'equals' ||
                      selectedOperator == 'contains') {
                    ruleVal = selectValue;
                  }
                } else if (selectedCol.type == 'text' ||
                    selectedCol.type == 'title' ||
                    selectedCol.type == 'url' ||
                    selectedCol.type == 'number') {
                  ruleVal = textValue.trim();
                }

                onAddFilter(
                  DatabaseFilterRule(
                    columnId: selectedCol.id,
                    operator: selectedOperator,
                    value: ruleVal,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: Text(ctx.l10n.apply),
            ),
          ],
        );
      },
    ),
  );
}

// ----------------------------------------------------------------------------
// Add Tag Dialog
// ----------------------------------------------------------------------------

void showAddTagDialog({
  required BuildContext context,
  required DatabaseColumn column,
  required NotesRepository repository,
  required ValueChanged<dynamic> onUpdateValue,
  String? title,
}) {
  final nameController = TextEditingController();
  int selectedColor = tagColorPresets.first['color'] as int;
  final isStatus = column.type == 'status';
  final dialogTitle =
      title ?? (isStatus ? context.l10n.cellNewStatus : 'New Tag');
  final nameLabel = isStatus ? 'Status Name' : 'Tag Name';
  final nameHint =
      isStatus ? 'e.g. Planning, In Review' : 'e.g. In Progress, Urgent';
  final dialogIcon = isStatus ? AppIcons.circleLefthalfFill : AppIcons.tag;

  showAppDialog(
    context: context,
    animationStyle: Motion.dialogStyle(context),
    barrierColor: context.skin.scrim,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final skin = ctx.skin;
        return ModernDialog(
          title: dialogTitle,
          icon: dialogIcon,
          maxWidth: UiLayout.tagDialogWidth,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nameLabel,
                style: TextStyle(
                  fontSize: UiType.caption,
                  fontWeight: FontWeight.w600,
                  color: skin.muted,
                ),
              ),
              const SizedBox(height: UiSpace.s6),
              TextField(
                controller: nameController,
                autofocus: true,
                selectAllOnFocus: false,
                style: TextStyle(fontSize: UiType.body, color: skin.text),
                decoration: modernInputDecoration(
                  skin: skin,
                  hintText: nameHint,
                ),
              ),
              const SizedBox(height: UiSpace.s16),
              Text(
                'Color Preset',
                style: TextStyle(
                  fontSize: UiType.caption,
                  fontWeight: FontWeight.w600,
                  color: skin.muted,
                ),
              ),
              const SizedBox(height: UiSpace.s8),
              Wrap(
                spacing: UiSpace.s8,
                runSpacing: UiSpace.s8,
                children: [
                  for (final preset in tagColorPresets) ...[
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = preset['color'] as int;
                        });
                      },
                      child: Container(
                        width: UiSpace.s28,
                        height: UiSpace.s28,
                        decoration: BoxDecoration(
                          color: Palette.stored(preset['color'] as int),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == preset['color']
                                ? Palette.onAccent
                                : Palette.transparent,
                            width: UiSpace.s2_5,
                          ),
                          boxShadow: selectedColor == preset['color']
                              ? [
                                  BoxShadow(
                                    color: skin.shadow,
                                    blurRadius: UiSpace.s4,
                                  ),
                                ]
                              : null,
                        ),
                        child: selectedColor == preset['color']
                            ? const Icon(
                                AppIcons.checkMark,
                                size: UiSpace.s14,
                                color: Palette.onAccent,
                              )
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: skin.muted),
              child: Text(ctx.l10n.cancel),
            ),
            const SizedBox(width: UiSpace.s8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.accent,
                foregroundColor: Palette.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UiRadius.control),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s16,
                  vertical: UiSpace.s8,
                ),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  List<dynamic> existingOptions = [];
                  if (column.options != null && column.options!.isNotEmpty) {
                    try {
                      existingOptions =
                          jsonDecode(column.options!) as List<dynamic>;
                    } catch (_) {}
                  }
                  final newId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
                  existingOptions.add({
                    'id': newId,
                    'label': name,
                    'color':
                        '0x${selectedColor.toRadixString(16).toUpperCase()}',
                  });
                  await repository.updateColumn(
                    column.id,
                    options: jsonEncode(existingOptions),
                  );
                  onUpdateValue(newId);
                }
              },
              child: Text(ctx.l10n.createTag),
            ),
          ],
        );
      },
    ),
  );
}

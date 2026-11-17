import '../../../common/app_dialog.dart';
import 'database_grid_navigation.dart';
import '../../../../services/database_cell_saves.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';

import 'expanded_cell_editor.dart';
import '../../../common/app_icons.dart';
export 'database_number_cell.dart';
export 'database_row_view.dart';
export 'database_url_cell.dart';

import 'dart:convert';

import 'package:flutter/material.dart' hide Page, DataCell;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/menu.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/common/spring_motion.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_dialogs.dart';
import 'database_number_cell.dart';
import 'database_url_cell.dart';

/// Cell callbacks are synchronous, so report failed asynchronous patches here.
Future<void> patchRowPropertiesFromCell(
  BuildContext context,
  NotesRepository repository,
  String pageId,
  Map<String, dynamic> changes,
) async {
  try {
    await repository.patchRowProperties(pageId, changes);
  } catch (_) {
    if (!context.mounted) return;
    final skin = context.skin;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: skin.card,
        content: Text(
          context.l10n.cellCouldNotSave,
          style: TextStyle(color: skin.text),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Individual Data Cell
// ----------------------------------------------------------------------------

class DataCell extends StatefulWidget {
  final DatabaseCellSaves? saves;
  final String? rowId;
  final EdgeInsetsGeometry contentPadding;
  final DatabaseColumn column;
  final double width;
  final Color borderColor;
  final String pageTitle;
  final dynamic cellValue;
  final NotesRepository repository;
  final ValueChanged<String> onUpdateTitle;
  final ValueChanged<dynamic> onUpdateValue;
  final VoidCallback onOpenPage;

  const DataCell({
    super.key,
    this.saves,
    this.rowId,
    required this.column,
    required this.width,
    required this.borderColor,
    required this.pageTitle,
    required this.cellValue,
    required this.repository,
    required this.onUpdateTitle,
    required this.onUpdateValue,
    required this.onOpenPage,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: UiSpace.s8),
  });

  @override
  State<DataCell> createState() => _DataCellState();
}

class _DataCellState extends State<DataCell> {
  final _editor = DatabaseCellEditor();
  final _frameKey = GlobalKey();
  DatabaseGridNavigation? _grid;
  (String, String)? _registered;

  void _registerGrid() {
    final next = widget.rowId == null
        ? null
        : (widget.rowId!, widget.column.id);
    if (_registered != null &&
        identical(_grid?.editors[_registered], _editor)) {
      _grid?.editors.remove(_registered);
    }
    _registered = next;
    if (next != null) _grid?.editors[next] = _editor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registered != null &&
        identical(_grid?.editors[_registered], _editor)) {
      _grid?.editors.remove(_registered);
    }
    _grid = DatabaseGridScope.maybeOf(context);
    _registerGrid();
  }

  @override
  void didUpdateWidget(DataCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowId != widget.rowId ||
        oldWidget.column.id != widget.column.id) {
      _registerGrid();
    }
  }

  CellSaveKey get _saveKey => (
    databaseId: widget.column.databaseId,
    rowId: widget.rowId!,
    columnId: widget.column.id,
    title: widget.column.type == 'title',
  );
  CellSaveEntry? get _saveEntry {
    final entry = widget.saves?.entry(_saveKey);
    if (entry != null) {
      entry.columnLabel = widget.column.name;
      entry.columnType = widget.column.type;
      entry.columnOptions = widget.column.options;
      entry.rowLabel = widget.pageTitle;
    }
    return entry;
  }

  dynamic get _value {
    final remote = widget.column.type == 'title'
        ? widget.pageTitle
        : widget.cellValue;
    return _saveEntry == null ? remote : _saveEntry!.display(remote);
  }

  void _editingChanged(bool value) {
    if (mounted) widget.saves?.editingChanged(_saveKey, value);
  }

  void _updateValue(dynamic value) {
    if (!mounted) return;
    if (widget.saves != null) {
      widget.saves!.submit(_saveKey, value);
    } else {
      widget.onUpdateValue(value);
    }
  }

  void _updateTitle(String value) {
    if (!mounted) return;
    if (widget.saves != null) {
      widget.saves!.submit(_saveKey, value);
    } else {
      widget.onUpdateTitle(value);
    }
  }

  bool _cellHovered = false;
  bool _cellFocused = false;
  String? _optionsJson;
  List<dynamic> _options = const [];

  @override
  void dispose() {
    if (_registered != null &&
        identical(_grid?.editors[_registered], _editor)) {
      _grid?.editors.remove(_registered);
    }
    _editingChanged(false);
    widget.saves?.release(_saveKey);
    super.dispose();
  }

  List<dynamic> get _columnOptions {
    if (_optionsJson != widget.column.options) {
      _optionsJson = widget.column.options;
      try {
        final decoded = _optionsJson == null ? null : jsonDecode(_optionsJson!);
        _options = decoded is List ? decoded : const [];
      } catch (_) {
        _options = const [];
      }
    }
    return _options;
  }

  void _openTagPicker(BuildContext ctx, List<dynamic> options) {
    if (HardwareKeyboard.instance.isShiftPressed) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    final selectedId = _value?.toString() ?? '';

    _editingChanged(true);
    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.cellMenuWidth,
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final opt in options)
            MenuRow(
              label: opt['label'].toString(),
              icon: Container(
                width: UiSpace.s9,
                height: UiSpace.s9,
                decoration: BoxDecoration(
                  color: Palette.stored(
                    int.tryParse(opt['color'].toString()) ??
                        Palette.defaultTagArgb,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              selected: opt['id'].toString() == selectedId,
              onTap: () {
                close();
                _updateValue(opt['id'].toString());
              },
            ),
          if (selectedId.isNotEmpty) ...[
            const MenuDivider(),
            MenuRow(
              label: context.l10n.cellClearSelection,
              glyph: AppIcons.xmark,
              onTap: () {
                close();
                _updateValue('');
              },
            ),
          ],
          const MenuDivider(),
          MenuRow(
            label: context.l10n.cellNewTag,
            glyph: AppIcons.plus,
            onTap: () {
              close();
              showAddTagDialog(
                context: context,
                column: widget.column,
                repository: widget.repository,
                onUpdateValue: _updateValue,
              );
            },
          ),
        ],
      ),
    ).whenComplete(() => _editingChanged(false));
  }

  void _openStatusPicker(BuildContext ctx, List<dynamic> options) {
    if (HardwareKeyboard.instance.isShiftPressed) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    final selectedId = _value?.toString() ?? '';

    _editingChanged(true);
    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.cellMenuWidth,
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final opt in options)
            MenuRow(
              label: opt['label'].toString(),
              icon: Container(
                width: UiSpace.s9,
                height: UiSpace.s9,
                decoration: BoxDecoration(
                  color: Palette.stored(
                    int.tryParse(opt['color'].toString()) ??
                        Palette.defaultTagArgb,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              selected: opt['id'].toString() == selectedId,
              onTap: () {
                close();
                _updateValue(opt['id'].toString());
              },
            ),
          if (selectedId.isNotEmpty) ...[
            const MenuDivider(),
            MenuRow(
              label: context.l10n.cellClearSelection,
              glyph: AppIcons.xmark,
              onTap: () {
                close();
                _updateValue('');
              },
            ),
          ],
          const MenuDivider(),
          MenuRow(
            label: context.l10n.cellNewStatus,
            glyph: AppIcons.plus,
            onTap: () {
              close();
              showAddTagDialog(
                context: context,
                column: widget.column,
                repository: widget.repository,
                onUpdateValue: _updateValue,
                title: context.l10n.cellNewStatus,
              );
            },
          ),
        ],
      ),
    ).whenComplete(() => _editingChanged(false));
  }

  void _openMultiSelectPicker(BuildContext ctx, List<dynamic> options) {
    if (HardwareKeyboard.instance.isShiftPressed) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    List<String> currentSelected = [];
    if (_value is List) {
      currentSelected = (_value as List).map((e) => e.toString()).toList();
    } else if (_value != null && _value.toString().isNotEmpty) {
      final str = _value.toString();
      if (str.startsWith('[')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            currentSelected = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          currentSelected = [str];
        }
      } else {
        currentSelected = [str];
      }
    }

    _editingChanged(true);
    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.cellMenuWidth,
      builder: (context, close) => StatefulBuilder(
        builder: (context, setPickerState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final opt in options) ...[
              Builder(
                builder: (ctx) {
                  final optId = opt['id'].toString();
                  final isSelected = currentSelected.contains(optId);
                  return MenuRow(
                    label: opt['label'].toString(),
                    icon: Container(
                      width: UiSpace.s9,
                      height: UiSpace.s9,
                      decoration: BoxDecoration(
                        color: Palette.stored(
                          int.tryParse(opt['color'].toString()) ??
                              Palette.defaultTagArgb,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            AppIcons.checkMark,
                            size: UiSpace.s14,
                            color: Palette.accent,
                          )
                        : null,
                    onTap: () {
                      if (isSelected) {
                        currentSelected.remove(optId);
                      } else {
                        currentSelected.add(optId);
                      }
                      setPickerState(() {});
                      _updateValue(List<String>.from(currentSelected));
                    },
                  );
                },
              ),
            ],
            if (currentSelected.isNotEmpty) ...[
              const MenuDivider(),
              MenuRow(
                label: context.l10n.cellClearSelection,
                glyph: AppIcons.xmark,
                onTap: () {
                  currentSelected.clear();
                  setPickerState(() {});
                  _updateValue(<String>[]);
                },
              ),
            ],
            const MenuDivider(),
            MenuRow(
              label: context.l10n.cellNewTag,
              glyph: AppIcons.plus,
              onTap: () {
                close();
                showAddTagDialog(
                  context: context,
                  column: widget.column,
                  repository: widget.repository,
                  onUpdateValue: (newId) {
                    final updated = List<String>.from(currentSelected)
                      ..add(newId.toString());
                    _updateValue(updated);
                  },
                );
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() => _editingChanged(false));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.saves == null) return _withGridFocus(_buildTrackedCell(context));
    return ListenableBuilder(
      listenable: _saveEntry!,
      builder: (context, _) => _withGridFocus(_buildTrackedCell(context)),
    );
  }

  Widget _withGridFocus(Widget child) => Focus(
    canRequestFocus: false,
    onFocusChange: (focused) {
      if (focused && widget.rowId != null) {
        _grid?.activate(widget.rowId!, widget.column.id);
      }
    },
    child: child,
  );

  Widget _buildTrackedCell(BuildContext context) {
    _editor.anchorContext = () => _frameKey.currentContext;
    final skin = context.skin;
    final thinBorderColor = widget.borderColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _cellHovered = true),
      onExit: (_) => setState(() => _cellHovered = false),
      child: Container(
        key: _frameKey,
        width: widget.width,
        height: DesktopUx.databaseRowHeight,
        foregroundDecoration:
            (_saveEntry?.phase == CellSavePhase.invalid ||
                _saveEntry?.phase == CellSavePhase.failed ||
                _saveEntry?.phase == CellSavePhase.conflict)
            ? BoxDecoration(border: Border.all(color: skin.destructive))
            : null,
        decoration: BoxDecoration(
          border: Border(
            right: widget.borderColor == Palette.transparent
                ? BorderSide.none
                : BorderSide(color: thinBorderColor, width: UiSpace.s0_8),
          ),
        ),
        padding: widget.contentPadding,
        alignment: Alignment.centerLeft,
        child: _buildCellContent(context, skin),
      ),
    );
  }

  Widget _buildCellContent(BuildContext context, Skin skin) {
    _editor.open = null;
    _editor.cancel = null;
    if (widget.column.type == 'title') {
      return TitleCellInput(
        editor: _editor,
        onEditingChanged: widget.saves == null ? null : _editingChanged,
        initialValue: _value?.toString() ?? '',
        isCellHovered: _cellHovered,
        onChanged: _updateTitle,
      );
    }

    if (widget.column.type == 'checkbox') {
      final isChecked = _value == true || _value == 'true' || _value == 1;
      _editor.open = () => _updateValue(!isChecked);
      return _DatabaseCheckbox(
        value: isChecked,
        onChanged: (val) {
          if (HardwareKeyboard.instance.isShiftPressed) return;
          _updateValue(val);
          _grid?.focus();
        },
      );
    }

    if (widget.column.type == 'date') {
      final dateStr = _value?.toString() ?? '';

      Future<void> pickDate() async {
        final now = DateTime.now();
        DateTime initial = now;
        if (dateStr.isNotEmpty) {
          initial = DateTime.tryParse(dateStr) ?? now;
        }
        _editingChanged(true);
        final picked = await showAppDialog<DateTime>(
          context: context,
          animationStyle: Motion.dialogStyle(context),
          barrierColor: context.skin.scrim,
          builder: (context) => DatePickerDialog(
            initialDate: initial,
            firstDate: DateTime(1970),
            lastDate: DateTime(2100),
          ),
        );
        if (picked != null) {
          final formatted =
              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          _updateValue(formatted);
        }
        _editingChanged(false);

        if (mounted) _grid?.focus();
      }

      _editor.open = pickDate;
      return InkWell(
        key: ValueKey('date_cell_${widget.column.id}'),
        onTap: () {
          if (!HardwareKeyboard.instance.isShiftPressed) pickDate();
        },
        child: Container(
          alignment: Alignment.centerLeft,
          child: (_cellHovered || dateStr.isNotEmpty)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: UiSpace.s14,
                      color: dateStr.isNotEmpty ? skin.muted : skin.hint,
                    ),
                    const SizedBox(width: UiSpace.s5),
                    Flexible(
                      child: Text(
                        dateStr.isNotEmpty ? dateStr : 'Date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: UiType.body,
                          color: dateStr.isNotEmpty ? skin.text : skin.hint,
                          fontFeatures: UiType.tabular,
                        ),
                      ),
                    ),
                    if (dateStr.isNotEmpty && _cellHovered) ...[
                      const SizedBox(width: UiSpace.s4),
                      InkWell(
                        onTap: () => _updateValue(''),
                        child: Icon(
                          AppIcons.xmark,
                          size: UiSpace.s14,
                          color: skin.muted,
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    if (widget.column.type == 'select') {
      final selectedId = _value?.toString() ?? '';
      final options = _columnOptions;

      final activeOption = options.firstWhere(
        (o) => o['id'] == selectedId,
        orElse: () => null,
      );

      final label =
          activeOption?['label']?.toString() ??
          (selectedId.isNotEmpty ? selectedId : '');
      final colorHex = activeOption?['color'] ?? Palette.defaultTagArgb;
      final tagColor = Palette.stored(
        int.tryParse(colorHex.toString()) ?? Palette.defaultTagArgb,
      );

      return Builder(
        builder: (tagCtx) {
          _editor.open = () => _openTagPicker(tagCtx, options);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              key: ValueKey('select_cell_${widget.column.id}'),
              onFocusChange: (focused) =>
                  setState(() => _cellFocused = focused),
              onTap: () => _openTagPicker(tagCtx, options),
              child: Container(
                alignment: Alignment.centerLeft,
                child: label.isNotEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiSpace.s7,
                            vertical: UiSpace.s2_5,
                          ),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              UiRadius.compact,
                            ),
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: UiType.body,
                              fontWeight: FontWeight.w600,
                              color: tagColor,
                            ),
                          ),
                        ),
                      )
                    : (_cellHovered || _cellFocused
                          ? Text(
                              '+ Tag',
                              style: TextStyle(
                                fontSize: UiType.body,
                                color: skin.hint,
                              ),
                            )
                          : const SizedBox.shrink()),
              ),
            ),
          );
        },
      );
    }

    if (widget.column.type == 'status') {
      final selectedId = _value?.toString() ?? '';
      final options = _columnOptions.isNotEmpty
          ? _columnOptions
          : [
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
            ];

      final activeOption = options.firstWhere(
        (o) => o['id'] == selectedId,
        orElse: () => null,
      );

      final label =
          activeOption?['label']?.toString() ??
          (selectedId.isNotEmpty ? selectedId : '');
      final colorHex = activeOption?['color'] ?? '0xFF9E9E9E';
      final statusColor = Palette.stored(
        int.tryParse(colorHex.toString()) ?? 0xFF9E9E9E,
      );

      return Builder(
        builder: (statusCtx) {
          _editor.open = () => _openStatusPicker(statusCtx, options);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              key: ValueKey('status_cell_${widget.column.id}'),
              onFocusChange: (focused) =>
                  setState(() => _cellFocused = focused),
              onTap: () => _openStatusPicker(statusCtx, options),
              child: Container(
                alignment: Alignment.centerLeft,
                child: label.isNotEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiSpace.s8,
                            vertical: UiSpace.s2_5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              UiRadius.action,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: UiSpace.s7,
                                height: UiSpace.s7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: UiSpace.s6),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: UiType.body,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (_cellHovered || _cellFocused
                          ? Text(
                              context.l10n.cellAddStatus,
                              style: TextStyle(
                                fontSize: UiType.body,
                                color: skin.hint,
                              ),
                            )
                          : const SizedBox.shrink()),
              ),
            ),
          );
        },
      );
    }

    if (widget.column.type == 'multi_select') {
      final options = _columnOptions;
      List<String> selectedIds = [];
      if (_value is List) {
        selectedIds = (_value as List).map((e) => e.toString()).toList();
      } else if (_value != null && _value.toString().isNotEmpty) {
        final str = _value.toString();
        if (str.startsWith('[')) {
          try {
            final decoded = jsonDecode(str);
            if (decoded is List) {
              selectedIds = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {
            selectedIds = [str];
          }
        } else {
          selectedIds = [str];
        }
      }

      final activeOptions = <Map<String, dynamic>>[];
      for (final id in selectedIds) {
        final opt = options.firstWhere(
          (o) => o['id'].toString() == id,
          orElse: () => {
            'id': id,
            'label': id,
            'color': Palette.defaultTagArgb,
          },
        );
        activeOptions.add(Map<String, dynamic>.from(opt));
      }

      return Builder(
        builder: (tagCtx) {
          _editor.open = () => _openMultiSelectPicker(tagCtx, options);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              key: ValueKey('multi_select_cell_${widget.column.id}'),
              onFocusChange: (focused) =>
                  setState(() => _cellFocused = focused),
              onTap: () => _openMultiSelectPicker(tagCtx, options),
              child: Container(
                alignment: Alignment.centerLeft,
                child: activeOptions.isNotEmpty
                    ? Tooltip(
                        message: activeOptions
                            .map((o) => o['label']?.toString() ?? '')
                            .where((l) => l.isNotEmpty)
                            .join(', '),
                        waitDuration: const Duration(milliseconds: 500),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final opt in activeOptions) ...[
                                Builder(
                                  builder: (ctx) {
                                    final label = opt['label']?.toString() ?? '';
                                    final colorHex = opt['color'] ??
                                        Palette.defaultTagArgb;
                                    final tagColor = Palette.stored(
                                      int.tryParse(colorHex.toString()) ??
                                          Palette.defaultTagArgb,
                                    );
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        right: UiSpace.s4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: UiSpace.s6,
                                        vertical: UiSpace.s2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tagColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          UiRadius.compact,
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: UiType.caption,
                                          fontWeight: FontWeight.w600,
                                          color: tagColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : (_cellHovered || _cellFocused
                          ? Text(
                              context.l10n.cellAddMultiSelect,
                              style: TextStyle(
                                fontSize: UiType.body,
                                color: skin.hint,
                              ),
                            )
                          : const SizedBox.shrink()),
              ),
            ),
          );
        },
      );
    }

    if (widget.column.type == 'url') {
      return UrlCellInput(
        editor: _editor,
        onEditingChanged: widget.saves == null ? null : _editingChanged,
        initialValue: _value?.toString() ?? '',
        isCellHovered: _cellHovered,
        onChanged: (val) => _updateValue(val),
      );
    }

    if (widget.column.type == 'number') {
      return DatabaseNumberCell(
        editor: _editor,
        onEditingChanged: widget.saves == null ? null : _editingChanged,
        key: ValueKey('number_cell_${widget.column.id}'),
        column: widget.column,
        cellValue: _value,
        isCellHovered: _cellHovered,
        onChanged: _updateValue,
      );
    }

    // Default: text or number field
    return InlineCellInput(
      editor: _editor,
      onEditingChanged: widget.saves == null ? null : _editingChanged,
      initialValue: _value?.toString() ?? '',
      isNumber: false,
      isCellHovered: _cellHovered,
      onChanged: _updateValue,
    );
  }
}

// ----------------------------------------------------------------------------
// Custom Rounded Checkbox
// ----------------------------------------------------------------------------

class _DatabaseCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DatabaseCheckbox({required this.value, required this.onChanged});

  @override
  State<_DatabaseCheckbox> createState() => _DatabaseCheckboxState();
}

class _DatabaseCheckboxState extends State<_DatabaseCheckbox> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    Widget buildCheckbox() => MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        key: const ValueKey('database_checkbox'),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => widget.onChanged(!widget.value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: UiSpace.s16,
          height: UiSpace.s16,
          decoration: BoxDecoration(
            color: widget.value ? Palette.accent : Palette.transparent,
            borderRadius: BorderRadius.circular(UiRadius.action),
            border: Border.all(
              color: widget.value
                  ? Palette.accent
                  : (_hover
                        ? Palette.accent.withValues(alpha: 0.8)
                        : skin.controlBorder),
              width: UiSpace.s1_3,
            ),
          ),
          alignment: Alignment.center,
          child: widget.value
              ? const Icon(
                  AppIcons.checkMark,
                  size: UiSpace.s14,
                  color: Palette.onAccent,
                )
              : null,
        ),
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: buildCheckbox(),
      );
    }

    return SpringValue(
      value: _pressed ? 0.92 : 1.0,
      spring: Motion.spatialSpring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: buildCheckbox(),
    );
  }
}

// ----------------------------------------------------------------------------
// Title Cell
// ----------------------------------------------------------------------------

class TitleCellInput extends StatefulWidget {
  final DatabaseCellEditor? editor;
  final ValueChanged<bool>? onEditingChanged;
  final String initialValue;
  final bool isCellHovered;
  final ValueChanged<String> onChanged;

  const TitleCellInput({
    this.editor,
    super.key,
    this.onEditingChanged,
    required this.initialValue,
    this.isCellHovered = false,
    required this.onChanged,
  });

  @override
  State<TitleCellInput> createState() => _TitleCellInputState();
}

class _TitleCellInputState extends State<TitleCellInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String _lastSubmittedValue = '';
  String? _deferredTitle;
  bool _editedWhileFocused = false;
  bool _overlayOpen = false;
  bool _suppressReturnFocus = false;
  VoidCallback? _closeEditor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSubmittedValue = widget.initialValue;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (_suppressReturnFocus) {
        _suppressReturnFocus = false;
      } else {
        widget.onEditingChanged?.call(true);
      }
    }
    if (_overlayOpen) return;
    if (_focusNode.hasFocus) {
      _editedWhileFocused = false;
    } else if (!_editedWhileFocused && _deferredTitle != null) {
      _controller.text = _deferredTitle!;
      _lastSubmittedValue = _deferredTitle!;
      _deferredTitle = null;
    } else {
      final force = _editedWhileFocused && _deferredTitle != null;
      _deferredTitle = null;
      _commit(force: force);
    }
    if (!_focusNode.hasFocus) {
      _controller.selection = const TextSelection.collapsed(offset: 0);
    }
    setState(() {});
    if (!_focusNode.hasFocus) widget.onEditingChanged?.call(false);
  }

  void _commit({bool force = false}) {
    final text = _controller.text;
    if (force || text != _lastSubmittedValue) {
      _lastSubmittedValue = text;
      _deferredTitle = null;
      widget.onChanged(text);
    }
  }

  @override
  void didUpdateWidget(TitleCellInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      if ((_focusNode.hasFocus || _overlayOpen) &&
          !(widget.onEditingChanged != null &&
              !_overlayOpen &&
              !_editedWhileFocused)) {
        _deferredTitle = widget.initialValue == _controller.text
            ? null
            : widget.initialValue;
      } else {
        _controller.text = widget.initialValue;
        _lastSubmittedValue = widget.initialValue;
      }
    }
  }

  @override
  void dispose() {
    _closeEditor?.call();
    _commit(force: _editedWhileFocused && _deferredTitle != null);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    Future<void> expand() async {
      if (_overlayOpen || HardwareKeyboard.instance.isShiftPressed) return;
      _overlayOpen = true;
      _suppressReturnFocus = false;
      widget.onEditingChanged?.call(true);
      await showExpandedCellEditor(
        context,
        _controller.text,
        anchorContext: widget.editor?.anchorContext?.call(),
        title: true,
        onCloseReady: (close) => _closeEditor = close,
        onSave: (value) {
          _controller.text = value;
          _editedWhileFocused = true;
          _commit(force: _deferredTitle != null);
        },
      );
      if (!mounted) return;
      _closeEditor = null;
      _overlayOpen = false;
      _suppressReturnFocus = true;
      if (!_editedWhileFocused && _deferredTitle != null) {
        _controller.text = _deferredTitle!;
        _lastSubmittedValue = _deferredTitle!;
        _deferredTitle = null;
      }
      _onFocusChange();
      widget.onEditingChanged?.call(false);
    }

    widget.editor?.open = expand;
    return TextField(
      onTap: expand,
      controller: _controller,
      focusNode: _focusNode,
      selectAllOnFocus: false,
      style: TextStyle(
        fontSize: UiType.editorTitle,
        fontWeight: FontWeight.w600,
        height: UiType.editorLineHeight,
        color: skin.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: (_focusNode.hasFocus || widget.isCellHovered || _controller.text.isEmpty)
            ? context.l10n.cellUntitledPage
            : null,
        hintStyle: TextStyle(
          color: (_focusNode.hasFocus || widget.isCellHovered)
              ? skin.hint
              : skin.hint.withValues(alpha: 0.45),
          fontSize: UiType.editorTitle,
        ),
      ),
      onChanged: (_) => _editedWhileFocused = true,
      onSubmitted: (_) => _commit(),
    );
  }
}

class InlineCellInput extends StatefulWidget {
  final DatabaseCellEditor? editor;
  final ValueChanged<bool>? onEditingChanged;
  final String initialValue;
  final bool isNumber;
  final bool isCellHovered;
  final ValueChanged<dynamic> onChanged;

  const InlineCellInput({
    this.editor,
    super.key,
    this.onEditingChanged,
    required this.initialValue,
    this.isNumber = false,
    this.isCellHovered = false,
    required this.onChanged,
  });

  @override
  State<InlineCellInput> createState() => _InlineCellInputState();
}

class _InlineCellInputState extends State<InlineCellInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  dynamic _lastSubmittedValue;
  bool _overlayOpen = false;
  bool _suppressReturnFocus = false;
  VoidCallback? _closeEditor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSubmittedValue = widget.isNumber
        ? (num.tryParse(widget.initialValue.trim()) ??
              (widget.initialValue.trim().isEmpty ? null : widget.initialValue))
        : widget.initialValue;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (_suppressReturnFocus) {
        _suppressReturnFocus = false;
      } else {
        widget.onEditingChanged?.call(true);
      }
    }
    if (_overlayOpen) return;
    if (!_focusNode.hasFocus) {
      _commit();
    }
    if (!_focusNode.hasFocus) {
      _controller.selection = const TextSelection.collapsed(offset: 0);
    }
    setState(() {});
    if (!_focusNode.hasFocus) widget.onEditingChanged?.call(false);
  }

  void _commit() {
    final raw = _controller.text;
    final dynamic val;
    if (widget.isNumber) {
      final trimmed = raw.trim();
      val = trimmed.isEmpty ? null : (num.tryParse(trimmed) ?? trimmed);
    } else {
      val = raw;
    }

    if (val != _lastSubmittedValue) {
      _lastSubmittedValue = val;
      widget.onChanged(val);
    }
  }

  @override
  void didUpdateWidget(InlineCellInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        (!_focusNode.hasFocus ||
            (widget.onEditingChanged != null &&
                _controller.text == _lastSubmittedValue?.toString())) &&
        !_overlayOpen) {
      _controller.text = widget.initialValue;
      _lastSubmittedValue = widget.isNumber
          ? (num.tryParse(widget.initialValue.trim()) ??
                (widget.initialValue.trim().isEmpty
                    ? null
                    : widget.initialValue))
          : widget.initialValue;
    }
  }

  @override
  void dispose() {
    _closeEditor?.call();
    _commit();
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    Future<void> expand() async {
      if (_overlayOpen || HardwareKeyboard.instance.isShiftPressed) return;
      _overlayOpen = true;
      _suppressReturnFocus = false;
      widget.onEditingChanged?.call(true);
      await showExpandedCellEditor(
        context,
        _controller.text,
        anchorContext: widget.editor?.anchorContext?.call(),
        title: false,
        onCloseReady: (close) => _closeEditor = close,
        onSave: (value) {
          _controller.text = value;

          _commit();
        },
      );
      if (!mounted) return;
      _closeEditor = null;
      _overlayOpen = false;
      _suppressReturnFocus = true;
      _onFocusChange();
      widget.onEditingChanged?.call(false);
    }

    widget.editor?.open = expand;
    final textField = TextField(
      onTap: expand,
      controller: _controller,
      focusNode: _focusNode,
      selectAllOnFocus: false,
      keyboardType: widget.isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        fontSize: UiType.body,
        fontWeight: FontWeight.w400,
        color: skin.text,
        fontFeatures: widget.isNumber ? UiType.tabular : null,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: (_focusNode.hasFocus || widget.isCellHovered)
            ? (widget.isNumber ? '0' : context.l10n.cellTypeText)
            : null,
        hintStyle: TextStyle(
          color: skin.hint.withValues(alpha: 0.7),
          fontSize: UiType.body,
        ),
      ),
      onSubmitted: (_) => _commit(),
    );

    if (!_focusNode.hasFocus && _controller.text.trim().isNotEmpty) {
      return Tooltip(
        message: _controller.text,
        waitDuration: const Duration(milliseconds: 600),
        child: textField,
      );
    }
    return textField;
  }
}

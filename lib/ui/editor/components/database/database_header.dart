import '../../../common/app_icons.dart';

import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/menu.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_dialogs.dart';
import 'database_models.dart';

// ----------------------------------------------------------------------------
// Database Header Widget & Actions
// ----------------------------------------------------------------------------

class DatabaseHeader extends StatefulWidget {
  final String title;
  final int totalRowCount;
  final int filteredRowCount;
  final List<DatabaseColumn> columns;
  final DatabaseSortConfig? sortConfig;
  final List<DatabaseFilterRule> filterRules;
  final String searchQuery;
  final void Function(String? colId, bool ascending) onSortChanged;
  final ValueChanged<DatabaseFilterRule> onAddFilter;
  final ValueChanged<String> onRemoveFilter;
  final VoidCallback onClearFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddRow;
  final VoidCallback? onAddColumn;
  final ValueChanged<String> onTitleChanged;

  const DatabaseHeader({
    super.key,
    required this.title,
    required this.totalRowCount,
    required this.filteredRowCount,
    required this.columns,
    this.sortConfig,
    required this.filterRules,
    required this.searchQuery,
    required this.onSortChanged,
    required this.onAddFilter,
    required this.onRemoveFilter,
    required this.onClearFilters,
    required this.onSearchChanged,
    required this.onAddRow,
    this.onAddColumn,
    required this.onTitleChanged,
  });

  @override
  State<DatabaseHeader> createState() => _DatabaseHeaderState();
}

class _DatabaseHeaderState extends State<DatabaseHeader> {
  late final TextEditingController _titleController;
  final FocusNode _focusNode = FocusNode();
  String _lastCommittedTitle = '';
  String? _deferredTitle;
  bool _editedWhileFocused = false;
  bool _isSearchOpen = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _lastCommittedTitle = widget.title;
    _focusNode.addListener(_onTitleFocusChange);
    _searchController = TextEditingController(text: widget.searchQuery);
    _isSearchOpen = widget.searchQuery.isNotEmpty;
  }

  void _onTitleFocusChange() {
    if (_focusNode.hasFocus) {
      _editedWhileFocused = false;
    } else if (!_editedWhileFocused && _deferredTitle != null) {
      _titleController.text = _deferredTitle!;
      _lastCommittedTitle = _deferredTitle!;
      _deferredTitle = null;
    } else {
      final force = _editedWhileFocused && _deferredTitle != null;
      _deferredTitle = null;
      _commitTitle(force: force);
    }
    setState(() {});
  }

  void _commitTitle({bool force = false}) {
    final text = _titleController.text.trim();
    if (text.isNotEmpty && (force || text != _lastCommittedTitle)) {
      _lastCommittedTitle = text;
      _deferredTitle = null;
      widget.onTitleChanged(text);
    }
  }

  @override
  void didUpdateWidget(DatabaseHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      if (_focusNode.hasFocus) {
        _deferredTitle = widget.title == _titleController.text
            ? null
            : widget.title;
      } else {
        _titleController.text = widget.title;
        _lastCommittedTitle = widget.title;
      }
    }
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _commitTitle(force: _editedWhileFocused && _deferredTitle != null);
    _focusNode.removeListener(_onTitleFocusChange);
    _titleController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openSortMenu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.databaseMenuWidth,
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in widget.columns)
            MenuRow(
              label: col.name,
              icon: Icon(
                iconForColumnType(col.type),
                size: UiSpace.s14,
                color: widget.sortConfig?.columnId == col.id
                    ? Palette.accent
                    : null,
              ),
              selected: widget.sortConfig?.columnId == col.id,
              onTap: () {
                close();
                final isCurrent = widget.sortConfig?.columnId == col.id;
                widget.onSortChanged(
                  col.id,
                  isCurrent ? !widget.sortConfig!.ascending : true,
                );
              },
            ),
          if (widget.sortConfig != null) ...[
            const MenuDivider(),
            MenuRow(
              label: widget.sortConfig!.ascending
                  ? context.l10n.databaseSortDescending
                  : context.l10n.databaseSortAscending,
              glyph: widget.sortConfig!.ascending
                  ? AppIcons.arrowDown
                  : AppIcons.arrowUp,
              onTap: () {
                close();
                widget.onSortChanged(
                  widget.sortConfig!.columnId,
                  !widget.sortConfig!.ascending,
                );
              },
            ),
            MenuRow(
              label: context.l10n.databaseClearSort,
              glyph: AppIcons.xmark,
              onTap: () {
                close();
                widget.onSortChanged(null, true);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openCreationMenu(BuildContext anchorContext) {
    final box = anchorContext.findRenderObject() as RenderBox;
    showPopover(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      width: DesktopUx.menuMaxWidth,
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuRow(
            label: context.l10n.newPage,
            glyph: AppIcons.plus,
            onTap: () {
              close();
              widget.onAddRow();
            },
          ),
          if (widget.onAddColumn != null)
            MenuRow(
              label: context.l10n.databaseAddProperty,
              glyph: AppIcons.rectangleSplit3x1,
              onTap: () {
                close();
                widget.onAddColumn!();
              },
            ),
        ],
      ),
    );
  }

  void _openOptions(BuildContext anchorContext) {
    final box = anchorContext.findRenderObject() as RenderBox;
    showPopover(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      width: DesktopUx.menuMaxWidth,
      builder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuRow(
            label: context.l10n.databaseRename,
            glyph: AppIcons.pencil,
            onTap: () {
              close();
              _focusNode.requestFocus();
              _titleController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _titleController.text.length,
              );
            },
          ),
          MenuRow(
            label: context.l10n.databaseSearch,
            glyph: AppIcons.search,
            onTap: () {
              close();
              setState(() => _isSearchOpen = true);
            },
          ),
          if (widget.onAddColumn != null) ...[
            const MenuDivider(),
            MenuRow(
              label: context.l10n.databaseAddProperty,
              glyph: AppIcons.rectangleSplit3x1,
              onTap: () {
                close();
                widget.onAddColumn!();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openFilter() => showFilterDialog(
    context: context,
    columns: widget.columns,
    filterRules: widget.filterRules,
    onAddFilter: widget.onAddFilter,
    onRemoveFilter: widget.onRemoveFilter,
    onClearFilters: widget.onClearFilters,
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final sort = widget.sortConfig;
    final sortName = widget.columns
        .where((c) => c.id == sort?.columnId)
        .firstOrNull
        ?.name;
    final title = TextField(
      controller: _titleController,
      focusNode: _focusNode,
      style: TextStyle(
        fontSize: DesktopUx.databaseTitleSize,
        fontWeight: FontWeight.w600,
        color: skin.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: context.l10n.untitledDatabase,
        hintStyle: TextStyle(color: skin.hint),
      ),
      onChanged: (_) => _editedWhileFocused = true,
      onSubmitted: (_) => _commitTitle(),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeaderActionButton(
          icon: AppIcons.lineHorizontal3Decrease,
          label: '',
          tooltip: context.l10n.databaseFilter,
          isActive: widget.filterRules.isNotEmpty,
          onTap: _openFilter,
        ),
        Builder(
          builder: (ctx) => HeaderActionButton(
            icon: AppIcons.arrowUpArrowDown,
            label: '',
            tooltip: context.l10n.databaseSort,
            isActive: sort != null,
            onTap: () => _openSortMenu(ctx),
          ),
        ),
        HeaderActionButton(
          icon: AppIcons.search,
          label: '',
          tooltip: context.l10n.search,
          isActive: _isSearchOpen || widget.searchQuery.isNotEmpty,
          onTap: () => setState(
            () =>
                _isSearchOpen = !_isSearchOpen || widget.searchQuery.isNotEmpty,
          ),
        ),
        Builder(
          builder: (ctx) => HeaderActionButton(
            icon: AppIcons.ellipsis,
            label: '',
            tooltip: context.l10n.databaseOptions,
            onTap: () => _openOptions(ctx),
          ),
        ),
        const SizedBox(width: UiSpace.s8),
        ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: DesktopUx.databaseToolbarExtent,
                child: TextButton(
                  onPressed: widget.onAddRow,
                  style: TextButton.styleFrom(
                    foregroundColor: skin.accentText,
                    backgroundColor: skin.tablePrimaryTint,
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiSpace.s12,
                    ),
                    minimumSize: Size.zero,
                    shape: const RoundedRectangleBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.newRow,
                    style: const TextStyle(
                      fontSize: UiType.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (widget.onAddColumn != null) ...[
                SizedBox(
                  width: UiSpace.s1,
                  height: DesktopUx.databaseToolbarExtent,
                  child: ColoredBox(color: skin.tableControlActive),
                ),
                Builder(
                  builder: (ctx) => SizedBox.square(
                    dimension: DesktopUx.databaseToolbarExtent,
                    child: TextButton(
                      onPressed: () => _openCreationMenu(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: skin.accentText,
                        backgroundColor: skin.tablePrimaryTint,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        shape: const RoundedRectangleBorder(),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Tooltip(
                        message: context.l10n.databaseMoreCreationOptions,
                        child: const Icon(
                          AppIcons.chevronDown,
                          size: UiSpace.s16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: UiSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < DesktopUx.databaseNarrowToolbar
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      const SizedBox(height: UiSpace.s8),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: UiSpace.s24),
                      actions,
                    ],
                  ),
          ),
          if (_isSearchOpen)
            Padding(
              padding: const EdgeInsets.only(
                top: UiSpace.s10,
                bottom: UiSpace.s4,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontSize: UiType.body, color: skin.text),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: skin.hover,
                  hintText: context.l10n.databaseSearchPlaceholder,
                  prefixIcon: Icon(
                    AppIcons.search,
                    size: UiSpace.s16,
                    color: skin.muted,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: UiSpace.s32,
                  ),
                  suffixIcon: IconButton(
                    tooltip: context.l10n.databaseCloseSearch,
                    icon: const Icon(AppIcons.xmark, size: UiSpace.s16),
                    onPressed: () {
                      _searchController.clear();
                      widget.onSearchChanged('');
                      setState(() => _isSearchOpen = false);
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: UiSpace.s12,
                    vertical: UiSpace.s8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    borderSide: BorderSide(color: skin.hairlineBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    borderSide: const BorderSide(color: Palette.accent),
                  ),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
          if (widget.filterRules.isNotEmpty || sort != null)
            Padding(
              padding: const EdgeInsets.only(top: UiSpace.s8),
              child: Wrap(
                spacing: UiSpace.s6,
                runSpacing: UiSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.filterRules.isNotEmpty)
                    HeaderActionButton(
                      icon: AppIcons.lineHorizontal3Decrease,
                      label: context.l10n.databaseFilterCount(
                        widget.filterRules.length,
                      ),
                      isActive: true,
                      onTap: _openFilter,
                    ),
                  if (sort != null)
                    Builder(
                      builder: (ctx) => HeaderActionButton(
                        icon: AppIcons.arrowUpArrowDown,
                        label:
                            '${sortName ?? context.l10n.databaseSort} ${sort.ascending ? '↑' : '↓'}',
                        tooltip: context.l10n.databaseSort,
                        isActive: true,
                        onTap: () => _openSortMenu(ctx),
                      ),
                    ),
                  TextButton(
                    onPressed: () {
                      widget.onClearFilters();
                      widget.onSortChanged(null, true);
                    },
                    child: Text(
                      context.l10n.clear,
                      style: const TextStyle(fontSize: UiType.caption),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact desktop action with native keyboard activation and visible focus.
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.isActive = false,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool isActive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final button = TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(
            DesktopUx.databaseToolbarExtent,
            DesktopUx.databaseToolbarExtent,
          ),
        ),
        padding: WidgetStatePropertyAll(
          label.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: UiSpace.s8),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiRadius.action),
          ),
        ),
        foregroundColor: WidgetStatePropertyAll(
          isActive ? skin.accentText : skin.muted,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)
              ? skin.hover
              : isActive
              ? skin.tableControlActive
              : Palette.transparent,
        ),
        visualDensity: VisualDensity.standard,
        animationDuration: Motion.of(context, Motion.micro),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: UiSpace.s16),
          if (label.isNotEmpty) ...[
            const SizedBox(width: UiSpace.s6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: UiType.caption),
              ),
            ),
          ],
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

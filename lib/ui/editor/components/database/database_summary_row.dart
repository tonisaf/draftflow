import '../../../../data/model/numeric_cell_input.dart';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/menu.dart';
import 'package:notes_here/ui/common/popover.dart';
import 'package:notes_here/ui/theme.dart';

import 'database_models.dart';
import 'database_row_view.dart';
import 'database_sticky_pane.dart';

enum SummaryType {
  none,
  count,
  sum,
  average,
  min,
  max,
  range,
  checked,
  unchecked,
  percentChecked,
  empty,
  notEmpty,
  unique;

  static SummaryType fromId(String? id) {
    if (id == null) return SummaryType.none;
    for (final val in SummaryType.values) {
      if (val.name == id) return val;
    }
    return SummaryType.none;
  }
}

List<SummaryType> getAvailableSummariesForColumn(DatabaseColumn column) {
  switch (column.type) {
    case 'number':
      return const [
        SummaryType.none,
        SummaryType.sum,
        SummaryType.average,
        SummaryType.min,
        SummaryType.max,
        SummaryType.range,
        SummaryType.count,
      ];
    case 'checkbox':
      return const [
        SummaryType.none,
        SummaryType.checked,
        SummaryType.unchecked,
        SummaryType.percentChecked,
        SummaryType.count,
      ];
    case 'select':
    case 'multi_select':
    case 'status':
      return const [
        SummaryType.none,
        SummaryType.count,
        SummaryType.unique,
        SummaryType.empty,
        SummaryType.notEmpty,
      ];
    default:
      return const [
        SummaryType.none,
        SummaryType.count,
        SummaryType.unique,
        SummaryType.empty,
        SummaryType.notEmpty,
      ];
  }
}

String summaryTypeLabel(SummaryType type, BuildContext context) {
  switch (type) {
    case SummaryType.none:
      return context.l10n.calcNone;
    case SummaryType.sum:
      return context.l10n.calcSum;
    case SummaryType.average:
      return context.l10n.calcAverage;
    case SummaryType.min:
      return context.l10n.calcMin;
    case SummaryType.max:
      return context.l10n.calcMax;
    case SummaryType.range:
      return context.l10n.calcRange;
    case SummaryType.count:
      return context.l10n.calcCount;
    case SummaryType.checked:
      return context.l10n.calcChecked;
    case SummaryType.unchecked:
      return context.l10n.calcUnchecked;
    case SummaryType.percentChecked:
      return context.l10n.calcPercentChecked;
    case SummaryType.empty:
      return context.l10n.calcEmpty;
    case SummaryType.notEmpty:
      return context.l10n.calcNotEmpty;
    case SummaryType.unique:
      return context.l10n.calcUnique;
  }
}

class SummaryResult {
  final String label;
  final String value;

  const SummaryResult({this.label = '', required this.value});

  String get formatted => label.isEmpty ? value : '$label $value';

  @override
  String toString() => formatted;
}

class DatabaseSummaryStats {
  final int rows, nonEmpty, unique, checked, numericCount;
  final num sum;
  final num? min, max;
  const DatabaseSummaryStats(
    this.rows,
    this.nonEmpty,
    this.unique,
    this.checked,
    this.numericCount,
    this.sum,
    this.min,
    this.max,
  );
}

DatabaseSummaryStats summarizeDatabaseGroups(
  List<DatabaseValueGroup> groups, {
  String format = 'number',
}) {
  var rows = 0, nonEmpty = 0, checked = 0, numericCount = 0;
  num sum = 0;
  num? min, max;
  final unique = <String>{};
  for (final group in groups) {
    final value = group.value;
    rows += group.count;
    if (value == true || value == 'true' || value == 1) checked += group.count;
    if (value != null &&
        value.toString().trim().isNotEmpty &&
        value.toString().trim() != '[]') {
      nonEmpty += group.count;
      unique.add(value.toString().trim());
    }
    final number = parseNumericCellInput(value, format: format).value;
    if (number != null) {
      numericCount += group.count;
      sum += number * group.count;
      min = min == null || number < min ? number : min;
      max = max == null || number > max ? number : max;
    }
  }
  return DatabaseSummaryStats(
    rows,
    nonEmpty,
    unique.length,
    checked,
    numericCount,
    sum,
    min,
    max,
  );
}

Map<String, DatabaseSummaryStats> summarizeAllDatabaseGroups(
  Map<String, List<DatabaseValueGroup>> groups, {
  Map<String, String> formats = const {},
}) => groups.map(
  (id, values) => MapEntry(
    id,
    summarizeDatabaseGroups(values, format: formats[id] ?? 'number'),
  ),
);

Map<String, DatabaseSummaryStats> _computeStats(
  (Map<String, List<DatabaseValueGroup>>, Map<String, String>) input,
) => summarizeAllDatabaseGroups(input.$1, formats: input.$2);

Future<Map<String, DatabaseSummaryStats>> calculateDatabaseSummaryStats(
  Map<String, List<DatabaseValueGroup>> groups, {
  Map<String, String> formats = const {},
}) => compute(_computeStats, (groups, formats));

SummaryResult calculateSummaryResult({
  required SummaryType type,
  required DatabaseColumn column,
  required List<DatabaseRowData> rows,
  required BuildContext context,
  DatabaseSummaryStats? stats,
}) {
  if (type == SummaryType.none) return const SummaryResult(value: '');
  final config = NumberColumnConfig.fromOptions(column.options);
  final data =
      stats ??
      summarizeDatabaseGroups([
        for (final row in rows)
          DatabaseValueGroup(
            column.type == 'title' ? row.page.title : row.properties[column.id],
            1,
          ),
      ], format: config.format);
  String number(num value) =>
      !value.isFinite ||
          (config.format.startsWith('duration') &&
              value.abs() > 9007199254740991)
      ? context.l10n.numericTooLarge
      : formatNumberValue(value, config);
  final label = summaryTypeLabel(type, context);
  final String value;
  switch (type) {
    case SummaryType.none:
      value = '';
    case SummaryType.sum:
      value = number(data.sum);
    case SummaryType.average:
      if (data.numericCount == 0) {
        value = '-';
      } else {
        final average = data.sum / data.numericCount;
        value =
            !average.isFinite ||
                (config.format.startsWith('duration') &&
                    average.abs() > 9007199254740991)
            ? context.l10n.numericTooLarge
            : formatNumberValue(
                average,
                config.copyWith(
                  decimalPlaces: () =>
                      config.decimalPlaces ??
                      (average == average.truncateToDouble() ? 0 : 2),
                ),
              );
      }
    case SummaryType.min:
      value = data.min == null ? '-' : number(data.min!);
    case SummaryType.max:
      value = data.max == null ? '-' : number(data.max!);
    case SummaryType.range:
      value = data.min == null ? '-' : number(data.max! - data.min!);
    case SummaryType.count:
      value = '${data.nonEmpty}';
    case SummaryType.checked:
      value = '${data.checked}';
    case SummaryType.unchecked:
      value = '${data.rows - data.checked}';
    case SummaryType.percentChecked:
      return SummaryResult(
        value:
            '${data.rows == 0 ? 0 : (100 * data.checked / data.rows).round()}%',
      );
    case SummaryType.empty:
      value = '${data.rows - data.nonEmpty}';
    case SummaryType.notEmpty:
      value = '${data.nonEmpty}';
    case SummaryType.unique:
      value = '${data.unique}';
  }
  return SummaryResult(label: label, value: value);
}

String calculateSummary({
  required SummaryType type,
  required DatabaseColumn column,
  required List<DatabaseRowData> rows,
  required BuildContext context,
}) => calculateSummaryResult(
  type: type,
  column: column,
  rows: rows,
  context: context,
).formatted;

class TableSummaryRow extends StatelessWidget {
  final ScrollController? horizontalScrollController;
  final bool freezeTitle;
  final Map<String, DatabaseSummaryStats>? stats;
  final bool loading;
  final bool error;
  final VoidCallback? onAddRow;
  final List<DatabaseColumn> columns;
  final Map<String, double> columnWidths;
  final Color borderColor;
  final List<DatabaseRowData> rows;
  final Map<String, String> summaries;
  final void Function(String columnId, String? summaryType) onSummaryChanged;

  const TableSummaryRow({
    super.key,
    this.horizontalScrollController,
    this.freezeTitle = true,
    this.stats,
    this.loading = false,
    this.error = false,
    this.onAddRow,
    required this.columns,
    required this.columnWidths,
    required this.borderColor,
    required this.rows,
    required this.summaries,
    required this.onSummaryChanged,
  });

  Widget _buildSummaryCell(
    DatabaseColumn col, {
    bool transparentBorder = false,
  }) {
    final effectiveBorderColor =
        transparentBorder ? Palette.transparent : borderColor;
    if (col.type == 'title' && onAddRow != null) {
      return SizedBox(
        width: columnWidths[col.id] ?? col.width,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: BottomAddRowButton(onTap: onAddRow!),
              ),
            ),
            Flexible(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) => TableSummaryCell(
                  key: ValueKey('summary_${col.id}'),
                  stats: stats?[col.id],
                  loading: loading,
                  error: error,
                  column: col,
                  width: constraints.maxWidth,
                  borderColor: effectiveBorderColor,
                  rows: rows,
                  currentSummaryType: SummaryType.fromId(
                    summaries[col.id],
                  ),
                  onSummaryChanged: onSummaryChanged,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return TableSummaryCell(
      key: ValueKey('summary_${col.id}'),
      stats: stats?[col.id],
      loading: loading,
      error: error,
      column: col,
      width: columnWidths[col.id] ?? col.width,
      borderColor: effectiveBorderColor,
      rows: rows,
      currentSummaryType: SummaryType.fromId(summaries[col.id]),
      onSummaryChanged: onSummaryChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final shouldFreeze = freezeTitle &&
        columns.isNotEmpty &&
        columns.first.type == 'title' &&
        horizontalScrollController != null;

    if (!shouldFreeze) {
      return SizedBox(
        height: DesktopUx.databaseRowHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: DesktopUx.databaseGutterWidth),
            for (final col in columns) _buildSummaryCell(col),
            const SizedBox(width: DesktopUx.databaseActionWidth),
          ],
        ),
      );
    }

    final titleWidth = columnWidths[columns[0].id] ?? columns[0].width;
    final frozenWidth = DesktopUx.databaseGutterWidth + titleWidth;

    return SizedBox(
      height: DesktopUx.databaseRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: frozenWidth),
              for (int i = 1; i < columns.length; i++)
                _buildSummaryCell(columns[i]),
              const SizedBox(width: DesktopUx.databaseActionWidth),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: DatabaseStickyPane(
              horizontalScrollController: horizontalScrollController,
              width: frozenWidth,
              backgroundColor: skin.surface,
              borderColor: borderColor,
              isFrozen: true,
              child: Row(
                children: [
                  const SizedBox(width: DesktopUx.databaseGutterWidth),
                  _buildSummaryCell(columns[0], transparentBorder: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TableSummaryCell extends StatefulWidget {
  final DatabaseSummaryStats? stats;
  final bool loading;
  final bool error;
  final DatabaseColumn column;
  final double width;
  final Color borderColor;
  final List<DatabaseRowData> rows;
  final SummaryType currentSummaryType;
  final void Function(String columnId, String? summaryType) onSummaryChanged;

  const TableSummaryCell({
    super.key,
    this.stats,
    this.loading = false,
    this.error = false,
    required this.column,
    required this.width,
    required this.borderColor,
    required this.rows,
    required this.currentSummaryType,
    required this.onSummaryChanged,
  });

  @override
  State<TableSummaryCell> createState() => _TableSummaryCellState();
}

class _TableSummaryCellState extends State<TableSummaryCell> {
  bool _isHovered = false;

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;

    final available = getAvailableSummariesForColumn(widget.column);

    showPopover(
      context,
      anchor: anchor,
      width: UiLayout.cellMenuWidth,
      builder: (popContext, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuSectionHeader(title: context.l10n.calculate),
          for (final opt in available)
            MenuRow(
              label: summaryTypeLabel(opt, context),
              selected: widget.currentSummaryType == opt,
              onTap: () {
                close();
                widget.onSummaryChanged(
                  widget.column.id,
                  opt == SummaryType.none ? null : opt.name,
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final hasSummary = widget.currentSummaryType != SummaryType.none;
    final result = hasSummary
        ? calculateSummaryResult(
            type: widget.currentSummaryType,
            column: widget.column,
            rows: widget.rows,
            context: context,
            stats: widget.stats,
          )
        : null;

    final isNumber = widget.column.type == 'number';

    return Tooltip(
      message: hasSummary ? context.l10n.databaseSummaryScope : '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showMenu(context),
          child: Container(
            width: widget.width,
            height: DesktopUx.databaseRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.s8),
            decoration: BoxDecoration(
              color: _isHovered ? skin.hover : Palette.transparent,
            ),
            alignment: isNumber ? Alignment.centerRight : Alignment.centerLeft,
            child: hasSummary && (widget.loading || widget.error)
                ? Text(
                    widget.error ? context.l10n.databaseLoadError : '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: UiType.caption,
                      color: skin.muted,
                    ),
                  )
                : hasSummary && result != null
                ? Text.rich(
                    TextSpan(
                      children: [
                        if (result.label.isNotEmpty) ...[
                          TextSpan(
                            text: result.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: UiType.small,
                              fontWeight: FontWeight.w400,
                              color: skin.hint,
                            ),
                          ),
                          const TextSpan(text: ' '),
                        ],
                        TextSpan(
                          text: result.value,
                          style: TextStyle(
                            fontSize: UiType.caption,
                            fontWeight: FontWeight.w400,
                            color: skin.muted,
                            fontFeatures: UiType.tabular,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : AnimatedOpacity(
                    curve: Motion.curve,
                    duration: Motion.of(context, Motion.micro),
                    opacity: _isHovered ? 1.0 : 0.0,
                    child: Text(
                      context.l10n.calculate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: UiType.caption,
                        color: skin.hint,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

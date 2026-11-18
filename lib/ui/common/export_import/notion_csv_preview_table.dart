import 'package:flutter/material.dart';

import '../../../services/export_import_service.dart';
import '../../../ui/design_tokens.dart';
import '../../../ui/theme.dart';
import '../../editor/components/database/database_models.dart';
import '../app_icons.dart';
import 'export_import_shared.dart';

class NotionCsvPreviewTable extends StatefulWidget {
  final ParsedCsvDatabase? parsedCsv;

  const NotionCsvPreviewTable({
    super.key,
    required this.parsedCsv,
  });

  @override
  State<NotionCsvPreviewTable> createState() => _NotionCsvPreviewTableState();
}

class _NotionCsvPreviewTableState extends State<NotionCsvPreviewTable> {
  final ScrollController _tableHorizController = ScrollController();
  final ScrollController _tableVertController = ScrollController();

  @override
  void dispose() {
    _tableHorizController.dispose();
    _tableVertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final parsedCsv = widget.parsedCsv;

    if (parsedCsv == null || parsedCsv.columns.isEmpty) {
      return Center(
        child: Text(
          'No CSV data parsed',
          style: TextStyle(fontSize: UiType.caption, color: skin.muted),
        ),
      );
    }

    final columns = parsedCsv.columns;
    final rows = parsedCsv.rows;
    const maxPreviewRows = 50;
    final previewRows = rows.take(maxPreviewRows).toList();

    return Container(
      decoration: panelDecoration(skin),
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: UiRadius.squircle(UiRadius.dialog),
        ),
        child: Scrollbar(
          controller: _tableHorizController,
          child: SingleChildScrollView(
            controller: _tableHorizController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (columns.length * 150.0 + 44.0).clamp(650.0, 3000.0),
              child: Scrollbar(
                controller: _tableVertController,
                child: SingleChildScrollView(
                  controller: _tableVertController,
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Container(
                        height: UiSpace.s32,
                        decoration: BoxDecoration(
                          color: skin.hover,
                          border: Border(
                            bottom: BorderSide(
                              color: skin.hairlineBorder,
                              width: UiSpace.s1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: UiSpace.s44,
                              alignment: Alignment.center,
                              child: Text(
                                '#',
                                style: TextStyle(
                                  fontSize: UiType.small,
                                  fontWeight: FontWeight.w600,
                                  color: skin.muted,
                                ),
                              ),
                            ),
                            for (
                              var colIdx = 0;
                              colIdx < columns.length;
                              colIdx++
                            ) ...[
                              Container(
                                width: UiSpace.s1,
                                height: UiSpace.s18,
                                color: skin.hairlineBorder,
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: UiSpace.s8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        iconForColumnType(columns[colIdx].type),
                                        size: UiSpace.s14,
                                        color: columns[colIdx].type == 'title'
                                            ? skin.text
                                            : skin.muted,
                                      ),
                                      const SizedBox(width: UiSpace.s5),
                                      Expanded(
                                        child: Text(
                                          columns[colIdx].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: UiType.caption,
                                            fontWeight:
                                                columns[colIdx].type == 'title'
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                            color:
                                                columns[colIdx].type == 'title'
                                                    ? skin.text
                                                    : skin.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Data Rows
                      for (var r = 0; r < previewRows.length; r++)
                        Container(
                          height: UiSpace.s28,
                          decoration: BoxDecoration(
                            color: r.isOdd
                                ? skin.hover.withValues(
                                    alpha: skin.hover.a * 0.5,
                                  )
                                : Palette.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: skin.hairlineBorder,
                                width: UiSpace.s1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: UiSpace.s44,
                                alignment: Alignment.center,
                                child: Text(
                                  '${r + 1}',
                                  style: TextStyle(
                                    fontSize: UiType.small,
                                    color: skin.hint,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              for (
                                var colIdx = 0;
                                colIdx < columns.length;
                                colIdx++
                              ) ...[
                                Container(
                                  width: UiSpace.s1,
                                  height: UiSpace.s16,
                                  color: skin.hairlineBorder,
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: UiSpace.s8,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: _buildCellContent(
                                      skin,
                                      columns[colIdx].type,
                                      colIdx < previewRows[r].length
                                          ? previewRows[r][colIdx]
                                          : '',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(Skin skin, String colType, String value) {
    if (value.isEmpty) {
      return Text(
        '-',
        style: TextStyle(fontSize: UiType.small, color: skin.hint),
      );
    }

    if (colType == 'select' || colType == 'status') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpace.s6,
          vertical: UiSpace.s1_5,
        ),
        decoration: BoxDecoration(
          color: Palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(UiRadius.action),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: UiType.small,
            fontWeight: FontWeight.w500,
            color: Palette.accent,
          ),
        ),
      );
    }

    if (colType == 'multi_select') {
      final tags =
          value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
      return Wrap(
        spacing: UiSpace.s4,
        runSpacing: UiSpace.s2,
        children: [
          for (final tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UiSpace.s6,
                vertical: UiSpace.s1_5,
              ),
              decoration: BoxDecoration(
                color: Palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(UiRadius.action),
              ),
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: UiType.small,
                  fontWeight: FontWeight.w500,
                  color: Palette.accent,
                ),
              ),
            ),
        ],
      );
    }

    if (colType == 'checkbox') {
      final isChecked =
          value.toLowerCase() == 'true' ||
          value.toLowerCase() == 'yes' ||
          value == '1' ||
          value == '✓';
      return Icon(
        isChecked ? AppIcons.checkmarkSquare : AppIcons.square,
        size: UiSpace.s14,
        color: isChecked ? Palette.accent : skin.muted,
      );
    }

    if (colType == 'url') {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: UiType.small,
          color: Palette.accent,
          decoration: TextDecoration.underline,
        ),
      );
    }

    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: UiType.caption,
        color: colType == 'title' ? skin.text : skin.muted,
        fontWeight: colType == 'title' ? FontWeight.w500 : FontWeight.w400,
      ),
    );
  }
}

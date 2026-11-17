import 'package:flutter/material.dart' hide Page;
import '../../../common/app_icons.dart';
import 'database_models.dart';

enum DatabaseViewType {
  table,
  board,
  gallery,
  list;

  static DatabaseViewType fromString(String? val) {
    switch (val) {
      case 'board':
        return DatabaseViewType.board;
      case 'gallery':
        return DatabaseViewType.gallery;
      case 'list':
        return DatabaseViewType.list;
      case 'table':
      default:
        return DatabaseViewType.table;
    }
  }

  IconData get icon {
    switch (this) {
      case DatabaseViewType.table:
        return AppIcons.table;
      case DatabaseViewType.board:
        return AppIcons.rectangleSplit3x1;
      case DatabaseViewType.gallery:
        return AppIcons.squareGrid2x2;
      case DatabaseViewType.list:
        return AppIcons.listBullet;
    }
  }
}

class DatabaseViewConfig {
  final String id;
  final String name;
  final DatabaseViewType type;
  final DatabaseSortConfig? sort;
  final List<DatabaseFilterRule> filters;
  final List<String> visibleColumnIds; // empty means all visible
  final Map<String, double> columnWidths;
  final String? groupByColumnId;
  final bool wrapCells;

  const DatabaseViewConfig({
    required this.id,
    required this.name,
    this.type = DatabaseViewType.table,
    this.sort,
    this.filters = const [],
    this.visibleColumnIds = const [],
    this.columnWidths = const {},
    this.groupByColumnId,
    this.wrapCells = true,
  });

  DatabaseViewConfig copyWith({
    String? id,
    String? name,
    DatabaseViewType? type,
    DatabaseSortConfig? sort,
    bool clearSort = false,
    List<DatabaseFilterRule>? filters,
    List<String>? visibleColumnIds,
    Map<String, double>? columnWidths,
    String? groupByColumnId,
    bool? wrapCells,
  }) {
    return DatabaseViewConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      sort: clearSort ? null : (sort ?? this.sort),
      filters: filters ?? this.filters,
      visibleColumnIds: visibleColumnIds ?? this.visibleColumnIds,
      columnWidths: columnWidths ?? this.columnWidths,
      groupByColumnId: groupByColumnId ?? this.groupByColumnId,
      wrapCells: wrapCells ?? this.wrapCells,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      if (sort != null)
        'sort': {
          'columnId': sort!.columnId,
          'ascending': sort!.ascending,
        },
      if (filters.isNotEmpty)
        'filters': [
          for (final f in filters)
            {
              'columnId': f.columnId,
              'operator': f.operator,
              'value': f.value,
            },
        ],
      if (visibleColumnIds.isNotEmpty) 'visibleColumnIds': visibleColumnIds,
      if (columnWidths.isNotEmpty) 'columnWidths': columnWidths,
      if (groupByColumnId != null) 'groupByColumnId': groupByColumnId,
      'wrapCells': wrapCells,
    };
  }

  factory DatabaseViewConfig.fromJson(Map<String, dynamic> json) {
    DatabaseSortConfig? sort;
    if (json['sort'] is Map) {
      final s = json['sort'] as Map;
      if (s['columnId'] != null) {
        sort = DatabaseSortConfig(
          columnId: s['columnId'].toString(),
          ascending: s['ascending'] as bool? ?? true,
        );
      }
    }

    final filters = <DatabaseFilterRule>[];
    if (json['filters'] is List) {
      for (final f in json['filters'] as List) {
        if (f is Map && f['columnId'] != null && f['operator'] != null) {
          filters.add(
            DatabaseFilterRule(
              columnId: f['columnId'].toString(),
              operator: f['operator'].toString(),
              value: f['value'],
            ),
          );
        }
      }
    }

    final visibleCols = <String>[];
    if (json['visibleColumnIds'] is List) {
      for (final v in json['visibleColumnIds'] as List) {
        visibleCols.add(v.toString());
      }
    }

    final widths = <String, double>{};
    if (json['columnWidths'] is Map) {
      for (final entry in (json['columnWidths'] as Map).entries) {
        final val = entry.value;
        if (val is num) widths[entry.key.toString()] = val.toDouble();
      }
    }

    return DatabaseViewConfig(
      id: json['id']?.toString() ?? 'view_default',
      name: json['name']?.toString() ?? 'Table',
      type: DatabaseViewType.fromString(json['type']?.toString()),
      sort: sort,
      filters: filters,
      visibleColumnIds: visibleCols,
      columnWidths: widths,
      groupByColumnId: json['groupByColumnId']?.toString(),
      wrapCells: json['wrapCells'] as bool? ?? true,
    );
  }
}

List<DatabaseViewConfig> parseDatabaseViews(dynamic raw) {
  if (raw is List) {
    final list = <DatabaseViewConfig>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          list.add(DatabaseViewConfig.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    if (list.isNotEmpty) return list;
  }
  return const [];
}

import 'dart:convert';

import '../db/app_database.dart';

class DatabaseSortConfig {
  final String columnId;
  final bool ascending;
  const DatabaseSortConfig({required this.columnId, this.ascending = true});
}

class DatabaseFilterRule {
  final String columnId;
  final String operator;
  final dynamic value;
  const DatabaseFilterRule({
    required this.columnId,
    required this.operator,
    this.value,
  });
}

class DatabaseRowData {
  final Page page;
  final Map<String, dynamic> properties;
  DatabaseRowData(this.page, {Map<String, dynamic>? properties})
    : properties = properties ?? decodeRowProperties(page.properties);
}

Map<String, dynamic> decodeRowProperties(String? json) {
  if (json == null || json.isEmpty) return const {};
  try {
    final decoded = jsonDecode(json);
    return decoded is Map<String, dynamic>
        ? Map.unmodifiable(decoded)
        : const {};
  } catch (_) {
    return const {};
  }
}

// Store Unicode case folding on mutation, rather than relying on SQLite's
// ASCII-only lower() during every search and sort.
String? foldProperties(String? json) {
  if (json == null) return null;
  try {
    Object? fold(Object? value) {
      if (value is String) return value.toLowerCase();
      if (value is List) return value.map(fold).toList();
      if (value is Map) {
        return value.map((key, value) => MapEntry(key, fold(value)));
      }
      return value;
    }

    return jsonEncode(fold(jsonDecode(json)));
  } catch (_) {
    return null;
  }
}

class DatabaseRowsPage {
  final List<DatabaseRowData> rows;
  final int totalCount;
  final int filteredCount;
  final int offset;
  final int limit;
  DatabaseRowsPage({
    required List<Page> pages,
    required this.totalCount,
    required this.filteredCount,
    required this.offset,
    required this.limit,
    DatabaseRowData Function(Page)? decode,
  }) : rows = List.unmodifiable(pages.map(decode ?? DatabaseRowData.new));
}

abstract final class DatabaseQueryPolicy {
  static const pageSize = 50;
  static const maxPageSize = 200;
  static const searchDebounce = Duration(milliseconds: 200);
}

/// Weighted values from SQL GROUP BY, rather than materialized pages.
class DatabaseValueGroup {
  final dynamic value;
  final int count;
  const DatabaseValueGroup(this.value, this.count);
}

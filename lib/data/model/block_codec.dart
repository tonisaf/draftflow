import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

/// AppFlowy's JSON omits IDs; recovery drafts and detached snapshots must not.
Map<String, Object> encodeNodeWithIds(Node node) => {
  ...shallowNodeJson(node),
  'id': node.id,
  if (node.children.isNotEmpty)
    'children': node.children.map(encodeNodeWithIds).toList(),
};

Map<String, Object> shallowNodeJson(Node node) {
  final attributes = node.attributes..removeWhere((_, value) => value == null);
  return {'type': node.type, if (attributes.isNotEmpty) 'data': attributes};
}

Node decodeNodeWithIds(Map<String, Object> json) {
  return Node(
    type: json['type'] as String,
    id: json['id'] as String?,
    attributes: (json['data'] as Map? ?? {}).cast<String, dynamic>(),
    children: (json['children'] as List? ?? [])
        .map(
          (child) => decodeNodeWithIds((child as Map).cast<String, Object>()),
        )
        .toList(),
  );
}

String canonicalBlockJson(Object? value) {
  Object? sort(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sort(value[key])};
    }
    if (value is List) return value.map(sort).toList();
    return value;
  }

  return jsonEncode(sort(value));
}

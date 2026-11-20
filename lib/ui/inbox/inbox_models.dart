import 'dart:convert';
import 'package:flutter/widgets.dart' hide Page;

import '../../data/db/app_database.dart';
import '../common/app_icons.dart';

enum InboxItemType {
  article,
  link,
  quote,
  screenshot,
  note;

  String get label {
    switch (this) {
      case InboxItemType.article:
        return 'Статья';
      case InboxItemType.link:
        return 'Ссылка';
      case InboxItemType.quote:
        return 'Цитата';
      case InboxItemType.screenshot:
        return 'Скриншот';
      case InboxItemType.note:
        return 'Заметка';
    }
  }

  IconData get icon {
    switch (this) {
      case InboxItemType.article:
        return AppIcons.docText;
      case InboxItemType.link:
        return AppIcons.link;
      case InboxItemType.quote:
        return AppIcons.quote;
      case InboxItemType.screenshot:
        return AppIcons.photo;
      case InboxItemType.note:
        return AppIcons.pencil;
    }
  }

  static InboxItemType fromString(String? value) {
    switch (value) {
      case 'article':
        return InboxItemType.article;
      case 'link':
        return InboxItemType.link;
      case 'quote':
        return InboxItemType.quote;
      case 'screenshot':
        return InboxItemType.screenshot;
      case 'note':
        return InboxItemType.note;
      default:
        return InboxItemType.link;
    }
  }
}

const inboxItemKey = '_draftflow_inbox_item';

class InboxItemMetadata {
  final bool isInboxItem;
  final InboxItemType type;
  final String? url;
  final String? domain;
  final String? faviconUrl;
  final String? previewImageUrl;
  final String? excerpt;
  final String? author;
  final bool isArchived;
  final DateTime? savedAt;

  const InboxItemMetadata({
    this.isInboxItem = false,
    this.type = InboxItemType.link,
    this.url,
    this.domain,
    this.faviconUrl,
    this.previewImageUrl,
    this.excerpt,
    this.author,
    this.isArchived = false,
    this.savedAt,
  });

  InboxItemMetadata copyWith({
    bool? isInboxItem,
    InboxItemType? type,
    String? url,
    String? domain,
    String? faviconUrl,
    String? previewImageUrl,
    String? excerpt,
    String? author,
    bool? isArchived,
    DateTime? savedAt,
  }) {
    return InboxItemMetadata(
      isInboxItem: isInboxItem ?? this.isInboxItem,
      type: type ?? this.type,
      url: url ?? this.url,
      domain: domain ?? this.domain,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      excerpt: excerpt ?? this.excerpt,
      author: author ?? this.author,
      isArchived: isArchived ?? this.isArchived,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'isInboxItem': isInboxItem,
        'type': type.name,
        if (url != null) 'url': url,
        if (domain != null) 'domain': domain,
        if (faviconUrl != null) 'faviconUrl': faviconUrl,
        if (previewImageUrl != null) 'previewImageUrl': previewImageUrl,
        if (excerpt != null) 'excerpt': excerpt,
        if (author != null) 'author': author,
        'isArchived': isArchived,
        if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
      };

  factory InboxItemMetadata.fromMap(Map<String, dynamic> map) {
    return InboxItemMetadata(
      isInboxItem: map['isInboxItem'] == true,
      type: InboxItemType.fromString(map['type'] as String?),
      url: map['url'] as String?,
      domain: map['domain'] as String?,
      faviconUrl: map['faviconUrl'] as String?,
      previewImageUrl: map['previewImageUrl'] as String?,
      excerpt: map['excerpt'] as String?,
      author: map['author'] as String?,
      isArchived: map['isArchived'] == true,
      savedAt: map['savedAt'] != null
          ? DateTime.tryParse(map['savedAt'] as String)
          : null,
    );
  }
}

InboxItemMetadata inboxItemFromProperties(String? properties) {
  try {
    final data = jsonDecode(properties ?? '{}');
    if (data is Map && data[inboxItemKey] is Map) {
      final map = Map<String, dynamic>.from(data[inboxItemKey] as Map);
      return InboxItemMetadata.fromMap(map);
    }
    return const InboxItemMetadata();
  } catch (_) {
    return const InboxItemMetadata();
  }
}

String mergeInboxItemToProperties(String? properties, InboxItemMetadata metadata) {
  Map<String, dynamic> data = {};
  try {
    final decoded = jsonDecode(properties ?? '{}');
    if (decoded is Map) {
      data = Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  data[inboxItemKey] = metadata.toMap();
  return jsonEncode(data);
}

class InboxCardData {
  final Page page;
  final InboxItemMetadata metadata;
  final String textSnippet;
  final List<Block> blocks;

  const InboxCardData({
    required this.page,
    required this.metadata,
    this.textSnippet = '',
    this.blocks = const [],
  });

  static InboxCardData fromPageAndBlocks(Page page, List<Block> blocks) {
    final metadata = inboxItemFromProperties(page.properties);
    final textLines = <String>[];

    for (final b in blocks) {
      if (b.type == 'paragraph' || b.type == 'text' || b.type == 'callout' || b.type == 'quote') {
        try {
          final data = jsonDecode(b.content);
          if (data is Map && data['data'] is Map && data['data']['delta'] is List) {
            final delta = data['data']['delta'] as List;
            for (final op in delta) {
              if (op is Map && op['insert'] is String) {
                final txt = op['insert'] as String;
                if (txt.trim().isNotEmpty) textLines.add(txt.trim());
              }
            }
          }
        } catch (_) {}
      }
    }

    final snippet = metadata.excerpt?.isNotEmpty == true
        ? metadata.excerpt!
        : textLines.take(3).join(' ');

    return InboxCardData(
      page: page,
      metadata: metadata,
      textSnippet: snippet,
      blocks: blocks,
    );
  }
}

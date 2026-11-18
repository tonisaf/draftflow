import '../app_database.dart';

class DocumentConflictException implements Exception {
  final String pageId;
  const DocumentConflictException(this.pageId);

  @override
  String toString() => 'DocumentConflictException($pageId)';
}

class PageMatchRecord {
  final Page page;
  final String? snippet;
  final bool isContentMatch;
  final bool isFuzzyMatch;
  final String? matchedTerm;
  final int score;

  const PageMatchRecord({
    required this.page,
    this.snippet,
    this.isContentMatch = false,
    this.isFuzzyMatch = false,
    this.matchedTerm,
    this.score = 0,
  });
}

/// A detached, flat block snapshot. List order defines order within each parent.
typedef BlockWrite = ({
  String id,
  String? parentId,
  String type,
  String content,
});

Iterable<List<String>> chunks(Set<String> ids, [int size = 400]) sync* {
  final values = ids.toList();
  for (var i = 0; i < values.length; i += size) {
    yield values.sublist(i, (i + size).clamp(0, values.length));
  }
}

import '../db/app_database.dart';

class PageTreeNode {
  final Page page;
  final List<PageTreeNode> children;
  final int depth;

  const PageTreeNode({
    required this.page,
    this.children = const [],
    this.depth = 0,
  });

  bool get hasChildren => children.isNotEmpty;
}

List<PageTreeNode> buildPageTree(List<Page> pages) {
  final childrenByParent = <String?, List<Page>>{};
  for (final page in pages) {
    childrenByParent.putIfAbsent(page.parentId, () => []).add(page);
  }

  List<PageTreeNode> buildSubtree(String? parentId, int depth) {
    final list = childrenByParent[parentId] ?? [];
    return list.map((p) {
      return PageTreeNode(
        page: p,
        children: buildSubtree(p.id, depth + 1),
        depth: depth,
      );
    }).toList();
  }

  return buildSubtree(null, 0);
}

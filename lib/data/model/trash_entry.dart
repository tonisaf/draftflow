/// One deleted page/database and the context shown beneath its title.
class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.title,
    required this.isDatabase,
    required this.deletedAt,
    this.icon,
    this.parentTitle,
  });
  final String id;
  final String title;
  final String? icon;
  final bool isDatabase;
  final DateTime deletedAt;
  final String? parentTitle;
  String get key => '${isDatabase ? 'database' : 'page'}:$id';
}

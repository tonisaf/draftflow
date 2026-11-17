/// The targeted cell changed since editing began; other columns are irrelevant.
class DatabaseCellConflict implements Exception {
  const DatabaseCellConflict(this.current);
  final dynamic current;
}

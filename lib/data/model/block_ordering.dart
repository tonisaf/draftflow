import 'package:fractional_indexing/fractional_indexing.dart';

/// Keep the largest ordered set of existing sibling keys. A single move then
/// changes one key rather than renumbering every sibling after the drop target.
List<String> reconcileBlockOrder(List<String?> existingKeys) {
  final tails = <int>[];
  final predecessors = List<int>.filled(existingKeys.length, -1);
  for (var i = 0; i < existingKeys.length; i++) {
    final key = existingKeys[i];
    if (key == null) continue;
    try {
      FractionalIndexer.validateOrderKey(key);
    } catch (_) {
      continue;
    }
    var low = 0;
    var high = tails.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (existingKeys[tails[middle]]!.compareTo(key) < 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low > 0) predecessors[i] = tails[low - 1];
    if (low == tails.length) {
      tails.add(i);
    } else {
      tails[low] = i;
    }
  }
  final result = List<String?>.filled(existingKeys.length, null);
  var anchor = tails.isEmpty ? -1 : tails.last;
  while (anchor != -1) {
    result[anchor] = existingKeys[anchor];
    anchor = predecessors[anchor];
  }
  String? previous;
  var start = 0;
  while (start < result.length) {
    if (result[start] != null) {
      previous = result[start++];
      continue;
    }
    var end = start;
    while (end < result.length && result[end] == null) {
      end++;
    }
    final keys = FractionalIndexer.generateNKeysBetween(
      previous,
      end < result.length ? result[end] : null,
      end - start,
    );
    for (var i = start; i < end; i++) {
      result[i] = keys[i - start]!;
    }
    previous = result[end - 1];
    start = end;
  }
  return result.cast<String>();
}

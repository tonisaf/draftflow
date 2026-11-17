import 'package:flutter_test/flutter_test.dart';
import 'package:fractional_indexing/fractional_indexing.dart';

void main() {
  test('FractionalIndexer basic ordering', () {
    final first = FractionalIndexer.generateKeyBetween(null, null)!;
    final second = FractionalIndexer.generateKeyBetween(first, null)!;
    final middle = FractionalIndexer.generateKeyBetween(first, second)!;

    expect(first, 'a0');
    expect(second, 'a1');
    expect(first.compareTo(middle) < 0, true);
    expect(middle.compareTo(second) < 0, true);
  });
}

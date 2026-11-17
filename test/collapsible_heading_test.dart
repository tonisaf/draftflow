import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/collapsible_heading_component.dart';

void main() {
  test('isNodeHiddenByCollapsedHeading hides blocks under collapsed H1 until next H1', () {
    final children = [
      headingNode(level: 1, text: 'H1 Section 1', attributes: {'collapsed': true}), // 0
      paragraphNode(text: 'Paragraph in H1'),                                      // 1
      headingNode(level: 2, text: 'H2 inside H1'),                                 // 2
      paragraphNode(text: 'Paragraph in H2'),                                      // 3
      headingNode(level: 1, text: 'H1 Section 2'),                                 // 4
      paragraphNode(text: 'Paragraph in Section 2'),                               // 5
    ];

    expect(isNodeHiddenByCollapsedHeading(children, 0), isFalse); // H1 itself is visible
    expect(isNodeHiddenByCollapsedHeading(children, 1), isTrue);  // hidden by H1
    expect(isNodeHiddenByCollapsedHeading(children, 2), isTrue);  // H2 is sub-heading of H1, hidden
    expect(isNodeHiddenByCollapsedHeading(children, 3), isTrue);  // hidden by H1
    expect(isNodeHiddenByCollapsedHeading(children, 4), isFalse); // new H1 ends the collapsed section
    expect(isNodeHiddenByCollapsedHeading(children, 5), isFalse); // visible under new H1
  });

  test('isNodeHiddenByCollapsedHeading hides blocks under collapsed H2 until next H2 or H1', () {
    final children = [
      headingNode(level: 1, text: 'H1 Section 1'),                                 // 0
      paragraphNode(text: 'Paragraph in H1'),                                      // 1
      headingNode(level: 2, text: 'H2 Section 1.1', attributes: {'collapsed': true}), // 2
      paragraphNode(text: 'Paragraph in H2'),                                      // 3
      headingNode(level: 2, text: 'H2 Section 1.2'),                               // 4
      paragraphNode(text: 'Paragraph in Section 1.2'),                             // 5
    ];

    expect(isNodeHiddenByCollapsedHeading(children, 0), isFalse);
    expect(isNodeHiddenByCollapsedHeading(children, 1), isFalse);
    expect(isNodeHiddenByCollapsedHeading(children, 2), isFalse); // H2 itself is visible
    expect(isNodeHiddenByCollapsedHeading(children, 3), isTrue);  // hidden by H2
    expect(isNodeHiddenByCollapsedHeading(children, 4), isFalse); // new H2 ends collapsed H2
    expect(isNodeHiddenByCollapsedHeading(children, 5), isFalse); // visible
  });
}

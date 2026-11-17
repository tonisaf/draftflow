import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/editor/components/code_highlighter.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  for (final language in ['bash', 'shell', 'sh', 'zsh']) {
    test('$language keeps CLI flags, URLs and quoted strings distinct', () {
      const source =
          'systemctl stop tomcat && find /opt/apps -name "cmj*" --delete\n'
          'curl --silent --form file=@data.jar https://example.test/a # note';
      final spans = CodeHighlighter.highlight(
        text: source,
        language: language,
        isDark: false,
        fontName: 'Consolas',
      );
      expect(spans.map((span) => span.text).join(), source);
      expect(
        spans.firstWhere((span) => span.text == 'find').style!.color,
        const SyntaxColors(dark: false).keyword,
      );
      expect(
        spans.firstWhere((span) => span.text == '"cmj*"').style!.color,
        const SyntaxColors(dark: false).string,
      );
      expect(
        spans.firstWhere((span) => span.text == '# note').style!.color,
        const SyntaxColors(dark: false).comment,
      );
      expect(
        spans
            .where(
              (span) =>
                  span.style?.color == const SyntaxColors(dark: false).comment,
            )
            .map((span) => span.text)
            .join(),
        '# note',
      );
    });
  }

  test('explicit plain text stays unhighlighted', () {
    final spans = CodeHighlighter.highlight(
      text: 'find "file" --delete',
      language: 'plaintext',
      isDark: false,
      fontName: 'Consolas',
    );
    expect(spans, hasLength(1));
    expect(spans.single.style!.color, const SyntaxColors(dark: false).text);
  });
}

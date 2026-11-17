import '../../theme.dart';

import 'package:flutter/material.dart';

class CodeHighlighter {
  static const Map<String, List<String>> _languageKeywords = {
    'dart': [
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'base',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'Function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'of',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'sealed',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'when',
      'while',
      'with',
      'yield',
    ],
    'javascript': [
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'debugger',
      'default',
      'delete',
      'do',
      'else',
      'enum',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'from',
      'function',
      'get',
      'if',
      'import',
      'in',
      'instanceof',
      'let',
      'new',
      'null',
      'of',
      'return',
      'set',
      'static',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'typeof',
      'var',
      'void',
      'while',
      'with',
      'yield',
    ],
    'typescript': [
      'any',
      'as',
      'async',
      'await',
      'boolean',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'declare',
      'default',
      'delete',
      'do',
      'else',
      'enum',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'from',
      'function',
      'if',
      'implements',
      'import',
      'in',
      'instanceof',
      'interface',
      'is',
      'keyof',
      'let',
      'module',
      'namespace',
      'never',
      'new',
      'null',
      'number',
      'readonly',
      'return',
      'static',
      'string',
      'super',
      'switch',
      'symbol',
      'this',
      'throw',
      'true',
      'try',
      'type',
      'typeof',
      'undefined',
      'unknown',
      'var',
      'void',
      'while',
      'with',
      'yield',
    ],
    'python': [
      'and',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'class',
      'continue',
      'def',
      'del',
      'elif',
      'else',
      'except',
      'False',
      'finally',
      'for',
      'from',
      'global',
      'if',
      'import',
      'in',
      'is',
      'lambda',
      'None',
      'nonlocal',
      'not',
      'or',
      'pass',
      'raise',
      'return',
      'self',
      'True',
      'try',
      'while',
      'with',
      'yield',
    ],
    'sql': [
      'add',
      'all',
      'alter',
      'and',
      'as',
      'asc',
      'between',
      'by',
      'case',
      'check',
      'column',
      'create',
      'database',
      'default',
      'delete',
      'desc',
      'distinct',
      'drop',
      'else',
      'end',
      'foreign',
      'from',
      'group',
      'having',
      'in',
      'index',
      'inner',
      'insert',
      'into',
      'is',
      'join',
      'key',
      'left',
      'like',
      'limit',
      'not',
      'null',
      'offset',
      'on',
      'or',
      'order',
      'outer',
      'primary',
      'references',
      'right',
      'select',
      'set',
      'table',
      'then',
      'union',
      'unique',
      'update',
      'values',
      'view',
      'where',
    ],
    'bash': [
      'find',
      'cp',
      'mv',
      'rm',
      'systemctl',
      'curl',
      'sudo',
      'mkdir',
      'chmod',
      'chown',
      'grep',
      'cat',
      'ls',
      'pwd',
      'printf',
      'apt',
      'yum',
      'dnf',
      'docker',
      'ssh',
      'scp',
      'tar',
      'wget',
      'alias',
      'bg',
      'case',
      'cd',
      'do',
      'done',
      'echo',
      'elif',
      'else',
      'esac',
      'exit',
      'export',
      'fi',
      'for',
      'function',
      'if',
      'in',
      'local',
      'read',
      'return',
      'set',
      'shift',
      'source',
      'then',
      'until',
      'while',
    ],
    'rust': [
      'as',
      'async',
      'await',
      'break',
      'const',
      'continue',
      'crate',
      'dyn',
      'else',
      'enum',
      'extern',
      'false',
      'fn',
      'for',
      'if',
      'impl',
      'in',
      'let',
      'loop',
      'match',
      'mod',
      'move',
      'mut',
      'pub',
      'ref',
      'return',
      'self',
      'Self',
      'static',
      'struct',
      'super',
      'trait',
      'true',
      'type',
      'unsafe',
      'use',
      'where',
      'while',
    ],
    'go': [
      'break',
      'case',
      'chan',
      'const',
      'continue',
      'default',
      'defer',
      'else',
      'fallthrough',
      'for',
      'func',
      'go',
      'goto',
      'if',
      'import',
      'interface',
      'map',
      'package',
      'range',
      'return',
      'select',
      'struct',
      'switch',
      'type',
      'var',
    ],
    'json': ['true', 'false', 'null'],
    'yaml': ['true', 'false', 'yes', 'no', 'null', 'on', 'off'],
    'html': [
      '!doctype',
      'html',
      'head',
      'body',
      'div',
      'span',
      'p',
      'a',
      'script',
      'style',
      'link',
      'meta',
      'title',
      'table',
      'tr',
      'td',
      'th',
      'ul',
      'ol',
      'li',
      'form',
      'input',
      'button',
      'header',
      'footer',
      'nav',
      'section',
    ],
    'css': [
      'important',
      'inherit',
      'initial',
      'unset',
      'none',
      'auto',
      'hidden',
      'block',
      'flex',
      'grid',
      'inline',
      'relative',
      'absolute',
      'fixed',
    ],
    'markdown': [],
    'plaintext': [],
  };

  static List<TextSpan> highlight({
    required String text,
    required String language,
    required bool isDark,
    required String fontName,
    double fontSize = UiType.code,
    double height = UiType.codeLineHeight,
  }) {
    if (text.isEmpty) {
      return const [];
    }

    final syntax = SyntaxColors(dark: isDark);
    final defaultColor = syntax.text;
    final keywordColor = syntax.keyword;
    final stringColor = syntax.string;
    final commentColor = syntax.comment;
    final numberColor = syntax.number;
    final typeColor = syntax.type;
    final annotationColor = syntax.annotation;

    final baseStyle = TextStyle(
      fontFamily: fontName,
      fontSize: fontSize,
      height: height,
      fontWeight: FontWeight.w400,
      color: defaultColor,
    );

    final rawLanguage = language.trim().toLowerCase();
    final langKey =
        const {
          'sh': 'bash',
          'shell': 'bash',
          'zsh': 'bash',
          'shellscript': 'bash',
          'bash/shell': 'bash',
        }[rawLanguage] ??
        rawLanguage;
    if (langKey == 'plaintext' || langKey == 'text') {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final keywords = _languageKeywords[langKey] ?? const <String>[];
    final keywordSet = keywords.toSet();

    // Regex matching comments, strings, annotations, numbers, words, and other symbols
    // Group 1: Comments (//... or /*...*/ or #... or --...)
    // Group 2: Strings ("..." or '...' or `...`)
    // Group 3: Annotations (@word)
    // Group 4: Numbers (0x123 or 123.45 or 123)
    // Group 5: Words / Identifiers
    final commentPattern = langKey == 'bash'
        ? r'((?<!\S)#[^\n]*)'
        : r'(\/\/[^\n]*|\/\*[\s\S]*?\*\/|#[^\n]*|--[^\n]*)';
    final regex = RegExp(
      '$commentPattern'
      r'|("(?:\\[\s\S]|[^"\\])*"|'
      r"'(?:\\[\s\S]|[^'\\])*'|"
      r'`(?:\\`|[^`])*`)'
      r'|(@[a-zA-Z_]\w*)'
      r'|\b(0x[0-9a-fA-F]+|\d+(?:\.\d+)?)\b'
      r'|\b([a-zA-Z_]\w*)\b',
      multiLine: true,
    );

    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Append unhighlighted text before the match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;

      if (match.group(1) != null) {
        // Comment
        spans.add(
          TextSpan(
            text: matchedText,
            style: baseStyle.copyWith(
              color: commentColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // String
        spans.add(
          TextSpan(
            text: matchedText,
            style: baseStyle.copyWith(color: stringColor),
          ),
        );
      } else if (match.group(3) != null) {
        // Annotation / Decorator
        spans.add(
          TextSpan(
            text: matchedText,
            style: baseStyle.copyWith(color: annotationColor),
          ),
        );
      } else if (match.group(4) != null) {
        // Number
        spans.add(
          TextSpan(
            text: matchedText,
            style: baseStyle.copyWith(color: numberColor),
          ),
        );
      } else if (match.group(5) != null) {
        final word = match.group(5)!;
        final lower = word.toLowerCase();

        if (keywordSet.contains(word) || keywordSet.contains(lower)) {
          // Keyword
          spans.add(
            TextSpan(
              text: matchedText,
              style: baseStyle.copyWith(
                color: keywordColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        } else if (word[0].toUpperCase() == word[0] &&
            word[0] != word[0].toLowerCase() &&
            word.length > 1) {
          // PascalCase: Likely a Class, Type, or Struct name (e.g. MemorySettingsStore)
          spans.add(
            TextSpan(
              text: matchedText,
              style: baseStyle.copyWith(color: typeColor),
            ),
          );
        } else {
          // Normal identifier
          spans.add(TextSpan(text: matchedText, style: baseStyle));
        }
      }

      lastMatchEnd = match.end;
    }

    // Append remaining text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
    }

    return spans;
  }
}

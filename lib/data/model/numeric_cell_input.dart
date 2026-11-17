import 'dart:convert';

enum NumericInputIssue {
  number,
  duration,
  nonFinite,
  formula,
  separators,
  tooLarge,
}

class NumericCellInput {
  const NumericCellInput.valid(this.value) : issue = null;
  const NumericCellInput.invalid(this.issue) : value = null;
  final num? value;
  final NumericInputIssue? issue;
  bool get valid => issue == null;
}

class NumericCellValidationException implements Exception {
  const NumericCellValidationException(this.issue);
  final NumericInputIssue issue;
}

String numericColumnFormat(String? options) {
  try {
    final parsed = jsonDecode(options ?? '{}');
    return parsed is Map ? parsed['format']?.toString() ?? 'number' : 'number';
  } catch (_) {
    return 'number';
  }
}

/// Comma and point are decimal separators. Thousands use groups of three
/// separated by spaces. Mixed comma/point notation is deliberately not guessed.
NumericCellInput parseNumericCellInput(
  dynamic input, {
  String format = 'number',
}) {
  if (input == null) return const NumericCellInput.valid(null);
  if (input is num &&
      format.startsWith('duration') &&
      input.isFinite &&
      input.abs() > 9007199254740991) {
    return const NumericCellInput.invalid(NumericInputIssue.tooLarge);
  }
  if (input is num) {
    return input.isFinite
        ? NumericCellInput.valid(input)
        : const NumericCellInput.invalid(NumericInputIssue.nonFinite);
  }
  if (input is! String) {
    return NumericCellInput.invalid(
      format.startsWith('duration')
          ? NumericInputIssue.duration
          : NumericInputIssue.number,
    );
  }
  var text = input
      .trim()
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ')
      .replaceAll('−', '-');
  if (text.isEmpty) return const NumericCellInput.valid(null);
  if (RegExp(
    r'^[+-]?(nan|infinity|inf|∞)$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return const NumericCellInput.invalid(NumericInputIssue.nonFinite);
  }
  if (text.startsWith('=')) {
    return const NumericCellInput.invalid(NumericInputIssue.formula);
  }
  if (format == 'percent' && text.endsWith('%')) {
    text = text.substring(0, text.length - 1).trim();
  }
  if (format.startsWith('duration')) {
    final result = _duration(text);
    return result.valid && result.value!.abs() > 9007199254740991
        ? const NumericCellInput.invalid(NumericInputIssue.tooLarge)
        : result;
  }
  return _number(text);
}

NumericCellInput _number(String text) {
  if (text.contains(',') && text.contains('.')) {
    return const NumericCellInput.invalid(NumericInputIssue.separators);
  }
  if (text.contains(' ')) {
    if (!RegExp(r'^[+-]?\d{1,3}(?: \d{3})+(?:[.,]\d+)?$').hasMatch(text)) {
      return const NumericCellInput.invalid(NumericInputIssue.separators);
    }
    text = text.replaceAll(' ', '');
  }
  if (!RegExp(r'^[+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)(?:[eE][+-]?\d+)?$')
      .hasMatch(text)) {
    return NumericCellInput.invalid(
      RegExp(r'[+*/()^=]|\d\s*-\s*\d').hasMatch(text)
          ? NumericInputIssue.formula
          : NumericInputIssue.number,
    );
  }
  final number = num.tryParse(text.replaceAll(',', '.'));
  if (number == null || !number.isFinite) {
    return const NumericCellInput.invalid(NumericInputIssue.nonFinite);
  }
  return NumericCellInput.valid(number);
}

const _units = <String, num>{
  'd': 86400,
  'day': 86400,
  'days': 86400,
  'д': 86400,
  'дн': 86400,
  'день': 86400,
  'дня': 86400,
  'дней': 86400,
  'h': 3600,
  'hr': 3600,
  'hrs': 3600,
  'hour': 3600,
  'hours': 3600,
  'ч': 3600,
  'час': 3600,
  'часа': 3600,
  'часов': 3600,
  'm': 60,
  'min': 60,
  'mins': 60,
  'minute': 60,
  'minutes': 60,
  'м': 60,
  'мин': 60,
  'минута': 60,
  'минуты': 60,
  'минут': 60,
  's': 1,
  'sec': 1,
  'secs': 1,
  'second': 1,
  'seconds': 1,
  'с': 1,
  'сек': 1,
  'секунда': 1,
  'секунды': 1,
  'секунд': 1,
  'ms': 0.001,
  'msec': 0.001,
  'msecs': 0.001,
  'millisecond': 0.001,
  'milliseconds': 0.001,
  'мс': 0.001,
  'миллисекунда': 0.001,
  'миллисекунды': 0.001,
  'миллисекунд': 0.001,
};

NumericCellInput _duration(String text) {
  if (RegExp(r'[*/()^=]|\d\s*\+').hasMatch(text)) {
    return const NumericCellInput.invalid(NumericInputIssue.formula);
  }
  final plain = _number(text);
  if (plain.valid || plain.issue == NumericInputIssue.nonFinite) return plain;
  var sign = 1;
  if (text.startsWith('-') || text.startsWith('+')) {
    if (text.startsWith('-')) sign = -1;
    text = text.substring(1);
  }
  num total = 0;
  if (text.contains(':')) {
    final parts = text.split(':').map((s) => s.trim()).toList();
    if (parts.length < 2 || parts.length > 4) {
      return const NumericCellInput.invalid(NumericInputIssue.duration);
    }
    for (var i = 0; i < parts.length; i++) {
      final last = i == parts.length - 1;
      if (!(last ? RegExp(r'^\d+(?:[.,]\d+)?$') : RegExp(r'^\d+$')).hasMatch(
        parts[i],
      )) {
        return const NumericCellInput.invalid(NumericInputIssue.duration);
      }
      final value = num.tryParse(parts[i].replaceAll(',', '.'));
      if (value == null || !value.isFinite) {
        return const NumericCellInput.invalid(NumericInputIssue.nonFinite);
      }
      if (i > 0 && value >= (parts.length == 4 && i == 1 ? 24 : 60)) {
        return const NumericCellInput.invalid(NumericInputIssue.duration);
      }
      // Four components are D:H:M:S, rather than a base-60 day.
      total = i == 1 && parts.length == 4
          ? total * 24 + value
          : total * 60 + value;
    }
  } else {
    final tokens = RegExp(
      r'(\d+(?:[.,]\d+)?|[.,]\d+)\s*([a-zа-яё]+)',
      caseSensitive: false,
    ).allMatches(text);
    var end = 0, count = 0;
    final seen = <num>{};
    for (final token in tokens) {
      final unit = _units[token[2]!.toLowerCase()];
      if (text.substring(end, token.start).trim().isNotEmpty ||
          unit == null ||
          !seen.add(unit)) {
        return const NumericCellInput.invalid(NumericInputIssue.duration);
      }
      final value = num.tryParse(token[1]!.replaceAll(',', '.'));
      if (value == null || !value.isFinite) {
        return const NumericCellInput.invalid(NumericInputIssue.nonFinite);
      }
      total += value * unit;
      count++;
      end = token.end;
    }
    if (count == 0 || text.substring(end).trim().isNotEmpty) {
      return const NumericCellInput.invalid(NumericInputIssue.duration);
    }
  }
  total *= sign;
  return total.isFinite
      ? NumericCellInput.valid(total)
      : const NumericCellInput.invalid(NumericInputIssue.nonFinite);
}

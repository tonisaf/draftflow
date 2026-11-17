import '../../../../data/model/numeric_cell_input.dart';
import '../../../common/app_icons.dart';
export '../../../design_tokens.dart' show tagColorPresets;

import 'package:notes_here/ui/theme.dart';

import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
export 'package:notes_here/data/model/database_query.dart';

const String databaseBlockType = 'database';

Node databaseBlockNode({
  required String databaseId,
  String title = 'Untitled Table',
}) => Node(
  type: databaseBlockType,
  attributes: {'databaseId': databaseId, 'title': title},
);

IconData iconForColumnType(String type) {
  switch (type) {
    case 'title':
      return AppIcons.textformat;
    case 'number':
      return AppIcons.number;
    case 'select':
    case 'multi_select':
      return AppIcons.tag;
    case 'status':
      return AppIcons.circleLefthalfFill;
    case 'checkbox':
      return AppIcons.checkmarkSquare;
    case 'date':
      return AppIcons.calendar;
    case 'url':
      return AppIcons.link;
    default:
      return AppIcons.textAlignleft;
  }
}

String ruleLabel(DatabaseFilterRule rule, List<DatabaseColumn> columns) {
  final col = columns.firstWhere(
    (c) => c.id == rule.columnId,
    orElse: () => DatabaseColumn(
      id: '',
      databaseId: '',
      name: 'Column',
      type: 'text',
      width: UiLayout.fallbackColumnWidth,
      orderKey: 'a',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
  switch (rule.operator) {
    case 'is_true':
      return '${col.name}: Checked';
    case 'is_false':
      return '${col.name}: Unchecked';
    case 'is_empty':
      return '${col.name}: Empty';
    case 'is_not_empty':
      return '${col.name}: Not empty';
    case 'contains':
      if (col.type == 'multi_select' && col.options != null) {
        try {
          final opts = jsonDecode(col.options!) as List<dynamic>;
          final match = opts.firstWhere(
            (o) => o['id'] == rule.value,
            orElse: () => null,
          );
          if (match != null) {
            return '${col.name}: ${match['label'] ?? rule.value}';
          }
        } catch (_) {}
      }
      return '${col.name} ~ "${rule.value}"';
    case 'equals':
      String valLabel = rule.value?.toString() ?? '';
      if ((col.type == 'select' ||
              col.type == 'multi_select' ||
              col.type == 'status') &&
          col.options != null) {
        try {
          final opts = jsonDecode(col.options!) as List<dynamic>;
          final match = opts.firstWhere(
            (o) => o['id'] == rule.value,
            orElse: () => null,
          );
          if (match != null) valLabel = match['label']?.toString() ?? valLabel;
        } catch (_) {}
      }
      return '${col.name}: $valLabel';
    default:
      return col.name;
  }
}

List<DropdownMenuItem<String>> buildSelectFilterItems(DatabaseColumn column) {
  List<dynamic> options = [];
  if (column.options != null && column.options!.isNotEmpty) {
    try {
      options = jsonDecode(column.options!) as List<dynamic>;
    } catch (_) {}
  }

  return [
    for (final opt in options)
      DropdownMenuItem<String>(
        value: opt['id'].toString(),
        child: Text(
          opt['label'].toString(),
          style: const TextStyle(fontSize: UiType.body),
        ),
      ),
    const DropdownMenuItem<String>(
      value: '__is_not_empty__',
      child: Text(
        'Has tag (Not empty)',
        style: TextStyle(fontSize: UiType.body, fontStyle: FontStyle.italic),
      ),
    ),
    const DropdownMenuItem<String>(
      value: '__is_empty__',
      child: Text(
        'No tag (Empty)',
        style: TextStyle(fontSize: UiType.body, fontStyle: FontStyle.italic),
      ),
    ),
  ];
}

class NumberFormatDescriptor {
  final String id;
  final String label;
  final String? symbol;
  final bool symbolAfter;
  final bool useSeparators;
  final bool isDuration;
  final List<String> searchKeywords;

  const NumberFormatDescriptor({
    required this.id,
    required this.label,
    this.symbol,
    this.symbolAfter = false,
    this.useSeparators = true,
    this.isDuration = false,
    this.searchKeywords = const [],
  });
}

const List<NumberFormatDescriptor> kNumberFormats = [
  NumberFormatDescriptor(id: 'number', label: 'Number', useSeparators: false),
  NumberFormatDescriptor(
    id: 'number_with_separators',
    label: 'Number with separators',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'percent',
    label: 'Percent',
    symbol: '%',
    symbolAfter: true,
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'duration_human',
    label: 'Duration (e.g. 1d 2h 30m 15s)',
    useSeparators: false,
    isDuration: true,
    searchKeywords: [
      'duration',
      'time',
      'время',
      'длительность',
      'дни',
      'часы',
      'минуты',
      'секунды',
      'дней',
      'часов',
      'минут',
      'секунд',
      'days',
      'hours',
      'minutes',
      'seconds',
    ],
  ),
  NumberFormatDescriptor(
    id: 'duration_hms',
    label: 'Time (hh:mm:ss)',
    useSeparators: false,
    isDuration: true,
    searchKeywords: [
      'time',
      'hh:mm:ss',
      'duration',
      'время',
      'длительность',
      'часы',
      'минуты',
      'секунды',
    ],
  ),
  NumberFormatDescriptor(
    id: 'duration_ms',
    label: 'Time (mm:ss)',
    useSeparators: false,
    isDuration: true,
    searchKeywords: ['time', 'mm:ss', 'duration', 'время', 'минуты', 'секунды'],
  ),
  NumberFormatDescriptor(
    id: 'days',
    label: 'Days (d)',
    symbol: 'd',
    symbolAfter: true,
    useSeparators: false,
    searchKeywords: ['days', 'дни', 'день', 'дней', 'сутки'],
  ),
  NumberFormatDescriptor(
    id: 'hours',
    label: 'Hours (h)',
    symbol: 'h',
    symbolAfter: true,
    useSeparators: false,
    searchKeywords: ['hours', 'часы', 'час', 'часов'],
  ),
  NumberFormatDescriptor(
    id: 'minutes',
    label: 'Minutes (min)',
    symbol: 'm',
    symbolAfter: true,
    useSeparators: false,
    searchKeywords: ['minutes', 'минуты', 'минут', 'мин'],
  ),
  NumberFormatDescriptor(
    id: 'seconds',
    label: 'Seconds (s)',
    symbol: 's',
    symbolAfter: true,
    useSeparators: false,
    searchKeywords: ['seconds', 'секунды', 'секунд', 'сек'],
  ),
  NumberFormatDescriptor(
    id: 'milliseconds',
    label: 'Milliseconds (ms)',
    symbol: 'ms',
    symbolAfter: true,
    useSeparators: false,
    searchKeywords: ['milliseconds', 'миллисекунды', 'мс'],
  ),
  NumberFormatDescriptor(
    id: 'usd',
    label: 'US Dollar (USD)',
    symbol: r'$',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'aud',
    label: 'Australian dollar (AUD)',
    symbol: r'A$',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'cad',
    label: 'Canadian dollar (CAD)',
    symbol: r'CA$',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'sgd',
    label: 'Singapore dollar (SGD)',
    symbol: r'S$',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'eur',
    label: 'Euro (EUR)',
    symbol: '€',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'gbp',
    label: 'Pound (GBP)',
    symbol: '£',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'jpy',
    label: 'Yen (JPY)',
    symbol: '¥',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'rub',
    label: 'Ruble (RUB)',
    symbol: '₽',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'inr',
    label: 'Rupee (INR)',
    symbol: '₹',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'krw',
    label: 'Won (KRW)',
    symbol: '₩',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'cny',
    label: 'Yuan (CNY)',
    symbol: '¥',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'brl',
    label: 'Real (BRL)',
    symbol: r'R$',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'try',
    label: 'Lira (TRY)',
    symbol: '₺',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'chf',
    label: 'Swiss Franc (CHF)',
    symbol: 'CHF ',
    useSeparators: true,
  ),
  NumberFormatDescriptor(
    id: 'nzd',
    label: 'New Zealand dollar (NZD)',
    symbol: r'NZ$',
    useSeparators: true,
  ),
];

class NumberColumnConfig {
  final String format;
  final int? decimalPlaces;
  final String showAs; // 'number', 'bar', 'ring'
  final double maxValue;
  final int? color;

  const NumberColumnConfig({
    this.format = 'number',
    this.decimalPlaces,
    this.showAs = 'number',
    this.maxValue = 100.0,
    this.color,
  });

  factory NumberColumnConfig.fromJson(Map<String, dynamic> json) {
    return NumberColumnConfig(
      format: json['format'] as String? ?? 'number',
      decimalPlaces: json['decimalPlaces'] as int?,
      showAs: json['showAs'] as String? ?? 'number',
      maxValue: (json['maxValue'] as num?)?.toDouble() ?? 100.0,
      color: json['color'] as int?,
    );
  }

  factory NumberColumnConfig.fromOptions(String? options) {
    if (options == null || options.trim().isEmpty) {
      return const NumberColumnConfig();
    }
    try {
      final decoded = jsonDecode(options);
      if (decoded is Map<String, dynamic>) {
        return NumberColumnConfig.fromJson(decoded);
      }
    } catch (_) {}
    return const NumberColumnConfig();
  }

  Map<String, dynamic> toJson() => {
    'format': format,
    'decimalPlaces': decimalPlaces,
    'showAs': showAs,
    'maxValue': maxValue,
    if (color != null) 'color': color,
  };

  String toOptions() => jsonEncode(toJson());

  NumberColumnConfig copyWith({
    String? format,
    int? Function()? decimalPlaces,
    String? showAs,
    double? maxValue,
    int? Function()? color,
  }) {
    return NumberColumnConfig(
      format: format ?? this.format,
      decimalPlaces: decimalPlaces != null
          ? decimalPlaces()
          : this.decimalPlaces,
      showAs: showAs ?? this.showAs,
      maxValue: maxValue ?? this.maxValue,
      color: color != null ? color() : this.color,
    );
  }
}

num? parseDurationToSeconds(String input) =>
    parseNumericCellInput(input, format: 'duration_human').value;

String formatDurationHuman(num seconds) {
  if (seconds == 0) return '0s';
  if (seconds != seconds.truncateToDouble()) return '${seconds}s';
  final isNeg = seconds < 0;
  var sec = seconds.abs().truncate();
  final days = sec ~/ 86400;
  sec %= 86400;
  final hours = sec ~/ 3600;
  sec %= 3600;
  final minutes = sec ~/ 60;
  final remainingSec = sec % 60;

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}m');
  if (remainingSec > 0 || parts.isEmpty) parts.add('${remainingSec}s');

  final res = parts.join(' ');
  return isNeg ? '-$res' : res;
}

String formatDurationHms(num seconds) {
  final isNeg = seconds < 0;
  var sec = seconds.abs().truncate();
  final hours = sec ~/ 3600;
  sec %= 3600;
  final minutes = sec ~/ 60;
  final remainingSec = sec % 60;
  final hStr = hours.toString().padLeft(2, '0');
  final mStr = minutes.toString().padLeft(2, '0');
  final raw = seconds.abs().toString();
  if (raw.contains('e')) return '${seconds}s';
  final suffix = seconds == seconds.truncateToDouble()
      ? ''
      : raw.substring(raw.indexOf('.'));
  final sStr = remainingSec.toString().padLeft(2, '0') + suffix;
  final res = '$hStr:$mStr:$sStr';
  return isNeg ? '-$res' : res;
}

String formatDurationMs(num seconds) {
  final isNeg = seconds < 0;
  var sec = seconds.abs().truncate();
  final minutes = sec ~/ 60;
  final remainingSec = sec % 60;
  final mStr = minutes.toString().padLeft(2, '0');
  final raw = seconds.abs().toString();
  if (raw.contains('e')) return '${seconds}s';
  final suffix = seconds == seconds.truncateToDouble()
      ? ''
      : raw.substring(raw.indexOf('.'));
  final sStr = remainingSec.toString().padLeft(2, '0') + suffix;
  final res = '$mStr:$sStr';
  return isNeg ? '-$res' : res;
}

String formatNumberValue(num value, NumberColumnConfig config) {
  if (value.isNaN || value.isInfinite) return '0';

  final descriptor = kNumberFormats.firstWhere(
    (f) => f.id == config.format,
    orElse: () => kNumberFormats.first,
  );

  if (descriptor.isDuration) {
    if (config.format == 'duration_human') {
      return formatDurationHuman(value);
    } else if (config.format == 'duration_hms') {
      return formatDurationHms(value);
    } else if (config.format == 'duration_ms') {
      return formatDurationMs(value);
    }
  }

  final isNegative = value < 0;
  final absValue = isNegative ? -value : value;

  String formattedNumber;
  if (absValue >= 9e18) {
    formattedNumber = absValue.toString();
  } else if (config.decimalPlaces != null) {
    formattedNumber = absValue.toStringAsFixed(config.decimalPlaces!);
  } else {
    if (absValue == absValue.truncateToDouble()) {
      formattedNumber = absValue.toInt().toString();
    } else {
      final fixed = absValue.toStringAsFixed(6);
      formattedNumber = fixed
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
  }

  if (descriptor.useSeparators && !formattedNumber.contains('e')) {
    final parts = formattedNumber.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = integerPart.replaceAllMapped(
      reg,
      (Match m) => '${m[1]},',
    );
    formattedNumber = '$formattedInt$decimalPart';
  }

  final symbol = descriptor.symbol ?? '';
  String result;
  if (symbol.isEmpty) {
    result = formattedNumber;
  } else if (descriptor.symbolAfter) {
    result = '$formattedNumber$symbol';
  } else {
    result = '$symbol$formattedNumber';
  }

  return isNegative ? '-$result' : result;
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 2.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -3.141592653589793 / 2;
      final sweepAngle = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

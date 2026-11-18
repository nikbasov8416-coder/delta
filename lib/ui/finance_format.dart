import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';

String groupedDigits(String value) => value.replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]}\u00a0',
);

String formatDecimal(
  Decimal value, {
  int precision = 2,
  bool trimZeros = false,
}) {
  final parts = value
      .round(scale: precision)
      .toStringAsFixed(precision)
      .split('.');
  final whole = groupedDigits(parts.first);
  if (parts.length == 1) return whole;
  final fraction = trimZeros
      ? parts.last.replaceFirst(RegExp(r'0+$'), '')
      : parts.last;
  return fraction.isEmpty ? whole : '$whole,$fraction';
}

String displayDate(String iso, {bool short = false}) {
  final date = DateTime.parse(iso);
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return short ? '$day.$month' : '$day.$month.${date.year}';
}

class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  static String group(String input) {
    final parts = input
        .replaceAll(RegExp('[ \\u00a0\\u202f]'), '')
        .replaceAll('.', ',')
        .split(',');
    return [groupedDigits(parts.first), ...parts.skip(1)].join(',');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final raw = newValue.text.replaceAll(RegExp('[ \\u00a0\\u202f]'), '');
    if (!RegExp(r'^\d*(?:[.,]\d*)?$').hasMatch(raw)) return oldValue;
    final formatted = group(raw);
    final suffix = newValue.selection.end < 0
        ? ''
        : newValue.text
              .substring(newValue.selection.end)
              .replaceAll(RegExp('[ \\u00a0\\u202f]'), '');
    var cursor = formatted.length;
    var remaining = suffix.length;
    while (cursor > 0 && remaining > 0) {
      cursor--;
      if (formatted[cursor] != '\u00a0') remaining--;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

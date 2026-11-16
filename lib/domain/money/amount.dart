import 'package:decimal/decimal.dart';

import 'currency.dart';

/// Внешние суммы поступают строками: преобразования из double запрещены.
Decimal parseAmount(String value, Currency currency) {
  value = normalizeNumberInput(value);
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    throw FormatException('Ожидается неотрицательное десятичное число');
  }
  final amount = Decimal.parse(value);
  if (amount.scale > currency.precision) {
    throw FormatException('Превышена точность валюты ${currency.code}');
  }
  return amount;
}

/// Допускает десятичную запятую и корректные группы по три цифры.
/// Знак минуса, экспоненты и смешанные десятичные разделители запрещены.
String normalizeNumberInput(String input) {
  final value = input
      .trim()
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ');
  if (!RegExp(r'^(?:\d+|\d{1,3}(?: \d{3})+)(?:[.,]\d+)?$').hasMatch(value)) {
    throw const FormatException(
      'Введите неотрицательное число, например 1 234,56',
    );
  }
  return value.replaceAll(' ', '').replaceAll(',', '.');
}

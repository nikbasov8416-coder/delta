import 'package:decimal/decimal.dart';

import 'currency.dart';

/// Внешние суммы поступают строками: преобразования из double запрещены.
Decimal parseAmount(String value, Currency currency) {
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    throw FormatException('Ожидается неотрицательное десятичное число');
  }
  final amount = Decimal.parse(value);
  if (amount.scale > currency.precision) {
    throw FormatException('Превышена точность валюты ${currency.code}');
  }
  return amount;
}

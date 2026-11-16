import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../domain/rates/rates.dart';

/// Числовые лексемы остаются строками: JSON-цены не проходят через double.
Object? decodeExactJson(String source) {
  final output = StringBuffer();
  var inString = false, escaped = false;
  final number = RegExp(r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?');
  for (var i = 0; i < source.length;) {
    final c = source[i];
    if (inString) {
      output.write(c);
      i++;
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
    } else if (c == '"') {
      inString = true;
      output.write(c);
      i++;
    } else if (c == '-' || RegExp(r'\d').hasMatch(c)) {
      final match = number.matchAsPrefix(source, i);
      if (match == null) {
        throw const RateFailure('Неверный числовой ответ источника');
      }
      output.write(jsonEncode(match.group(0)));
      i = match.end;
    } else {
      output.write(c);
      i++;
    }
  }
  try {
    return jsonDecode(output.toString());
  } catch (_) {
    throw const RateFailure('Источник вернул неверный JSON');
  }
}

Decimal positiveRate(Object? value) {
  if (value is! String || value.length > 100) {
    throw const RateFailure('Источник вернул неверную цену');
  }
  // Ограничиваем экспоненту до преобразования больших BigInt.
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d{1,2}))?$')
      .firstMatch(value);
  if (match == null) throw const RateFailure('Источник вернул неверную цену');
  final exponent = int.parse(match.group(3) ?? '0');
  if (exponent.abs() > 30) {
    throw const RateFailure('Цена вне допустимого диапазона');
  }
  final result = Decimal.parse('${match.group(1)}.${match.group(2) ?? '0'}')
      .shift(exponent);
  if (result <= Decimal.zero) {
    throw const RateFailure('Курс должен быть положительным');
  }
  return result;
}

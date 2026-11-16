import 'package:decimal/decimal.dart';
import 'package:delta/domain/money/amount.dart';
import 'package:delta/domain/money/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0.1 + 0.2 точно равно 0.3', () {
    expect(Decimal.parse('0.1') + Decimal.parse('0.2'), Decimal.parse('0.3'));
  });

  test('Большие суммы не теряют копейки', () {
    expect(
      Decimal.parse('9007199254740993.01') + Decimal.parse('0.02'),
      Decimal.parse('9007199254740993.03'),
    );
  });

  test('Точность RUB/USD/EUR, USDT и BTC', () {
    for (final code in ['RUB', 'USD', 'EUR']) {
      expect(parseAmount('12.34', Currency(code, 2)), Decimal.parse('12.34'));
      expect(
        () => parseAmount('12.345', Currency(code, 2)),
        throwsFormatException,
      );
    }
    expect(
      parseAmount('0.000001', Currency('USDT', 6)),
      Decimal.parse('0.000001'),
    );
    expect(
      parseAmount('0.00000001', Currency('BTC', 8)),
      Decimal.parse('0.00000001'),
    );
    expect(
      () => parseAmount('0.000000001', Currency('BTC', 8)),
      throwsFormatException,
    );
  });

  test('Запятая и пробелы нормализуются', () {
    for (final value in [
      '1 234,56',
      '1\u00a0234,56',
      '1\u202f234.56',
      ' 1234,56 ',
    ]) {
      expect(parseAmount(value, Currency('RUB', 2)), Decimal.parse('1234.56'));
    }
  });

  test('Неверный ввод не превращается в деньги', () {
    for (final value in ['-1', 'NaN', '1e6', '1,2.3', '1 23', '']) {
      expect(
        () => parseAmount(value, Currency('RUB', 2)),
        throwsFormatException,
      );
    }
  });
}

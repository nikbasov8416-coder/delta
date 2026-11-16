import 'package:decimal/decimal.dart';
import 'package:delta/data/database/decimal_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Десятичная сумма проходит через TEXT без потери точности', () {
    const converter = DecimalConverter();
    final amount = Decimal.parse('9007199254740993.00000001');
    expect(converter.toSql(amount), '9007199254740993.00000001');
    expect(converter.fromSql(converter.toSql(amount)), amount);
  });
}

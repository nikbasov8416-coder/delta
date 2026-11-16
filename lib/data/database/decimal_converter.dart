import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

/// Денежные значения в SQLite — только TEXT, без REAL и double.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}

import 'package:decimal/decimal.dart';
import 'package:sqlite3/sqlite3.dart';

/// Ограничения схемы без преобразований TEXT в REAL.
/// Чистые арифметические функции без IO разрешены внутри CHECK.
void installDecimalFunctions(Database database) {
  Decimal? parse(Object? value) {
    if (value is! String || !RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
      return null;
    }
    return Decimal.tryParse(value);
  }

  database.createFunction(
    functionName: 'delta_decimal_valid',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    directOnly: false,
    function: (args) => parse(args[0]) != null ? 1 : 0,
  );
  database.createFunction(
    functionName: 'delta_decimal_positive',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    directOnly: false,
    function: (args) => (parse(args[0]) ?? Decimal.zero) > Decimal.zero ? 1 : 0,
  );
  database.createFunction(
    functionName: 'delta_decimal_le',
    argumentCount: const AllowedArgumentCount(2),
    deterministic: true,
    directOnly: false,
    function: (args) {
      final a = parse(args[0]);
      final b = parse(args[1]);
      return a != null && b != null && a <= b ? 1 : 0;
    },
  );
}

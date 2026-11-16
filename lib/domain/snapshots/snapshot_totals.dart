import 'package:decimal/decimal.dart';

/// Строка слепка. Все данные здесь переданы вызывающей стороной.
final class SnapshotPosition {
  SnapshotPosition({
    required this.storageId,
    required this.currencyCode,
    required this.liquidityId,
    required this.amount,
    required this.familyAmount,
  }) {
    if (amount < Decimal.zero ||
        familyAmount < Decimal.zero ||
        familyAmount > amount) {
      throw ArgumentError('Семейная часть должна быть от нуля до суммы');
    }
  }

  final String storageId;
  final String currencyCode;
  final String liquidityId;
  final Decimal amount;
  final Decimal familyAmount;
}

final class AmountTotals {
  const AmountTotals({required this.total, required this.family});

  final Decimal total;
  final Decimal family;
  Decimal get personal => total - family;

  AmountTotals add(Decimal amount, Decimal familyAmount) =>
      AmountTotals(total: total + amount, family: family + familyAmount);
}

final class SnapshotTotals {
  const SnapshotTotals({
    required this.rubles,
    required this.byCurrency,
    required this.byStorageRubles,
    required this.byLiquidityRubles,
  });

  final AmountTotals rubles;
  final Map<String, AmountTotals> byCurrency;
  final Map<String, AmountTotals> byStorageRubles;
  final Map<String, AmountTotals> byLiquidityRubles;
}

/// Курсы выбираются снаружи: зафиксированные или сегодняшние.
/// Округление — только при отображении, после сложения всех произведений.
SnapshotTotals calculateTotals(
  Iterable<SnapshotPosition> positions,
  Map<String, Decimal> rubleRates,
) {
  final zero = AmountTotals(total: Decimal.zero, family: Decimal.zero);
  var rubles = zero;
  final byCurrency = <String, AmountTotals>{};
  final byStorage = <String, AmountTotals>{};
  final byLiquidity = <String, AmountTotals>{};
  final seen = <(String, String)>{};
  final liquidityByStorage = <String, String>{};

  for (final line in positions) {
    if (!seen.add((line.storageId, line.currencyCode))) {
      throw ArgumentError('Повтор пары место хранения / валюта');
    }
    final previous = liquidityByStorage[line.storageId];
    if (previous != null && previous != line.liquidityId) {
      throw ArgumentError('Ликвидность задаётся месту хранения целиком');
    }
    liquidityByStorage[line.storageId] = line.liquidityId;
    final rate = rubleRates[line.currencyCode];
    if (rate == null ||
        rate <= Decimal.zero ||
        (line.currencyCode == 'RUB' && rate != Decimal.one)) {
      throw ArgumentError('Нет корректного курса ${line.currencyCode}');
    }
    final amount = line.amount * rate;
    final family = line.familyAmount * rate;
    rubles = rubles.add(amount, family);
    byCurrency.update(
      line.currencyCode,
      (old) => old.add(line.amount, line.familyAmount),
      ifAbsent: () => zero.add(line.amount, line.familyAmount),
    );
    byStorage.update(
      line.storageId,
      (old) => old.add(amount, family),
      ifAbsent: () => zero.add(amount, family),
    );
    byLiquidity.update(
      line.liquidityId,
      (old) => old.add(amount, family),
      ifAbsent: () => zero.add(amount, family),
    );
  }
  return SnapshotTotals(
    rubles: rubles,
    byCurrency: Map.unmodifiable(byCurrency),
    byStorageRubles: Map.unmodifiable(byStorage),
    byLiquidityRubles: Map.unmodifiable(byLiquidity),
  );
}

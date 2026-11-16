import 'package:decimal/decimal.dart';
import 'package:delta/domain/snapshots/snapshot_totals.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String value) => Decimal.parse(value);

SnapshotPosition line(
  String storage,
  String currency,
  String amount,
  String family, {
  String liquidity = 'instant',
}) => SnapshotPosition(
  storageId: storage,
  currencyCode: currency,
  liquidityId: liquidity,
  amount: d(amount),
  familyAmount: d(family),
);

void main() {
  // Только выдуманные примеры, без реальных счетов или остатков.
  final rows = [
    line('sample-wallet', 'RUB', '100.10', '20'),
    line('sample-wallet', 'USD', '2.50', '0.50'),
    line('sample-investment', 'USD', '1', '0', liquidity: 'long-term'),
    line('sample-crypto', 'BTC', '0.00000001', '0'),
  ];
  final rates = {'RUB': d('1'), 'USD': d('90.25'), 'BTC': d('6000000')};

  test('Итоги, валюты, места, ликвидность и семейная часть', () {
    final result = calculateTotals(rows, rates);
    expect(result.rubles.total, d('416.035'));
    expect(result.rubles.family, d('65.125'));
    expect(result.rubles.personal, d('350.910'));
    expect(result.byCurrency['USD']!.total, d('3.50'));
    expect(result.byCurrency['USD']!.family, d('0.50'));
    expect(result.byStorageRubles['sample-wallet']!.total, d('325.725'));
    expect(result.byLiquidityRubles['instant']!.total, d('325.785'));
    expect(result.byLiquidityRubles['long-term']!.total, d('90.25'));
  });

  test('Выбор других курсов меняет оценку, но не исходные суммы', () {
    final result = calculateTotals(rows, {...rates, 'USD': d('100')});
    expect(result.rubles.total, d('450.16'));
    expect(result.byCurrency['USD']!.total, d('3.5'));
  });

  test('Пустой слепок', () {
    final result = calculateTotals([], {});
    expect(result.rubles.total, Decimal.zero);
    expect(result.rubles.personal, Decimal.zero);
    expect(result.byCurrency, isEmpty);
  });

  test('Нет курса, нулевой курс и неверный курс RUB — ошибки', () {
    expect(() => calculateTotals(rows, {'RUB': d('1')}), throwsArgumentError);
    expect(
      () => calculateTotals(rows, {...rates, 'USD': d('0')}),
      throwsArgumentError,
    );
    expect(
      () => calculateTotals(rows, {...rates, 'RUB': d('2')}),
      throwsArgumentError,
    );
  });

  test('Дубли и разная ликвидность валют одного места запрещены', () {
    expect(
      () => calculateTotals([rows.first, rows.first], rates),
      throwsArgumentError,
    );
    expect(
      () => calculateTotals([
        rows.first,
        line('sample-wallet', 'USD', '1', '0', liquidity: 'other'),
      ], rates),
      throwsArgumentError,
    );
  });

  test('Границы семейной части', () {
    expect(line('a', 'RUB', '1', '1').familyAmount, d('1'));
    for (final pair in [('1', '2'), ('1', '-1'), ('-1', '0')]) {
      expect(() => line('a', 'RUB', pair.$1, pair.$2), throwsArgumentError);
    }
  });
}

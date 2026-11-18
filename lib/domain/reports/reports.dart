import 'package:decimal/decimal.dart';

import '../snapshots/snapshot_totals.dart';

enum ReportPeriod { all, year, halfYear }

enum ReportChart { total, liquidity, currency, family }

/// Пригодные для расчётов слепки и даты слепков, которым нужно обновить курсы.
class ReportData {
  ReportData(
    List<ReportSnapshot> snapshots, {
    List<String> excludedDates = const [],
  }) : snapshots = List.unmodifiable(snapshots),
       excludedDates = List.unmodifiable(excludedDates);
  final List<ReportSnapshot> snapshots;
  final List<String> excludedDates;
}

class ReportPosition {
  const ReportPosition({
    required this.storageId,
    required this.storageName,
    required this.currency,
    required this.precision,
    required this.liquidityId,
    required this.liquidityName,
    required this.amount,
    required this.family,
    this.kind = '',
    this.liquidityOrder = 0,
    this.liquidityColor = 0xff26a69a,
  });
  final String storageId, storageName, currency, liquidityId, liquidityName;
  final String kind;
  final int precision, liquidityOrder, liquidityColor;
  final Decimal amount, family;
}

class ReportSnapshot {
  ReportSnapshot({
    required this.id,
    required this.date,
    required List<ReportPosition> positions,
    required Map<String, Decimal> rates,
  }) : positions = List.unmodifiable(positions),
       rates = Map.unmodifiable({'RUB': Decimal.one, ...rates}) {
    if (this.rates['RUB'] != Decimal.one) {
      throw ArgumentError('Курс RUB должен быть равен 1');
    }
  }
  final String id, date;
  final List<ReportPosition> positions;
  final Map<String, Decimal> rates;
  late final SnapshotTotals totals = calculateTotals(
    positions.map(
      (p) => SnapshotPosition(
        storageId: p.storageId,
        currencyCode: p.currency,
        liquidityId: p.liquidityId,
        amount: p.amount,
        familyAmount: p.family,
      ),
    ),
    rates,
  );
}

List<ReportSnapshot> reportPeriod(
  List<ReportSnapshot> snapshots,
  ReportPeriod period,
  DateTime now,
) {
  if (period == ReportPeriod.all) return List.unmodifiable(snapshots);
  final month =
      now.year * 12 + now.month - 1 - (period == ReportPeriod.year ? 12 : 6);
  final y = month ~/ 12,
      m = month % 12 + 1,
      last = DateTime.utc(y, m + 1, 0).day;
  final from = DateTime.utc(y, m, now.day > last ? last : now.day);
  final until = DateTime.utc(now.year, now.month, now.day);
  return snapshots.where((s) {
    final d = DateTime.parse('${s.date}T00:00:00Z');
    return !d.isBefore(from) && !d.isAfter(until);
  }).toList();
}

class ReportSeries {
  const ReportSeries(this.name, this.values, {this.color});
  final String name;
  final int? color;
  final List<Decimal> values;
}

List<ReportSeries> reportSeries(
  List<ReportSnapshot> snapshots,
  ReportChart chart,
) {
  if (chart == ReportChart.total) {
    return [
      ReportSeries('Всего', [for (final s in snapshots) s.totals.rubles.total]),
    ];
  }
  if (chart == ReportChart.family) {
    return [
      ReportSeries('Личные', [
        for (final s in snapshots) s.totals.rubles.personal,
      ]),
      ReportSeries('Семейные', [
        for (final s in snapshots) s.totals.rubles.family,
      ]),
    ];
  }
  if (chart == ReportChart.currency) {
    final codes =
        snapshots
            .expand((s) => s.positions.map((p) => p.currency))
            .toSet()
            .toList()
          ..sort();
    return [
      for (final code in codes)
        ReportSeries(code, [
          for (final s in snapshots)
            s.totals.byCurrencyRubles[code]?.total ?? Decimal.zero,
        ]),
    ];
  }
  final levels = {
    for (final s in snapshots)
      for (final p in s.positions) p.liquidityId: p,
  };
  final keys = levels.keys.toList()
    ..sort((a, b) {
      final byOrder = levels[a]!.liquidityOrder.compareTo(
        levels[b]!.liquidityOrder,
      );
      return byOrder == 0 ? a.compareTo(b) : byOrder;
    });
  // Каждая следующая линия — сумма уровней до неё включительно (накопление).
  return [
    for (var i = 0; i < keys.length; i++)
      ReportSeries(levels[keys[i]]!.liquidityName, [
        for (final s in snapshots)
          keys
              .take(i + 1)
              .fold(
                Decimal.zero,
                (sum, key) =>
                    sum +
                    (s.totals.byLiquidityRubles[key]?.total ?? Decimal.zero),
              ),
      ], color: levels[keys[i]]!.liquidityColor),
  ];
}

class ComparisonAmount {
  Decimal before = Decimal.zero,
      after = Decimal.zero,
      balance = Decimal.zero,
      fx = Decimal.zero;
  final nativeBefore = <String, Decimal>{}, nativeAfter = <String, Decimal>{};
  Decimal get delta => after - before;
  Map<String, Decimal> get nativeDelta => {
    for (final code in {...nativeBefore.keys, ...nativeAfter.keys})
      code:
          (nativeAfter[code] ?? Decimal.zero) -
          (nativeBefore[code] ?? Decimal.zero),
  };
  void add(String code, Decimal a, Decimal b, Decimal r1, Decimal r2) {
    before += a * r1;
    after += b * r2;
    balance += (b - a) * r1;
    fx += b * (r2 - r1);
    nativeBefore.update(code, (v) => v + a, ifAbsent: () => a);
    nativeAfter.update(code, (v) => v + b, ifAbsent: () => b);
  }
}

class SnapshotComparison {
  final total = ComparisonAmount();
  final byStorage = <String, ComparisonAmount>{},
      byCurrency = <String, ComparisonAmount>{},
      byLiquidity = <String, ComparisonAmount>{};
  final storageNames = <String, String>{}, liquidityNames = <String, String>{};
}

SnapshotComparison compareSnapshots(
  ReportSnapshot first,
  ReportSnapshot second,
) {
  // Проверяем собственные курсы обеих сторон, не маскируем неполный слепок.
  first.totals;
  second.totals;
  final result = SnapshotComparison();
  final a = {for (final p in first.positions) (p.storageId, p.currency): p};
  final b = {for (final p in second.positions) (p.storageId, p.currency): p};
  for (final key in {...a.keys, ...b.keys}) {
    final before = a[key], after = b[key], p = after ?? before!;
    final q1 = before?.amount ?? Decimal.zero,
        q2 = after?.amount ?? Decimal.zero;
    final r1 = first.rates[p.currency] ?? second.rates[p.currency]!;
    final r2 = second.rates[p.currency] ?? first.rates[p.currency]!;
    result.total.add(p.currency, q1, q2, r1, r2);
    result.byStorage
        .putIfAbsent(p.storageId, ComparisonAmount.new)
        .add(p.currency, q1, q2, r1, r2);
    result.byCurrency
        .putIfAbsent(p.currency, ComparisonAmount.new)
        .add(p.currency, q1, q2, r1, r2);
    result.byLiquidity
        .putIfAbsent(p.liquidityId, ComparisonAmount.new)
        .add(p.currency, q1, q2, r1, r2);
    result.storageNames[p.storageId] = p.storageName;
    result.liquidityNames[p.liquidityId] = p.liquidityName;
  }
  return result;
}

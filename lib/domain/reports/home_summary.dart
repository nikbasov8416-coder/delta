import 'package:decimal/decimal.dart';

import '../rates/rates.dart';
import 'reports.dart';

const snapshotReminderDays = 30;

int? daysSinceSnapshot(String date, DateTime now) {
  final age = calendarDay(now)
      .difference(DateTime.parse('${date}T00:00:00Z'))
      .inDays;
  return age > snapshotReminderDays ? age : null;
}

/// Передаются только действующие слепки, в хронологическом порядке.
List<ReportSnapshot> homeValuations(
  List<ReportSnapshot> snapshots, {
  Map<String, Decimal>? today,
}) => today == null
    ? snapshots
    : [
        for (final snapshot in snapshots)
          ReportSnapshot(
            id: snapshot.id,
            date: snapshot.date,
            positions: snapshot.positions,
            rates: today,
          ),
      ];

({Decimal amount, Decimal? percent})? changeFromPrevious(
  List<ReportSnapshot> snapshots,
) {
  if (snapshots.length < 2) return null;
  final previous = snapshots[snapshots.length - 2].totals.rubles.total;
  final amount = snapshots.last.totals.rubles.total - previous;
  return (
    amount: amount,
    percent: previous == Decimal.zero
        ? null
        : (amount * Decimal.fromInt(100) / previous).toDecimal(
            scaleOnInfinitePrecision: 8,
          ),
  );
}

typedef LiquidityShare = ({
  String name,
  int color,
  Decimal amount,
  Decimal percent,
});

List<LiquidityShare> liquidityShares(ReportSnapshot snapshot) {
  final values = snapshot.totals.byLiquidityRubles;
  final levels = {
    for (final position in snapshot.positions) position.liquidityId: position,
  };
  final used =
      levels.values
          .where((level) => values[level.liquidityId]!.total > Decimal.zero)
          .toList()
        ..sort((a, b) {
          final order = a.liquidityOrder.compareTo(b.liquidityOrder);
          return order == 0 ? a.liquidityId.compareTo(b.liquidityId) : order;
        });
  return [
    for (final level in used)
      (
        name: level.liquidityName,
        color: level.liquidityColor,
        amount: values[level.liquidityId]!.total,
        percent:
            (values[level.liquidityId]!.total *
                    Decimal.fromInt(100) /
                    snapshot.totals.rubles.total)
                .toDecimal(scaleOnInfinitePrecision: 8),
      ),
  ];
}

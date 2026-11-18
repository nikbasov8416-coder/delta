import 'package:decimal/decimal.dart';

import '../rates/rates.dart';
import '../snapshots/snapshot_totals.dart';

/// Неизменяемая проекция сущности для экранов. Суммы остаются строками Decimal.
class FinanceRecord {
  FinanceRecord(Map<String, Object?> values)
    : values = Map.unmodifiable(values);
  final Map<String, Object?> values;
  String get id => text('id');
  String text(String field) => values[field]?.toString() ?? '';
  int number(String field) => (values[field] as int?) ?? 0;
  bool flag(String field) => number(field) != 0;
  Decimal decimal(String field) => Decimal.parse(text(field));
}

class FinanceOverview {
  const FinanceOverview({
    required this.currencies,
    required this.liquidity,
    required this.storages,
    required this.storageCurrencies,
    required this.snapshots,
  });
  final List<FinanceRecord> currencies;
  final List<FinanceRecord> liquidity;
  final List<FinanceRecord> storages;
  final List<FinanceRecord> storageCurrencies;
  final List<FinanceRecord> snapshots;
}

class SnapshotDetail {
  const SnapshotDetail(
    this.header,
    this.lines,
    this.rates,
    this.audit, {
    this.rateErrors = const {},
    this.missingStorages = const [],
  });
  final FinanceRecord header;
  final List<FinanceRecord> lines;
  final List<FinanceRecord> rates;
  final List<FinanceRecord> audit;
  final Map<String, String> rateErrors;
  final List<FinanceRecord> missingStorages;
}

class SnapshotValuation {
  const SnapshotValuation(this.totals, this.rates);
  final SnapshotTotals totals;
  final List<RateQuote> rates;
}

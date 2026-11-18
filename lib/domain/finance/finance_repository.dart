import 'package:decimal/decimal.dart';

import 'records.dart';
import '../reports/reports.dart';
import '../snapshots/snapshot_totals.dart';
import '../rates/rates.dart';

abstract interface class FinanceRepository {
  Future<void> initialize();
  Future<FinanceOverview> overview();
  Future<void> saveCurrency({
    String? id,
    required String code,
    required String name,
    required String kind,
    required int precision,
  });
  Future<void> saveLiquidity({
    String? id,
    required String name,
    required int order,
    required int color,
  });
  Future<void> saveStorage({
    String? id,
    required String name,
    required String type,
    required String liquidityId,
    required String organization,
    required String note,
    required bool archived,
    required List<String> currencyIds,
  });
  Future<void> removeCatalogEntry(String catalog, String id);
  Future<String> createSnapshot(String date, String note);
  Future<SnapshotDetail> snapshot(String id);
  Future<void> saveLine(String id, String amount, String family, String note);
  Future<void> confirmLine(String id);
  Future<int> confirmUnreviewed(String snapshotId);
  Future<RateBatch> refreshSnapshotRates(String id, {bool force = true});
  Future<SnapshotValuation> valuation(
    String id, {
    bool today = false,
    bool force = false,
  });
  Future<void> addSnapshotCurrency(
    String snapshotId,
    String storageId,
    String currencyId,
  );
  Future<void> saveRate(String snapshotId, String currencyId, String value);
  Future<void> saveSnapshotHeader(String id, String date, String note);
  Future<void> finalizeSnapshot(String id);
  Future<SnapshotTotals> totals(String id);
  Future<ReportData> reportSnapshots();
  Future<Map<String, Decimal>> currentRates(Set<String> codes);
  Future<void> close();
}

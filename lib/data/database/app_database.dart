import 'package:drift/drift.dart';

import '../sync/sync_journal.dart';

part 'app_database.g.dart';

/// Предметная схема, версия 1 была пустым каркасом этапа 1.
@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 4) {
        await m.createAll();
      } else if (from == 2 && to == 4) {
        await m.addColumn(snapshotRate, snapshotRate.rateDate);
        await m.addColumn(snapshotRate, snapshotRate.effectiveAt);
        await m.addColumn(rateCache, rateCache.fetchedAt);
        await m.addColumn(rateCache, rateCache.effectiveAt);
        await customStatement(
          'UPDATE snapshot_rate SET rate_date=(SELECT date FROM snapshot WHERE snapshot.id=snapshot_rate.snapshot_id), effective_at=fetched_at',
        );
      } else if (from == 3 && to == 4) {
        // Локальные таблицы журнала устанавливаются ниже; предметная схема та же.
      } else {
        throw StateError('Не поддерживается версия базы');
      }
    },
    beforeOpen: (_) async {
      await SyncJournal.install(this);
      await customStatement('PRAGMA foreign_keys = ON');
      final broken = await customSelect('PRAGMA foreign_key_check').get();
      if (broken.isNotEmpty) throw StateError('Нарушена целостность базы');
    },
  );
}

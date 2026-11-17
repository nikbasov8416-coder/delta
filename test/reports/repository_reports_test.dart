import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  test(
    'Только fixed без deleted; архив учитывается, ликвидность берётся текущая',
    () async {
      final repo = await testRepository();
      addTearDown(repo.close);
      final data = await repo.overview(),
          rub = data.currencies.firstWhere((c) => c.text('code') == 'RUB').id;
      final oldLevel = data.liquidity.first.id,
          newLevel = data.liquidity.last.id;
      await repo.saveStorage(
        name: 'Выдуманный архив',
        type: 'cash',
        liquidityId: oldLevel,
        organization: '',
        note: '',
        archived: false,
        currencyIds: [rub],
      );
      final fixed = await repo.createSnapshot('2026-01-10', '');
      final line = (await repo.snapshot(fixed)).lines.single;
      await repo.saveLine(line.id, '10', '2', '');
      await repo.finalizeSnapshot(fixed);
      final removed = await repo.createSnapshot('2026-02-10', '');
      final line2 = (await repo.snapshot(removed)).lines.single;
      await repo.saveLine(line2.id, '20', '3', '');
      await repo.finalizeSnapshot(removed);
      await repo.db.customStatement(
        'UPDATE snapshot SET deleted=1 WHERE id=?',
        [removed],
      );
      await repo.createSnapshot('2026-03-10', 'Черновик');
      final place = (await repo.overview()).storages.single.id;
      await repo.saveStorage(
        id: place,
        name: 'Выдуманный архив',
        type: 'cash',
        liquidityId: newLevel,
        organization: '',
        note: '',
        archived: true,
        currencyIds: [rub],
      );
      final reports = await repo.reportSnapshots();
      expect(reports, hasLength(1));
      expect(reports.single.id, fixed);
      expect(reports.single.positions.single.liquidityId, newLevel);
      expect(reports.single.positions.single.storageId, place);
      expect(reports.single.totals.rubles.total.toString(), '10');
      expect(
        (await repo.snapshot(fixed)).lines.single.text('liquidity_id'),
        oldLevel,
      ); // legacy поле не меняем в журнале
    },
  );
}

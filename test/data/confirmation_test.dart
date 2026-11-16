import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  test('Копия только зафиксированного; кнопки подтверждения не меняют суммы и пропускают пустые', () async {
    final repo = await testRepository();
    addTearDown(repo.close);
    final data = await repo.overview();
    String currency(String code) =>
        data.currencies.firstWhere((c) => c.text('code') == code).id;
    await repo.saveStorage(
      name: 'Выдуманное место',
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [currency('RUB'), currency('USD')],
    );
    final fixed = await repo.createSnapshot('2026-01-10', '');
    for (final line in (await repo.snapshot(fixed)).lines) {
      await repo.saveLine(line.id, '5', '1', 'синтетическая заметка');
    }
    await repo.saveRate(fixed, currency('USD'), '2');
    await repo.finalizeSnapshot(fixed);
    final draft = await repo.createSnapshot('2026-01-11', '');
    for (final line in (await repo.snapshot(draft)).lines) {
      await repo.saveLine(line.id, '99', '3', 'не для копирования');
    }
    final fresh = await repo.createSnapshot('2026-01-12', '');
    var detail = await repo.snapshot(fresh);
    expect(
      detail.lines.every(
        (l) => l.text('amount') == '5' && !l.flag('confirmed'),
      ),
      isTrue,
    );
    await repo.confirmLine(detail.lines.first.id);
    detail = await repo.snapshot(fresh);
    expect(detail.lines.where((l) => l.flag('confirmed')).length, 1);
    final place = (await repo.overview()).storages.single.id;
    await repo.addSnapshotCurrency(fresh, place, currency('EUR'));
    expect(await repo.confirmUnreviewed(fresh), 1);
    detail = await repo.snapshot(fresh);
    expect(detail.lines.where((l) => l.flag('confirmed')).length, 2);
    expect(
      detail.lines
          .where((l) => l.text('code') != 'EUR')
          .every(
            (l) =>
                l.text('amount') == '5' &&
                l.text('family_amount') == '1' &&
                l.text('note') == 'синтетическая заметка',
          ),
      isTrue,
    );
    await expectLater(
      repo.confirmLine(
        detail.lines.firstWhere((l) => l.text('code') == 'EUR').id,
      ),
      throwsStateError,
    );
    await expectLater(repo.confirmUnreviewed(fixed), throwsStateError);
  });
}

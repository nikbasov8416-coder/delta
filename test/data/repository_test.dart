import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:delta/data/finance_repository.dart';
import 'package:delta/domain/finance/records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  late DriftFinanceRepository repo;
  late FinanceOverview data;
  String currency(String code) =>
      data.currencies.firstWhere((c) => c.text('code') == code).id;
  Future<String> storage({
    String name = 'Тестовое место',
    bool archived = false,
    List<String>? currencies,
  }) async {
    await repo.saveStorage(
      name: name,
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: archived,
      currencyIds: currencies ?? [currency('RUB'), currency('USD')],
    );
    return (await repo.overview()).storages
        .firstWhere((s) => s.text('name') == name)
        .id;
  }

  setUp(() async {
    repo = await testRepository();
    data = await repo.overview();
  });
  tearDown(() async {
    await repo.close();
  });

  test('Начальная схема, валюты, метаданные, HLC и повторный запуск', () async {
    expect(data.currencies.map((c) => c.text('code')).toSet(), {
      'RUB',
      'USD',
      'EUR',
      'CNY',
      'BTC',
      'USDT',
    });
    expect(data.liquidity.length, 5);
    expect(data.liquidity.last.text('name'), 'Долгосрочные (страхование)');
    for (final row in data.currencies) {
      expect(row.id, hasLength(36));
      expect(row.text('updated_at'), contains(':'));
      expect(row.text('device_id'), isNotEmpty);
      expect(row.flag('deleted'), isFalse);
    }
    await repo.initialize();
    expect((await repo.overview()).currencies.length, 6);
    final names = await repo.query(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    expect(
      names.map((r) => r.text('name')),
      containsAll(DriftFinanceRepository.tables),
    );
  });

  test(
    'Фиксация требует подтверждений и курсов; итоги в своей валюте и рублях',
    () async {
      await storage();
      final id = await repo.createSnapshot('2026-01-01', 'Выдуманный пример');
      await expectLater(repo.finalizeSnapshot(id), throwsStateError);
      var detail = await repo.snapshot(id);
      for (final row in detail.lines) {
        await repo.saveLine(
          row.id,
          row.text('code') == 'RUB' ? '1 234,56' : '2,50',
          row.text('code') == 'RUB' ? '234,56' : '0,5',
          '',
        );
      }
      await expectLater(repo.finalizeSnapshot(id), throwsArgumentError);
      expect((await repo.snapshot(id)).header.text('status'), 'draft');
      expect(
        (await repo.snapshot(id)).rates,
        isEmpty,
      ); // Откат всей попытки фиксации.
      await repo.saveRate(id, currency('USD'), '90,25');
      await repo.finalizeSnapshot(id);
      detail = await repo.snapshot(id);
      expect(detail.header.text('status'), 'fixed');
      expect(
        detail.rates.map((r) => r.text('source')),
        containsAll(['identity', 'manual']),
      );
      final totals = await repo.totals(id);
      expect(totals.rubles.total, Decimal.parse('1460.185'));
      expect(totals.rubles.family, Decimal.parse('279.685'));
      expect(totals.byCurrencyRubles['USD']!.total, Decimal.parse('225.625'));
      expect(totals.byCurrency['USD']!.total, Decimal.parse('2.5'));
    },
  );

  test(
    'Правки после фиксации атомарно сохраняют старое/новое в audit_log',
    () async {
      await storage(currencies: [currency('RUB')]);
      final id = await repo.createSnapshot('2026-01-02', '');
      final row = (await repo.snapshot(id)).lines.single;
      await repo.saveLine(row.id, '10', '2', 'искусственная запись');
      await repo.finalizeSnapshot(id);
      expect((await repo.snapshot(id)).audit, isEmpty);
      await repo.saveLine(row.id, '15', '3', 'исправление');
      await repo.saveSnapshotHeader(id, '2026-01-03', 'Изменённая заметка');
      await repo.saveRate(id, currency('RUB'), '1');
      final audit = (await repo.snapshot(id)).audit;
      expect(audit.length, 3);
      final lineChange = audit.firstWhere(
        (a) => a.text('entity_type') == 'snapshot_line',
      );
      expect(jsonDecode(lineChange.text('old_value'))['amount'], '10');
      expect(jsonDecode(lineChange.text('new_value'))['amount'], '15');
      expect((await repo.totals(id)).rubles.personal, Decimal.parse('12'));
      await expectLater(
        repo.saveLine(row.id, '1', '2', ''),
        throwsFormatException,
      );
      expect((await repo.snapshot(id)).audit.length, 3);
      expect((await repo.snapshot(id)).lines.single.text('amount'), '15');
    },
  );

  test(
    'Копия прошлого, архив, неактивные валюты и добавление валюты из слепка',
    () async {
      final place = await storage();
      await storage(name: 'Архивный пример', archived: true);
      final previous = await repo.createSnapshot('2026-01-01', '');
      for (final row in (await repo.snapshot(previous)).lines) {
        await repo.saveLine(row.id, '3', '1', '');
      }
      await repo.saveStorage(
        id: place,
        name: 'Тестовое место',
        type: 'cash',
        liquidityId: data.liquidity.first.id,
        organization: '',
        note: '',
        archived: false,
        currencyIds: [currency('RUB')],
      );
      final next = await repo.createSnapshot('2026-01-02', '');
      var detail = await repo.snapshot(next);
      expect(detail.lines.length, 1);
      expect(detail.lines.single.text('amount'), '3');
      expect(detail.lines.single.flag('confirmed'), isFalse);
      await repo.addSnapshotCurrency(next, place, currency('USD'));
      detail = await repo.snapshot(next);
      expect(detail.lines.length, 2);
      expect(
        detail.lines
            .firstWhere((l) => l.text('code') == 'USD')
            .values['amount'],
        isNull,
      );
      await expectLater(
        repo.addSnapshotCurrency(next, place, currency('USD')),
        throwsStateError,
      );
      expect((await repo.snapshot(previous)).lines.length, 2);
    },
  );

  test('Смена ликвидности места не меняет старый слепок', () async {
    final place = await storage(currencies: [currency('RUB')]);
    final id = await repo.createSnapshot('2026-01-01', '');
    final row = (await repo.snapshot(id)).lines.single;
    await repo.saveLine(row.id, '5', '0', '');
    await repo.finalizeSnapshot(id);
    await repo.saveStorage(
      id: place,
      name: 'Тестовое место',
      type: 'cash',
      liquidityId: data.liquidity.last.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [currency('RUB')],
    );
    expect(
      (await repo.totals(id)).byLiquidityRubles.keys.single,
      data.liquidity.first.id,
    );
  });

  test('Стандартные валюты сохраняют код и точность', () async {
    await expectLater(
      repo.saveCurrency(
        id: currency('RUB'),
        code: 'RUB',
        name: 'Пример',
        kind: 'fiat',
        precision: 3,
      ),
      throwsFormatException,
    );
    await expectLater(
      repo.saveCurrency(
        id: currency('RUB'),
        code: 'AAA',
        name: 'Пример',
        kind: 'fiat',
        precision: 2,
      ),
      throwsStateError,
    );
  });
  test(
    'Справочники: мягкое удаление и запрет удаления используемого',
    () async {
      await repo.saveCurrency(
        code: 'AAA',
        name: 'Искусственная валюта',
        kind: 'fiat',
        precision: 2,
      );
      final added = (await repo.overview()).currencies.firstWhere(
        (c) => c.text('code') == 'AAA',
      );
      await repo.removeCatalogEntry('currency', added.id);
      expect(
        (await repo.query('SELECT deleted FROM currency WHERE id=?', [
          added.id,
        ])).single.flag('deleted'),
        isTrue,
      );
      await storage();
      await expectLater(
        repo.removeCatalogEntry('currency', currency('RUB')),
        throwsStateError,
      );
      await expectLater(
        repo.removeCatalogEntry('liquidity_level', data.liquidity.first.id),
        throwsStateError,
      );
    },
  );

  test(
    'Схема не пропускает отрицательные суммы и семейную часть выше суммы',
    () async {
      await storage(currencies: [currency('RUB')]);
      final id = await repo.createSnapshot('2026-01-01', '');
      final line = (await repo.snapshot(id)).lines.single;
      await expectLater(
        repo.db.customStatement(
          'UPDATE snapshot_line SET amount=? WHERE id=?',
          ['-1', line.id],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        repo.db.customStatement(
          'UPDATE snapshot_line SET amount=?,family_amount=? WHERE id=?',
          ['1', '2', line.id],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        repo.saveLine(line.id, '0.001', '0', ''),
        throwsFormatException,
      );
      await expectLater(
        repo.saveSnapshotHeader(id, '2026-02-30', ''),
        throwsFormatException,
      );
    },
  );
}

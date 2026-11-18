import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta/domain/rates/rates.dart';
import 'package:delta/data/finance_repository.dart';

import '../support/test_database.dart';

class SyntheticGateway implements RateGateway {
  int calls = 0;
  bool fail = false, wrongDate = false;
  final fetchedCodes = <Set<String>>[];
  DateTime current = DateTime.utc(2026, 1, 12, 10);
  Completer<RateBatch>? pending;
  @override
  Future<RateBatch> fetch(Set<String> codes, DateTime date) async {
    calls++;
    fetchedCodes.add({...codes});
    if (pending != null) return pending!.future;
    if (fail) {
      return RateBatch(errors: {for (final c in codes) c: 'Выдуманный сбой'});
    }
    return RateBatch(
      quotes: {
        for (final c in codes)
          c: RateQuote(
            code: c,
            date: wrongDate ? '2000-01-01' : dayKey(date),
            value: Decimal.parse(dayKey(date) == '2026-01-10' ? '2' : '3'),
            source: ['BTC', 'USDT'].contains(c) ? 'coingecko' : 'cbr',
            effectiveAt: dayKey(date),
            fetchedAt: current,
          ),
      },
    );
  }
}

void main() {
  late SyntheticGateway gateway;
  late DriftFinanceRepository repo;
  late String usd, rub, eur, place;
  setUp(() async {
    gateway = SyntheticGateway();
    repo = await testRepository(gateway: gateway, now: () => gateway.current);
    final data = await repo.overview();
    usd = data.currencies.firstWhere((c) => c.text('code') == 'USD').id;
    rub = data.currencies.firstWhere((c) => c.text('code') == 'RUB').id;
    eur = data.currencies.firstWhere((c) => c.text('code') == 'EUR').id;
    await repo.saveStorage(
      name: 'Выдуманное место',
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [rub, usd],
    );
    place = (await repo.overview()).storages.single.id;
  });
  tearDown(() async => repo.close());
  Future<String> filled() async {
    final id = await repo.createSnapshot('2026-01-10', '');
    for (final line in (await repo.snapshot(id)).lines) {
      await repo.saveLine(line.id, '10', '2', '');
    }
    return id;
  }

  test(
    'Создание получает курсы автоматически, кэш сохраняет источник и время',
    () async {
      final id = await filled();
      expect(gateway.calls, 1);
      final rate = (await repo.snapshot(id)).rates
          .firstWhere((r) => r.text('code') == 'USD');
      expect(rate.text('source'), 'cbr');
      expect(rate.text('rate_date'), '2026-01-10');
      expect(rate.text('fetched_at'), isNotEmpty);
      final cache = await repo.query('SELECT * FROM rate_cache');
      expect(cache.single.text('rate'), '2');
      await repo.refreshSnapshotRates(id, force: false);
      expect(gateway.calls, 1);
    },
  );
  test(
    'Добавление места без истории создаёт пустые строки и загружает курсы',
    () async {
      final draft = await filled();
      await repo.saveRate(draft, usd, '99');
      final catalog = await repo.overview();
      await repo.saveStorage(
        name: 'Новое место',
        type: 'cash',
        liquidityId: catalog.liquidity.last.id,
        organization: '',
        note: '',
        archived: false,
        currencyIds: [rub, eur],
      );
      final id = (await repo.snapshot(draft)).missingStorages.single.id;
      await repo.addSnapshotStorage(draft, id);
      final detail = await repo.snapshot(draft);
      final lines = detail.lines.where((l) => l.text('storage_id') == id);
      expect(lines.map((l) => l.text('code')).toSet(), {'RUB', 'EUR'});
      for (final line in lines) {
        expect(line.values['amount'], isNull);
        expect(line.text('family_amount'), '0');
        expect(line.text('note'), isEmpty);
        expect(line.flag('confirmed'), isFalse);
      }
      expect(gateway.fetchedCodes, [
        {'USD'},
        {'EUR'},
      ]);
      final rate = detail.rates.singleWhere((r) => r.text('code') == 'EUR');
      expect(rate.text('rate_date'), '2026-01-10');
      expect(rate.text('rate'), '2');
      final manual = detail.rates.singleWhere((r) => r.text('code') == 'USD');
      expect(manual.text('rate'), '99');
      expect(manual.text('source'), 'manual');
    },
  );
  test(
    'Сегодняшняя оценка не меняет сохранённые курсы, суммы и аудит',
    () async {
      final id = await filled();
      await repo.finalizeSnapshot(id);
      final before = await repo.snapshot(id);
      expect(
        (await repo.valuation(id)).totals.rubles.total,
        Decimal.parse('30'),
      );
      final today = await repo.valuation(id, today: true);
      expect(today.totals.rubles.total, Decimal.parse('40'));
      expect(today.rates.firstWhere((r) => r.code == 'USD').date, '2026-01-12');
      final after = await repo.snapshot(id);
      expect(
        after.rates.map((r) => r.values).toList(),
        before.rates.map((r) => r.values).toList(),
      );
      expect(after.audit, isEmpty);
      expect(
        after.lines.map((l) => l.text('amount')),
        before.lines.map((l) => l.text('amount')),
      );
      final calls = gateway.calls;
      await repo.valuation(id, today: true);
      expect(gateway.calls, calls);
      gateway.current = gateway.current.add(const Duration(minutes: 16));
      await repo.valuation(id, today: true);
      expect(gateway.calls, calls + 1);
    },
  );
  test('Обновление фиксированного слепка аудируется; ошибки сохраняют старые значения', () async {
    final id = await filled();
    await repo.finalizeSnapshot(id);
    gateway.current = gateway.current.add(const Duration(seconds: 1));
    await repo.refreshSnapshotRates(id);
    expect((await repo.snapshot(id)).audit, isNotEmpty);
    gateway.fail = true;
    final report = await repo.refreshSnapshotRates(id);
    expect(report.errors, contains('USD'));
    expect(
      (await repo.snapshot(id)).rates
          .firstWhere((r) => r.text('code') == 'USD')
          .text('rate'),
      '2',
    );
    await expectLater(
      repo.valuation(id, today: true, force: true),
      throwsStateError,
    );
  });
  test('Добавление валюты не заменяет ручной курс; смена даты не использует старый', () async {
    final id = await filled();
    await repo.saveRate(id, usd, '9');
    await repo.addSnapshotCurrency(id, place, eur);
    expect(gateway.fetchedCodes.last, {'EUR'});
    expect(
      (await repo.snapshot(id)).rates
          .firstWhere((r) => r.text('code') == 'USD')
          .text('rate'),
      '9',
    );
    final line = (await repo.snapshot(id)).lines
        .firstWhere((r) => r.text('code') == 'EUR');
    await repo.saveLine(line.id, '0', '0', '');
    gateway.fail = true;
    await repo.saveSnapshotHeader(id, '2026-01-11', '');
    await expectLater(repo.totals(id), throwsStateError);
    await repo.saveRate(id, usd, '4');
    await repo.saveRate(id, eur, '5');
    expect((await repo.totals(id)).rubles.total, Decimal.parse('50'));
  });
  test('Ответ другой даты не попадает ни в кэш, ни в слепок', () async {
    gateway.wrongDate = true;
    final id = await filled();
    expect(
      (await repo.snapshot(id)).rates.any((r) => r.text('code') == 'USD'),
      isFalse,
    );
    expect(await repo.query('SELECT * FROM rate_cache'), isEmpty);
    expect((await repo.snapshot(id)).rateErrors, contains('USD'));
  });
  test(
    'Слепок изменён во время сети: запоздавшие курсы не перезаписывают его',
    () async {
      final id = await filled();
      gateway.pending = Completer<RateBatch>();
      final work = repo.refreshSnapshotRates(id);
      while (gateway.calls < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      final row = (await repo.snapshot(id)).lines.first;
      await repo.saveLine(row.id, '12', '2', '');
      final assertion = expectLater(work, throwsStateError);
      gateway.pending!.complete(
        RateBatch(
          quotes: {
            'USD': RateQuote(
              code: 'USD',
              date: '2026-01-10',
              value: Decimal.parse('7'),
              source: 'cbr',
              effectiveAt: '2026-01-10',
              fetchedAt: gateway.current,
            ),
          },
        ),
      );
      await assertion;
      expect(
        (await repo.snapshot(id)).rates
            .firstWhere((r) => r.text('code') == 'USD')
            .text('rate'),
        '2',
      );
    },
  );
}

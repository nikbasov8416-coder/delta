import 'package:decimal/decimal.dart';
import 'package:delta/domain/reports/reports.dart';
import 'package:flutter_test/flutter_test.dart';

ReportPosition position(
  String storage,
  String code,
  String amount, {
  String family = '0',
  String liquidity = 'L1',
  int order = 0,
}) => ReportPosition(
  storageId: storage,
  storageName: storage,
  currency: code,
  precision: code == 'BTC' ? 8 : 2,
  liquidityId: liquidity,
  liquidityName: liquidity,
  liquidityOrder: order,
  amount: Decimal.parse(amount),
  family: Decimal.parse(family),
);
ReportSnapshot snapshot(
  String id,
  String date,
  List<ReportPosition> rows,
  Map<String, String> rates,
) => ReportSnapshot(
  id: id,
  date: date,
  positions: rows,
  rates: rates.map((k, v) => MapEntry(k, Decimal.parse(v))),
);
void main() {
  test(
    'Разложение Decimal: части точно равны разнице; по каждой группе тоже',
    () {
      final a = snapshot(
        'a',
        '2026-01-01',
        [
          position('wallet', 'USD', '10.25', family: '2.25'),
          position('bank', 'RUB', '100'),
        ],
        {'USD': '73.123456789123456789'},
      );
      final b = snapshot(
        'b',
        '2026-02-01',
        [
          position('wallet', 'USD', '15.75', family: '3.15'),
          position('bank', 'RUB', '75'),
        ],
        {'USD': '84.987654321987654321'},
      );
      final c = compareSnapshots(a, b);
      expect(c.total.delta, b.totals.rubles.total - a.totals.rubles.total);
      expect(c.total.balance + c.total.fx, c.total.delta);
      expect(
        c.total.balance,
        (Decimal.parse('5.5') * a.rates['USD']!) - Decimal.fromInt(25),
      );
      for (final groups in [c.byStorage, c.byCurrency, c.byLiquidity]) {
        expect(
          groups.values.fold(Decimal.zero, (v, e) => v + e.delta),
          c.total.delta,
        );
        for (final e in groups.values) {
          expect(e.balance + e.fx, e.delta);
        }
      }
    },
  );
  test('Новая/исчезнувшая валюта и место — ноль на другой стороне, без выдуманного курса', () {
    final a = snapshot(
      'a',
      '2026-01-01',
      [position('cash', 'USD', '10'), position('same', 'RUB', '5')],
      {'USD': '2'},
    );
    final b = snapshot(
      'b',
      '2026-02-01',
      [position('new', 'BTC', '0.1'), position('same', 'RUB', '7')],
      {'BTC': '100'},
    );
    final c = compareSnapshots(a, b);
    expect(c.total.delta, Decimal.fromInt(-8));
    expect(c.total.fx, Decimal.zero);
    expect(c.total.balance, c.total.delta);
    expect(c.byStorage['cash']!.nativeAfter['USD'], Decimal.zero);
    expect(c.byStorage['new']!.nativeBefore['BTC'], Decimal.zero);
    expect(c.byCurrency['BTC']!.delta, Decimal.fromInt(10));
  });
  test('Новое место с уже известной валютой использует реальные курсы обоих слепков', () {
    final a = snapshot(
      'a',
      '2026-01-01',
      [position('old', 'USD', '1')],
      {'USD': '2'},
    );
    final b = snapshot(
      'b',
      '2026-02-01',
      [position('old', 'USD', '1'), position('new', 'USD', '5')],
      {'USD': '3'},
    );
    final c = compareSnapshots(a, b);
    expect(c.byStorage['new']!.balance, Decimal.fromInt(10));
    expect(c.byStorage['new']!.fx, Decimal.fromInt(5));
    expect(c.total.balance + c.total.fx, c.total.delta);
    final reverse = compareSnapshots(b, a);
    expect(reverse.total.delta, -c.total.delta);
    expect(reverse.total.balance + reverse.total.fx, reverse.total.delta);
  });
  test(
    'RUB = 1, неверный RUB или отсутствующий собственный курс не скрываются',
    () {
      final rub = snapshot('a', '2026-01-01', [
        position('cash', 'RUB', '10'),
      ], {});
      expect(rub.totals.rubles.total, Decimal.fromInt(10));
      expect(
        () => snapshot('bad', '2026-01-01', [], {'RUB': '2'}),
        throwsArgumentError,
      );
      final missing = snapshot('bad', '2026-01-01', [
        position('cash', 'USD', '10'),
      ], {});
      expect(() => compareSnapshots(missing, rub), throwsArgumentError);
    },
  );
  test(
    'Ряды графиков: итог, валюты, личные/семейные и накопление ликвидности',
    () {
      final data = [
        snapshot(
          'a',
          '2026-01-01',
          [
            position('a', 'RUB', '10', family: '2'),
            position('b', 'USD', '5', liquidity: 'L2', order: 1),
          ],
          {'USD': '2'},
        ),
        snapshot(
          'b',
          '2026-02-01',
          [
            position('a', 'RUB', '20', family: '3'),
            position('b', 'USD', '10', family: '1', liquidity: 'L2', order: 1),
          ],
          {'USD': '3'},
        ),
      ];
      expect(reportSeries(data, ReportChart.total).single.values, [
        Decimal.fromInt(20),
        Decimal.fromInt(50),
      ]);
      final liq = reportSeries(data, ReportChart.liquidity);
      expect(liq.map((s) => s.name), ['L1', 'L2']);
      expect(liq.first.values, [Decimal.fromInt(10), Decimal.fromInt(20)]);
      expect(liq.last.values, [Decimal.fromInt(20), Decimal.fromInt(50)]);
      final family = reportSeries(data, ReportChart.family);
      expect(family.last.values, [Decimal.fromInt(2), Decimal.fromInt(6)]);
      expect(family.first.values, [Decimal.fromInt(18), Decimal.fromInt(44)]);
      final currencies = reportSeries(data, ReportChart.currency);
      expect(currencies.first.name, 'RUB');
      expect(currencies.last.values, [
        Decimal.fromInt(10),
        Decimal.fromInt(30),
      ]);
    },
  );
  test('Периоды: все/год/полгода, границы месяцев и будущие даты', () {
    final data = [
      for (final date in [
        '2024-02-29',
        '2024-08-31',
        '2024-09-01',
        '2025-02-28',
        '2025-03-01',
      ])
        snapshot(date, date, [], {}),
    ];
    final now = DateTime.utc(2025, 2, 28);
    expect(reportPeriod(data, ReportPeriod.all, now), hasLength(5));
    expect(reportPeriod(data, ReportPeriod.year, now).map((s) => s.date), [
      '2024-02-29',
      '2024-08-31',
      '2024-09-01',
      '2025-02-28',
    ]);
    expect(reportPeriod(data, ReportPeriod.halfYear, now).map((s) => s.date), [
      '2024-08-31',
      '2024-09-01',
      '2025-02-28',
    ]);
  });
}

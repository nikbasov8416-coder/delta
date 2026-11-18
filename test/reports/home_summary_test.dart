import 'package:decimal/decimal.dart';
import 'package:delta/domain/reports/home_summary.dart';
import 'package:delta/domain/reports/reports.dart';
import 'package:delta/ui/finance_format.dart';
import 'package:delta/ui/money_visibility.dart';
import 'package:delta/ui/reports/report_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ReportPosition position(String id, String amount, {String code = 'USD'}) =>
    ReportPosition(
      storageId: id,
      storageName: id,
      currency: code,
      precision: 2,
      liquidityId: id,
      liquidityName: id,
      amount: Decimal.parse(amount),
      family: Decimal.zero,
    );
ReportSnapshot snapshot(
  String id,
  String date,
  String rate,
  List<ReportPosition> positions,
) => ReportSnapshot(
  id: id,
  date: date,
  positions: positions,
  rates: {'USD': Decimal.parse(rate)},
);

void main() {
  test('Ось сумм выбирает минимальный круглый верх с 4–6 делениями', () {
    for (final (maximum, step, divisions) in [
      (0.0, '1', 5),
      (0.0009, '0.0002', 5),
      (0.01, '0.002', 5),
      (0.56, '0.1', 6),
      (9.1, '2', 5),
      (10.1, '2', 6),
      (980800.0, '200000', 5),
      (4900000.0, '1000000', 5),
    ]) {
      final axis = roundRublesAxis(maximum);
      expect(axis, (
        step: Decimal.parse(step),
        divisions: divisions,
      ), reason: '$maximum');
      expect(
        (axis.step * Decimal.fromInt(axis.divisions)).toDouble(),
        greaterThanOrEqualTo(maximum),
      );
    }
    expect(compactRubles(Decimal.fromInt(1000000)), '1\u00a0млн');
    expect(compactRubles(Decimal.fromInt(500000)), '500\u00a0тыс');
    expect(compactRubles(Decimal.parse('0.0002')), '0,0002');
  });

  test('Формат сумм и оба варианта вставки', () {
    expect(formatMoney(Decimal.parse('1250000.5')), '1\u00a0250\u00a0000,50');
    for (final (input, expected) in [
      ('0.50000000', '0,5'),
      ('1.00000000', '1'),
      ('0.00012300', '0,000123'),
    ]) {
      expect(formatMoney(Decimal.parse(input), precision: 8), expected);
    }
    const formatter = AmountInputFormatter();
    for (final input in ['1 250 000,50', '1250000.50', '1250000,50']) {
      final edit = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      );
      expect(edit.text, '1\u00a0250\u00a0000,50');
      expect(edit.selection.end, edit.text.length);
    }
  });
  test('Напоминание строго после 30 дней', () {
    final now = DateTime(2026, 11, 18);
    expect(daysSinceSnapshot('2026-10-20', now), isNull);
    expect(daysSinceSnapshot('2026-10-19', now), isNull);
    expect(daysSinceSnapshot('2026-10-18', now), 31);
  });
  test(
    'Изменение учитывает только действующие слепки и выбранный режим курса',
    () {
      final a = snapshot('a', '2026-10-01', '2', [position('x', '10')]);
      final b = snapshot('b', '2026-10-03', '1', [position('x', '15')]);
      final history = ReportData([a, b], excludedDates: ['2026-10-02']);
      expect(changeFromPrevious([b]), isNull);
      expect(changeFromPrevious(history.snapshots), (
        amount: Decimal.fromInt(-5),
        percent: Decimal.fromInt(-25),
      ));
      expect(
        changeFromPrevious(
          homeValuations(history.snapshots, today: {'USD': Decimal.fromInt(3)}),
        ),
        (amount: Decimal.fromInt(15), percent: Decimal.fromInt(50)),
      );
    },
  );
  test('Ликвидность пропускает пустые уровни и считает проценты', () {
    final values = liquidityShares(
      snapshot('a', '2026-10-01', '1', [
        position('x', '75'),
        position('y', '0'),
        position('z', '25'),
      ]),
    );
    expect(values.map((v) => v.name), ['x', 'z']);
    expect(values.map((v) => v.percent), [
      Decimal.fromInt(75),
      Decimal.fromInt(25),
    ]);
  });
  test('Даты графика имеют реальный масштаб и отмечают совпадения', () {
    final dates = ReportDates([
      snapshot('a', '2026-11-17', '1', []),
      snapshot('b', '2026-11-17', '1', []),
      snapshot('c', '2026-11-21', '1', []),
    ]);
    expect(dates.positions, [0, .5, 4]);
    expect(dates.labels, ['17.11 (2)', '17.11 (2)', '21.11']);
  });
}

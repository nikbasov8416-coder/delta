import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:decimal/decimal.dart';

import '../../domain/rates/rates.dart';
import '../finance_repository.dart';
import 'finance_copy.dart';

typedef _Row = List<Object?>;
typedef _Sheet = ({String name, List<_Row> rows});
typedef _Number = ({Decimal value, int precision});

_Number _number(Decimal amount, int precision) =>
    (value: amount, precision: precision);
Decimal _decimal(Object value) => Decimal.parse(value as String);

Future<Uint8List> exportFinanceExcel(DriftFinanceRepository repository) async {
  final (tables, fixed) = await repository.db.transaction(
    () async => (
      await readFinanceTables(repository.db, includeDeleted: false),
      (await repository.reportSnapshots()).snapshots,
    ),
  );
  final totals = {
    for (final snapshot in fixed) snapshot.id: snapshot.totals.rubles,
  };
  Map<Object?, Map<String, Object?>> index(String table) => {
    for (final row in tables[table]!) row['id']: row,
  };
  final currencies = index('currency'),
      levels = index('liquidity_level'),
      places = index('storage');
  final rates = {
    for (final rate in tables['snapshot_rate']!)
      (rate['snapshot_id'], rate['currency_id']): rate,
  };
  final linesBySnapshot = <Object?, List<Map<String, Object?>>>{};
  for (final line in tables['snapshot_line']!) {
    linesBySnapshot.putIfAbsent(line['snapshot_id'], () => []).add(line);
  }
  final ratesBySnapshot = <Object?, List<Map<String, Object?>>>{};
  for (final rate in tables['snapshot_rate']!) {
    ratesBySnapshot.putIfAbsent(rate['snapshot_id'], () => []).add(rate);
  }
  final storageCurrencies = <Object?, List<String>>{};
  for (final entry in tables['storage_currency']!) {
    final currency = currencies[entry['currency_id']];
    if (entry['active'] == 1 && currency != null) {
      storageCurrencies
          .putIfAbsent(entry['storage_id'], () => [])
          .add(currency['code']! as String);
    }
  }
  final snapshotRows = <_Row>[
    ['Дата', 'Статус', 'Заметка', 'Итог, ₽', 'Семейные, ₽', 'Личные, ₽'],
  ];
  final balanceRows = <_Row>[
    [
      'Дата слепка',
      'Место',
      'Ликвидность',
      'Валюта',
      'Всего',
      'Семейные',
      'Личные',
      'Курс',
      'Всего, ₽',
    ],
  ];
  final rateRows = <_Row>[
    ['Дата слепка', 'Валюта', 'Курс', 'Источник', 'Дата действия'],
  ];
  final snapshots = tables['snapshot']!
    ..sort((a, b) {
      final date = (a['date']! as String).compareTo(b['date']! as String);
      return date == 0
          ? (a['created_at']! as String).compareTo(b['created_at']! as String)
          : date;
    });
  for (final snapshot in snapshots) {
    final id = snapshot['id'], date = snapshot['date']! as String;
    final day = DateTime.parse(date);
    final draft = snapshot['status'] == 'draft';
    var complete = true;
    var sum = Decimal.zero, familySum = Decimal.zero;
    for (final line in linesBySnapshot[id] ?? const []) {
      final place = places[line['storage_id']],
          currency = currencies[line['currency_id']];
      if (place == null || currency == null) {
        complete = false;
        continue;
      }
      final precision = currency['precision']! as int;
      final code = currency['code']! as String;
      final amount = line['amount'] == null ? null : _decimal(line['amount']!);
      final family = _decimal(line['family_amount']!);
      final row = rates[(id, line['currency_id'])];
      final rate = code == 'RUB'
          ? Decimal.one
          : row?['rate_date'] == date
          ? _decimal(row!['rate']!)
          : null;
      final rubles = amount == null || rate == null ? null : amount * rate;
      if (rubles == null) {
        complete = false;
      } else {
        sum += rubles;
        familySum += family * rate!;
      }
      balanceRows.add([
        day,
        place['name'],
        levels[place['liquidity_id']]?['name'],
        code,
        if (amount == null) null else _number(amount, precision),
        _number(family, precision),
        if (amount == null) null else _number(amount - family, precision),
        if (rate == null) null else _number(rate, rate.scale.clamp(2, 18)),
        if (rubles == null) null else _number(rubles, 2),
      ]);
    }
    final total = draft && complete ? sum : totals[id]?.total;
    final family = draft && complete ? familySum : totals[id]?.family;
    snapshotRows.add([
      day,
      draft ? 'черновик' : 'зафиксирован',
      snapshot['note'],
      if (total == null) null else _number(total, 2),
      if (family == null) null else _number(family, 2),
      if (total == null || family == null) null else _number(total - family, 2),
    ]);
    for (final rate in ratesBySnapshot[id] ?? const []) {
      final code = currencies[rate['currency_id']]?['code'];
      if (code == null) continue;
      final amount = _decimal(rate['rate']!);
      rateRows.add([
        day,
        code,
        _number(amount, amount.scale.clamp(2, 18)),
        rateSourceLabel(rate['source']! as String),
        DateTime.tryParse(rate['effective_at']! as String),
      ]);
    }
  }
  final sheets = <_Sheet>[
    (name: 'Слепки', rows: snapshotRows),
    (name: 'Остатки', rows: balanceRows),
    (name: 'Курсы', rows: rateRows),
    (
      name: 'Места',
      rows: [
        ['Место', 'Ликвидность', 'Валюты', 'Архив'],
        for (final place in places.values)
          [
            place['name'],
            levels[place['liquidity_id']]?['name'],
            (storageCurrencies[place['id']] ?? []).join(', '),
            place['archived'] == 1 ? 'Да' : 'Нет',
          ],
      ],
    ),
    (
      name: 'Справочники',
      rows: [
        ['Справочник', 'Код', 'Название', 'Точность'],
        for (final currency in currencies.values)
          ['Валюта', currency['code'], currency['name'], currency['precision']],
        for (final level in levels.values)
          ['Ликвидность', null, level['name'], null],
      ],
    ),
  ];
  return _writeWorkbook(sheets);
}

const _main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _relationships =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _package = 'http://schemas.openxmlformats.org/package/2006/relationships';

String _escape(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFE\uFFFF]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _sheetXml(List<_Row> rows) {
  const epoch = 25569; // 1970-01-01 в календаре Excel 1900.
  final start = DateTime.utc(1970);
  final output = StringBuffer(
    '<worksheet xmlns="$_main"><sheetViews><sheetView workbookViewId="0">'
    '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
    '</sheetView></sheetViews><sheetData>',
  );
  for (final (i, row) in rows.indexed) {
    output.write('<row r="${i + 1}">');
    for (final (column, value) in row.indexed) {
      if (value == null) continue;
      final cell = '${String.fromCharCode(65 + column)}${i + 1}';
      switch (value) {
        case String text:
          output.write(
            '<c r="$cell" t="inlineStr"><is><t xml:space="preserve">${_escape(text)}</t></is></c>',
          );
        case DateTime date:
          final day = DateTime.utc(date.year, date.month, date.day);
          final serial =
              day.difference(start).inDays +
              epoch -
              (day.isBefore(DateTime.utc(1900, 3)) ? 1 : 0);
          output.write('<c r="$cell" s="1"><v>$serial</v></c>');
        case _Number number:
          output.write(
            '<c r="$cell" s="${number.precision + 2}"><v>${number.value}</v></c>',
          );
        case int integer:
          output.write('<c r="$cell"><v>$integer</v></c>');
      }
    }
    output.write('</row>');
  }
  return '$output</sheetData></worksheet>';
}

Uint8List _writeWorkbook(List<_Sheet> sheets) {
  final archive = Archive();
  void add(String path, String text) {
    final bytes = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>$text',
    );
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  final indexes = List.generate(sheets.length, (index) => index + 1);
  add(
    '[Content_Types].xml',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${indexes.map((i) => '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '<Relationships xmlns="$_package">'
        '<Relationship Id="rId1" Type="$_relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="$_package">'
        '${indexes.map((i) => '<Relationship Id="rId$i" Type="$_relationships/worksheet" Target="worksheets/sheet$i.xml"/>').join()}'
        '<Relationship Id="rId${sheets.length + 1}" Type="$_relationships/styles" Target="styles.xml"/></Relationships>',
  );
  add(
    'xl/workbook.xml',
    '<workbook xmlns="$_main" xmlns:r="$_relationships"><sheets>'
        '${indexes.map((i) => '<sheet name="${sheets[i - 1].name}" sheetId="$i" r:id="rId$i"/>').join()}'
        '</sheets></workbook>',
  );
  final formats = List.generate(19, (i) => i);
  add(
    'xl/styles.xml',
    '<styleSheet xmlns="$_main">'
        '<numFmts count="20"><numFmt numFmtId="164" formatCode="dd.mm.yyyy"/>'
        '${formats.map((i) => '<numFmt numFmtId="${165 + i}" formatCode="#,##0${i == 0 ? '' : '.${'0' * i}'}"/>').join()}</numFmts>'
        '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="21"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '${[164, for (final i in formats) i + 165].map((id) => '<xf numFmtId="$id" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>').join()}</cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
  );
  for (final i in indexes) {
    add('xl/worksheets/sheet$i.xml', _sheetXml(sheets[i - 1].rows));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

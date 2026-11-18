import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:delta/data/backup/finance_copy.dart';
import 'package:delta/data/backup/finance_excel.dart';
import 'package:delta/data/sync/sync_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';

import '../sync/fake_disk.dart';
import '../sync/sync_test.dart' show TestDevice;

Future<void> populate(TestDevice device) async {
  final repo = device.repo;
  final catalog = await repo.overview();
  final btc = catalog.currencies
      .singleWhere((currency) => currency.text('code') == 'BTC')
      .id;
  await repo.saveStorage(
    name: 'Пробный кошелёк',
    type: 'crypto',
    liquidityId: catalog.liquidity.first.id,
    organization: '',
    note: '',
    archived: false,
    currencyIds: [btc],
  );
  await repo.saveLiquidity(
    name: 'Скрытый уровень',
    order: 100,
    color: 4280723098,
  );
  final custom = (await repo.overview()).liquidity.singleWhere(
    (level) => level.text('name') == 'Скрытый уровень',
  );
  await repo.removeCatalogEntry('liquidity_level', custom.id);
  const date = '2026-11-17';
  final fixed = await repo.createSnapshot(date, '=2+2 & <тест>');
  final line = (await repo.snapshot(fixed)).lines.single;
  await repo.saveLine(line.id, '0.01020304', '0.00000001', '');
  await repo.saveRate(fixed, btc, '6500000');
  await repo.finalizeSnapshot(fixed);
  await repo.saveLine(line.id, '0.01020305', '0.00000001', '');
  await repo.createSnapshot('2026-11-18', 'Пробный черновик');
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late FakeDisk disk;
  late TestDevice source, target;
  late String password;
  setUp(() async {
    password = const Uuid().v4();
    disk = FakeDisk();
    source = await TestDevice.open(disk, 1);
    target = await TestDevice.open(disk, 2);
    await populate(source);
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  test(
    'Удалённый черновик и поздние дочерние записи не входят в файлы',
    () async {
      final repo = source.repo;
      final draft = (await repo.overview()).snapshots
          .singleWhere((row) => row.text('status') == 'draft')
          .id;
      final line = (await repo.snapshot(draft)).lines.single;
      await repo.saveLine(line.id, '0.12345678', '0.01', '');
      await repo.saveRate(draft, line.text('currency_id'), '123456.789');
      expect((await repo.totals(draft)).rubles.total.toString(), isNot('0'));
      await source.setup(create: true);
      expect(source.sync.error, isNull);
      final beforeDelete = await readFinanceTables(repo.db);
      await repo.db.customStatement('''
        CREATE TEMP TRIGGER test_failed_deletion
        BEFORE UPDATE OF deleted ON snapshot_rate WHEN NEW.deleted=1
        BEGIN SELECT RAISE(ABORT, 'Пробный сбой'); END
      ''');
      await expectLater(repo.deleteDraft(draft), throwsA(isA<Exception>()));
      expect(await readFinanceTables(repo.db), beforeDelete);
      expect(await source.sync.journal.changes(), isEmpty);
      await repo.db.customStatement('DROP TRIGGER test_failed_deletion');
      await repo.deleteDraft(draft);
      final changes = await source.sync.journal.changes();
      expect(
        changes.map((c) => c['table']),
        unorderedEquals(['snapshot', 'snapshot_line', 'snapshot_rate']),
      );
      for (final change in changes) {
        final row = change['row'] as Map;
        expect(row['deleted'], 1);
        expect(row['device_id'], repo.deviceId);
        expect((row['updated_at'] as String).endsWith(repo.deviceId), isTrue);
      }
      final raw = await readFinanceTables(repo.db);
      expect(
        raw['snapshot']!.singleWhere((r) => r['id'] == draft)['deleted'],
        1,
      );
      for (final table in ['snapshot_line', 'snapshot_rate']) {
        expect(
          raw[table]!.singleWhere((r) => r['snapshot_id'] == draft)['deleted'],
          1,
        );
        // Состояние после более позднего изменения строки с другого устройства.
        await repo.db.customStatement(
          'UPDATE $table SET deleted=0 WHERE snapshot_id=?',
          [draft],
        );
      }
      expect((await repo.overview()).snapshots.map((r) => r.text('status')), [
        'fixed',
      ]);
      await expectLater(
        repo.valuation(draft, draftPreview: true),
        throwsStateError,
      );
      final report = await repo.reportSnapshots();
      expect(report.excludedDates, isEmpty);
      expect(report.snapshots.map((r) => r.date), ['2026-11-17']);
      expect(
        report.snapshots.single.totals.rubles.total.toString(),
        '66319.825',
      );

      final visible = await readFinanceTables(repo.db, includeDeleted: false);
      for (final table in ['snapshot_line', 'snapshot_rate']) {
        expect(
          visible[table]!.map((r) => r['snapshot_id']),
          isNot(contains(draft)),
        );
      }
      final excel = ZipDecoder().decodeBytes(
        await exportFinanceExcel(repo),
        verify: true,
      );
      for (final sheet in [1, 2, 3]) {
        final file = excel.findFile('xl/worksheets/sheet$sheet.xml')!;
        final rows = XmlDocument.parse(utf8.decode(file.content as List<int>))
            .findAllElements('row');
        expect(rows, hasLength(2));
        expect(rows.last.innerText, isNot(contains('Пробный черновик')));
      }
      final copy = FinanceCopy(target.sync);
      final opened = await copy.open(
        await FinanceCopy(source.sync).create(password),
        password,
      );
      expect(opened.snapshots, 1);
      expect(opened.lastSnapshot, '2026-11-17');
      await copy.restore(opened);
      final restored = await readFinanceTables(target.repo.db);
      expect(restored['snapshot']!.map((r) => r['id']), isNot(contains(draft)));
      for (final table in ['snapshot_line', 'snapshot_rate']) {
        expect(
          restored[table]!.map((r) => r['snapshot_id']),
          isNot(contains(draft)),
        );
      }
      expect(await target.repo.query('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'Копия сохраняет таблицы, HLC, авторов и надгробия; нет настроек и журнала',
    () async {
      await source.setup(create: true);
      source.secrets.values['theme_mode'] = 'dark';
      final tables = await readFinanceTables(source.repo.db);
      expect(
        tables['liquidity_level']!.any((row) => row['deleted'] == 1),
        isTrue,
      );
      expect(tables['audit_log'], isNotEmpty);
      final local = await readFinanceTables(target.repo.db);
      final bytes = await FinanceCopy(source.sync).create(password);
      expect(latin1.decode(bytes), isNot(contains('Пробный кошелёк')));
      final restore = FinanceCopy(target.sync);
      final checked = await restore.open(bytes, password);
      expect(checked.snapshots, 2);
      expect(checked.storages, 1);
      expect(checked.lastSnapshot, '2026-11-18');
      expect(await readFinanceTables(target.repo.db), local);
      await restore.restore(checked);
      expect(await readFinanceTables(target.repo.db), tables);
      expect(await target.repo.query('SELECT * FROM sync_outbox'), isEmpty);
      expect(await target.repo.query('SELECT * FROM sync_local'), isEmpty);
      expect(target.secrets.values, isEmpty);
      final greatest = tables.values
          .expand((rows) => rows)
          .map((row) => row['updated_at']! as String)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      expect(target.repo.clock.next().compareTo(greatest), greaterThan(0));
    },
  );

  test(
    'Неверный пароль, повреждение, чужие magic, версия и параметры отклоняются',
    () async {
      final restore = FinanceCopy(target.sync);
      final bytes = await FinanceCopy(source.sync).create(password);
      final before = await readFinanceTables(target.repo.db);
      Matcher failure(String message) => isA<BackupFailure>().having(
        (error) => error.message,
        'текст',
        contains(message),
      );
      await expectLater(
        restore.open(bytes, 'другой пароль'),
        throwsA(failure('Неверный пароль')),
      );
      final broken = Uint8List.fromList(bytes);
      broken[broken.length - 1] ^= 1;
      await expectLater(
        restore.open(broken, password),
        throwsA(failure('файл повреждён')),
      );
      final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
      Uint8List headerChange(String from, String to) {
        final text = utf8.decode(bytes.sublist(4, 4 + length));
        final header = utf8.encode(text.replaceFirst(from, to));
        return (BytesBuilder()
              ..add(
                (ByteData(4)..setUint32(0, header.length)).buffer.asUint8List(),
              )
              ..add(header)
              ..add(bytes.sublist(4 + length)))
            .takeBytes();
      }

      await expectLater(
        restore.open(headerChange('DELTA-BACKUP', 'OTHER-BACKUP'), password),
        throwsA(failure('заголовок')),
      );
      await expectLater(
        restore.open(headerChange('"version":1', '"version":2'), password),
        throwsA(failure('Версия')),
      );
      await expectLater(
        restore.open(
          headerChange('"memory":19456', '"memory":999999999'),
          password,
        ),
        throwsA(failure('заголовок')),
      );
      await expectLater(
        restore.open(Uint8List(12), password),
        throwsA(failure('Размер')),
      );
      expect(await readFinanceTables(target.repo.db), before);
    },
  );

  test(
    'Подключение между предпросмотром и заменой запрещает восстановление',
    () async {
      final bytes = await FinanceCopy(source.sync).create(password);
      final restore = FinanceCopy(target.sync);
      final checked = await restore.open(bytes, password);
      await target.setup(create: true);
      final before = await readFinanceTables(target.repo.db);
      await expectLater(
        restore.open(bytes, password),
        throwsA(isA<SyncFailure>()),
      );
      await expectLater(restore.restore(checked), throwsA(isA<SyncFailure>()));
      expect(await readFinanceTables(target.repo.db), before);
    },
  );

  test('Ошибка вставки в рабочую базу откатывает всю замену', () async {
    final restore = FinanceCopy(target.sync);
    final backup = await restore.open(
      await FinanceCopy(source.sync).create(password),
      password,
    );
    await target.repo.saveLiquidity(
      name: 'Было до восстановления',
      order: 9,
      color: 4280723098,
    );
    await target.repo.db.customStatement('''
CREATE TRIGGER fail_restore BEFORE INSERT ON snapshot_line
BEGIN SELECT RAISE(ABORT, 'test rollback'); END
''');
    final local = await readFinanceTables(target.repo.db);
    final outbox = (await target.repo.query(
      'SELECT * FROM sync_outbox ORDER BY seq',
    )).map((row) => row.values).toList();
    await expectLater(restore.restore(backup), throwsA(anything));
    expect(await readFinanceTables(target.repo.db), local);
    expect(
      (await target.repo.query('SELECT * FROM sync_outbox ORDER BY seq'))
          .map((row) => row.values),
      outbox,
    );
  });

  test(
    'XLSX открывается как OOXML: листы, числовые суммы, даты, точность BTC',
    () async {
      final bytes = await exportFinanceExcel(source.repo);
      if (const bool.fromEnvironment('DELTA_SAVE_TEST_XLSX')) {
        await File('../tmp/delta-stage6-example.xlsx').writeAsBytes(bytes);
      }
      final zip = ZipDecoder().decodeBytes(bytes, verify: true);
      XmlDocument xml(String file) => XmlDocument.parse(
        utf8.decode(zip.findFile(file)!.content as List<int>),
      );
      final book = xml('xl/workbook.xml');
      expect(
        book
            .findAllElements('sheet')
            .map((sheet) => sheet.getAttribute('name')),
        ['Слепки', 'Остатки', 'Курсы', 'Места', 'Справочники'],
      );
      for (var i = 1; i <= 5; i++) {
        final sheet = xml('xl/worksheets/sheet$i.xml');
        expect(
          sheet.findAllElements('pane').single.getAttribute('state'),
          'frozen',
        );
        expect(sheet.findAllElements('f'), isEmpty);
        expect(sheet.innerText, isNot(contains('Скрытый уровень')));
      }
      XmlElement cell(XmlDocument sheet, String ref) => sheet
          .findAllElements('c')
          .singleWhere((cell) => cell.getAttribute('r') == ref);
      final snapshots = xml('xl/worksheets/sheet1.xml');
      expect(cell(snapshots, 'A2').getAttribute('s'), '1');
      expect(cell(snapshots, 'A2').innerText, matches(r'^\d+$'));
      expect(cell(snapshots, 'D2').innerText, '=2+2 & <тест>');
      expect(cell(snapshots, 'D2').getAttribute('t'), 'inlineStr');
      expect(cell(snapshots, 'C3').innerText, 'черновик');
      final balances = xml('xl/worksheets/sheet2.xml');
      expect(cell(balances, 'G2').getAttribute('t'), isNull);
      expect(cell(balances, 'G2').getAttribute('s'), '10');
      expect(cell(balances, 'G2').innerText, '0.01020305');
      expect(cell(balances, 'H2').innerText, '0.00000001');
      expect(zip.files.every((file) => !file.name.contains('vba')), isTrue);
    },
  );

  test(
    'XLSX сохраняет подписи одноимённых дат, заметки и точные курсы',
    () async {
      final repo = source.repo;
      final currencies = (await repo.overview()).currencies;
      final usd = currencies.singleWhere((row) => row.text('code') == 'USD').id;
      final btc = currencies.singleWhere((row) => row.text('code') == 'BTC').id;
      const date = '2026-11-17';
      final first = (await repo.overview()).snapshots
          .singleWhere((row) => row.text('date') == date)
          .id;
      final place = (await repo.overview()).storages.single;
      Future<void> stamp(String id, String time) => repo.db.customStatement(
        'UPDATE snapshot SET created_at=? WHERE id=?',
        ['2026-11-17T${time}Z', id],
      );
      await stamp(first, '08:00:00.000');
      // Разный порядок вставки, одна секунда и необязательные микросекунды.
      final registrations = [
        ('Поздний слепок', '12:00:00.000001', '92.4567', '150000.123456789'),
        ('Дневной слепок', '12:00:00.000', '91.5', '140000.12345678'),
      ];
      final storedRates = <(String, String), String>{};
      for (final (note, time, dollar, bitcoin) in registrations) {
        final id = await repo.createSnapshot(date, note);
        await stamp(id, time);
        final detail = await repo.snapshot(id);
        if (!detail.lines.any((line) => line.text('currency_id') == usd)) {
          await repo.addSnapshotCurrency(id, place.id, usd);
        }
        for (final line in (await repo.snapshot(id)).lines) {
          await repo.saveLine(line.id, '1', '0', '');
        }
        await repo.saveRate(id, usd, dollar);
        await repo.saveRate(id, btc, bitcoin);
        await repo.finalizeSnapshot(id);
        final detailAfter = await repo.snapshot(id);
        for (final (code, expected) in [('USD', dollar), ('BTC', bitcoin)]) {
          final stored = detailAfter.rates
              .singleWhere((row) => row.text('code') == code)
              .text('rate');
          expect(stored, expected);
          storedRates[(note, code)] = stored;
        }
      }

      final bytes = await exportFinanceExcel(repo);
      if (const bool.fromEnvironment('DELTA_SAVE_TEST_XLSX')) {
        await File('../tmp/delta-final-export.xlsx').writeAsBytes(bytes);
      }
      final zip = ZipDecoder().decodeBytes(bytes, verify: true);
      XmlDocument xml(String file) => XmlDocument.parse(
        utf8.decode(zip.findFile(file)!.content as List<int>),
      );
      final styles = xml('xl/styles.xml');
      final xfs = styles
          .findAllElements('cellXfs')
          .single
          .findElements('xf')
          .toList();
      final numberFormats = {
        for (final node in styles.findAllElements('numFmt'))
          node.getAttribute('numFmtId'): node.getAttribute('formatCode')!,
      };
      for (final i in [1, 2, 3]) {
        final sheet = xml('xl/worksheets/sheet$i.xml');
        final rows = sheet.findAllElements('row').toList();
        final columns = {
          for (final cell in rows.first.findElements('c'))
            cell.innerText: cell
                .getAttribute('r')!
                .replaceAll(RegExp(r'\d'), ''),
        };
        expect(columns['Слепок'], 'B');
        final notes = i == 1 ? 'Заметка' : 'Заметка слепка';
        expect(columns, contains(notes));
        final labels = <String>{};
        final observedRates = <(String, String)>{};
        if (i != 1) {
          final index = columns['Курс']!.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1;
          final width = sheet
              .findAllElements('col')
              .singleWhere((col) => col.getAttribute('min') == '$index')
              .getAttribute('width')!;
          expect(int.parse(width), greaterThanOrEqualTo(17));
        }
        for (final row in rows.skip(1)) {
          final cells = {
            for (final cell in row.findElements('c'))
              cell.getAttribute('r')!.replaceAll(RegExp(r'\d'), ''): cell,
          };
          final label = cells[columns['Слепок']]!.innerText;
          labels.add(label);
          final note = switch (label) {
            '17.11.2026' => '=2+2 & <тест>',
            '17.11.2026 (2)' => 'Дневной слепок',
            '17.11.2026 (3)' => 'Поздний слепок',
            _ => null,
          };
          if (note == null) continue;
          expect(cells[columns[notes]]!.innerText, note);
          final code = cells[columns['Валюта']]?.innerText;
          if (code == null || label == '17.11.2026') continue;
          final stored = storedRates[(note, code)]!;
          observedRates.add((note, code));
          final cell = cells[columns['Курс']]!;
          expect(cell.getAttribute('t'), isNull);
          expect(cell.findElements('v').single.innerText, stored);
          final xf = xfs[int.parse(cell.getAttribute('s')!)];
          final format = numberFormats[xf.getAttribute('numFmtId')]!;
          expect(format, matches(r'^#,##0\.00#+$'));
          expect(
            format.split('.').last.length,
            greaterThanOrEqualTo(stored.split('.').last.length),
          );
        }
        if (i != 1) expect(observedRates, unorderedEquals(storedRates.keys));
        expect(labels.take(3), [
          '17.11.2026',
          '17.11.2026 (2)',
          '17.11.2026 (3)',
        ]);
      }
    },
  );
}

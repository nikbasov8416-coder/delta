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
    'Копия сохраняет таблицы, HLC, авторов и надгробия; нет настроек и журнала',
    () async {
      await source.setup(create: true);
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
      expect(cell(snapshots, 'C2').innerText, '=2+2 & <тест>');
      expect(cell(snapshots, 'C2').getAttribute('t'), 'inlineStr');
      expect(cell(snapshots, 'B3').innerText, 'черновик');
      final balances = xml('xl/worksheets/sheet2.xml');
      expect(cell(balances, 'E2').getAttribute('t'), isNull);
      expect(cell(balances, 'E2').getAttribute('s'), '10');
      expect(cell(balances, 'E2').innerText, '0.01020305');
      expect(cell(balances, 'F2').innerText, '0.00000001');
      expect(zip.files.every((file) => !file.name.contains('vba')), isTrue);
    },
  );
}

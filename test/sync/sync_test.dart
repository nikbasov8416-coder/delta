import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:delta/data/finance_repository.dart';
import 'package:delta/data/sync/sync_crypto.dart';
import 'package:delta/data/sync/sync_error.dart';
import 'package:delta/data/sync/sync_journal.dart';
import 'package:delta/data/sync/sync_service.dart';
import 'package:delta/data/sync/webdav.dart';
import 'package:delta/data/sync/sync_storage.dart';
import 'package:delta/domain/sync/hlc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';
import 'fake_disk.dart';

const syntheticToken = 'synthetic-token';
const phrase = 'выдуманная длинная фраза для тестов';
String device(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

// KDF подменена только в интеграционных тестах. Настоящая Argon2id проверяется ниже.
Future<SyncCrypto> fastKdf(String phrase, Map<String, dynamic> meta) async =>
    SyncCrypto(
      SecretKey(
        (await Sha256().hash(utf8.encode('$phrase|${meta['salt']}'))).bytes,
      ),
    );

class TestDevice {
  TestDevice(this.repo, this.secrets, this.sync);
  final DriftFinanceRepository repo;
  final MemorySecrets secrets;
  final SyncService sync;
  static Future<TestDevice> open(FakeDisk disk, int n, {int format = 1}) async {
    final repo = DriftFinanceRepository(
      memoryDatabase(),
      device(n),
      clock: HybridClock(device(n), milliseconds: () => 1700000000000),
    );
    await repo.initialize();
    final secrets = MemorySecrets();
    final sync = SyncService(
      repo,
      secrets,
      diskFactory: (_) => disk,
      derive: fastKdf,
      initialFormat: format,
    );
    return TestDevice(repo, secrets, sync);
  }

  Future<void> setup({
    bool create = false,
    bool replace = true,
    String passphrase = phrase,
  }) async {
    await sync.configure(
      token: syntheticToken,
      phrase: passphrase,
      create: create,
      replace: replace,
    );
  }

  Future<void> close() async {
    sync.dispose();
    await repo.close();
  }
}

void main() {
  // Разные memory-executor намеренно моделируют независимые устройства.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  test('Argon2id → AES-256-GCM: туда-обратно, неверная фраза, подмена пути и шифротекста', () async {
    final meta = SyncCrypto.header();
    final crypto = await SyncCrypto.derive(phrase, meta);
    final check = await crypto.encrypt(
      utf8.encode(SyncCrypto.checkText),
      SyncCrypto.checkAad(meta),
    );
    meta['check'] = base64Encode(check);
    await crypto.check(meta);
    final same = await SyncCrypto.derive(phrase, meta);
    final cipher = await crypto.encrypt(
      utf8.encode('Выдуманная запись'),
      'dataset|device|1',
    );
    expect(
      utf8.decode(await same.decrypt(cipher, 'dataset|device|1')),
      'Выдуманная запись',
    );
    final wrong = await SyncCrypto.derive('другая выдуманная фраза', meta);
    await expectLater(
      wrong.check(meta),
      throwsA(
        isA<SyncFailure>().having(
          (e) => e.message,
          'причина',
          contains('Неверная парольная фраза'),
        ),
      ),
    );
    await expectLater(
      same.decrypt(cipher, 'dataset|device|2'),
      throwsA(isA<SyncFailure>()),
    );
    cipher[cipher.length - 1] ^= 1;
    await expectLater(
      same.decrypt(cipher, 'dataset|device|1'),
      throwsA(isA<SyncFailure>()),
    );
    expect(
      () => SyncCrypto.validate({...meta, 'memory': 999999999}),
      throwsA(isA<SyncFailure>()),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  late FakeDisk disk;
  late TestDevice a, b;
  setUp(() async {
    disk = FakeDisk();
    a = await TestDevice.open(disk, 1);
    b = await TestDevice.open(disk, 2);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<String> addStorage(TestDevice d, String name) async {
    final data = await d.repo.overview();
    await d.repo.saveStorage(
      name: name,
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [data.currencies.first.id],
    );
    return (await d.repo.overview()).storages.last.id;
  }

  Future<void> startBoth() async {
    await a.setup(create: true);
    expect(a.sync.error, isNull);
    await b.setup();
    expect(b.sync.error, isNull);
  }

  for (final deletionFirst in [true, false]) {
    test('Format 2: удаление и более поздняя правка черновика, '
        'сначала ${deletionFirst ? 'удаление' : 'правка'}', () async {
      final author = await TestDevice.open(disk, 3, format: 2);
      final observer = await TestDevice.open(disk, 4);
      final fresh = await TestDevice.open(disk, 5);
      addTearDown(author.close);
      addTearDown(observer.close);
      addTearDown(fresh.close);
      final place = await addStorage(author, 'Пробное место');
      final id = await author.repo.createSnapshot('2026-01-15', 'Черновик');
      await author.setup(create: true);
      await b.setup();
      await observer.setup();
      expect([
        author.sync.error,
        b.sync.error,
        observer.sync.error,
      ], everyElement(isNull));

      await author.repo.deleteDraft(id);
      // Устройство B работает автономно. Его часы опережают A.
      b.repo.clock.observe('1700000000001:0000000000:${b.repo.deviceId}');
      final line = (await b.repo.snapshot(id)).lines.single;
      await b.repo.saveLine(line.id, '50', '2', 'Автономная правка');
      final rub = (await b.repo.overview()).currencies
          .singleWhere((c) => c.text('code') == 'RUB')
          .id;
      await b.repo.addSnapshotCurrency(id, place, rub);
      await b.repo.saveRate(id, rub, '1');
      final editedStamp = (await b.repo.snapshot(id)).header.text('updated_at');

      final first = deletionFirst ? author : b;
      final second = deletionFirst ? b : author;
      await first.sync.synchronize(uploadOnly: true);
      await observer.sync.synchronize();
      expect(first.sync.error, isNull);
      expect(observer.sync.error, isNull);
      if (deletionFirst) {
        expect((await observer.repo.overview()).snapshots, isEmpty);
      } else {
        final detail = await observer.repo.snapshot(id);
        expect(
          detail.lines.singleWhere((row) => row.id == line.id).text('amount'),
          '50',
        );
      }
      await second.sync.synchronize(uploadOnly: true);
      await observer.sync.synchronize();
      await author.sync.synchronize();
      await b.sync.synchronize();
      await fresh.setup(); // Обе версии приходят за один обмен.
      for (final device in [author, b, observer, fresh]) {
        expect(device.sync.error, isNull);
        final repo = device.repo;
        final header = (await repo.query('SELECT * FROM snapshot WHERE id=?', [
          id,
        ])).single;
        expect(header.flag('deleted'), isTrue);
        expect(header.text('updated_at'), editedStamp);
        expect((await repo.overview()).snapshots, isEmpty);
        expect((await repo.reportSnapshots()).snapshots, isEmpty);
        await expectLater(repo.snapshot(id), throwsStateError);
        await expectLater(repo.totals(id), throwsStateError);
        expect(await repo.query('PRAGMA foreign_key_check'), isEmpty);
        expect(await device.sync.journal.changes(), isEmpty);
      }
      final lateRows = await observer.repo.query(
        'SELECT * FROM snapshot_line WHERE snapshot_id=? AND deleted=0',
        [id],
      );
      expect(lateRows, hasLength(2));
      expect(
        await observer.repo.query(
          'SELECT * FROM snapshot_rate WHERE snapshot_id=? AND deleted=0',
          [id],
        ),
        hasLength(1),
      );
    });
  }

  test(
    'Удалённый заголовок сам по себе не считается локальными данными',
    () async {
      expect(await a.sync.hasLocalData(), isFalse);
      const id = '00000000-0000-4000-8000-000000009999';
      await a.repo.db.customStatement(
        'INSERT INTO snapshot (id,updated_at,device_id,date,created_at) VALUES (?,?,?,?,?)',
        [
          id,
          a.repo.clock.next(),
          a.repo.deviceId,
          '2026-01-15',
          '2026-01-15T12:00:00Z',
        ],
      );
      expect(await a.sync.hasLocalData(), isTrue);
      await a.repo.deleteDraft(id);
      expect(await a.sync.hasLocalData(), isFalse);
    },
  );

  test('Восстановление чистого устройства полное, курс-кэш тоже; безопасность не уходит', () async {
    await addStorage(a, 'Выдуманное место');
    final snap = await a.repo.createSnapshot('2026-01-10', 'выдуманный слепок');
    for (final line in (await a.repo.snapshot(snap)).lines) {
      await a.repo.saveLine(line.id, '12', '2', 'выдуманное');
    }
    final rub = (await a.repo.overview()).currencies.firstWhere(
      (c) => c.text('code') == 'RUB',
    );
    await a.repo.db.customStatement(
      'INSERT INTO rate_cache(id,updated_at,device_id,deleted,currency_id,date,rate,source) VALUES (?,?,?,?,?,?,?,?)',
      [
        device(77),
        a.repo.clock.next(),
        a.repo.deviceId,
        0,
        rub.id,
        '2026-01-10',
        '1',
        'cbr',
      ],
    );
    a.secrets.values['pin_hash_v1'] = 'synthetic-local-pin';
    await a.repo.db.customStatement(
      'INSERT INTO settings VALUES (?,?,?,?,?,?)',
      [
        device(88),
        a.repo.clock.next(),
        a.repo.deviceId,
        0,
        'local-security',
        'synthetic',
      ],
    );
    await startBoth();
    for (final table in syncTables) {
      final left = await a.repo.query('SELECT * FROM $table ORDER BY id');
      final right = await b.repo.query('SELECT * FROM $table ORDER BY id');
      expect(
        right.map((r) => r.values),
        left.map((r) => r.values),
        reason: table,
      );
    }
    expect(await b.repo.query('SELECT * FROM settings'), isEmpty);
    expect(b.secrets.values.containsKey('pin_hash_v1'), isFalse);
    expect(await b.sync.journal.changes(), isEmpty);
    expect(b.sync.lastSync, isNotNull);
  });

  test(
    'Замена данных второго устройства; неверная фраза ничего не меняет',
    () async {
      await addStorage(a, 'Данные с Диска');
      await a.setup(create: true);
      await addStorage(b, 'Локальные данные');
      b.secrets.values['biometric_enabled'] = 'true';
      await b.setup(passphrase: 'неверная выдуманная фраза');
      expect(b.sync.error, contains('Неверная парольная фраза'));
      expect(
        (await b.repo.overview()).storages.single.text('name'),
        'Локальные данные',
      );
      expect(b.secrets.values.containsKey(SyncService.credentialsKey), isFalse);
      await b.setup();
      expect(b.sync.error, isNull);
      expect(
        (await b.repo.overview()).storages.single.text('name'),
        'Данные с Диска',
      );
      expect(b.secrets.values['biometric_enabled'], 'true');
    },
  );

  test(
    'Явный выбор объединения сохраняет собственные данные второго устройства',
    () async {
      await addStorage(a, 'Первое');
      await a.setup(create: true);
      await addStorage(b, 'Второе');
      await b.setup(replace: false);
      expect(b.sync.error, isNull);
      await a.sync.synchronize();
      expect(
        (await a.repo.overview()).storages.map((r) => r.text('name')).toSet(),
        {'Первое', 'Второе'},
      );
    },
  );

  test(
    'Два устройства: LWW одной записи, удаление-надгробие и повтор пачки',
    () async {
      await a.repo.saveLiquidity(
        name: 'Выдуманная ликвидность',
        order: 99,
        color: 1,
      );
      final id = (await a.repo.overview()).liquidity.last.id;
      await startBoth();
      await a.repo.saveLiquidity(id: id, name: 'Правка A', order: 99, color: 1);
      await b.repo.saveLiquidity(id: id, name: 'Правка B', order: 99, color: 1);
      final ar = (await a.repo.query(
        'SELECT * FROM liquidity_level WHERE id=?',
        [id],
      )).single;
      final br = (await b.repo.query(
        'SELECT * FROM liquidity_level WHERE id=?',
        [id],
      )).single;
      final winner = ar.text('updated_at').compareTo(br.text('updated_at')) > 0
          ? ar.text('name')
          : br.text('name');
      await a.sync.synchronize();
      await b.sync.synchronize();
      await a.sync.synchronize();
      expect(
        (await a.repo.query('SELECT name FROM liquidity_level WHERE id=?', [
          id,
        ])).single.text('name'),
        winner,
      );
      expect(
        (await b.repo.query('SELECT name FROM liquidity_level WHERE id=?', [
          id,
        ])).single.text('name'),
        winner,
      );
      await a.repo.removeCatalogEntry('liquidity_level', id);
      await a.sync.synchronize();
      await b.sync.synchronize();
      expect(
        (await b.repo.query('SELECT deleted FROM liquidity_level WHERE id=?', [
          id,
        ])).single.number('deleted'),
        1,
      );
      final count = (await b.repo.query(
        'SELECT count(*) AS n FROM liquidity_level',
      )).single.number('n');
      await b.sync.journal.set('cursor:${a.repo.deviceId}', '0');
      await b.sync.synchronize();
      expect(b.sync.error, isNull);
      expect(
        (await b.repo.query('SELECT count(*) AS n FROM liquidity_level')).single
            .number('n'),
        count,
      );
      expect(await b.sync.journal.changes(), isEmpty);
    },
  );

  test(
    'Обрыв PUT: очередь/шифротекст сохраняются; повтор точно той же пачки',
    () async {
      await startBoth();
      await addStorage(a, 'После обрыва');
      disk.interruptUpload = true;
      await a.sync.synchronize();
      expect(a.sync.error, isNotNull);
      final pending = await a.sync.journal.get('pending');
      expect(pending, isNotEmpty);
      expect(await a.sync.journal.changes(), isNotEmpty);
      await b.sync.synchronize();
      expect(b.sync.error, isNull);
      expect((await b.repo.overview()).storages, isEmpty);
      await a.sync.synchronize();
      expect(a.sync.error, isNull);
      await b.sync.synchronize();
      expect(
        (await b.repo.overview()).storages.single.text('name'),
        'После обрыва',
      );
      final repeated = disk.publications.values.singleWhere(
        (v) => v.length == 2,
      );
      expect(repeated.first, repeated.last);
      expect(await a.sync.journal.changes(), isEmpty);
    },
  );

  test(
    'Потеря ACK после публикации; перезапуск приложения не создаёт новую пачку',
    () async {
      await startBoth();
      await addStorage(a, 'ACK потерян');
      disk.loseAck = true;
      await a.sync.synchronize();
      expect(a.sync.error, isNotNull);
      final retry = SyncService(
        a.repo,
        a.secrets,
        diskFactory: (_) => disk,
        derive: fastKdf,
        initialFormat: 1,
      );
      addTearDown(retry.dispose);
      await retry.load();
      expect(retry.enabled, isTrue);
      await retry.synchronize();
      expect(retry.error, isNull);
      await b.sync.synchronize();
      expect(
        (await b.repo.overview()).storages.single.text('name'),
        'ACK потерян',
      );
      final repeated = disk.publications.values.singleWhere(
        (v) => v.length == 2,
      );
      expect(repeated.first, repeated.last);
    },
  );

  test(
    'Прерванное чтение: ни частичного применения, ни продвижения курсора',
    () async {
      await startBoth();
      await addStorage(a, 'Первая пачка');
      await a.sync.synchronize();
      await addStorage(a, 'Вторая пачка');
      await a.sync.synchronize();
      final folder = '${syncRoot}log/${a.repo.deviceId}/';
      disk.failRead = '${folder}00000000000000000003.bin';
      final cursor = await b.sync.journal.get('cursor:${a.repo.deviceId}');
      await b.sync.synchronize();
      expect(b.sync.error, isNotNull);
      expect((await b.repo.overview()).storages, isEmpty);
      expect(await b.sync.journal.get('cursor:${a.repo.deviceId}'), cursor);
      disk.failRead = null;
      await b.sync.synchronize();
      expect(b.sync.error, isNull);
      expect((await b.repo.overview()).storages, hasLength(2));
    },
  );

  test('Первое создание прервано до meta: ключ и намерение переживают новый сервис', () async {
    await addStorage(a, 'Первоначальные данные');
    disk.interruptMeta = true;
    await a.setup(create: true);
    expect(a.sync.error, isNotNull);
    expect(a.sync.enabled, isTrue);
    expect(disk.files.containsKey('${syncRoot}meta'), isFalse);
    final reopened = SyncService(
      a.repo,
      a.secrets,
      diskFactory: (_) => disk,
      derive: fastKdf,
      initialFormat: 1,
    );
    addTearDown(reopened.dispose);
    await reopened.load();
    await reopened.synchronize();
    expect(reopened.error, isNull);
    await b.setup();
    expect(b.sync.error, isNull);
    expect(
      (await b.repo.overview()).storages.single.text('name'),
      'Первоначальные данные',
    );
  });

  test('Ошибочная запись: транзакция откатывает все строки и курсор', () async {
    await startBoth();
    final folder = '${syncRoot}log/${a.repo.deviceId}/';
    final meta = jsonDecode(
      utf8.decode(disk.files['${syncRoot}meta']!),
    ) as Map<String, dynamic>;
    final crypto = await fastKdf(phrase, meta);
    final liquidity = (await a.repo.query(
      'SELECT * FROM liquidity_level LIMIT 1',
    )).single.values;
    final edited = {
      ...liquidity,
      'name': 'НЕ ДОЛЖНО ПРИМЕНИТЬСЯ',
      'updated_at': a.repo.clock.next(),
    };
    final invalid = {...edited, 'id': device(90), 'name': null};
    final bytes = await crypto.encrypt(
      utf8.encode(
        jsonEncode({
          'format': 1,
          'dataset': meta['dataset'],
          'device': a.repo.deviceId,
          'number': 2,
          'entries': [
            {'table': 'liquidity_level', 'row': edited},
            {'table': 'liquidity_level', 'row': invalid},
          ],
        }),
      ),
      '${meta['dataset']}|${a.repo.deviceId}|2',
    );
    disk.files['${folder}00000000000000000002.bin'] = bytes;
    final cursor = await b.sync.journal.get('cursor:${a.repo.deviceId}');
    await b.sync.synchronize();
    expect(b.sync.error, isNotNull);
    expect(
      (await b.repo.query('SELECT name FROM liquidity_level WHERE id=?', [
        liquidity['id'],
      ])).single.text('name'),
      liquidity['name'],
    );
    expect(await b.sync.journal.get('cursor:${a.repo.deviceId}'), cursor);
  });

  test(
    'Одновременное создание одного курса с разными UUID: LWW составного ключа',
    () async {
      await startBoth();
      final currency = (await a.repo.overview()).currencies
          .firstWhere((c) => c.text('code') == 'USD')
          .id;
      for (final d in [a, b]) {
        await d.repo.db.customStatement(
          'INSERT INTO rate_cache(id,updated_at,device_id,deleted,currency_id,date,rate,source) VALUES (?,?,?,?,?,?,?,?)',
          [
            device(d == a ? 71 : 72),
            d.repo.clock.next(),
            d.repo.deviceId,
            0,
            currency,
            '2026-01-10',
            d == a ? '2' : '3',
            'cbr',
          ],
        );
      }
      final rows = [
        ...await a.repo.query('SELECT * FROM rate_cache'),
        ...await b.repo.query('SELECT * FROM rate_cache'),
      ]..sort((l, r) => l.text('updated_at').compareTo(r.text('updated_at')));
      final winner = rows.last.text('rate');
      await a.sync.synchronize();
      await b.sync.synchronize();
      await a.sync.synchronize();
      expect(a.sync.error, isNull);
      expect(b.sync.error, isNull);
      for (final d in [a, b]) {
        expect(
          (await d.repo.query('SELECT * FROM rate_cache')).single.text('rate'),
          winner,
        );
      }
    },
  );

  test('Сохранение накапливает очередь без обмена', () async {
    await a.setup(create: true);
    expect(a.sync.error, isNull);
    final count = disk.files.keys.where((p) => p.endsWith('.bin')).length;
    a.repo.onChanged = a.sync.changed;
    await addStorage(a, 'Автоматически');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(a.sync.error, isNull);
    expect(disk.files.keys.where((p) => p.endsWith('.bin')).length, count);
    expect(await a.sync.journal.changes(), isNotEmpty);
    a.repo.onChanged = null;
  });

  test(
    'Разные UUID одной новой валюты: безопасный конфликт и исправление кодом',
    () async {
      await startBoth();
      await a.repo.saveCurrency(
        code: 'CAD',
        name: 'Выдуманная A',
        kind: 'fiat',
        precision: 2,
      );
      await a.sync.synchronize();
      await b.repo.saveCurrency(
        code: 'CAD',
        name: 'Выдуманная B',
        kind: 'fiat',
        precision: 2,
      );
      await b.sync.synchronize();
      expect(b.sync.error, contains('Конфликт валют'));
      final bId = (await b.repo.overview()).currencies
          .firstWhere((c) => c.text('code') == 'CAD')
          .id;
      await b.repo.saveCurrency(
        id: bId,
        code: 'NZD',
        name: 'Выдуманная B',
        kind: 'fiat',
        precision: 2,
      );
      await b.sync.synchronize();
      expect(b.sync.error, isNull);
      await a.sync.synchronize();
      expect(a.sync.error, isNull);
      for (final d in [a, b]) {
        expect(
          (await d.repo.overview()).currencies.where(
            (c) => ['CAD', 'NZD'].contains(c.text('code')),
          ),
          hasLength(2),
        );
      }
    },
  );

  test('Несовпадение колонок: отдельная ошибка версии, база и курсоры не меняются', () async {
    await startBoth();
    final meta = jsonDecode(
      utf8.decode(disk.files['${syncRoot}meta']!),
    ) as Map<String, dynamic>;
    final crypto = await fastKdf(phrase, meta);
    final original = (await a.repo.query(
      'SELECT * FROM liquidity_level LIMIT 1',
    )).single.values;
    final before = <String, List<Object?>>{};
    for (final table in [
      ...syncTables,
      'settings',
      'sync_local',
      'sync_outbox',
    ]) {
      before[table] = [
        for (final row in await b.repo.query('SELECT * FROM $table'))
          row.values,
      ];
    }
    final edited = {
      ...original,
      'name': 'не должно примениться',
      'updated_at': a.repo.clock.next(),
    };
    for (final missing in [false, true]) {
      final incompatible = {...edited};
      if (missing) {
        incompatible.remove('color');
      } else {
        incompatible['future_column'] = 'выдуманное';
      }
      final bytes = await crypto.encrypt(
        utf8.encode(
          jsonEncode({
            'format': 1,
            'dataset': meta['dataset'],
            'device': a.repo.deviceId,
            'number': 2,
            'entries': [
              {'table': 'liquidity_level', 'row': edited},
              {'table': 'liquidity_level', 'row': incompatible},
            ],
          }),
        ),
        '${meta['dataset']}|${a.repo.deviceId}|2',
      );
      disk.files['${syncRoot}log/${a.repo.deviceId}/00000000000000000002.bin'] =
          bytes;
      await b.sync.synchronize();
      expect(
        b.sync.error,
        'Данные пришли с другой версии Delta. Обновите приложение на этом устройстве',
      );
      for (final table in before.keys) {
        expect(
          [
            for (final row in await b.repo.query('SELECT * FROM $table'))
              row.values,
          ],
          before[table],
          reason: table,
        );
      }
    }
  });

  test('Чистый засев не считается данными; слепок считается', () async {
    expect(await a.sync.hasLocalData(), isFalse);
    await a.repo.initialize();
    expect(await a.sync.hasLocalData(), isFalse);
    await a.repo.db.customStatement(
      'INSERT INTO snapshot(id,updated_at,device_id,date,created_at) VALUES (?,?,?,?,?)',
      [
        device(90),
        a.repo.clock.next(),
        a.repo.deviceId,
        '2026-01-10',
        '2026-01-10T00:00:00Z',
      ],
    );
    expect((await a.repo.overview()).storages, isEmpty);
    expect(await a.sync.hasLocalData(), isTrue);
  });

  test('Старые заводские цвета не считаются правкой, пользовательский цвет считается', () async {
    expect(await a.sync.hasLocalData(), isFalse);
    for (final level in (await a.repo.overview()).liquidity) {
      final order = level.number('sort_order');
      await a.repo.saveLiquidity(
        id: level.id,
        name: level.text('name'),
        order: order,
        color: 0xff26a69a + order * 0x00111111,
      );
    }
    expect(await a.sync.hasLocalData(), isFalse);
    await a.repo.initialize();
    expect(await a.sync.hasLocalData(), isFalse);
    final level = (await a.repo.overview()).liquidity.first;
    await a.repo.saveLiquidity(
      id: level.id,
      name: level.text('name'),
      order: level.number('sort_order'),
      color: 0xff37b7ab, // Заводской цвет другого уровня.
    );
    expect(await a.sync.hasLocalData(), isTrue);
  });

  test('Изменённые, добавленные и удалённые справочники считаются пользовательскими данными', () async {
    final catalog = await a.repo.overview();
    final level = catalog.liquidity.first;
    await a.repo.saveLiquidity(
      id: level.id,
      name: 'Выдуманная правка',
      order: level.number('sort_order'),
      color: level.number('color'),
    );
    expect(await a.sync.hasLocalData(), isTrue);
    final currency = (await b.repo.overview()).currencies.first;
    await b.repo.saveCurrency(
      id: currency.id,
      code: currency.text('code'),
      name: 'Выдуманная правка',
      kind: currency.text('kind'),
      precision: currency.number('precision'),
    );
    expect(await b.sync.hasLocalData(), isTrue);
    final fresh = await TestDevice.open(disk, 3);
    try {
      expect(await fresh.sync.hasLocalData(), isFalse);
      await fresh.repo.saveLiquidity(
        name: 'Дополнительная',
        order: 99,
        color: 1,
      );
      expect(await fresh.sync.hasLocalData(), isTrue);
    } finally {
      await fresh.close();
    }
    final deleted = await TestDevice.open(disk, 4);
    try {
      await deleted.repo.removeCatalogEntry(
        'liquidity_level',
        (await deleted.repo.overview()).liquidity.first.id,
      );
      expect(await deleted.sync.hasLocalData(), isTrue);
    } finally {
      await deleted.close();
    }
  });

  test(
    'Настройка REST хранит токен; старый формат WebDAV считается ненастроенным',
    () async {
      await a.setup(create: true);
      expect(a.sync.error, isNull);
      final saved = jsonDecode(
        a.secrets.values[SyncService.credentialsKey]!,
      ) as Map<String, dynamic>;
      expect(saved['provider'], 'yandex-rest-v1');
      expect(saved['token'], syntheticToken);
      expect(saved.containsKey('login'), isFalse);
      expect(saved.containsKey('password'), isFalse);
      expect(saved.values, isNot(contains(phrase)));
      final legacy = {...saved}
        ..remove('provider')
        ..remove('token');
      legacy['login'] = 'synthetic-login';
      legacy['password'] = syntheticToken;
      b.secrets.values[SyncService.credentialsKey] = jsonEncode(legacy);
      final before = await b.sync.journal.changes();
      await b.sync.load();
      expect(b.sync.enabled, isFalse);
      expect(b.sync.error, isNull);
      expect(b.sync.lastSync, isNull);
      expect(await b.sync.journal.changes(), before);
      expect(jsonDecode(b.secrets.values[SyncService.credentialsKey]!), legacy);
    },
  );

  test('Ограничение WebDAV: никакого другого хоста, каталога, traversal', () {
    for (final path in [
      '/Apps/',
      '/Apps/Finance/../other',
      '/Apps/Finance/%2e%2e/',
      '/Apps/Finance/log?token=x',
      'https://example.invalid/',
    ]) {
      expect(() => YandexWebDav.address(path), throwsA(isA<SyncFailure>()));
    }
    expect(YandexWebDav.address('/Apps/Finance/meta').host, 'webdav.yandex.ru');
  });
}

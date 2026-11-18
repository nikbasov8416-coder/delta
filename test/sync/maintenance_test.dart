import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:delta/data/sync/sync_service.dart';
import 'package:delta/data/sync/sync_storage.dart';
import 'package:delta/ui/sync/exit_sync.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'fake_disk.dart';
import 'sync_test.dart' show TestDevice, fastKdf, phrase, syntheticToken;

const newPhrase = 'Новая выдуманная парольная фраза';
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
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
  Future<void> start() async {
    await a.setup(create: true);
    await b.setup();
    expect(a.sync.error, isNull);
    expect(b.sync.error, isNull);
  }

  Future<String> snapshot() async {
    final data = await a.repo.overview();
    await a.repo.saveStorage(
      name: 'Выдуманное',
      type: 'cash',
      liquidityId: data.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [
        data.currencies.firstWhere((c) => c.text('code') == 'RUB').id,
      ],
    );
    final id = await a.repo.createSnapshot('2026-01-10', '');
    final line = (await a.repo.snapshot(id)).lines.single;
    await a.repo.saveLine(line.id, '10', '2', '');
    return id;
  }

  Future<Map<String, List<Object?>>> finances() async => {
    for (final table in [
      'currency',
      'liquidity_level',
      'storage',
      'storage_currency',
      'snapshot',
      'snapshot_line',
      'snapshot_rate',
      'audit_log',
      'rate_cache',
    ])
      table: [
        for (final row in await a.repo.query(
          'SELECT * FROM $table ORDER BY id',
        ))
          row.values,
      ],
  };

  test('Обычное сохранение не отправляет; фиксация запускает; фон отправляет непустую очередь', () async {
    await start();
    a.repo.onChanged = a.sync.changed;
    a.repo.onFinalized = a.sync.schedule;
    final before = disk.files.length;
    final id = await snapshot();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(disk.files.length, before);
    expect(await a.sync.refreshPending(), isTrue);
    await a.repo.finalizeSnapshot(id);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (a.sync.busy) await a.sync.synchronize();
    expect(a.sync.error, isNull);
    expect(await a.sync.refreshPending(), isFalse);
    await a.repo.saveSnapshotHeader(id, '2026-01-10', 'После фиксации');
    expect(await a.sync.refreshPending(), isTrue);
    await a.sync.sendPending();
    expect(await a.sync.refreshPending(), isFalse);
    final after = disk.publications.length;
    await a.sync.sendPending();
    expect(disk.publications.length, after);
  });
  test('Выход: немедленно при блокировке/пустой очереди, ожидание ≤ лимита и закрытие при ошибке', () async {
    var calls = 0, shown = 0;
    await exchangeBeforeExit(
      unlocked: false,
      needed: () async => true,
      exchange: () async {
        calls++;
      },
      showWaiting: () {
        shown++;
      },
    );
    await exchangeBeforeExit(
      unlocked: true,
      needed: () async => false,
      exchange: () async {
        calls++;
      },
      showWaiting: () {
        shown++;
      },
    );
    expect(calls, 0);
    expect(shown, 0);
    await exchangeBeforeExit(
      unlocked: true,
      needed: () async => true,
      exchange: () async {
        calls++;
        throw StateError('синтетический сбой');
      },
      showWaiting: () {
        shown++;
      },
    );
    final watch = Stopwatch()..start();
    await exchangeBeforeExit(
      unlocked: true,
      needed: () async => true,
      exchange: () => Completer<void>().future,
      showWaiting: () {
        shown++;
      },
      timeout: const Duration(milliseconds: 20),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(shown, 2);
  });
  test('Обновление токена не меняет базу, очередь, курсоры, ключ; чужой набор отклонён', () async {
    await start();
    await snapshot();
    final tables = ['sync_outbox', 'sync_local', 'snapshot'];
    final before = {
      for (final table in tables)
        table: [
          for (final row in await a.repo.query('SELECT * FROM $table'))
            row.values,
        ],
    };
    final config =
        jsonDecode(a.secrets.values[SyncService.credentialsKey]!) as Map;
    await a.sync.refreshToken('synthetic-new-token', exchange: false);
    expect(a.sync.error, isNull);
    final updated =
        jsonDecode(a.secrets.values[SyncService.credentialsKey]!) as Map;
    expect(updated['token'], 'synthetic-new-token');
    expect(updated['key'], config['key']);
    expect(updated['meta'], config['meta']);
    for (final table in tables) {
      expect([
        for (final row in await a.repo.query('SELECT * FROM $table'))
          row.values,
      ], before[table]);
    }
    final meta = Uint8List.fromList(disk.files['${syncRoot}meta']!);
    final other = jsonDecode(utf8.decode(meta)) as Map;
    other['dataset'] = '00000000-0000-4000-8000-000000000099';
    disk.files['${syncRoot}meta'] = Uint8List.fromList(
      utf8.encode(jsonEncode(other)),
    );
    await a.sync.refreshToken('synthetic-other-token', exchange: false);
    expect(a.sync.error, contains('другой набор'));
    expect(jsonDecode(a.secrets.values[SyncService.credentialsKey]!), updated);
    disk.files['${syncRoot}meta'] = meta;
  });
  for (final failure in [
    'upload',
    'pointer',
    'lost-ack',
    'marker',
    'cleanup',
  ]) {
    test(
      'Смена фразы: $failure, возобновление и восстановление второго устройства',
      () async {
        await start();
        final id = await snapshot();
        await a.sync.synchronize();
        final before = await finances();
        disk.files['${syncRoot}old.part'] = Uint8List.fromList([1]);
        disk.files['${syncRoot}current.fresh.part'] = Uint8List.fromList([2]);
        disk.modified['${syncRoot}current.fresh.part'] = DateTime.now().toUtc();
        if (failure == 'upload') disk.interruptUpload = true;
        if (failure == 'pointer') disk.failReplace = '${syncRoot}current';
        if (failure == 'lost-ack') disk.loseReplaceAck = true;
        if (failure == 'marker') disk.failReplace = '${syncRoot}meta';
        if (failure == 'cleanup') disk.failDelete = '${syncRoot}log/';
        await a.sync.changePhrase(newPhrase);
        expect(a.sync.error, isNotNull);
        expect(disk.deleted, isEmpty);
        expect(
          disk.files.keys.any((p) => p.startsWith('${syncRoot}log/')),
          isTrue,
        );
        expect(await finances(), before);
        disk.failReplace = null;
        disk.failDelete = null;
        disk.modified['${syncRoot}old.part'] = DateTime.now().toUtc().subtract(
          const Duration(hours: 25),
        );
        final reopened = SyncService(
          a.repo,
          a.secrets,
          diskFactory: (_) => disk,
          derive: fastKdf,
        );
        addTearDown(reopened.dispose);
        await reopened.load();
        await reopened.synchronize();
        expect(reopened.error, isNull);
        expect(await finances(), before);
        final current =
            jsonDecode(utf8.decode(disk.files['${syncRoot}current']!)) as Map;
        expect(current['format'], 2);
        expect(
          disk.files.containsKey('${syncRoot}sets/${current['dataset']}/meta'),
          isTrue,
        );
        expect(disk.files.containsKey('${syncRoot}old.part'), isFalse);
        expect(disk.files.containsKey('${syncRoot}current.fresh.part'), isTrue);
        expect(disk.deleted, contains('${syncRoot}log/'));
        await b.sync.synchronize();
        expect(
          b.sync.error,
          'Синхронизация на Диске пересоздана. Подключитесь заново — если парольную фразу меняли, введите новую',
        );
        await b.setup(passphrase: newPhrase);
        expect(b.sync.error, isNull);
        expect((await b.repo.snapshot(id)).lines.single.text('amount'), '10');
      },
    );
  }
  test(
    'Блокировка ждёт текущий обмен до лимита и сохраняет очередь при тайм-ауте',
    () async {
      await start();
      await snapshot();
      final before = await a.sync.journal.changes();
      final gate = Completer<void>();
      disk.pauseRead = gate;
      final flight = a.sync.synchronize();
      var released = false;
      final close = a.sync
          .release(timeout: const Duration(milliseconds: 30))
          .then((_) {
            released = true;
          });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(released, isFalse);
      await close;
      expect(released, isTrue);
      gate.complete();
      disk.pauseRead = null;
      await flight;
      expect(await a.sync.journal.changes(), before);
    },
  );

  test('Неудачный предварительный обмен не начинает смену фразы', () async {
    await start();
    disk.failRead = '${syncRoot}meta';
    final saved = a.secrets.values[SyncService.credentialsKey];
    await a.sync.changePhrase(newPhrase);
    expect(a.sync.error, isNotNull);
    expect(a.secrets.values[SyncService.credentialsKey], saved);
    expect(await a.sync.journal.get('rotation_plan'), isNull);
    expect(disk.files.keys.any((p) => p.contains('/sets/')), isFalse);
  });
  test('Новое создание format2 и подключение работают; старый format1 читается без перенастройки', () async {
    final modern = SyncService(
      a.repo,
      a.secrets,
      diskFactory: (_) => disk,
      derive: fastKdf,
    );
    addTearDown(modern.dispose);
    await modern.configure(token: syntheticToken, phrase: phrase, create: true);
    expect(modern.error, isNull);
    expect(disk.files.containsKey('${syncRoot}current'), isTrue);
    await b.setup();
    expect(b.sync.error, isNull);
    expect(
      (jsonDecode(b.secrets.values[SyncService.credentialsKey]!)
          as Map)['meta']['format'],
      2,
    );
  });
  test(
    'Повторная смена format2 → format2 удаляет только прежний набор',
    () async {
      await start();
      await snapshot();
      await a.sync.changePhrase(newPhrase);
      expect(a.sync.error, isNull);
      final first = (jsonDecode(
        utf8.decode(disk.files['${syncRoot}current']!),
      ) as Map)['dataset'];
      await a.sync.changePhrase('Ещё одна выдуманная длинная фраза');
      expect(a.sync.error, isNull);
      final second = (jsonDecode(
        utf8.decode(disk.files['${syncRoot}current']!),
      ) as Map)['dataset'];
      expect(second, isNot(first));
      expect(disk.files.containsKey('${syncRoot}sets/$first/meta'), isFalse);
      expect(disk.files.containsKey('${syncRoot}sets/$second/meta'), isTrue);
    },
  );
}

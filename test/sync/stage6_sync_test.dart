import 'dart:convert';
import 'dart:typed_data';

import 'package:delta/data/backup/finance_copy.dart';
import 'package:delta/data/sync/sync_service.dart';
import 'package:delta/data/sync/sync_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;

import '../support/test_database.dart';
import 'fake_disk.dart';
import 'sync_test.dart' show TestDevice, fastKdf, phrase, syntheticToken;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late FakeDisk disk;
  late TestDevice a, b;
  setUp(() async {
    disk = FakeDisk();
    final repo = await testRepository(
      now: () => DateTime.utc(2026, 11, 18, 12),
    );
    final secrets = MemorySecrets();
    a = TestDevice(
      repo,
      secrets,
      SyncService(repo, secrets, diskFactory: (_) => disk, derive: fastKdf),
    );
    b = await TestDevice.open(disk, 2);
    await a.setup(create: true);
    expect(a.sync.error, isNull);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<void> addPlace(TestDevice device, String name) async {
    final catalog = await device.repo.overview();
    await device.repo.saveStorage(
      name: name,
      type: 'cash',
      liquidityId: catalog.liquidity.first.id,
      organization: '',
      note: '',
      archived: false,
      currencyIds: [
        catalog.currencies.singleWhere((row) => row.text('code') == 'RUB').id,
      ],
    );
  }

  test('Отключение предупреждает об очереди, очищает локальную настройку и оставляет Диск', () async {
    await addPlace(a, 'Новое пробное место');
    final remote = Map.of(disk.files);
    final before = await readFinanceTables(a.repo.db);
    await a.sync.disconnect();
    expect(a.sync.error, contains('неотправленные изменения'));
    expect(a.sync.enabled, isTrue);
    await a.sync.disconnect(discardPending: true);
    expect(a.sync.error, isNull);
    expect(a.sync.enabled, isFalse);
    expect(a.sync.hasConfiguration, isFalse);
    expect(disk.files, remote);
    expect(a.secrets.values[SyncService.credentialsKey], isNull);
    expect(await a.repo.query('SELECT * FROM sync_local'), isEmpty);
    expect(await a.repo.query('SELECT * FROM sync_outbox'), isEmpty);
    expect(await readFinanceTables(a.repo.db), before);
    await a.sync.load();
    expect(a.sync.enabled, isFalse);
    await a.setup(replace: false);
    await b.setup();
    expect(a.sync.error, isNull);
    expect(b.sync.error, isNull);
    expect(
      (await b.repo.overview()).storages.single.text('name'),
      'Новое пробное место',
    );
  });

  test(
    'Полный обмен убирает старые .part в своём наборе и общем корне',
    () async {
      final pointer =
          jsonDecode(utf8.decode(disk.files['${syncRoot}current']!)) as Map;
      final base = '${syncRoot}sets/${pointer['dataset']}/';
      final bin = disk.files.keys.singleWhere((name) => name.endsWith('.bin'));
      final stale = '$bin.old.part';
      final fresh = '$bin.fresh.part';
      final broken = '$bin.error.part';
      final top = '${base}meta.old.part';
      const oldCurrent = '${syncRoot}current.abandoned.part';
      const oldMeta = '${syncRoot}meta.abandoned.part';
      const freshCurrent = '${syncRoot}current.in-progress.part';
      const missingTime = '${syncRoot}meta.unknown-age.part';
      const other = '${syncRoot}sets/other/meta.part';
      const rootDirectory = '${syncRoot}directory.part/';
      await disk.mkdir(rootDirectory);
      disk.modified[rootDirectory.substring(0, rootDirectory.length - 1)] =
          DateTime.utc(2026, 11, 16);
      disk.files[missingTime] = Uint8List.fromList([4, 5, 6]);
      for (final path in [
        stale,
        fresh,
        broken,
        top,
        oldCurrent,
        oldMeta,
        freshCurrent,
        other,
      ]) {
        disk.files[path] = Uint8List.fromList([4, 5, 6]);
        disk.modified[path] = path == fresh || path == freshCurrent
            ? DateTime.utc(2026, 11, 17, 12)
            : DateTime.utc(2026, 11, 17, 11, 59);
      }
      disk.failDelete = broken;
      await a.sync.synchronize(uploadOnly: true);
      expect(disk.deleted, isEmpty);
      await a.sync.synchronize();
      expect(a.sync.error, isNull);
      expect(disk.deleted, unorderedEquals([stale, top, oldCurrent, oldMeta]));
      expect(
        disk.files.keys,
        containsAll([
          fresh,
          broken,
          other,
          bin,
          freshCurrent,
          missingTime,
          '${syncRoot}current',
          '${syncRoot}meta',
          '${base}meta',
        ]),
      );
      expect(a.sync.journalStats, (files: 1, bytes: disk.files[bin]!.length));
      expect(disk.folders, contains(rootDirectory));
      const failedRoot = '${syncRoot}current.error.part';
      disk.files[failedRoot] = Uint8List.fromList([4, 5, 6]);
      disk.modified[failedRoot] = DateTime.utc(2026, 11, 16);
      disk.failDelete = failedRoot;
      await a.sync.synchronize();
      expect(a.sync.error, isNull);
      expect(disk.files.keys, contains(failedRoot));
      await a.sync.load();
      expect(a.sync.journalStats, (files: 1, bytes: disk.files[bin]!.length));
    },
  );

  test(
    'Замена данными отключённого устройства пересобирает журнал без слияния',
    () async {
      await addPlace(a, 'Старое место на Диске');
      await a.sync.synchronize();
      await addPlace(b, 'Восстановленное место');
      await b.sync.configure(
        token: syntheticToken,
        phrase: phrase,
        create: false,
        replaceFromDevice: true,
      );
      expect(b.sync.error, isNull);
      expect(b.sync.replacingDisk, isFalse);
      await a.sync.synchronize();
      expect(
        a.sync.error,
        'Синхронизация на Диске пересоздана. Подключитесь заново — если парольную фразу меняли, введите новую',
      );
      await a.setup();
      expect(a.sync.error, isNull);
      expect(
        (await a.repo.overview()).storages.single.text('name'),
        'Восстановленное место',
      );
    },
  );
}

part of 'sync_service.dart';

extension SyncMaintenance on SyncService {
  Future<void> refreshToken(String token, {bool exchange = true}) => _exclusive(
    () async {
      final candidate = diskFactory(token.trim());
      var installed = false;
      try {
        final active = await _active(candidate);
        var expected = _meta!;
        var checker = _crypto!;
        if (active != null &&
            active.meta['dataset'] != expected['dataset'] &&
            _credentials['rotation'] != null) {
          final rotation = Map<String, dynamic>.from(
            _credentials['rotation'] as Map,
          );
          expected = Map<String, dynamic>.from(rotation['meta'] as Map);
          checker = SyncCrypto(
            SecretKey(base64Decode(rotation['key'] as String)),
          );
        }
        if (active == null ||
            SyncCrypto.checkAad(active.meta) != SyncCrypto.checkAad(expected) ||
            active.meta['check'] != expected['check']) {
          throw const SyncFailure(
            'На Диске другой набор данных. Вход не изменён.',
          );
        }
        await checker.check(active.meta);
        final config = {..._credentials, 'token': token.trim()};
        await secrets.write(SyncService.credentialsKey, jsonEncode(config));
        _credentials = config;
        _disk?.close();
        _disk = candidate;
        installed = true;
        if (exchange) {
          if (_credentials['rotation'] != null) {
            await _resumeRotation();
          } else {
            await _sync();
          }
        }
      } finally {
        if (!installed) candidate.close();
      }
    },
  );

  Future<void> _exclusive(Future<void> Function() action) {
    if (busy) throw const SyncFailure('Дождитесь завершения синхронизации.');
    if (!enabled) throw const SyncFailure('Сначала подключите синхронизацию.');
    _flight = _guard(action).whenComplete(() {
      _flight = null;
      _notify();
    });
    _notify();
    return _flight!;
  }

  Future<void> changePhrase(String phrase) => _exclusive(() async {
    if (phrase.length < 12) {
      throw const SyncFailure(
        'Используйте парольную фразу не короче 12 символов.',
      );
    }
    if (_credentials['rotation'] != null) {
      throw const SyncFailure(
        'Смена фразы уже начата. Продолжите её кнопкой синхронизации.',
      );
    }
    await _sync(); // Сначала полный обмен. Ошибка не создаёт намерения смены.
    await _prepareRotation(phrase, _credentials);
    await _resumeRotation();
  });

  Future<void> _prepareRotation(
    String phrase,
    Map<String, dynamic> credentials, {
    bool replaceFromDevice = false,
  }) async {
    final meta = SyncCrypto.header(format: 2);
    final crypto = await derive(phrase, meta);
    meta['check'] = base64Encode(
      await crypto.encrypt(
        utf8.encode(SyncCrypto.checkText),
        SyncCrypto.checkAad(meta),
      ),
    );
    await journal.set('rotation_plan', '');
    final nextCredentials = {
      ...credentials,
      'rotation': {
        if (replaceFromDevice) 'replaceFromDevice': true,
        'meta': meta,
        'key': base64Encode(await crypto.key.extractBytes()),
      },
    };
    await secrets.write(
      SyncService.credentialsKey,
      jsonEncode(nextCredentials),
    );
    _credentials = nextCredentials;
  }

  Future<void> _resumeRotation() async {
    _alive();
    final rotation = Map<String, dynamic>.from(_credentials['rotation'] as Map);
    final meta = Map<String, dynamic>.from(rotation['meta'] as Map);
    SyncCrypto.validate(meta);
    final crypto = SyncCrypto(
      SecretKey(base64Decode(rotation['key'] as String)),
    );
    await crypto.check(meta);
    final disk = _disk!, newBase = SyncService._layout(meta);
    var stored = await journal.get('rotation_plan');
    Map<String, dynamic> plan;
    if (stored == null || stored.isEmpty) {
      if (rotation['replaceFromDevice'] != true) await _sync();
      final entries = <Map<String, dynamic>>[];
      var boundary = 0;
      await repository.db.transaction(() async {
        for (final table in syncTables) {
          for (final row
              in await repository.db
                  .customSelect('SELECT * FROM $table')
                  .get()) {
            entries.add({'table': table, 'row': row.data});
          }
        }
        final row = await repository.db
            .customSelect('SELECT coalesce(max(seq),0) AS n FROM sync_outbox')
            .getSingle();
        boundary = row.read<int>('n');
      });
      final chunks = <String>[];
      for (var start = 0; start < entries.length;) {
        final number = chunks.length + 1;
        var end = start + 300 < entries.length ? start + 300 : entries.length;
        List<int> encode() => utf8.encode(
          jsonEncode({
            'format': 2,
            'dataset': meta['dataset'],
            'device': _device,
            'number': number,
            'entries': entries.sublist(start, end),
          }),
        );
        var clear = encode();
        while (clear.length + 28 > syncMaximumBytes && end - start > 1) {
          end = start + (end - start) ~/ 2;
          clear = encode();
        }
        if (clear.length + 28 > syncMaximumBytes) {
          throw const SyncFailure(
            'Одна запись слишком велика для синхронизации. Смена фразы не завершена.',
          );
        }
        chunks.add(
          base64Encode(
            await crypto.encrypt(clear, '${meta['dataset']}|$_device|$number'),
          ),
        );
        start = end;
      }
      plan = {
        'newDataset': meta['dataset'],
        'oldBase': _base,
        'oldDataset': _dataset,
        'boundary': boundary,
        'chunks': chunks,
        'uploaded': 0,
        'phase': 'uploading',
        'parts': [
          for (final name in await disk.list(_base))
            if (name.endsWith('.part')) '$_base$name',
        ],
      };
      await journal.set('rotation_plan', jsonEncode(plan));
    } else {
      plan = jsonDecode(stored) as Map<String, dynamic>;
    }
    final chunks = (plan['chunks'] as List).cast<String>();
    var active = await _active(disk);
    final isNew = active?.meta['dataset'] == meta['dataset'];
    if (!isNew && active?.meta['dataset'] != plan['oldDataset']) {
      throw const SyncFailure(
        'Синхронизация на Диске пересоздана. Подключитесь с новой парольной фразой',
      );
    }
    if (!isNew) {
      await disk.mkdir('${syncRoot}sets/');
      await disk.mkdir(newBase);
      await disk.mkdir('${newBase}log/');
      await disk.mkdir('${newBase}log/$_device/');
      await disk.publish(
        '${newBase}meta',
        Uint8List.fromList(utf8.encode(jsonEncode(meta))),
      );
      for (var i = plan['uploaded'] as int; i < chunks.length; i++) {
        _alive();
        await disk.publish(
          '${newBase}log/$_device/${(i + 1).toString().padLeft(20, '0')}.bin',
          base64Decode(chunks[i]),
        );
        plan['uploaded'] = i + 1;
        await journal.set('rotation_plan', jsonEncode(plan));
      }
      active = await _active(disk);
      if (active?.meta['dataset'] != plan['oldDataset']) {
        throw const SyncFailure(
          'Набор на Диске изменился. Смена фразы приостановлена.',
        );
      }
      _alive();
      await _pointCurrent(disk, meta);
    }
    // Pointer мог переключиться, но ответ потеряться. Всё ниже идемпотентно.
    if ((await _active(disk))?.meta['dataset'] != meta['dataset']) {
      throw const SyncFailure(
        'Набор на Диске изменился. Удаление прежних файлов отменено.',
      );
    }
    _credentials = {..._credentials, 'meta': meta, 'key': rotation['key']};
    await secrets.write(SyncService.credentialsKey, jsonEncode(_credentials));
    _meta = meta;
    _crypto = crypto;
    _base = newBase;
    if (plan['phase'] != 'adopted') {
      await repository.db.transaction(() async {
        await repository.db.customStatement(
          "DELETE FROM sync_local WHERE key LIKE 'cursor:%' OR key IN ('pending','next_batch')",
        );
        await repository.db.customStatement(
          'DELETE FROM sync_outbox WHERE seq<=?',
          [plan['boundary']],
        );
        await journal.set('dataset', meta['dataset'] as String);
        await journal.set('cursor:$_device', '${chunks.length}');
        await journal.set('next_batch', '${chunks.length + 1}');
        await journal.set('initializing', '0');
        plan['phase'] = 'adopted';
        await journal.set('rotation_plan', jsonEncode(plan));
      });
    }
    _alive();
    // Старый root/meta заменяется маркером, не оставляется доступным старому ПО.
    await disk.replace(
      '${syncRoot}meta',
      Uint8List.fromList(
        utf8.encode(jsonEncode({'format': 2, 'layout': 'sets'})),
      ),
    );
    if (plan['oldBase'] == syncRoot) {
      await disk.delete('${syncRoot}log/');
    } else {
      await disk.delete(plan['oldBase'] as String);
    }
    for (final path in (plan['parts'] as List).cast<String>()) {
      await disk.delete(path);
    }
    _credentials.remove('rotation');
    await secrets.write(SyncService.credentialsKey, jsonEncode(_credentials));
    await journal.set('rotation_plan', '');
    await _sync();
  }
}

import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../finance_repository.dart';
import '../security/secret_store.dart';
import 'sync_crypto.dart';
import 'sync_error.dart';
import 'sync_journal.dart';
import 'sync_storage.dart';
part 'sync_rotation.dart';

typedef DiskFactory = SyncDisk Function(String token);
typedef CryptoDeriver = Future<SyncCrypto> Function(
  String phrase,
  Map<String, dynamic> meta,
);

class _Remote {
  final entries = <Map<String, dynamic>>[];
  final cursors = <String, int>{};
  final completed = <String, int>{};
}

class SyncService extends ChangeNotifier {
  SyncService(
    this.repository,
    this.secrets, {
    required this.diskFactory,
    CryptoDeriver? derive,
    this.initialFormat = 2,
  }) : derive = derive ?? SyncCrypto.derive,
       journal = SyncJournal(repository.db, repository.clock);
  final DriftFinanceRepository repository;
  final SecretStore secrets;
  final DiskFactory diskFactory;
  final CryptoDeriver derive;
  final int initialFormat;
  Map<String, dynamic> _credentials = {};
  String _base = syncRoot;
  bool hasPendingChanges = false;
  Future<void>? _release;
  final SyncJournal journal;
  SyncDisk? _disk;
  SyncCrypto? _crypto;
  Map<String, dynamic>? _meta;
  Future<void>? _flight;
  bool _again = false, _closed = false, _disconnecting = false;
  bool _settingsUnreadable = false;
  ({int files, int bytes})? journalStats;
  final Zone _zone = Zone.current;
  Timer? _timer;
  void schedule() {
    if (_closed || !enabled) return;
    _timer?.cancel();
    _timer = _zone.run(() => Timer(Duration.zero, synchronize));
  }

  void changed() {
    if (_closed) return;
    _zone.run(() => unawaited(refreshPending()));
  }

  Future<bool> refreshPending() async {
    if (_closed) return false;
    hasPendingChanges =
        (await journal.changes()).isNotEmpty ||
        (await journal.get('pending') ?? '').isNotEmpty;
    _notify();
    return hasPendingChanges;
  }

  Future<void> sendPending() async {
    if (busy) {
      await _flight;
      return;
    }
    if (await refreshPending()) await synchronize(uploadOnly: true);
  }

  Future<void> release({Duration timeout = const Duration(seconds: 15)}) {
    if (_closed) return SynchronousFuture<void>(null);
    if (_release != null) return _release!;
    final flight = _flight;
    if (flight == null) {
      dispose();
      return _release = SynchronousFuture<void>(null);
    }
    return _release = flight
        .timeout(timeout)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(dispose);
  }

  static String _layout(Map<String, dynamic> meta) =>
      meta['format'] == 1 ? syncRoot : '${syncRoot}sets/${meta['dataset']}/';
  Future<({String base, Map<String, dynamic> meta})?> _active(
    SyncDisk disk,
  ) async {
    final pointer = await disk.read('${syncRoot}current');
    var base = syncRoot;
    if (pointer != null) {
      try {
        final json = jsonDecode(utf8.decode(pointer)) as Map;
        if (json['format'] != 2 ||
            !RegExp(r'^[a-f0-9-]{36}$').hasMatch(json['dataset'] as String)) {
          throw const FormatException();
        }
        base = '${syncRoot}sets/${json['dataset']}/';
      } catch (_) {
        throw const SyncFailure(
          'Данные пришли с другой версии Delta. Обновите приложение на этом устройстве',
        );
      }
    }
    final bytes = await disk.read('${base}meta');
    if (bytes == null) {
      if (pointer != null) {
        throw const SyncFailure(
          'Текущий набор синхронизации недоступен. Повторите позже.',
        );
      }
      return null;
    }
    final meta = _decodeMeta(bytes);
    if (pointer != null && _layout(meta) != base) {
      throw const SyncFailure('Повреждён указатель синхронизации.');
    }
    return (base: base, meta: meta);
  }

  Future<void> _pointCurrent(SyncDisk disk, Map<String, dynamic> meta) async {
    await disk.replace(
      '${syncRoot}current',
      Uint8List.fromList(
        utf8.encode(jsonEncode({'format': 2, 'dataset': meta['dataset']})),
      ),
    );
    // Старые выпуски останавливаются до чтения/записи прежнего журнала.
    await disk.replace(
      '${syncRoot}meta',
      Uint8List.fromList(
        utf8.encode(jsonEncode({'format': 2, 'layout': 'sets'})),
      ),
    );
  }

  String? error;
  DateTime? lastSync;
  bool get enabled => _disk != null && !_disconnecting;
  bool get hasConfiguration =>
      _disk != null ||
      _credentials.isNotEmpty ||
      _disconnecting ||
      _settingsUnreadable;
  bool get busy => _flight != null;
  bool get phraseChangePending => _credentials['rotation'] != null;
  bool get replacingDisk =>
      (_credentials['rotation'] as Map?)?['replaceFromDevice'] == true;
  String get _device => repository.deviceId;
  String get _dataset => _meta!['dataset'] as String;
  static const credentialsKey = 'sync_credentials_v1';

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _alive() {
    if (_closed) throw const SyncFailure('Синхронизация остановлена.');
  }

  Future<void> load() async {
    _disk?.close();
    _disk = null;
    _crypto = null;
    _meta = null;
    _credentials = {};
    journalStats = null;
    _settingsUnreadable = false;
    error = null;
    try {
      _disconnecting = await journal.get('disconnecting') == '1';
      if (_disconnecting) {
        await _finishDisconnect();
        return;
      }
      final saved = await secrets.read(credentialsKey);
      if (saved != null && saved.isNotEmpty) _credentials = {'saved': true};
      final stats = (await journal.get('disk_stats') ?? '').split(':');
      if (stats.length == 2 &&
          int.tryParse(stats[0]) != null &&
          int.tryParse(stats[1]) != null) {
        journalStats = (files: int.parse(stats[0]), bytes: int.parse(stats[1]));
      }
      lastSync = DateTime.tryParse(await journal.get('last_sync') ?? '');
      if (saved == null || saved.isEmpty) return;
      final config = jsonDecode(saved) as Map<String, dynamic>;
      _credentials = config;
      if (config['provider'] != 'yandex-rest-v1') {
        lastSync = null;
        return; // Старые login/password не являются настройкой REST/OAuth.
      }
      final meta = Map<String, dynamic>.from(config['meta'] as Map);
      SyncCrypto.validate(meta);
      final key = base64Decode(config['key'] as String);
      if (key.length != 32) throw const FormatException();
      final crypto = SyncCrypto(SecretKey(key));
      await crypto.check(meta);
      _alive();
      _meta = meta;
      _crypto = crypto;
      _disk = diskFactory(config['token'] as String);
      _base = _layout(meta);
      await refreshPending();
    } catch (_) {
      _settingsUnreadable = true;
      error =
          'Не удалось открыть настройку синхронизации. Подключитесь заново.';
    }
    _notify();
  }

  Future<bool> hasLocalData() => journal.hasData();

  /// Резервное восстановление и настройка обмена используют один локальный замок.
  Future<T> withoutSync<T>(Future<T> Function() action) async {
    if (busy || hasConfiguration) {
      throw const SyncFailure(
        'Сначала отключите синхронизацию на этом устройстве',
      );
    }
    _alive();
    final done = Completer<void>();
    _flight = done.future;
    _notify();
    try {
      return await action();
    } finally {
      _flight = null;
      done.complete();
      _notify();
    }
  }

  Future<void> disconnect({bool discardPending = false}) {
    if (busy) throw const SyncFailure('Дождитесь завершения синхронизации.');
    _alive();
    _timer?.cancel();
    final pending = _guard(() async {
      if (!_disconnecting && await refreshPending() && !discardPending) {
        throw const SyncFailure(
          'Есть неотправленные изменения. Сначала синхронизируйте устройство.',
        );
      }
      await journal.set('disconnecting', '1');
      _disconnecting = true;
      await _finishDisconnect();
    });
    _flight = pending.whenComplete(() {
      _flight = null;
      _notify();
    });
    _notify();
    return _flight!;
  }

  Future<void> _finishDisconnect() async {
    await secrets.delete(credentialsKey);
    await repository.db.transaction(() async {
      await repository.db.customStatement('DELETE FROM sync_outbox');
      await repository.db.customStatement('DELETE FROM sync_local');
    });
    _disk?.close();
    _disk = null;
    _meta = null;
    _crypto = null;
    _credentials = {};
    _disconnecting = false;
    _settingsUnreadable = false;
    _base = syncRoot;
    lastSync = null;
    journalStats = null;
    hasPendingChanges = false;
    _notify();
  }

  Future<void> configure({
    required String token,
    required String phrase,
    required bool create,
    bool replace = true,
    bool replaceFromDevice = false,
  }) {
    if (_flight != null) {
      throw const SyncFailure('Дождитесь завершения синхронизации.');
    }
    final future = _guard(
      () => _configure(token, phrase, create, replace, replaceFromDevice),
    );
    _flight = future.whenComplete(() {
      _flight = null;
      _notify();
    });
    _notify();
    return _flight!;
  }

  Future<void> _configure(
    String token,
    String phrase,
    bool create,
    bool replace,
    bool replaceFromDevice,
  ) async {
    _alive();
    if (_disconnecting) {
      throw const SyncFailure('Завершите отключение синхронизации.');
    }
    if (phrase.length < 12) {
      throw const SyncFailure(
        'Используйте парольную фразу не короче 12 символов.',
      );
    }
    final disk = diskFactory(token.trim());
    var installed = false;
    try {
      if (create) {
        await disk.mkdir(syncRoot);
        if (initialFormat == 1) await disk.mkdir('${syncRoot}log/');
      }
      final active = await _active(disk);
      final bytes = active == null
          ? null
          : Uint8List.fromList(utf8.encode(jsonEncode(active.meta)));
      Map<String, dynamic> meta;
      SyncCrypto crypto;
      if (create) {
        if (bytes != null) {
          throw const SyncFailure(
            'Синхронизация уже создана. Выберите «Подключиться».',
          );
        }
        meta = SyncCrypto.header(format: initialFormat);
        crypto = await derive(phrase, meta);
        meta['check'] = base64Encode(
          await crypto.encrypt(
            utf8.encode(SyncCrypto.checkText),
            SyncCrypto.checkAad(meta),
          ),
        );
        // Meta публикуется после локального сохранения ключа и намерения создать журнал.
      } else {
        if (bytes == null) {
          throw const SyncFailure('Синхронизация на Диске ещё не создана.');
        }
        meta = _decodeMeta(bytes);
        crypto = await derive(phrase, meta);
        await crypto.check(meta); // До изменения локальной базы и настроек.
      }
      if (!create && replaceFromDevice) {
        if (hasConfiguration || !await journal.hasData()) {
          throw const SyncFailure(
            'Отключите синхронизацию и проверьте данные на этом устройстве.',
          );
        }
        final credentials = {
          'provider': 'yandex-rest-v1',
          'token': token.trim(),
          'meta': meta,
          'key': base64Encode(await crypto.key.extractBytes()),
        };
        await _prepareRotation(phrase, credentials, replaceFromDevice: true);
        _disk = disk;
        _meta = meta;
        _crypto = crypto;
        _base = _layout(meta);
        installed = true;
        await _resumeRotation();
        return;
      }
      final remote = create
          ? _Remote()
          : await _download(disk, crypto, meta, fresh: true);
      if (!create && remote.entries.isEmpty) {
        throw const SyncFailure(
          'Первое устройство ещё не загрузило данные. Завершите синхронизацию на нём.',
        );
      }
      _alive();
      await repository.db.transaction(() async {
        await repository.db.customStatement('PRAGMA defer_foreign_keys=ON');
        await journal.set('applying', '1');
        if (create || replace) {
          if (!create) {
            for (final table in syncTables.reversed) {
              await repository.db.customStatement('DELETE FROM $table');
            }
          }
          await repository.db.customStatement('DELETE FROM sync_outbox');
          if (create) await SyncJournal.enqueueAll(repository.db);
        } else if (!hasConfiguration) {
          await repository.db.customStatement('DELETE FROM sync_outbox');
          await SyncJournal.enqueueAll(repository.db);
        }
        await repository.db.customStatement(
          "DELETE FROM sync_local WHERE key LIKE 'cursor:%' OR key IN ('pending','next_batch','last_sync','disk_stats')",
        );
        await journal.apply(remote.entries);
        for (final entry in remote.cursors.entries) {
          await journal.set('cursor:${entry.key}', '${entry.value}');
        }
        await journal.set(
          'next_batch',
          '${(remote.cursors[_device] ?? 0) + 1}',
        );
        await journal.set('dataset', meta['dataset'] as String);
        await journal.set('initializing', create ? '1' : '0');
        await journal.set('applying', '0');
      });
      _credentials = {
        'provider': 'yandex-rest-v1',
        'token': token.trim(),
        'meta': meta,
        'key': base64Encode(await crypto.key.extractBytes()),
      };
      await secrets.write(credentialsKey, jsonEncode(_credentials));
      _disk?.close();
      _disk = disk;
      _meta = meta;
      _crypto = crypto;
      _base = _layout(meta);
      installed = true;
      _settingsUnreadable = false;
      lastSync = null;
      journalStats = null;
      do {
        _again = false;
        await _sync();
      } while (_again && !_closed);
    } finally {
      if (!installed) disk.close();
    }
  }

  Map<String, dynamic> _decodeMeta(Uint8List bytes) {
    try {
      final meta = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      SyncCrypto.validate(meta);
      return meta;
    } on SyncFailure {
      rethrow;
    } catch (_) {
      throw const SyncFailure('Повреждён файл настройки синхронизации.');
    }
  }

  Future<_Remote> _download(
    SyncDisk disk,
    SyncCrypto crypto,
    Map<String, dynamic> meta, {
    bool fresh = false,
    bool maintenance = false,
  }) async {
    final result = _Remote();
    final base = _layout(meta);
    final devices = await disk.listEntries('${base}log/');
    if (maintenance && meta['format'] == 2) {
      await _cleanListedParts(disk, base);
      await _removeStaleParts(disk, '${base}log/', devices);
    }
    for (final deviceEntry in devices) {
      final device = deviceEntry.name;
      if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(device)) continue;
      var cursor = fresh
          ? 0
          : int.parse(await journal.get('cursor:$device') ?? '0');
      final folder = '${base}log/$device/';
      final entries = await disk.listEntries(folder);
      if (maintenance && meta['format'] == 2) {
        await _removeStaleParts(disk, folder, entries);
      }
      final files = entries.where(
        (entry) =>
            !entry.directory && RegExp(r'^\d{20}\.bin$').hasMatch(entry.name),
      );
      final names = files.map((entry) => entry.name).toList()..sort();
      for (final file in files) {
        result.completed['$folder${file.name}'] = file.size ?? 0;
      }
      for (final name in names) {
        final number = int.parse(name.substring(0, 20));
        if (number <= cursor) continue;
        if (number != cursor + 1) {
          throw const SyncFailure(
            'В журнале отсутствует пачка. Повторите после синхронизации другого устройства.',
          );
        }
        final bytes = await disk.read('$folder$name');
        if (bytes == null) {
          throw const SyncFailure(
            'Пачка временно недоступна. Повторите позже.',
          );
        }
        final clear = await crypto.decrypt(
          bytes,
          '${meta['dataset']}|$device|$number',
        );
        try {
          final batch = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
          if (batch['format'] != meta['format'] ||
              batch['dataset'] != meta['dataset'] ||
              batch['device'] != device ||
              batch['number'] != number) {
            throw const FormatException();
          }
          result.entries.addAll(
            await journal.validate(batch['entries'] as List),
          );
        } on SyncFailure {
          rethrow;
        } catch (_) {
          throw const SyncFailure('Повреждён формат пачки синхронизации.');
        }
        cursor = number;
      }
      result.cursors[device] = cursor;
    }
    return result;
  }

  Future<void> _cleanListedParts(SyncDisk disk, String folder) async {
    try {
      await _removeStaleParts(disk, folder, await disk.listEntries(folder));
    } catch (_) {
      developer.log(
        'Не удалось проверить временные файлы журнала.',
        name: 'delta.sync',
      );
    }
  }

  Future<void> _removeStaleParts(
    SyncDisk disk,
    String folder,
    List<SyncDiskEntry> entries,
  ) async {
    final cutoff = repository.now().toUtc().subtract(const Duration(hours: 24));
    for (final entry in entries) {
      if (_closed) return;
      if (entry.directory ||
          !RegExp(r'^[a-zA-Z0-9._-]*\.part$').hasMatch(entry.name) ||
          entry.modified?.isBefore(cutoff) != true) {
        continue;
      }
      try {
        await disk.delete('$folder${entry.name}');
      } catch (_) {
        developer.log(
          'Не удалось убрать временный файл журнала.',
          name: 'delta.sync',
        );
      }
    }
  }

  Future<void> synchronize({bool uploadOnly = false}) {
    if (_closed || !enabled) return Future.value();
    if (_flight != null) {
      _again = true;
      return _flight!;
    }
    final future = _guard(() async {
      do {
        _again = false;
        if (_credentials['rotation'] != null) {
          await _resumeRotation();
        } else {
          await _sync(uploadOnly: uploadOnly);
        }
      } while (_again && !_closed);
    });
    _flight = future.whenComplete(() {
      _flight = null;
      _notify();
    });
    _notify();
    return _flight!;
  }

  Future<void> _guard(Future<void> Function() action) async {
    error = null;
    try {
      await action();
    } on SyncFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'Не удалось выполнить синхронизацию. Локальные изменения сохранены; повторите позже.';
    } finally {
      _notify();
    }
  }

  Future<void> _sync({bool uploadOnly = false}) async {
    _alive();
    final disk = _disk!, crypto = _crypto!;
    final initializing = await journal.get('initializing') == '1';
    final active = await _active(disk);
    if (active != null && active.meta['dataset'] != _dataset) {
      if (active.meta['format'] == 2) {
        throw const SyncFailure(syncRecreatedMessage);
      }
      throw const SyncFailure(
        'На Диске другая синхронизация. Подключитесь заново.',
      );
    }
    if (initializing) {
      if (_meta!['format'] == 2) {
        await disk.mkdir('${syncRoot}sets/');
        await disk.mkdir(_base);
      }
      await disk.mkdir('${_base}log/');
      await disk.publish(
        '${_base}meta',
        Uint8List.fromList(utf8.encode(jsonEncode(_meta))),
      );
    } else if (active == null) {
      throw const SyncFailure(
        'Папка синхронизации недоступна. Данные не отправлены.',
      );
    }
    if (active != null &&
        (SyncCrypto.checkAad(active.meta) != SyncCrypto.checkAad(_meta!) ||
            active.meta['check'] != _meta!['check'])) {
      throw const SyncFailure(
        'На Диске другая синхронизация. Подключитесь заново.',
      );
    }
    if (await journal.get('dataset') != _dataset) {
      throw const SyncFailure(
        'Локальная настройка синхронизации не совпала. Подключитесь заново.',
      );
    }
    if (!uploadOnly) await _cleanListedParts(disk, syncRoot);
    final remote = uploadOnly
        ? null
        : await _download(disk, crypto, _meta!, maintenance: true);
    if (remote != null) {
      _alive();
      await repository.db.transaction(() async {
        await repository.db.customStatement('PRAGMA defer_foreign_keys=ON');
        await journal.set('applying', '1');
        await journal.apply(remote.entries);
        for (final entry in remote.cursors.entries) {
          await journal.set('cursor:${entry.key}', '${entry.value}');
        }
        await journal.set('applying', '0');
      });
    }
    final folder = '${_base}log/$_device/';
    await disk.mkdir(folder);
    while (!_closed) {
      var pending = await journal.get('pending');
      if (pending == null || pending.isEmpty) {
        final changes = await journal.changes();
        if (changes.isEmpty) break;
        final number = int.parse(await journal.get('next_batch') ?? '1');
        final clear = utf8.encode(
          jsonEncode({
            'format': _meta!['format'],
            'dataset': _dataset,
            'device': _device,
            'number': number,
            'entries': [
              for (final c in changes) {'table': c['table'], 'row': c['row']},
            ],
          }),
        );
        final cipher = await crypto.encrypt(
          clear,
          '$_dataset|$_device|$number',
        );
        if (cipher.length > syncMaximumBytes) {
          throw const SyncFailure(
            'Изменения слишком велики для одной пачки. Данные не потеряны.',
          );
        }
        pending = jsonEncode({
          'number': number,
          'lastSeq': changes.last['seq'],
          'bytes': base64Encode(cipher),
        });
        await journal.set('pending', pending);
      }
      final payload = jsonDecode(pending) as Map<String, dynamic>;
      final number = payload['number'] as int;
      final path = '$folder${number.toString().padLeft(20, '0')}.bin';
      final bytes = base64Decode(payload['bytes'] as String);
      await disk.publish(path, bytes);
      if (remote != null) remote.completed[path] = bytes.length;
      _alive();
      await repository.db.transaction(() async {
        await repository.db.customStatement(
          'DELETE FROM sync_outbox WHERE seq<=?',
          [payload['lastSeq']],
        );
        await journal.set('cursor:$_device', '$number');
        await journal.set('next_batch', '${number + 1}');
        await journal.set('pending', '');
      });
    }
    _alive();
    if (initializing && _meta!['format'] == 2) {
      await _pointCurrent(disk, _meta!);
    }
    await journal.set('initializing', '0');
    await refreshPending();
    if (remote != null) {
      final files = remote.completed.length;
      final bytes = remote.completed.values.fold(
        0,
        (int sum, size) => sum + size,
      );
      await journal.set('disk_stats', '$files:$bytes');
      journalStats = (files: files, bytes: bytes);
    }
    lastSync = DateTime.now().toUtc();
    await journal.set('last_sync', lastSync!.toIso8601String());
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _disk?.close();
    super.dispose();
  }
}

import 'dart:convert';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../finance_repository.dart';
import '../security/secret_store.dart';
import 'sync_crypto.dart';
import 'sync_error.dart';
import 'sync_journal.dart';
import 'sync_storage.dart';

typedef DiskFactory = SyncDisk Function(String login, String password);
typedef CryptoDeriver = Future<SyncCrypto> Function(
  String phrase,
  Map<String, dynamic> meta,
);

class _Remote {
  final entries = <Map<String, dynamic>>[];
  final cursors = <String, int>{};
}

class SyncService extends ChangeNotifier {
  SyncService(
    this.repository,
    this.secrets, {
    required this.diskFactory,
    CryptoDeriver? derive,
  }) : derive = derive ?? SyncCrypto.derive,
       journal = SyncJournal(repository.db, repository.clock);
  final DriftFinanceRepository repository;
  final SecretStore secrets;
  final DiskFactory diskFactory;
  final CryptoDeriver derive;
  final SyncJournal journal;
  SyncDisk? _disk;
  SyncCrypto? _crypto;
  Map<String, dynamic>? _meta;
  Future<void>? _flight;
  bool _again = false, _closed = false;
  final Zone _zone = Zone.current;
  Timer? _timer;
  void schedule() {
    if (_closed || !enabled) return;
    _timer?.cancel();
    // onChanged вызывается внутри drift-транзакции. Таймер не должен
    // унаследовать её Zone и затем использовать уже закрытый executor.
    _timer = _zone.run(
      () => Timer(const Duration(milliseconds: 500), synchronize),
    );
  }

  String? error;
  DateTime? lastSync;
  bool get enabled => _disk != null;
  bool get busy => _flight != null;
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
    try {
      final saved = await secrets.read(credentialsKey);
      lastSync = DateTime.tryParse(await journal.get('last_sync') ?? '');
      if (saved == null || saved.isEmpty) return;
      final config = jsonDecode(saved) as Map<String, dynamic>;
      final meta = Map<String, dynamic>.from(config['meta'] as Map);
      SyncCrypto.validate(meta);
      final key = base64Decode(config['key'] as String);
      if (key.length != 32) throw const FormatException();
      final crypto = SyncCrypto(SecretKey(key));
      await crypto.check(meta);
      _alive();
      _meta = meta;
      _crypto = crypto;
      _disk = diskFactory(
        config['login'] as String,
        config['password'] as String,
      );
    } catch (_) {
      error =
          'Не удалось открыть настройку синхронизации. Подключитесь заново.';
    }
    _notify();
  }

  Future<bool> hasLocalData() => journal.hasData();

  Future<void> configure({
    required String login,
    required String password,
    required String phrase,
    required bool create,
    bool replace = true,
  }) {
    if (_flight != null) {
      throw const SyncFailure('Дождитесь завершения синхронизации.');
    }
    final future = _guard(
      () => _configure(login, password, phrase, create, replace),
    );
    _flight = future.whenComplete(() {
      _flight = null;
      _notify();
    });
    _notify();
    return _flight!;
  }

  Future<void> _configure(
    String login,
    String password,
    String phrase,
    bool create,
    bool replace,
  ) async {
    _alive();
    if (phrase.length < 12) {
      throw const SyncFailure(
        'Используйте парольную фразу не короче 12 символов.',
      );
    }
    final disk = diskFactory(login.trim(), password);
    var installed = false;
    try {
      if (create) {
        await disk.mkdir(syncRoot);
        await disk.mkdir('${syncRoot}log/');
      }
      final bytes = await disk.read('${syncRoot}meta');
      Map<String, dynamic> meta;
      SyncCrypto crypto;
      if (create) {
        if (bytes != null) {
          throw const SyncFailure(
            'Синхронизация уже создана. Выберите «Подключиться».',
          );
        }
        meta = SyncCrypto.header();
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
          if (create) {
            for (final table in syncTables) {
              for (final row
                  in await repository.db
                      .customSelect('SELECT * FROM $table')
                      .get()) {
                await repository.db.customStatement(
                  'INSERT INTO sync_outbox(entity,payload) VALUES (?,?)',
                  [table, jsonEncode(row.data)],
                );
              }
            }
          }
        }
        await repository.db.customStatement(
          "DELETE FROM sync_local WHERE key LIKE 'cursor:%' OR key IN ('pending','next_batch','last_sync')",
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
      await secrets.write(
        credentialsKey,
        jsonEncode({
          'login': login.trim(),
          'password': password,
          'meta': meta,
          'key': base64Encode(await crypto.key.extractBytes()),
        }),
      );
      _disk?.close();
      _disk = disk;
      _meta = meta;
      _crypto = crypto;
      installed = true;
      lastSync = null;
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
  }) async {
    final result = _Remote();
    final devices = await disk.list('${syncRoot}log/');
    for (final device in devices) {
      if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(device)) continue;
      var cursor = fresh
          ? 0
          : int.parse(await journal.get('cursor:$device') ?? '0');
      final folder = '${syncRoot}log/$device/';
      final names = (await disk.list(
        folder,
      )).where((s) => RegExp(r'^\d{20}\.bin$').hasMatch(s)).toList()..sort();
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
          if (batch['format'] != 1 ||
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

  Future<void> synchronize() {
    if (_closed || !enabled) return Future.value();
    if (_flight != null) {
      _again = true;
      return _flight!;
    }
    final future = _guard(() async {
      do {
        _again = false;
        await _sync();
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

  Future<void> _sync() async {
    _alive();
    final disk = _disk!, crypto = _crypto!;
    var bytes = await disk.read('${syncRoot}meta');
    if (bytes == null && await journal.get('initializing') == '1') {
      bytes = Uint8List.fromList(utf8.encode(jsonEncode(_meta)));
      await disk.publish('${syncRoot}meta', bytes);
    }
    if (bytes == null) {
      throw const SyncFailure(
        'Папка синхронизации недоступна. Данные не отправлены.',
      );
    }
    final remoteMeta = _decodeMeta(bytes);
    if (SyncCrypto.checkAad(remoteMeta) != SyncCrypto.checkAad(_meta!) ||
        remoteMeta['check'] != _meta!['check']) {
      throw const SyncFailure(
        'На Диске другая синхронизация. Подключитесь заново.',
      );
    }
    if (await journal.get('dataset') != _dataset) {
      throw const SyncFailure(
        'Локальная настройка синхронизации не совпала. Подключитесь заново.',
      );
    }
    final remote = await _download(disk, crypto, _meta!);
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
    final folder = '${syncRoot}log/$_device/';
    await disk.mkdir(folder);
    while (!_closed) {
      var pending = await journal.get('pending');
      if (pending == null || pending.isEmpty) {
        final changes = await journal.changes();
        if (changes.isEmpty) break;
        final number = int.parse(await journal.get('next_batch') ?? '1');
        final clear = utf8.encode(
          jsonEncode({
            'format': 1,
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
      await disk.publish(
        '$folder${number.toString().padLeft(20, '0')}.bin',
        base64Decode(payload['bytes'] as String),
      );
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
    await journal.set('initializing', '0');
    lastSync = DateTime.now().toUtc();
    await journal.set('last_sync', lastSync!.toIso8601String());
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _disk?.close();
    super.dispose();
  }
}

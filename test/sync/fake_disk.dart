import 'dart:typed_data';
import 'dart:async';

import 'package:delta/data/sync/sync_storage.dart';
import 'package:delta/data/sync/sync_error.dart';

/// Выдуманный Диск. Сбой PUT оставляет .part; потеря ACK оставляет готовый .bin.
class FakeDisk implements SyncDisk {
  final files = <String, Uint8List>{};
  final folders = <String>{};
  final publications = <String, List<Uint8List>>{};
  bool interruptUpload = false, loseAck = false, interruptMeta = false;
  String? failRead;
  Completer<void>? pauseRead;
  @override
  Future<void> mkdir(String path) async {
    if (!path.startsWith(syncRoot)) {
      throw const SyncFailure('Путь вне приложения.');
    }
    folders.add(path);
  }

  @override
  Future<Uint8List?> read(String path) async {
    await pauseRead?.future;
    if (!path.startsWith(syncRoot)) {
      throw const SyncFailure('Путь вне приложения.');
    }
    if (path == failRead) throw const SyncFailure('Нет сети.');
    final bytes = files[path];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<List<String>> list(String path) async {
    if (!path.startsWith(syncRoot)) {
      throw const SyncFailure('Путь вне приложения.');
    }
    return {...folders, ...files.keys}
        .where((p) => p.startsWith(path) && p != path)
        .map((p) => p.substring(path.length).split('/').first)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<void> publish(String path, Uint8List bytes) async {
    if (!path.startsWith(syncRoot)) {
      throw const SyncFailure('Путь вне приложения.');
    }
    if (interruptMeta && path.endsWith('/meta')) {
      interruptMeta = false;
      throw const SyncFailure('Нет сети при создании.');
    }
    publications.putIfAbsent(path, () => []).add(Uint8List.fromList(bytes));
    if (interruptUpload && path.endsWith('.bin')) {
      interruptUpload = false;
      files['$path.part'] = Uint8List.fromList(bytes.take(10).toList());
      throw const SyncFailure('Сетевое соединение прервано.');
    }
    if (files.containsKey(path)) {
      final old = files[path]!;
      if (old.length != bytes.length ||
          List.generate(old.length, (i) => old[i] != bytes[i]).any((v) => v)) {
        throw const SyncFailure('Конфликт файла.');
      }
    } else {
      files[path] = Uint8List.fromList(bytes);
    }
    if (loseAck && path.endsWith('.bin')) {
      loseAck = false;
      throw const SyncFailure('Ответ потерян.');
    }
  }

  String? failReplace;
  String? failDelete;
  bool loseReplaceAck = false;
  final deleted = <String>[];
  @override
  Future<void> replace(String path, Uint8List bytes) async {
    if (!path.startsWith(syncRoot)) {
      throw const SyncFailure('Путь вне приложения.');
    }
    if (path == failReplace) throw const SyncFailure('Обрыв переключения.');
    files[path] = Uint8List.fromList(bytes);
    if (loseReplaceAck) {
      loseReplaceAck = false;
      throw const SyncFailure('Ответ переключения потерян.');
    }
  }

  @override
  Future<void> delete(String path) async {
    if (!path.startsWith(syncRoot) || path == syncRoot) {
      throw const SyncFailure('Путь вне приложения.');
    }
    if (path == failDelete) throw const SyncFailure('Обрыв удаления.');
    deleted.add(path);
    files.removeWhere(
      (key, _) => key == path || path.endsWith('/') && key.startsWith(path),
    );
    folders.removeWhere(
      (key) => key == path || path.endsWith('/') && key.startsWith(path),
    );
  }

  @override
  void close() {}
}

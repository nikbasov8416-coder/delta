import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/backup/finance_copy.dart';

class DeltaFileDialogs {
  const DeltaFileDialogs();
  static const _platform = MethodChannel('delta/files');

  Future<bool> save(String name, Uint8List bytes) async {
    final extension = name.split('.').last;
    if (Platform.isAndroid) {
      return await _platform.invokeMethod<bool>('save', {
            'name': name,
            'extension': extension,
            'bytes': bytes,
          }) ??
          false;
    }
    final path = await _platform.invokeMethod<String>('save', {
      'name': name,
      'extension': extension,
    });
    if (path == null) return false;
    // Пишем рядом, чтобы при сбое предыдущий файл остался на месте.
    final temporary = File('$path.${const Uuid().v4()}.part');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(path);
      return true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<Uint8List?> openBackup() async {
    if (Platform.isAndroid) {
      return _platform.invokeMethod<Uint8List>('open', {
        'maximum': maximumBackupBytes,
      });
    }
    final path = await _platform.invokeMethod<String>('open');
    if (path == null) return null;
    final input = await File(path).open();
    try {
      final length = await input.length();
      if (length > maximumBackupBytes) {
        throw const BackupFailure('Слишком большой файл резервной копии.');
      }
      return await input.read(length);
    } finally {
      await input.close();
    }
  }

  Future<String> version() async {
    final info = await _platform.invokeMapMethod<String, String>('version');
    if (info == null) throw StateError('Не удалось прочитать версию.');
    return 'Версия ${info['version']} (сборка ${info['build']})';
  }
}

final fileDialogsProvider = Provider<DeltaFileDialogs>(
  (ref) => const DeltaFileDialogs(),
);
final applicationVersionProvider = FutureProvider<String>(
  (ref) => ref.watch(fileDialogsProvider).version(),
  retry: (_, _) => null,
);

import 'dart:typed_data';

const syncRoot = '/Apps/Finance/';
const syncMaximumBytes = 8 * 1024 * 1024;

/// Нейтральный контракт: WebDAV либо будущий REST/OAuth адаптер.
/// Пути логические, только внутри syncRoot. list возвращает имена прямых детей.
/// publish публикует готовый файл атомарно и без перезаписи: повтор тех же байтов
/// успешен; другие байты по существующему пути дают SyncFailure.
/// Незавершённые загрузки не попадают в список законченных .bin/meta.
abstract interface class SyncDisk {
  Future<void> mkdir(String path);
  Future<Uint8List?> read(String path);
  Future<List<String>> list(String path);
  Future<void> publish(String path, Uint8List bytes);
  void close();
}

import 'dart:typed_data';

const syncRoot = '/Apps/Finance/';
const syncMaximumBytes = 8 * 1024 * 1024;

class SyncDiskEntry {
  const SyncDiskEntry(
    this.name, {
    this.directory = false,
    this.size,
    this.modified,
  });
  final String name;
  final bool directory;
  final int? size;
  final DateTime? modified;
}

/// Нейтральный контракт: REST/OAuth или WebDAV.
/// Пути логические, только внутри syncRoot. list возвращает имена прямых детей.
/// publish публикует готовый файл атомарно и без перезаписи: повтор тех же байтов
/// успешен; другие байты по существующему пути дают SyncFailure.
/// Незавершённые загрузки не попадают в список законченных .bin/meta.
abstract interface class SyncDisk {
  Future<void> mkdir(String path);
  Future<Uint8List?> read(String path);
  Future<List<String>> list(String path);
  Future<List<SyncDiskEntry>> listEntries(String path);
  Future<void> publish(String path, Uint8List bytes);

  /// Атомарная замена служебного указателя/маркера, готовые пачки не заменяет.
  Future<void> replace(String path, Uint8List bytes);

  /// Идемпотентное окончательное удаление только внутри syncRoot.
  Future<void> delete(String path);
  void close();
}

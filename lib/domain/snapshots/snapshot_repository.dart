/// Контракт хранения; реализация сценариев слепков появится на этапе 2.
abstract interface class SnapshotRepository {
  Future<List<String>> listSnapshotIds();
}

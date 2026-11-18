const syncRecreatedMessage =
    'Синхронизация на Диске пересоздана. Подключитесь заново — если парольную фразу меняли, введите новую';

class SyncFailure implements Exception {
  const SyncFailure(this.message);
  final String message;
}

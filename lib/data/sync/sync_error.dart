class SyncFailure implements Exception {
  const SyncFailure(this.message);
  final String message;
}

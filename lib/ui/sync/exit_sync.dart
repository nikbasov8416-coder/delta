import 'dart:async';

/// Выход разрешается всегда: ошибка и тайм-аут не удерживают окно.
Future<void> exchangeBeforeExit({
  required bool unlocked,
  required Future<bool> Function() needed,
  required Future<void> Function() exchange,
  required void Function() showWaiting,
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (!unlocked) return;
  try {
    await (() async {
      if (await needed()) {
        showWaiting();
        await exchange();
      }
    })().timeout(timeout);
  } catch (_) {
    /* pending/outbox остаются до следующего запуска */
  }
}

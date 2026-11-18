import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart';
import '../data/sync/sync_service.dart';
import '../data/sync/yandex_disk_rest.dart';
import '../data/rates/source_gateway.dart';
import '../data/rates/transport.dart';
import '../domain/rates/rates.dart';
import '../data/database/encrypted_connection.dart';
import '../data/finance_repository.dart';
import '../data/security/secret_store.dart';
import '../data/security/device_auth.dart';
import '../domain/security/device_authenticator.dart';
import '../data/security/vault_keys.dart';
import '../domain/finance/finance_repository.dart';
import '../domain/finance/records.dart';
import '../domain/reports/reports.dart';
import '../domain/security/pin_service.dart';

class SessionAccess extends Notifier<bool> {
  @override
  bool build() => false;
  void setUnlocked(bool value) => state = value;
}

final sessionAccessProvider = NotifierProvider<SessionAccess, bool>(
  SessionAccess.new,
);

final deviceAuthProvider = Provider<DeviceAuthenticator>((ref) => DeviceAuth());

final secretStoreProvider = Provider<SecretStore>(
  (ref) => PlatformSecretStore(),
);
final pinServiceProvider = Provider<PinService>((ref) {
  final store = ref.watch(secretStoreProvider);
  return PinService(read: store.read, write: store.write);
});

// Этот провайдер читают только экраны внутри открытой сессии.
final rateGatewayProvider = Provider.autoDispose<RateGateway>((ref) {
  final transport = SourceHttpTransport();
  ref.onDispose(transport.close);
  return PublicRateGateway(transport);
});

final repositoryProvider = FutureProvider<FinanceRepository>((ref) async {
  // Проверка нужна и при прямом чтении провайдера, и во время снятия экранов
  // после блокировки: старые подписки не должны заново открыть базу.
  if (!ref.watch(sessionAccessProvider)) throw StateError('Сессия закрыта');
  final store = ref.watch(secretStoreProvider);
  final keys = VaultKeys(store);
  final gateway = ref.watch(rateGatewayProvider);
  AppDatabase? database;
  DriftFinanceRepository? openedRepository;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    if (openedRepository != null) {
      openedRepository.close();
    } else {
      database?.close();
    }
  });
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final deviceId = await keys.deviceId();
  final file = File('${directory.path}/delta.db');
  final key = await keys.databaseKey(file);
  try {
    if (disposed) throw StateError('Сессия закрыта');
    database = AppDatabase(encryptedConnection(file, key));
  } finally {
    key.fillRange(0, key.length, 0);
  }
  final repository = DriftFinanceRepository(
    database,
    deviceId,
    gateway: gateway,
  );
  openedRepository = repository;
  try {
    await repository.initialize();
    if (disposed) throw StateError('Сессия закрыта');
    return repository;
  } catch (_) {
    await repository.close();
    rethrow;
  }
});

final overviewProvider = FutureProvider<FinanceOverview>(
  (ref) async => (await ref.watch(repositoryProvider.future)).overview(),
);
final snapshotProvider = FutureProvider.family<SnapshotDetail, String>(
  (ref, id) async => (await ref.watch(repositoryProvider.future)).snapshot(id),
);

void refreshFinance(WidgetRef ref, [String? id]) {
  ref.invalidate(overviewProvider);
  ref.invalidate(reportSnapshotsProvider);
  if (id == null) {
    ref.invalidate(snapshotProvider);
  } else {
    ref.invalidate(snapshotProvider(id));
  }
}

final syncServiceProvider = FutureProvider.autoDispose<SyncService?>((
  ref,
) async {
  final repository = await ref.watch(repositoryProvider.future);
  if (repository is! DriftFinanceRepository) return null;
  final service = SyncService(
    repository,
    ref.read(secretStoreProvider),
    diskFactory: (token) => YandexDiskRest(token),
  );
  var disposed = false;
  DateTime? previous;
  void updated() {
    if (disposed) return;
    if (service.lastSync != previous) {
      previous = service.lastSync;
      ref.invalidate(overviewProvider);
      ref.invalidate(snapshotProvider);
      ref.invalidate(reportSnapshotsProvider);
    }
  }

  ref.onDispose(() {
    disposed = true;
    repository.onChanged = null;
    repository.onFinalized = null;
    service.removeListener(updated);
    service.release();
  });
  service.addListener(updated);
  repository.onChanged = service.changed;
  repository.onFinalized = service.schedule;
  repository.beforeClose = service.release;
  await service.load();
  if (!disposed) service.schedule();
  return service;
});

final reportSnapshotsProvider = FutureProvider<ReportData>(
  (ref) async => (await ref.watch(repositoryProvider.future)).reportSnapshots(),
);

import 'package:drift/native.dart';
import 'package:delta/domain/rates/rates.dart';
import 'package:delta/data/database/app_database.dart';
import 'package:delta/data/database/decimal_sql.dart';
import 'package:delta/data/finance_repository.dart';
import 'package:delta/data/security/secret_store.dart';

AppDatabase memoryDatabase() =>
    AppDatabase(NativeDatabase.memory(setup: installDecimalFunctions));
Future<DriftFinanceRepository> testRepository({
  RateGateway? gateway,
  DateTime Function()? now,
}) async {
  final repository = DriftFinanceRepository(
    memoryDatabase(),
    '00000000-0000-4000-8000-000000000001',
    gateway: gateway,
    now: now,
  );
  await repository.initialize();
  return repository;
}

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

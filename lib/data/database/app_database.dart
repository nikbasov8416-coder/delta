import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Предметная схема, версия 1 была пустым каркасом этапа 1.
@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        await m.createAll();
      } else {
        throw StateError('Не поддерживается версия базы');
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final broken = await customSelect('PRAGMA foreign_key_check').get();
      if (broken.isNotEmpty) throw StateError('Нарушена целостность базы');
    },
  );
}

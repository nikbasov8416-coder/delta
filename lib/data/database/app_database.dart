import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Каркас drift. Таблицы и миграции предметной модели — этап 2.
/// Исполнитель передаётся явно: приложение не открывает незашифрованную базу.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

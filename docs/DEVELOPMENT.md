# Разработка и проверки

Зафиксированы Flutter stable **3.50.0**, Dart **3.14.0** и `pubspec.lock`.
SDK на сервере: `/home/claude/Claude/tools/flutter`; системной установки нет.
Android SDK здесь не нужен: сервер выполняет анализ и тесты Linux.
Восстановление SDK и SHA256 — в основном проекте `ops/MIGRATION.md`.

Под пользователем claude из корня личного проекта:

```bash
finance-app/tool/flutterw pub get --enforce-lockfile
finance-app/tool/flutterw pub run build_runner build
finance-app/tool/flutterw analyze --no-pub --fatal-infos
finance-app/tool/flutterw test --no-pub --reporter expanded
python/bin/python finance-app/tool/dependency_inventory.py
```

`tool/flutterw` перенаправляет кэши/временные файлы внутрь проекта и подавляет
телеметрию CLI. Системные HOME и PATH не меняет. Использовать обёртку только
в основном проекте; в самостоятельном зеркале с установленным Flutter
выполнять обычные `flutter …` / `dart …` из корня приложения.

SQLCipher подключён build hook пакета sqlite3. При первом тесте/сборке он
скачивает нативную библиотеку нужной платформы с проверкой SHA256.
Тест неправильного ключа намеренно вызывает диагностические сообщения
SQLCipher о невозможности расшифровать страницу; это ожидаемый отказ.
В лог не выводятся ни ключ, ни содержимое базы. Тест создаёт только искусственный
файл в системной temp-папке runner; обёртка сервера задаёт TMPDIR внутри проекта.
Файл удаляется при завершении теста.

После изменения схемы перегенерировать `app_database.g.dart` и фиксировать
его вместе с исходниками: CI проверяет, что повторная генерация не меняет файл.
Не редактировать generated-код вручную. Форматирование:

```bash
dart format lib test
```

Все тесты используют только выдуманные значения. Пакеты для следующих этапов
добавлять отдельно с обновлением lockfile и `DEPENDENCIES.md`.
Реальные базы, экспорты, ключи, `.env`, `key.properties`, keystore и сборки
исключены `.gitignore`. На этом этапе приложение данных не хранит.

Проверки CI:

- Linux: lockfile, drift generation, форматирование, analyze, все тесты.
- Android после проверок: `flutter build apk --debug`, minSdk 26.
- Windows x64 после проверок: тесты, `flutter build windows --release`,
  упаковка всего каталога Release в ZIP.

На сервере нельзя подтвердить Windows/Android-сборки без соответствующих
toolchain. Их первая фактическая проверка — Actions после публикации владельцем.

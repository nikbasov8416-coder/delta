#!/usr/bin/env python3
"""Список версий и лицензий из локально разрешённых зависимостей, без сети.

Запуск после flutter pub get: python3 tool/dependency_inventory.py
Не публикует код, не читает домашние каталоги или файлы входа.
"""
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent


def license_id(text):
    if 'Apache License' in text and 'Version 2.0' in text:
        return 'Apache-2.0'
    if 'Permission is hereby granted, free of charge' in text:
        return 'MIT'
    if 'Redistribution and use in source and binary forms' in text:
        if 'Neither the name' in text or 'Neither the names' in text:
            return 'BSD-3-Clause'
        return 'BSD-2-Clause'
    raise ValueError('Лицензия требует ручной проверки')


def main():
    config = ROOT / '.dart_tool/package_config.json'
    packages = json.loads(config.read_text())['packages']
    lock = (ROOT / 'pubspec.lock').read_text()
    resolved = {}
    for name, block in re.findall(
        r'^  ([a-zA-Z0-9_]+):\n(.*?)(?=^  [a-zA-Z0-9_]+:|^sdks:|\Z)',
        lock, re.M | re.S,
    ):
        version = re.search(r'^    version: "?([^"\n]+)', block, re.M).group(1)
        kind = re.search(r'^    dependency: "?([^"\n]+)', block, re.M).group(1)
        resolved[name] = (version, kind)
    paths = {}
    for package in packages:
        uri = package['rootUri']
        paths[package['name']] = (
            Path(unquote(urlparse(uri).path)) if uri.startswith('file:')
            else (config.parent / uri).resolve()
        )
    sdk = paths['flutter'].parent.parent
    rows = []
    for name, (version, kind) in sorted(resolved.items()):
        directory = paths[name]
        candidates = [directory / f for f in ('LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING')]
        if name in ('flutter_localizations', 'flutter_test', 'flutter_web_plugins'):
            candidates.append(sdk / 'LICENSE')
        license_file = next((f for f in candidates if f.is_file()), None)
        if license_file is None:
            raise ValueError(f'Нет лицензии: {name}')
        text = license_file.read_text()
        identity = ('Составная: лицензии Flutter Engine' if name == 'sky_engine'
                    else license_id(text))
        if version == '0.0.0':
            version = 'SDK Flutter 3.50.0'
            source = ('https://github.com/flutter/engine/blob/main/sky/packages/sky_engine/LICENSE'
                      if name == 'sky_engine' else
                      'https://github.com/flutter/flutter/blob/ab2912035e160d9cad6306df307576da6128ebdb/LICENSE')
        else:
            source = f'https://pub.dev/packages/{name}/versions/{version}/license'
        group = {'direct main': 'основная', 'direct dev': 'разработка',
                 'transitive': 'транзитивная'}[kind]
        digest = hashlib.sha256(license_file.read_bytes()).hexdigest()
        rows.append(f'| {name} | {version} | {group} | [{identity}]({source}) | `{digest}` |')

    header = '''# Зависимости Delta — этап 2

Состояние: 2026-11-16. Список подготовлен Codex для ревью Claude;
окончательное принятие — владельцем. Версии взяты из `pubspec.lock`, лицензии —
из файлов LICENSE установленных пакетов. Все хеши ниже относятся к текстам
лицензий, не к бинарным файлам. Lockfile фиксирует также хеши архивов pub.dev.

## Инструменты и нативные библиотеки

| Компонент | Версия | Лицензия / источник |
|---|---|---|
| Flutter stable | 3.50.0, ab2912035e160d9cad6306df307576da6128ebdb | BSD-3-Clause; LICENSE в SDK |
| Dart | 3.14.0 из Flutter SDK | BSD-3-Clause и уведомления компонентов SDK |
| SQLCipher Community | 4.20.0, сборка sqlite3 3.9.1 | BSD-3-Clause; [SQLCipher LICENSE](https://github.com/sqlcipher/sqlcipher/blob/v4.20.0/LICENSE) |
| OpenSSL в SQLCipher (Android/Windows/Linux) | 4.0.3, по CHANGELOG sqlite3 | Apache-2.0; [OpenSSL LICENSE](https://github.com/openssl/openssl/blob/openssl-4.0.3/LICENSE.txt) |
| SQLite в основе SQLCipher | 3.54.1 (проверена библиотека Linux) | Public Domain; [SQLite copyright](https://sqlite.org/copyright.html) |

SQLCipher подключён через build hook `sqlite3` (`source: sqlcipher`), без устаревших
`sqlcipher_flutter_libs`/`sqlite3_flutter_libs`. Платформенные библиотеки проверяются
по SHA256 из `sqlite3/lib/src/hook/asset_hashes.dart`. Нативные версии выше взяты из
CHANGELOG sqlite3; на сервере дополнительно проверены SQLCipher 4.20.0 community
и SQLite 3.54.1. Результат `PRAGMA cipher_version` проверяется тестом Linux
и Windows CI. Перед распространением релизов на этапе 6 следует включить полные
уведомления SQLCipher/OpenSSL в поставку и проверить SBOM нативных артефактов.
Flutter сам включает уведомления своих библиотек в сборку.

material_ui 1.1.0 соответствует шаблону Flutter 3.50.0. Старый импорт
`package:flutter/material.dart` в этом SDK помечен deprecated; используется
официальный отдельный пакет Material. Это не сторонняя тема интерфейса.

На этапе 2 добавлены flutter_secure_storage, local_auth, cryptography (PBKDF2),
path_provider и uuid. fl_chart, Argon2id и HTTP/WebDAV-клиент добавляются
на профильных этапах с отдельной проверкой лицензий. Список ниже содержит и служебные зависимости
тестов/генератора: не все они попадают в APK/EXE.

## Все разрешённые пакеты

Перегенерация после `flutter pub get`: `python3 tool/dependency_inventory.py`.
Составная лицензия sky_engine содержит много отдельных уведомлений;
сводить её к одной MIT/BSD нельзя. SHA256 позволяет сверить точный локальный файл.

| Пакет | Версия | Назначение | Лицензия | SHA256 LICENSE |
|---|---|---|---|---|
'''
    (ROOT / 'DEPENDENCIES.md').write_text(header + '\n'.join(rows) + '\n')
    print(f'DEPENDENCIES.md: {len(rows)} пакетов')


if __name__ == '__main__':
    main()

# Зависимости Delta — этап 3

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
path_provider и uuid. Этап 3 добавляет xml/petitparser; HTTP — стандартный dart:io.
fl_chart, Argon2id и WebDAV-клиент добавляются
на профильных этапах с отдельной проверкой лицензий. Список ниже содержит и служебные зависимости
тестов/генератора: не все они попадают в APK/EXE.

## Все разрешённые пакеты

Перегенерация после `flutter pub get`: `python3 tool/dependency_inventory.py`.
Составная лицензия sky_engine содержит много отдельных уведомлений;
сводить её к одной MIT/BSD нельзя. SHA256 позволяет сверить точный локальный файл.

| Пакет | Версия | Назначение | Лицензия | SHA256 LICENSE |
|---|---|---|---|---|
| _fe_analyzer_shared | 111.0.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/_fe_analyzer_shared/versions/111.0.0/license) | `efa31b5ac790016736fa9761642b0af16d37cd4fb483de2905adb5258cb89722` |
| analyzer | 14.7.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/analyzer/versions/14.7.0/license) | `7e124af6a556f045cb3a20cafbdaa31602ac2c82cbcb3c3b15faaaf514b06028` |
| args | 2.7.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/args/versions/2.7.0/license) | `dfb09c74e29386cd3e2719f32d4995d59526179753931d31840757c77fbf2791` |
| async | 2.13.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/async/versions/2.13.1/license) | `ff15faa32a2e638107b7789592b14426162a75ba620044ee2340a20ec6ce5e73` |
| boolean_selector | 2.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/boolean_selector/versions/2.1.2/license) | `b71519245009a3b8f126196a5408ec031e216e8e0d985085958c6543f82a8a2a` |
| build | 5.0.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/build/versions/5.0.0/license) | `a4b5d7d31626e90b77e8696f1c47643aa31f52e17c1907c1ab60b068110e6e10` |
| build_config | 1.4.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/build_config/versions/1.4.0/license) | `ea97a7558a7bd7cee4e2355f7529e3cbebb0dcbb546ddb9a90f10c9eb6b08da5` |
| build_daemon | 4.1.7 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/build_daemon/versions/4.1.7/license) | `0371d1da6a57fb791db29d29b95333429205f51f3cb2eb3a0c12d91838a38744` |
| build_runner | 2.17.1 | разработка | [BSD-3-Clause](https://pub.dev/packages/build_runner/versions/2.17.1/license) | `a4b5d7d31626e90b77e8696f1c47643aa31f52e17c1907c1ab60b068110e6e10` |
| built_collection | 5.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/built_collection/versions/5.1.2/license) | `4f1b0f444c862e8dc586122c00592538fb0e9dd6d81a5214882b25b8054f7dfa` |
| built_value | 8.13.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/built_value/versions/8.13.0/license) | `4f1b0f444c862e8dc586122c00592538fb0e9dd6d81a5214882b25b8054f7dfa` |
| characters | 1.4.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/characters/versions/1.4.1/license) | `0371d1da6a57fb791db29d29b95333429205f51f3cb2eb3a0c12d91838a38744` |
| charcode | 1.4.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/charcode/versions/1.4.0/license) | `8a4dbe6d3ddcf937b18d1768d13f9ba718b45bcb43bc00a3b63eb160d264acf7` |
| checked_yaml | 2.0.4 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/checked_yaml/versions/2.0.4/license) | `4771d808721f4d5f02318ab857c92f5a5dce87b14ae1c3770fe21ca7fd4a9280` |
| cli_util | 0.6.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/cli_util/versions/0.6.0/license) | `ff15faa32a2e638107b7789592b14426162a75ba620044ee2340a20ec6ce5e73` |
| clock | 1.1.3 | транзитивная | [Apache-2.0](https://pub.dev/packages/clock/versions/1.1.3/license) | `58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd` |
| code_assets | 2.2.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/code_assets/versions/2.2.0/license) | `21ae23b0b9ff67a2dc75ab085d1e8db8ac548c5faf370af17f28dd2ef3b52b7b` |
| collection | 1.19.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/collection/versions/1.19.1/license) | `ff15faa32a2e638107b7789592b14426162a75ba620044ee2340a20ec6ce5e73` |
| convert | 3.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/convert/versions/3.1.2/license) | `ad6a71997da90924b2cfb1fb47ec46537f70faf469efe016168794ae45ed6888` |
| crypto | 3.0.8 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/crypto/versions/3.0.8/license) | `ad6a71997da90924b2cfb1fb47ec46537f70faf469efe016168794ae45ed6888` |
| cryptography | 2.9.0 | основная | [Apache-2.0](https://pub.dev/packages/cryptography/versions/2.9.0/license) | `59899c6091b540582ed617e8eeaac4919dc985ccfc35459ee9752b699be5205b` |
| cupertino_ui | 1.1.6 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/cupertino_ui/versions/1.1.6/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| dart_style | 3.1.14 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/dart_style/versions/3.1.14/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| decimal | 3.2.6 | основная | [Apache-2.0](https://pub.dev/packages/decimal/versions/3.2.6/license) | `58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd` |
| drift | 2.35.4 | основная | [MIT](https://pub.dev/packages/drift/versions/2.35.4/license) | `31f84e4edff98f0238a5bef1c2ce754e401fbab149782f0ff4dc9b68fd086f75` |
| drift_dev | 2.35.3 | разработка | [MIT](https://pub.dev/packages/drift_dev/versions/2.35.3/license) | `31f84e4edff98f0238a5bef1c2ce754e401fbab149782f0ff4dc9b68fd086f75` |
| equatable | 3.0.0 | транзитивная | [MIT](https://pub.dev/packages/equatable/versions/3.0.0/license) | `07720a43bdabe44206067a2bffd1089dcdc4cc5b0b7f8169308c2f8ba6ad0c86` |
| fake_async | 1.3.3 | транзитивная | [Apache-2.0](https://pub.dev/packages/fake_async/versions/1.3.3/license) | `58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd` |
| ffi | 2.2.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/ffi/versions/2.2.0/license) | `0371d1da6a57fb791db29d29b95333429205f51f3cb2eb3a0c12d91838a38744` |
| ffi_leak_tracker | 0.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/ffi_leak_tracker/versions/0.1.2/license) | `332f290333e64ed007b4f59aeeebd8fd3ceaadfbfa226a6cf2a3ab1583281624` |
| file | 7.0.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/file/versions/7.0.1/license) | `f6df86b1412172537273e8e80ee2fb8a66aa7307ce0b39ea5ddab47ca41b8c49` |
| fixnum | 1.1.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/fixnum/versions/1.1.1/license) | `ff0b91d4f3c32b25cb6ec84985e8da89b0ba2a2b2f7eef353cda5e5423a20390` |
| fl_chart | 1.3.1 | основная | [MIT](https://pub.dev/packages/fl_chart/versions/1.3.1/license) | `7e49df776ee082bb160c96290e28d7834fd4b5df5d20212d5b3e411bcfe31d96` |
| flutter | SDK Flutter 3.50.0 | основная | [BSD-3-Clause](https://github.com/flutter/flutter/blob/ab2912035e160d9cad6306df307576da6128ebdb/LICENSE) | `a598db94b6290ffbe10b5ecf911057b6a943351c727fdda9e5f2891d68700a20` |
| flutter_lints | 6.0.0 | разработка | [BSD-3-Clause](https://pub.dev/packages/flutter_lints/versions/6.0.0/license) | `89519eca6f7b9529b35bdddd623a58c3af06a88c458dbd6531ddb4675acf75a9` |
| flutter_localizations | SDK Flutter 3.50.0 | основная | [BSD-3-Clause](https://github.com/flutter/flutter/blob/ab2912035e160d9cad6306df307576da6128ebdb/LICENSE) | `a598db94b6290ffbe10b5ecf911057b6a943351c727fdda9e5f2891d68700a20` |
| flutter_plugin_android_lifecycle | 2.0.35 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/flutter_plugin_android_lifecycle/versions/2.0.35/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| flutter_riverpod | 3.5.0 | основная | [MIT](https://pub.dev/packages/flutter_riverpod/versions/3.5.0/license) | `757d9c09a9a2a701144328c0fd596234ea287ff62952b39cd22f9ad4caed1171` |
| flutter_secure_storage | 11.2.0 | основная | [BSD-3-Clause](https://pub.dev/packages/flutter_secure_storage/versions/11.2.0/license) | `55dafb084270616f95b9bea53654adda8bdcad95c022a83c4cf8769073f829fa` |
| flutter_secure_storage_darwin | 0.4.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/flutter_secure_storage_darwin/versions/0.4.3/license) | `3754c516086c62307896512b68024837bee5d2bea42a55cfd03f7448b92b06c8` |
| flutter_secure_storage_linux | 3.0.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/flutter_secure_storage_linux/versions/3.0.3/license) | `55dafb084270616f95b9bea53654adda8bdcad95c022a83c4cf8769073f829fa` |
| flutter_secure_storage_platform_interface | 2.1.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/flutter_secure_storage_platform_interface/versions/2.1.1/license) | `55dafb084270616f95b9bea53654adda8bdcad95c022a83c4cf8769073f829fa` |
| flutter_secure_storage_web | 2.1.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/flutter_secure_storage_web/versions/2.1.1/license) | `55dafb084270616f95b9bea53654adda8bdcad95c022a83c4cf8769073f829fa` |
| flutter_secure_storage_windows | 4.2.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/flutter_secure_storage_windows/versions/4.2.2/license) | `55dafb084270616f95b9bea53654adda8bdcad95c022a83c4cf8769073f829fa` |
| flutter_test | SDK Flutter 3.50.0 | разработка | [BSD-3-Clause](https://github.com/flutter/flutter/blob/ab2912035e160d9cad6306df307576da6128ebdb/LICENSE) | `a598db94b6290ffbe10b5ecf911057b6a943351c727fdda9e5f2891d68700a20` |
| flutter_web_plugins | SDK Flutter 3.50.0 | транзитивная | [BSD-3-Clause](https://github.com/flutter/flutter/blob/ab2912035e160d9cad6306df307576da6128ebdb/LICENSE) | `a598db94b6290ffbe10b5ecf911057b6a943351c727fdda9e5f2891d68700a20` |
| glob | 2.2.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/glob/versions/2.2.0/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| go_router | 18.1.4 | основная | [BSD-3-Clause](https://pub.dev/packages/go_router/versions/18.1.4/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| graphs | 2.3.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/graphs/versions/2.3.2/license) | `ea97a7558a7bd7cee4e2355f7529e3cbebb0dcbb546ddb9a90f10c9eb6b08da5` |
| hooks | 2.2.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/hooks/versions/2.2.0/license) | `21ae23b0b9ff67a2dc75ab085d1e8db8ac548c5faf370af17f28dd2ef3b52b7b` |
| http_multi_server | 3.2.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/http_multi_server/versions/3.2.3/license) | `ff0b91d4f3c32b25cb6ec84985e8da89b0ba2a2b2f7eef353cda5e5423a20390` |
| http_parser | 4.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/http_parser/versions/4.1.2/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| intl | 0.20.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/intl/versions/0.20.3/license) | `7e124af6a556f045cb3a20cafbdaa31602ac2c82cbcb3c3b15faaaf514b06028` |
| io | 1.1.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/io/versions/1.1.0/license) | `ea97a7558a7bd7cee4e2355f7529e3cbebb0dcbb546ddb9a90f10c9eb6b08da5` |
| jni | 1.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/jni/versions/1.1.2/license) | `08a004aa8956c3cf3b24f7f69c966247233953e18e6afaa61191ea47b7eb70f6` |
| jni_flutter | 1.0.4+1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/jni_flutter/versions/1.0.4+1/license) | `b1fcb475d67817411f335ac92872507011e574c4cb29cfdaaf7707b75641932c` |
| jni_util | 1.0.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/jni_util/versions/1.0.0/license) | `b1fcb475d67817411f335ac92872507011e574c4cb29cfdaaf7707b75641932c` |
| json_annotation | 4.12.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/json_annotation/versions/4.12.0/license) | `143839f62c9b7f88143ea9f688361c27050888acde7696b34e04414bd254fafc` |
| leak_tracker | 11.0.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/leak_tracker/versions/11.0.2/license) | `08a004aa8956c3cf3b24f7f69c966247233953e18e6afaa61191ea47b7eb70f6` |
| leak_tracker_flutter_testing | 3.0.10 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/leak_tracker_flutter_testing/versions/3.0.10/license) | `08a004aa8956c3cf3b24f7f69c966247233953e18e6afaa61191ea47b7eb70f6` |
| leak_tracker_testing | 3.0.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/leak_tracker_testing/versions/3.0.2/license) | `08a004aa8956c3cf3b24f7f69c966247233953e18e6afaa61191ea47b7eb70f6` |
| lints | 6.1.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/lints/versions/6.1.0/license) | `421fe78c3b5df297f8b4ab2c74f2450a274ee6d245a113091f6b9f90570af193` |
| listen | 1.0.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/listen/versions/1.0.1/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| local_auth | 3.0.2 | основная | [BSD-3-Clause](https://pub.dev/packages/local_auth/versions/3.0.2/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| local_auth_android | 2.3.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/local_auth_android/versions/2.3.0/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| local_auth_darwin | 2.0.5 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/local_auth_darwin/versions/2.0.5/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| local_auth_platform_interface | 1.1.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/local_auth_platform_interface/versions/1.1.0/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| local_auth_windows | 2.0.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/local_auth_windows/versions/2.0.2/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| logging | 1.3.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/logging/versions/1.3.0/license) | `dfb09c74e29386cd3e2719f32d4995d59526179753931d31840757c77fbf2791` |
| matcher | 0.12.20 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/matcher/versions/0.12.20/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| material_color_utilities | 0.13.0 | транзитивная | [Apache-2.0](https://pub.dev/packages/material_color_utilities/versions/0.13.0/license) | `d103f246ef4c18dab8af0c1dcf6a8af884e5cff554da7261a48ac43c17d98f2e` |
| material_ui | 1.1.0 | основная | [BSD-3-Clause](https://pub.dev/packages/material_ui/versions/1.1.0/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| meta | 1.19.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/meta/versions/1.19.0/license) | `b71519245009a3b8f126196a5408ec031e216e8e0d985085958c6543f82a8a2a` |
| mime | 2.1.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/mime/versions/2.1.0/license) | `ff15faa32a2e638107b7789592b14426162a75ba620044ee2340a20ec6ce5e73` |
| native_toolchain_c | 0.19.6 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/native_toolchain_c/versions/0.19.6/license) | `aa81abb1ac43e40d2f5a606385edd37e974a5858d4109f7f439dd43d964487a7` |
| objective_c | 9.6.4 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/objective_c/versions/9.6.4/license) | `1cda25a8de6880c5338de0b4a06ee89e8537c213eb1379c16a4c035bfd198b5c` |
| package_config | 3.0.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/package_config/versions/3.0.0/license) | `0371d1da6a57fb791db29d29b95333429205f51f3cb2eb3a0c12d91838a38744` |
| path | 1.9.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/path/versions/1.9.1/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| path_provider | 2.1.6 | основная | [BSD-3-Clause](https://pub.dev/packages/path_provider/versions/2.1.6/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| path_provider_android | 2.3.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/path_provider_android/versions/2.3.1/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| path_provider_foundation | 2.6.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/path_provider_foundation/versions/2.6.0/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| path_provider_linux | 2.2.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/path_provider_linux/versions/2.2.2/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| path_provider_platform_interface | 2.1.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/path_provider_platform_interface/versions/2.1.3/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| path_provider_windows | 2.3.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/path_provider_windows/versions/2.3.0/license) | `89519eca6f7b9529b35bdddd623a58c3af06a88c458dbd6531ddb4675acf75a9` |
| petitparser | 7.1.0 | транзитивная | [MIT](https://pub.dev/packages/petitparser/versions/7.1.0/license) | `0be767174b97278f17da4923a74169e8645631f03ea3d8482ec3523c9b1a0dd3` |
| platform | 3.2.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/platform/versions/3.2.0/license) | `143839f62c9b7f88143ea9f688361c27050888acde7696b34e04414bd254fafc` |
| plugin_platform_interface | 2.1.8 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/plugin_platform_interface/versions/2.1.8/license) | `89519eca6f7b9529b35bdddd623a58c3af06a88c458dbd6531ddb4675acf75a9` |
| pool | 1.5.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/pool/versions/1.5.3/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| process | 5.0.6 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/process/versions/5.0.6/license) | `5f018bbc25a55406d7a4e1d3229135439e315210b0050ca56dbb367a4934e85d` |
| pub_semver | 2.2.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/pub_semver/versions/2.2.1/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| pubspec_parse | 1.7.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/pubspec_parse/versions/1.7.0/license) | `479bb84361ed3d6b78f55871c9ae5d6c8f15f49c2089e59fc1d6644d8b0ed32b` |
| rational | 2.2.3 | транзитивная | [Apache-2.0](https://pub.dev/packages/rational/versions/2.2.3/license) | `58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd` |
| recase | 4.1.0 | транзитивная | [BSD-2-Clause](https://pub.dev/packages/recase/versions/4.1.0/license) | `389acee6b73f27ef83bdd997f32acc7dc12970c68fbc505284b7bf39d6d80bde` |
| record_use | 1.1.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/record_use/versions/1.1.1/license) | `1cda25a8de6880c5338de0b4a06ee89e8537c213eb1379c16a4c035bfd198b5c` |
| riverpod | 3.5.0 | транзитивная | [MIT](https://pub.dev/packages/riverpod/versions/3.5.0/license) | `757d9c09a9a2a701144328c0fd596234ea287ff62952b39cd22f9ad4caed1171` |
| shelf | 1.4.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/shelf/versions/1.4.3/license) | `ff0b91d4f3c32b25cb6ec84985e8da89b0ba2a2b2f7eef353cda5e5423a20390` |
| shelf_web_socket | 3.0.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/shelf_web_socket/versions/3.0.0/license) | `ff0b91d4f3c32b25cb6ec84985e8da89b0ba2a2b2f7eef353cda5e5423a20390` |
| sky_engine | SDK Flutter 3.50.0 | транзитивная | [Составная: лицензии Flutter Engine](https://github.com/flutter/engine/blob/main/sky/packages/sky_engine/LICENSE) | `0d5050142d6b4605704d8844fcd5656ac23e718cf8f7d1e41149950da5edb4ef` |
| source_gen | 4.3.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/source_gen/versions/4.3.1/license) | `ad6a71997da90924b2cfb1fb47ec46537f70faf469efe016168794ae45ed6888` |
| source_span | 1.10.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/source_span/versions/1.10.2/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| sqlite3 | 3.9.1 | основная | [MIT](https://pub.dev/packages/sqlite3/versions/3.9.1/license) | `67e5d73a3a0c6e41f33d688a672b1161bf7f16e04da9ae48a7a14f1ba7436a4d` |
| sqlparser | 0.45.1 | транзитивная | [MIT](https://pub.dev/packages/sqlparser/versions/0.45.1/license) | `bec8c7a58f3e043a40123d332260048aeff40ebdcaf33bf8d497a3fea84b8f84` |
| stack_trace | 1.12.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/stack_trace/versions/1.12.2/license) | `ff0b91d4f3c32b25cb6ec84985e8da89b0ba2a2b2f7eef353cda5e5423a20390` |
| state_notifier | 1.0.0 | транзитивная | [MIT](https://pub.dev/packages/state_notifier/versions/1.0.0/license) | `757d9c09a9a2a701144328c0fd596234ea287ff62952b39cd22f9ad4caed1171` |
| stream_channel | 2.1.4 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/stream_channel/versions/2.1.4/license) | `ff15faa32a2e638107b7789592b14426162a75ba620044ee2340a20ec6ce5e73` |
| stream_transform | 2.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/stream_transform/versions/2.1.2/license) | `ea97a7558a7bd7cee4e2355f7529e3cbebb0dcbb546ddb9a90f10c9eb6b08da5` |
| string_scanner | 1.4.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/string_scanner/versions/1.4.1/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| term_glyph | 1.2.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/term_glyph/versions/1.2.2/license) | `ea97a7558a7bd7cee4e2355f7529e3cbebb0dcbb546ddb9a90f10c9eb6b08da5` |
| test_api | 0.7.14 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/test_api/versions/0.7.14/license) | `ff1b9f0df9036c04be424b1e3ce12789bea880ad5ffc3a48e069ae2d40a087a4` |
| typed_data | 1.4.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/typed_data/versions/1.4.0/license) | `ff15faa32a2e638107b7789592b14426162a75ba620044ee2340a20ec6ce5e73` |
| uuid | 4.6.0 | основная | [MIT](https://pub.dev/packages/uuid/versions/4.6.0/license) | `ad3e5523e51004e94ba9ce728805b1b4242dbccdb65e62b523800e35a8a7cfdc` |
| vector_math | 2.4.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/vector_math/versions/2.4.3/license) | `420f7739f169097f0aad1242045169cd643c8f1d94e62866fad265ae4c369b7d` |
| vm_service | 15.4.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/vm_service/versions/15.4.0/license) | `ad6a71997da90924b2cfb1fb47ec46537f70faf469efe016168794ae45ed6888` |
| watcher | 1.2.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/watcher/versions/1.2.1/license) | `3c32b53167c7dae9190c38dab5dd9fe1789c53623ebc7d1babcb29914c5b3f16` |
| web | 1.1.2 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/web/versions/1.1.2/license) | `aa913ff50d7542eb8cc35b9f48a80928ac6819ba9057f85d424655e3e8dc271c` |
| web_socket | 1.0.1 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/web_socket/versions/1.0.1/license) | `cbe822ef3446af4366b2b82c48b0979d0b12865edfe74c22b9aa617fc362d6e0` |
| web_socket_channel | 3.0.3 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/web_socket_channel/versions/3.0.3/license) | `a4b5d7d31626e90b77e8696f1c47643aa31f52e17c1907c1ab60b068110e6e10` |
| win32 | 6.4.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/win32/versions/6.4.0/license) | `87ef8bccdd619f2345ba5b9026cf1d6cccb305e36ab83849a8a3af9293abde7e` |
| xdg_directories | 1.1.0 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/xdg_directories/versions/1.1.0/license) | `89519eca6f7b9529b35bdddd623a58c3af06a88c458dbd6531ddb4675acf75a9` |
| xml | 7.1.0 | основная | [MIT](https://pub.dev/packages/xml/versions/7.1.0/license) | `0be767174b97278f17da4923a74169e8645631f03ea3d8482ec3523c9b1a0dd3` |
| yaml | 3.1.4 | транзитивная | [MIT](https://pub.dev/packages/yaml/versions/3.1.4/license) | `d47b93335401b052d79a2f5a3710e4cf7b5aed782faedf84d40fbdd6eb934ec7` |
| yaml_edit | 2.2.4 | транзитивная | [BSD-3-Clause](https://pub.dev/packages/yaml_edit/versions/2.2.4/license) | `021c41b9b081664f6ee181aaf4e03602c51591204dabe9ac8c8d736f0965b851` |

## Этап 6

- `archive 3.6.1` — MIT, SHA-256 файла LICENSE
  `32f97d332eae7453ec4079858e6f1d74be85beeb6d3881068b47d02a379cccea`.
  Используется для записи ZIP-контейнера XLSX. Дополнительных транзитивных
  пакетов в lockfile нет.
- Pillow 12.3.0 — HPND, локальный инструмент генерации иконок (см. `docs/ICON.md`).
  Для сборки и запуска Delta Pillow не требуется.

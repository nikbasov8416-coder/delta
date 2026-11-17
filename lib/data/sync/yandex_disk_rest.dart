import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'sync_error.dart';
import 'sync_storage.dart';

typedef _Reply = (int status, Uint8List bytes, String? location);

class _OperationFailed extends SyncFailure {
  const _OperationFailed()
    : super('Яндекс не завершил операцию. Повторите синхронизацию.');
}

/// OAuth передаётся только REST API. Подписанные ссылки имеют собственный доступ.
class YandexDiskRest implements SyncDisk {
  YandexDiskRest(
    String token, {
    HttpClient? client,
    this.pageSize = 100,
    this.requestTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 1),
  }) : _client = client ?? HttpClient(),
       _authorization = 'OAuth ${token.trim()}' {
    if (!RegExp(r'^[A-Za-z0-9._~+/-]+=*$').hasMatch(token.trim())) {
      throw const SyncFailure(
        'Вставьте OAuth-токен Яндекса без ссылки и пробелов.',
      );
    }
    if (pageSize < 1 || pageSize > 1000) throw ArgumentError('Размер страницы');
    _client.connectionTimeout = const Duration(seconds: 10);
  }
  final HttpClient _client;
  final String _authorization;
  final int pageSize;
  final Duration requestTimeout, pollInterval;

  static String resourcePath(String path) {
    if (!path.startsWith(syncRoot) ||
        path.contains(RegExp(r'[%\\?#]')) ||
        path.split('/').any((p) => p == '.' || p == '..') ||
        !RegExp(r'^[/A-Za-z0-9_.-]+$').hasMatch(path)) {
      throw const SyncFailure('Недопустимый путь синхронизации.');
    }
    return 'app:/${path.substring(syncRoot.length).replaceFirst(RegExp(r'/$'), '')}';
  }

  static Uri _api(String endpoint, Map<String, String> query) =>
      Uri.https('cloud-api.yandex.net', '/v1/disk/$endpoint', query);
  static bool _apiUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'cloud-api.yandex.net' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      uri.path.startsWith('/v1/disk/') &&
      !uri.pathSegments.any((s) => s == '.' || s == '..');
  static Uri _transferUri(String text) {
    try {
      final uri = Uri.parse(text);
      if (uri.scheme != 'https' ||
          uri.port != 443 ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          !RegExp(r'^[a-z0-9.-]+$').hasMatch(uri.host) ||
          !(uri.host.endsWith('.yandex.net') ||
              uri.host.endsWith('.yandex.ru'))) {
        throw const FormatException();
      }
      return uri;
    } catch (_) {
      throw const SyncFailure(
        'Яндекс вернул недопустимую ссылку передачи файла.',
      );
    }
  }

  Map<String, dynamic> _json(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const SyncFailure('Некорректный ответ Яндекса.');
    }
  }

  String _href(_Reply reply) {
    final href = reply.$2.isEmpty
        ? reply.$3
        : (_json(reply.$2)['href'] ?? reply.$3);
    if (href is! String) {
      throw const SyncFailure('Яндекс не выдал ссылку операции.');
    }
    return href;
  }

  void _status(int code, Set<int> allowed) {
    if (!allowed.contains(code)) {
      throw SyncFailure(
        'Ошибка Яндекса (HTTP $code). Повторите синхронизацию.',
      );
    }
  }

  Duration _remaining(Stopwatch watch) {
    final remaining = requestTimeout - watch.elapsed;
    if (remaining <= Duration.zero) {
      throw const SyncFailure('Тайм-аут синхронизации. Повторите позже.');
    }
    return remaining;
  }

  Future<_Reply> _request(
    String method,
    Uri uri, {
    bool oauth = true,
    Uint8List? body,
    Duration? timeout,
  }) async {
    if (oauth) {
      if (!_apiUri(uri)) {
        throw const SyncFailure('Недопустимый адрес API Яндекса.');
      }
    } else {
      _transferUri(uri.toString());
    }
    HttpClientRequest? request;
    try {
      return await (() async {
        request = await _client.openUrl(method, uri);
        request!.followRedirects = false;
        if (oauth) {
          request!.headers.set(HttpHeaders.authorizationHeader, _authorization);
        }
        if (body != null) {
          request!.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/octet-stream',
          );
          request!.contentLength = body.length;
          request!.add(body);
        }
        final response = await request!.close();
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (bytes.length + chunk.length > syncMaximumBytes) {
            request!.abort();
            throw const SyncFailure('Файл синхронизации слишком большой.');
          }
          bytes.add(chunk);
        }
        switch (response.statusCode) {
          case 401:
            throw const SyncFailure(
              'Вход в Яндекс истёк или отозван. Войдите заново',
            );
          case 402:
            throw const SyncFailure(
              'Яндекс ограничил операцию по условиям тарифа (HTTP 402). Проверьте доступ к Диску.',
            );
          case 403:
            throw const SyncFailure(
              'Нет доступа к папке приложения. Войдите заново и разрешите доступ к папке Delta.',
            );
          case 507:
            throw const SyncFailure(
              'На Яндекс Диске недостаточно свободного места.',
            );
        }
        if (oauth && response.statusCode >= 300 && response.statusCode < 400) {
          throw const SyncFailure(
            'API Яндекса предложил запрещённое перенаправление.',
          );
        }
        return (
          response.statusCode,
          bytes.takeBytes(),
          response.headers.value(HttpHeaders.locationHeader),
        );
      })().timeout(
        timeout ?? requestTimeout,
        onTimeout: () {
          request?.abort();
          throw const SyncFailure('Тайм-аут синхронизации. Повторите позже.');
        },
      );
    } on SyncFailure {
      rethrow;
    } on HandshakeException {
      throw const SyncFailure('Не удалось проверить сертификат Яндекса.');
    } on TimeoutException {
      throw const SyncFailure('Тайм-аут синхронизации. Повторите позже.');
    } on SocketException {
      throw const SyncFailure('Нет сети. Изменения сохранены на устройстве.');
    } on HttpException {
      throw const SyncFailure('Сетевое соединение прервано. Повторите позже.');
    } catch (_) {
      throw const SyncFailure('Не удалось обработать ответ Яндекса.');
    }
  }

  Future<_Reply> _transfer(
    String method,
    String href, {
    Uint8List? body,
  }) async {
    var uri = _transferUri(href);
    final watch = Stopwatch()..start();
    for (var redirects = 0; redirects <= 3; redirects++) {
      final result = await _request(
        method,
        uri,
        oauth: false,
        body: body,
        timeout: _remaining(watch),
      );
      if (result.$1 < 300 || result.$1 >= 400) return result;
      if (result.$3 == null ||
          redirects == 3 ||
          !(method == 'GET' ? [301, 302, 303, 307, 308] : [307, 308]).contains(
            result.$1,
          )) {
        throw const SyncFailure('Недопустимое перенаправление передачи файла.');
      }
      uri = _transferUri(uri.resolve(result.$3!).toString());
    }
    throw const SyncFailure('Слишком много перенаправлений Яндекса.');
  }

  Future<void> _operation(_Reply reply) async {
    Uri uri;
    try {
      uri = Uri.parse(_href(reply));
    } catch (_) {
      throw const SyncFailure('Яндекс вернул недопустимую ссылку операции.');
    }
    if (!_apiUri(uri) ||
        !uri.path.startsWith('/v1/disk/operations/') ||
        uri.path == '/v1/disk/operations/') {
      throw const SyncFailure('Яндекс вернул недопустимую ссылку операции.');
    }
    final watch = Stopwatch()..start();
    while (true) {
      final result = await _request('GET', uri, timeout: _remaining(watch));
      _status(result.$1, {200});
      switch (_json(result.$2)['status']) {
        case 'success':
          return;
        case 'failed':
          throw const _OperationFailed();
        case 'in-progress':
          final remaining = _remaining(watch);
          await Future<void>.delayed(
            pollInterval < remaining ? pollInterval : remaining,
          );
        default:
          throw const SyncFailure('Некорректный статус операции Яндекса.');
      }
    }
  }

  @override
  Future<void> mkdir(String path) async {
    final resource = resourcePath(path);
    final result = await _request('PUT', _api('resources', {'path': resource}));
    if (result.$1 == 202) {
      await _operation(result);
      return;
    }
    if (result.$1 == 409) {
      final existing = await _request(
        'GET',
        _api('resources', {'path': resource, 'fields': 'type'}),
      );
      if (existing.$1 == 200 && _json(existing.$2)['type'] == 'dir') return;
    }
    _status(result.$1, {201});
  }

  @override
  Future<List<String>> list(String path) async {
    final resource = resourcePath(path);
    if (!path.endsWith('/')) throw const SyncFailure('Ожидается папка.');
    var offset = 0;
    final result = <String>{};
    final watch = Stopwatch()..start();
    while (true) {
      final page = await _request(
        'GET',
        _api('resources', {
          'path': resource,
          'fields': '_embedded.items.name',
          'limit': '$pageSize',
          'offset': '$offset',
        }),
        timeout: _remaining(watch),
      );
      if (page.$1 == 404) return [];
      _status(page.$1, {200});
      final data = _json(page.$2);
      final embedded = data['_embedded'];
      if (embedded is! Map || embedded['items'] is! List) {
        throw const SyncFailure('Некорректный список файлов синхронизации.');
      }
      final items = embedded['items'] as List;
      if (items.length > pageSize) {
        throw const SyncFailure('Некорректная страница файлов Яндекса.');
      }
      for (final item in items) {
        final name = item is Map ? item['name'] : null;
        if (name is! String ||
            name.isEmpty ||
            name == '.' ||
            name == '..' ||
            name.contains(RegExp(r'[/\\%?#]'))) {
          throw const SyncFailure('Некорректное имя файла синхронизации.');
        }
        result.add(name);
      }
      if (items.length < pageSize) return result.toList()..sort();
      offset += items.length;
    }
  }

  @override
  Future<Uint8List?> read(String path) async {
    final result = await _request(
      'GET',
      _api('resources/download', {'path': resourcePath(path)}),
    );
    if (result.$1 == 404) return null;
    _status(result.$1, {200});
    final file = await _transfer('GET', _href(result));
    if (file.$1 == 404) return null;
    _status(file.$1, {200});
    return file.$2;
  }

  bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _existing(String path, Uint8List bytes) async {
    final current = await read(path);
    if (current == null) return false;
    if (!_same(current, bytes)) {
      throw const SyncFailure(
        'Конфликт файла синхронизации. Данные не перезаписаны.',
      );
    }
    return true;
  }

  @override
  Future<void> publish(String path, Uint8List bytes) =>
      _publish(path, bytes, false);

  @override
  Future<void> replace(String path, Uint8List bytes) =>
      _publish(path, bytes, true);

  Future<void> _publish(String path, Uint8List bytes, bool overwrite) async {
    final resource = resourcePath(path);
    if (bytes.length > syncMaximumBytes) {
      throw const SyncFailure('Пачка синхронизации слишком большая.');
    }
    if (!overwrite && await _existing(path, bytes)) return;
    // Два устройства могут одновременно создавать meta. Разные временные
    // имена не позволяют MOVE одного устройства опубликовать чужие байты.
    final temp = resourcePath('$path.${const Uuid().v4()}.part');
    final upload = await _request(
      'GET',
      _api('resources/upload', {'path': temp, 'overwrite': 'true'}),
    );
    _status(upload.$1, {200});
    final sent = await _transfer('PUT', _href(upload), body: bytes);
    if (sent.$1 == 202) {
      await _operation(sent);
    } else {
      _status(sent.$1, {200, 201, 204});
    }
    final move = await _request(
      'POST',
      _api('resources/move', {
        'from': temp,
        'path': resource,
        'overwrite': '$overwrite',
      }),
    );
    if (!overwrite && move.$1 == 409 && await _existing(path, bytes)) return;
    if (move.$1 == 202) {
      try {
        await _operation(move);
      } on _OperationFailed {
        if (!overwrite && await _existing(path, bytes)) return;
        rethrow;
      }
    } else {
      _status(move.$1, {201});
    }
  }

  @override
  Future<void> delete(String path) async {
    final resource = resourcePath(path);
    if (resource == 'app:/') {
      throw const SyncFailure('Удаление корня синхронизации запрещено.');
    }
    final result = await _request(
      'DELETE',
      _api('resources', {'path': resource, 'permanently': 'true'}),
    );
    if (result.$1 == 202) {
      await _operation(result);
      return;
    }
    _status(result.$1, {204, 404});
  }

  @override
  void close() => _client.close(force: true);
}

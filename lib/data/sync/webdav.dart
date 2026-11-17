import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'sync_error.dart';
import 'sync_storage.dart';

/// Только выделенная папка приложения; без редиректов и произвольных href.
class YandexWebDav implements SyncDisk {
  YandexWebDav(String login, String password, {HttpClient? client})
    : _client = client ?? HttpClient(),
      _authorization =
          'Basic ${base64Encode(utf8.encode('$login:$password'))}' {
    if (login.contains(':') || login.trim().isEmpty || password.isEmpty) {
      throw const SyncFailure('Введите логин и пароль приложения Яндекса.');
    }
    _client.connectionTimeout = const Duration(seconds: 10);
  }
  final HttpClient _client;
  final String _authorization;

  static Uri address(String path) {
    if (!path.startsWith(syncRoot) ||
        path.contains(RegExp(r'[%\\?#]')) ||
        path.split('/').any((p) => p == '.' || p == '..') ||
        !RegExp(r'^[/A-Za-z0-9_.-]+$').hasMatch(path)) {
      throw const SyncFailure('Недопустимый путь синхронизации.');
    }
    return Uri.https('webdav.yandex.ru', path);
  }

  Future<(int, Uint8List)> _request(
    String method,
    String path, {
    Uint8List? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = address(path);
    HttpClientRequest? request;
    try {
      return await (() async {
        request = await _client.openUrl(method, uri);
        request!.followRedirects = false;
        request!.headers.set(HttpHeaders.authorizationHeader, _authorization);
        headers.forEach((key, value) => request!.headers.set(key, value));
        if (body != null) {
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
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const SyncFailure(
            'Неверный логин или пароль приложения Яндекса, либо нет доступа к папке.',
          );
        }
        if (response.statusCode >= 300 && response.statusCode < 400) {
          throw const SyncFailure(
            'Сервер предложил запрещённое перенаправление.',
          );
        }
        return (response.statusCode, bytes.takeBytes());
      })().timeout(
        const Duration(seconds: 30),
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

  void _status(int status, Set<int> allowed) {
    if (!allowed.contains(status)) {
      throw SyncFailure(
        'Ошибка Яндекса (HTTP $status). Повторите синхронизацию.',
      );
    }
  }

  @override
  Future<void> mkdir(String path) async {
    final result = await _request('MKCOL', path);
    if (result.$1 == 409 && path == syncRoot) {
      throw const SyncFailure(
        'Не удалось создать папку приложения. Создайте папку Apps в корне Диска и повторите.',
      );
    }
    _status(result.$1, {201, 405});
  }

  @override
  Future<Uint8List?> read(String path) async {
    final result = await _request('GET', path);
    if (result.$1 == 404) return null;
    _status(result.$1, {200});
    return result.$2;
  }

  @override
  Future<List<String>> list(String path) async {
    address(path);
    if (!path.endsWith('/')) throw const SyncFailure('Ожидается папка.');
    final result = await _request('PROPFIND', path, headers: {'Depth': '1'});
    if (result.$1 == 404) return [];
    _status(result.$1, {207});
    try {
      final text = utf8.decode(result.$2);
      if (text.contains('<!DOCTYPE')) throw const FormatException();
      final document = XmlDocument.parse(text);
      final found = <String>[];
      for (final element in document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'href',
      )) {
        final href = Uri.parse(element.innerText);
        if (href.hasAuthority &&
            (href.host != 'webdav.yandex.ru' ||
                href.scheme != 'https' ||
                href.userInfo.isNotEmpty ||
                href.port != 443)) {
          throw const FormatException();
        }
        final candidate = Uri.decodeComponent(href.path);
        address(candidate);
        if (candidate == path) continue;
        if (!candidate.startsWith(path)) throw const FormatException();
        final name = candidate
            .substring(path.length)
            .replaceFirst(RegExp(r'/$'), '');
        if (name.isEmpty || name.contains('/')) throw const FormatException();
        found.add(name);
      }
      return found.toSet().toList()..sort();
    } on SyncFailure {
      rethrow;
    } catch (_) {
      throw const SyncFailure('Некорректный список файлов синхронизации.');
    }
  }

  @override
  Future<void> publish(String path, Uint8List bytes) async {
    address(path);
    if (bytes.length > syncMaximumBytes) {
      throw const SyncFailure('Пачка синхронизации слишком большая.');
    }
    final existing = await read(path);
    if (existing != null) {
      if (base64Encode(existing) != base64Encode(bytes)) {
        throw const SyncFailure(
          'Конфликт файла синхронизации. Данные не перезаписаны.',
        );
      }
      return;
    }
    // Оборванный PUT оставляет только .part. Читатели видят лишь законченный MOVE.
    final temp = '$path.part';
    final put = await _request('PUT', temp, body: bytes);
    _status(put.$1, {200, 201, 204});
    final move = await _request(
      'MOVE',
      temp,
      headers: {'Destination': address(path).toString(), 'Overwrite': 'F'},
    );
    if (move.$1 == 412) {
      final winner = await read(path);
      if (winner != null && base64Encode(winner) == base64Encode(bytes)) return;
    }
    _status(move.$1, {201, 204});
  }

  @override
  void close() => _client.close(force: true);
}

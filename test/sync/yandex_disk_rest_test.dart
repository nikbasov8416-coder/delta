import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:delta/data/sync/yandex_disk_rest.dart';
import 'package:delta/data/sync/sync_error.dart';
import 'package:delta/data/sync/sync_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const syntheticToken = 'synthetic-token';
const download = 'https://downloader.disk.yandex.ru/presigned';
const upload = 'https://uploader.disk.yandex.net/presigned';
const operation = 'https://cloud-api.yandex.net/v1/disk/operations/synthetic';

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  String? value(String name) => values[name] as String?;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, {Object? json, List<int>? bytes, String? location})
    : bytes = bytes ?? (json == null ? [] : utf8.encode(jsonEncode(json))) {
    if (location != null) headers.set(HttpHeaders.locationHeader, location);
  }
  @override
  final int statusCode;
  final List<int> bytes;
  @override
  final _Headers headers = _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Request implements HttpClientRequest {
  _Request(this.method, this.uri, this.respond);
  @override
  final String method;
  @override
  final Uri uri;
  final _Response Function(_Request) respond;
  @override
  bool followRedirects = true;
  @override
  int contentLength = 0;
  bool aborted = false;
  final body = BytesBuilder();
  @override
  final _Headers headers = _Headers();
  @override
  void add(List<int> data) => body.add(data);
  @override
  Future<HttpClientResponse> close() async => respond(this);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Client implements HttpClient {
  final replies = <_Response>[];
  final requests = <_Request>[];
  _Response Function(_Request)? respond;
  Object? error;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (error != null) throw error!;
    final request = _Request(
      method,
      url,
      respond ?? (_) => replies.removeAt(0),
    );
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

_Response _link(String href) => _Response(200, json: {'href': href});
_Response _names(List<String> names) => _Response(
  200,
  json: {
    '_embedded': {
      'items': [
        for (final name in names) {'name': name},
      ],
    },
  },
);
List<_Response> _freshPublish([_Response? move]) => [
  _Response(404),
  _link(upload),
  _Response(201),
  move ?? _Response(201),
];
void _authBoundary(_Client client) {
  for (final request in client.requests) {
    expect(request.followRedirects, isFalse);
    final authorized = request.uri.host == 'cloud-api.yandex.net';
    expect(
      request.headers.values[HttpHeaders.authorizationHeader],
      authorized ? 'OAuth $syntheticToken' : isNull,
    );
    expect(request.uri.toString(), isNot(contains(syntheticToken)));
  }
}

void main() {
  test(
    'Логический корень отображается только в app:/; выход за каталог запрещён',
    () async {
      expect(YandexDiskRest.resourcePath(syncRoot), 'app:/');
      expect(
        YandexDiskRest.resourcePath('${syncRoot}log/device/'),
        'app:/log/device',
      );
      final client = _Client();
      final disk = YandexDiskRest(syntheticToken, client: client);
      for (final path in [
        '/Apps/',
        '/Apps/Finance/../x',
        '/Apps/Finance/%2e%2e/x',
        '/Apps/Finance/x?query',
        'app:/meta',
      ]) {
        await expectLater(disk.read(path), throwsA(isA<SyncFailure>()));
      }
      expect(client.requests, isEmpty);
    },
  );
  test('mkdir: PUT 201, уже существующая папка, но не файл', () async {
    for (final existing in [null, 'dir', 'file']) {
      final client = _Client()
        ..replies.addAll(
          existing == null
              ? [_Response(201)]
              : [
                  _Response(409),
                  _Response(200, json: {'type': existing}),
                ],
        );
      final disk = YandexDiskRest(syntheticToken, client: client);
      final action = disk.mkdir('${syncRoot}log/');
      if (existing == 'file') {
        await expectLater(action, throwsA(isA<SyncFailure>()));
      } else {
        await action;
      }
      expect(client.requests.first.method, 'PUT');
      expect(client.requests.first.uri.path, '/v1/disk/resources');
      expect(client.requests.first.uri.queryParameters['path'], 'app:/log');
      _authBoundary(client);
    }
  });
  test('list: страницы и offset, без молчаливого усечения', () async {
    final client = _Client()
      ..replies.addAll([
        _names(['b', 'a']),
        _names(['c']),
      ]);
    final disk = YandexDiskRest(syntheticToken, client: client, pageSize: 2);
    expect(await disk.list('${syncRoot}log/'), ['a', 'b', 'c']);
    expect(client.requests.map((r) => r.uri.queryParameters['offset']), [
      '0',
      '2',
    ]);
    for (final request in client.requests) {
      expect(request.uri.queryParameters['limit'], '2');
      expect(
        request.uri.queryParameters['fields'],
        '_embedded.items.name,_embedded.items.type,_embedded.items.size,_embedded.items.modified',
      );
      expect(request.uri.queryParameters['path'], 'app:/log');
    }
    _authBoundary(client);
  });
  test('list/read: 404 означает отсутствие', () async {
    final client = _Client()
      ..replies.addAll([
        _Response(404),
        _Response(404),
        _link(download),
        _Response(404),
      ]);
    final disk = YandexDiskRest(syntheticToken, client: client);
    expect(await disk.list('${syncRoot}log/'), isEmpty);
    expect(await disk.read('${syncRoot}meta'), isNull);
    expect(await disk.read('${syncRoot}meta'), isNull);
    _authBoundary(client);
  });
  test('read: API download → HTTPS href без OAuth', () async {
    final client = _Client()
      ..replies.addAll([
        _link(download),
        _Response(200, bytes: [0, 1, 255]),
      ]);
    final disk = YandexDiskRest(syntheticToken, client: client);
    expect(await disk.read('${syncRoot}meta'), [0, 1, 255]);
    expect(client.requests.first.uri.path, '/v1/disk/resources/download');
    expect(client.requests.first.uri.queryParameters['path'], 'app:/meta');
    _authBoundary(client);
  });
  for (final href in [
    'https://example.invalid/x',
    'http://disk.yandex.net/x',
    'https://yandex.net.evil.invalid/x',
    'https://evil-yandex.net/x',
    'https://user@disk.yandex.ru/x',
    'https://disk.yandex.ru:8443/x',
  ]) {
    test('Чужой/недопустимый href отклонён до запроса: $href', () async {
      final client = _Client()..replies.add(_link(href));
      await expectLater(
        YandexDiskRest(syntheticToken, client: client).read('${syncRoot}meta'),
        throwsA(isA<SyncFailure>()),
      );
      expect(client.requests, hasLength(1));
    });
  }
  test('Даже href на хосте API получает файл без OAuth', () async {
    final client = _Client()
      ..replies.addAll([
        _link('https://cloud-api.yandex.net/v1/disk/presigned'),
        _Response(200, bytes: [1]),
      ]);
    expect(
      await YandexDiskRest(
        syntheticToken,
        client: client,
      ).read('${syncRoot}meta'),
      [1],
    );
    expect(
      client.requests.first.headers.values[HttpHeaders.authorizationHeader],
      'OAuth $syntheticToken',
    );
    expect(
      client.requests.last.headers.values[HttpHeaders.authorizationHeader],
      isNull,
    );
  });

  test(
    'Редиректы передачи только внутри HTTPS Яндекса, OAuth не переносится',
    () async {
      final client = _Client()
        ..replies.addAll([
          _link(download),
          _Response(302, location: upload),
          _Response(200, bytes: [5]),
        ]);
      final disk = YandexDiskRest(syntheticToken, client: client);
      expect(await disk.read('${syncRoot}meta'), [5]);
      _authBoundary(client);
      final bad = _Client()
        ..replies.addAll([
          _link(download),
          _Response(302, location: 'https://evil.invalid/x'),
        ]);
      await expectLater(
        YandexDiskRest(syntheticToken, client: bad).read('${syncRoot}meta'),
        throwsA(isA<SyncFailure>()),
      );
      expect(bad.requests, hasLength(2));
      expect(
        bad.requests.last.headers.values[HttpHeaders.authorizationHeader],
        isNull,
      );
    },
  );
  test(
    'publish: upload .part, PUT без токена, POST move без overwrite',
    () async {
      final client = _Client()..replies.addAll(_freshPublish());
      final disk = YandexDiskRest(syntheticToken, client: client);
      await disk.publish('${syncRoot}meta', Uint8List.fromList([1, 2, 3]));
      expect(client.requests.map((r) => r.method), [
        'GET',
        'GET',
        'PUT',
        'POST',
      ]);
      expect(client.requests[1].uri.path, '/v1/disk/resources/upload');
      expect(
        client.requests[1].uri.queryParameters['path'],
        matches(r'^app:/meta\.[a-f0-9-]{36}\.part$'),
      );
      expect(client.requests[1].uri.queryParameters['overwrite'], 'true');
      expect(client.requests[2].body.takeBytes(), [1, 2, 3]);
      expect(client.requests.last.uri.queryParameters, {
        'from': client.requests[1].uri.queryParameters['path'],
        'path': 'app:/meta',
        'overwrite': 'false',
      });
      _authBoundary(client);
      disk.close();
      expect(client.closed, isTrue);
    },
  );
  test(
    'Неверный upload href и внешний redirect PUT не получают данные/токен',
    () async {
      for (final redirect in [false, true]) {
        final client = _Client()
          ..replies.addAll([
            _Response(404),
            _link(redirect ? upload : 'https://evil.invalid/put'),
            if (redirect) _Response(307, location: 'https://evil.invalid/put'),
          ]);
        await expectLater(
          YandexDiskRest(
            syntheticToken,
            client: client,
          ).publish('${syncRoot}meta', Uint8List.fromList([1])),
          throwsA(isA<SyncFailure>()),
        );
        expect(client.requests, hasLength(redirect ? 3 : 2));
        expect(
          client.requests.any((r) => r.uri.host == 'evil.invalid'),
          isFalse,
        );
        if (redirect) {
          expect(
            client.requests.last.headers.values[HttpHeaders
                .authorizationHeader],
            isNull,
          );
        }
      }
    },
  );

  test(
    'Два одновременных publish не могут подменить друг другу временный файл',
    () async {
      final files = <String, List<int>>{};
      final client = _Client()
        ..respond = (request) {
          final query = request.uri.queryParameters;
          final path = query['path'];
          if (request.uri.path == '/v1/disk/resources/download') {
            return files.containsKey(path)
                ? _link(
                    Uri.https('downloader.disk.yandex.ru', '/file', {
                      'path': path!,
                    }).toString(),
                  )
                : _Response(404);
          }
          if (request.uri.path == '/v1/disk/resources/upload') {
            return _link(
              Uri.https('uploader.disk.yandex.net', '/file', {
                'path': path!,
              }).toString(),
            );
          }
          if (request.method == 'PUT') {
            files[path!] = request.body.takeBytes();
            return _Response(201);
          }
          if (request.method == 'POST') {
            if (files.containsKey(path)) return _Response(409);
            files[path!] = files.remove(query['from'])!;
            return _Response(201);
          }
          return _Response(200, bytes: files[path]);
        };
      final results = await Future.wait(
        [1, 2].map((n) async {
          try {
            await YandexDiskRest(
              syntheticToken,
              client: client,
            ).publish('${syncRoot}meta', Uint8List.fromList([n]));
            return n;
          } on SyncFailure {
            return null;
          }
        }),
      );
      final success = results.whereType<int>().single;
      expect(files['app:/meta'], [success]);
      final temps = client.requests
          .where((r) => r.uri.path == '/v1/disk/resources/upload')
          .map((r) => r.uri.queryParameters['path'])
          .toSet();
      expect(temps, hasLength(2));
    },
  );

  test(
    'MOVE 202: опрос in-progress → success с OAuth только операции API',
    () async {
      final client = _Client()
        ..replies.addAll([
          ..._freshPublish(_Response(202, json: {'href': operation})),
          _Response(200, json: {'status': 'in-progress'}),
          _Response(200, json: {'status': 'success'}),
        ]);
      final disk = YandexDiskRest(
        syntheticToken,
        client: client,
        pollInterval: Duration.zero,
      );
      await disk.publish('${syncRoot}meta', Uint8List.fromList([1]));
      expect(
        client.requests.where((r) => r.uri.path.contains('/operations/')),
        hasLength(2),
      );
      _authBoundary(client);
    },
  );
  test(
    'mkdir 202 по Location; ссылка операции не может увести токен',
    () async {
      final client = _Client()
        ..replies.addAll([
          _Response(202, location: operation),
          _Response(200, json: {'status': 'success'}),
        ]);
      await YandexDiskRest(
        syntheticToken,
        client: client,
      ).mkdir('${syncRoot}log/');
      _authBoundary(client);
      for (final href in [
        'https://evil.invalid/v1/disk/operations/x',
        'https://cloud-api.yandex.net/not-api/x',
        'https://cloud-api.yandex.net/v1/disk/resources',
      ]) {
        final bad = _Client()
          ..replies.add(_Response(202, json: {'href': href}));
        await expectLater(
          YandexDiskRest(syntheticToken, client: bad).mkdir('${syncRoot}log/'),
          throwsA(isA<SyncFailure>()),
        );
        expect(bad.requests, hasLength(1));
      }
    },
  );
  test('Опрос 202 ограничен временем и не печатает ответ', () async {
    final client = _Client()
      ..respond = (r) => r.method == 'PUT'
          ? _Response(202, json: {'href': operation})
          : _Response(
              200,
              json: {'status': 'in-progress', 'message': 'SECRET'},
            );
    final disk = YandexDiskRest(
      syntheticToken,
      client: client,
      requestTimeout: const Duration(milliseconds: 25),
      pollInterval: const Duration(milliseconds: 5),
    );
    await expectLater(
      disk.mkdir('${syncRoot}log/'),
      throwsA(
        isA<SyncFailure>().having(
          (e) => e.message,
          'причина',
          contains('Тайм-аут'),
        ),
      ),
    );
  });
  test(
    'Повтор publish: те же байты успешны, другие не перезаписывают файл',
    () async {
      for (final bytes in [
        [1, 2],
        [3, 4],
      ]) {
        final client = _Client()
          ..replies.addAll([_link(download), _Response(200, bytes: bytes)]);
        final action = YandexDiskRest(
          syntheticToken,
          client: client,
        ).publish('${syncRoot}meta', Uint8List.fromList([1, 2]));
        if (bytes.first == 1) {
          await action;
        } else {
          await expectLater(
            action,
            throwsA(
              isA<SyncFailure>().having(
                (e) => e.message,
                'причина',
                contains('Конфликт файла'),
              ),
            ),
          );
        }
        expect(client.requests.map((r) => r.method), ['GET', 'GET']);
        _authBoundary(client);
      }
    },
  );
  test('Гонка MOVE 409: сравнение готового файла, без перезаписи', () async {
    final client = _Client()
      ..replies.addAll([
        ..._freshPublish(_Response(409)),
        _link(download),
        _Response(200, bytes: [1]),
      ]);
    await YandexDiskRest(
      syntheticToken,
      client: client,
    ).publish('${syncRoot}meta', Uint8List.fromList([1]));
    expect(client.requests.where((r) => r.method == 'POST'), hasLength(1));
    _authBoundary(client);
  });
  test(
    'Асинхронный MOVE failed: ошибка либо идентичный уже опубликованный файл',
    () async {
      final client = _Client()
        ..replies.addAll([
          ..._freshPublish(_Response(202, json: {'href': operation})),
          _Response(200, json: {'status': 'failed', 'message': 'SECRET'}),
          _link(download),
          _Response(200, bytes: [1]),
        ]);
      await YandexDiskRest(
        syntheticToken,
        client: client,
      ).publish('${syncRoot}meta', Uint8List.fromList([1]));
      final failed = _Client()
        ..replies.addAll([
          _Response(202, json: {'href': operation}),
          _Response(200, json: {'status': 'failed', 'message': 'SECRET'}),
        ]);
      await expectLater(
        YandexDiskRest(syntheticToken, client: failed).mkdir('${syncRoot}log/'),
        throwsA(
          isA<SyncFailure>().having(
            (e) => e.message,
            'без ответа',
            isNot(contains('SECRET')),
          ),
        ),
      );
    },
  );
  for (final status in [401, 402, 403, 507]) {
    test('HTTP $status: понятная ошибка без токена, URL и тела', () async {
      final client = _Client()
        ..replies.add(
          _Response(
            status,
            json: {'message': 'SECRET https://evil.invalid/$syntheticToken'},
          ),
        );
      await expectLater(
        YandexDiskRest(syntheticToken, client: client).read('${syncRoot}meta'),
        throwsA(
          isA<SyncFailure>()
              .having(
                (e) => e.message,
                'секрет',
                isNot(contains(syntheticToken)),
              )
              .having((e) => e.message, 'тело', isNot(contains('SECRET')))
              .having((e) => e.message, 'URL', isNot(contains('https://')))
              .having(
                (e) => e.message,
                'причина',
                contains(switch (status) {
                  401 => 'Вход в Яндекс истёк или отозван. Войдите заново',
                  402 => 'тарифа',
                  403 => 'Нет доступа',
                  _ => 'свободного места',
                }),
              ),
        ),
      );
    });
  }
  test('API redirect запрещён; сеть/тайм-аут безопасны', () async {
    final client = _Client()
      ..replies.add(_Response(302, location: 'https://evil.invalid/'));
    await expectLater(
      YandexDiskRest(syntheticToken, client: client).read('${syncRoot}meta'),
      throwsA(isA<SyncFailure>()),
    );
    expect(client.requests, hasLength(1));
    for (final error in [
      const SocketException('SECRET'),
      TimeoutException('SECRET'),
    ]) {
      final broken = _Client()..error = error;
      await expectLater(
        YandexDiskRest(syntheticToken, client: broken).read('${syncRoot}meta'),
        throwsA(
          isA<SyncFailure>().having(
            (e) => e.message,
            'без деталей',
            isNot(contains('SECRET')),
          ),
        ),
      );
    }
  });
  test('Размер: ограничение чтения и загрузки до обращения к API', () async {
    final big = Uint8List(syncMaximumBytes + 1);
    final client = _Client()
      ..replies.addAll([_link(download), _Response(200, bytes: big)]);
    await expectLater(
      YandexDiskRest(syntheticToken, client: client).read('${syncRoot}meta'),
      throwsA(isA<SyncFailure>()),
    );
    expect(client.requests.last.aborted, isTrue);
    final empty = _Client();
    await expectLater(
      YandexDiskRest(
        syntheticToken,
        client: empty,
      ).publish('${syncRoot}meta', big),
      throwsA(isA<SyncFailure>()),
    );
    expect(empty.requests, isEmpty);
  });
  test(
    'delete: только внутри корня, permanently=true, 202 опрашивается',
    () async {
      final client = _Client()
        ..replies.addAll([
          _Response(202, json: {'href': operation}),
          _Response(200, json: {'status': 'success'}),
        ]);
      final disk = YandexDiskRest(syntheticToken, client: client);
      await disk.delete('${syncRoot}sets/old/');
      expect(client.requests.first.method, 'DELETE');
      expect(client.requests.first.uri.queryParameters, {
        'path': 'app:/sets/old',
        'permanently': 'true',
      });
      final count = client.requests.length;
      for (final bad in ['/Apps/', '$syncRoot../x', syncRoot]) {
        await expectLater(disk.delete(bad), throwsA(isA<SyncFailure>()));
      }
      expect(client.requests.length, count);
    },
  );
  test('replace: указатель меняется атомарным MOVE с overwrite=true', () async {
    final client = _Client()
      ..replies.addAll([_link(upload), _Response(201), _Response(201)]);
    await YandexDiskRest(
      syntheticToken,
      client: client,
    ).replace('${syncRoot}current', Uint8List.fromList([1]));
    expect(client.requests.map((r) => r.method), ['GET', 'PUT', 'POST']);
    expect(client.requests.last.uri.queryParameters['overwrite'], 'true');
  });
}

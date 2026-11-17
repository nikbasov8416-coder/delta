import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:delta/data/sync/webdav.dart';
import 'package:delta/data/sync/sync_error.dart';
import 'package:flutter_test/flutter_test.dart';

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.method, this.uri, this.response);
  @override
  final String method;
  @override
  final Uri uri;
  final _Response response;
  final bytes = BytesBuilder();
  @override
  int contentLength = 0;
  @override
  bool followRedirects = true;
  @override
  final _Headers headers = _Headers();
  @override
  void add(List<int> data) => bytes.add(data);
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, [this.body = '']);
  @override
  final int statusCode;
  final String body;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  final replies = <_Response>[];
  final requests = <_Request>[];
  Object? error;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    if (error != null) throw error!;
    final request = _Request(method, uri, replies.removeAt(0));
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Публикация: GET, PUT .part, MOVE без перезаписи; Basic только заданному хосту', () async {
    final client = _Client()
      ..replies.addAll([_Response(404), _Response(201), _Response(201)]);
    final disk = YandexWebDav(
      'synthetic-login',
      'synthetic-secret',
      client: client,
    );
    addTearDown(disk.close);
    await disk.publish(
      '/Apps/Finance/log/test/1.bin',
      Uint8List.fromList([1, 2, 3]),
    );
    expect(client.requests.map((r) => r.method), ['GET', 'PUT', 'MOVE']);
    expect(client.requests[1].uri.path, endsWith('.bin.part'));
    expect(client.requests[1].bytes.takeBytes(), [1, 2, 3]);
    expect(client.requests.last.headers.values['Overwrite'], 'F');
    expect(
      client.requests.last.headers.values['Destination'],
      'https://webdav.yandex.ru/Apps/Finance/log/test/1.bin',
    );
    for (final request in client.requests) {
      expect(request.uri.host, 'webdav.yandex.ru');
      expect(request.uri.userInfo, isEmpty);
      expect(request.followRedirects, isFalse);
      expect(
        request.headers.values[HttpHeaders.authorizationHeader],
        'Basic ${base64Encode(utf8.encode('synthetic-login:synthetic-secret'))}',
      );
    }
  });
  test(
    'Повтор идентичного файла успешен, другие байты не перезаписываются',
    () async {
      for (final content in ['same', 'different']) {
        final client = _Client()..replies.add(_Response(200, content));
        final disk = YandexWebDav(
          'synthetic',
          'synthetic-secret',
          client: client,
        );
        final action = disk.publish(
          '/Apps/Finance/meta',
          Uint8List.fromList(utf8.encode('same')),
        );
        if (content == 'same') {
          await action;
        } else {
          await expectLater(action, throwsA(isA<SyncFailure>()));
        }
        expect(client.requests.map((r) => r.method), ['GET']);
      }
    },
  );

  test('Подмена href не вызывает запрос за пределами хранилища', () async {
    final client = _Client()
      ..replies.add(
        _Response(
          207,
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>https://example.invalid/Apps/Finance/log/evil</d:href></d:response></d:multistatus>',
        ),
      );
    final disk = YandexWebDav('synthetic', 'synthetic-secret', client: client);
    await expectLater(
      disk.list('/Apps/Finance/log/'),
      throwsA(isA<SyncFailure>()),
    );
    expect(client.requests, hasLength(1));
  });
  test('PROPFIND Depth 1 и MKCOL: только имена прямых детей', () async {
    final client = _Client()
      ..replies.addAll([
        _Response(201),
        _Response(
          207,
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/Apps/Finance/log/</d:href></d:response><d:response><d:href>/Apps/Finance/log/device/</d:href></d:response></d:multistatus>',
        ),
      ]);
    final disk = YandexWebDav('synthetic', 'synthetic-secret', client: client);
    await disk.mkdir('/Apps/Finance/log/');
    expect(await disk.list('/Apps/Finance/log/'), ['device']);
    expect(client.requests.last.headers.values['Depth'], '1');
  });
  for (final status in [401, 403, 302, 503]) {
    test('Безопасная ошибка HTTP $status: без тела и учётных данных', () async {
      final client = _Client()
        ..replies.add(_Response(status, 'SECRET https://synthetic.invalid/'));
      final disk = YandexWebDav(
        'synthetic',
        'synthetic-secret',
        client: client,
      );
      await expectLater(
        disk.read('/Apps/Finance/meta'),
        throwsA(
          isA<SyncFailure>()
              .having((e) => e.message, 'текст', isNot(contains('SECRET')))
              .having((e) => e.message, 'URL', isNot(contains('https://')))
              .having(
                (e) => e.message,
                'пароль',
                isNot(contains('synthetic-secret')),
              ),
        ),
      );
    });
  }
  test('Нет сети: безопасная категория', () async {
    final client = _Client()
      ..error = const SocketException('SECRET https://synthetic.invalid');
    final disk = YandexWebDav('synthetic', 'synthetic-secret', client: client);
    await expectLater(
      disk.read('/Apps/Finance/meta'),
      throwsA(
        isA<SyncFailure>().having(
          (e) => e.message,
          'категория',
          contains('Нет сети'),
        ),
      ),
    );
  });
  test('delete WebDAV ограничен корнем', () async {
    final client = _Client()..replies.add(_Response(204));
    final disk = YandexWebDav('synthetic', 'synthetic-secret', client: client);
    await disk.delete('/Apps/Finance/log/old/');
    expect(client.requests.single.method, 'DELETE');
    for (final path in ['/Apps/', '/Apps/Finance/../x', '/Apps/Finance/']) {
      await expectLater(disk.delete(path), throwsA(isA<SyncFailure>()));
    }
    expect(client.requests, hasLength(1));
  });
}

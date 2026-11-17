import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:delta/data/rates/transport.dart';
import 'package:delta/domain/rates/rates.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class TestClient implements HttpClient {
  final seen = <Uri>[];
  Object? error;
  int status = 200;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    seen.add(url);
    if (error != null) throw error!;
    return TestRequest(status);
  }

  @override
  void close({bool force = false}) => closed = true;
  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) => throw StateError('Проверка сертификатов не должна отключаться');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRequest implements HttpClientRequest {
  TestRequest(this.status);
  final int status;
  @override
  bool followRedirects = true;
  @override
  final headers = TestHeaders();
  @override
  Future<HttpClientResponse> close() async => TestResponse(status);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestResponse extends Stream<List<int>> implements HttpClientResponse {
  TestResponse(this.statusCode);
  @override
  final int statusCode;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode('synthetic')).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'HARICA: отпечаток DER из упакованного PEM совпадает с утверждённым',
    () async {
      final pem = await rootBundle.loadString(SourceHttpTransport.cbrRootAsset);
      final base64 = RegExp(
        r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----',
      ).firstMatch(pem)!.group(1)!.replaceAll(RegExp(r'\s'), '');
      final hash = await Sha256().hash(base64Decode(base64));
      expect(
        hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'd95d0e8eda79525bf9beb11b14d2100d3294985f0c62d9fabd9cd999eccb7b1d',
      );
    },
  );

  test(
    'Контекст с HARICA применяется только к ЦБ и переиспользуется',
    () async {
      final contexts = <SecurityContext?>[];
      final clients = <TestClient>[];
      final transport = SourceHttpTransport(
        createClient: (context) {
          contexts.add(context);
          final client = TestClient();
          clients.add(client);
          return client;
        },
      );
      for (final host in [
        'api.coingecko.com',
        'www.cbr.ru',
        'api.kraken.com',
        'www.cbr.ru',
      ]) {
        expect(await transport.get(Uri.https(host, '/')), 'synthetic');
      }
      expect(contexts, hasLength(2));
      expect(contexts.first, isNull);
      expect(contexts.last, isA<SecurityContext>());
      expect(clients.first.seen.map((u) => u.host), [
        'api.coingecko.com',
        'api.kraken.com',
      ]);
      expect(clients.last.seen.map((u) => u.host), [
        'www.cbr.ru',
        'www.cbr.ru',
      ]);
      transport.close();
      expect(clients.every((client) => client.closed), isTrue);
      await expectLater(
        transport.get(Uri.https('www.cbr.ru', '/')),
        throwsA(isA<RateFailure>()),
      );
    },
  );

  for (final entry in <Object, String>{
    const HandshakeException('SECRET https://synthetic.invalid'): 'сертификата',
    const SocketException('SECRET https://synthetic.invalid'): 'Сетевая',
    TimeoutException('SECRET https://synthetic.invalid'): 'Тайм-аут',
    const HttpException('SECRET https://synthetic.invalid'): 'Сетевая',
  }.entries) {
    test(
      'Безопасная причина: ${entry.value} (${entry.key.runtimeType})',
      () async {
        final client = TestClient()..error = entry.key;
        final transport = SourceHttpTransport(createClient: (_) => client);
        addTearDown(transport.close);
        await expectLater(
          transport.get(Uri.https('www.cbr.ru', '/')),
          throwsA(
            isA<RateFailure>()
                .having((e) => e.message, 'причина', contains(entry.value))
                .having((e) => e.message, 'секрет', isNot(contains('SECRET')))
                .having((e) => e.message, 'URL', isNot(contains('https://'))),
          ),
        );
      },
    );
  }

  test('HTTP-код сохраняется без тела ответа и URL', () async {
    final client = TestClient()..status = 418;
    final transport = SourceHttpTransport(createClient: (_) => client);
    addTearDown(transport.close);
    await expectLater(
      transport.get(Uri.https('api.coingecko.com', '/')),
      throwsA(
        isA<RateFailure>()
            .having((e) => e.message, 'код', contains('HTTP 418'))
            .having((e) => e.message, 'тело', isNot(contains('synthetic')))
            .having((e) => e.message, 'URL', isNot(contains('https://'))),
      ),
    );
  });
}

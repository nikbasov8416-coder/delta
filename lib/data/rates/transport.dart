import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/rates/rates.dart';

abstract interface class RateTransport {
  Future<String> get(Uri uri);
  void close();
}

class SourceHttpTransport implements RateTransport {
  SourceHttpTransport({HttpClient Function(SecurityContext?)? createClient})
    : _createClient = createClient ?? _httpClient {
    _client = _newClient(null);
  }

  static const cbrRootAsset =
      'assets/certificates/harica_tls_rsa_root_ca_2021.crt';
  final HttpClient Function(SecurityContext?) _createClient;
  late final HttpClient _client;
  HttpClient? _cbrClient;
  Future<HttpClient>? _cbrFuture;

  static HttpClient _httpClient(SecurityContext? context) =>
      HttpClient(context: context);

  HttpClient _newClient(SecurityContext? context) =>
      _createClient(context)..connectionTimeout = const Duration(seconds: 8);

  Future<HttpClient> _loadCbrClient() async {
    final pem = await rootBundle.load(cbrRootAsset);
    // Системные корни сохраняются. Этот контекст не используется другими хостами.
    final context = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(
        pem.buffer.asUint8List(pem.offsetInBytes, pem.lengthInBytes),
      );
    if (_closed) throw const RateFailure('Загрузка отменена');
    return _cbrClient = _newClient(context);
  }

  static const allowedHosts = {
    'www.cbr.ru',
    'api.coingecko.com',
    'api.kraken.com',
  };
  bool _closed = false;
  @override
  Future<String> get(Uri uri) async {
    if (uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443) {
      throw const RateFailure('Запрещённый адрес источника');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_closed) throw const RateFailure('Загрузка отменена');
      HttpClientRequest? request;
      try {
        return await (() async {
          final client = uri.host == 'www.cbr.ru'
              ? await (_cbrFuture ??= _loadCbrClient())
              : _client;
          request = await client.getUrl(uri);
          request!.followRedirects = false;
          request!.headers.set(
            HttpHeaders.acceptHeader,
            'application/json, application/xml, text/xml',
          );
          final response = await request!.close();
          if (response.statusCode != 200) {
            await response.drain<void>();
            if (attempt == 0 &&
                [429, 502, 503, 504].contains(response.statusCode)) {
              throw const _Retry();
            }
            throw RateFailure(
              'Источник недоступен (HTTP ${response.statusCode}). Введите курс вручную.',
            );
          }
          final bytes = <int>[];
          await for (final chunk in response) {
            if (bytes.length + chunk.length > 2 * 1024 * 1024) {
              request!.abort();
              throw const RateFailure('Слишком большой ответ источника');
            }
            bytes.addAll(chunk);
          }
          // Нужные поля ЦБ — ASCII. Названия валют в XML не используются.
          return uri.host == 'www.cbr.ru'
              ? latin1.decode(bytes)
              : utf8.decode(bytes);
        })().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            request?.abort();
            throw const RateFailure(
              'Тайм-аут источника. Введите курс вручную.',
            );
          },
        );
      } on _Retry {
        await Future<void>.delayed(const Duration(seconds: 2));
      } on RateFailure {
        rethrow;
      } on HandshakeException {
        throw const RateFailure(
          'Ошибка сертификата источника. Введите курс вручную.',
        );
      } on TimeoutException {
        throw const RateFailure('Тайм-аут источника. Введите курс вручную.');
      } on SocketException {
        throw const RateFailure(
          'Сетевая ошибка источника. Введите курс вручную.',
        );
      } on HttpException {
        throw const RateFailure(
          'Сетевая ошибка источника. Введите курс вручную.',
        );
      } catch (_) {
        throw const RateFailure(
          'Не удалось обработать ответ источника. Введите курс вручную.',
        );
      }
    }
    throw const RateFailure('Не удалось получить курс');
  }

  @override
  void close() {
    _closed = true;
    _client.close(force: true);
    _cbrClient?.close(force: true);
  }
}

class _Retry implements Exception {
  const _Retry();
}

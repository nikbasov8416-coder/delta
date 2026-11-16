import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/rates/rates.dart';

abstract interface class RateTransport {
  Future<String> get(Uri uri);
  void close();
}

class SourceHttpTransport implements RateTransport {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
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
          request = await _client.getUrl(uri);
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
              'Источник не ответил вовремя. Введите курс вручную.',
            );
          },
        );
      } on _Retry {
        await Future<void>.delayed(const Duration(seconds: 2));
      } on RateFailure {
        rethrow;
      } catch (_) {
        throw const RateFailure(
          'Ошибка соединения с источником. Введите курс вручную.',
        );
      }
    }
    throw const RateFailure('Не удалось получить курс');
  }

  @override
  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

class _Retry implements Exception {
  const _Retry();
}

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta/data/rates/source_gateway.dart';
import 'package:delta/data/rates/transport.dart';
import 'package:delta/domain/rates/rates.dart';

class FixtureTransport implements RateTransport {
  final seen = <Uri>[];
  bool failGecko = false, failCbr = false;
  @override
  Future<String> get(Uri uri) async {
    seen.add(uri);
    String name;
    if (uri.host == 'www.cbr.ru') {
      if (failCbr) throw const RateFailure('ЦБ недоступен');
      name = 'cbr.xml';
    } else if (uri.host == 'api.coingecko.com') {
      if (failGecko) throw const RateFailure('CoinGecko недоступен');
      name = uri.path.contains('simple')
          ? 'coingecko_current.json'
          : uri.path.contains('bitcoin')
          ? 'coingecko_history.json'
          : 'coingecko_tether_history.json';
    } else if (uri.host == 'api.kraken.com') {
      name = uri.path.contains('OHLC')
          ? 'kraken_ohlc.json'
          : 'kraken_ticker.json';
    } else {
      throw StateError('Сеть в тестах запрещена');
    }
    return File('test/fixtures/rates/$name').readAsStringSync();
  }

  @override
  void close() {}
}

void main() {
  test(
    'Kraken since на сутки раньше; из трёх свечей выбирается нужная дата UTC',
    () async {
      final transport = FixtureTransport()..failGecko = true;
      final result = await PublicRateGateway(
        transport,
        now: () => DateTime.utc(2026, 1, 12),
      ).fetch({'BTC'}, DateTime.utc(2026, 1, 10, 17, 30));
      final request = transport.seen.singleWhere(
        (uri) => uri.path == '/0/public/OHLC',
      );
      expect(
        request.queryParameters['since'],
        '${DateTime.utc(2026, 1, 9).millisecondsSinceEpoch ~/ 1000}',
      );
      expect(result.errors, isEmpty);
      expect(
        result.quotes['BTC']!.value,
        Decimal.parse('12.34567890123456789') * Decimal.parse('73.25'),
      );
      expect(
        result.quotes['BTC']!.effectiveAt,
        startsWith('2026-01-10T00:00:00.000Z'),
      );
    },
  );
  test('Маршруты ЦБ и CoinGecko history, номинал и календарная дата', () async {
    final transport = FixtureTransport();
    final gateway = PublicRateGateway(
      transport,
      now: () => DateTime.utc(2026, 1, 12, 10),
    );
    final result = await gateway.fetch({
      'RUB',
      'CNY',
      'BTC',
      'USDT',
    }, DateTime.utc(2026, 1, 10));
    expect(result.errors, isEmpty);
    expect(result.quotes['CNY']!.value, Decimal.parse('12.345678'));
    expect(transport.seen.first.queryParameters['date_req'], '10/01/2026');
    expect(
      transport.seen
          .where((u) => u.host == 'api.coingecko.com')
          .every((u) => u.queryParameters['date'] == '10-01-2026'),
      isTrue,
    );
    expect(transport.seen.any((u) => u.host == 'api.kraken.com'), isFalse);
  });
  test(
    'Резерв BTC: историческая цена USD умножается на USD ЦБ, виден источник',
    () async {
      final transport = FixtureTransport()..failGecko = true;
      final result = await PublicRateGateway(
        transport,
        now: () => DateTime.utc(2026, 1, 12),
      ).fetch({'BTC'}, DateTime.utc(2026, 1, 10));
      expect(result.errors, isEmpty);
      expect(
        result.quotes['BTC']!.value,
        Decimal.parse('12.34567890123456789') * Decimal.parse('73.25'),
      );
      expect(result.quotes['BTC']!.source, 'kraken+cbr');
    },
  );
  test('Сбой не возвращает выдуманный курс, RUB остаётся доступен', () async {
    final transport = FixtureTransport()
      ..failGecko = true
      ..failCbr = true;
    final result = await PublicRateGateway(
      transport,
      now: () => DateTime.utc(2026, 1, 12),
    ).fetch({'RUB', 'BTC', 'USD'}, DateTime.utc(2026, 1, 10));
    expect(result.quotes.keys, {'RUB'});
    expect(result.errors.keys, containsAll(['BTC', 'USD']));
  });
  test(
    'Текущий резерв USDT использует биржевую цену, а не паритет USD',
    () async {
      final transport = FixtureTransport()..failGecko = true;
      final current = DateTime.utc(2026, 1, 12, 10);
      final result = await PublicRateGateway(
        transport,
        now: () => current,
      ).fetch({'USDT'}, current);
      expect(result.errors, isEmpty);
      expect(
        result.quotes['USDT']!.value,
        Decimal.parse('0.9987654321') * Decimal.parse('73.25'),
      );
      expect(result.quotes['USDT']!.source, 'kraken+cbr');
    },
  );
}

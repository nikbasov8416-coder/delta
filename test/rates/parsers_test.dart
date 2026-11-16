import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta/data/rates/source_gateway.dart';
import 'package:delta/data/rates/exact_json.dart';
import 'package:delta/data/rates/transport.dart';
import 'package:delta/domain/rates/rates.dart';

String fixture(String name) =>
    File('test/fixtures/rates/$name').readAsStringSync();
void main() {
  final fetched = DateTime.utc(2026, 1, 12, 10);
  test(
    'ЦБ: номинал и действующий курс выходного, без сдвига на будущую дату',
    () {
      final requested = DateTime.utc(2026, 1, 11);
      expect(requested.weekday, DateTime.sunday);
      final values = parseCbr(fixture('cbr.xml'), requested, fetched);
      expect(values['USD']!.value, Decimal.parse('73.25'));
      expect(values['CNY']!.value, Decimal.parse('12.345678'));
      expect(values['USD']!.date, '2026-01-11');
      expect(values['USD']!.effectiveAt, '2026-01-10');
      expect(
        () => parseCbr(fixture('cbr.xml'), DateTime.utc(2026, 1, 9), fetched),
        throwsA(isA<RateFailure>()),
      );
      expect(
        () => parseCbr(
          fixture('cbr.xml')
              .replaceFirst('<Nominal>1</Nominal>', '<Nominal>0</Nominal>'),
          requested,
          fetched,
        ),
        throwsA(isA<RateFailure>()),
      );
      expect(
        () => parseCbr(
          '<!DOCTYPE fake>${fixture('cbr.xml')}',
          requested,
          fetched,
        ),
        throwsA(isA<RateFailure>()),
      );
    },
  );
  test('CoinGecko history: BTC и USDT в RUB, цифры JSON без double', () {
    final day = DateTime.utc(2026, 1, 10);
    final btc = parseCoinGeckoHistory(
      fixture('coingecko_history.json'),
      'BTC',
      day,
      fetched,
    );
    final usdt = parseCoinGeckoHistory(
      fixture('coingecko_tether_history.json'),
      'USDT',
      day,
      fetched,
    );
    expect(btc.value, Decimal.parse('1234567.890123456789'));
    expect(usdt.value, Decimal.parse('74.123456789012345678'));
    expect(btc.effectiveAt, day.toIso8601String());
    expect(
      () => parseCoinGeckoHistory(
        fixture('coingecko_history.json'),
        'USDT',
        day,
        fetched,
      ),
      throwsA(isA<RateFailure>()),
    );
    expect(
      () => parseCoinGeckoHistory('{"id":"bitcoin"}', 'BTC', day, fetched),
      throwsA(isA<RateFailure>()),
    );
  });
  test(
    'Текущие CoinGecko: время источника обязательно, старые цены отклоняются',
    () {
      final prices = parseCoinGeckoCurrent(
        fixture('coingecko_current.json'),
        {'BTC', 'USDT'},
        fetched,
        fetched,
      );
      expect(prices['USDT']!.value, Decimal.parse('74.123456789012345678'));
      expect(prices['BTC']!.fetchedAt, fetched);
      expect(
        () => parseCoinGeckoCurrent(
          fixture('coingecko_current.json'),
          {'BTC'},
          fetched,
          fetched.add(const Duration(days: 2)),
        ),
        throwsA(isA<RateFailure>()),
      );
    },
  );
  test('Kraken: открытие свечи строго нужной даты; USDT не равен 1 USD', () {
    expect(
      parseKrakenUsd(
        fixture('kraken_ohlc.json'),
        DateTime.utc(2026, 1, 10),
        current: false,
      ),
      Decimal.parse('12.34567890123456789'),
    );
    expect(
      parseKrakenUsd(fixture('kraken_ticker.json'), fetched, current: true),
      Decimal.parse('0.9987654321'),
    );
    expect(
      () => parseKrakenUsd(
        fixture('kraken_ohlc.json'),
        DateTime.utc(2020, 1, 1),
        current: false,
      ),
      throwsA(isA<RateFailure>()),
    );
  });
  test('Лексемы JSON: строки/escape не меняются, экспонента десятичная', () {
    final data = decodeExactJson(
      r'{"text":"12.34 and \"hi\"","value":1.234567890123456789e-2}',
    ) as Map;
    expect(data['text'], '12.34 and "hi"');
    expect(
      positiveRate(data['value']),
      Decimal.parse('0.01234567890123456789'),
    );
    expect(() => positiveRate('1e99'), throwsA(isA<RateFailure>()));
    expect(() => positiveRate('-1'), throwsA(isA<RateFailure>()));
    expect(() => decodeExactJson('{"a":01}'), throwsA(isA<RateFailure>()));
  });
  test(
    'Транспорт не обращается к посторонним адресам и незашифрованному HTTP',
    () async {
      final transport = SourceHttpTransport();
      addTearDown(transport.close);
      for (final url in [
        'https://example.org/',
        'http://www.cbr.ru/',
        'https://user@www.cbr.ru/',
        'https://www.cbr.ru:8443/',
      ]) {
        await expectLater(
          transport.get(Uri.parse(url)),
          throwsA(isA<RateFailure>()),
        );
      }
    },
  );
}

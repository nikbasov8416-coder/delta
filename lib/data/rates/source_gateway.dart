import 'package:decimal/decimal.dart';
import 'package:xml/xml.dart';

import '../../domain/rates/rates.dart';
import 'exact_json.dart';
import 'transport.dart';

Map<String, RateQuote> parseCbr(
  String body,
  DateTime requested,
  DateTime fetched,
) {
  if (body.contains('<!DOCTYPE')) {
    throw const RateFailure('Неподдерживаемый XML ЦБ');
  }
  try {
    final root = XmlDocument.parse(body).rootElement;
    if (root.name.local != 'ValCurs') {
      throw const RateFailure('Неверный XML ЦБ');
    }
    final parts = (root.getAttribute('Date') ?? '').split('.');
    if (parts.length != 3) throw const RateFailure('ЦБ не указал дату курса');
    final date = DateTime.utc(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
    if (date.isAfter(calendarDay(requested)) ||
        date.day != int.parse(parts[0]) ||
        date.month != int.parse(parts[1])) {
      throw const RateFailure('ЦБ вернул курс не на запрошенную дату');
    }
    final result = <String, RateQuote>{};
    for (final item in root.findElements('Valute')) {
      String text(String name) => item.getElement(name)?.innerText.trim() ?? '';
      final code = text('CharCode');
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) continue;
      final count = int.tryParse(text('Nominal'));
      if (count == null || count <= 0 || count > 1000000000) {
        throw const RateFailure('ЦБ вернул неверный номинал');
      }
      final nominal = Decimal.fromInt(count);
      final value = (positiveRate(text('Value').replaceAll(',', '.')) / nominal)
          .toDecimal(scaleOnInfinitePrecision: 18);
      if (result.containsKey(code)) {
        throw const RateFailure('Дубли валют в ответе ЦБ');
      }
      result[code] = RateQuote(
        code: code,
        date: dayKey(requested),
        value: value,
        source: 'cbr',
        effectiveAt: dayKey(date),
        fetchedAt: fetched.toUtc(),
      );
    }
    return result;
  } on RateFailure {
    rethrow;
  } catch (_) {
    throw const RateFailure('Не удалось разобрать ответ ЦБ');
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const RateFailure('Неверная структура ответа источника');
  }
  return value;
}

const coinIds = {'BTC': 'bitcoin', 'USDT': 'tether'};
const krakenPairs = {'BTC': 'XBTUSD', 'USDT': 'USDTUSD'};

RateQuote parseCoinGeckoHistory(
  String body,
  String code,
  DateTime date,
  DateTime fetched,
) {
  final payload = _map(decodeExactJson(body));
  if (payload['id'] != coinIds[code]) {
    throw const RateFailure('CoinGecko вернул другую валюту');
  }
  final rate = positiveRate(
    _map(_map(payload['market_data'])['current_price'])['rub'],
  );
  return RateQuote(
    code: code,
    date: dayKey(date),
    value: rate,
    source: 'coingecko',
    effectiveAt: calendarDay(date).toIso8601String(),
    fetchedAt: fetched.toUtc(),
  );
}

Map<String, RateQuote> parseCoinGeckoCurrent(
  String body,
  Set<String> codes,
  DateTime date,
  DateTime fetched,
) {
  final payload = _map(decodeExactJson(body));
  final result = <String, RateQuote>{};
  for (final code in codes) {
    final price = _map(payload[coinIds[code]]);
    final stamp = int.tryParse(price['last_updated_at']?.toString() ?? '');
    if (stamp == null) {
      throw const RateFailure('CoinGecko не указал время цены');
    }
    final effective = DateTime.fromMillisecondsSinceEpoch(
      stamp * 1000,
      isUtc: true,
    );
    if (fetched.toUtc().difference(effective) > const Duration(hours: 2) ||
        effective.isAfter(fetched.toUtc().add(const Duration(minutes: 5)))) {
      throw const RateFailure('CoinGecko вернул устаревшую цену');
    }
    result[code] = RateQuote(
      code: code,
      date: dayKey(date),
      value: positiveRate(price['rub']),
      source: 'coingecko',
      effectiveAt: effective.toIso8601String(),
      fetchedAt: fetched.toUtc(),
    );
  }
  return result;
}

Decimal parseKrakenUsd(
  String body,
  DateTime date, {
  required bool current,
  String? expectedCode,
}) {
  final payload = _map(decodeExactJson(body));
  if (payload['error'] is! List || (payload['error'] as List).isNotEmpty) {
    throw const RateFailure('Резервный источник недоступен');
  }
  final result = _map(payload['result']);
  final keys = result.keys.where((key) => key != 'last').toList();
  if (keys.length != 1) {
    throw const RateFailure('Неоднозначная валютная пара резерва');
  }
  if (expectedCode != null) {
    final aliases = expectedCode == 'BTC'
        ? {'XXBTZUSD', 'XBTUSD'}
        : {'USDTZUSD', 'USDTUSD'};
    if (!aliases.contains(keys.single)) {
      throw const RateFailure('Kraken вернул другую валютную пару');
    }
  }
  if (current) {
    final prices = _map(result[keys.single])['c'];
    if (prices is! List || prices.isEmpty) {
      throw const RateFailure('Неверный ответ Kraken');
    }
    return positiveRate(prices.first);
  }
  final rows = result[keys.single];
  if (rows is! List) throw const RateFailure('Неверная история Kraken');
  final target = calendarDay(date).millisecondsSinceEpoch ~/ 1000;
  for (final row in rows) {
    if (row is List &&
        row.length >= 5 &&
        int.tryParse(row[0].toString()) == target) {
      // Открытие дневной свечи = 00:00 UTC, как историческая точка CoinGecko.
      return positiveRate(row[1]);
    }
  }
  throw const RateFailure(
    'В резервном источнике нет нужной даты. Введите курс вручную.',
  );
}

class PublicRateGateway implements RateGateway {
  PublicRateGateway(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final RateTransport transport;
  final DateTime Function() now;
  @override
  Future<RateBatch> fetch(Set<String> codes, DateTime date) async {
    final quotes = <String, RateQuote>{}, errors = <String, String>{};
    final today = dayKey(now());
    if (dayKey(date).compareTo(today) > 0) {
      return RateBatch(
        errors: {
          for (final code in codes)
            code: 'Будущая дата: автоматического курса ещё нет',
        },
      );
    }
    if (codes.contains('RUB')) {
      quotes['RUB'] = RateQuote(
        code: 'RUB',
        date: dayKey(date),
        value: Decimal.one,
        source: 'identity',
        effectiveAt: dayKey(date),
        fetchedAt: now().toUtc(),
      );
    }
    final crypto = codes.where(coinIds.containsKey).toSet();
    final fiat = codes.difference({'RUB', ...crypto});
    Map<String, RateQuote>? cbr;
    Future<Map<String, RateQuote>> loadCbr() async {
      if (cbr != null) return cbr!;
      final query =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      cbr = parseCbr(
        await transport.get(
          Uri.https('www.cbr.ru', '/scripts/XML_daily.asp', {
            'date_req': query,
          }),
        ),
        date,
        now(),
      );
      return cbr!;
    }

    if (fiat.isNotEmpty) {
      try {
        final values = await loadCbr();
        for (final code in fiat) {
          if (values.containsKey(code)) {
            quotes[code] = values[code]!;
          } else {
            errors[code] = 'ЦБ не публикует курс $code. Введите вручную.';
          }
        }
      } catch (e) {
        for (final code in fiat) {
          errors[code] = _error(e);
        }
      }
    }
    if (crypto.isNotEmpty) {
      if (dayKey(date) == today) {
        try {
          final body = await transport.get(
            Uri.https('api.coingecko.com', '/api/v3/simple/price', {
              'ids': crypto.map((c) => coinIds[c]!).join(','),
              'vs_currencies': 'rub',
              'include_last_updated_at': 'true',
            }),
          );
          quotes.addAll(parseCoinGeckoCurrent(body, crypto, date, now()));
        } catch (e) {
          for (final code in crypto) {
            errors[code] = _error(e);
          }
        }
      } else {
        for (final code in crypto) {
          try {
            final formatted =
                '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
            quotes[code] = parseCoinGeckoHistory(
              await transport.get(
                Uri.https(
                  'api.coingecko.com',
                  '/api/v3/coins/${coinIds[code]}/history',
                  {'date': formatted, 'localization': 'false'},
                ),
              ),
              code,
              date,
              now(),
            );
          } catch (e) {
            errors[code] = _error(e);
          }
        }
      }
      for (final code in crypto.where((c) => !quotes.containsKey(c))) {
        final primary = errors[code] ?? 'CoinGecko недоступен';
        try {
          final usd = (await loadCbr())['USD'];
          if (usd == null) {
            throw const RateFailure('Нет USD ЦБ для пересчёта резерва');
          }
          final current = dayKey(date) == today;
          final uri = Uri.https(
            'api.kraken.com',
            current ? '/0/public/Ticker' : '/0/public/OHLC',
            {
              'pair': krakenPairs[code]!,
              if (!current) 'interval': '1440',
              if (!current)
                'since':
                    '${calendarDay(date).millisecondsSinceEpoch ~/ 1000 - 86400}',
            },
          );
          final value =
              parseKrakenUsd(
                await transport.get(uri),
                date,
                current: current,
                expectedCode: code,
              ) *
              usd.value;
          quotes[code] = RateQuote(
            code: code,
            date: dayKey(date),
            value: value,
            source: 'kraken+cbr',
            effectiveAt:
                '${current ? now().toUtc().toIso8601String() : calendarDay(date).toIso8601String()}; USD ЦБ: ${usd.effectiveAt}',
            fetchedAt: now().toUtc(),
          );
          errors.remove(code);
        } catch (e) {
          errors[code] = '$primary; резерв: ${_error(e)}';
        }
      }
    }
    return RateBatch(quotes: quotes, errors: errors);
  }

  String _error(Object error) => error is RateFailure
      ? error.message
      : 'Неверный ответ источника. Введите курс вручную.';
}

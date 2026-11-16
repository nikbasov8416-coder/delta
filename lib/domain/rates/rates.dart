import 'package:decimal/decimal.dart';

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime calendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class RateQuote {
  const RateQuote({
    required this.code,
    required this.date,
    required this.value,
    required this.source,
    required this.effectiveAt,
    required this.fetchedAt,
    this.cached = false,
  });
  final String code, date, source, effectiveAt;
  final Decimal value;
  final DateTime fetchedAt;
  final bool cached;
}

class RateBatch {
  RateBatch({
    Map<String, RateQuote> quotes = const {},
    Map<String, String> errors = const {},
  }) : quotes = Map.unmodifiable(quotes),
       errors = Map.unmodifiable(errors);
  final Map<String, RateQuote> quotes;
  final Map<String, String> errors;
}

abstract interface class RateGateway {
  Future<RateBatch> fetch(Set<String> codes, DateTime date);
}

class RateFailure implements Exception {
  const RateFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String rateSourceLabel(String source) => switch (source) {
  'cbr' => 'ЦБ РФ',
  'coingecko' => 'CoinGecko',
  'kraken+cbr' => 'Kraken × USD ЦБ',
  'identity' => 'Постоянный курс',
  'manual' => 'Вручную',
  _ => 'Неизвестный источник',
};

import 'package:uuid/uuid.dart';

/// Единственный источник засева и сравнения с нетронутыми справочниками.
Map<String, Map<String, Object>> defaultCatalog(String table) {
  const uuid = Uuid();
  if (table == 'currency') {
    return {
      for (final spec in const [
        ('RUB', 'Рубль', 'fiat', 2, 'cbr'),
        ('USD', 'Доллар США', 'fiat', 2, 'cbr'),
        ('EUR', 'Евро', 'fiat', 2, 'cbr'),
        ('CNY', 'Юань', 'fiat', 2, 'cbr'),
        ('BTC', 'Биткоин', 'crypto', 8, 'coingecko'),
        ('USDT', 'Tether', 'crypto', 6, 'coingecko'),
      ])
        uuid.v5(Namespace.url.value, 'delta/currency/${spec.$1}'): {
          'code': spec.$1,
          'name': spec.$2,
          'kind': spec.$3,
          'precision': spec.$4,
          'rate_source': spec.$5,
          'deleted': 0,
        },
    };
  }
  if (table == 'liquidity_level') {
    const names = [
      'Сразу',
      'До недели',
      'Вклады до срока',
      'Инвестиции',
      'Долгосрочные (страхование)',
    ];
    return {
      for (var i = 0; i < names.length; i++)
        uuid.v5(Namespace.url.value, 'delta/liquidity/$i'): {
          'name': names[i],
          'sort_order': i,
          'color': 0xff26a69a + i * 0x00111111,
          'deleted': 0,
        },
    };
  }
  throw ArgumentError('Таблица не относится к засеву');
}

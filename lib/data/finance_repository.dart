import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/finance/finance_repository.dart';
import '../domain/finance/records.dart';
import '../domain/reports/reports.dart';
import '../domain/money/amount.dart';
import '../domain/money/currency.dart' as money;
import '../domain/snapshots/snapshot_totals.dart';
import '../domain/sync/hlc.dart';
import '../domain/rates/rates.dart';
import 'database/app_database.dart';
import 'default_catalog.dart';

class DriftFinanceRepository implements FinanceRepository {
  DriftFinanceRepository(
    this.db,
    this.deviceId, {
    HybridClock? clock,
    this.gateway,
    DateTime Function()? now,
  }) : clock = clock ?? HybridClock(deviceId),
       now = now ?? DateTime.now;
  final AppDatabase db;
  void Function()? onChanged;
  void Function()? onFinalized;
  Future<void> Function()? beforeClose;
  final String deviceId;
  final HybridClock clock;
  final RateGateway? gateway;
  final DateTime Function() now;
  final _rateIssues = <String, Map<String, String>>{};
  static const _uuid = Uuid();
  static const tables = [
    'currency',
    'liquidity_level',
    'storage',
    'storage_currency',
    'snapshot',
    'snapshot_line',
    'snapshot_rate',
    'audit_log',
    'settings',
    'rate_cache',
  ];

  Variable _variable(Object? value) => switch (value) {
    String v => Variable.withString(v),
    int v => Variable.withInt(v),
    null => const Variable<String>(null),
    _ => throw ArgumentError('Тип параметра'),
  };
  Future<List<FinanceRecord>> query(
    String sql, [
    List<Object?> args = const [],
  ]) async =>
      (await db
              .customSelect(sql, variables: args.map(_variable).toList())
              .get())
          .map((row) => FinanceRecord(row.data))
          .toList();
  Future<FinanceRecord> _one(String table, String id) async {
    final rows = await query('SELECT * FROM $table WHERE id=? AND deleted=0', [
      id,
    ]);
    if (rows.length != 1) throw StateError('Запись не найдена');
    return rows.single;
  }

  Map<String, Object?> _stamp() => {
    'updated_at': clock.next(),
    'device_id': deviceId,
  };
  Map<String, Object?> _new([String? id]) => {
    'id': id ?? _uuid.v4(),
    ..._stamp(),
    'deleted': 0,
  };
  Future<void> _insert(
    String table,
    Map<String, Object?> data, {
    bool ignore = false,
  }) async {
    await db.customStatement(
      'INSERT ${ignore ? 'OR IGNORE ' : ''}INTO $table '
      '(${data.keys.join(',')}) VALUES (${List.filled(data.length, '?').join(',')})',
      data.values.toList(),
    );
    onChanged?.call();
  }

  Future<void> _update(
    String table,
    String id,
    Map<String, Object?> data,
  ) async {
    final fields = {...data, ..._stamp()};
    await db.customStatement(
      'UPDATE $table SET ${fields.keys.map((k) => '$k=?').join(',')} WHERE id=?',
      [...fields.values, id],
    );
    onChanged?.call();
  }

  String _required(String value) {
    if (value.trim().isEmpty || value.length > 500) {
      throw const FormatException('Заполните название (до 500 символов)');
    }
    return value.trim();
  }

  void _date(String value) {
    final date = DateTime.tryParse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Дата в формате ГГГГ-ММ-ДД');
    }
  }

  @override
  Future<void> initialize() => db.transaction(() async {
    // После перезапуска ни одна локальная отметка HLC не должна стать старше.
    for (final table in tables) {
      final rows = await query('SELECT max(updated_at) AS stamp FROM $table');
      if (rows.single.text('stamp').isNotEmpty) {
        clock.observe(rows.single.text('stamp'));
      }
    }
    for (final table in ['currency', 'liquidity_level']) {
      for (final entry in defaultCatalog(table).entries) {
        await _insert(table, {
          ..._new(entry.key),
          ...entry.value,
        }, ignore: true);
      }
    }
  });

  @override
  Future<FinanceOverview> overview() async => FinanceOverview(
    currencies: await query(
      'SELECT * FROM currency WHERE deleted=0 ORDER BY code',
    ),
    liquidity: await query(
      'SELECT * FROM liquidity_level WHERE deleted=0 ORDER BY sort_order,name',
    ),
    storages: await query(
      'SELECT s.*,l.name AS liquidity_name FROM storage s JOIN liquidity_level l ON l.id=s.liquidity_id WHERE s.deleted=0 ORDER BY s.archived,s.sort_order,s.name',
    ),
    storageCurrencies: await query(
      'SELECT * FROM storage_currency WHERE deleted=0',
    ),
    snapshots: await query(
      'SELECT * FROM snapshot WHERE deleted=0 ORDER BY date DESC,created_at DESC',
    ),
  );

  @override
  Future<void> saveCurrency({
    String? id,
    required String code,
    required String name,
    required String kind,
    required int precision,
  }) => db.transaction(() async {
    code = code.trim().toUpperCase();
    money.Currency(code, precision);
    const standard = {
      'RUB': 2,
      'USD': 2,
      'EUR': 2,
      'CNY': 2,
      'BTC': 8,
      'USDT': 6,
    };
    if (standard.containsKey(code) &&
        (precision != standard[code] ||
            kind != (['BTC', 'USDT'].contains(code) ? 'crypto' : 'fiat'))) {
      throw const FormatException(
        'Для стандартной валюты нельзя менять вид и точность',
      );
    }
    if (!['fiat', 'crypto'].contains(kind)) {
      throw const FormatException('Вид валюты');
    }
    if (id != null) {
      final old = await _one('currency', id);
      if (standard.containsKey(old.text('code')) && old.text('code') != code) {
        throw StateError('Код стандартной валюты менять нельзя');
      }
      final used = await query(
        'SELECT id FROM snapshot_line WHERE currency_id=? LIMIT 1',
        [id],
      );
      if (used.isNotEmpty &&
          (old.text('code') != code || old.number('precision') != precision)) {
        throw StateError('Код и точность использованной валюты менять нельзя');
      }
      await _update('currency', id, {
        'code': code,
        'name': _required(name),
        'kind': kind,
        'precision': precision,
        'rate_source': kind == 'fiat' ? 'cbr' : 'coingecko',
      });
    } else {
      await _insert('currency', {
        ..._new(),
        'code': code,
        'name': _required(name),
        'kind': kind,
        'precision': precision,
        'rate_source': kind == 'fiat' ? 'cbr' : 'coingecko',
      });
    }
  });

  @override
  Future<void> saveLiquidity({
    String? id,
    required String name,
    required int order,
    required int color,
  }) async {
    final fields = {
      'name': _required(name),
      'sort_order': order,
      'color': color,
    };
    if (id == null) {
      await _insert('liquidity_level', {..._new(), ...fields});
    } else {
      await _one('liquidity_level', id);
      await _update('liquidity_level', id, fields);
    }
  }

  @override
  Future<void> removeCatalogEntry(String catalog, String id) =>
      db.transaction(() async {
        if (!['currency', 'liquidity_level'].contains(catalog)) {
          throw ArgumentError('Справочник');
        }
        await _one(catalog, id);
        final checks = catalog == 'currency'
            ? [
                ('storage_currency', 'currency_id'),
                ('snapshot_line', 'currency_id'),
                ('snapshot_rate', 'currency_id'),
              ]
            : [('storage', 'liquidity_id'), ('snapshot_line', 'liquidity_id')];
        for (final check in checks) {
          if ((await query(
            'SELECT id FROM ${check.$1} WHERE ${check.$2}=? LIMIT 1',
            [id],
          )).isNotEmpty) {
            throw StateError(
              'Запись используется; удаление запрещено для сохранения истории',
            );
          }
        }
        await _update(catalog, id, {'deleted': 1});
      });

  @override
  Future<void> saveStorage({
    String? id,
    required String name,
    required String type,
    required String liquidityId,
    required String organization,
    required String note,
    required bool archived,
    required List<String> currencyIds,
  }) => db.transaction(() async {
    if (currencyIds.isEmpty) throw StateError('Выберите хотя бы одну валюту');
    const types = [
      'account',
      'card',
      'cash',
      'deposit',
      'broker',
      'crypto',
      'insurance',
      'other',
    ];
    if (!types.contains(type)) throw ArgumentError('Тип места хранения');
    await _one('liquidity_level', liquidityId);
    for (final currency in currencyIds) {
      await _one('currency', currency);
    }
    final fields = {
      'name': _required(name),
      'type': type,
      'liquidity_id': liquidityId,
      'organization': organization.trim(),
      'note': note.trim(),
      'archived': archived ? 1 : 0,
    };
    final target = id ?? _uuid.v4();
    if (id == null) {
      await _insert('storage', {..._new(target), ...fields});
    } else {
      await _one('storage', id);
      await _update('storage', id, fields);
    }
    final old = await query(
      'SELECT * FROM storage_currency WHERE storage_id=?',
      [target],
    );
    for (final pair in old) {
      await _update('storage_currency', pair.id, {
        'active': currencyIds.contains(pair.text('currency_id')) ? 1 : 0,
      });
    }
    for (final currency in currencyIds.toSet()) {
      if (!old.any((p) => p.text('currency_id') == currency)) {
        await _insert('storage_currency', {
          ..._new(),
          'storage_id': target,
          'currency_id': currency,
          'active': 1,
        });
      }
    }
  });

  @override
  Future<String> createSnapshot(String date, String note) async {
    final id = await _createSnapshot(date, note);
    if (gateway != null) await refreshSnapshotRates(id, force: false);
    return id;
  }

  Future<String> _createSnapshot(String date, String note) => db.transaction(
    () async {
      _date(date);
      final id = _uuid.v4();
      // Последний слепок на выбранную дату: будущие значения не копируем назад.
      final previous = await query(
        "SELECT id FROM snapshot WHERE deleted=0 AND status='fixed' AND date<=? ORDER BY date DESC,created_at DESC LIMIT 1",
        [date],
      );
      await _insert('snapshot', {
        ..._new(id),
        'date': date,
        'note': note.trim(),
        'status': 'draft',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final pairs = await query(
        'SELECT sc.*,s.liquidity_id FROM storage_currency sc JOIN storage s ON s.id=sc.storage_id JOIN currency c ON c.id=sc.currency_id WHERE sc.deleted=0 AND sc.active=1 AND s.deleted=0 AND s.archived=0 AND c.deleted=0',
      );
      if (pairs.isEmpty) {
        throw StateError('Сначала добавьте место хранения и валюту');
      }
      for (final pair in pairs) {
        final old = previous.isEmpty
            ? <FinanceRecord>[]
            : await query(
                'SELECT * FROM snapshot_line WHERE snapshot_id=? AND storage_id=? AND currency_id=? AND deleted=0',
                [
                  previous.single.id,
                  pair.text('storage_id'),
                  pair.text('currency_id'),
                ],
              );
        await _insert('snapshot_line', {
          ..._new(),
          'snapshot_id': id,
          'storage_id': pair.text('storage_id'),
          'currency_id': pair.text('currency_id'),
          'liquidity_id': pair.text('liquidity_id'),
          'amount': old.isEmpty ? null : old.single.values['amount'],
          'family_amount': old.isEmpty ? '0' : old.single.text('family_amount'),
          'note': old.isEmpty ? '' : old.single.text('note'),
          'confirmed': 0,
        });
      }
      return id;
    },
  );

  @override
  Future<SnapshotDetail> snapshot(String id) async => SnapshotDetail(
    await _one('snapshot', id),
    await query(
      'SELECT sl.*,s.name AS storage_name,c.code,c.precision,l.name AS liquidity_name,l.sort_order AS liquidity_order FROM snapshot_line sl JOIN storage s ON s.id=sl.storage_id JOIN currency c ON c.id=sl.currency_id JOIN liquidity_level l ON l.id=sl.liquidity_id WHERE sl.snapshot_id=? AND sl.deleted=0 ORDER BY l.sort_order,s.sort_order,s.name,c.code',
      [id],
    ),
    await query(
      'SELECT sr.*,c.code FROM snapshot_rate sr JOIN currency c ON c.id=sr.currency_id WHERE sr.snapshot_id=? AND sr.deleted=0 ORDER BY c.code',
      [id],
    ),
    await query(
      'SELECT * FROM audit_log WHERE snapshot_id=? AND deleted=0 ORDER BY updated_at DESC',
      [id],
    ),
    rateErrors: Map.unmodifiable(_rateIssues[id] ?? {}),
  );

  Future<void> _audit(
    FinanceRecord header,
    String type,
    String entityId,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async {
    if (header.text('status') != 'fixed' ||
        jsonEncode(before) == jsonEncode(after)) {
      return;
    }
    await _insert('audit_log', {
      ..._new(),
      'snapshot_id': header.id,
      'entity_type': type,
      'entity_id': entityId,
      'operation': 'update',
      'old_value': jsonEncode(before),
      'new_value': jsonEncode(after),
      'changed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> saveLine(String id, String amount, String family, String note) =>
      db.transaction(() async {
        final line = await _one('snapshot_line', id);
        final currency = await _one('currency', line.text('currency_id'));
        final spec = money.Currency(
          currency.text('code'),
          currency.number('precision'),
        );
        final value = parseAmount(amount, spec);
        final familyValue = parseAmount(family, spec);
        if (familyValue > value) {
          throw const FormatException(
            'Семейная часть не может превышать сумму',
          );
        }
        final header = await _one('snapshot', line.text('snapshot_id'));
        final fields = {
          'amount': value.toString(),
          'family_amount': familyValue.toString(),
          'note': note.trim(),
          'confirmed': 1,
        };
        await _audit(header, 'snapshot_line', id, {
          for (final key in fields.keys) key: line.values[key],
        }, fields);
        await _update('snapshot_line', id, fields);
        await _update('snapshot', header.id, {});
      });

  @override
  Future<void> addSnapshotCurrency(
    String snapshotId,
    String storageId,
    String currencyId,
  ) async {
    await _addSnapshotCurrency(snapshotId, storageId, currencyId);
    if (gateway != null) await refreshSnapshotRates(snapshotId, force: false);
  }

  Future<void> _addSnapshotCurrency(
    String snapshotId,
    String storageId,
    String currencyId,
  ) => db.transaction(() async {
    final header = await _one('snapshot', snapshotId);
    if (header.text('status') != 'draft') {
      throw StateError('Добавить валюту можно в черновике');
    }
    await _one('currency', currencyId);
    final storage = await _one('storage', storageId);
    final existing = await query(
      'SELECT id FROM snapshot_line WHERE snapshot_id=? AND storage_id=? AND currency_id=?',
      [snapshotId, storageId, currencyId],
    );
    if (existing.isNotEmpty) throw StateError('Эта валюта уже есть в слепке');
    final pair = await query(
      'SELECT * FROM storage_currency WHERE storage_id=? AND currency_id=?',
      [storageId, currencyId],
    );
    if (pair.isEmpty) {
      await _insert('storage_currency', {
        ..._new(),
        'storage_id': storageId,
        'currency_id': currencyId,
        'active': 1,
      });
    } else {
      await _update('storage_currency', pair.single.id, {
        'active': 1,
        'deleted': 0,
      });
    }
    final sameStorage = await query(
      'SELECT liquidity_id FROM snapshot_line WHERE snapshot_id=? AND storage_id=? LIMIT 1',
      [snapshotId, storageId],
    );
    await _insert('snapshot_line', {
      ..._new(),
      'snapshot_id': snapshotId,
      'storage_id': storageId,
      'currency_id': currencyId,
      'liquidity_id': sameStorage.isEmpty
          ? storage.text('liquidity_id')
          : sameStorage.single.text('liquidity_id'),
      'family_amount': '0',
      'confirmed': 0,
    });
    await _update('snapshot', snapshotId, {});
  });

  @override
  Future<void> saveRate(
    String snapshotId,
    String currencyId,
    String value,
  ) async {
    final header = await _one('snapshot', snapshotId);
    final currency = await _one('currency', currencyId);
    await _writeRate(
      snapshotId,
      currencyId,
      RateQuote(
        code: currency.text('code'),
        date: header.text('date'),
        value: Decimal.parse(normalizeNumberInput(value)),
        source: currency.text('code') == 'RUB' ? 'identity' : 'manual',
        effectiveAt: header.text('date'),
        fetchedAt: now().toUtc(),
      ),
    );
    _rateIssues[snapshotId]?.remove(currency.text('code'));
  }

  Future<void> _writeRate(
    String snapshotId,
    String currencyId,
    RateQuote quote,
  ) => db.transaction(() async {
    final header = await _one('snapshot', snapshotId);
    final currency = await _one('currency', currencyId);
    final rate = quote.value;
    if (rate <= Decimal.zero ||
        (currency.text('code') == 'RUB' && rate != Decimal.one)) {
      throw const FormatException(
        'Курс должен быть положительным; для RUB равен 1',
      );
    }
    final used = await query(
      'SELECT id FROM snapshot_line WHERE snapshot_id=? AND currency_id=? AND deleted=0 LIMIT 1',
      [snapshotId, currencyId],
    );
    if (used.isEmpty) throw StateError('Валюты нет в слепке');
    final old = await query(
      'SELECT * FROM snapshot_rate WHERE snapshot_id=? AND currency_id=?',
      [snapshotId, currencyId],
    );
    final target = old.isEmpty ? _uuid.v4() : old.single.id;
    final fields = {
      'rate': rate.toString(),
      'source': quote.source,
      'fetched_at': quote.fetchedAt.toUtc().toIso8601String(),
      'rate_date': quote.date,
      'effective_at': quote.effectiveAt,
    };
    await _audit(
      header,
      'snapshot_rate',
      target,
      old.isEmpty
          ? {}
          : {for (final key in fields.keys) key: old.single.values[key]},
      fields,
    );
    if (old.isEmpty) {
      await _insert('snapshot_rate', {
        ..._new(target),
        'snapshot_id': snapshotId,
        'currency_id': currencyId,
        ...fields,
      });
    } else {
      await _update('snapshot_rate', target, fields);
    }
    await _update('snapshot', snapshotId, {});
  });

  @override
  Future<void> saveSnapshotHeader(String id, String date, String note) async {
    final old = await _one('snapshot', id);
    await _saveSnapshotHeader(id, date, note);
    if (old.text('date') != date &&
        old.text('status') == 'draft' &&
        gateway != null) {
      await refreshSnapshotRates(id, force: false);
    }
  }

  Future<void> _saveSnapshotHeader(String id, String date, String note) =>
      db.transaction(() async {
        _date(date);
        final old = await _one('snapshot', id);
        final fields = {'date': date, 'note': note.trim()};
        await _audit(old, 'snapshot', id, {
          'date': old.text('date'),
          'note': old.text('note'),
        }, fields);
        await _update('snapshot', id, fields);
      });

  @override
  Future<void> finalizeSnapshot(String id) async {
    await db.transaction(() async {
      final detail = await snapshot(id);
      if (detail.header.text('status') != 'draft') {
        throw StateError('Слепок уже зафиксирован');
      }
      if (detail.lines.isEmpty ||
          detail.lines.any(
            (l) => !l.flag('confirmed') || l.values['amount'] == null,
          )) {
        throw StateError('Подтвердите суммы во всех строках');
      }
      for (final line in detail.lines) {
        if (line.text('code') == 'RUB' &&
            !detail.rates.any(
              (r) => r.text('currency_id') == line.text('currency_id'),
            )) {
          await saveRate(id, line.text('currency_id'), '1');
        }
      }
      await totals(
        id,
      ); // Отсутствие любого курса не позволяет зафиксировать слепок.
      await _update('snapshot', id, {'status': 'fixed'});
    });
    onFinalized?.call();
  }

  @override
  Future<SnapshotTotals> totals(String id) async =>
      (await valuation(id)).totals;

  @override
  Future<void> confirmLine(String id) => db.transaction(() async {
    final line = await _one('snapshot_line', id);
    final header = await _one('snapshot', line.text('snapshot_id'));
    if (header.text('status') != 'draft') {
      throw StateError('Слепок уже зафиксирован');
    }
    if (line.values['amount'] == null) {
      throw StateError('Сначала заполните сумму');
    }
    if (!line.flag('confirmed')) {
      await _update('snapshot_line', id, {'confirmed': 1});
      await _update('snapshot', header.id, {});
    }
  });

  @override
  Future<int> confirmUnreviewed(String snapshotId) => db.transaction(() async {
    final header = await _one('snapshot', snapshotId);
    if (header.text('status') != 'draft') {
      throw StateError('Слепок уже зафиксирован');
    }
    final lines = await query(
      'SELECT id FROM snapshot_line WHERE snapshot_id=? AND deleted=0 AND confirmed=0 AND amount IS NOT NULL',
      [snapshotId],
    );
    for (final line in lines) {
      await _update('snapshot_line', line.id, {'confirmed': 1});
    }
    if (lines.isNotEmpty) await _update('snapshot', snapshotId, {});
    return lines.length;
  });

  RateQuote _storedQuote(
    FinanceRecord row,
    String date, {
    bool cached = false,
  }) => RateQuote(
    code: row.text('code'),
    date: date,
    value: row.decimal('rate'),
    source: row.text('source'),
    effectiveAt: row.text('effective_at'),
    fetchedAt: DateTime.parse(row.text('fetched_at')),
    cached: cached,
  );

  Future<RateBatch> _obtainRates(
    Set<String> codes,
    DateTime date, {
    required bool force,
  }) async {
    final result = <String, RateQuote>{}, errors = <String, String>{};
    final dateString = dayKey(date), today = dayKey(now());
    if (codes.contains('RUB')) {
      result['RUB'] = RateQuote(
        code: 'RUB',
        date: dateString,
        value: Decimal.one,
        source: 'identity',
        effectiveAt: dateString,
        fetchedAt: now().toUtc(),
      );
    }
    if (!force) {
      for (final code in codes.difference({'RUB'})) {
        final cached = await query(
          'SELECT rc.*,c.code FROM rate_cache rc JOIN currency c ON c.id=rc.currency_id WHERE c.code=? AND rc.date=? AND rc.deleted=0 ORDER BY CASE rc.source WHEN \'coingecko\' THEN 0 WHEN \'cbr\' THEN 0 ELSE 1 END,rc.fetched_at DESC',
          [code, dateString],
        );
        for (final row in cached) {
          if (row.text('fetched_at').isEmpty ||
              row.text('effective_at').isEmpty) {
            continue;
          }
          final source = row.text('source');
          if (!(['BTC', 'USDT'].contains(code)
                  ? ['coingecko', 'kraken+cbr']
                  : ['cbr'])
              .contains(source)) {
            continue;
          }
          try {
            final quote = _storedQuote(row, dateString, cached: true);
            final age = now().toUtc().difference(quote.fetchedAt.toUtc());
            if (dateString == today &&
                (age > const Duration(minutes: 15) ||
                    age < const Duration(minutes: -5))) {
              continue;
            }
            result[code] = quote;
            break;
          } catch (_) {
            continue;
          }
        }
      }
    }
    final missing = codes.difference(result.keys.toSet());
    if (missing.isNotEmpty) {
      if (gateway == null) {
        for (final code in missing) {
          errors[code] =
              'Автоматический источник не подключён. Введите курс вручную.';
        }
      } else {
        RateBatch fetched;
        try {
          fetched = await gateway!.fetch(missing, date);
        } catch (_) {
          fetched = RateBatch(
            errors: {
              for (final code in missing)
                code: 'Не удалось получить курс. Введите вручную.',
            },
          );
        }
        errors.addAll(fetched.errors);
        for (final code in missing) {
          final quote = fetched.quotes[code];
          final validSource = ['BTC', 'USDT'].contains(code)
              ? ['coingecko', 'kraken+cbr']
              : ['cbr'];
          if (quote == null) {
            errors.putIfAbsent(
              code,
              () => 'Источник не вернул курс. Введите вручную.',
            );
            continue;
          }
          if (quote.code != code ||
              quote.date != dateString ||
              quote.value <= Decimal.zero ||
              !validSource.contains(quote.source) ||
              quote.effectiveAt.isEmpty) {
            errors[code] =
                'Источник вернул курс другой даты или неверное значение';
            continue;
          }
          result[code] = quote;
          errors.remove(code);
        }
        // Сохраняем только проверенные ответы, а не ручные курсы и не ошибки.
        await db.transaction(() async {
          for (final code in missing.where(result.containsKey)) {
            final quote = result[code]!;
            final currency = (await query(
              'SELECT id FROM currency WHERE code=? AND deleted=0',
              [code],
            )).single;
            final old = await query(
              'SELECT id FROM rate_cache WHERE currency_id=? AND date=? AND source=?',
              [currency.id, dateString, quote.source],
            );
            final fields = {
              'rate': quote.value.toString(),
              'fetched_at': quote.fetchedAt.toUtc().toIso8601String(),
              'effective_at': quote.effectiveAt,
            };
            if (old.isEmpty) {
              await _insert('rate_cache', {
                ..._new(),
                'currency_id': currency.id,
                'date': dateString,
                'source': quote.source,
                ...fields,
              });
            } else {
              await _update('rate_cache', old.single.id, {
                ...fields,
                'deleted': 0,
              });
            }
          }
        });
      }
    }
    return RateBatch(quotes: result, errors: errors);
  }

  @override
  Future<RateBatch> refreshSnapshotRates(String id, {bool force = true}) async {
    final before = await snapshot(id), date = before.header.text('date');
    final codes = before.lines.map((l) => l.text('code')).toSet();
    final preserved = <String, RateQuote>{};
    if (!force) {
      for (final row in before.rates) {
        if (row.text('source') == 'manual' && row.text('rate_date') == date) {
          preserved[row.text('code')] = _storedQuote(row, date);
        }
      }
    }
    final fetched = await _obtainRates(
      codes.difference(preserved.keys.toSet()),
      DateTime.parse(date),
      force: force,
    );
    final batch = RateBatch(
      quotes: {...fetched.quotes, ...preserved},
      errors: fetched.errors,
    );
    await db.transaction(() async {
      final header = await _one('snapshot', id);
      if (header.text('date') != date ||
          header.text('updated_at') != before.header.text('updated_at')) {
        throw StateError(
          'Слепок изменился во время загрузки. Повторите обновление курсов.',
        );
      }
      for (final quote in batch.quotes.values) {
        final line = before.lines.firstWhere(
          (l) => l.text('code') == quote.code,
        );
        await _writeRate(id, line.text('currency_id'), quote);
      }
    });
    _rateIssues[id] = Map.of(batch.errors);
    return batch;
  }

  @override
  Future<SnapshotValuation> valuation(
    String id, {
    bool today = false,
    bool force = false,
  }) async {
    final detail = await snapshot(id);
    if (detail.lines.any((l) => l.values['amount'] == null)) {
      throw StateError('Не все суммы заполнены');
    }
    final codes = detail.lines.map((l) => l.text('code')).toSet();
    final quotes = <String, RateQuote>{};
    if (today) {
      final batch = await _obtainRates(codes, calendarDay(now()), force: force);
      if (batch.errors.isNotEmpty) {
        throw StateError(
          'Сегодняшняя оценка недоступна: ${batch.errors.entries.map((e) => '${e.key}: ${e.value}').join('; ')} Переключитесь на курс слепка.',
        );
      }
      quotes.addAll(batch.quotes);
    } else {
      final date = detail.header.text('date');
      for (final row in detail.rates) {
        if (row.text('code') == 'RUB') continue;
        if (row.text('rate_date') != date) {
          throw StateError(
            'Дата слепка изменилась. Обновите курсы или введите их вручную.',
          );
        }
        quotes[row.text('code')] = _storedQuote(row, date);
      }
      quotes['RUB'] = RateQuote(
        code: 'RUB',
        date: date,
        value: Decimal.one,
        source: 'identity',
        effectiveAt: date,
        fetchedAt: now().toUtc(),
      );
    }
    final totals = calculateTotals(
      detail.lines.map(
        (line) => SnapshotPosition(
          storageId: line.text('storage_id'),
          currencyCode: line.text('code'),
          liquidityId: line.text('liquidity_id'),
          amount: line.decimal('amount'),
          familyAmount: line.decimal('family_amount'),
        ),
      ),
      {for (final quote in quotes.values) quote.code: quote.value},
    );
    return SnapshotValuation(totals, [
      for (final code in codes)
        if (quotes.containsKey(code)) quotes[code]!,
    ]);
  }

  @override
  Future<List<ReportSnapshot>> reportSnapshots() async {
    final result = <ReportSnapshot>[];
    final headers = await query(
      "SELECT * FROM snapshot WHERE status='fixed' AND deleted=0 ORDER BY date,created_at,id",
    );
    for (final header in headers) {
      final lines = await query(
        'SELECT sl.*,s.name AS storage_name,s.liquidity_id AS current_liquidity_id,l.name AS liquidity_name,l.sort_order AS liquidity_order,l.color AS liquidity_color,c.code,c.precision FROM snapshot_line sl JOIN storage s ON s.id=sl.storage_id JOIN liquidity_level l ON l.id=s.liquidity_id JOIN currency c ON c.id=sl.currency_id WHERE sl.snapshot_id=? AND sl.deleted=0 ORDER BY sl.id',
        [header.id],
      );
      final rates = await query(
        'SELECT sr.*,c.code FROM snapshot_rate sr JOIN currency c ON c.id=sr.currency_id WHERE sr.snapshot_id=? AND sr.deleted=0',
        [header.id],
      );
      for (final row in rates) {
        if (row.text('code') != 'RUB' &&
            row.text('rate_date') != header.text('date')) {
          throw StateError('Дата слепка изменилась. Обновите его курсы.');
        }
      }
      final report = ReportSnapshot(
        id: header.id,
        date: header.text('date'),
        positions: [
          for (final row in lines)
            ReportPosition(
              storageId: row.text('storage_id'),
              storageName: row.text('storage_name'),
              currency: row.text('code'),
              precision: row.number('precision'),
              liquidityId: row.text('current_liquidity_id'),
              liquidityName: row.text('liquidity_name'),
              liquidityOrder: row.number('liquidity_order'),
              liquidityColor: row.number('liquidity_color'),
              amount: row.decimal('amount'),
              family: row.decimal('family_amount'),
            ),
        ],
        rates: {for (final r in rates) r.text('code'): r.decimal('rate')},
      );
      report.totals;
      result.add(report);
    }
    return result;
  }

  @override
  Future<void> close() async {
    await beforeClose?.call();
    await db.close();
  }
}

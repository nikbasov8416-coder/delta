// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class Currency extends Table with TableInfo<Currency, CurrencyData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Currency(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'fiat\', \'crypto\'))',
  );
  static const VerificationMeta _precisionMeta = const VerificationMeta(
    'precision',
  );
  late final GeneratedColumn<int> precision = GeneratedColumn<int>(
    'precision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (precision BETWEEN 0 AND 18)',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _rateSourceMeta = const VerificationMeta(
    'rateSource',
  );
  late final GeneratedColumn<String> rateSource = GeneratedColumn<String>(
    'rate_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    code,
    kind,
    precision,
    name,
    rateSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currency';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurrencyData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('precision')) {
      context.handle(
        _precisionMeta,
        precision.isAcceptableOrUnknown(data['precision']!, _precisionMeta),
      );
    } else if (isInserting) {
      context.missing(_precisionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('rate_source')) {
      context.handle(
        _rateSourceMeta,
        rateSource.isAcceptableOrUnknown(data['rate_source']!, _rateSourceMeta),
      );
    } else if (isInserting) {
      context.missing(_rateSourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CurrencyData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrencyData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      precision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}precision'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rateSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_source'],
      )!,
    );
  }

  @override
  Currency createAlias(String alias) {
    return Currency(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CurrencyData extends DataClass implements Insertable<CurrencyData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String code;
  final String kind;
  final int precision;
  final String name;
  final String rateSource;
  const CurrencyData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.code,
    required this.kind,
    required this.precision,
    required this.name,
    required this.rateSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['code'] = Variable<String>(code);
    map['kind'] = Variable<String>(kind);
    map['precision'] = Variable<int>(precision);
    map['name'] = Variable<String>(name);
    map['rate_source'] = Variable<String>(rateSource);
    return map;
  }

  CurrencyCompanion toCompanion(bool nullToAbsent) {
    return CurrencyCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      code: Value(code),
      kind: Value(kind),
      precision: Value(precision),
      name: Value(name),
      rateSource: Value(rateSource),
    );
  }

  factory CurrencyData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrencyData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      code: serializer.fromJson<String>(json['code']),
      kind: serializer.fromJson<String>(json['kind']),
      precision: serializer.fromJson<int>(json['precision']),
      name: serializer.fromJson<String>(json['name']),
      rateSource: serializer.fromJson<String>(json['rate_source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'code': serializer.toJson<String>(code),
      'kind': serializer.toJson<String>(kind),
      'precision': serializer.toJson<int>(precision),
      'name': serializer.toJson<String>(name),
      'rate_source': serializer.toJson<String>(rateSource),
    };
  }

  CurrencyData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? code,
    String? kind,
    int? precision,
    String? name,
    String? rateSource,
  }) => CurrencyData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    code: code ?? this.code,
    kind: kind ?? this.kind,
    precision: precision ?? this.precision,
    name: name ?? this.name,
    rateSource: rateSource ?? this.rateSource,
  );
  CurrencyData copyWithCompanion(CurrencyCompanion data) {
    return CurrencyData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      code: data.code.present ? data.code.value : this.code,
      kind: data.kind.present ? data.kind.value : this.kind,
      precision: data.precision.present ? data.precision.value : this.precision,
      name: data.name.present ? data.name.value : this.name,
      rateSource: data.rateSource.present
          ? data.rateSource.value
          : this.rateSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrencyData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('code: $code, ')
          ..write('kind: $kind, ')
          ..write('precision: $precision, ')
          ..write('name: $name, ')
          ..write('rateSource: $rateSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    code,
    kind,
    precision,
    name,
    rateSource,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrencyData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.code == this.code &&
          other.kind == this.kind &&
          other.precision == this.precision &&
          other.name == this.name &&
          other.rateSource == this.rateSource);
}

class CurrencyCompanion extends UpdateCompanion<CurrencyData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> code;
  final Value<String> kind;
  final Value<int> precision;
  final Value<String> name;
  final Value<String> rateSource;
  final Value<int> rowid;
  const CurrencyCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.code = const Value.absent(),
    this.kind = const Value.absent(),
    this.precision = const Value.absent(),
    this.name = const Value.absent(),
    this.rateSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrencyCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String code,
    required String kind,
    required int precision,
    required String name,
    required String rateSource,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       code = Value(code),
       kind = Value(kind),
       precision = Value(precision),
       name = Value(name),
       rateSource = Value(rateSource);
  static Insertable<CurrencyData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? code,
    Expression<String>? kind,
    Expression<int>? precision,
    Expression<String>? name,
    Expression<String>? rateSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (code != null) 'code': code,
      if (kind != null) 'kind': kind,
      if (precision != null) 'precision': precision,
      if (name != null) 'name': name,
      if (rateSource != null) 'rate_source': rateSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrencyCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? code,
    Value<String>? kind,
    Value<int>? precision,
    Value<String>? name,
    Value<String>? rateSource,
    Value<int>? rowid,
  }) {
    return CurrencyCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      code: code ?? this.code,
      kind: kind ?? this.kind,
      precision: precision ?? this.precision,
      name: name ?? this.name,
      rateSource: rateSource ?? this.rateSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (precision.present) {
      map['precision'] = Variable<int>(precision.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rateSource.present) {
      map['rate_source'] = Variable<String>(rateSource.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrencyCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('code: $code, ')
          ..write('kind: $kind, ')
          ..write('precision: $precision, ')
          ..write('name: $name, ')
          ..write('rateSource: $rateSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LiquidityLevel extends Table
    with TableInfo<LiquidityLevel, LiquidityLevelData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LiquidityLevel(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    name,
    sortOrder,
    color,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'liquidity_level';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiquidityLevelData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LiquidityLevelData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiquidityLevelData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
    );
  }

  @override
  LiquidityLevel createAlias(String alias) {
    return LiquidityLevel(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LiquidityLevelData extends DataClass
    implements Insertable<LiquidityLevelData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String name;
  final int sortOrder;
  final int color;
  const LiquidityLevelData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.name,
    required this.sortOrder,
    required this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['color'] = Variable<int>(color);
    return map;
  }

  LiquidityLevelCompanion toCompanion(bool nullToAbsent) {
    return LiquidityLevelCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      name: Value(name),
      sortOrder: Value(sortOrder),
      color: Value(color),
    );
  }

  factory LiquidityLevelData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiquidityLevelData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      color: serializer.fromJson<int>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'name': serializer.toJson<String>(name),
      'sort_order': serializer.toJson<int>(sortOrder),
      'color': serializer.toJson<int>(color),
    };
  }

  LiquidityLevelData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? name,
    int? sortOrder,
    int? color,
  }) => LiquidityLevelData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    color: color ?? this.color,
  );
  LiquidityLevelData copyWithCompanion(LiquidityLevelCompanion data) {
    return LiquidityLevelData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiquidityLevelData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, updatedAt, deviceId, deleted, name, sortOrder, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiquidityLevelData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.color == this.color);
}

class LiquidityLevelCompanion extends UpdateCompanion<LiquidityLevelData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> color;
  final Value<int> rowid;
  const LiquidityLevelCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LiquidityLevelCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    required int color,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       name = Value(name),
       color = Value(color);
  static Insertable<LiquidityLevelData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LiquidityLevelCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? color,
    Value<int>? rowid,
  }) {
    return LiquidityLevelCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiquidityLevelCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Storage extends Table with TableInfo<Storage, StorageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Storage(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _liquidityIdMeta = const VerificationMeta(
    'liquidityId',
  );
  late final GeneratedColumn<String> liquidityId = GeneratedColumn<String>(
    'liquidity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES liquidity_level(id)',
  );
  static const VerificationMeta _organizationMeta = const VerificationMeta(
    'organization',
  );
  late final GeneratedColumn<String> organization = GeneratedColumn<String>(
    'organization',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  late final GeneratedColumn<int> archived = GeneratedColumn<int>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    name,
    type,
    liquidityId,
    organization,
    note,
    archived,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('liquidity_id')) {
      context.handle(
        _liquidityIdMeta,
        liquidityId.isAcceptableOrUnknown(
          data['liquidity_id']!,
          _liquidityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_liquidityIdMeta);
    }
    if (data.containsKey('organization')) {
      context.handle(
        _organizationMeta,
        organization.isAcceptableOrUnknown(
          data['organization']!,
          _organizationMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StorageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      liquidityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}liquidity_id'],
      )!,
      organization: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  Storage createAlias(String alias) {
    return Storage(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class StorageData extends DataClass implements Insertable<StorageData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String name;
  final String type;
  final String liquidityId;
  final String organization;
  final String note;
  final int archived;
  final int sortOrder;
  const StorageData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.name,
    required this.type,
    required this.liquidityId,
    required this.organization,
    required this.note,
    required this.archived,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['liquidity_id'] = Variable<String>(liquidityId);
    map['organization'] = Variable<String>(organization);
    map['note'] = Variable<String>(note);
    map['archived'] = Variable<int>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  StorageCompanion toCompanion(bool nullToAbsent) {
    return StorageCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      name: Value(name),
      type: Value(type),
      liquidityId: Value(liquidityId),
      organization: Value(organization),
      note: Value(note),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
    );
  }

  factory StorageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      liquidityId: serializer.fromJson<String>(json['liquidity_id']),
      organization: serializer.fromJson<String>(json['organization']),
      note: serializer.fromJson<String>(json['note']),
      archived: serializer.fromJson<int>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'liquidity_id': serializer.toJson<String>(liquidityId),
      'organization': serializer.toJson<String>(organization),
      'note': serializer.toJson<String>(note),
      'archived': serializer.toJson<int>(archived),
      'sort_order': serializer.toJson<int>(sortOrder),
    };
  }

  StorageData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? name,
    String? type,
    String? liquidityId,
    String? organization,
    String? note,
    int? archived,
    int? sortOrder,
  }) => StorageData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    type: type ?? this.type,
    liquidityId: liquidityId ?? this.liquidityId,
    organization: organization ?? this.organization,
    note: note ?? this.note,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  StorageData copyWithCompanion(StorageCompanion data) {
    return StorageData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      liquidityId: data.liquidityId.present
          ? data.liquidityId.value
          : this.liquidityId,
      organization: data.organization.present
          ? data.organization.value
          : this.organization,
      note: data.note.present ? data.note.value : this.note,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('liquidityId: $liquidityId, ')
          ..write('organization: $organization, ')
          ..write('note: $note, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    name,
    type,
    liquidityId,
    organization,
    note,
    archived,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.name == this.name &&
          other.type == this.type &&
          other.liquidityId == this.liquidityId &&
          other.organization == this.organization &&
          other.note == this.note &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder);
}

class StorageCompanion extends UpdateCompanion<StorageData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> name;
  final Value<String> type;
  final Value<String> liquidityId;
  final Value<String> organization;
  final Value<String> note;
  final Value<int> archived;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const StorageCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.liquidityId = const Value.absent(),
    this.organization = const Value.absent(),
    this.note = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String name,
    required String type,
    required String liquidityId,
    this.organization = const Value.absent(),
    this.note = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       name = Value(name),
       type = Value(type),
       liquidityId = Value(liquidityId);
  static Insertable<StorageData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? liquidityId,
    Expression<String>? organization,
    Expression<String>? note,
    Expression<int>? archived,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (liquidityId != null) 'liquidity_id': liquidityId,
      if (organization != null) 'organization': organization,
      if (note != null) 'note': note,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? name,
    Value<String>? type,
    Value<String>? liquidityId,
    Value<String>? organization,
    Value<String>? note,
    Value<int>? archived,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return StorageCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      name: name ?? this.name,
      type: type ?? this.type,
      liquidityId: liquidityId ?? this.liquidityId,
      organization: organization ?? this.organization,
      note: note ?? this.note,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (liquidityId.present) {
      map['liquidity_id'] = Variable<String>(liquidityId.value);
    }
    if (organization.present) {
      map['organization'] = Variable<String>(organization.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (archived.present) {
      map['archived'] = Variable<int>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('liquidityId: $liquidityId, ')
          ..write('organization: $organization, ')
          ..write('note: $note, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StorageCurrency extends Table
    with TableInfo<StorageCurrency, StorageCurrencyData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StorageCurrency(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _storageIdMeta = const VerificationMeta(
    'storageId',
  );
  late final GeneratedColumn<String> storageId = GeneratedColumn<String>(
    'storage_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES storage(id)',
  );
  static const VerificationMeta _currencyIdMeta = const VerificationMeta(
    'currencyId',
  );
  late final GeneratedColumn<String> currencyId = GeneratedColumn<String>(
    'currency_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES currency(id)',
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  late final GeneratedColumn<int> active = GeneratedColumn<int>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1 CHECK (active IN (0, 1))',
    defaultValue: const CustomExpression('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    storageId,
    currencyId,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_currency';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageCurrencyData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('storage_id')) {
      context.handle(
        _storageIdMeta,
        storageId.isAcceptableOrUnknown(data['storage_id']!, _storageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storageIdMeta);
    }
    if (data.containsKey('currency_id')) {
      context.handle(
        _currencyIdMeta,
        currencyId.isAcceptableOrUnknown(data['currency_id']!, _currencyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyIdMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {storageId, currencyId},
  ];
  @override
  StorageCurrencyData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageCurrencyData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      storageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_id'],
      )!,
      currencyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_id'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  StorageCurrency createAlias(String alias) {
    return StorageCurrency(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'UNIQUE(storage_id, currency_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class StorageCurrencyData extends DataClass
    implements Insertable<StorageCurrencyData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String storageId;
  final String currencyId;
  final int active;
  const StorageCurrencyData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.storageId,
    required this.currencyId,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['storage_id'] = Variable<String>(storageId);
    map['currency_id'] = Variable<String>(currencyId);
    map['active'] = Variable<int>(active);
    return map;
  }

  StorageCurrencyCompanion toCompanion(bool nullToAbsent) {
    return StorageCurrencyCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      storageId: Value(storageId),
      currencyId: Value(currencyId),
      active: Value(active),
    );
  }

  factory StorageCurrencyData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageCurrencyData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      storageId: serializer.fromJson<String>(json['storage_id']),
      currencyId: serializer.fromJson<String>(json['currency_id']),
      active: serializer.fromJson<int>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'storage_id': serializer.toJson<String>(storageId),
      'currency_id': serializer.toJson<String>(currencyId),
      'active': serializer.toJson<int>(active),
    };
  }

  StorageCurrencyData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? storageId,
    String? currencyId,
    int? active,
  }) => StorageCurrencyData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    storageId: storageId ?? this.storageId,
    currencyId: currencyId ?? this.currencyId,
    active: active ?? this.active,
  );
  StorageCurrencyData copyWithCompanion(StorageCurrencyCompanion data) {
    return StorageCurrencyData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      storageId: data.storageId.present ? data.storageId.value : this.storageId,
      currencyId: data.currencyId.present
          ? data.currencyId.value
          : this.currencyId,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageCurrencyData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('storageId: $storageId, ')
          ..write('currencyId: $currencyId, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    storageId,
    currencyId,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageCurrencyData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.storageId == this.storageId &&
          other.currencyId == this.currencyId &&
          other.active == this.active);
}

class StorageCurrencyCompanion extends UpdateCompanion<StorageCurrencyData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> storageId;
  final Value<String> currencyId;
  final Value<int> active;
  final Value<int> rowid;
  const StorageCurrencyCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.storageId = const Value.absent(),
    this.currencyId = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageCurrencyCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String storageId,
    required String currencyId,
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       storageId = Value(storageId),
       currencyId = Value(currencyId);
  static Insertable<StorageCurrencyData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? storageId,
    Expression<String>? currencyId,
    Expression<int>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (storageId != null) 'storage_id': storageId,
      if (currencyId != null) 'currency_id': currencyId,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageCurrencyCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? storageId,
    Value<String>? currencyId,
    Value<int>? active,
    Value<int>? rowid,
  }) {
    return StorageCurrencyCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      storageId: storageId ?? this.storageId,
      currencyId: currencyId ?? this.currencyId,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (storageId.present) {
      map['storage_id'] = Variable<String>(storageId.value);
    }
    if (currencyId.present) {
      map['currency_id'] = Variable<String>(currencyId.value);
    }
    if (active.present) {
      map['active'] = Variable<int>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageCurrencyCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('storageId: $storageId, ')
          ..write('currencyId: $currencyId, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Snapshot extends Table with TableInfo<Snapshot, SnapshotData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Snapshot(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'draft\' CHECK (status IN (\'draft\', \'fixed\'))',
    defaultValue: const CustomExpression('\'draft\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    date,
    note,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  Snapshot createAlias(String alias) {
    return Snapshot(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SnapshotData extends DataClass implements Insertable<SnapshotData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String date;
  final String note;
  final String status;
  final String createdAt;
  const SnapshotData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.date,
    required this.note,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['date'] = Variable<String>(date);
    map['note'] = Variable<String>(note);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  SnapshotCompanion toCompanion(bool nullToAbsent) {
    return SnapshotCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      date: Value(date),
      note: Value(note),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory SnapshotData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      date: serializer.fromJson<String>(json['date']),
      note: serializer.fromJson<String>(json['note']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'date': serializer.toJson<String>(date),
      'note': serializer.toJson<String>(note),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<String>(createdAt),
    };
  }

  SnapshotData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? date,
    String? note,
    String? status,
    String? createdAt,
  }) => SnapshotData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    date: date ?? this.date,
    note: note ?? this.note,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  SnapshotData copyWithCompanion(SnapshotCompanion data) {
    return SnapshotData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    date,
    note,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.date == this.date &&
          other.note == this.note &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class SnapshotCompanion extends UpdateCompanion<SnapshotData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> date;
  final Value<String> note;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<int> rowid;
  const SnapshotCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String date,
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       date = Value(date),
       createdAt = Value(createdAt);
  static Insertable<SnapshotData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? date,
    Expression<String>? note,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? date,
    Value<String>? note,
    Value<String>? status,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return SnapshotCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      date: date ?? this.date,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SnapshotLine extends Table
    with TableInfo<SnapshotLine, SnapshotLineData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SnapshotLine(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _snapshotIdMeta = const VerificationMeta(
    'snapshotId',
  );
  late final GeneratedColumn<String> snapshotId = GeneratedColumn<String>(
    'snapshot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES snapshot(id)',
  );
  static const VerificationMeta _storageIdMeta = const VerificationMeta(
    'storageId',
  );
  late final GeneratedColumn<String> storageId = GeneratedColumn<String>(
    'storage_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES storage(id)',
  );
  static const VerificationMeta _currencyIdMeta = const VerificationMeta(
    'currencyId',
  );
  late final GeneratedColumn<String> currencyId = GeneratedColumn<String>(
    'currency_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES currency(id)',
  );
  static const VerificationMeta _liquidityIdMeta = const VerificationMeta(
    'liquidityId',
  );
  late final GeneratedColumn<String> liquidityId = GeneratedColumn<String>(
    'liquidity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES liquidity_level(id)',
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (amount IS NULL OR delta_decimal_valid(amount))',
  );
  static const VerificationMeta _familyAmountMeta = const VerificationMeta(
    'familyAmount',
  );
  late final GeneratedColumn<String> familyAmount = GeneratedColumn<String>(
    'family_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'0\' CHECK (delta_decimal_valid(family_amount))',
    defaultValue: const CustomExpression('\'0\''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _confirmedMeta = const VerificationMeta(
    'confirmed',
  );
  late final GeneratedColumn<int> confirmed = GeneratedColumn<int>(
    'confirmed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (confirmed IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    snapshotId,
    storageId,
    currencyId,
    liquidityId,
    amount,
    familyAmount,
    note,
    confirmed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot_line';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotLineData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('snapshot_id')) {
      context.handle(
        _snapshotIdMeta,
        snapshotId.isAcceptableOrUnknown(data['snapshot_id']!, _snapshotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotIdMeta);
    }
    if (data.containsKey('storage_id')) {
      context.handle(
        _storageIdMeta,
        storageId.isAcceptableOrUnknown(data['storage_id']!, _storageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storageIdMeta);
    }
    if (data.containsKey('currency_id')) {
      context.handle(
        _currencyIdMeta,
        currencyId.isAcceptableOrUnknown(data['currency_id']!, _currencyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyIdMeta);
    }
    if (data.containsKey('liquidity_id')) {
      context.handle(
        _liquidityIdMeta,
        liquidityId.isAcceptableOrUnknown(
          data['liquidity_id']!,
          _liquidityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_liquidityIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('family_amount')) {
      context.handle(
        _familyAmountMeta,
        familyAmount.isAcceptableOrUnknown(
          data['family_amount']!,
          _familyAmountMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('confirmed')) {
      context.handle(
        _confirmedMeta,
        confirmed.isAcceptableOrUnknown(data['confirmed']!, _confirmedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {snapshotId, storageId, currencyId},
  ];
  @override
  SnapshotLineData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotLineData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      snapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_id'],
      )!,
      storageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_id'],
      )!,
      currencyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_id'],
      )!,
      liquidityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}liquidity_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      ),
      familyAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_amount'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      confirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmed'],
      )!,
    );
  }

  @override
  SnapshotLine createAlias(String alias) {
    return SnapshotLine(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK(amount IS NULL OR delta_decimal_le(family_amount, amount))',
    'UNIQUE(snapshot_id, storage_id, currency_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SnapshotLineData extends DataClass
    implements Insertable<SnapshotLineData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String snapshotId;
  final String storageId;
  final String currencyId;
  final String liquidityId;
  final String? amount;
  final String familyAmount;
  final String note;
  final int confirmed;
  const SnapshotLineData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.snapshotId,
    required this.storageId,
    required this.currencyId,
    required this.liquidityId,
    this.amount,
    required this.familyAmount,
    required this.note,
    required this.confirmed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['snapshot_id'] = Variable<String>(snapshotId);
    map['storage_id'] = Variable<String>(storageId);
    map['currency_id'] = Variable<String>(currencyId);
    map['liquidity_id'] = Variable<String>(liquidityId);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<String>(amount);
    }
    map['family_amount'] = Variable<String>(familyAmount);
    map['note'] = Variable<String>(note);
    map['confirmed'] = Variable<int>(confirmed);
    return map;
  }

  SnapshotLineCompanion toCompanion(bool nullToAbsent) {
    return SnapshotLineCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      snapshotId: Value(snapshotId),
      storageId: Value(storageId),
      currencyId: Value(currencyId),
      liquidityId: Value(liquidityId),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      familyAmount: Value(familyAmount),
      note: Value(note),
      confirmed: Value(confirmed),
    );
  }

  factory SnapshotLineData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotLineData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      snapshotId: serializer.fromJson<String>(json['snapshot_id']),
      storageId: serializer.fromJson<String>(json['storage_id']),
      currencyId: serializer.fromJson<String>(json['currency_id']),
      liquidityId: serializer.fromJson<String>(json['liquidity_id']),
      amount: serializer.fromJson<String?>(json['amount']),
      familyAmount: serializer.fromJson<String>(json['family_amount']),
      note: serializer.fromJson<String>(json['note']),
      confirmed: serializer.fromJson<int>(json['confirmed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'snapshot_id': serializer.toJson<String>(snapshotId),
      'storage_id': serializer.toJson<String>(storageId),
      'currency_id': serializer.toJson<String>(currencyId),
      'liquidity_id': serializer.toJson<String>(liquidityId),
      'amount': serializer.toJson<String?>(amount),
      'family_amount': serializer.toJson<String>(familyAmount),
      'note': serializer.toJson<String>(note),
      'confirmed': serializer.toJson<int>(confirmed),
    };
  }

  SnapshotLineData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? snapshotId,
    String? storageId,
    String? currencyId,
    String? liquidityId,
    Value<String?> amount = const Value.absent(),
    String? familyAmount,
    String? note,
    int? confirmed,
  }) => SnapshotLineData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    snapshotId: snapshotId ?? this.snapshotId,
    storageId: storageId ?? this.storageId,
    currencyId: currencyId ?? this.currencyId,
    liquidityId: liquidityId ?? this.liquidityId,
    amount: amount.present ? amount.value : this.amount,
    familyAmount: familyAmount ?? this.familyAmount,
    note: note ?? this.note,
    confirmed: confirmed ?? this.confirmed,
  );
  SnapshotLineData copyWithCompanion(SnapshotLineCompanion data) {
    return SnapshotLineData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      snapshotId: data.snapshotId.present
          ? data.snapshotId.value
          : this.snapshotId,
      storageId: data.storageId.present ? data.storageId.value : this.storageId,
      currencyId: data.currencyId.present
          ? data.currencyId.value
          : this.currencyId,
      liquidityId: data.liquidityId.present
          ? data.liquidityId.value
          : this.liquidityId,
      amount: data.amount.present ? data.amount.value : this.amount,
      familyAmount: data.familyAmount.present
          ? data.familyAmount.value
          : this.familyAmount,
      note: data.note.present ? data.note.value : this.note,
      confirmed: data.confirmed.present ? data.confirmed.value : this.confirmed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotLineData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('storageId: $storageId, ')
          ..write('currencyId: $currencyId, ')
          ..write('liquidityId: $liquidityId, ')
          ..write('amount: $amount, ')
          ..write('familyAmount: $familyAmount, ')
          ..write('note: $note, ')
          ..write('confirmed: $confirmed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    snapshotId,
    storageId,
    currencyId,
    liquidityId,
    amount,
    familyAmount,
    note,
    confirmed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotLineData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.snapshotId == this.snapshotId &&
          other.storageId == this.storageId &&
          other.currencyId == this.currencyId &&
          other.liquidityId == this.liquidityId &&
          other.amount == this.amount &&
          other.familyAmount == this.familyAmount &&
          other.note == this.note &&
          other.confirmed == this.confirmed);
}

class SnapshotLineCompanion extends UpdateCompanion<SnapshotLineData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> snapshotId;
  final Value<String> storageId;
  final Value<String> currencyId;
  final Value<String> liquidityId;
  final Value<String?> amount;
  final Value<String> familyAmount;
  final Value<String> note;
  final Value<int> confirmed;
  final Value<int> rowid;
  const SnapshotLineCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.snapshotId = const Value.absent(),
    this.storageId = const Value.absent(),
    this.currencyId = const Value.absent(),
    this.liquidityId = const Value.absent(),
    this.amount = const Value.absent(),
    this.familyAmount = const Value.absent(),
    this.note = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotLineCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String snapshotId,
    required String storageId,
    required String currencyId,
    required String liquidityId,
    this.amount = const Value.absent(),
    this.familyAmount = const Value.absent(),
    this.note = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       snapshotId = Value(snapshotId),
       storageId = Value(storageId),
       currencyId = Value(currencyId),
       liquidityId = Value(liquidityId);
  static Insertable<SnapshotLineData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? snapshotId,
    Expression<String>? storageId,
    Expression<String>? currencyId,
    Expression<String>? liquidityId,
    Expression<String>? amount,
    Expression<String>? familyAmount,
    Expression<String>? note,
    Expression<int>? confirmed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (snapshotId != null) 'snapshot_id': snapshotId,
      if (storageId != null) 'storage_id': storageId,
      if (currencyId != null) 'currency_id': currencyId,
      if (liquidityId != null) 'liquidity_id': liquidityId,
      if (amount != null) 'amount': amount,
      if (familyAmount != null) 'family_amount': familyAmount,
      if (note != null) 'note': note,
      if (confirmed != null) 'confirmed': confirmed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotLineCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? snapshotId,
    Value<String>? storageId,
    Value<String>? currencyId,
    Value<String>? liquidityId,
    Value<String?>? amount,
    Value<String>? familyAmount,
    Value<String>? note,
    Value<int>? confirmed,
    Value<int>? rowid,
  }) {
    return SnapshotLineCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      snapshotId: snapshotId ?? this.snapshotId,
      storageId: storageId ?? this.storageId,
      currencyId: currencyId ?? this.currencyId,
      liquidityId: liquidityId ?? this.liquidityId,
      amount: amount ?? this.amount,
      familyAmount: familyAmount ?? this.familyAmount,
      note: note ?? this.note,
      confirmed: confirmed ?? this.confirmed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (snapshotId.present) {
      map['snapshot_id'] = Variable<String>(snapshotId.value);
    }
    if (storageId.present) {
      map['storage_id'] = Variable<String>(storageId.value);
    }
    if (currencyId.present) {
      map['currency_id'] = Variable<String>(currencyId.value);
    }
    if (liquidityId.present) {
      map['liquidity_id'] = Variable<String>(liquidityId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (familyAmount.present) {
      map['family_amount'] = Variable<String>(familyAmount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (confirmed.present) {
      map['confirmed'] = Variable<int>(confirmed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotLineCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('storageId: $storageId, ')
          ..write('currencyId: $currencyId, ')
          ..write('liquidityId: $liquidityId, ')
          ..write('amount: $amount, ')
          ..write('familyAmount: $familyAmount, ')
          ..write('note: $note, ')
          ..write('confirmed: $confirmed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SnapshotRate extends Table
    with TableInfo<SnapshotRate, SnapshotRateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SnapshotRate(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _snapshotIdMeta = const VerificationMeta(
    'snapshotId',
  );
  late final GeneratedColumn<String> snapshotId = GeneratedColumn<String>(
    'snapshot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES snapshot(id)',
  );
  static const VerificationMeta _currencyIdMeta = const VerificationMeta(
    'currencyId',
  );
  late final GeneratedColumn<String> currencyId = GeneratedColumn<String>(
    'currency_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES currency(id)',
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (delta_decimal_positive(rate))',
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  late final GeneratedColumn<String> fetchedAt = GeneratedColumn<String>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    snapshotId,
    currencyId,
    rate,
    source,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot_rate';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotRateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('snapshot_id')) {
      context.handle(
        _snapshotIdMeta,
        snapshotId.isAcceptableOrUnknown(data['snapshot_id']!, _snapshotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotIdMeta);
    }
    if (data.containsKey('currency_id')) {
      context.handle(
        _currencyIdMeta,
        currencyId.isAcceptableOrUnknown(data['currency_id']!, _currencyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyIdMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {snapshotId, currencyId},
  ];
  @override
  SnapshotRateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotRateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      snapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_id'],
      )!,
      currencyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_id'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  SnapshotRate createAlias(String alias) {
    return SnapshotRate(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'UNIQUE(snapshot_id, currency_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SnapshotRateData extends DataClass
    implements Insertable<SnapshotRateData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String snapshotId;
  final String currencyId;
  final String rate;
  final String source;
  final String fetchedAt;
  const SnapshotRateData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.snapshotId,
    required this.currencyId,
    required this.rate,
    required this.source,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['snapshot_id'] = Variable<String>(snapshotId);
    map['currency_id'] = Variable<String>(currencyId);
    map['rate'] = Variable<String>(rate);
    map['source'] = Variable<String>(source);
    map['fetched_at'] = Variable<String>(fetchedAt);
    return map;
  }

  SnapshotRateCompanion toCompanion(bool nullToAbsent) {
    return SnapshotRateCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      snapshotId: Value(snapshotId),
      currencyId: Value(currencyId),
      rate: Value(rate),
      source: Value(source),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory SnapshotRateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotRateData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      snapshotId: serializer.fromJson<String>(json['snapshot_id']),
      currencyId: serializer.fromJson<String>(json['currency_id']),
      rate: serializer.fromJson<String>(json['rate']),
      source: serializer.fromJson<String>(json['source']),
      fetchedAt: serializer.fromJson<String>(json['fetched_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'snapshot_id': serializer.toJson<String>(snapshotId),
      'currency_id': serializer.toJson<String>(currencyId),
      'rate': serializer.toJson<String>(rate),
      'source': serializer.toJson<String>(source),
      'fetched_at': serializer.toJson<String>(fetchedAt),
    };
  }

  SnapshotRateData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? snapshotId,
    String? currencyId,
    String? rate,
    String? source,
    String? fetchedAt,
  }) => SnapshotRateData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    snapshotId: snapshotId ?? this.snapshotId,
    currencyId: currencyId ?? this.currencyId,
    rate: rate ?? this.rate,
    source: source ?? this.source,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  SnapshotRateData copyWithCompanion(SnapshotRateCompanion data) {
    return SnapshotRateData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      snapshotId: data.snapshotId.present
          ? data.snapshotId.value
          : this.snapshotId,
      currencyId: data.currencyId.present
          ? data.currencyId.value
          : this.currencyId,
      rate: data.rate.present ? data.rate.value : this.rate,
      source: data.source.present ? data.source.value : this.source,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRateData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('currencyId: $currencyId, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    snapshotId,
    currencyId,
    rate,
    source,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotRateData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.snapshotId == this.snapshotId &&
          other.currencyId == this.currencyId &&
          other.rate == this.rate &&
          other.source == this.source &&
          other.fetchedAt == this.fetchedAt);
}

class SnapshotRateCompanion extends UpdateCompanion<SnapshotRateData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> snapshotId;
  final Value<String> currencyId;
  final Value<String> rate;
  final Value<String> source;
  final Value<String> fetchedAt;
  final Value<int> rowid;
  const SnapshotRateCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.snapshotId = const Value.absent(),
    this.currencyId = const Value.absent(),
    this.rate = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotRateCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String snapshotId,
    required String currencyId,
    required String rate,
    required String source,
    required String fetchedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       snapshotId = Value(snapshotId),
       currencyId = Value(currencyId),
       rate = Value(rate),
       source = Value(source),
       fetchedAt = Value(fetchedAt);
  static Insertable<SnapshotRateData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? snapshotId,
    Expression<String>? currencyId,
    Expression<String>? rate,
    Expression<String>? source,
    Expression<String>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (snapshotId != null) 'snapshot_id': snapshotId,
      if (currencyId != null) 'currency_id': currencyId,
      if (rate != null) 'rate': rate,
      if (source != null) 'source': source,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotRateCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? snapshotId,
    Value<String>? currencyId,
    Value<String>? rate,
    Value<String>? source,
    Value<String>? fetchedAt,
    Value<int>? rowid,
  }) {
    return SnapshotRateCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      snapshotId: snapshotId ?? this.snapshotId,
      currencyId: currencyId ?? this.currencyId,
      rate: rate ?? this.rate,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (snapshotId.present) {
      map['snapshot_id'] = Variable<String>(snapshotId.value);
    }
    if (currencyId.present) {
      map['currency_id'] = Variable<String>(currencyId.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<String>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRateCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('currencyId: $currencyId, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AuditLog extends Table with TableInfo<AuditLog, AuditLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AuditLog(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _snapshotIdMeta = const VerificationMeta(
    'snapshotId',
  );
  late final GeneratedColumn<String> snapshotId = GeneratedColumn<String>(
    'snapshot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES snapshot(id)',
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  late final GeneratedColumn<String> changedAt = GeneratedColumn<String>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    snapshotId,
    entityType,
    entityId,
    operation,
    oldValue,
    newValue,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('snapshot_id')) {
      context.handle(
        _snapshotIdMeta,
        snapshotId.isAcceptableOrUnknown(data['snapshot_id']!, _snapshotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    } else if (isInserting) {
      context.missing(_oldValueMeta);
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    } else if (isInserting) {
      context.missing(_newValueMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      snapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      )!,
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  AuditLog createAlias(String alias) {
    return AuditLog(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AuditLogData extends DataClass implements Insertable<AuditLogData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String snapshotId;
  final String entityType;
  final String entityId;
  final String operation;
  final String oldValue;
  final String newValue;
  final String changedAt;
  const AuditLogData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.snapshotId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.oldValue,
    required this.newValue,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['snapshot_id'] = Variable<String>(snapshotId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['old_value'] = Variable<String>(oldValue);
    map['new_value'] = Variable<String>(newValue);
    map['changed_at'] = Variable<String>(changedAt);
    return map;
  }

  AuditLogCompanion toCompanion(bool nullToAbsent) {
    return AuditLogCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      snapshotId: Value(snapshotId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      oldValue: Value(oldValue),
      newValue: Value(newValue),
      changedAt: Value(changedAt),
    );
  }

  factory AuditLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      snapshotId: serializer.fromJson<String>(json['snapshot_id']),
      entityType: serializer.fromJson<String>(json['entity_type']),
      entityId: serializer.fromJson<String>(json['entity_id']),
      operation: serializer.fromJson<String>(json['operation']),
      oldValue: serializer.fromJson<String>(json['old_value']),
      newValue: serializer.fromJson<String>(json['new_value']),
      changedAt: serializer.fromJson<String>(json['changed_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'snapshot_id': serializer.toJson<String>(snapshotId),
      'entity_type': serializer.toJson<String>(entityType),
      'entity_id': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'old_value': serializer.toJson<String>(oldValue),
      'new_value': serializer.toJson<String>(newValue),
      'changed_at': serializer.toJson<String>(changedAt),
    };
  }

  AuditLogData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? snapshotId,
    String? entityType,
    String? entityId,
    String? operation,
    String? oldValue,
    String? newValue,
    String? changedAt,
  }) => AuditLogData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    snapshotId: snapshotId ?? this.snapshotId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    oldValue: oldValue ?? this.oldValue,
    newValue: newValue ?? this.newValue,
    changedAt: changedAt ?? this.changedAt,
  );
  AuditLogData copyWithCompanion(AuditLogCompanion data) {
    return AuditLogData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      snapshotId: data.snapshotId.present
          ? data.snapshotId.value
          : this.snapshotId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    snapshotId,
    entityType,
    entityId,
    operation,
    oldValue,
    newValue,
    changedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.snapshotId == this.snapshotId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue &&
          other.changedAt == this.changedAt);
}

class AuditLogCompanion extends UpdateCompanion<AuditLogData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> snapshotId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> oldValue;
  final Value<String> newValue;
  final Value<String> changedAt;
  final Value<int> rowid;
  const AuditLogCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.snapshotId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String snapshotId,
    required String entityType,
    required String entityId,
    required String operation,
    required String oldValue,
    required String newValue,
    required String changedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       snapshotId = Value(snapshotId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       oldValue = Value(oldValue),
       newValue = Value(newValue),
       changedAt = Value(changedAt);
  static Insertable<AuditLogData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? snapshotId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<String>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (snapshotId != null) 'snapshot_id': snapshotId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? snapshotId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? oldValue,
    Value<String>? newValue,
    Value<String>? changedAt,
    Value<int>? rowid,
  }) {
    return AuditLogCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      snapshotId: snapshotId ?? this.snapshotId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (snapshotId.present) {
      map['snapshot_id'] = Variable<String>(snapshotId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<String>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Settings extends Table with TableInfo<Settings, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    name,
    value,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Setting extends DataClass implements Insertable<Setting> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String name;
  final String value;
  const Setting({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.name,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      name: Value(name),
      value: Value(value),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? name,
    String? value,
  }) => Setting(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    value: value ?? this.value,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, updatedAt, deviceId, deleted, name, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.name == this.name &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> name;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String name,
    required String value,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       name = Value(name),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? name,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? name,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      name: name ?? this.name,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RateCache extends Table with TableInfo<RateCache, RateCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RateCache(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 36)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  late final GeneratedColumn<int> deleted = GeneratedColumn<int>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _currencyIdMeta = const VerificationMeta(
    'currencyId',
  );
  late final GeneratedColumn<String> currencyId = GeneratedColumn<String>(
    'currency_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES currency(id)',
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (delta_decimal_positive(rate))',
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deviceId,
    deleted,
    currencyId,
    date,
    rate,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rate_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RateCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('currency_id')) {
      context.handle(
        _currencyIdMeta,
        currencyId.isAcceptableOrUnknown(data['currency_id']!, _currencyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {currencyId, date, source},
  ];
  @override
  RateCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RateCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted'],
      )!,
      currencyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  RateCache createAlias(String alias) {
    return RateCache(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'UNIQUE(currency_id, date, source)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class RateCacheData extends DataClass implements Insertable<RateCacheData> {
  final String id;
  final String updatedAt;
  final String deviceId;
  final int deleted;
  final String currencyId;
  final String date;
  final String rate;
  final String source;
  const RateCacheData({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    required this.currencyId,
    required this.date,
    required this.rate,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<String>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<int>(deleted);
    map['currency_id'] = Variable<String>(currencyId);
    map['date'] = Variable<String>(date);
    map['rate'] = Variable<String>(rate);
    map['source'] = Variable<String>(source);
    return map;
  }

  RateCacheCompanion toCompanion(bool nullToAbsent) {
    return RateCacheCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      currencyId: Value(currencyId),
      date: Value(date),
      rate: Value(rate),
      source: Value(source),
    );
  }

  factory RateCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RateCacheData(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deleted: serializer.fromJson<int>(json['deleted']),
      currencyId: serializer.fromJson<String>(json['currency_id']),
      date: serializer.fromJson<String>(json['date']),
      rate: serializer.fromJson<String>(json['rate']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<String>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<int>(deleted),
      'currency_id': serializer.toJson<String>(currencyId),
      'date': serializer.toJson<String>(date),
      'rate': serializer.toJson<String>(rate),
      'source': serializer.toJson<String>(source),
    };
  }

  RateCacheData copyWith({
    String? id,
    String? updatedAt,
    String? deviceId,
    int? deleted,
    String? currencyId,
    String? date,
    String? rate,
    String? source,
  }) => RateCacheData(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    currencyId: currencyId ?? this.currencyId,
    date: date ?? this.date,
    rate: rate ?? this.rate,
    source: source ?? this.source,
  );
  RateCacheData copyWithCompanion(RateCacheCompanion data) {
    return RateCacheData(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      currencyId: data.currencyId.present
          ? data.currencyId.value
          : this.currencyId,
      date: data.date.present ? data.date.value : this.date,
      rate: data.rate.present ? data.rate.value : this.rate,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RateCacheData(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('currencyId: $currencyId, ')
          ..write('date: $date, ')
          ..write('rate: $rate, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deviceId,
    deleted,
    currencyId,
    date,
    rate,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RateCacheData &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.currencyId == this.currencyId &&
          other.date == this.date &&
          other.rate == this.rate &&
          other.source == this.source);
}

class RateCacheCompanion extends UpdateCompanion<RateCacheData> {
  final Value<String> id;
  final Value<String> updatedAt;
  final Value<String> deviceId;
  final Value<int> deleted;
  final Value<String> currencyId;
  final Value<String> date;
  final Value<String> rate;
  final Value<String> source;
  final Value<int> rowid;
  const RateCacheCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.currencyId = const Value.absent(),
    this.date = const Value.absent(),
    this.rate = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RateCacheCompanion.insert({
    required String id,
    required String updatedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String currencyId,
    required String date,
    required String rate,
    required String source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       currencyId = Value(currencyId),
       date = Value(date),
       rate = Value(rate),
       source = Value(source);
  static Insertable<RateCacheData> custom({
    Expression<String>? id,
    Expression<String>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deleted,
    Expression<String>? currencyId,
    Expression<String>? date,
    Expression<String>? rate,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (currencyId != null) 'currency_id': currencyId,
      if (date != null) 'date': date,
      if (rate != null) 'rate': rate,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RateCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? updatedAt,
    Value<String>? deviceId,
    Value<int>? deleted,
    Value<String>? currencyId,
    Value<String>? date,
    Value<String>? rate,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return RateCacheCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      currencyId: currencyId ?? this.currencyId,
      date: date ?? this.date,
      rate: rate ?? this.rate,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<int>(deleted.value);
    }
    if (currencyId.present) {
      map['currency_id'] = Variable<String>(currencyId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RateCacheCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('currencyId: $currencyId, ')
          ..write('date: $date, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final Currency currency = Currency(this);
  late final LiquidityLevel liquidityLevel = LiquidityLevel(this);
  late final Storage storage = Storage(this);
  late final StorageCurrency storageCurrency = StorageCurrency(this);
  late final Snapshot snapshot = Snapshot(this);
  late final SnapshotLine snapshotLine = SnapshotLine(this);
  late final SnapshotRate snapshotRate = SnapshotRate(this);
  late final AuditLog auditLog = AuditLog(this);
  late final Settings settings = Settings(this);
  late final RateCache rateCache = RateCache(this);
  late final Index snapshotLineParent = Index(
    'snapshot_line_parent',
    'CREATE INDEX snapshot_line_parent ON snapshot_line (snapshot_id)',
  );
  late final Index auditLogParent = Index(
    'audit_log_parent',
    'CREATE INDEX audit_log_parent ON audit_log (snapshot_id, changed_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    currency,
    liquidityLevel,
    storage,
    storageCurrency,
    snapshot,
    snapshotLine,
    snapshotRate,
    auditLog,
    settings,
    rateCache,
    snapshotLineParent,
    auditLogParent,
  ];
}

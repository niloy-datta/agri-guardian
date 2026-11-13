// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedFieldsTable extends CachedFields
    with TableInfo<$CachedFieldsTable, CachedField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverCreatedAtMeta = const VerificationMeta(
    'serverCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>(
        'server_created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    payloadJson,
    serverVersion,
    serverCreatedAt,
    serverUpdatedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedField> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverVersionMeta);
    }
    if (data.containsKey('server_created_at')) {
      context.handle(
        _serverCreatedAtMeta,
        serverCreatedAt.isAcceptableOrUnknown(
          data['server_created_at']!,
          _serverCreatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverCreatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverUpdatedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  CachedField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedField(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      serverCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_created_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedFieldsTable createAlias(String alias) {
    return $CachedFieldsTable(attachedDatabase, alias);
  }
}

class CachedField extends DataClass implements Insertable<CachedField> {
  final String serverId;
  final String payloadJson;
  final int serverVersion;
  final DateTime serverCreatedAt;
  final DateTime serverUpdatedAt;
  final DateTime cachedAt;
  const CachedField({
    required this.serverId,
    required this.payloadJson,
    required this.serverVersion,
    required this.serverCreatedAt,
    required this.serverUpdatedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['server_version'] = Variable<int>(serverVersion);
    map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedFieldsCompanion toCompanion(bool nullToAbsent) {
    return CachedFieldsCompanion(
      serverId: Value(serverId),
      payloadJson: Value(payloadJson),
      serverVersion: Value(serverVersion),
      serverCreatedAt: Value(serverCreatedAt),
      serverUpdatedAt: Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedField.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedField(
      serverId: serializer.fromJson<String>(json['serverId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      serverCreatedAt: serializer.fromJson<DateTime>(json['serverCreatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'serverCreatedAt': serializer.toJson<DateTime>(serverCreatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedField copyWith({
    String? serverId,
    String? payloadJson,
    int? serverVersion,
    DateTime? serverCreatedAt,
    DateTime? serverUpdatedAt,
    DateTime? cachedAt,
  }) => CachedField(
    serverId: serverId ?? this.serverId,
    payloadJson: payloadJson ?? this.payloadJson,
    serverVersion: serverVersion ?? this.serverVersion,
    serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
    serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedField copyWithCompanion(CachedFieldsCompanion data) {
    return CachedField(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedField(')
          ..write('serverId: $serverId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    payloadJson,
    serverVersion,
    serverCreatedAt,
    serverUpdatedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedField &&
          other.serverId == this.serverId &&
          other.payloadJson == this.payloadJson &&
          other.serverVersion == this.serverVersion &&
          other.serverCreatedAt == this.serverCreatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedFieldsCompanion extends UpdateCompanion<CachedField> {
  final Value<String> serverId;
  final Value<String> payloadJson;
  final Value<int> serverVersion;
  final Value<DateTime> serverCreatedAt;
  final Value<DateTime> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedFieldsCompanion({
    this.serverId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFieldsCompanion.insert({
    required String serverId,
    required String payloadJson,
    required int serverVersion,
    required DateTime serverCreatedAt,
    required DateTime serverUpdatedAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       payloadJson = Value(payloadJson),
       serverVersion = Value(serverVersion),
       serverCreatedAt = Value(serverCreatedAt),
       serverUpdatedAt = Value(serverUpdatedAt),
       cachedAt = Value(cachedAt);
  static Insertable<CachedField> custom({
    Expression<String>? serverId,
    Expression<String>? payloadJson,
    Expression<int>? serverVersion,
    Expression<DateTime>? serverCreatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (serverVersion != null) 'server_version': serverVersion,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFieldsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? payloadJson,
    Value<int>? serverVersion,
    Value<DateTime>? serverCreatedAt,
    Value<DateTime>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedFieldsCompanion(
      serverId: serverId ?? this.serverId,
      payloadJson: payloadJson ?? this.payloadJson,
      serverVersion: serverVersion ?? this.serverVersion,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFieldsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCropCyclesTable extends CachedCropCycles
    with TableInfo<$CachedCropCyclesTable, CachedCropCycle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCropCyclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldServerIdMeta = const VerificationMeta(
    'fieldServerId',
  );
  @override
  late final GeneratedColumn<String> fieldServerId = GeneratedColumn<String>(
    'field_server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverCreatedAtMeta = const VerificationMeta(
    'serverCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>(
        'server_created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    fieldServerId,
    payloadJson,
    serverVersion,
    serverCreatedAt,
    serverUpdatedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_crop_cycles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCropCycle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('field_server_id')) {
      context.handle(
        _fieldServerIdMeta,
        fieldServerId.isAcceptableOrUnknown(
          data['field_server_id']!,
          _fieldServerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fieldServerIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverVersionMeta);
    }
    if (data.containsKey('server_created_at')) {
      context.handle(
        _serverCreatedAtMeta,
        serverCreatedAt.isAcceptableOrUnknown(
          data['server_created_at']!,
          _serverCreatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverCreatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverUpdatedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  CachedCropCycle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCropCycle(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      fieldServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_server_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      serverCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_created_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedCropCyclesTable createAlias(String alias) {
    return $CachedCropCyclesTable(attachedDatabase, alias);
  }
}

class CachedCropCycle extends DataClass implements Insertable<CachedCropCycle> {
  final String serverId;
  final String fieldServerId;
  final String payloadJson;
  final int serverVersion;
  final DateTime serverCreatedAt;
  final DateTime serverUpdatedAt;
  final DateTime cachedAt;
  const CachedCropCycle({
    required this.serverId,
    required this.fieldServerId,
    required this.payloadJson,
    required this.serverVersion,
    required this.serverCreatedAt,
    required this.serverUpdatedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['field_server_id'] = Variable<String>(fieldServerId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['server_version'] = Variable<int>(serverVersion);
    map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedCropCyclesCompanion toCompanion(bool nullToAbsent) {
    return CachedCropCyclesCompanion(
      serverId: Value(serverId),
      fieldServerId: Value(fieldServerId),
      payloadJson: Value(payloadJson),
      serverVersion: Value(serverVersion),
      serverCreatedAt: Value(serverCreatedAt),
      serverUpdatedAt: Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedCropCycle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCropCycle(
      serverId: serializer.fromJson<String>(json['serverId']),
      fieldServerId: serializer.fromJson<String>(json['fieldServerId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      serverCreatedAt: serializer.fromJson<DateTime>(json['serverCreatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'fieldServerId': serializer.toJson<String>(fieldServerId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'serverCreatedAt': serializer.toJson<DateTime>(serverCreatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedCropCycle copyWith({
    String? serverId,
    String? fieldServerId,
    String? payloadJson,
    int? serverVersion,
    DateTime? serverCreatedAt,
    DateTime? serverUpdatedAt,
    DateTime? cachedAt,
  }) => CachedCropCycle(
    serverId: serverId ?? this.serverId,
    fieldServerId: fieldServerId ?? this.fieldServerId,
    payloadJson: payloadJson ?? this.payloadJson,
    serverVersion: serverVersion ?? this.serverVersion,
    serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
    serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedCropCycle copyWithCompanion(CachedCropCyclesCompanion data) {
    return CachedCropCycle(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      fieldServerId: data.fieldServerId.present
          ? data.fieldServerId.value
          : this.fieldServerId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCropCycle(')
          ..write('serverId: $serverId, ')
          ..write('fieldServerId: $fieldServerId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    fieldServerId,
    payloadJson,
    serverVersion,
    serverCreatedAt,
    serverUpdatedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCropCycle &&
          other.serverId == this.serverId &&
          other.fieldServerId == this.fieldServerId &&
          other.payloadJson == this.payloadJson &&
          other.serverVersion == this.serverVersion &&
          other.serverCreatedAt == this.serverCreatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedCropCyclesCompanion extends UpdateCompanion<CachedCropCycle> {
  final Value<String> serverId;
  final Value<String> fieldServerId;
  final Value<String> payloadJson;
  final Value<int> serverVersion;
  final Value<DateTime> serverCreatedAt;
  final Value<DateTime> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedCropCyclesCompanion({
    this.serverId = const Value.absent(),
    this.fieldServerId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCropCyclesCompanion.insert({
    required String serverId,
    required String fieldServerId,
    required String payloadJson,
    required int serverVersion,
    required DateTime serverCreatedAt,
    required DateTime serverUpdatedAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       fieldServerId = Value(fieldServerId),
       payloadJson = Value(payloadJson),
       serverVersion = Value(serverVersion),
       serverCreatedAt = Value(serverCreatedAt),
       serverUpdatedAt = Value(serverUpdatedAt),
       cachedAt = Value(cachedAt);
  static Insertable<CachedCropCycle> custom({
    Expression<String>? serverId,
    Expression<String>? fieldServerId,
    Expression<String>? payloadJson,
    Expression<int>? serverVersion,
    Expression<DateTime>? serverCreatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (fieldServerId != null) 'field_server_id': fieldServerId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (serverVersion != null) 'server_version': serverVersion,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCropCyclesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? fieldServerId,
    Value<String>? payloadJson,
    Value<int>? serverVersion,
    Value<DateTime>? serverCreatedAt,
    Value<DateTime>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedCropCyclesCompanion(
      serverId: serverId ?? this.serverId,
      fieldServerId: fieldServerId ?? this.fieldServerId,
      payloadJson: payloadJson ?? this.payloadJson,
      serverVersion: serverVersion ?? this.serverVersion,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (fieldServerId.present) {
      map['field_server_id'] = Variable<String>(fieldServerId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCropCyclesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('fieldServerId: $fieldServerId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMutationsTable extends PendingMutations
    with TableInfo<$PendingMutationsTable, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetServerIdMeta = const VerificationMeta(
    'targetServerId',
  );
  @override
  late final GeneratedColumn<String> targetServerId = GeneratedColumn<String>(
    'target_server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentMutationIdMeta = const VerificationMeta(
    'parentMutationId',
  );
  @override
  late final GeneratedColumn<String> parentMutationId = GeneratedColumn<String>(
    'parent_mutation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedServerIdMeta = const VerificationMeta(
    'resolvedServerId',
  );
  @override
  late final GeneratedColumn<String> resolvedServerId = GeneratedColumn<String>(
    'resolved_server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMessageMeta = const VerificationMeta(
    'lastErrorMessage',
  );
  @override
  late final GeneratedColumn<String> lastErrorMessage = GeneratedColumn<String>(
    'last_error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    type,
    payloadJson,
    idempotencyKey,
    targetServerId,
    parentMutationId,
    resolvedServerId,
    status,
    attemptCount,
    lastErrorCode,
    lastErrorMessage,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('target_server_id')) {
      context.handle(
        _targetServerIdMeta,
        targetServerId.isAcceptableOrUnknown(
          data['target_server_id']!,
          _targetServerIdMeta,
        ),
      );
    }
    if (data.containsKey('parent_mutation_id')) {
      context.handle(
        _parentMutationIdMeta,
        parentMutationId.isAcceptableOrUnknown(
          data['parent_mutation_id']!,
          _parentMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('resolved_server_id')) {
      context.handle(
        _resolvedServerIdMeta,
        resolvedServerId.isAcceptableOrUnknown(
          data['resolved_server_id']!,
          _resolvedServerIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('last_error_message')) {
      context.handle(
        _lastErrorMessageMeta,
        lastErrorMessage.isAcceptableOrUnknown(
          data['last_error_message']!,
          _lastErrorMessageMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      targetServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_server_id'],
      ),
      parentMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_mutation_id'],
      ),
      resolvedServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_server_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      lastErrorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingMutationsTable createAlias(String alias) {
    return $PendingMutationsTable(attachedDatabase, alias);
  }
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final String mutationId;
  final String type;
  final String payloadJson;
  final String idempotencyKey;
  final String? targetServerId;
  final String? parentMutationId;
  final String? resolvedServerId;
  final String status;
  final int attemptCount;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PendingMutation({
    required this.mutationId,
    required this.type,
    required this.payloadJson,
    required this.idempotencyKey,
    this.targetServerId,
    this.parentMutationId,
    this.resolvedServerId,
    required this.status,
    required this.attemptCount,
    this.lastErrorCode,
    this.lastErrorMessage,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['type'] = Variable<String>(type);
    map['payload_json'] = Variable<String>(payloadJson);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    if (!nullToAbsent || targetServerId != null) {
      map['target_server_id'] = Variable<String>(targetServerId);
    }
    if (!nullToAbsent || parentMutationId != null) {
      map['parent_mutation_id'] = Variable<String>(parentMutationId);
    }
    if (!nullToAbsent || resolvedServerId != null) {
      map['resolved_server_id'] = Variable<String>(resolvedServerId);
    }
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || lastErrorMessage != null) {
      map['last_error_message'] = Variable<String>(lastErrorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      mutationId: Value(mutationId),
      type: Value(type),
      payloadJson: Value(payloadJson),
      idempotencyKey: Value(idempotencyKey),
      targetServerId: targetServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetServerId),
      parentMutationId: parentMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentMutationId),
      resolvedServerId: resolvedServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedServerId),
      status: Value(status),
      attemptCount: Value(attemptCount),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      lastErrorMessage: lastErrorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      mutationId: serializer.fromJson<String>(json['mutationId']),
      type: serializer.fromJson<String>(json['type']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      targetServerId: serializer.fromJson<String?>(json['targetServerId']),
      parentMutationId: serializer.fromJson<String?>(json['parentMutationId']),
      resolvedServerId: serializer.fromJson<String?>(json['resolvedServerId']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      lastErrorMessage: serializer.fromJson<String?>(json['lastErrorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutationId': serializer.toJson<String>(mutationId),
      'type': serializer.toJson<String>(type),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'targetServerId': serializer.toJson<String?>(targetServerId),
      'parentMutationId': serializer.toJson<String?>(parentMutationId),
      'resolvedServerId': serializer.toJson<String?>(resolvedServerId),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'lastErrorMessage': serializer.toJson<String?>(lastErrorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingMutation copyWith({
    String? mutationId,
    String? type,
    String? payloadJson,
    String? idempotencyKey,
    Value<String?> targetServerId = const Value.absent(),
    Value<String?> parentMutationId = const Value.absent(),
    Value<String?> resolvedServerId = const Value.absent(),
    String? status,
    int? attemptCount,
    Value<String?> lastErrorCode = const Value.absent(),
    Value<String?> lastErrorMessage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PendingMutation(
    mutationId: mutationId ?? this.mutationId,
    type: type ?? this.type,
    payloadJson: payloadJson ?? this.payloadJson,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    targetServerId: targetServerId.present
        ? targetServerId.value
        : this.targetServerId,
    parentMutationId: parentMutationId.present
        ? parentMutationId.value
        : this.parentMutationId,
    resolvedServerId: resolvedServerId.present
        ? resolvedServerId.value
        : this.resolvedServerId,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    lastErrorMessage: lastErrorMessage.present
        ? lastErrorMessage.value
        : this.lastErrorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      type: data.type.present ? data.type.value : this.type,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      targetServerId: data.targetServerId.present
          ? data.targetServerId.value
          : this.targetServerId,
      parentMutationId: data.parentMutationId.present
          ? data.parentMutationId.value
          : this.parentMutationId,
      resolvedServerId: data.resolvedServerId.present
          ? data.resolvedServerId.value
          : this.resolvedServerId,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      lastErrorMessage: data.lastErrorMessage.present
          ? data.lastErrorMessage.value
          : this.lastErrorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('mutationId: $mutationId, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('targetServerId: $targetServerId, ')
          ..write('parentMutationId: $parentMutationId, ')
          ..write('resolvedServerId: $resolvedServerId, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mutationId,
    type,
    payloadJson,
    idempotencyKey,
    targetServerId,
    parentMutationId,
    resolvedServerId,
    status,
    attemptCount,
    lastErrorCode,
    lastErrorMessage,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.mutationId == this.mutationId &&
          other.type == this.type &&
          other.payloadJson == this.payloadJson &&
          other.idempotencyKey == this.idempotencyKey &&
          other.targetServerId == this.targetServerId &&
          other.parentMutationId == this.parentMutationId &&
          other.resolvedServerId == this.resolvedServerId &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.lastErrorCode == this.lastErrorCode &&
          other.lastErrorMessage == this.lastErrorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<String> mutationId;
  final Value<String> type;
  final Value<String> payloadJson;
  final Value<String> idempotencyKey;
  final Value<String?> targetServerId;
  final Value<String?> parentMutationId;
  final Value<String?> resolvedServerId;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<String?> lastErrorCode;
  final Value<String?> lastErrorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingMutationsCompanion({
    this.mutationId = const Value.absent(),
    this.type = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.targetServerId = const Value.absent(),
    this.parentMutationId = const Value.absent(),
    this.resolvedServerId = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    required String mutationId,
    required String type,
    required String payloadJson,
    required String idempotencyKey,
    this.targetServerId = const Value.absent(),
    this.parentMutationId = const Value.absent(),
    this.resolvedServerId = const Value.absent(),
    required String status,
    this.attemptCount = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       type = Value(type),
       payloadJson = Value(payloadJson),
       idempotencyKey = Value(idempotencyKey),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingMutation> custom({
    Expression<String>? mutationId,
    Expression<String>? type,
    Expression<String>? payloadJson,
    Expression<String>? idempotencyKey,
    Expression<String>? targetServerId,
    Expression<String>? parentMutationId,
    Expression<String>? resolvedServerId,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<String>? lastErrorCode,
    Expression<String>? lastErrorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (type != null) 'type': type,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (targetServerId != null) 'target_server_id': targetServerId,
      if (parentMutationId != null) 'parent_mutation_id': parentMutationId,
      if (resolvedServerId != null) 'resolved_server_id': resolvedServerId,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMutationsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? type,
    Value<String>? payloadJson,
    Value<String>? idempotencyKey,
    Value<String?>? targetServerId,
    Value<String?>? parentMutationId,
    Value<String?>? resolvedServerId,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<String?>? lastErrorCode,
    Value<String?>? lastErrorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingMutationsCompanion(
      mutationId: mutationId ?? this.mutationId,
      type: type ?? this.type,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      targetServerId: targetServerId ?? this.targetServerId,
      parentMutationId: parentMutationId ?? this.parentMutationId,
      resolvedServerId: resolvedServerId ?? this.resolvedServerId,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (targetServerId.present) {
      map['target_server_id'] = Variable<String>(targetServerId.value);
    }
    if (parentMutationId.present) {
      map['parent_mutation_id'] = Variable<String>(parentMutationId.value);
    }
    if (resolvedServerId.present) {
      map['resolved_server_id'] = Variable<String>(resolvedServerId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (lastErrorMessage.present) {
      map['last_error_message'] = Variable<String>(lastErrorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('targetServerId: $targetServerId, ')
          ..write('parentMutationId: $parentMutationId, ')
          ..write('resolvedServerId: $resolvedServerId, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMarketplaceResponsesTable extends CachedMarketplaceResponses
    with
        TableInfo<$CachedMarketplaceResponsesTable, CachedMarketplaceResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMarketplaceResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeUserIdMeta = const VerificationMeta(
    'scopeUserId',
  );
  @override
  late final GeneratedColumn<String> scopeUserId = GeneratedColumn<String>(
    'scope_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    scopeUserId,
    payloadJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_marketplace_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMarketplaceResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('scope_user_id')) {
      context.handle(
        _scopeUserIdMeta,
        scopeUserId.isAcceptableOrUnknown(
          data['scope_user_id']!,
          _scopeUserIdMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CachedMarketplaceResponse map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMarketplaceResponse(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      scopeUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_user_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedMarketplaceResponsesTable createAlias(String alias) {
    return $CachedMarketplaceResponsesTable(attachedDatabase, alias);
  }
}

class CachedMarketplaceResponse extends DataClass
    implements Insertable<CachedMarketplaceResponse> {
  final String cacheKey;
  final String? scopeUserId;
  final String payloadJson;
  final DateTime cachedAt;
  const CachedMarketplaceResponse({
    required this.cacheKey,
    this.scopeUserId,
    required this.payloadJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    if (!nullToAbsent || scopeUserId != null) {
      map['scope_user_id'] = Variable<String>(scopeUserId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedMarketplaceResponsesCompanion toCompanion(bool nullToAbsent) {
    return CachedMarketplaceResponsesCompanion(
      cacheKey: Value(cacheKey),
      scopeUserId: scopeUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(scopeUserId),
      payloadJson: Value(payloadJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedMarketplaceResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMarketplaceResponse(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      scopeUserId: serializer.fromJson<String?>(json['scopeUserId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'scopeUserId': serializer.toJson<String?>(scopeUserId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedMarketplaceResponse copyWith({
    String? cacheKey,
    Value<String?> scopeUserId = const Value.absent(),
    String? payloadJson,
    DateTime? cachedAt,
  }) => CachedMarketplaceResponse(
    cacheKey: cacheKey ?? this.cacheKey,
    scopeUserId: scopeUserId.present ? scopeUserId.value : this.scopeUserId,
    payloadJson: payloadJson ?? this.payloadJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedMarketplaceResponse copyWithCompanion(
    CachedMarketplaceResponsesCompanion data,
  ) {
    return CachedMarketplaceResponse(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      scopeUserId: data.scopeUserId.present
          ? data.scopeUserId.value
          : this.scopeUserId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMarketplaceResponse(')
          ..write('cacheKey: $cacheKey, ')
          ..write('scopeUserId: $scopeUserId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, scopeUserId, payloadJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMarketplaceResponse &&
          other.cacheKey == this.cacheKey &&
          other.scopeUserId == this.scopeUserId &&
          other.payloadJson == this.payloadJson &&
          other.cachedAt == this.cachedAt);
}

class CachedMarketplaceResponsesCompanion
    extends UpdateCompanion<CachedMarketplaceResponse> {
  final Value<String> cacheKey;
  final Value<String?> scopeUserId;
  final Value<String> payloadJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedMarketplaceResponsesCompanion({
    this.cacheKey = const Value.absent(),
    this.scopeUserId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMarketplaceResponsesCompanion.insert({
    required String cacheKey,
    this.scopeUserId = const Value.absent(),
    required String payloadJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payloadJson = Value(payloadJson),
       cachedAt = Value(cachedAt);
  static Insertable<CachedMarketplaceResponse> custom({
    Expression<String>? cacheKey,
    Expression<String>? scopeUserId,
    Expression<String>? payloadJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (scopeUserId != null) 'scope_user_id': scopeUserId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMarketplaceResponsesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String?>? scopeUserId,
    Value<String>? payloadJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedMarketplaceResponsesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      scopeUserId: scopeUserId ?? this.scopeUserId,
      payloadJson: payloadJson ?? this.payloadJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (scopeUserId.present) {
      map['scope_user_id'] = Variable<String>(scopeUserId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMarketplaceResponsesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('scopeUserId: $scopeUserId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingCommerceOperationsTable extends PendingCommerceOperations
    with TableInfo<$PendingCommerceOperationsTable, PendingCommerceOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingCommerceOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeUserIdMeta = const VerificationMeta(
    'scopeUserId',
  );
  @override
  late final GeneratedColumn<String> scopeUserId = GeneratedColumn<String>(
    'scope_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadFingerprintMeta =
      const VerificationMeta('payloadFingerprint');
  @override
  late final GeneratedColumn<String> payloadFingerprint =
      GeneratedColumn<String>(
        'payload_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    scopeUserId,
    operationType,
    resourceId,
    payloadFingerprint,
    idempotencyKey,
    payloadJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_commerce_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingCommerceOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('scope_user_id')) {
      context.handle(
        _scopeUserIdMeta,
        scopeUserId.isAcceptableOrUnknown(
          data['scope_user_id']!,
          _scopeUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scopeUserIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    }
    if (data.containsKey('payload_fingerprint')) {
      context.handle(
        _payloadFingerprintMeta,
        payloadFingerprint.isAcceptableOrUnknown(
          data['payload_fingerprint']!,
          _payloadFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadFingerprintMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scopeUserId, operationType, payloadFingerprint},
  ];
  @override
  PendingCommerceOperation map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingCommerceOperation(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      scopeUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_user_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      ),
      payloadFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_fingerprint'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingCommerceOperationsTable createAlias(String alias) {
    return $PendingCommerceOperationsTable(attachedDatabase, alias);
  }
}

class PendingCommerceOperation extends DataClass
    implements Insertable<PendingCommerceOperation> {
  final String operationId;
  final String scopeUserId;
  final String operationType;
  final String? resourceId;
  final String payloadFingerprint;
  final String idempotencyKey;
  final String payloadJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PendingCommerceOperation({
    required this.operationId,
    required this.scopeUserId,
    required this.operationType,
    this.resourceId,
    required this.payloadFingerprint,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['scope_user_id'] = Variable<String>(scopeUserId);
    map['operation_type'] = Variable<String>(operationType);
    if (!nullToAbsent || resourceId != null) {
      map['resource_id'] = Variable<String>(resourceId);
    }
    map['payload_fingerprint'] = Variable<String>(payloadFingerprint);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingCommerceOperationsCompanion toCompanion(bool nullToAbsent) {
    return PendingCommerceOperationsCompanion(
      operationId: Value(operationId),
      scopeUserId: Value(scopeUserId),
      operationType: Value(operationType),
      resourceId: resourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceId),
      payloadFingerprint: Value(payloadFingerprint),
      idempotencyKey: Value(idempotencyKey),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingCommerceOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingCommerceOperation(
      operationId: serializer.fromJson<String>(json['operationId']),
      scopeUserId: serializer.fromJson<String>(json['scopeUserId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      resourceId: serializer.fromJson<String?>(json['resourceId']),
      payloadFingerprint: serializer.fromJson<String>(
        json['payloadFingerprint'],
      ),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'scopeUserId': serializer.toJson<String>(scopeUserId),
      'operationType': serializer.toJson<String>(operationType),
      'resourceId': serializer.toJson<String?>(resourceId),
      'payloadFingerprint': serializer.toJson<String>(payloadFingerprint),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingCommerceOperation copyWith({
    String? operationId,
    String? scopeUserId,
    String? operationType,
    Value<String?> resourceId = const Value.absent(),
    String? payloadFingerprint,
    String? idempotencyKey,
    String? payloadJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PendingCommerceOperation(
    operationId: operationId ?? this.operationId,
    scopeUserId: scopeUserId ?? this.scopeUserId,
    operationType: operationType ?? this.operationType,
    resourceId: resourceId.present ? resourceId.value : this.resourceId,
    payloadFingerprint: payloadFingerprint ?? this.payloadFingerprint,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingCommerceOperation copyWithCompanion(
    PendingCommerceOperationsCompanion data,
  ) {
    return PendingCommerceOperation(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      scopeUserId: data.scopeUserId.present
          ? data.scopeUserId.value
          : this.scopeUserId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      payloadFingerprint: data.payloadFingerprint.present
          ? data.payloadFingerprint.value
          : this.payloadFingerprint,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingCommerceOperation(')
          ..write('operationId: $operationId, ')
          ..write('scopeUserId: $scopeUserId, ')
          ..write('operationType: $operationType, ')
          ..write('resourceId: $resourceId, ')
          ..write('payloadFingerprint: $payloadFingerprint, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    scopeUserId,
    operationType,
    resourceId,
    payloadFingerprint,
    idempotencyKey,
    payloadJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCommerceOperation &&
          other.operationId == this.operationId &&
          other.scopeUserId == this.scopeUserId &&
          other.operationType == this.operationType &&
          other.resourceId == this.resourceId &&
          other.payloadFingerprint == this.payloadFingerprint &&
          other.idempotencyKey == this.idempotencyKey &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingCommerceOperationsCompanion
    extends UpdateCompanion<PendingCommerceOperation> {
  final Value<String> operationId;
  final Value<String> scopeUserId;
  final Value<String> operationType;
  final Value<String?> resourceId;
  final Value<String> payloadFingerprint;
  final Value<String> idempotencyKey;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingCommerceOperationsCompanion({
    this.operationId = const Value.absent(),
    this.scopeUserId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.payloadFingerprint = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingCommerceOperationsCompanion.insert({
    required String operationId,
    required String scopeUserId,
    required String operationType,
    this.resourceId = const Value.absent(),
    required String payloadFingerprint,
    required String idempotencyKey,
    required String payloadJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       scopeUserId = Value(scopeUserId),
       operationType = Value(operationType),
       payloadFingerprint = Value(payloadFingerprint),
       idempotencyKey = Value(idempotencyKey),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingCommerceOperation> custom({
    Expression<String>? operationId,
    Expression<String>? scopeUserId,
    Expression<String>? operationType,
    Expression<String>? resourceId,
    Expression<String>? payloadFingerprint,
    Expression<String>? idempotencyKey,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (scopeUserId != null) 'scope_user_id': scopeUserId,
      if (operationType != null) 'operation_type': operationType,
      if (resourceId != null) 'resource_id': resourceId,
      if (payloadFingerprint != null) 'payload_fingerprint': payloadFingerprint,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingCommerceOperationsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? scopeUserId,
    Value<String>? operationType,
    Value<String?>? resourceId,
    Value<String>? payloadFingerprint,
    Value<String>? idempotencyKey,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingCommerceOperationsCompanion(
      operationId: operationId ?? this.operationId,
      scopeUserId: scopeUserId ?? this.scopeUserId,
      operationType: operationType ?? this.operationType,
      resourceId: resourceId ?? this.resourceId,
      payloadFingerprint: payloadFingerprint ?? this.payloadFingerprint,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (scopeUserId.present) {
      map['scope_user_id'] = Variable<String>(scopeUserId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (payloadFingerprint.present) {
      map['payload_fingerprint'] = Variable<String>(payloadFingerprint.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingCommerceOperationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('scopeUserId: $scopeUserId, ')
          ..write('operationType: $operationType, ')
          ..write('resourceId: $resourceId, ')
          ..write('payloadFingerprint: $payloadFingerprint, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedFieldsTable cachedFields = $CachedFieldsTable(this);
  late final $CachedCropCyclesTable cachedCropCycles = $CachedCropCyclesTable(
    this,
  );
  late final $PendingMutationsTable pendingMutations = $PendingMutationsTable(
    this,
  );
  late final $CachedMarketplaceResponsesTable cachedMarketplaceResponses =
      $CachedMarketplaceResponsesTable(this);
  late final $PendingCommerceOperationsTable pendingCommerceOperations =
      $PendingCommerceOperationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedFields,
    cachedCropCycles,
    pendingMutations,
    cachedMarketplaceResponses,
    pendingCommerceOperations,
  ];
}

typedef $$CachedFieldsTableCreateCompanionBuilder =
    CachedFieldsCompanion Function({
      required String serverId,
      required String payloadJson,
      required int serverVersion,
      required DateTime serverCreatedAt,
      required DateTime serverUpdatedAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedFieldsTableUpdateCompanionBuilder =
    CachedFieldsCompanion Function({
      Value<String> serverId,
      Value<String> payloadJson,
      Value<int> serverVersion,
      Value<DateTime> serverCreatedAt,
      Value<DateTime> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedFieldsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedFieldsTable> {
  $$CachedFieldsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedFieldsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedFieldsTable> {
  $$CachedFieldsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedFieldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedFieldsTable> {
  $$CachedFieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedFieldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedFieldsTable,
          CachedField,
          $$CachedFieldsTableFilterComposer,
          $$CachedFieldsTableOrderingComposer,
          $$CachedFieldsTableAnnotationComposer,
          $$CachedFieldsTableCreateCompanionBuilder,
          $$CachedFieldsTableUpdateCompanionBuilder,
          (
            CachedField,
            BaseReferences<_$AppDatabase, $CachedFieldsTable, CachedField>,
          ),
          CachedField,
          PrefetchHooks Function()
        > {
  $$CachedFieldsTableTableManager(_$AppDatabase db, $CachedFieldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedFieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedFieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedFieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<DateTime> serverCreatedAt = const Value.absent(),
                Value<DateTime> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFieldsCompanion(
                serverId: serverId,
                payloadJson: payloadJson,
                serverVersion: serverVersion,
                serverCreatedAt: serverCreatedAt,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String payloadJson,
                required int serverVersion,
                required DateTime serverCreatedAt,
                required DateTime serverUpdatedAt,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedFieldsCompanion.insert(
                serverId: serverId,
                payloadJson: payloadJson,
                serverVersion: serverVersion,
                serverCreatedAt: serverCreatedAt,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedFieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedFieldsTable,
      CachedField,
      $$CachedFieldsTableFilterComposer,
      $$CachedFieldsTableOrderingComposer,
      $$CachedFieldsTableAnnotationComposer,
      $$CachedFieldsTableCreateCompanionBuilder,
      $$CachedFieldsTableUpdateCompanionBuilder,
      (
        CachedField,
        BaseReferences<_$AppDatabase, $CachedFieldsTable, CachedField>,
      ),
      CachedField,
      PrefetchHooks Function()
    >;
typedef $$CachedCropCyclesTableCreateCompanionBuilder =
    CachedCropCyclesCompanion Function({
      required String serverId,
      required String fieldServerId,
      required String payloadJson,
      required int serverVersion,
      required DateTime serverCreatedAt,
      required DateTime serverUpdatedAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedCropCyclesTableUpdateCompanionBuilder =
    CachedCropCyclesCompanion Function({
      Value<String> serverId,
      Value<String> fieldServerId,
      Value<String> payloadJson,
      Value<int> serverVersion,
      Value<DateTime> serverCreatedAt,
      Value<DateTime> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedCropCyclesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCropCyclesTable> {
  $$CachedCropCyclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldServerId => $composableBuilder(
    column: $table.fieldServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCropCyclesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCropCyclesTable> {
  $$CachedCropCyclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldServerId => $composableBuilder(
    column: $table.fieldServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCropCyclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCropCyclesTable> {
  $$CachedCropCyclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get fieldServerId => $composableBuilder(
    column: $table.fieldServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedCropCyclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCropCyclesTable,
          CachedCropCycle,
          $$CachedCropCyclesTableFilterComposer,
          $$CachedCropCyclesTableOrderingComposer,
          $$CachedCropCyclesTableAnnotationComposer,
          $$CachedCropCyclesTableCreateCompanionBuilder,
          $$CachedCropCyclesTableUpdateCompanionBuilder,
          (
            CachedCropCycle,
            BaseReferences<
              _$AppDatabase,
              $CachedCropCyclesTable,
              CachedCropCycle
            >,
          ),
          CachedCropCycle,
          PrefetchHooks Function()
        > {
  $$CachedCropCyclesTableTableManager(
    _$AppDatabase db,
    $CachedCropCyclesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCropCyclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCropCyclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCropCyclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> fieldServerId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<DateTime> serverCreatedAt = const Value.absent(),
                Value<DateTime> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCropCyclesCompanion(
                serverId: serverId,
                fieldServerId: fieldServerId,
                payloadJson: payloadJson,
                serverVersion: serverVersion,
                serverCreatedAt: serverCreatedAt,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String fieldServerId,
                required String payloadJson,
                required int serverVersion,
                required DateTime serverCreatedAt,
                required DateTime serverUpdatedAt,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCropCyclesCompanion.insert(
                serverId: serverId,
                fieldServerId: fieldServerId,
                payloadJson: payloadJson,
                serverVersion: serverVersion,
                serverCreatedAt: serverCreatedAt,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCropCyclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCropCyclesTable,
      CachedCropCycle,
      $$CachedCropCyclesTableFilterComposer,
      $$CachedCropCyclesTableOrderingComposer,
      $$CachedCropCyclesTableAnnotationComposer,
      $$CachedCropCyclesTableCreateCompanionBuilder,
      $$CachedCropCyclesTableUpdateCompanionBuilder,
      (
        CachedCropCycle,
        BaseReferences<_$AppDatabase, $CachedCropCyclesTable, CachedCropCycle>,
      ),
      CachedCropCycle,
      PrefetchHooks Function()
    >;
typedef $$PendingMutationsTableCreateCompanionBuilder =
    PendingMutationsCompanion Function({
      required String mutationId,
      required String type,
      required String payloadJson,
      required String idempotencyKey,
      Value<String?> targetServerId,
      Value<String?> parentMutationId,
      Value<String?> resolvedServerId,
      required String status,
      Value<int> attemptCount,
      Value<String?> lastErrorCode,
      Value<String?> lastErrorMessage,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PendingMutationsTableUpdateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<String> mutationId,
      Value<String> type,
      Value<String> payloadJson,
      Value<String> idempotencyKey,
      Value<String?> targetServerId,
      Value<String?> parentMutationId,
      Value<String?> resolvedServerId,
      Value<String> status,
      Value<int> attemptCount,
      Value<String?> lastErrorCode,
      Value<String?> lastErrorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetServerId => $composableBuilder(
    column: $table.targetServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentMutationId => $composableBuilder(
    column: $table.parentMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedServerId => $composableBuilder(
    column: $table.resolvedServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetServerId => $composableBuilder(
    column: $table.targetServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentMutationId => $composableBuilder(
    column: $table.parentMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedServerId => $composableBuilder(
    column: $table.resolvedServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetServerId => $composableBuilder(
    column: $table.targetServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentMutationId => $composableBuilder(
    column: $table.parentMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedServerId => $composableBuilder(
    column: $table.resolvedServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMutationsTable,
          PendingMutation,
          $$PendingMutationsTableFilterComposer,
          $$PendingMutationsTableOrderingComposer,
          $$PendingMutationsTableAnnotationComposer,
          $$PendingMutationsTableCreateCompanionBuilder,
          $$PendingMutationsTableUpdateCompanionBuilder,
          (
            PendingMutation,
            BaseReferences<
              _$AppDatabase,
              $PendingMutationsTable,
              PendingMutation
            >,
          ),
          PendingMutation,
          PrefetchHooks Function()
        > {
  $$PendingMutationsTableTableManager(
    _$AppDatabase db,
    $PendingMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String?> targetServerId = const Value.absent(),
                Value<String?> parentMutationId = const Value.absent(),
                Value<String?> resolvedServerId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion(
                mutationId: mutationId,
                type: type,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                targetServerId: targetServerId,
                parentMutationId: parentMutationId,
                resolvedServerId: resolvedServerId,
                status: status,
                attemptCount: attemptCount,
                lastErrorCode: lastErrorCode,
                lastErrorMessage: lastErrorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String type,
                required String payloadJson,
                required String idempotencyKey,
                Value<String?> targetServerId = const Value.absent(),
                Value<String?> parentMutationId = const Value.absent(),
                Value<String?> resolvedServerId = const Value.absent(),
                required String status,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion.insert(
                mutationId: mutationId,
                type: type,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                targetServerId: targetServerId,
                parentMutationId: parentMutationId,
                resolvedServerId: resolvedServerId,
                status: status,
                attemptCount: attemptCount,
                lastErrorCode: lastErrorCode,
                lastErrorMessage: lastErrorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMutationsTable,
      PendingMutation,
      $$PendingMutationsTableFilterComposer,
      $$PendingMutationsTableOrderingComposer,
      $$PendingMutationsTableAnnotationComposer,
      $$PendingMutationsTableCreateCompanionBuilder,
      $$PendingMutationsTableUpdateCompanionBuilder,
      (
        PendingMutation,
        BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation>,
      ),
      PendingMutation,
      PrefetchHooks Function()
    >;
typedef $$CachedMarketplaceResponsesTableCreateCompanionBuilder =
    CachedMarketplaceResponsesCompanion Function({
      required String cacheKey,
      Value<String?> scopeUserId,
      required String payloadJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedMarketplaceResponsesTableUpdateCompanionBuilder =
    CachedMarketplaceResponsesCompanion Function({
      Value<String> cacheKey,
      Value<String?> scopeUserId,
      Value<String> payloadJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedMarketplaceResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMarketplaceResponsesTable> {
  $$CachedMarketplaceResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeUserId => $composableBuilder(
    column: $table.scopeUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMarketplaceResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMarketplaceResponsesTable> {
  $$CachedMarketplaceResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeUserId => $composableBuilder(
    column: $table.scopeUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMarketplaceResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMarketplaceResponsesTable> {
  $$CachedMarketplaceResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get scopeUserId => $composableBuilder(
    column: $table.scopeUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedMarketplaceResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMarketplaceResponsesTable,
          CachedMarketplaceResponse,
          $$CachedMarketplaceResponsesTableFilterComposer,
          $$CachedMarketplaceResponsesTableOrderingComposer,
          $$CachedMarketplaceResponsesTableAnnotationComposer,
          $$CachedMarketplaceResponsesTableCreateCompanionBuilder,
          $$CachedMarketplaceResponsesTableUpdateCompanionBuilder,
          (
            CachedMarketplaceResponse,
            BaseReferences<
              _$AppDatabase,
              $CachedMarketplaceResponsesTable,
              CachedMarketplaceResponse
            >,
          ),
          CachedMarketplaceResponse,
          PrefetchHooks Function()
        > {
  $$CachedMarketplaceResponsesTableTableManager(
    _$AppDatabase db,
    $CachedMarketplaceResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMarketplaceResponsesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedMarketplaceResponsesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedMarketplaceResponsesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String?> scopeUserId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMarketplaceResponsesCompanion(
                cacheKey: cacheKey,
                scopeUserId: scopeUserId,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                Value<String?> scopeUserId = const Value.absent(),
                required String payloadJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedMarketplaceResponsesCompanion.insert(
                cacheKey: cacheKey,
                scopeUserId: scopeUserId,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMarketplaceResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMarketplaceResponsesTable,
      CachedMarketplaceResponse,
      $$CachedMarketplaceResponsesTableFilterComposer,
      $$CachedMarketplaceResponsesTableOrderingComposer,
      $$CachedMarketplaceResponsesTableAnnotationComposer,
      $$CachedMarketplaceResponsesTableCreateCompanionBuilder,
      $$CachedMarketplaceResponsesTableUpdateCompanionBuilder,
      (
        CachedMarketplaceResponse,
        BaseReferences<
          _$AppDatabase,
          $CachedMarketplaceResponsesTable,
          CachedMarketplaceResponse
        >,
      ),
      CachedMarketplaceResponse,
      PrefetchHooks Function()
    >;
typedef $$PendingCommerceOperationsTableCreateCompanionBuilder =
    PendingCommerceOperationsCompanion Function({
      required String operationId,
      required String scopeUserId,
      required String operationType,
      Value<String?> resourceId,
      required String payloadFingerprint,
      required String idempotencyKey,
      required String payloadJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PendingCommerceOperationsTableUpdateCompanionBuilder =
    PendingCommerceOperationsCompanion Function({
      Value<String> operationId,
      Value<String> scopeUserId,
      Value<String> operationType,
      Value<String?> resourceId,
      Value<String> payloadFingerprint,
      Value<String> idempotencyKey,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingCommerceOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingCommerceOperationsTable> {
  $$PendingCommerceOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeUserId => $composableBuilder(
    column: $table.scopeUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadFingerprint => $composableBuilder(
    column: $table.payloadFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingCommerceOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingCommerceOperationsTable> {
  $$PendingCommerceOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeUserId => $composableBuilder(
    column: $table.scopeUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadFingerprint => $composableBuilder(
    column: $table.payloadFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingCommerceOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingCommerceOperationsTable> {
  $$PendingCommerceOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scopeUserId => $composableBuilder(
    column: $table.scopeUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadFingerprint => $composableBuilder(
    column: $table.payloadFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingCommerceOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingCommerceOperationsTable,
          PendingCommerceOperation,
          $$PendingCommerceOperationsTableFilterComposer,
          $$PendingCommerceOperationsTableOrderingComposer,
          $$PendingCommerceOperationsTableAnnotationComposer,
          $$PendingCommerceOperationsTableCreateCompanionBuilder,
          $$PendingCommerceOperationsTableUpdateCompanionBuilder,
          (
            PendingCommerceOperation,
            BaseReferences<
              _$AppDatabase,
              $PendingCommerceOperationsTable,
              PendingCommerceOperation
            >,
          ),
          PendingCommerceOperation,
          PrefetchHooks Function()
        > {
  $$PendingCommerceOperationsTableTableManager(
    _$AppDatabase db,
    $PendingCommerceOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingCommerceOperationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingCommerceOperationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingCommerceOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> scopeUserId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String?> resourceId = const Value.absent(),
                Value<String> payloadFingerprint = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingCommerceOperationsCompanion(
                operationId: operationId,
                scopeUserId: scopeUserId,
                operationType: operationType,
                resourceId: resourceId,
                payloadFingerprint: payloadFingerprint,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String scopeUserId,
                required String operationType,
                Value<String?> resourceId = const Value.absent(),
                required String payloadFingerprint,
                required String idempotencyKey,
                required String payloadJson,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingCommerceOperationsCompanion.insert(
                operationId: operationId,
                scopeUserId: scopeUserId,
                operationType: operationType,
                resourceId: resourceId,
                payloadFingerprint: payloadFingerprint,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingCommerceOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingCommerceOperationsTable,
      PendingCommerceOperation,
      $$PendingCommerceOperationsTableFilterComposer,
      $$PendingCommerceOperationsTableOrderingComposer,
      $$PendingCommerceOperationsTableAnnotationComposer,
      $$PendingCommerceOperationsTableCreateCompanionBuilder,
      $$PendingCommerceOperationsTableUpdateCompanionBuilder,
      (
        PendingCommerceOperation,
        BaseReferences<
          _$AppDatabase,
          $PendingCommerceOperationsTable,
          PendingCommerceOperation
        >,
      ),
      PendingCommerceOperation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedFieldsTableTableManager get cachedFields =>
      $$CachedFieldsTableTableManager(_db, _db.cachedFields);
  $$CachedCropCyclesTableTableManager get cachedCropCycles =>
      $$CachedCropCyclesTableTableManager(_db, _db.cachedCropCycles);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$CachedMarketplaceResponsesTableTableManager
  get cachedMarketplaceResponses =>
      $$CachedMarketplaceResponsesTableTableManager(
        _db,
        _db.cachedMarketplaceResponses,
      );
  $$PendingCommerceOperationsTableTableManager get pendingCommerceOperations =>
      $$PendingCommerceOperationsTableTableManager(
        _db,
        _db.pendingCommerceOperations,
      );
}

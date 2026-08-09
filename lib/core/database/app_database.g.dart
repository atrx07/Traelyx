// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAtMicros];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final int updatedAtMicros;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  AppSetting copyWith({String? key, String? value, int? updatedAtMicros}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAtMicros);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNamespaceMeta = const VerificationMeta(
    'ownerNamespace',
  );
  @override
  late final GeneratedColumn<String> ownerNamespace = GeneratedColumn<String>(
    'owner_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleTypeMeta = const VerificationMeta(
    'vehicleType',
  );
  @override
  late final GeneratedColumn<String> vehicleType = GeneratedColumn<String>(
    'vehicle_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manufacturerMeta = const VerificationMeta(
    'manufacturer',
  );
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
    'manufacturer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelYearMeta = const VerificationMeta(
    'modelYear',
  );
  @override
  late final GeneratedColumn<int> modelYear = GeneratedColumn<int>(
    'model_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calibrationMetadataJsonMeta =
      const VerificationMeta('calibrationMetadataJson');
  @override
  late final GeneratedColumn<String> calibrationMetadataJson =
      GeneratedColumn<String>(
        'calibration_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _baselineMetadataJsonMeta =
      const VerificationMeta('baselineMetadataJson');
  @override
  late final GeneratedColumn<String> baselineMetadataJson =
      GeneratedColumn<String>(
        'baseline_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerNamespace,
    displayName,
    vehicleType,
    manufacturer,
    model,
    modelYear,
    calibrationMetadataJson,
    baselineMetadataJson,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_namespace')) {
      context.handle(
        _ownerNamespaceMeta,
        ownerNamespace.isAcceptableOrUnknown(
          data['owner_namespace']!,
          _ownerNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerNamespaceMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('vehicle_type')) {
      context.handle(
        _vehicleTypeMeta,
        vehicleType.isAcceptableOrUnknown(
          data['vehicle_type']!,
          _vehicleTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vehicleTypeMeta);
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
        _manufacturerMeta,
        manufacturer.isAcceptableOrUnknown(
          data['manufacturer']!,
          _manufacturerMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('model_year')) {
      context.handle(
        _modelYearMeta,
        modelYear.isAcceptableOrUnknown(data['model_year']!, _modelYearMeta),
      );
    }
    if (data.containsKey('calibration_metadata_json')) {
      context.handle(
        _calibrationMetadataJsonMeta,
        calibrationMetadataJson.isAcceptableOrUnknown(
          data['calibration_metadata_json']!,
          _calibrationMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('baseline_metadata_json')) {
      context.handle(
        _baselineMetadataJsonMeta,
        baselineMetadataJson.isAcceptableOrUnknown(
          data['baseline_metadata_json']!,
          _baselineMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_namespace'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      vehicleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_type'],
      )!,
      manufacturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      modelYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model_year'],
      ),
      calibrationMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calibration_metadata_json'],
      ),
      baselineMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_metadata_json'],
      ),
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final String id;
  final String ownerNamespace;
  final String displayName;
  final String vehicleType;
  final String? manufacturer;
  final String? model;
  final int? modelYear;
  final String? calibrationMetadataJson;
  final String? baselineMetadataJson;
  final int createdAtMicros;
  final int updatedAtMicros;
  const Vehicle({
    required this.id,
    required this.ownerNamespace,
    required this.displayName,
    required this.vehicleType,
    this.manufacturer,
    this.model,
    this.modelYear,
    this.calibrationMetadataJson,
    this.baselineMetadataJson,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_namespace'] = Variable<String>(ownerNamespace);
    map['display_name'] = Variable<String>(displayName);
    map['vehicle_type'] = Variable<String>(vehicleType);
    if (!nullToAbsent || manufacturer != null) {
      map['manufacturer'] = Variable<String>(manufacturer);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || modelYear != null) {
      map['model_year'] = Variable<int>(modelYear);
    }
    if (!nullToAbsent || calibrationMetadataJson != null) {
      map['calibration_metadata_json'] = Variable<String>(
        calibrationMetadataJson,
      );
    }
    if (!nullToAbsent || baselineMetadataJson != null) {
      map['baseline_metadata_json'] = Variable<String>(baselineMetadataJson);
    }
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      ownerNamespace: Value(ownerNamespace),
      displayName: Value(displayName),
      vehicleType: Value(vehicleType),
      manufacturer: manufacturer == null && nullToAbsent
          ? const Value.absent()
          : Value(manufacturer),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      modelYear: modelYear == null && nullToAbsent
          ? const Value.absent()
          : Value(modelYear),
      calibrationMetadataJson: calibrationMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(calibrationMetadataJson),
      baselineMetadataJson: baselineMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineMetadataJson),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory Vehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<String>(json['id']),
      ownerNamespace: serializer.fromJson<String>(json['ownerNamespace']),
      displayName: serializer.fromJson<String>(json['displayName']),
      vehicleType: serializer.fromJson<String>(json['vehicleType']),
      manufacturer: serializer.fromJson<String?>(json['manufacturer']),
      model: serializer.fromJson<String?>(json['model']),
      modelYear: serializer.fromJson<int?>(json['modelYear']),
      calibrationMetadataJson: serializer.fromJson<String?>(
        json['calibrationMetadataJson'],
      ),
      baselineMetadataJson: serializer.fromJson<String?>(
        json['baselineMetadataJson'],
      ),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerNamespace': serializer.toJson<String>(ownerNamespace),
      'displayName': serializer.toJson<String>(displayName),
      'vehicleType': serializer.toJson<String>(vehicleType),
      'manufacturer': serializer.toJson<String?>(manufacturer),
      'model': serializer.toJson<String?>(model),
      'modelYear': serializer.toJson<int?>(modelYear),
      'calibrationMetadataJson': serializer.toJson<String?>(
        calibrationMetadataJson,
      ),
      'baselineMetadataJson': serializer.toJson<String?>(baselineMetadataJson),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  Vehicle copyWith({
    String? id,
    String? ownerNamespace,
    String? displayName,
    String? vehicleType,
    Value<String?> manufacturer = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> modelYear = const Value.absent(),
    Value<String?> calibrationMetadataJson = const Value.absent(),
    Value<String?> baselineMetadataJson = const Value.absent(),
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => Vehicle(
    id: id ?? this.id,
    ownerNamespace: ownerNamespace ?? this.ownerNamespace,
    displayName: displayName ?? this.displayName,
    vehicleType: vehicleType ?? this.vehicleType,
    manufacturer: manufacturer.present ? manufacturer.value : this.manufacturer,
    model: model.present ? model.value : this.model,
    modelYear: modelYear.present ? modelYear.value : this.modelYear,
    calibrationMetadataJson: calibrationMetadataJson.present
        ? calibrationMetadataJson.value
        : this.calibrationMetadataJson,
    baselineMetadataJson: baselineMetadataJson.present
        ? baselineMetadataJson.value
        : this.baselineMetadataJson,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      ownerNamespace: data.ownerNamespace.present
          ? data.ownerNamespace.value
          : this.ownerNamespace,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      vehicleType: data.vehicleType.present
          ? data.vehicleType.value
          : this.vehicleType,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      model: data.model.present ? data.model.value : this.model,
      modelYear: data.modelYear.present ? data.modelYear.value : this.modelYear,
      calibrationMetadataJson: data.calibrationMetadataJson.present
          ? data.calibrationMetadataJson.value
          : this.calibrationMetadataJson,
      baselineMetadataJson: data.baselineMetadataJson.present
          ? data.baselineMetadataJson.value
          : this.baselineMetadataJson,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('ownerNamespace: $ownerNamespace, ')
          ..write('displayName: $displayName, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('modelYear: $modelYear, ')
          ..write('calibrationMetadataJson: $calibrationMetadataJson, ')
          ..write('baselineMetadataJson: $baselineMetadataJson, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerNamespace,
    displayName,
    vehicleType,
    manufacturer,
    model,
    modelYear,
    calibrationMetadataJson,
    baselineMetadataJson,
    createdAtMicros,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.ownerNamespace == this.ownerNamespace &&
          other.displayName == this.displayName &&
          other.vehicleType == this.vehicleType &&
          other.manufacturer == this.manufacturer &&
          other.model == this.model &&
          other.modelYear == this.modelYear &&
          other.calibrationMetadataJson == this.calibrationMetadataJson &&
          other.baselineMetadataJson == this.baselineMetadataJson &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<String> id;
  final Value<String> ownerNamespace;
  final Value<String> displayName;
  final Value<String> vehicleType;
  final Value<String?> manufacturer;
  final Value<String?> model;
  final Value<int?> modelYear;
  final Value<String?> calibrationMetadataJson;
  final Value<String?> baselineMetadataJson;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.ownerNamespace = const Value.absent(),
    this.displayName = const Value.absent(),
    this.vehicleType = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.modelYear = const Value.absent(),
    this.calibrationMetadataJson = const Value.absent(),
    this.baselineMetadataJson = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    required String ownerNamespace,
    required String displayName,
    required String vehicleType,
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.modelYear = const Value.absent(),
    this.calibrationMetadataJson = const Value.absent(),
    this.baselineMetadataJson = const Value.absent(),
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerNamespace = Value(ownerNamespace),
       displayName = Value(displayName),
       vehicleType = Value(vehicleType),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<Vehicle> custom({
    Expression<String>? id,
    Expression<String>? ownerNamespace,
    Expression<String>? displayName,
    Expression<String>? vehicleType,
    Expression<String>? manufacturer,
    Expression<String>? model,
    Expression<int>? modelYear,
    Expression<String>? calibrationMetadataJson,
    Expression<String>? baselineMetadataJson,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerNamespace != null) 'owner_namespace': ownerNamespace,
      if (displayName != null) 'display_name': displayName,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (modelYear != null) 'model_year': modelYear,
      if (calibrationMetadataJson != null)
        'calibration_metadata_json': calibrationMetadataJson,
      if (baselineMetadataJson != null)
        'baseline_metadata_json': baselineMetadataJson,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerNamespace,
    Value<String>? displayName,
    Value<String>? vehicleType,
    Value<String?>? manufacturer,
    Value<String?>? model,
    Value<int?>? modelYear,
    Value<String?>? calibrationMetadataJson,
    Value<String?>? baselineMetadataJson,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      ownerNamespace: ownerNamespace ?? this.ownerNamespace,
      displayName: displayName ?? this.displayName,
      vehicleType: vehicleType ?? this.vehicleType,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      modelYear: modelYear ?? this.modelYear,
      calibrationMetadataJson:
          calibrationMetadataJson ?? this.calibrationMetadataJson,
      baselineMetadataJson: baselineMetadataJson ?? this.baselineMetadataJson,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerNamespace.present) {
      map['owner_namespace'] = Variable<String>(ownerNamespace.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (vehicleType.present) {
      map['vehicle_type'] = Variable<String>(vehicleType.value);
    }
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (modelYear.present) {
      map['model_year'] = Variable<int>(modelYear.value);
    }
    if (calibrationMetadataJson.present) {
      map['calibration_metadata_json'] = Variable<String>(
        calibrationMetadataJson.value,
      );
    }
    if (baselineMetadataJson.present) {
      map['baseline_metadata_json'] = Variable<String>(
        baselineMetadataJson.value,
      );
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('ownerNamespace: $ownerNamespace, ')
          ..write('displayName: $displayName, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('modelYear: $modelYear, ')
          ..write('calibrationMetadataJson: $calibrationMetadataJson, ')
          ..write('baselineMetadataJson: $baselineMetadataJson, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _startWallTimeMicrosMeta =
      const VerificationMeta('startWallTimeMicros');
  @override
  late final GeneratedColumn<int> startWallTimeMicros = GeneratedColumn<int>(
    'start_wall_time_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endWallTimeMicrosMeta = const VerificationMeta(
    'endWallTimeMicros',
  );
  @override
  late final GeneratedColumn<int> endWallTimeMicros = GeneratedColumn<int>(
    'end_wall_time_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startElapsedNanosMeta = const VerificationMeta(
    'startElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> startElapsedNanos = GeneratedColumn<int>(
    'start_elapsed_nanos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endElapsedNanosMeta = const VerificationMeta(
    'endElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> endElapsedNanos = GeneratedColumn<int>(
    'end_elapsed_nanos',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMillisMeta = const VerificationMeta(
    'durationMillis',
  );
  @override
  late final GeneratedColumn<int> durationMillis = GeneratedColumn<int>(
    'duration_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionStateMeta = const VerificationMeta(
    'completionState',
  );
  @override
  late final GeneratedColumn<String> completionState = GeneratedColumn<String>(
    'completion_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recoveryStateMeta = const VerificationMeta(
    'recoveryState',
  );
  @override
  late final GeneratedColumn<String> recoveryState = GeneratedColumn<String>(
    'recovery_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _telemetrySchemaVersionMeta =
      const VerificationMeta('telemetrySchemaVersion');
  @override
  late final GeneratedColumn<int> telemetrySchemaVersion = GeneratedColumn<int>(
    'telemetry_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoringVersionMeta = const VerificationMeta(
    'scoringVersion',
  );
  @override
  late final GeneratedColumn<String> scoringVersion = GeneratedColumn<String>(
    'scoring_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventEngineVersionMeta =
      const VerificationMeta('eventEngineVersion');
  @override
  late final GeneratedColumn<String> eventEngineVersion =
      GeneratedColumn<String>(
        'event_engine_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mlModelRefsJsonMeta = const VerificationMeta(
    'mlModelRefsJson',
  );
  @override
  late final GeneratedColumn<String> mlModelRefsJson = GeneratedColumn<String>(
    'ml_model_refs_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _integrityStatusMeta = const VerificationMeta(
    'integrityStatus',
  );
  @override
  late final GeneratedColumn<String> integrityStatus = GeneratedColumn<String>(
    'integrity_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _telemetryConfidenceMeta =
      const VerificationMeta('telemetryConfidence');
  @override
  late final GeneratedColumn<double> telemetryConfidence =
      GeneratedColumn<double>(
        'telemetry_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _telemetryQualitySummaryJsonMeta =
      const VerificationMeta('telemetryQualitySummaryJson');
  @override
  late final GeneratedColumn<String> telemetryQualitySummaryJson =
      GeneratedColumn<String>(
        'telemetry_quality_summary_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cloudSyncStateMeta = const VerificationMeta(
    'cloudSyncState',
  );
  @override
  late final GeneratedColumn<String> cloudSyncState = GeneratedColumn<String>(
    'cloud_sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    startWallTimeMicros,
    endWallTimeMicros,
    startElapsedNanos,
    endElapsedNanos,
    durationMillis,
    distanceMeters,
    completionState,
    recoveryState,
    telemetrySchemaVersion,
    scoringVersion,
    eventEngineVersion,
    mlModelRefsJson,
    integrityStatus,
    telemetryConfidence,
    telemetryQualitySummaryJson,
    cloudSyncState,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('start_wall_time_micros')) {
      context.handle(
        _startWallTimeMicrosMeta,
        startWallTimeMicros.isAcceptableOrUnknown(
          data['start_wall_time_micros']!,
          _startWallTimeMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startWallTimeMicrosMeta);
    }
    if (data.containsKey('end_wall_time_micros')) {
      context.handle(
        _endWallTimeMicrosMeta,
        endWallTimeMicros.isAcceptableOrUnknown(
          data['end_wall_time_micros']!,
          _endWallTimeMicrosMeta,
        ),
      );
    }
    if (data.containsKey('start_elapsed_nanos')) {
      context.handle(
        _startElapsedNanosMeta,
        startElapsedNanos.isAcceptableOrUnknown(
          data['start_elapsed_nanos']!,
          _startElapsedNanosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startElapsedNanosMeta);
    }
    if (data.containsKey('end_elapsed_nanos')) {
      context.handle(
        _endElapsedNanosMeta,
        endElapsedNanos.isAcceptableOrUnknown(
          data['end_elapsed_nanos']!,
          _endElapsedNanosMeta,
        ),
      );
    }
    if (data.containsKey('duration_millis')) {
      context.handle(
        _durationMillisMeta,
        durationMillis.isAcceptableOrUnknown(
          data['duration_millis']!,
          _durationMillisMeta,
        ),
      );
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('completion_state')) {
      context.handle(
        _completionStateMeta,
        completionState.isAcceptableOrUnknown(
          data['completion_state']!,
          _completionStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completionStateMeta);
    }
    if (data.containsKey('recovery_state')) {
      context.handle(
        _recoveryStateMeta,
        recoveryState.isAcceptableOrUnknown(
          data['recovery_state']!,
          _recoveryStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recoveryStateMeta);
    }
    if (data.containsKey('telemetry_schema_version')) {
      context.handle(
        _telemetrySchemaVersionMeta,
        telemetrySchemaVersion.isAcceptableOrUnknown(
          data['telemetry_schema_version']!,
          _telemetrySchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_telemetrySchemaVersionMeta);
    }
    if (data.containsKey('scoring_version')) {
      context.handle(
        _scoringVersionMeta,
        scoringVersion.isAcceptableOrUnknown(
          data['scoring_version']!,
          _scoringVersionMeta,
        ),
      );
    }
    if (data.containsKey('event_engine_version')) {
      context.handle(
        _eventEngineVersionMeta,
        eventEngineVersion.isAcceptableOrUnknown(
          data['event_engine_version']!,
          _eventEngineVersionMeta,
        ),
      );
    }
    if (data.containsKey('ml_model_refs_json')) {
      context.handle(
        _mlModelRefsJsonMeta,
        mlModelRefsJson.isAcceptableOrUnknown(
          data['ml_model_refs_json']!,
          _mlModelRefsJsonMeta,
        ),
      );
    }
    if (data.containsKey('integrity_status')) {
      context.handle(
        _integrityStatusMeta,
        integrityStatus.isAcceptableOrUnknown(
          data['integrity_status']!,
          _integrityStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_integrityStatusMeta);
    }
    if (data.containsKey('telemetry_confidence')) {
      context.handle(
        _telemetryConfidenceMeta,
        telemetryConfidence.isAcceptableOrUnknown(
          data['telemetry_confidence']!,
          _telemetryConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('telemetry_quality_summary_json')) {
      context.handle(
        _telemetryQualitySummaryJsonMeta,
        telemetryQualitySummaryJson.isAcceptableOrUnknown(
          data['telemetry_quality_summary_json']!,
          _telemetryQualitySummaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('cloud_sync_state')) {
      context.handle(
        _cloudSyncStateMeta,
        cloudSyncState.isAcceptableOrUnknown(
          data['cloud_sync_state']!,
          _cloudSyncStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cloudSyncStateMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      startWallTimeMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_wall_time_micros'],
      )!,
      endWallTimeMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_wall_time_micros'],
      ),
      startElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_elapsed_nanos'],
      )!,
      endElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_elapsed_nanos'],
      ),
      durationMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_millis'],
      ),
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      ),
      completionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_state'],
      )!,
      recoveryState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recovery_state'],
      )!,
      telemetrySchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}telemetry_schema_version'],
      )!,
      scoringVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scoring_version'],
      ),
      eventEngineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_engine_version'],
      ),
      mlModelRefsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ml_model_refs_json'],
      ),
      integrityStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}integrity_status'],
      )!,
      telemetryConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}telemetry_confidence'],
      ),
      telemetryQualitySummaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telemetry_quality_summary_json'],
      ),
      cloudSyncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_sync_state'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final String id;
  final String vehicleId;
  final int startWallTimeMicros;
  final int? endWallTimeMicros;
  final int startElapsedNanos;
  final int? endElapsedNanos;
  final int? durationMillis;
  final double? distanceMeters;
  final String completionState;
  final String recoveryState;
  final int telemetrySchemaVersion;
  final String? scoringVersion;
  final String? eventEngineVersion;
  final String? mlModelRefsJson;
  final String integrityStatus;
  final double? telemetryConfidence;
  final String? telemetryQualitySummaryJson;
  final String cloudSyncState;
  final int createdAtMicros;
  final int updatedAtMicros;
  const Trip({
    required this.id,
    required this.vehicleId,
    required this.startWallTimeMicros,
    this.endWallTimeMicros,
    required this.startElapsedNanos,
    this.endElapsedNanos,
    this.durationMillis,
    this.distanceMeters,
    required this.completionState,
    required this.recoveryState,
    required this.telemetrySchemaVersion,
    this.scoringVersion,
    this.eventEngineVersion,
    this.mlModelRefsJson,
    required this.integrityStatus,
    this.telemetryConfidence,
    this.telemetryQualitySummaryJson,
    required this.cloudSyncState,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['start_wall_time_micros'] = Variable<int>(startWallTimeMicros);
    if (!nullToAbsent || endWallTimeMicros != null) {
      map['end_wall_time_micros'] = Variable<int>(endWallTimeMicros);
    }
    map['start_elapsed_nanos'] = Variable<int>(startElapsedNanos);
    if (!nullToAbsent || endElapsedNanos != null) {
      map['end_elapsed_nanos'] = Variable<int>(endElapsedNanos);
    }
    if (!nullToAbsent || durationMillis != null) {
      map['duration_millis'] = Variable<int>(durationMillis);
    }
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<double>(distanceMeters);
    }
    map['completion_state'] = Variable<String>(completionState);
    map['recovery_state'] = Variable<String>(recoveryState);
    map['telemetry_schema_version'] = Variable<int>(telemetrySchemaVersion);
    if (!nullToAbsent || scoringVersion != null) {
      map['scoring_version'] = Variable<String>(scoringVersion);
    }
    if (!nullToAbsent || eventEngineVersion != null) {
      map['event_engine_version'] = Variable<String>(eventEngineVersion);
    }
    if (!nullToAbsent || mlModelRefsJson != null) {
      map['ml_model_refs_json'] = Variable<String>(mlModelRefsJson);
    }
    map['integrity_status'] = Variable<String>(integrityStatus);
    if (!nullToAbsent || telemetryConfidence != null) {
      map['telemetry_confidence'] = Variable<double>(telemetryConfidence);
    }
    if (!nullToAbsent || telemetryQualitySummaryJson != null) {
      map['telemetry_quality_summary_json'] = Variable<String>(
        telemetryQualitySummaryJson,
      );
    }
    map['cloud_sync_state'] = Variable<String>(cloudSyncState);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      startWallTimeMicros: Value(startWallTimeMicros),
      endWallTimeMicros: endWallTimeMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(endWallTimeMicros),
      startElapsedNanos: Value(startElapsedNanos),
      endElapsedNanos: endElapsedNanos == null && nullToAbsent
          ? const Value.absent()
          : Value(endElapsedNanos),
      durationMillis: durationMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMillis),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      completionState: Value(completionState),
      recoveryState: Value(recoveryState),
      telemetrySchemaVersion: Value(telemetrySchemaVersion),
      scoringVersion: scoringVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(scoringVersion),
      eventEngineVersion: eventEngineVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(eventEngineVersion),
      mlModelRefsJson: mlModelRefsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mlModelRefsJson),
      integrityStatus: Value(integrityStatus),
      telemetryConfidence: telemetryConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(telemetryConfidence),
      telemetryQualitySummaryJson:
          telemetryQualitySummaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(telemetryQualitySummaryJson),
      cloudSyncState: Value(cloudSyncState),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      startWallTimeMicros: serializer.fromJson<int>(
        json['startWallTimeMicros'],
      ),
      endWallTimeMicros: serializer.fromJson<int?>(json['endWallTimeMicros']),
      startElapsedNanos: serializer.fromJson<int>(json['startElapsedNanos']),
      endElapsedNanos: serializer.fromJson<int?>(json['endElapsedNanos']),
      durationMillis: serializer.fromJson<int?>(json['durationMillis']),
      distanceMeters: serializer.fromJson<double?>(json['distanceMeters']),
      completionState: serializer.fromJson<String>(json['completionState']),
      recoveryState: serializer.fromJson<String>(json['recoveryState']),
      telemetrySchemaVersion: serializer.fromJson<int>(
        json['telemetrySchemaVersion'],
      ),
      scoringVersion: serializer.fromJson<String?>(json['scoringVersion']),
      eventEngineVersion: serializer.fromJson<String?>(
        json['eventEngineVersion'],
      ),
      mlModelRefsJson: serializer.fromJson<String?>(json['mlModelRefsJson']),
      integrityStatus: serializer.fromJson<String>(json['integrityStatus']),
      telemetryConfidence: serializer.fromJson<double?>(
        json['telemetryConfidence'],
      ),
      telemetryQualitySummaryJson: serializer.fromJson<String?>(
        json['telemetryQualitySummaryJson'],
      ),
      cloudSyncState: serializer.fromJson<String>(json['cloudSyncState']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'startWallTimeMicros': serializer.toJson<int>(startWallTimeMicros),
      'endWallTimeMicros': serializer.toJson<int?>(endWallTimeMicros),
      'startElapsedNanos': serializer.toJson<int>(startElapsedNanos),
      'endElapsedNanos': serializer.toJson<int?>(endElapsedNanos),
      'durationMillis': serializer.toJson<int?>(durationMillis),
      'distanceMeters': serializer.toJson<double?>(distanceMeters),
      'completionState': serializer.toJson<String>(completionState),
      'recoveryState': serializer.toJson<String>(recoveryState),
      'telemetrySchemaVersion': serializer.toJson<int>(telemetrySchemaVersion),
      'scoringVersion': serializer.toJson<String?>(scoringVersion),
      'eventEngineVersion': serializer.toJson<String?>(eventEngineVersion),
      'mlModelRefsJson': serializer.toJson<String?>(mlModelRefsJson),
      'integrityStatus': serializer.toJson<String>(integrityStatus),
      'telemetryConfidence': serializer.toJson<double?>(telemetryConfidence),
      'telemetryQualitySummaryJson': serializer.toJson<String?>(
        telemetryQualitySummaryJson,
      ),
      'cloudSyncState': serializer.toJson<String>(cloudSyncState),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  Trip copyWith({
    String? id,
    String? vehicleId,
    int? startWallTimeMicros,
    Value<int?> endWallTimeMicros = const Value.absent(),
    int? startElapsedNanos,
    Value<int?> endElapsedNanos = const Value.absent(),
    Value<int?> durationMillis = const Value.absent(),
    Value<double?> distanceMeters = const Value.absent(),
    String? completionState,
    String? recoveryState,
    int? telemetrySchemaVersion,
    Value<String?> scoringVersion = const Value.absent(),
    Value<String?> eventEngineVersion = const Value.absent(),
    Value<String?> mlModelRefsJson = const Value.absent(),
    String? integrityStatus,
    Value<double?> telemetryConfidence = const Value.absent(),
    Value<String?> telemetryQualitySummaryJson = const Value.absent(),
    String? cloudSyncState,
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => Trip(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    startWallTimeMicros: startWallTimeMicros ?? this.startWallTimeMicros,
    endWallTimeMicros: endWallTimeMicros.present
        ? endWallTimeMicros.value
        : this.endWallTimeMicros,
    startElapsedNanos: startElapsedNanos ?? this.startElapsedNanos,
    endElapsedNanos: endElapsedNanos.present
        ? endElapsedNanos.value
        : this.endElapsedNanos,
    durationMillis: durationMillis.present
        ? durationMillis.value
        : this.durationMillis,
    distanceMeters: distanceMeters.present
        ? distanceMeters.value
        : this.distanceMeters,
    completionState: completionState ?? this.completionState,
    recoveryState: recoveryState ?? this.recoveryState,
    telemetrySchemaVersion:
        telemetrySchemaVersion ?? this.telemetrySchemaVersion,
    scoringVersion: scoringVersion.present
        ? scoringVersion.value
        : this.scoringVersion,
    eventEngineVersion: eventEngineVersion.present
        ? eventEngineVersion.value
        : this.eventEngineVersion,
    mlModelRefsJson: mlModelRefsJson.present
        ? mlModelRefsJson.value
        : this.mlModelRefsJson,
    integrityStatus: integrityStatus ?? this.integrityStatus,
    telemetryConfidence: telemetryConfidence.present
        ? telemetryConfidence.value
        : this.telemetryConfidence,
    telemetryQualitySummaryJson: telemetryQualitySummaryJson.present
        ? telemetryQualitySummaryJson.value
        : this.telemetryQualitySummaryJson,
    cloudSyncState: cloudSyncState ?? this.cloudSyncState,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      startWallTimeMicros: data.startWallTimeMicros.present
          ? data.startWallTimeMicros.value
          : this.startWallTimeMicros,
      endWallTimeMicros: data.endWallTimeMicros.present
          ? data.endWallTimeMicros.value
          : this.endWallTimeMicros,
      startElapsedNanos: data.startElapsedNanos.present
          ? data.startElapsedNanos.value
          : this.startElapsedNanos,
      endElapsedNanos: data.endElapsedNanos.present
          ? data.endElapsedNanos.value
          : this.endElapsedNanos,
      durationMillis: data.durationMillis.present
          ? data.durationMillis.value
          : this.durationMillis,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      completionState: data.completionState.present
          ? data.completionState.value
          : this.completionState,
      recoveryState: data.recoveryState.present
          ? data.recoveryState.value
          : this.recoveryState,
      telemetrySchemaVersion: data.telemetrySchemaVersion.present
          ? data.telemetrySchemaVersion.value
          : this.telemetrySchemaVersion,
      scoringVersion: data.scoringVersion.present
          ? data.scoringVersion.value
          : this.scoringVersion,
      eventEngineVersion: data.eventEngineVersion.present
          ? data.eventEngineVersion.value
          : this.eventEngineVersion,
      mlModelRefsJson: data.mlModelRefsJson.present
          ? data.mlModelRefsJson.value
          : this.mlModelRefsJson,
      integrityStatus: data.integrityStatus.present
          ? data.integrityStatus.value
          : this.integrityStatus,
      telemetryConfidence: data.telemetryConfidence.present
          ? data.telemetryConfidence.value
          : this.telemetryConfidence,
      telemetryQualitySummaryJson: data.telemetryQualitySummaryJson.present
          ? data.telemetryQualitySummaryJson.value
          : this.telemetryQualitySummaryJson,
      cloudSyncState: data.cloudSyncState.present
          ? data.cloudSyncState.value
          : this.cloudSyncState,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('startWallTimeMicros: $startWallTimeMicros, ')
          ..write('endWallTimeMicros: $endWallTimeMicros, ')
          ..write('startElapsedNanos: $startElapsedNanos, ')
          ..write('endElapsedNanos: $endElapsedNanos, ')
          ..write('durationMillis: $durationMillis, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('completionState: $completionState, ')
          ..write('recoveryState: $recoveryState, ')
          ..write('telemetrySchemaVersion: $telemetrySchemaVersion, ')
          ..write('scoringVersion: $scoringVersion, ')
          ..write('eventEngineVersion: $eventEngineVersion, ')
          ..write('mlModelRefsJson: $mlModelRefsJson, ')
          ..write('integrityStatus: $integrityStatus, ')
          ..write('telemetryConfidence: $telemetryConfidence, ')
          ..write('telemetryQualitySummaryJson: $telemetryQualitySummaryJson, ')
          ..write('cloudSyncState: $cloudSyncState, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    startWallTimeMicros,
    endWallTimeMicros,
    startElapsedNanos,
    endElapsedNanos,
    durationMillis,
    distanceMeters,
    completionState,
    recoveryState,
    telemetrySchemaVersion,
    scoringVersion,
    eventEngineVersion,
    mlModelRefsJson,
    integrityStatus,
    telemetryConfidence,
    telemetryQualitySummaryJson,
    cloudSyncState,
    createdAtMicros,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.startWallTimeMicros == this.startWallTimeMicros &&
          other.endWallTimeMicros == this.endWallTimeMicros &&
          other.startElapsedNanos == this.startElapsedNanos &&
          other.endElapsedNanos == this.endElapsedNanos &&
          other.durationMillis == this.durationMillis &&
          other.distanceMeters == this.distanceMeters &&
          other.completionState == this.completionState &&
          other.recoveryState == this.recoveryState &&
          other.telemetrySchemaVersion == this.telemetrySchemaVersion &&
          other.scoringVersion == this.scoringVersion &&
          other.eventEngineVersion == this.eventEngineVersion &&
          other.mlModelRefsJson == this.mlModelRefsJson &&
          other.integrityStatus == this.integrityStatus &&
          other.telemetryConfidence == this.telemetryConfidence &&
          other.telemetryQualitySummaryJson ==
              this.telemetryQualitySummaryJson &&
          other.cloudSyncState == this.cloudSyncState &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<int> startWallTimeMicros;
  final Value<int?> endWallTimeMicros;
  final Value<int> startElapsedNanos;
  final Value<int?> endElapsedNanos;
  final Value<int?> durationMillis;
  final Value<double?> distanceMeters;
  final Value<String> completionState;
  final Value<String> recoveryState;
  final Value<int> telemetrySchemaVersion;
  final Value<String?> scoringVersion;
  final Value<String?> eventEngineVersion;
  final Value<String?> mlModelRefsJson;
  final Value<String> integrityStatus;
  final Value<double?> telemetryConfidence;
  final Value<String?> telemetryQualitySummaryJson;
  final Value<String> cloudSyncState;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.startWallTimeMicros = const Value.absent(),
    this.endWallTimeMicros = const Value.absent(),
    this.startElapsedNanos = const Value.absent(),
    this.endElapsedNanos = const Value.absent(),
    this.durationMillis = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.completionState = const Value.absent(),
    this.recoveryState = const Value.absent(),
    this.telemetrySchemaVersion = const Value.absent(),
    this.scoringVersion = const Value.absent(),
    this.eventEngineVersion = const Value.absent(),
    this.mlModelRefsJson = const Value.absent(),
    this.integrityStatus = const Value.absent(),
    this.telemetryConfidence = const Value.absent(),
    this.telemetryQualitySummaryJson = const Value.absent(),
    this.cloudSyncState = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    required String vehicleId,
    required int startWallTimeMicros,
    this.endWallTimeMicros = const Value.absent(),
    required int startElapsedNanos,
    this.endElapsedNanos = const Value.absent(),
    this.durationMillis = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    required String completionState,
    required String recoveryState,
    required int telemetrySchemaVersion,
    this.scoringVersion = const Value.absent(),
    this.eventEngineVersion = const Value.absent(),
    this.mlModelRefsJson = const Value.absent(),
    required String integrityStatus,
    this.telemetryConfidence = const Value.absent(),
    this.telemetryQualitySummaryJson = const Value.absent(),
    required String cloudSyncState,
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       startWallTimeMicros = Value(startWallTimeMicros),
       startElapsedNanos = Value(startElapsedNanos),
       completionState = Value(completionState),
       recoveryState = Value(recoveryState),
       telemetrySchemaVersion = Value(telemetrySchemaVersion),
       integrityStatus = Value(integrityStatus),
       cloudSyncState = Value(cloudSyncState),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<Trip> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<int>? startWallTimeMicros,
    Expression<int>? endWallTimeMicros,
    Expression<int>? startElapsedNanos,
    Expression<int>? endElapsedNanos,
    Expression<int>? durationMillis,
    Expression<double>? distanceMeters,
    Expression<String>? completionState,
    Expression<String>? recoveryState,
    Expression<int>? telemetrySchemaVersion,
    Expression<String>? scoringVersion,
    Expression<String>? eventEngineVersion,
    Expression<String>? mlModelRefsJson,
    Expression<String>? integrityStatus,
    Expression<double>? telemetryConfidence,
    Expression<String>? telemetryQualitySummaryJson,
    Expression<String>? cloudSyncState,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (startWallTimeMicros != null)
        'start_wall_time_micros': startWallTimeMicros,
      if (endWallTimeMicros != null) 'end_wall_time_micros': endWallTimeMicros,
      if (startElapsedNanos != null) 'start_elapsed_nanos': startElapsedNanos,
      if (endElapsedNanos != null) 'end_elapsed_nanos': endElapsedNanos,
      if (durationMillis != null) 'duration_millis': durationMillis,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (completionState != null) 'completion_state': completionState,
      if (recoveryState != null) 'recovery_state': recoveryState,
      if (telemetrySchemaVersion != null)
        'telemetry_schema_version': telemetrySchemaVersion,
      if (scoringVersion != null) 'scoring_version': scoringVersion,
      if (eventEngineVersion != null)
        'event_engine_version': eventEngineVersion,
      if (mlModelRefsJson != null) 'ml_model_refs_json': mlModelRefsJson,
      if (integrityStatus != null) 'integrity_status': integrityStatus,
      if (telemetryConfidence != null)
        'telemetry_confidence': telemetryConfidence,
      if (telemetryQualitySummaryJson != null)
        'telemetry_quality_summary_json': telemetryQualitySummaryJson,
      if (cloudSyncState != null) 'cloud_sync_state': cloudSyncState,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<int>? startWallTimeMicros,
    Value<int?>? endWallTimeMicros,
    Value<int>? startElapsedNanos,
    Value<int?>? endElapsedNanos,
    Value<int?>? durationMillis,
    Value<double?>? distanceMeters,
    Value<String>? completionState,
    Value<String>? recoveryState,
    Value<int>? telemetrySchemaVersion,
    Value<String?>? scoringVersion,
    Value<String?>? eventEngineVersion,
    Value<String?>? mlModelRefsJson,
    Value<String>? integrityStatus,
    Value<double?>? telemetryConfidence,
    Value<String?>? telemetryQualitySummaryJson,
    Value<String>? cloudSyncState,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      startWallTimeMicros: startWallTimeMicros ?? this.startWallTimeMicros,
      endWallTimeMicros: endWallTimeMicros ?? this.endWallTimeMicros,
      startElapsedNanos: startElapsedNanos ?? this.startElapsedNanos,
      endElapsedNanos: endElapsedNanos ?? this.endElapsedNanos,
      durationMillis: durationMillis ?? this.durationMillis,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      completionState: completionState ?? this.completionState,
      recoveryState: recoveryState ?? this.recoveryState,
      telemetrySchemaVersion:
          telemetrySchemaVersion ?? this.telemetrySchemaVersion,
      scoringVersion: scoringVersion ?? this.scoringVersion,
      eventEngineVersion: eventEngineVersion ?? this.eventEngineVersion,
      mlModelRefsJson: mlModelRefsJson ?? this.mlModelRefsJson,
      integrityStatus: integrityStatus ?? this.integrityStatus,
      telemetryConfidence: telemetryConfidence ?? this.telemetryConfidence,
      telemetryQualitySummaryJson:
          telemetryQualitySummaryJson ?? this.telemetryQualitySummaryJson,
      cloudSyncState: cloudSyncState ?? this.cloudSyncState,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (startWallTimeMicros.present) {
      map['start_wall_time_micros'] = Variable<int>(startWallTimeMicros.value);
    }
    if (endWallTimeMicros.present) {
      map['end_wall_time_micros'] = Variable<int>(endWallTimeMicros.value);
    }
    if (startElapsedNanos.present) {
      map['start_elapsed_nanos'] = Variable<int>(startElapsedNanos.value);
    }
    if (endElapsedNanos.present) {
      map['end_elapsed_nanos'] = Variable<int>(endElapsedNanos.value);
    }
    if (durationMillis.present) {
      map['duration_millis'] = Variable<int>(durationMillis.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (completionState.present) {
      map['completion_state'] = Variable<String>(completionState.value);
    }
    if (recoveryState.present) {
      map['recovery_state'] = Variable<String>(recoveryState.value);
    }
    if (telemetrySchemaVersion.present) {
      map['telemetry_schema_version'] = Variable<int>(
        telemetrySchemaVersion.value,
      );
    }
    if (scoringVersion.present) {
      map['scoring_version'] = Variable<String>(scoringVersion.value);
    }
    if (eventEngineVersion.present) {
      map['event_engine_version'] = Variable<String>(eventEngineVersion.value);
    }
    if (mlModelRefsJson.present) {
      map['ml_model_refs_json'] = Variable<String>(mlModelRefsJson.value);
    }
    if (integrityStatus.present) {
      map['integrity_status'] = Variable<String>(integrityStatus.value);
    }
    if (telemetryConfidence.present) {
      map['telemetry_confidence'] = Variable<double>(telemetryConfidence.value);
    }
    if (telemetryQualitySummaryJson.present) {
      map['telemetry_quality_summary_json'] = Variable<String>(
        telemetryQualitySummaryJson.value,
      );
    }
    if (cloudSyncState.present) {
      map['cloud_sync_state'] = Variable<String>(cloudSyncState.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('startWallTimeMicros: $startWallTimeMicros, ')
          ..write('endWallTimeMicros: $endWallTimeMicros, ')
          ..write('startElapsedNanos: $startElapsedNanos, ')
          ..write('endElapsedNanos: $endElapsedNanos, ')
          ..write('durationMillis: $durationMillis, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('completionState: $completionState, ')
          ..write('recoveryState: $recoveryState, ')
          ..write('telemetrySchemaVersion: $telemetrySchemaVersion, ')
          ..write('scoringVersion: $scoringVersion, ')
          ..write('eventEngineVersion: $eventEngineVersion, ')
          ..write('mlModelRefsJson: $mlModelRefsJson, ')
          ..write('integrityStatus: $integrityStatus, ')
          ..write('telemetryConfidence: $telemetryConfidence, ')
          ..write('telemetryQualitySummaryJson: $telemetryQualitySummaryJson, ')
          ..write('cloudSyncState: $cloudSyncState, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripChunksTable extends TripChunks
    with TableInfo<$TripChunksTable, TripChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storageReferenceMeta = const VerificationMeta(
    'storageReference',
  );
  @override
  late final GeneratedColumn<String> storageReference = GeneratedColumn<String>(
    'storage_reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encodingVersionMeta = const VerificationMeta(
    'encodingVersion',
  );
  @override
  late final GeneratedColumn<int> encodingVersion = GeneratedColumn<int>(
    'encoding_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startElapsedNanosMeta = const VerificationMeta(
    'startElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> startElapsedNanos = GeneratedColumn<int>(
    'start_elapsed_nanos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endElapsedNanosMeta = const VerificationMeta(
    'endElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> endElapsedNanos = GeneratedColumn<int>(
    'end_elapsed_nanos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelSampleCountsJsonMeta =
      const VerificationMeta('channelSampleCountsJson');
  @override
  late final GeneratedColumn<String> channelSampleCountsJson =
      GeneratedColumn<String>(
        'channel_sample_counts_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _compressionMeta = const VerificationMeta(
    'compression',
  );
  @override
  late final GeneratedColumn<String> compression = GeneratedColumn<String>(
    'compression',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atomicWriteStrategyMeta =
      const VerificationMeta('atomicWriteStrategy');
  @override
  late final GeneratedColumn<String> atomicWriteStrategy =
      GeneratedColumn<String>(
        'atomic_write_strategy',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _checksumAlgorithmMeta = const VerificationMeta(
    'checksumAlgorithm',
  );
  @override
  late final GeneratedColumn<String> checksumAlgorithm =
      GeneratedColumn<String>(
        'checksum_algorithm',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _writeStateMeta = const VerificationMeta(
    'writeState',
  );
  @override
  late final GeneratedColumn<String> writeState = GeneratedColumn<String>(
    'write_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tripId,
    sequence,
    storageReference,
    encodingVersion,
    startElapsedNanos,
    endElapsedNanos,
    channelSampleCountsJson,
    compression,
    atomicWriteStrategy,
    checksumAlgorithm,
    checksum,
    byteLength,
    writeState,
    createdAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('storage_reference')) {
      context.handle(
        _storageReferenceMeta,
        storageReference.isAcceptableOrUnknown(
          data['storage_reference']!,
          _storageReferenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageReferenceMeta);
    }
    if (data.containsKey('encoding_version')) {
      context.handle(
        _encodingVersionMeta,
        encodingVersion.isAcceptableOrUnknown(
          data['encoding_version']!,
          _encodingVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encodingVersionMeta);
    }
    if (data.containsKey('start_elapsed_nanos')) {
      context.handle(
        _startElapsedNanosMeta,
        startElapsedNanos.isAcceptableOrUnknown(
          data['start_elapsed_nanos']!,
          _startElapsedNanosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startElapsedNanosMeta);
    }
    if (data.containsKey('end_elapsed_nanos')) {
      context.handle(
        _endElapsedNanosMeta,
        endElapsedNanos.isAcceptableOrUnknown(
          data['end_elapsed_nanos']!,
          _endElapsedNanosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endElapsedNanosMeta);
    }
    if (data.containsKey('channel_sample_counts_json')) {
      context.handle(
        _channelSampleCountsJsonMeta,
        channelSampleCountsJson.isAcceptableOrUnknown(
          data['channel_sample_counts_json']!,
          _channelSampleCountsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelSampleCountsJsonMeta);
    }
    if (data.containsKey('compression')) {
      context.handle(
        _compressionMeta,
        compression.isAcceptableOrUnknown(
          data['compression']!,
          _compressionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compressionMeta);
    }
    if (data.containsKey('atomic_write_strategy')) {
      context.handle(
        _atomicWriteStrategyMeta,
        atomicWriteStrategy.isAcceptableOrUnknown(
          data['atomic_write_strategy']!,
          _atomicWriteStrategyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atomicWriteStrategyMeta);
    }
    if (data.containsKey('checksum_algorithm')) {
      context.handle(
        _checksumAlgorithmMeta,
        checksumAlgorithm.isAcceptableOrUnknown(
          data['checksum_algorithm']!,
          _checksumAlgorithmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checksumAlgorithmMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    if (data.containsKey('write_state')) {
      context.handle(
        _writeStateMeta,
        writeState.isAcceptableOrUnknown(data['write_state']!, _writeStateMeta),
      );
    } else if (isInserting) {
      context.missing(_writeStateMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, sequence};
  @override
  TripChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripChunk(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      storageReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_reference'],
      )!,
      encodingVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encoding_version'],
      )!,
      startElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_elapsed_nanos'],
      )!,
      endElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_elapsed_nanos'],
      )!,
      channelSampleCountsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_sample_counts_json'],
      )!,
      compression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compression'],
      )!,
      atomicWriteStrategy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}atomic_write_strategy'],
      )!,
      checksumAlgorithm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum_algorithm'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
      writeState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}write_state'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
    );
  }

  @override
  $TripChunksTable createAlias(String alias) {
    return $TripChunksTable(attachedDatabase, alias);
  }
}

class TripChunk extends DataClass implements Insertable<TripChunk> {
  final String tripId;
  final int sequence;
  final String storageReference;
  final int encodingVersion;
  final int startElapsedNanos;
  final int endElapsedNanos;
  final String channelSampleCountsJson;
  final String compression;
  final String atomicWriteStrategy;
  final String checksumAlgorithm;
  final String checksum;
  final int byteLength;
  final String writeState;
  final int createdAtMicros;
  const TripChunk({
    required this.tripId,
    required this.sequence,
    required this.storageReference,
    required this.encodingVersion,
    required this.startElapsedNanos,
    required this.endElapsedNanos,
    required this.channelSampleCountsJson,
    required this.compression,
    required this.atomicWriteStrategy,
    required this.checksumAlgorithm,
    required this.checksum,
    required this.byteLength,
    required this.writeState,
    required this.createdAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<String>(tripId);
    map['sequence'] = Variable<int>(sequence);
    map['storage_reference'] = Variable<String>(storageReference);
    map['encoding_version'] = Variable<int>(encodingVersion);
    map['start_elapsed_nanos'] = Variable<int>(startElapsedNanos);
    map['end_elapsed_nanos'] = Variable<int>(endElapsedNanos);
    map['channel_sample_counts_json'] = Variable<String>(
      channelSampleCountsJson,
    );
    map['compression'] = Variable<String>(compression);
    map['atomic_write_strategy'] = Variable<String>(atomicWriteStrategy);
    map['checksum_algorithm'] = Variable<String>(checksumAlgorithm);
    map['checksum'] = Variable<String>(checksum);
    map['byte_length'] = Variable<int>(byteLength);
    map['write_state'] = Variable<String>(writeState);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    return map;
  }

  TripChunksCompanion toCompanion(bool nullToAbsent) {
    return TripChunksCompanion(
      tripId: Value(tripId),
      sequence: Value(sequence),
      storageReference: Value(storageReference),
      encodingVersion: Value(encodingVersion),
      startElapsedNanos: Value(startElapsedNanos),
      endElapsedNanos: Value(endElapsedNanos),
      channelSampleCountsJson: Value(channelSampleCountsJson),
      compression: Value(compression),
      atomicWriteStrategy: Value(atomicWriteStrategy),
      checksumAlgorithm: Value(checksumAlgorithm),
      checksum: Value(checksum),
      byteLength: Value(byteLength),
      writeState: Value(writeState),
      createdAtMicros: Value(createdAtMicros),
    );
  }

  factory TripChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripChunk(
      tripId: serializer.fromJson<String>(json['tripId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      storageReference: serializer.fromJson<String>(json['storageReference']),
      encodingVersion: serializer.fromJson<int>(json['encodingVersion']),
      startElapsedNanos: serializer.fromJson<int>(json['startElapsedNanos']),
      endElapsedNanos: serializer.fromJson<int>(json['endElapsedNanos']),
      channelSampleCountsJson: serializer.fromJson<String>(
        json['channelSampleCountsJson'],
      ),
      compression: serializer.fromJson<String>(json['compression']),
      atomicWriteStrategy: serializer.fromJson<String>(
        json['atomicWriteStrategy'],
      ),
      checksumAlgorithm: serializer.fromJson<String>(json['checksumAlgorithm']),
      checksum: serializer.fromJson<String>(json['checksum']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
      writeState: serializer.fromJson<String>(json['writeState']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<String>(tripId),
      'sequence': serializer.toJson<int>(sequence),
      'storageReference': serializer.toJson<String>(storageReference),
      'encodingVersion': serializer.toJson<int>(encodingVersion),
      'startElapsedNanos': serializer.toJson<int>(startElapsedNanos),
      'endElapsedNanos': serializer.toJson<int>(endElapsedNanos),
      'channelSampleCountsJson': serializer.toJson<String>(
        channelSampleCountsJson,
      ),
      'compression': serializer.toJson<String>(compression),
      'atomicWriteStrategy': serializer.toJson<String>(atomicWriteStrategy),
      'checksumAlgorithm': serializer.toJson<String>(checksumAlgorithm),
      'checksum': serializer.toJson<String>(checksum),
      'byteLength': serializer.toJson<int>(byteLength),
      'writeState': serializer.toJson<String>(writeState),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
    };
  }

  TripChunk copyWith({
    String? tripId,
    int? sequence,
    String? storageReference,
    int? encodingVersion,
    int? startElapsedNanos,
    int? endElapsedNanos,
    String? channelSampleCountsJson,
    String? compression,
    String? atomicWriteStrategy,
    String? checksumAlgorithm,
    String? checksum,
    int? byteLength,
    String? writeState,
    int? createdAtMicros,
  }) => TripChunk(
    tripId: tripId ?? this.tripId,
    sequence: sequence ?? this.sequence,
    storageReference: storageReference ?? this.storageReference,
    encodingVersion: encodingVersion ?? this.encodingVersion,
    startElapsedNanos: startElapsedNanos ?? this.startElapsedNanos,
    endElapsedNanos: endElapsedNanos ?? this.endElapsedNanos,
    channelSampleCountsJson:
        channelSampleCountsJson ?? this.channelSampleCountsJson,
    compression: compression ?? this.compression,
    atomicWriteStrategy: atomicWriteStrategy ?? this.atomicWriteStrategy,
    checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
    checksum: checksum ?? this.checksum,
    byteLength: byteLength ?? this.byteLength,
    writeState: writeState ?? this.writeState,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
  );
  TripChunk copyWithCompanion(TripChunksCompanion data) {
    return TripChunk(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      storageReference: data.storageReference.present
          ? data.storageReference.value
          : this.storageReference,
      encodingVersion: data.encodingVersion.present
          ? data.encodingVersion.value
          : this.encodingVersion,
      startElapsedNanos: data.startElapsedNanos.present
          ? data.startElapsedNanos.value
          : this.startElapsedNanos,
      endElapsedNanos: data.endElapsedNanos.present
          ? data.endElapsedNanos.value
          : this.endElapsedNanos,
      channelSampleCountsJson: data.channelSampleCountsJson.present
          ? data.channelSampleCountsJson.value
          : this.channelSampleCountsJson,
      compression: data.compression.present
          ? data.compression.value
          : this.compression,
      atomicWriteStrategy: data.atomicWriteStrategy.present
          ? data.atomicWriteStrategy.value
          : this.atomicWriteStrategy,
      checksumAlgorithm: data.checksumAlgorithm.present
          ? data.checksumAlgorithm.value
          : this.checksumAlgorithm,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
      writeState: data.writeState.present
          ? data.writeState.value
          : this.writeState,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripChunk(')
          ..write('tripId: $tripId, ')
          ..write('sequence: $sequence, ')
          ..write('storageReference: $storageReference, ')
          ..write('encodingVersion: $encodingVersion, ')
          ..write('startElapsedNanos: $startElapsedNanos, ')
          ..write('endElapsedNanos: $endElapsedNanos, ')
          ..write('channelSampleCountsJson: $channelSampleCountsJson, ')
          ..write('compression: $compression, ')
          ..write('atomicWriteStrategy: $atomicWriteStrategy, ')
          ..write('checksumAlgorithm: $checksumAlgorithm, ')
          ..write('checksum: $checksum, ')
          ..write('byteLength: $byteLength, ')
          ..write('writeState: $writeState, ')
          ..write('createdAtMicros: $createdAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tripId,
    sequence,
    storageReference,
    encodingVersion,
    startElapsedNanos,
    endElapsedNanos,
    channelSampleCountsJson,
    compression,
    atomicWriteStrategy,
    checksumAlgorithm,
    checksum,
    byteLength,
    writeState,
    createdAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripChunk &&
          other.tripId == this.tripId &&
          other.sequence == this.sequence &&
          other.storageReference == this.storageReference &&
          other.encodingVersion == this.encodingVersion &&
          other.startElapsedNanos == this.startElapsedNanos &&
          other.endElapsedNanos == this.endElapsedNanos &&
          other.channelSampleCountsJson == this.channelSampleCountsJson &&
          other.compression == this.compression &&
          other.atomicWriteStrategy == this.atomicWriteStrategy &&
          other.checksumAlgorithm == this.checksumAlgorithm &&
          other.checksum == this.checksum &&
          other.byteLength == this.byteLength &&
          other.writeState == this.writeState &&
          other.createdAtMicros == this.createdAtMicros);
}

class TripChunksCompanion extends UpdateCompanion<TripChunk> {
  final Value<String> tripId;
  final Value<int> sequence;
  final Value<String> storageReference;
  final Value<int> encodingVersion;
  final Value<int> startElapsedNanos;
  final Value<int> endElapsedNanos;
  final Value<String> channelSampleCountsJson;
  final Value<String> compression;
  final Value<String> atomicWriteStrategy;
  final Value<String> checksumAlgorithm;
  final Value<String> checksum;
  final Value<int> byteLength;
  final Value<String> writeState;
  final Value<int> createdAtMicros;
  final Value<int> rowid;
  const TripChunksCompanion({
    this.tripId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.storageReference = const Value.absent(),
    this.encodingVersion = const Value.absent(),
    this.startElapsedNanos = const Value.absent(),
    this.endElapsedNanos = const Value.absent(),
    this.channelSampleCountsJson = const Value.absent(),
    this.compression = const Value.absent(),
    this.atomicWriteStrategy = const Value.absent(),
    this.checksumAlgorithm = const Value.absent(),
    this.checksum = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.writeState = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripChunksCompanion.insert({
    required String tripId,
    required int sequence,
    required String storageReference,
    required int encodingVersion,
    required int startElapsedNanos,
    required int endElapsedNanos,
    required String channelSampleCountsJson,
    required String compression,
    required String atomicWriteStrategy,
    required String checksumAlgorithm,
    required String checksum,
    required int byteLength,
    required String writeState,
    required int createdAtMicros,
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       sequence = Value(sequence),
       storageReference = Value(storageReference),
       encodingVersion = Value(encodingVersion),
       startElapsedNanos = Value(startElapsedNanos),
       endElapsedNanos = Value(endElapsedNanos),
       channelSampleCountsJson = Value(channelSampleCountsJson),
       compression = Value(compression),
       atomicWriteStrategy = Value(atomicWriteStrategy),
       checksumAlgorithm = Value(checksumAlgorithm),
       checksum = Value(checksum),
       byteLength = Value(byteLength),
       writeState = Value(writeState),
       createdAtMicros = Value(createdAtMicros);
  static Insertable<TripChunk> custom({
    Expression<String>? tripId,
    Expression<int>? sequence,
    Expression<String>? storageReference,
    Expression<int>? encodingVersion,
    Expression<int>? startElapsedNanos,
    Expression<int>? endElapsedNanos,
    Expression<String>? channelSampleCountsJson,
    Expression<String>? compression,
    Expression<String>? atomicWriteStrategy,
    Expression<String>? checksumAlgorithm,
    Expression<String>? checksum,
    Expression<int>? byteLength,
    Expression<String>? writeState,
    Expression<int>? createdAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (sequence != null) 'sequence': sequence,
      if (storageReference != null) 'storage_reference': storageReference,
      if (encodingVersion != null) 'encoding_version': encodingVersion,
      if (startElapsedNanos != null) 'start_elapsed_nanos': startElapsedNanos,
      if (endElapsedNanos != null) 'end_elapsed_nanos': endElapsedNanos,
      if (channelSampleCountsJson != null)
        'channel_sample_counts_json': channelSampleCountsJson,
      if (compression != null) 'compression': compression,
      if (atomicWriteStrategy != null)
        'atomic_write_strategy': atomicWriteStrategy,
      if (checksumAlgorithm != null) 'checksum_algorithm': checksumAlgorithm,
      if (checksum != null) 'checksum': checksum,
      if (byteLength != null) 'byte_length': byteLength,
      if (writeState != null) 'write_state': writeState,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripChunksCompanion copyWith({
    Value<String>? tripId,
    Value<int>? sequence,
    Value<String>? storageReference,
    Value<int>? encodingVersion,
    Value<int>? startElapsedNanos,
    Value<int>? endElapsedNanos,
    Value<String>? channelSampleCountsJson,
    Value<String>? compression,
    Value<String>? atomicWriteStrategy,
    Value<String>? checksumAlgorithm,
    Value<String>? checksum,
    Value<int>? byteLength,
    Value<String>? writeState,
    Value<int>? createdAtMicros,
    Value<int>? rowid,
  }) {
    return TripChunksCompanion(
      tripId: tripId ?? this.tripId,
      sequence: sequence ?? this.sequence,
      storageReference: storageReference ?? this.storageReference,
      encodingVersion: encodingVersion ?? this.encodingVersion,
      startElapsedNanos: startElapsedNanos ?? this.startElapsedNanos,
      endElapsedNanos: endElapsedNanos ?? this.endElapsedNanos,
      channelSampleCountsJson:
          channelSampleCountsJson ?? this.channelSampleCountsJson,
      compression: compression ?? this.compression,
      atomicWriteStrategy: atomicWriteStrategy ?? this.atomicWriteStrategy,
      checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
      checksum: checksum ?? this.checksum,
      byteLength: byteLength ?? this.byteLength,
      writeState: writeState ?? this.writeState,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (storageReference.present) {
      map['storage_reference'] = Variable<String>(storageReference.value);
    }
    if (encodingVersion.present) {
      map['encoding_version'] = Variable<int>(encodingVersion.value);
    }
    if (startElapsedNanos.present) {
      map['start_elapsed_nanos'] = Variable<int>(startElapsedNanos.value);
    }
    if (endElapsedNanos.present) {
      map['end_elapsed_nanos'] = Variable<int>(endElapsedNanos.value);
    }
    if (channelSampleCountsJson.present) {
      map['channel_sample_counts_json'] = Variable<String>(
        channelSampleCountsJson.value,
      );
    }
    if (compression.present) {
      map['compression'] = Variable<String>(compression.value);
    }
    if (atomicWriteStrategy.present) {
      map['atomic_write_strategy'] = Variable<String>(
        atomicWriteStrategy.value,
      );
    }
    if (checksumAlgorithm.present) {
      map['checksum_algorithm'] = Variable<String>(checksumAlgorithm.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (writeState.present) {
      map['write_state'] = Variable<String>(writeState.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripChunksCompanion(')
          ..write('tripId: $tripId, ')
          ..write('sequence: $sequence, ')
          ..write('storageReference: $storageReference, ')
          ..write('encodingVersion: $encodingVersion, ')
          ..write('startElapsedNanos: $startElapsedNanos, ')
          ..write('endElapsedNanos: $endElapsedNanos, ')
          ..write('channelSampleCountsJson: $channelSampleCountsJson, ')
          ..write('compression: $compression, ')
          ..write('atomicWriteStrategy: $atomicWriteStrategy, ')
          ..write('checksumAlgorithm: $checksumAlgorithm, ')
          ..write('checksum: $checksum, ')
          ..write('byteLength: $byteLength, ')
          ..write('writeState: $writeState, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripEventsTable extends TripEvents
    with TableInfo<$TripEventsTable, TripEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startElapsedNanosMeta = const VerificationMeta(
    'startElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> startElapsedNanos = GeneratedColumn<int>(
    'start_elapsed_nanos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peakElapsedNanosMeta = const VerificationMeta(
    'peakElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> peakElapsedNanos = GeneratedColumn<int>(
    'peak_elapsed_nanos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endElapsedNanosMeta = const VerificationMeta(
    'endElapsedNanos',
  );
  @override
  late final GeneratedColumn<int> endElapsedNanos = GeneratedColumn<int>(
    'end_elapsed_nanos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<double> severity = GeneratedColumn<double>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityCalibrationVersionMeta =
      const VerificationMeta('severityCalibrationVersion');
  @override
  late final GeneratedColumn<String> severityCalibrationVersion =
      GeneratedColumn<String>(
        'severity_calibration_version',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityFlagsJsonMeta = const VerificationMeta(
    'qualityFlagsJson',
  );
  @override
  late final GeneratedColumn<String> qualityFlagsJson = GeneratedColumn<String>(
    'quality_flags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryMeasurementsJsonMeta =
      const VerificationMeta('primaryMeasurementsJson');
  @override
  late final GeneratedColumn<String> primaryMeasurementsJson =
      GeneratedColumn<String>(
        'primary_measurements_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _ruleEvidenceJsonMeta = const VerificationMeta(
    'ruleEvidenceJson',
  );
  @override
  late final GeneratedColumn<String> ruleEvidenceJson = GeneratedColumn<String>(
    'rule_evidence_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mlEvidenceJsonMeta = const VerificationMeta(
    'mlEvidenceJson',
  );
  @override
  late final GeneratedColumn<String> mlEvidenceJson = GeneratedColumn<String>(
    'ml_evidence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextTagsJsonMeta = const VerificationMeta(
    'contextTagsJson',
  );
  @override
  late final GeneratedColumn<String> contextTagsJson = GeneratedColumn<String>(
    'context_tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    eventType,
    startElapsedNanos,
    peakElapsedNanos,
    endElapsedNanos,
    severity,
    severityCalibrationVersion,
    confidence,
    qualityFlagsJson,
    primaryMeasurementsJson,
    ruleEvidenceJson,
    mlEvidenceJson,
    contextTagsJson,
    algorithmVersion,
    createdAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('start_elapsed_nanos')) {
      context.handle(
        _startElapsedNanosMeta,
        startElapsedNanos.isAcceptableOrUnknown(
          data['start_elapsed_nanos']!,
          _startElapsedNanosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startElapsedNanosMeta);
    }
    if (data.containsKey('peak_elapsed_nanos')) {
      context.handle(
        _peakElapsedNanosMeta,
        peakElapsedNanos.isAcceptableOrUnknown(
          data['peak_elapsed_nanos']!,
          _peakElapsedNanosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peakElapsedNanosMeta);
    }
    if (data.containsKey('end_elapsed_nanos')) {
      context.handle(
        _endElapsedNanosMeta,
        endElapsedNanos.isAcceptableOrUnknown(
          data['end_elapsed_nanos']!,
          _endElapsedNanosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endElapsedNanosMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('severity_calibration_version')) {
      context.handle(
        _severityCalibrationVersionMeta,
        severityCalibrationVersion.isAcceptableOrUnknown(
          data['severity_calibration_version']!,
          _severityCalibrationVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_severityCalibrationVersionMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('quality_flags_json')) {
      context.handle(
        _qualityFlagsJsonMeta,
        qualityFlagsJson.isAcceptableOrUnknown(
          data['quality_flags_json']!,
          _qualityFlagsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_qualityFlagsJsonMeta);
    }
    if (data.containsKey('primary_measurements_json')) {
      context.handle(
        _primaryMeasurementsJsonMeta,
        primaryMeasurementsJson.isAcceptableOrUnknown(
          data['primary_measurements_json']!,
          _primaryMeasurementsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_primaryMeasurementsJsonMeta);
    }
    if (data.containsKey('rule_evidence_json')) {
      context.handle(
        _ruleEvidenceJsonMeta,
        ruleEvidenceJson.isAcceptableOrUnknown(
          data['rule_evidence_json']!,
          _ruleEvidenceJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ruleEvidenceJsonMeta);
    }
    if (data.containsKey('ml_evidence_json')) {
      context.handle(
        _mlEvidenceJsonMeta,
        mlEvidenceJson.isAcceptableOrUnknown(
          data['ml_evidence_json']!,
          _mlEvidenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('context_tags_json')) {
      context.handle(
        _contextTagsJsonMeta,
        contextTagsJson.isAcceptableOrUnknown(
          data['context_tags_json']!,
          _contextTagsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contextTagsJsonMeta);
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algorithmVersionMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      startElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_elapsed_nanos'],
      )!,
      peakElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}peak_elapsed_nanos'],
      )!,
      endElapsedNanos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_elapsed_nanos'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}severity'],
      )!,
      severityCalibrationVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity_calibration_version'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      qualityFlagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_flags_json'],
      )!,
      primaryMeasurementsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_measurements_json'],
      )!,
      ruleEvidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_evidence_json'],
      )!,
      mlEvidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ml_evidence_json'],
      ),
      contextTagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_tags_json'],
      )!,
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
    );
  }

  @override
  $TripEventsTable createAlias(String alias) {
    return $TripEventsTable(attachedDatabase, alias);
  }
}

class TripEvent extends DataClass implements Insertable<TripEvent> {
  final String id;
  final String tripId;
  final String eventType;
  final int startElapsedNanos;
  final int peakElapsedNanos;
  final int endElapsedNanos;
  final double severity;
  final String severityCalibrationVersion;
  final double confidence;
  final String qualityFlagsJson;
  final String primaryMeasurementsJson;
  final String ruleEvidenceJson;
  final String? mlEvidenceJson;
  final String contextTagsJson;
  final String algorithmVersion;
  final int createdAtMicros;
  const TripEvent({
    required this.id,
    required this.tripId,
    required this.eventType,
    required this.startElapsedNanos,
    required this.peakElapsedNanos,
    required this.endElapsedNanos,
    required this.severity,
    required this.severityCalibrationVersion,
    required this.confidence,
    required this.qualityFlagsJson,
    required this.primaryMeasurementsJson,
    required this.ruleEvidenceJson,
    this.mlEvidenceJson,
    required this.contextTagsJson,
    required this.algorithmVersion,
    required this.createdAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['event_type'] = Variable<String>(eventType);
    map['start_elapsed_nanos'] = Variable<int>(startElapsedNanos);
    map['peak_elapsed_nanos'] = Variable<int>(peakElapsedNanos);
    map['end_elapsed_nanos'] = Variable<int>(endElapsedNanos);
    map['severity'] = Variable<double>(severity);
    map['severity_calibration_version'] = Variable<String>(
      severityCalibrationVersion,
    );
    map['confidence'] = Variable<double>(confidence);
    map['quality_flags_json'] = Variable<String>(qualityFlagsJson);
    map['primary_measurements_json'] = Variable<String>(
      primaryMeasurementsJson,
    );
    map['rule_evidence_json'] = Variable<String>(ruleEvidenceJson);
    if (!nullToAbsent || mlEvidenceJson != null) {
      map['ml_evidence_json'] = Variable<String>(mlEvidenceJson);
    }
    map['context_tags_json'] = Variable<String>(contextTagsJson);
    map['algorithm_version'] = Variable<String>(algorithmVersion);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    return map;
  }

  TripEventsCompanion toCompanion(bool nullToAbsent) {
    return TripEventsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      eventType: Value(eventType),
      startElapsedNanos: Value(startElapsedNanos),
      peakElapsedNanos: Value(peakElapsedNanos),
      endElapsedNanos: Value(endElapsedNanos),
      severity: Value(severity),
      severityCalibrationVersion: Value(severityCalibrationVersion),
      confidence: Value(confidence),
      qualityFlagsJson: Value(qualityFlagsJson),
      primaryMeasurementsJson: Value(primaryMeasurementsJson),
      ruleEvidenceJson: Value(ruleEvidenceJson),
      mlEvidenceJson: mlEvidenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mlEvidenceJson),
      contextTagsJson: Value(contextTagsJson),
      algorithmVersion: Value(algorithmVersion),
      createdAtMicros: Value(createdAtMicros),
    );
  }

  factory TripEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripEvent(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      startElapsedNanos: serializer.fromJson<int>(json['startElapsedNanos']),
      peakElapsedNanos: serializer.fromJson<int>(json['peakElapsedNanos']),
      endElapsedNanos: serializer.fromJson<int>(json['endElapsedNanos']),
      severity: serializer.fromJson<double>(json['severity']),
      severityCalibrationVersion: serializer.fromJson<String>(
        json['severityCalibrationVersion'],
      ),
      confidence: serializer.fromJson<double>(json['confidence']),
      qualityFlagsJson: serializer.fromJson<String>(json['qualityFlagsJson']),
      primaryMeasurementsJson: serializer.fromJson<String>(
        json['primaryMeasurementsJson'],
      ),
      ruleEvidenceJson: serializer.fromJson<String>(json['ruleEvidenceJson']),
      mlEvidenceJson: serializer.fromJson<String?>(json['mlEvidenceJson']),
      contextTagsJson: serializer.fromJson<String>(json['contextTagsJson']),
      algorithmVersion: serializer.fromJson<String>(json['algorithmVersion']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'eventType': serializer.toJson<String>(eventType),
      'startElapsedNanos': serializer.toJson<int>(startElapsedNanos),
      'peakElapsedNanos': serializer.toJson<int>(peakElapsedNanos),
      'endElapsedNanos': serializer.toJson<int>(endElapsedNanos),
      'severity': serializer.toJson<double>(severity),
      'severityCalibrationVersion': serializer.toJson<String>(
        severityCalibrationVersion,
      ),
      'confidence': serializer.toJson<double>(confidence),
      'qualityFlagsJson': serializer.toJson<String>(qualityFlagsJson),
      'primaryMeasurementsJson': serializer.toJson<String>(
        primaryMeasurementsJson,
      ),
      'ruleEvidenceJson': serializer.toJson<String>(ruleEvidenceJson),
      'mlEvidenceJson': serializer.toJson<String?>(mlEvidenceJson),
      'contextTagsJson': serializer.toJson<String>(contextTagsJson),
      'algorithmVersion': serializer.toJson<String>(algorithmVersion),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
    };
  }

  TripEvent copyWith({
    String? id,
    String? tripId,
    String? eventType,
    int? startElapsedNanos,
    int? peakElapsedNanos,
    int? endElapsedNanos,
    double? severity,
    String? severityCalibrationVersion,
    double? confidence,
    String? qualityFlagsJson,
    String? primaryMeasurementsJson,
    String? ruleEvidenceJson,
    Value<String?> mlEvidenceJson = const Value.absent(),
    String? contextTagsJson,
    String? algorithmVersion,
    int? createdAtMicros,
  }) => TripEvent(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    eventType: eventType ?? this.eventType,
    startElapsedNanos: startElapsedNanos ?? this.startElapsedNanos,
    peakElapsedNanos: peakElapsedNanos ?? this.peakElapsedNanos,
    endElapsedNanos: endElapsedNanos ?? this.endElapsedNanos,
    severity: severity ?? this.severity,
    severityCalibrationVersion:
        severityCalibrationVersion ?? this.severityCalibrationVersion,
    confidence: confidence ?? this.confidence,
    qualityFlagsJson: qualityFlagsJson ?? this.qualityFlagsJson,
    primaryMeasurementsJson:
        primaryMeasurementsJson ?? this.primaryMeasurementsJson,
    ruleEvidenceJson: ruleEvidenceJson ?? this.ruleEvidenceJson,
    mlEvidenceJson: mlEvidenceJson.present
        ? mlEvidenceJson.value
        : this.mlEvidenceJson,
    contextTagsJson: contextTagsJson ?? this.contextTagsJson,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
  );
  TripEvent copyWithCompanion(TripEventsCompanion data) {
    return TripEvent(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      startElapsedNanos: data.startElapsedNanos.present
          ? data.startElapsedNanos.value
          : this.startElapsedNanos,
      peakElapsedNanos: data.peakElapsedNanos.present
          ? data.peakElapsedNanos.value
          : this.peakElapsedNanos,
      endElapsedNanos: data.endElapsedNanos.present
          ? data.endElapsedNanos.value
          : this.endElapsedNanos,
      severity: data.severity.present ? data.severity.value : this.severity,
      severityCalibrationVersion: data.severityCalibrationVersion.present
          ? data.severityCalibrationVersion.value
          : this.severityCalibrationVersion,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      qualityFlagsJson: data.qualityFlagsJson.present
          ? data.qualityFlagsJson.value
          : this.qualityFlagsJson,
      primaryMeasurementsJson: data.primaryMeasurementsJson.present
          ? data.primaryMeasurementsJson.value
          : this.primaryMeasurementsJson,
      ruleEvidenceJson: data.ruleEvidenceJson.present
          ? data.ruleEvidenceJson.value
          : this.ruleEvidenceJson,
      mlEvidenceJson: data.mlEvidenceJson.present
          ? data.mlEvidenceJson.value
          : this.mlEvidenceJson,
      contextTagsJson: data.contextTagsJson.present
          ? data.contextTagsJson.value
          : this.contextTagsJson,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripEvent(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('eventType: $eventType, ')
          ..write('startElapsedNanos: $startElapsedNanos, ')
          ..write('peakElapsedNanos: $peakElapsedNanos, ')
          ..write('endElapsedNanos: $endElapsedNanos, ')
          ..write('severity: $severity, ')
          ..write('severityCalibrationVersion: $severityCalibrationVersion, ')
          ..write('confidence: $confidence, ')
          ..write('qualityFlagsJson: $qualityFlagsJson, ')
          ..write('primaryMeasurementsJson: $primaryMeasurementsJson, ')
          ..write('ruleEvidenceJson: $ruleEvidenceJson, ')
          ..write('mlEvidenceJson: $mlEvidenceJson, ')
          ..write('contextTagsJson: $contextTagsJson, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtMicros: $createdAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    eventType,
    startElapsedNanos,
    peakElapsedNanos,
    endElapsedNanos,
    severity,
    severityCalibrationVersion,
    confidence,
    qualityFlagsJson,
    primaryMeasurementsJson,
    ruleEvidenceJson,
    mlEvidenceJson,
    contextTagsJson,
    algorithmVersion,
    createdAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripEvent &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.eventType == this.eventType &&
          other.startElapsedNanos == this.startElapsedNanos &&
          other.peakElapsedNanos == this.peakElapsedNanos &&
          other.endElapsedNanos == this.endElapsedNanos &&
          other.severity == this.severity &&
          other.severityCalibrationVersion == this.severityCalibrationVersion &&
          other.confidence == this.confidence &&
          other.qualityFlagsJson == this.qualityFlagsJson &&
          other.primaryMeasurementsJson == this.primaryMeasurementsJson &&
          other.ruleEvidenceJson == this.ruleEvidenceJson &&
          other.mlEvidenceJson == this.mlEvidenceJson &&
          other.contextTagsJson == this.contextTagsJson &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtMicros == this.createdAtMicros);
}

class TripEventsCompanion extends UpdateCompanion<TripEvent> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> eventType;
  final Value<int> startElapsedNanos;
  final Value<int> peakElapsedNanos;
  final Value<int> endElapsedNanos;
  final Value<double> severity;
  final Value<String> severityCalibrationVersion;
  final Value<double> confidence;
  final Value<String> qualityFlagsJson;
  final Value<String> primaryMeasurementsJson;
  final Value<String> ruleEvidenceJson;
  final Value<String?> mlEvidenceJson;
  final Value<String> contextTagsJson;
  final Value<String> algorithmVersion;
  final Value<int> createdAtMicros;
  final Value<int> rowid;
  const TripEventsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.startElapsedNanos = const Value.absent(),
    this.peakElapsedNanos = const Value.absent(),
    this.endElapsedNanos = const Value.absent(),
    this.severity = const Value.absent(),
    this.severityCalibrationVersion = const Value.absent(),
    this.confidence = const Value.absent(),
    this.qualityFlagsJson = const Value.absent(),
    this.primaryMeasurementsJson = const Value.absent(),
    this.ruleEvidenceJson = const Value.absent(),
    this.mlEvidenceJson = const Value.absent(),
    this.contextTagsJson = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripEventsCompanion.insert({
    required String id,
    required String tripId,
    required String eventType,
    required int startElapsedNanos,
    required int peakElapsedNanos,
    required int endElapsedNanos,
    required double severity,
    required String severityCalibrationVersion,
    required double confidence,
    required String qualityFlagsJson,
    required String primaryMeasurementsJson,
    required String ruleEvidenceJson,
    this.mlEvidenceJson = const Value.absent(),
    required String contextTagsJson,
    required String algorithmVersion,
    required int createdAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       eventType = Value(eventType),
       startElapsedNanos = Value(startElapsedNanos),
       peakElapsedNanos = Value(peakElapsedNanos),
       endElapsedNanos = Value(endElapsedNanos),
       severity = Value(severity),
       severityCalibrationVersion = Value(severityCalibrationVersion),
       confidence = Value(confidence),
       qualityFlagsJson = Value(qualityFlagsJson),
       primaryMeasurementsJson = Value(primaryMeasurementsJson),
       ruleEvidenceJson = Value(ruleEvidenceJson),
       contextTagsJson = Value(contextTagsJson),
       algorithmVersion = Value(algorithmVersion),
       createdAtMicros = Value(createdAtMicros);
  static Insertable<TripEvent> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? eventType,
    Expression<int>? startElapsedNanos,
    Expression<int>? peakElapsedNanos,
    Expression<int>? endElapsedNanos,
    Expression<double>? severity,
    Expression<String>? severityCalibrationVersion,
    Expression<double>? confidence,
    Expression<String>? qualityFlagsJson,
    Expression<String>? primaryMeasurementsJson,
    Expression<String>? ruleEvidenceJson,
    Expression<String>? mlEvidenceJson,
    Expression<String>? contextTagsJson,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (eventType != null) 'event_type': eventType,
      if (startElapsedNanos != null) 'start_elapsed_nanos': startElapsedNanos,
      if (peakElapsedNanos != null) 'peak_elapsed_nanos': peakElapsedNanos,
      if (endElapsedNanos != null) 'end_elapsed_nanos': endElapsedNanos,
      if (severity != null) 'severity': severity,
      if (severityCalibrationVersion != null)
        'severity_calibration_version': severityCalibrationVersion,
      if (confidence != null) 'confidence': confidence,
      if (qualityFlagsJson != null) 'quality_flags_json': qualityFlagsJson,
      if (primaryMeasurementsJson != null)
        'primary_measurements_json': primaryMeasurementsJson,
      if (ruleEvidenceJson != null) 'rule_evidence_json': ruleEvidenceJson,
      if (mlEvidenceJson != null) 'ml_evidence_json': mlEvidenceJson,
      if (contextTagsJson != null) 'context_tags_json': contextTagsJson,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? eventType,
    Value<int>? startElapsedNanos,
    Value<int>? peakElapsedNanos,
    Value<int>? endElapsedNanos,
    Value<double>? severity,
    Value<String>? severityCalibrationVersion,
    Value<double>? confidence,
    Value<String>? qualityFlagsJson,
    Value<String>? primaryMeasurementsJson,
    Value<String>? ruleEvidenceJson,
    Value<String?>? mlEvidenceJson,
    Value<String>? contextTagsJson,
    Value<String>? algorithmVersion,
    Value<int>? createdAtMicros,
    Value<int>? rowid,
  }) {
    return TripEventsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      eventType: eventType ?? this.eventType,
      startElapsedNanos: startElapsedNanos ?? this.startElapsedNanos,
      peakElapsedNanos: peakElapsedNanos ?? this.peakElapsedNanos,
      endElapsedNanos: endElapsedNanos ?? this.endElapsedNanos,
      severity: severity ?? this.severity,
      severityCalibrationVersion:
          severityCalibrationVersion ?? this.severityCalibrationVersion,
      confidence: confidence ?? this.confidence,
      qualityFlagsJson: qualityFlagsJson ?? this.qualityFlagsJson,
      primaryMeasurementsJson:
          primaryMeasurementsJson ?? this.primaryMeasurementsJson,
      ruleEvidenceJson: ruleEvidenceJson ?? this.ruleEvidenceJson,
      mlEvidenceJson: mlEvidenceJson ?? this.mlEvidenceJson,
      contextTagsJson: contextTagsJson ?? this.contextTagsJson,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (startElapsedNanos.present) {
      map['start_elapsed_nanos'] = Variable<int>(startElapsedNanos.value);
    }
    if (peakElapsedNanos.present) {
      map['peak_elapsed_nanos'] = Variable<int>(peakElapsedNanos.value);
    }
    if (endElapsedNanos.present) {
      map['end_elapsed_nanos'] = Variable<int>(endElapsedNanos.value);
    }
    if (severity.present) {
      map['severity'] = Variable<double>(severity.value);
    }
    if (severityCalibrationVersion.present) {
      map['severity_calibration_version'] = Variable<String>(
        severityCalibrationVersion.value,
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (qualityFlagsJson.present) {
      map['quality_flags_json'] = Variable<String>(qualityFlagsJson.value);
    }
    if (primaryMeasurementsJson.present) {
      map['primary_measurements_json'] = Variable<String>(
        primaryMeasurementsJson.value,
      );
    }
    if (ruleEvidenceJson.present) {
      map['rule_evidence_json'] = Variable<String>(ruleEvidenceJson.value);
    }
    if (mlEvidenceJson.present) {
      map['ml_evidence_json'] = Variable<String>(mlEvidenceJson.value);
    }
    if (contextTagsJson.present) {
      map['context_tags_json'] = Variable<String>(contextTagsJson.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripEventsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('eventType: $eventType, ')
          ..write('startElapsedNanos: $startElapsedNanos, ')
          ..write('peakElapsedNanos: $peakElapsedNanos, ')
          ..write('endElapsedNanos: $endElapsedNanos, ')
          ..write('severity: $severity, ')
          ..write('severityCalibrationVersion: $severityCalibrationVersion, ')
          ..write('confidence: $confidence, ')
          ..write('qualityFlagsJson: $qualityFlagsJson, ')
          ..write('primaryMeasurementsJson: $primaryMeasurementsJson, ')
          ..write('ruleEvidenceJson: $ruleEvidenceJson, ')
          ..write('mlEvidenceJson: $mlEvidenceJson, ')
          ..write('contextTagsJson: $contextTagsJson, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriverBaselinesTable extends DriverBaselines
    with TableInfo<$DriverBaselinesTable, DriverBaseline> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriverBaselinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNamespaceMeta = const VerificationMeta(
    'ownerNamespace',
  );
  @override
  late final GeneratedColumn<String> ownerNamespace = GeneratedColumn<String>(
    'owner_namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _lifecycleStateMeta = const VerificationMeta(
    'lifecycleState',
  );
  @override
  late final GeneratedColumn<String> lifecycleState = GeneratedColumn<String>(
    'lifecycle_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionStatisticsJsonMeta =
      const VerificationMeta('dimensionStatisticsJson');
  @override
  late final GeneratedColumn<String> dimensionStatisticsJson =
      GeneratedColumn<String>(
        'dimension_statistics_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _baselineSchemaVersionMeta =
      const VerificationMeta('baselineSchemaVersion');
  @override
  late final GeneratedColumn<int> baselineSchemaVersion = GeneratedColumn<int>(
    'baseline_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoringVersionMeta = const VerificationMeta(
    'scoringVersion',
  );
  @override
  late final GeneratedColumn<String> scoringVersion = GeneratedColumn<String>(
    'scoring_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validTripCountMeta = const VerificationMeta(
    'validTripCount',
  );
  @override
  late final GeneratedColumn<int> validTripCount = GeneratedColumn<int>(
    'valid_trip_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowStartWallTimeMicrosMeta =
      const VerificationMeta('windowStartWallTimeMicros');
  @override
  late final GeneratedColumn<int> windowStartWallTimeMicros =
      GeneratedColumn<int>(
        'window_start_wall_time_micros',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _windowEndWallTimeMicrosMeta =
      const VerificationMeta('windowEndWallTimeMicros');
  @override
  late final GeneratedColumn<int> windowEndWallTimeMicros =
      GeneratedColumn<int>(
        'window_end_wall_time_micros',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerNamespace,
    vehicleId,
    lifecycleState,
    dimensionStatisticsJson,
    baselineSchemaVersion,
    scoringVersion,
    validTripCount,
    windowStartWallTimeMicros,
    windowEndWallTimeMicros,
    confidence,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'driver_baselines';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriverBaseline> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_namespace')) {
      context.handle(
        _ownerNamespaceMeta,
        ownerNamespace.isAcceptableOrUnknown(
          data['owner_namespace']!,
          _ownerNamespaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerNamespaceMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    }
    if (data.containsKey('lifecycle_state')) {
      context.handle(
        _lifecycleStateMeta,
        lifecycleState.isAcceptableOrUnknown(
          data['lifecycle_state']!,
          _lifecycleStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lifecycleStateMeta);
    }
    if (data.containsKey('dimension_statistics_json')) {
      context.handle(
        _dimensionStatisticsJsonMeta,
        dimensionStatisticsJson.isAcceptableOrUnknown(
          data['dimension_statistics_json']!,
          _dimensionStatisticsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dimensionStatisticsJsonMeta);
    }
    if (data.containsKey('baseline_schema_version')) {
      context.handle(
        _baselineSchemaVersionMeta,
        baselineSchemaVersion.isAcceptableOrUnknown(
          data['baseline_schema_version']!,
          _baselineSchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baselineSchemaVersionMeta);
    }
    if (data.containsKey('scoring_version')) {
      context.handle(
        _scoringVersionMeta,
        scoringVersion.isAcceptableOrUnknown(
          data['scoring_version']!,
          _scoringVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scoringVersionMeta);
    }
    if (data.containsKey('valid_trip_count')) {
      context.handle(
        _validTripCountMeta,
        validTripCount.isAcceptableOrUnknown(
          data['valid_trip_count']!,
          _validTripCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_validTripCountMeta);
    }
    if (data.containsKey('window_start_wall_time_micros')) {
      context.handle(
        _windowStartWallTimeMicrosMeta,
        windowStartWallTimeMicros.isAcceptableOrUnknown(
          data['window_start_wall_time_micros']!,
          _windowStartWallTimeMicrosMeta,
        ),
      );
    }
    if (data.containsKey('window_end_wall_time_micros')) {
      context.handle(
        _windowEndWallTimeMicrosMeta,
        windowEndWallTimeMicros.isAcceptableOrUnknown(
          data['window_end_wall_time_micros']!,
          _windowEndWallTimeMicrosMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriverBaseline map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriverBaseline(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerNamespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_namespace'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      ),
      lifecycleState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle_state'],
      )!,
      dimensionStatisticsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dimension_statistics_json'],
      )!,
      baselineSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}baseline_schema_version'],
      )!,
      scoringVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scoring_version'],
      )!,
      validTripCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valid_trip_count'],
      )!,
      windowStartWallTimeMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_start_wall_time_micros'],
      ),
      windowEndWallTimeMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_end_wall_time_micros'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $DriverBaselinesTable createAlias(String alias) {
    return $DriverBaselinesTable(attachedDatabase, alias);
  }
}

class DriverBaseline extends DataClass implements Insertable<DriverBaseline> {
  final String id;
  final String ownerNamespace;
  final String? vehicleId;
  final String lifecycleState;
  final String dimensionStatisticsJson;
  final int baselineSchemaVersion;
  final String scoringVersion;
  final int validTripCount;
  final int? windowStartWallTimeMicros;
  final int? windowEndWallTimeMicros;
  final double? confidence;
  final int createdAtMicros;
  final int updatedAtMicros;
  const DriverBaseline({
    required this.id,
    required this.ownerNamespace,
    this.vehicleId,
    required this.lifecycleState,
    required this.dimensionStatisticsJson,
    required this.baselineSchemaVersion,
    required this.scoringVersion,
    required this.validTripCount,
    this.windowStartWallTimeMicros,
    this.windowEndWallTimeMicros,
    this.confidence,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_namespace'] = Variable<String>(ownerNamespace);
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<String>(vehicleId);
    }
    map['lifecycle_state'] = Variable<String>(lifecycleState);
    map['dimension_statistics_json'] = Variable<String>(
      dimensionStatisticsJson,
    );
    map['baseline_schema_version'] = Variable<int>(baselineSchemaVersion);
    map['scoring_version'] = Variable<String>(scoringVersion);
    map['valid_trip_count'] = Variable<int>(validTripCount);
    if (!nullToAbsent || windowStartWallTimeMicros != null) {
      map['window_start_wall_time_micros'] = Variable<int>(
        windowStartWallTimeMicros,
      );
    }
    if (!nullToAbsent || windowEndWallTimeMicros != null) {
      map['window_end_wall_time_micros'] = Variable<int>(
        windowEndWallTimeMicros,
      );
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  DriverBaselinesCompanion toCompanion(bool nullToAbsent) {
    return DriverBaselinesCompanion(
      id: Value(id),
      ownerNamespace: Value(ownerNamespace),
      vehicleId: vehicleId == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleId),
      lifecycleState: Value(lifecycleState),
      dimensionStatisticsJson: Value(dimensionStatisticsJson),
      baselineSchemaVersion: Value(baselineSchemaVersion),
      scoringVersion: Value(scoringVersion),
      validTripCount: Value(validTripCount),
      windowStartWallTimeMicros:
          windowStartWallTimeMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(windowStartWallTimeMicros),
      windowEndWallTimeMicros: windowEndWallTimeMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(windowEndWallTimeMicros),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory DriverBaseline.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriverBaseline(
      id: serializer.fromJson<String>(json['id']),
      ownerNamespace: serializer.fromJson<String>(json['ownerNamespace']),
      vehicleId: serializer.fromJson<String?>(json['vehicleId']),
      lifecycleState: serializer.fromJson<String>(json['lifecycleState']),
      dimensionStatisticsJson: serializer.fromJson<String>(
        json['dimensionStatisticsJson'],
      ),
      baselineSchemaVersion: serializer.fromJson<int>(
        json['baselineSchemaVersion'],
      ),
      scoringVersion: serializer.fromJson<String>(json['scoringVersion']),
      validTripCount: serializer.fromJson<int>(json['validTripCount']),
      windowStartWallTimeMicros: serializer.fromJson<int?>(
        json['windowStartWallTimeMicros'],
      ),
      windowEndWallTimeMicros: serializer.fromJson<int?>(
        json['windowEndWallTimeMicros'],
      ),
      confidence: serializer.fromJson<double?>(json['confidence']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerNamespace': serializer.toJson<String>(ownerNamespace),
      'vehicleId': serializer.toJson<String?>(vehicleId),
      'lifecycleState': serializer.toJson<String>(lifecycleState),
      'dimensionStatisticsJson': serializer.toJson<String>(
        dimensionStatisticsJson,
      ),
      'baselineSchemaVersion': serializer.toJson<int>(baselineSchemaVersion),
      'scoringVersion': serializer.toJson<String>(scoringVersion),
      'validTripCount': serializer.toJson<int>(validTripCount),
      'windowStartWallTimeMicros': serializer.toJson<int?>(
        windowStartWallTimeMicros,
      ),
      'windowEndWallTimeMicros': serializer.toJson<int?>(
        windowEndWallTimeMicros,
      ),
      'confidence': serializer.toJson<double?>(confidence),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  DriverBaseline copyWith({
    String? id,
    String? ownerNamespace,
    Value<String?> vehicleId = const Value.absent(),
    String? lifecycleState,
    String? dimensionStatisticsJson,
    int? baselineSchemaVersion,
    String? scoringVersion,
    int? validTripCount,
    Value<int?> windowStartWallTimeMicros = const Value.absent(),
    Value<int?> windowEndWallTimeMicros = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => DriverBaseline(
    id: id ?? this.id,
    ownerNamespace: ownerNamespace ?? this.ownerNamespace,
    vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
    lifecycleState: lifecycleState ?? this.lifecycleState,
    dimensionStatisticsJson:
        dimensionStatisticsJson ?? this.dimensionStatisticsJson,
    baselineSchemaVersion: baselineSchemaVersion ?? this.baselineSchemaVersion,
    scoringVersion: scoringVersion ?? this.scoringVersion,
    validTripCount: validTripCount ?? this.validTripCount,
    windowStartWallTimeMicros: windowStartWallTimeMicros.present
        ? windowStartWallTimeMicros.value
        : this.windowStartWallTimeMicros,
    windowEndWallTimeMicros: windowEndWallTimeMicros.present
        ? windowEndWallTimeMicros.value
        : this.windowEndWallTimeMicros,
    confidence: confidence.present ? confidence.value : this.confidence,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  DriverBaseline copyWithCompanion(DriverBaselinesCompanion data) {
    return DriverBaseline(
      id: data.id.present ? data.id.value : this.id,
      ownerNamespace: data.ownerNamespace.present
          ? data.ownerNamespace.value
          : this.ownerNamespace,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      lifecycleState: data.lifecycleState.present
          ? data.lifecycleState.value
          : this.lifecycleState,
      dimensionStatisticsJson: data.dimensionStatisticsJson.present
          ? data.dimensionStatisticsJson.value
          : this.dimensionStatisticsJson,
      baselineSchemaVersion: data.baselineSchemaVersion.present
          ? data.baselineSchemaVersion.value
          : this.baselineSchemaVersion,
      scoringVersion: data.scoringVersion.present
          ? data.scoringVersion.value
          : this.scoringVersion,
      validTripCount: data.validTripCount.present
          ? data.validTripCount.value
          : this.validTripCount,
      windowStartWallTimeMicros: data.windowStartWallTimeMicros.present
          ? data.windowStartWallTimeMicros.value
          : this.windowStartWallTimeMicros,
      windowEndWallTimeMicros: data.windowEndWallTimeMicros.present
          ? data.windowEndWallTimeMicros.value
          : this.windowEndWallTimeMicros,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriverBaseline(')
          ..write('id: $id, ')
          ..write('ownerNamespace: $ownerNamespace, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('lifecycleState: $lifecycleState, ')
          ..write('dimensionStatisticsJson: $dimensionStatisticsJson, ')
          ..write('baselineSchemaVersion: $baselineSchemaVersion, ')
          ..write('scoringVersion: $scoringVersion, ')
          ..write('validTripCount: $validTripCount, ')
          ..write('windowStartWallTimeMicros: $windowStartWallTimeMicros, ')
          ..write('windowEndWallTimeMicros: $windowEndWallTimeMicros, ')
          ..write('confidence: $confidence, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerNamespace,
    vehicleId,
    lifecycleState,
    dimensionStatisticsJson,
    baselineSchemaVersion,
    scoringVersion,
    validTripCount,
    windowStartWallTimeMicros,
    windowEndWallTimeMicros,
    confidence,
    createdAtMicros,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriverBaseline &&
          other.id == this.id &&
          other.ownerNamespace == this.ownerNamespace &&
          other.vehicleId == this.vehicleId &&
          other.lifecycleState == this.lifecycleState &&
          other.dimensionStatisticsJson == this.dimensionStatisticsJson &&
          other.baselineSchemaVersion == this.baselineSchemaVersion &&
          other.scoringVersion == this.scoringVersion &&
          other.validTripCount == this.validTripCount &&
          other.windowStartWallTimeMicros == this.windowStartWallTimeMicros &&
          other.windowEndWallTimeMicros == this.windowEndWallTimeMicros &&
          other.confidence == this.confidence &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class DriverBaselinesCompanion extends UpdateCompanion<DriverBaseline> {
  final Value<String> id;
  final Value<String> ownerNamespace;
  final Value<String?> vehicleId;
  final Value<String> lifecycleState;
  final Value<String> dimensionStatisticsJson;
  final Value<int> baselineSchemaVersion;
  final Value<String> scoringVersion;
  final Value<int> validTripCount;
  final Value<int?> windowStartWallTimeMicros;
  final Value<int?> windowEndWallTimeMicros;
  final Value<double?> confidence;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const DriverBaselinesCompanion({
    this.id = const Value.absent(),
    this.ownerNamespace = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.lifecycleState = const Value.absent(),
    this.dimensionStatisticsJson = const Value.absent(),
    this.baselineSchemaVersion = const Value.absent(),
    this.scoringVersion = const Value.absent(),
    this.validTripCount = const Value.absent(),
    this.windowStartWallTimeMicros = const Value.absent(),
    this.windowEndWallTimeMicros = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriverBaselinesCompanion.insert({
    required String id,
    required String ownerNamespace,
    this.vehicleId = const Value.absent(),
    required String lifecycleState,
    required String dimensionStatisticsJson,
    required int baselineSchemaVersion,
    required String scoringVersion,
    required int validTripCount,
    this.windowStartWallTimeMicros = const Value.absent(),
    this.windowEndWallTimeMicros = const Value.absent(),
    this.confidence = const Value.absent(),
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerNamespace = Value(ownerNamespace),
       lifecycleState = Value(lifecycleState),
       dimensionStatisticsJson = Value(dimensionStatisticsJson),
       baselineSchemaVersion = Value(baselineSchemaVersion),
       scoringVersion = Value(scoringVersion),
       validTripCount = Value(validTripCount),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<DriverBaseline> custom({
    Expression<String>? id,
    Expression<String>? ownerNamespace,
    Expression<String>? vehicleId,
    Expression<String>? lifecycleState,
    Expression<String>? dimensionStatisticsJson,
    Expression<int>? baselineSchemaVersion,
    Expression<String>? scoringVersion,
    Expression<int>? validTripCount,
    Expression<int>? windowStartWallTimeMicros,
    Expression<int>? windowEndWallTimeMicros,
    Expression<double>? confidence,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerNamespace != null) 'owner_namespace': ownerNamespace,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (lifecycleState != null) 'lifecycle_state': lifecycleState,
      if (dimensionStatisticsJson != null)
        'dimension_statistics_json': dimensionStatisticsJson,
      if (baselineSchemaVersion != null)
        'baseline_schema_version': baselineSchemaVersion,
      if (scoringVersion != null) 'scoring_version': scoringVersion,
      if (validTripCount != null) 'valid_trip_count': validTripCount,
      if (windowStartWallTimeMicros != null)
        'window_start_wall_time_micros': windowStartWallTimeMicros,
      if (windowEndWallTimeMicros != null)
        'window_end_wall_time_micros': windowEndWallTimeMicros,
      if (confidence != null) 'confidence': confidence,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriverBaselinesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerNamespace,
    Value<String?>? vehicleId,
    Value<String>? lifecycleState,
    Value<String>? dimensionStatisticsJson,
    Value<int>? baselineSchemaVersion,
    Value<String>? scoringVersion,
    Value<int>? validTripCount,
    Value<int?>? windowStartWallTimeMicros,
    Value<int?>? windowEndWallTimeMicros,
    Value<double?>? confidence,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return DriverBaselinesCompanion(
      id: id ?? this.id,
      ownerNamespace: ownerNamespace ?? this.ownerNamespace,
      vehicleId: vehicleId ?? this.vehicleId,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      dimensionStatisticsJson:
          dimensionStatisticsJson ?? this.dimensionStatisticsJson,
      baselineSchemaVersion:
          baselineSchemaVersion ?? this.baselineSchemaVersion,
      scoringVersion: scoringVersion ?? this.scoringVersion,
      validTripCount: validTripCount ?? this.validTripCount,
      windowStartWallTimeMicros:
          windowStartWallTimeMicros ?? this.windowStartWallTimeMicros,
      windowEndWallTimeMicros:
          windowEndWallTimeMicros ?? this.windowEndWallTimeMicros,
      confidence: confidence ?? this.confidence,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerNamespace.present) {
      map['owner_namespace'] = Variable<String>(ownerNamespace.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (lifecycleState.present) {
      map['lifecycle_state'] = Variable<String>(lifecycleState.value);
    }
    if (dimensionStatisticsJson.present) {
      map['dimension_statistics_json'] = Variable<String>(
        dimensionStatisticsJson.value,
      );
    }
    if (baselineSchemaVersion.present) {
      map['baseline_schema_version'] = Variable<int>(
        baselineSchemaVersion.value,
      );
    }
    if (scoringVersion.present) {
      map['scoring_version'] = Variable<String>(scoringVersion.value);
    }
    if (validTripCount.present) {
      map['valid_trip_count'] = Variable<int>(validTripCount.value);
    }
    if (windowStartWallTimeMicros.present) {
      map['window_start_wall_time_micros'] = Variable<int>(
        windowStartWallTimeMicros.value,
      );
    }
    if (windowEndWallTimeMicros.present) {
      map['window_end_wall_time_micros'] = Variable<int>(
        windowEndWallTimeMicros.value,
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriverBaselinesCompanion(')
          ..write('id: $id, ')
          ..write('ownerNamespace: $ownerNamespace, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('lifecycleState: $lifecycleState, ')
          ..write('dimensionStatisticsJson: $dimensionStatisticsJson, ')
          ..write('baselineSchemaVersion: $baselineSchemaVersion, ')
          ..write('scoringVersion: $scoringVersion, ')
          ..write('validTripCount: $validTripCount, ')
          ..write('windowStartWallTimeMicros: $windowStartWallTimeMicros, ')
          ..write('windowEndWallTimeMicros: $windowEndWallTimeMicros, ')
          ..write('confidence: $confidence, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripScoresTable extends TripScores
    with TableInfo<$TripScoresTable, TripScore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripScoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scoreSchemaVersionMeta =
      const VerificationMeta('scoreSchemaVersion');
  @override
  late final GeneratedColumn<int> scoreSchemaVersion = GeneratedColumn<int>(
    'score_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoringVersionMeta = const VerificationMeta(
    'scoringVersion',
  );
  @override
  late final GeneratedColumn<String> scoringVersion = GeneratedColumn<String>(
    'scoring_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionValuesJsonMeta =
      const VerificationMeta('dimensionValuesJson');
  @override
  late final GeneratedColumn<String> dimensionValuesJson =
      GeneratedColumn<String>(
        'dimension_values_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _overallScoreMeta = const VerificationMeta(
    'overallScore',
  );
  @override
  late final GeneratedColumn<double> overallScore = GeneratedColumn<double>(
    'overall_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eligibilityStateMeta = const VerificationMeta(
    'eligibilityState',
  );
  @override
  late final GeneratedColumn<String> eligibilityState = GeneratedColumn<String>(
    'eligibility_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _auditContributionsJsonMeta =
      const VerificationMeta('auditContributionsJson');
  @override
  late final GeneratedColumn<String> auditContributionsJson =
      GeneratedColumn<String>(
        'audit_contributions_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _baselineIdMeta = const VerificationMeta(
    'baselineId',
  );
  @override
  late final GeneratedColumn<String> baselineId = GeneratedColumn<String>(
    'baseline_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES driver_baselines (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _modelVersionsJsonMeta = const VerificationMeta(
    'modelVersionsJson',
  );
  @override
  late final GeneratedColumn<String> modelVersionsJson =
      GeneratedColumn<String>(
        'model_versions_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    scoreSchemaVersion,
    scoringVersion,
    dimensionValuesJson,
    overallScore,
    confidence,
    eligibilityState,
    auditContributionsJson,
    baselineId,
    modelVersionsJson,
    createdAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_scores';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripScore> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('score_schema_version')) {
      context.handle(
        _scoreSchemaVersionMeta,
        scoreSchemaVersion.isAcceptableOrUnknown(
          data['score_schema_version']!,
          _scoreSchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scoreSchemaVersionMeta);
    }
    if (data.containsKey('scoring_version')) {
      context.handle(
        _scoringVersionMeta,
        scoringVersion.isAcceptableOrUnknown(
          data['scoring_version']!,
          _scoringVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scoringVersionMeta);
    }
    if (data.containsKey('dimension_values_json')) {
      context.handle(
        _dimensionValuesJsonMeta,
        dimensionValuesJson.isAcceptableOrUnknown(
          data['dimension_values_json']!,
          _dimensionValuesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dimensionValuesJsonMeta);
    }
    if (data.containsKey('overall_score')) {
      context.handle(
        _overallScoreMeta,
        overallScore.isAcceptableOrUnknown(
          data['overall_score']!,
          _overallScoreMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('eligibility_state')) {
      context.handle(
        _eligibilityStateMeta,
        eligibilityState.isAcceptableOrUnknown(
          data['eligibility_state']!,
          _eligibilityStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eligibilityStateMeta);
    }
    if (data.containsKey('audit_contributions_json')) {
      context.handle(
        _auditContributionsJsonMeta,
        auditContributionsJson.isAcceptableOrUnknown(
          data['audit_contributions_json']!,
          _auditContributionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_auditContributionsJsonMeta);
    }
    if (data.containsKey('baseline_id')) {
      context.handle(
        _baselineIdMeta,
        baselineId.isAcceptableOrUnknown(data['baseline_id']!, _baselineIdMeta),
      );
    }
    if (data.containsKey('model_versions_json')) {
      context.handle(
        _modelVersionsJsonMeta,
        modelVersionsJson.isAcceptableOrUnknown(
          data['model_versions_json']!,
          _modelVersionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripScore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripScore(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      scoreSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score_schema_version'],
      )!,
      scoringVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scoring_version'],
      )!,
      dimensionValuesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dimension_values_json'],
      )!,
      overallScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}overall_score'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      eligibilityState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eligibility_state'],
      )!,
      auditContributionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audit_contributions_json'],
      )!,
      baselineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_id'],
      ),
      modelVersionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_versions_json'],
      ),
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
    );
  }

  @override
  $TripScoresTable createAlias(String alias) {
    return $TripScoresTable(attachedDatabase, alias);
  }
}

class TripScore extends DataClass implements Insertable<TripScore> {
  final String id;
  final String tripId;
  final int scoreSchemaVersion;
  final String scoringVersion;
  final String dimensionValuesJson;
  final double? overallScore;
  final double? confidence;
  final String eligibilityState;
  final String auditContributionsJson;
  final String? baselineId;
  final String? modelVersionsJson;
  final int createdAtMicros;
  const TripScore({
    required this.id,
    required this.tripId,
    required this.scoreSchemaVersion,
    required this.scoringVersion,
    required this.dimensionValuesJson,
    this.overallScore,
    this.confidence,
    required this.eligibilityState,
    required this.auditContributionsJson,
    this.baselineId,
    this.modelVersionsJson,
    required this.createdAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['score_schema_version'] = Variable<int>(scoreSchemaVersion);
    map['scoring_version'] = Variable<String>(scoringVersion);
    map['dimension_values_json'] = Variable<String>(dimensionValuesJson);
    if (!nullToAbsent || overallScore != null) {
      map['overall_score'] = Variable<double>(overallScore);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['eligibility_state'] = Variable<String>(eligibilityState);
    map['audit_contributions_json'] = Variable<String>(auditContributionsJson);
    if (!nullToAbsent || baselineId != null) {
      map['baseline_id'] = Variable<String>(baselineId);
    }
    if (!nullToAbsent || modelVersionsJson != null) {
      map['model_versions_json'] = Variable<String>(modelVersionsJson);
    }
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    return map;
  }

  TripScoresCompanion toCompanion(bool nullToAbsent) {
    return TripScoresCompanion(
      id: Value(id),
      tripId: Value(tripId),
      scoreSchemaVersion: Value(scoreSchemaVersion),
      scoringVersion: Value(scoringVersion),
      dimensionValuesJson: Value(dimensionValuesJson),
      overallScore: overallScore == null && nullToAbsent
          ? const Value.absent()
          : Value(overallScore),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      eligibilityState: Value(eligibilityState),
      auditContributionsJson: Value(auditContributionsJson),
      baselineId: baselineId == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineId),
      modelVersionsJson: modelVersionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(modelVersionsJson),
      createdAtMicros: Value(createdAtMicros),
    );
  }

  factory TripScore.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripScore(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      scoreSchemaVersion: serializer.fromJson<int>(json['scoreSchemaVersion']),
      scoringVersion: serializer.fromJson<String>(json['scoringVersion']),
      dimensionValuesJson: serializer.fromJson<String>(
        json['dimensionValuesJson'],
      ),
      overallScore: serializer.fromJson<double?>(json['overallScore']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      eligibilityState: serializer.fromJson<String>(json['eligibilityState']),
      auditContributionsJson: serializer.fromJson<String>(
        json['auditContributionsJson'],
      ),
      baselineId: serializer.fromJson<String?>(json['baselineId']),
      modelVersionsJson: serializer.fromJson<String?>(
        json['modelVersionsJson'],
      ),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'scoreSchemaVersion': serializer.toJson<int>(scoreSchemaVersion),
      'scoringVersion': serializer.toJson<String>(scoringVersion),
      'dimensionValuesJson': serializer.toJson<String>(dimensionValuesJson),
      'overallScore': serializer.toJson<double?>(overallScore),
      'confidence': serializer.toJson<double?>(confidence),
      'eligibilityState': serializer.toJson<String>(eligibilityState),
      'auditContributionsJson': serializer.toJson<String>(
        auditContributionsJson,
      ),
      'baselineId': serializer.toJson<String?>(baselineId),
      'modelVersionsJson': serializer.toJson<String?>(modelVersionsJson),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
    };
  }

  TripScore copyWith({
    String? id,
    String? tripId,
    int? scoreSchemaVersion,
    String? scoringVersion,
    String? dimensionValuesJson,
    Value<double?> overallScore = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    String? eligibilityState,
    String? auditContributionsJson,
    Value<String?> baselineId = const Value.absent(),
    Value<String?> modelVersionsJson = const Value.absent(),
    int? createdAtMicros,
  }) => TripScore(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    scoreSchemaVersion: scoreSchemaVersion ?? this.scoreSchemaVersion,
    scoringVersion: scoringVersion ?? this.scoringVersion,
    dimensionValuesJson: dimensionValuesJson ?? this.dimensionValuesJson,
    overallScore: overallScore.present ? overallScore.value : this.overallScore,
    confidence: confidence.present ? confidence.value : this.confidence,
    eligibilityState: eligibilityState ?? this.eligibilityState,
    auditContributionsJson:
        auditContributionsJson ?? this.auditContributionsJson,
    baselineId: baselineId.present ? baselineId.value : this.baselineId,
    modelVersionsJson: modelVersionsJson.present
        ? modelVersionsJson.value
        : this.modelVersionsJson,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
  );
  TripScore copyWithCompanion(TripScoresCompanion data) {
    return TripScore(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      scoreSchemaVersion: data.scoreSchemaVersion.present
          ? data.scoreSchemaVersion.value
          : this.scoreSchemaVersion,
      scoringVersion: data.scoringVersion.present
          ? data.scoringVersion.value
          : this.scoringVersion,
      dimensionValuesJson: data.dimensionValuesJson.present
          ? data.dimensionValuesJson.value
          : this.dimensionValuesJson,
      overallScore: data.overallScore.present
          ? data.overallScore.value
          : this.overallScore,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      eligibilityState: data.eligibilityState.present
          ? data.eligibilityState.value
          : this.eligibilityState,
      auditContributionsJson: data.auditContributionsJson.present
          ? data.auditContributionsJson.value
          : this.auditContributionsJson,
      baselineId: data.baselineId.present
          ? data.baselineId.value
          : this.baselineId,
      modelVersionsJson: data.modelVersionsJson.present
          ? data.modelVersionsJson.value
          : this.modelVersionsJson,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripScore(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('scoreSchemaVersion: $scoreSchemaVersion, ')
          ..write('scoringVersion: $scoringVersion, ')
          ..write('dimensionValuesJson: $dimensionValuesJson, ')
          ..write('overallScore: $overallScore, ')
          ..write('confidence: $confidence, ')
          ..write('eligibilityState: $eligibilityState, ')
          ..write('auditContributionsJson: $auditContributionsJson, ')
          ..write('baselineId: $baselineId, ')
          ..write('modelVersionsJson: $modelVersionsJson, ')
          ..write('createdAtMicros: $createdAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    scoreSchemaVersion,
    scoringVersion,
    dimensionValuesJson,
    overallScore,
    confidence,
    eligibilityState,
    auditContributionsJson,
    baselineId,
    modelVersionsJson,
    createdAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripScore &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.scoreSchemaVersion == this.scoreSchemaVersion &&
          other.scoringVersion == this.scoringVersion &&
          other.dimensionValuesJson == this.dimensionValuesJson &&
          other.overallScore == this.overallScore &&
          other.confidence == this.confidence &&
          other.eligibilityState == this.eligibilityState &&
          other.auditContributionsJson == this.auditContributionsJson &&
          other.baselineId == this.baselineId &&
          other.modelVersionsJson == this.modelVersionsJson &&
          other.createdAtMicros == this.createdAtMicros);
}

class TripScoresCompanion extends UpdateCompanion<TripScore> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<int> scoreSchemaVersion;
  final Value<String> scoringVersion;
  final Value<String> dimensionValuesJson;
  final Value<double?> overallScore;
  final Value<double?> confidence;
  final Value<String> eligibilityState;
  final Value<String> auditContributionsJson;
  final Value<String?> baselineId;
  final Value<String?> modelVersionsJson;
  final Value<int> createdAtMicros;
  final Value<int> rowid;
  const TripScoresCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.scoreSchemaVersion = const Value.absent(),
    this.scoringVersion = const Value.absent(),
    this.dimensionValuesJson = const Value.absent(),
    this.overallScore = const Value.absent(),
    this.confidence = const Value.absent(),
    this.eligibilityState = const Value.absent(),
    this.auditContributionsJson = const Value.absent(),
    this.baselineId = const Value.absent(),
    this.modelVersionsJson = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripScoresCompanion.insert({
    required String id,
    required String tripId,
    required int scoreSchemaVersion,
    required String scoringVersion,
    required String dimensionValuesJson,
    this.overallScore = const Value.absent(),
    this.confidence = const Value.absent(),
    required String eligibilityState,
    required String auditContributionsJson,
    this.baselineId = const Value.absent(),
    this.modelVersionsJson = const Value.absent(),
    required int createdAtMicros,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       scoreSchemaVersion = Value(scoreSchemaVersion),
       scoringVersion = Value(scoringVersion),
       dimensionValuesJson = Value(dimensionValuesJson),
       eligibilityState = Value(eligibilityState),
       auditContributionsJson = Value(auditContributionsJson),
       createdAtMicros = Value(createdAtMicros);
  static Insertable<TripScore> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<int>? scoreSchemaVersion,
    Expression<String>? scoringVersion,
    Expression<String>? dimensionValuesJson,
    Expression<double>? overallScore,
    Expression<double>? confidence,
    Expression<String>? eligibilityState,
    Expression<String>? auditContributionsJson,
    Expression<String>? baselineId,
    Expression<String>? modelVersionsJson,
    Expression<int>? createdAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (scoreSchemaVersion != null)
        'score_schema_version': scoreSchemaVersion,
      if (scoringVersion != null) 'scoring_version': scoringVersion,
      if (dimensionValuesJson != null)
        'dimension_values_json': dimensionValuesJson,
      if (overallScore != null) 'overall_score': overallScore,
      if (confidence != null) 'confidence': confidence,
      if (eligibilityState != null) 'eligibility_state': eligibilityState,
      if (auditContributionsJson != null)
        'audit_contributions_json': auditContributionsJson,
      if (baselineId != null) 'baseline_id': baselineId,
      if (modelVersionsJson != null) 'model_versions_json': modelVersionsJson,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripScoresCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<int>? scoreSchemaVersion,
    Value<String>? scoringVersion,
    Value<String>? dimensionValuesJson,
    Value<double?>? overallScore,
    Value<double?>? confidence,
    Value<String>? eligibilityState,
    Value<String>? auditContributionsJson,
    Value<String?>? baselineId,
    Value<String?>? modelVersionsJson,
    Value<int>? createdAtMicros,
    Value<int>? rowid,
  }) {
    return TripScoresCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      scoreSchemaVersion: scoreSchemaVersion ?? this.scoreSchemaVersion,
      scoringVersion: scoringVersion ?? this.scoringVersion,
      dimensionValuesJson: dimensionValuesJson ?? this.dimensionValuesJson,
      overallScore: overallScore ?? this.overallScore,
      confidence: confidence ?? this.confidence,
      eligibilityState: eligibilityState ?? this.eligibilityState,
      auditContributionsJson:
          auditContributionsJson ?? this.auditContributionsJson,
      baselineId: baselineId ?? this.baselineId,
      modelVersionsJson: modelVersionsJson ?? this.modelVersionsJson,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (scoreSchemaVersion.present) {
      map['score_schema_version'] = Variable<int>(scoreSchemaVersion.value);
    }
    if (scoringVersion.present) {
      map['scoring_version'] = Variable<String>(scoringVersion.value);
    }
    if (dimensionValuesJson.present) {
      map['dimension_values_json'] = Variable<String>(
        dimensionValuesJson.value,
      );
    }
    if (overallScore.present) {
      map['overall_score'] = Variable<double>(overallScore.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (eligibilityState.present) {
      map['eligibility_state'] = Variable<String>(eligibilityState.value);
    }
    if (auditContributionsJson.present) {
      map['audit_contributions_json'] = Variable<String>(
        auditContributionsJson.value,
      );
    }
    if (baselineId.present) {
      map['baseline_id'] = Variable<String>(baselineId.value);
    }
    if (modelVersionsJson.present) {
      map['model_versions_json'] = Variable<String>(modelVersionsJson.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripScoresCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('scoreSchemaVersion: $scoreSchemaVersion, ')
          ..write('scoringVersion: $scoringVersion, ')
          ..write('dimensionValuesJson: $dimensionValuesJson, ')
          ..write('overallScore: $overallScore, ')
          ..write('confidence: $confidence, ')
          ..write('eligibilityState: $eligibilityState, ')
          ..write('auditContributionsJson: $auditContributionsJson, ')
          ..write('baselineId: $baselineId, ')
          ..write('modelVersionsJson: $modelVersionsJson, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityVersionMeta = const VerificationMeta(
    'entityVersion',
  );
  @override
  late final GeneratedColumn<int> entityVersion = GeneratedColumn<int>(
    'entity_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMicrosMeta =
      const VerificationMeta('nextAttemptAtMicros');
  @override
  late final GeneratedColumn<int> nextAttemptAtMicros = GeneratedColumn<int>(
    'next_attempt_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    idempotencyKey,
    entityType,
    entityId,
    entityVersion,
    operationType,
    state,
    payloadJson,
    attemptCount,
    nextAttemptAtMicros,
    lastErrorCode,
    createdAtMicros,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
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
    if (data.containsKey('entity_version')) {
      context.handle(
        _entityVersionMeta,
        entityVersion.isAcceptableOrUnknown(
          data['entity_version']!,
          _entityVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityVersionMeta);
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
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
    }
    if (data.containsKey('next_attempt_at_micros')) {
      context.handle(
        _nextAttemptAtMicrosMeta,
        nextAttemptAtMicros.isAcceptableOrUnknown(
          data['next_attempt_at_micros']!,
          _nextAttemptAtMicrosMeta,
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
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      entityVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_version'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at_micros'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final String operationId;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final int entityVersion;
  final String operationType;
  final String state;
  final String? payloadJson;
  final int attemptCount;
  final int? nextAttemptAtMicros;
  final String? lastErrorCode;
  final int createdAtMicros;
  final int updatedAtMicros;
  const SyncQueueData({
    required this.operationId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.operationType,
    required this.state,
    this.payloadJson,
    required this.attemptCount,
    this.nextAttemptAtMicros,
    this.lastErrorCode,
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_version'] = Variable<int>(entityVersion);
    map['operation_type'] = Variable<String>(operationType);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAtMicros != null) {
      map['next_attempt_at_micros'] = Variable<int>(nextAttemptAtMicros);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      operationId: Value(operationId),
      idempotencyKey: Value(idempotencyKey),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entityVersion: Value(entityVersion),
      operationType: Value(operationType),
      state: Value(state),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      attemptCount: Value(attemptCount),
      nextAttemptAtMicros: nextAttemptAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAtMicros),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAtMicros: Value(createdAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      operationId: serializer.fromJson<String>(json['operationId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityVersion: serializer.fromJson<int>(json['entityVersion']),
      operationType: serializer.fromJson<String>(json['operationType']),
      state: serializer.fromJson<String>(json['state']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAtMicros: serializer.fromJson<int?>(
        json['nextAttemptAtMicros'],
      ),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'entityVersion': serializer.toJson<int>(entityVersion),
      'operationType': serializer.toJson<String>(operationType),
      'state': serializer.toJson<String>(state),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAtMicros': serializer.toJson<int?>(nextAttemptAtMicros),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  SyncQueueData copyWith({
    String? operationId,
    String? idempotencyKey,
    String? entityType,
    String? entityId,
    int? entityVersion,
    String? operationType,
    String? state,
    Value<String?> payloadJson = const Value.absent(),
    int? attemptCount,
    Value<int?> nextAttemptAtMicros = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    int? createdAtMicros,
    int? updatedAtMicros,
  }) => SyncQueueData(
    operationId: operationId ?? this.operationId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    entityVersion: entityVersion ?? this.entityVersion,
    operationType: operationType ?? this.operationType,
    state: state ?? this.state,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAtMicros: nextAttemptAtMicros.present
        ? nextAttemptAtMicros.value
        : this.nextAttemptAtMicros,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityVersion: data.entityVersion.present
          ? data.entityVersion.value
          : this.entityVersion,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      state: data.state.present ? data.state.value : this.state,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAtMicros: data.nextAttemptAtMicros.present
          ? data.nextAttemptAtMicros.value
          : this.nextAttemptAtMicros,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('operationId: $operationId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entityVersion: $entityVersion, ')
          ..write('operationType: $operationType, ')
          ..write('state: $state, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAtMicros: $nextAttemptAtMicros, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    idempotencyKey,
    entityType,
    entityId,
    entityVersion,
    operationType,
    state,
    payloadJson,
    attemptCount,
    nextAttemptAtMicros,
    lastErrorCode,
    createdAtMicros,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.operationId == this.operationId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.entityVersion == this.entityVersion &&
          other.operationType == this.operationType &&
          other.state == this.state &&
          other.payloadJson == this.payloadJson &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAtMicros == this.nextAttemptAtMicros &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAtMicros == this.createdAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<String> operationId;
  final Value<String> idempotencyKey;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> entityVersion;
  final Value<String> operationType;
  final Value<String> state;
  final Value<String?> payloadJson;
  final Value<int> attemptCount;
  final Value<int?> nextAttemptAtMicros;
  final Value<String?> lastErrorCode;
  final Value<int> createdAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.operationId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityVersion = const Value.absent(),
    this.operationType = const Value.absent(),
    this.state = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAtMicros = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String operationId,
    required String idempotencyKey,
    required String entityType,
    required String entityId,
    required int entityVersion,
    required String operationType,
    required String state,
    this.payloadJson = const Value.absent(),
    required int attemptCount,
    this.nextAttemptAtMicros = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    required int createdAtMicros,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       idempotencyKey = Value(idempotencyKey),
       entityType = Value(entityType),
       entityId = Value(entityId),
       entityVersion = Value(entityVersion),
       operationType = Value(operationType),
       state = Value(state),
       attemptCount = Value(attemptCount),
       createdAtMicros = Value(createdAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<SyncQueueData> custom({
    Expression<String>? operationId,
    Expression<String>? idempotencyKey,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? entityVersion,
    Expression<String>? operationType,
    Expression<String>? state,
    Expression<String>? payloadJson,
    Expression<int>? attemptCount,
    Expression<int>? nextAttemptAtMicros,
    Expression<String>? lastErrorCode,
    Expression<int>? createdAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (entityVersion != null) 'entity_version': entityVersion,
      if (operationType != null) 'operation_type': operationType,
      if (state != null) 'state': state,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAtMicros != null)
        'next_attempt_at_micros': nextAttemptAtMicros,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? operationId,
    Value<String>? idempotencyKey,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? entityVersion,
    Value<String>? operationType,
    Value<String>? state,
    Value<String?>? payloadJson,
    Value<int>? attemptCount,
    Value<int?>? nextAttemptAtMicros,
    Value<String?>? lastErrorCode,
    Value<int>? createdAtMicros,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      operationId: operationId ?? this.operationId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityVersion: entityVersion ?? this.entityVersion,
      operationType: operationType ?? this.operationType,
      state: state ?? this.state,
      payloadJson: payloadJson ?? this.payloadJson,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAtMicros: nextAttemptAtMicros ?? this.nextAttemptAtMicros,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityVersion.present) {
      map['entity_version'] = Variable<int>(entityVersion.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAtMicros.present) {
      map['next_attempt_at_micros'] = Variable<int>(nextAttemptAtMicros.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('operationId: $operationId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entityVersion: $entityVersion, ')
          ..write('operationType: $operationType, ')
          ..write('state: $state, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAtMicros: $nextAttemptAtMicros, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TripChunksTable tripChunks = $TripChunksTable(this);
  late final $TripEventsTable tripEvents = $TripEventsTable(this);
  late final $DriverBaselinesTable driverBaselines = $DriverBaselinesTable(
    this,
  );
  late final $TripScoresTable tripScores = $TripScoresTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final Index vehiclesOwnerNamespace = Index(
    'vehicles_owner_namespace',
    'CREATE INDEX vehicles_owner_namespace ON vehicles (owner_namespace)',
  );
  late final Index tripsVehicleStart = Index(
    'trips_vehicle_start',
    'CREATE INDEX trips_vehicle_start ON trips (vehicle_id, start_wall_time_micros)',
  );
  late final Index tripsStartTime = Index(
    'trips_start_time',
    'CREATE INDEX trips_start_time ON trips (start_wall_time_micros)',
  );
  late final Index tripEventsTripStart = Index(
    'trip_events_trip_start',
    'CREATE INDEX trip_events_trip_start ON trip_events (trip_id, start_elapsed_nanos)',
  );
  late final Index tripScoresTripVersion = Index(
    'trip_scores_trip_version',
    'CREATE UNIQUE INDEX trip_scores_trip_version ON trip_scores (trip_id, score_schema_version, scoring_version)',
  );
  late final Index driverBaselinesOwnerVehicle = Index(
    'driver_baselines_owner_vehicle',
    'CREATE INDEX driver_baselines_owner_vehicle ON driver_baselines (owner_namespace, vehicle_id)',
  );
  late final Index syncQueueIdempotencyKey = Index(
    'sync_queue_idempotency_key',
    'CREATE UNIQUE INDEX sync_queue_idempotency_key ON sync_queue (idempotency_key)',
  );
  late final Index syncQueueStateNextAttempt = Index(
    'sync_queue_state_next_attempt',
    'CREATE INDEX sync_queue_state_next_attempt ON sync_queue (state, next_attempt_at_micros)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    vehicles,
    trips,
    tripChunks,
    tripEvents,
    driverBaselines,
    tripScores,
    syncQueue,
    vehiclesOwnerNamespace,
    tripsVehicleStart,
    tripsStartTime,
    tripEventsTripStart,
    tripScoresTripVersion,
    driverBaselinesOwnerVehicle,
    syncQueueIdempotencyKey,
    syncQueueStateNextAttempt,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_chunks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('driver_baselines', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_scores', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'driver_baselines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_scores', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$VehiclesTableCreateCompanionBuilder =
    VehiclesCompanion Function({
      required String id,
      required String ownerNamespace,
      required String displayName,
      required String vehicleType,
      Value<String?> manufacturer,
      Value<String?> model,
      Value<int?> modelYear,
      Value<String?> calibrationMetadataJson,
      Value<String?> baselineMetadataJson,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$VehiclesTableUpdateCompanionBuilder =
    VehiclesCompanion Function({
      Value<String> id,
      Value<String> ownerNamespace,
      Value<String> displayName,
      Value<String> vehicleType,
      Value<String?> manufacturer,
      Value<String?> model,
      Value<int?> modelYear,
      Value<String?> calibrationMetadataJson,
      Value<String?> baselineMetadataJson,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

final class $$VehiclesTableReferences
    extends BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle> {
  $$VehiclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripsTable, List<Trip>> _tripsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.trips,
    aliasName: 'vehicles__id__trips__vehicle_id',
  );

  $$TripsTableProcessedTableManager get tripsRefs {
    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DriverBaselinesTable, List<DriverBaseline>>
  _driverBaselinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.driverBaselines,
    aliasName: 'vehicles__id__driver_baselines__vehicle_id',
  );

  $$DriverBaselinesTableProcessedTableManager get driverBaselinesRefs {
    final manager = $$DriverBaselinesTableTableManager(
      $_db,
      $_db.driverBaselines,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _driverBaselinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerNamespace => $composableBuilder(
    column: $table.ownerNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleType => $composableBuilder(
    column: $table.vehicleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modelYear => $composableBuilder(
    column: $table.modelYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calibrationMetadataJson => $composableBuilder(
    column: $table.calibrationMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baselineMetadataJson => $composableBuilder(
    column: $table.baselineMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripsRefs(
    Expression<bool> Function($$TripsTableFilterComposer f) f,
  ) {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> driverBaselinesRefs(
    Expression<bool> Function($$DriverBaselinesTableFilterComposer f) f,
  ) {
    final $$DriverBaselinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.driverBaselines,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverBaselinesTableFilterComposer(
            $db: $db,
            $table: $db.driverBaselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerNamespace => $composableBuilder(
    column: $table.ownerNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleType => $composableBuilder(
    column: $table.vehicleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modelYear => $composableBuilder(
    column: $table.modelYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calibrationMetadataJson => $composableBuilder(
    column: $table.calibrationMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baselineMetadataJson => $composableBuilder(
    column: $table.baselineMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerNamespace => $composableBuilder(
    column: $table.ownerNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehicleType => $composableBuilder(
    column: $table.vehicleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get modelYear =>
      $composableBuilder(column: $table.modelYear, builder: (column) => column);

  GeneratedColumn<String> get calibrationMetadataJson => $composableBuilder(
    column: $table.calibrationMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baselineMetadataJson => $composableBuilder(
    column: $table.baselineMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  Expression<T> tripsRefs<T extends Object>(
    Expression<T> Function($$TripsTableAnnotationComposer a) f,
  ) {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> driverBaselinesRefs<T extends Object>(
    Expression<T> Function($$DriverBaselinesTableAnnotationComposer a) f,
  ) {
    final $$DriverBaselinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.driverBaselines,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverBaselinesTableAnnotationComposer(
            $db: $db,
            $table: $db.driverBaselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          Vehicle,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (Vehicle, $$VehiclesTableReferences),
          Vehicle,
          PrefetchHooks Function({bool tripsRefs, bool driverBaselinesRefs})
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerNamespace = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> vehicleType = const Value.absent(),
                Value<String?> manufacturer = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> modelYear = const Value.absent(),
                Value<String?> calibrationMetadataJson = const Value.absent(),
                Value<String?> baselineMetadataJson = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                ownerNamespace: ownerNamespace,
                displayName: displayName,
                vehicleType: vehicleType,
                manufacturer: manufacturer,
                model: model,
                modelYear: modelYear,
                calibrationMetadataJson: calibrationMetadataJson,
                baselineMetadataJson: baselineMetadataJson,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerNamespace,
                required String displayName,
                required String vehicleType,
                Value<String?> manufacturer = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> modelYear = const Value.absent(),
                Value<String?> calibrationMetadataJson = const Value.absent(),
                Value<String?> baselineMetadataJson = const Value.absent(),
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                ownerNamespace: ownerNamespace,
                displayName: displayName,
                vehicleType: vehicleType,
                manufacturer: manufacturer,
                model: model,
                modelYear: modelYear,
                calibrationMetadataJson: calibrationMetadataJson,
                baselineMetadataJson: baselineMetadataJson,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VehiclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({tripsRefs = false, driverBaselinesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tripsRefs) db.trips,
                    if (driverBaselinesRefs) db.driverBaselines,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripsRefs)
                        await $_getPrefetchedData<
                          Vehicle,
                          $VehiclesTable,
                          Trip
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._tripsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).tripsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (driverBaselinesRefs)
                        await $_getPrefetchedData<
                          Vehicle,
                          $VehiclesTable,
                          DriverBaseline
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._driverBaselinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).driverBaselinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      Vehicle,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (Vehicle, $$VehiclesTableReferences),
      Vehicle,
      PrefetchHooks Function({bool tripsRefs, bool driverBaselinesRefs})
    >;
typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      required String id,
      required String vehicleId,
      required int startWallTimeMicros,
      Value<int?> endWallTimeMicros,
      required int startElapsedNanos,
      Value<int?> endElapsedNanos,
      Value<int?> durationMillis,
      Value<double?> distanceMeters,
      required String completionState,
      required String recoveryState,
      required int telemetrySchemaVersion,
      Value<String?> scoringVersion,
      Value<String?> eventEngineVersion,
      Value<String?> mlModelRefsJson,
      required String integrityStatus,
      Value<double?> telemetryConfidence,
      Value<String?> telemetryQualitySummaryJson,
      required String cloudSyncState,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<int> startWallTimeMicros,
      Value<int?> endWallTimeMicros,
      Value<int> startElapsedNanos,
      Value<int?> endElapsedNanos,
      Value<int?> durationMillis,
      Value<double?> distanceMeters,
      Value<String> completionState,
      Value<String> recoveryState,
      Value<int> telemetrySchemaVersion,
      Value<String?> scoringVersion,
      Value<String?> eventEngineVersion,
      Value<String?> mlModelRefsJson,
      Value<String> integrityStatus,
      Value<double?> telemetryConfidence,
      Value<String?> telemetryQualitySummaryJson,
      Value<String> cloudSyncState,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('trips__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TripChunksTable, List<TripChunk>>
  _tripChunksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripChunks,
    aliasName: 'trips__id__trip_chunks__trip_id',
  );

  $$TripChunksTableProcessedTableManager get tripChunksRefs {
    final manager = $$TripChunksTableTableManager(
      $_db,
      $_db.tripChunks,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripChunksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TripEventsTable, List<TripEvent>>
  _tripEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripEvents,
    aliasName: 'trips__id__trip_events__trip_id',
  );

  $$TripEventsTableProcessedTableManager get tripEventsRefs {
    final manager = $$TripEventsTableTableManager(
      $_db,
      $_db.tripEvents,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TripScoresTable, List<TripScore>>
  _tripScoresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripScores,
    aliasName: 'trips__id__trip_scores__trip_id',
  );

  $$TripScoresTableProcessedTableManager get tripScoresRefs {
    final manager = $$TripScoresTableTableManager(
      $_db,
      $_db.tripScores,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripScoresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startWallTimeMicros => $composableBuilder(
    column: $table.startWallTimeMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endWallTimeMicros => $composableBuilder(
    column: $table.endWallTimeMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completionState => $composableBuilder(
    column: $table.completionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recoveryState => $composableBuilder(
    column: $table.recoveryState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get telemetrySchemaVersion => $composableBuilder(
    column: $table.telemetrySchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventEngineVersion => $composableBuilder(
    column: $table.eventEngineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mlModelRefsJson => $composableBuilder(
    column: $table.mlModelRefsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get integrityStatus => $composableBuilder(
    column: $table.integrityStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get telemetryConfidence => $composableBuilder(
    column: $table.telemetryConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telemetryQualitySummaryJson => $composableBuilder(
    column: $table.telemetryQualitySummaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudSyncState => $composableBuilder(
    column: $table.cloudSyncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tripChunksRefs(
    Expression<bool> Function($$TripChunksTableFilterComposer f) f,
  ) {
    final $$TripChunksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripChunks,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripChunksTableFilterComposer(
            $db: $db,
            $table: $db.tripChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tripEventsRefs(
    Expression<bool> Function($$TripEventsTableFilterComposer f) f,
  ) {
    final $$TripEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripEvents,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripEventsTableFilterComposer(
            $db: $db,
            $table: $db.tripEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tripScoresRefs(
    Expression<bool> Function($$TripScoresTableFilterComposer f) f,
  ) {
    final $$TripScoresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripScores,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripScoresTableFilterComposer(
            $db: $db,
            $table: $db.tripScores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startWallTimeMicros => $composableBuilder(
    column: $table.startWallTimeMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endWallTimeMicros => $composableBuilder(
    column: $table.endWallTimeMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completionState => $composableBuilder(
    column: $table.completionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recoveryState => $composableBuilder(
    column: $table.recoveryState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get telemetrySchemaVersion => $composableBuilder(
    column: $table.telemetrySchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventEngineVersion => $composableBuilder(
    column: $table.eventEngineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mlModelRefsJson => $composableBuilder(
    column: $table.mlModelRefsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get integrityStatus => $composableBuilder(
    column: $table.integrityStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get telemetryConfidence => $composableBuilder(
    column: $table.telemetryConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telemetryQualitySummaryJson => $composableBuilder(
    column: $table.telemetryQualitySummaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudSyncState => $composableBuilder(
    column: $table.cloudSyncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startWallTimeMicros => $composableBuilder(
    column: $table.startWallTimeMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endWallTimeMicros => $composableBuilder(
    column: $table.endWallTimeMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completionState => $composableBuilder(
    column: $table.completionState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recoveryState => $composableBuilder(
    column: $table.recoveryState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get telemetrySchemaVersion => $composableBuilder(
    column: $table.telemetrySchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventEngineVersion => $composableBuilder(
    column: $table.eventEngineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mlModelRefsJson => $composableBuilder(
    column: $table.mlModelRefsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get integrityStatus => $composableBuilder(
    column: $table.integrityStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get telemetryConfidence => $composableBuilder(
    column: $table.telemetryConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get telemetryQualitySummaryJson => $composableBuilder(
    column: $table.telemetryQualitySummaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudSyncState => $composableBuilder(
    column: $table.cloudSyncState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tripChunksRefs<T extends Object>(
    Expression<T> Function($$TripChunksTableAnnotationComposer a) f,
  ) {
    final $$TripChunksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripChunks,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripChunksTableAnnotationComposer(
            $db: $db,
            $table: $db.tripChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tripEventsRefs<T extends Object>(
    Expression<T> Function($$TripEventsTableAnnotationComposer a) f,
  ) {
    final $$TripEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripEvents,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tripScoresRefs<T extends Object>(
    Expression<T> Function($$TripScoresTableAnnotationComposer a) f,
  ) {
    final $$TripScoresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripScores,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripScoresTableAnnotationComposer(
            $db: $db,
            $table: $db.tripScores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({
            bool vehicleId,
            bool tripChunksRefs,
            bool tripEventsRefs,
            bool tripScoresRefs,
          })
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<int> startWallTimeMicros = const Value.absent(),
                Value<int?> endWallTimeMicros = const Value.absent(),
                Value<int> startElapsedNanos = const Value.absent(),
                Value<int?> endElapsedNanos = const Value.absent(),
                Value<int?> durationMillis = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<String> completionState = const Value.absent(),
                Value<String> recoveryState = const Value.absent(),
                Value<int> telemetrySchemaVersion = const Value.absent(),
                Value<String?> scoringVersion = const Value.absent(),
                Value<String?> eventEngineVersion = const Value.absent(),
                Value<String?> mlModelRefsJson = const Value.absent(),
                Value<String> integrityStatus = const Value.absent(),
                Value<double?> telemetryConfidence = const Value.absent(),
                Value<String?> telemetryQualitySummaryJson =
                    const Value.absent(),
                Value<String> cloudSyncState = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                vehicleId: vehicleId,
                startWallTimeMicros: startWallTimeMicros,
                endWallTimeMicros: endWallTimeMicros,
                startElapsedNanos: startElapsedNanos,
                endElapsedNanos: endElapsedNanos,
                durationMillis: durationMillis,
                distanceMeters: distanceMeters,
                completionState: completionState,
                recoveryState: recoveryState,
                telemetrySchemaVersion: telemetrySchemaVersion,
                scoringVersion: scoringVersion,
                eventEngineVersion: eventEngineVersion,
                mlModelRefsJson: mlModelRefsJson,
                integrityStatus: integrityStatus,
                telemetryConfidence: telemetryConfidence,
                telemetryQualitySummaryJson: telemetryQualitySummaryJson,
                cloudSyncState: cloudSyncState,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required int startWallTimeMicros,
                Value<int?> endWallTimeMicros = const Value.absent(),
                required int startElapsedNanos,
                Value<int?> endElapsedNanos = const Value.absent(),
                Value<int?> durationMillis = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                required String completionState,
                required String recoveryState,
                required int telemetrySchemaVersion,
                Value<String?> scoringVersion = const Value.absent(),
                Value<String?> eventEngineVersion = const Value.absent(),
                Value<String?> mlModelRefsJson = const Value.absent(),
                required String integrityStatus,
                Value<double?> telemetryConfidence = const Value.absent(),
                Value<String?> telemetryQualitySummaryJson =
                    const Value.absent(),
                required String cloudSyncState,
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                startWallTimeMicros: startWallTimeMicros,
                endWallTimeMicros: endWallTimeMicros,
                startElapsedNanos: startElapsedNanos,
                endElapsedNanos: endElapsedNanos,
                durationMillis: durationMillis,
                distanceMeters: distanceMeters,
                completionState: completionState,
                recoveryState: recoveryState,
                telemetrySchemaVersion: telemetrySchemaVersion,
                scoringVersion: scoringVersion,
                eventEngineVersion: eventEngineVersion,
                mlModelRefsJson: mlModelRefsJson,
                integrityStatus: integrityStatus,
                telemetryConfidence: telemetryConfidence,
                telemetryQualitySummaryJson: telemetryQualitySummaryJson,
                cloudSyncState: cloudSyncState,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                vehicleId = false,
                tripChunksRefs = false,
                tripEventsRefs = false,
                tripScoresRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tripChunksRefs) db.tripChunks,
                    if (tripEventsRefs) db.tripEvents,
                    if (tripScoresRefs) db.tripScores,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (vehicleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.vehicleId,
                                    referencedTable: $$TripsTableReferences
                                        ._vehicleIdTable(db),
                                    referencedColumn: $$TripsTableReferences
                                        ._vehicleIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripChunksRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, TripChunk>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripChunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tripEventsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, TripEvent>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tripScoresRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, TripScore>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripScoresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripScoresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({
        bool vehicleId,
        bool tripChunksRefs,
        bool tripEventsRefs,
        bool tripScoresRefs,
      })
    >;
typedef $$TripChunksTableCreateCompanionBuilder =
    TripChunksCompanion Function({
      required String tripId,
      required int sequence,
      required String storageReference,
      required int encodingVersion,
      required int startElapsedNanos,
      required int endElapsedNanos,
      required String channelSampleCountsJson,
      required String compression,
      required String atomicWriteStrategy,
      required String checksumAlgorithm,
      required String checksum,
      required int byteLength,
      required String writeState,
      required int createdAtMicros,
      Value<int> rowid,
    });
typedef $$TripChunksTableUpdateCompanionBuilder =
    TripChunksCompanion Function({
      Value<String> tripId,
      Value<int> sequence,
      Value<String> storageReference,
      Value<int> encodingVersion,
      Value<int> startElapsedNanos,
      Value<int> endElapsedNanos,
      Value<String> channelSampleCountsJson,
      Value<String> compression,
      Value<String> atomicWriteStrategy,
      Value<String> checksumAlgorithm,
      Value<String> checksum,
      Value<int> byteLength,
      Value<String> writeState,
      Value<int> createdAtMicros,
      Value<int> rowid,
    });

final class $$TripChunksTableReferences
    extends BaseReferences<_$AppDatabase, $TripChunksTable, TripChunk> {
  $$TripChunksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_chunks__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripChunksTableFilterComposer
    extends Composer<_$AppDatabase, $TripChunksTable> {
  $$TripChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageReference => $composableBuilder(
    column: $table.storageReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encodingVersion => $composableBuilder(
    column: $table.encodingVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelSampleCountsJson => $composableBuilder(
    column: $table.channelSampleCountsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compression => $composableBuilder(
    column: $table.compression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get atomicWriteStrategy => $composableBuilder(
    column: $table.atomicWriteStrategy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksumAlgorithm => $composableBuilder(
    column: $table.checksumAlgorithm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get writeState => $composableBuilder(
    column: $table.writeState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $TripChunksTable> {
  $$TripChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageReference => $composableBuilder(
    column: $table.storageReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encodingVersion => $composableBuilder(
    column: $table.encodingVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelSampleCountsJson => $composableBuilder(
    column: $table.channelSampleCountsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compression => $composableBuilder(
    column: $table.compression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get atomicWriteStrategy => $composableBuilder(
    column: $table.atomicWriteStrategy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksumAlgorithm => $composableBuilder(
    column: $table.checksumAlgorithm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get writeState => $composableBuilder(
    column: $table.writeState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripChunksTable> {
  $$TripChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get storageReference => $composableBuilder(
    column: $table.storageReference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encodingVersion => $composableBuilder(
    column: $table.encodingVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channelSampleCountsJson => $composableBuilder(
    column: $table.channelSampleCountsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compression => $composableBuilder(
    column: $table.compression,
    builder: (column) => column,
  );

  GeneratedColumn<String> get atomicWriteStrategy => $composableBuilder(
    column: $table.atomicWriteStrategy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksumAlgorithm => $composableBuilder(
    column: $table.checksumAlgorithm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get writeState => $composableBuilder(
    column: $table.writeState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripChunksTable,
          TripChunk,
          $$TripChunksTableFilterComposer,
          $$TripChunksTableOrderingComposer,
          $$TripChunksTableAnnotationComposer,
          $$TripChunksTableCreateCompanionBuilder,
          $$TripChunksTableUpdateCompanionBuilder,
          (TripChunk, $$TripChunksTableReferences),
          TripChunk,
          PrefetchHooks Function({bool tripId})
        > {
  $$TripChunksTableTableManager(_$AppDatabase db, $TripChunksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tripId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> storageReference = const Value.absent(),
                Value<int> encodingVersion = const Value.absent(),
                Value<int> startElapsedNanos = const Value.absent(),
                Value<int> endElapsedNanos = const Value.absent(),
                Value<String> channelSampleCountsJson = const Value.absent(),
                Value<String> compression = const Value.absent(),
                Value<String> atomicWriteStrategy = const Value.absent(),
                Value<String> checksumAlgorithm = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> byteLength = const Value.absent(),
                Value<String> writeState = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripChunksCompanion(
                tripId: tripId,
                sequence: sequence,
                storageReference: storageReference,
                encodingVersion: encodingVersion,
                startElapsedNanos: startElapsedNanos,
                endElapsedNanos: endElapsedNanos,
                channelSampleCountsJson: channelSampleCountsJson,
                compression: compression,
                atomicWriteStrategy: atomicWriteStrategy,
                checksumAlgorithm: checksumAlgorithm,
                checksum: checksum,
                byteLength: byteLength,
                writeState: writeState,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tripId,
                required int sequence,
                required String storageReference,
                required int encodingVersion,
                required int startElapsedNanos,
                required int endElapsedNanos,
                required String channelSampleCountsJson,
                required String compression,
                required String atomicWriteStrategy,
                required String checksumAlgorithm,
                required String checksum,
                required int byteLength,
                required String writeState,
                required int createdAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => TripChunksCompanion.insert(
                tripId: tripId,
                sequence: sequence,
                storageReference: storageReference,
                encodingVersion: encodingVersion,
                startElapsedNanos: startElapsedNanos,
                endElapsedNanos: endElapsedNanos,
                channelSampleCountsJson: channelSampleCountsJson,
                compression: compression,
                atomicWriteStrategy: atomicWriteStrategy,
                checksumAlgorithm: checksumAlgorithm,
                checksum: checksum,
                byteLength: byteLength,
                writeState: writeState,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripChunksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripChunksTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripChunksTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TripChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripChunksTable,
      TripChunk,
      $$TripChunksTableFilterComposer,
      $$TripChunksTableOrderingComposer,
      $$TripChunksTableAnnotationComposer,
      $$TripChunksTableCreateCompanionBuilder,
      $$TripChunksTableUpdateCompanionBuilder,
      (TripChunk, $$TripChunksTableReferences),
      TripChunk,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$TripEventsTableCreateCompanionBuilder =
    TripEventsCompanion Function({
      required String id,
      required String tripId,
      required String eventType,
      required int startElapsedNanos,
      required int peakElapsedNanos,
      required int endElapsedNanos,
      required double severity,
      required String severityCalibrationVersion,
      required double confidence,
      required String qualityFlagsJson,
      required String primaryMeasurementsJson,
      required String ruleEvidenceJson,
      Value<String?> mlEvidenceJson,
      required String contextTagsJson,
      required String algorithmVersion,
      required int createdAtMicros,
      Value<int> rowid,
    });
typedef $$TripEventsTableUpdateCompanionBuilder =
    TripEventsCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> eventType,
      Value<int> startElapsedNanos,
      Value<int> peakElapsedNanos,
      Value<int> endElapsedNanos,
      Value<double> severity,
      Value<String> severityCalibrationVersion,
      Value<double> confidence,
      Value<String> qualityFlagsJson,
      Value<String> primaryMeasurementsJson,
      Value<String> ruleEvidenceJson,
      Value<String?> mlEvidenceJson,
      Value<String> contextTagsJson,
      Value<String> algorithmVersion,
      Value<int> createdAtMicros,
      Value<int> rowid,
    });

final class $$TripEventsTableReferences
    extends BaseReferences<_$AppDatabase, $TripEventsTable, TripEvent> {
  $$TripEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_events__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripEventsTableFilterComposer
    extends Composer<_$AppDatabase, $TripEventsTable> {
  $$TripEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peakElapsedNanos => $composableBuilder(
    column: $table.peakElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severityCalibrationVersion => $composableBuilder(
    column: $table.severityCalibrationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityFlagsJson => $composableBuilder(
    column: $table.qualityFlagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryMeasurementsJson => $composableBuilder(
    column: $table.primaryMeasurementsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleEvidenceJson => $composableBuilder(
    column: $table.ruleEvidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mlEvidenceJson => $composableBuilder(
    column: $table.mlEvidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextTagsJson => $composableBuilder(
    column: $table.contextTagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripEventsTable> {
  $$TripEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peakElapsedNanos => $composableBuilder(
    column: $table.peakElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severityCalibrationVersion => $composableBuilder(
    column: $table.severityCalibrationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityFlagsJson => $composableBuilder(
    column: $table.qualityFlagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryMeasurementsJson => $composableBuilder(
    column: $table.primaryMeasurementsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleEvidenceJson => $composableBuilder(
    column: $table.ruleEvidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mlEvidenceJson => $composableBuilder(
    column: $table.mlEvidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextTagsJson => $composableBuilder(
    column: $table.contextTagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripEventsTable> {
  $$TripEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get startElapsedNanos => $composableBuilder(
    column: $table.startElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get peakElapsedNanos => $composableBuilder(
    column: $table.peakElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endElapsedNanos => $composableBuilder(
    column: $table.endElapsedNanos,
    builder: (column) => column,
  );

  GeneratedColumn<double> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get severityCalibrationVersion => $composableBuilder(
    column: $table.severityCalibrationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qualityFlagsJson => $composableBuilder(
    column: $table.qualityFlagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryMeasurementsJson => $composableBuilder(
    column: $table.primaryMeasurementsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleEvidenceJson => $composableBuilder(
    column: $table.ruleEvidenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mlEvidenceJson => $composableBuilder(
    column: $table.mlEvidenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contextTagsJson => $composableBuilder(
    column: $table.contextTagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripEventsTable,
          TripEvent,
          $$TripEventsTableFilterComposer,
          $$TripEventsTableOrderingComposer,
          $$TripEventsTableAnnotationComposer,
          $$TripEventsTableCreateCompanionBuilder,
          $$TripEventsTableUpdateCompanionBuilder,
          (TripEvent, $$TripEventsTableReferences),
          TripEvent,
          PrefetchHooks Function({bool tripId})
        > {
  $$TripEventsTableTableManager(_$AppDatabase db, $TripEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<int> startElapsedNanos = const Value.absent(),
                Value<int> peakElapsedNanos = const Value.absent(),
                Value<int> endElapsedNanos = const Value.absent(),
                Value<double> severity = const Value.absent(),
                Value<String> severityCalibrationVersion = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> qualityFlagsJson = const Value.absent(),
                Value<String> primaryMeasurementsJson = const Value.absent(),
                Value<String> ruleEvidenceJson = const Value.absent(),
                Value<String?> mlEvidenceJson = const Value.absent(),
                Value<String> contextTagsJson = const Value.absent(),
                Value<String> algorithmVersion = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripEventsCompanion(
                id: id,
                tripId: tripId,
                eventType: eventType,
                startElapsedNanos: startElapsedNanos,
                peakElapsedNanos: peakElapsedNanos,
                endElapsedNanos: endElapsedNanos,
                severity: severity,
                severityCalibrationVersion: severityCalibrationVersion,
                confidence: confidence,
                qualityFlagsJson: qualityFlagsJson,
                primaryMeasurementsJson: primaryMeasurementsJson,
                ruleEvidenceJson: ruleEvidenceJson,
                mlEvidenceJson: mlEvidenceJson,
                contextTagsJson: contextTagsJson,
                algorithmVersion: algorithmVersion,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required String eventType,
                required int startElapsedNanos,
                required int peakElapsedNanos,
                required int endElapsedNanos,
                required double severity,
                required String severityCalibrationVersion,
                required double confidence,
                required String qualityFlagsJson,
                required String primaryMeasurementsJson,
                required String ruleEvidenceJson,
                Value<String?> mlEvidenceJson = const Value.absent(),
                required String contextTagsJson,
                required String algorithmVersion,
                required int createdAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => TripEventsCompanion.insert(
                id: id,
                tripId: tripId,
                eventType: eventType,
                startElapsedNanos: startElapsedNanos,
                peakElapsedNanos: peakElapsedNanos,
                endElapsedNanos: endElapsedNanos,
                severity: severity,
                severityCalibrationVersion: severityCalibrationVersion,
                confidence: confidence,
                qualityFlagsJson: qualityFlagsJson,
                primaryMeasurementsJson: primaryMeasurementsJson,
                ruleEvidenceJson: ruleEvidenceJson,
                mlEvidenceJson: mlEvidenceJson,
                contextTagsJson: contextTagsJson,
                algorithmVersion: algorithmVersion,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripEventsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripEventsTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TripEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripEventsTable,
      TripEvent,
      $$TripEventsTableFilterComposer,
      $$TripEventsTableOrderingComposer,
      $$TripEventsTableAnnotationComposer,
      $$TripEventsTableCreateCompanionBuilder,
      $$TripEventsTableUpdateCompanionBuilder,
      (TripEvent, $$TripEventsTableReferences),
      TripEvent,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$DriverBaselinesTableCreateCompanionBuilder =
    DriverBaselinesCompanion Function({
      required String id,
      required String ownerNamespace,
      Value<String?> vehicleId,
      required String lifecycleState,
      required String dimensionStatisticsJson,
      required int baselineSchemaVersion,
      required String scoringVersion,
      required int validTripCount,
      Value<int?> windowStartWallTimeMicros,
      Value<int?> windowEndWallTimeMicros,
      Value<double?> confidence,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$DriverBaselinesTableUpdateCompanionBuilder =
    DriverBaselinesCompanion Function({
      Value<String> id,
      Value<String> ownerNamespace,
      Value<String?> vehicleId,
      Value<String> lifecycleState,
      Value<String> dimensionStatisticsJson,
      Value<int> baselineSchemaVersion,
      Value<String> scoringVersion,
      Value<int> validTripCount,
      Value<int?> windowStartWallTimeMicros,
      Value<int?> windowEndWallTimeMicros,
      Value<double?> confidence,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

final class $$DriverBaselinesTableReferences
    extends
        BaseReferences<_$AppDatabase, $DriverBaselinesTable, DriverBaseline> {
  $$DriverBaselinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('driver_baselines__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager? get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id');
    if ($_column == null) return null;
    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TripScoresTable, List<TripScore>>
  _tripScoresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripScores,
    aliasName: 'driver_baselines__id__trip_scores__baseline_id',
  );

  $$TripScoresTableProcessedTableManager get tripScoresRefs {
    final manager = $$TripScoresTableTableManager(
      $_db,
      $_db.tripScores,
    ).filter((f) => f.baselineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripScoresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DriverBaselinesTableFilterComposer
    extends Composer<_$AppDatabase, $DriverBaselinesTable> {
  $$DriverBaselinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerNamespace => $composableBuilder(
    column: $table.ownerNamespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycleState => $composableBuilder(
    column: $table.lifecycleState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dimensionStatisticsJson => $composableBuilder(
    column: $table.dimensionStatisticsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baselineSchemaVersion => $composableBuilder(
    column: $table.baselineSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get validTripCount => $composableBuilder(
    column: $table.validTripCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowStartWallTimeMicros => $composableBuilder(
    column: $table.windowStartWallTimeMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowEndWallTimeMicros => $composableBuilder(
    column: $table.windowEndWallTimeMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tripScoresRefs(
    Expression<bool> Function($$TripScoresTableFilterComposer f) f,
  ) {
    final $$TripScoresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripScores,
      getReferencedColumn: (t) => t.baselineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripScoresTableFilterComposer(
            $db: $db,
            $table: $db.tripScores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DriverBaselinesTableOrderingComposer
    extends Composer<_$AppDatabase, $DriverBaselinesTable> {
  $$DriverBaselinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerNamespace => $composableBuilder(
    column: $table.ownerNamespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycleState => $composableBuilder(
    column: $table.lifecycleState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dimensionStatisticsJson => $composableBuilder(
    column: $table.dimensionStatisticsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baselineSchemaVersion => $composableBuilder(
    column: $table.baselineSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get validTripCount => $composableBuilder(
    column: $table.validTripCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowStartWallTimeMicros => $composableBuilder(
    column: $table.windowStartWallTimeMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowEndWallTimeMicros => $composableBuilder(
    column: $table.windowEndWallTimeMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DriverBaselinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriverBaselinesTable> {
  $$DriverBaselinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerNamespace => $composableBuilder(
    column: $table.ownerNamespace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycleState => $composableBuilder(
    column: $table.lifecycleState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dimensionStatisticsJson => $composableBuilder(
    column: $table.dimensionStatisticsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baselineSchemaVersion => $composableBuilder(
    column: $table.baselineSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get validTripCount => $composableBuilder(
    column: $table.validTripCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windowStartWallTimeMicros => $composableBuilder(
    column: $table.windowStartWallTimeMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windowEndWallTimeMicros => $composableBuilder(
    column: $table.windowEndWallTimeMicros,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tripScoresRefs<T extends Object>(
    Expression<T> Function($$TripScoresTableAnnotationComposer a) f,
  ) {
    final $$TripScoresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripScores,
      getReferencedColumn: (t) => t.baselineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripScoresTableAnnotationComposer(
            $db: $db,
            $table: $db.tripScores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DriverBaselinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriverBaselinesTable,
          DriverBaseline,
          $$DriverBaselinesTableFilterComposer,
          $$DriverBaselinesTableOrderingComposer,
          $$DriverBaselinesTableAnnotationComposer,
          $$DriverBaselinesTableCreateCompanionBuilder,
          $$DriverBaselinesTableUpdateCompanionBuilder,
          (DriverBaseline, $$DriverBaselinesTableReferences),
          DriverBaseline,
          PrefetchHooks Function({bool vehicleId, bool tripScoresRefs})
        > {
  $$DriverBaselinesTableTableManager(
    _$AppDatabase db,
    $DriverBaselinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DriverBaselinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DriverBaselinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DriverBaselinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerNamespace = const Value.absent(),
                Value<String?> vehicleId = const Value.absent(),
                Value<String> lifecycleState = const Value.absent(),
                Value<String> dimensionStatisticsJson = const Value.absent(),
                Value<int> baselineSchemaVersion = const Value.absent(),
                Value<String> scoringVersion = const Value.absent(),
                Value<int> validTripCount = const Value.absent(),
                Value<int?> windowStartWallTimeMicros = const Value.absent(),
                Value<int?> windowEndWallTimeMicros = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriverBaselinesCompanion(
                id: id,
                ownerNamespace: ownerNamespace,
                vehicleId: vehicleId,
                lifecycleState: lifecycleState,
                dimensionStatisticsJson: dimensionStatisticsJson,
                baselineSchemaVersion: baselineSchemaVersion,
                scoringVersion: scoringVersion,
                validTripCount: validTripCount,
                windowStartWallTimeMicros: windowStartWallTimeMicros,
                windowEndWallTimeMicros: windowEndWallTimeMicros,
                confidence: confidence,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerNamespace,
                Value<String?> vehicleId = const Value.absent(),
                required String lifecycleState,
                required String dimensionStatisticsJson,
                required int baselineSchemaVersion,
                required String scoringVersion,
                required int validTripCount,
                Value<int?> windowStartWallTimeMicros = const Value.absent(),
                Value<int?> windowEndWallTimeMicros = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => DriverBaselinesCompanion.insert(
                id: id,
                ownerNamespace: ownerNamespace,
                vehicleId: vehicleId,
                lifecycleState: lifecycleState,
                dimensionStatisticsJson: dimensionStatisticsJson,
                baselineSchemaVersion: baselineSchemaVersion,
                scoringVersion: scoringVersion,
                validTripCount: validTripCount,
                windowStartWallTimeMicros: windowStartWallTimeMicros,
                windowEndWallTimeMicros: windowEndWallTimeMicros,
                confidence: confidence,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DriverBaselinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false, tripScoresRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tripScoresRefs) db.tripScores],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (vehicleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vehicleId,
                                referencedTable:
                                    $$DriverBaselinesTableReferences
                                        ._vehicleIdTable(db),
                                referencedColumn:
                                    $$DriverBaselinesTableReferences
                                        ._vehicleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripScoresRefs)
                    await $_getPrefetchedData<
                      DriverBaseline,
                      $DriverBaselinesTable,
                      TripScore
                    >(
                      currentTable: table,
                      referencedTable: $$DriverBaselinesTableReferences
                          ._tripScoresRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DriverBaselinesTableReferences(
                            db,
                            table,
                            p0,
                          ).tripScoresRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.baselineId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DriverBaselinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriverBaselinesTable,
      DriverBaseline,
      $$DriverBaselinesTableFilterComposer,
      $$DriverBaselinesTableOrderingComposer,
      $$DriverBaselinesTableAnnotationComposer,
      $$DriverBaselinesTableCreateCompanionBuilder,
      $$DriverBaselinesTableUpdateCompanionBuilder,
      (DriverBaseline, $$DriverBaselinesTableReferences),
      DriverBaseline,
      PrefetchHooks Function({bool vehicleId, bool tripScoresRefs})
    >;
typedef $$TripScoresTableCreateCompanionBuilder =
    TripScoresCompanion Function({
      required String id,
      required String tripId,
      required int scoreSchemaVersion,
      required String scoringVersion,
      required String dimensionValuesJson,
      Value<double?> overallScore,
      Value<double?> confidence,
      required String eligibilityState,
      required String auditContributionsJson,
      Value<String?> baselineId,
      Value<String?> modelVersionsJson,
      required int createdAtMicros,
      Value<int> rowid,
    });
typedef $$TripScoresTableUpdateCompanionBuilder =
    TripScoresCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<int> scoreSchemaVersion,
      Value<String> scoringVersion,
      Value<String> dimensionValuesJson,
      Value<double?> overallScore,
      Value<double?> confidence,
      Value<String> eligibilityState,
      Value<String> auditContributionsJson,
      Value<String?> baselineId,
      Value<String?> modelVersionsJson,
      Value<int> createdAtMicros,
      Value<int> rowid,
    });

final class $$TripScoresTableReferences
    extends BaseReferences<_$AppDatabase, $TripScoresTable, TripScore> {
  $$TripScoresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_scores__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DriverBaselinesTable _baselineIdTable(_$AppDatabase db) => db
      .driverBaselines
      .createAlias('trip_scores__baseline_id__driver_baselines__id');

  $$DriverBaselinesTableProcessedTableManager? get baselineId {
    final $_column = $_itemColumn<String>('baseline_id');
    if ($_column == null) return null;
    final manager = $$DriverBaselinesTableTableManager(
      $_db,
      $_db.driverBaselines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_baselineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripScoresTableFilterComposer
    extends Composer<_$AppDatabase, $TripScoresTable> {
  $$TripScoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scoreSchemaVersion => $composableBuilder(
    column: $table.scoreSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dimensionValuesJson => $composableBuilder(
    column: $table.dimensionValuesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get overallScore => $composableBuilder(
    column: $table.overallScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eligibilityState => $composableBuilder(
    column: $table.eligibilityState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get auditContributionsJson => $composableBuilder(
    column: $table.auditContributionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersionsJson => $composableBuilder(
    column: $table.modelVersionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DriverBaselinesTableFilterComposer get baselineId {
    final $$DriverBaselinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.baselineId,
      referencedTable: $db.driverBaselines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverBaselinesTableFilterComposer(
            $db: $db,
            $table: $db.driverBaselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripScoresTableOrderingComposer
    extends Composer<_$AppDatabase, $TripScoresTable> {
  $$TripScoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scoreSchemaVersion => $composableBuilder(
    column: $table.scoreSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dimensionValuesJson => $composableBuilder(
    column: $table.dimensionValuesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get overallScore => $composableBuilder(
    column: $table.overallScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eligibilityState => $composableBuilder(
    column: $table.eligibilityState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get auditContributionsJson => $composableBuilder(
    column: $table.auditContributionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersionsJson => $composableBuilder(
    column: $table.modelVersionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DriverBaselinesTableOrderingComposer get baselineId {
    final $$DriverBaselinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.baselineId,
      referencedTable: $db.driverBaselines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverBaselinesTableOrderingComposer(
            $db: $db,
            $table: $db.driverBaselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripScoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripScoresTable> {
  $$TripScoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get scoreSchemaVersion => $composableBuilder(
    column: $table.scoreSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scoringVersion => $composableBuilder(
    column: $table.scoringVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dimensionValuesJson => $composableBuilder(
    column: $table.dimensionValuesJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get overallScore => $composableBuilder(
    column: $table.overallScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eligibilityState => $composableBuilder(
    column: $table.eligibilityState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get auditContributionsJson => $composableBuilder(
    column: $table.auditContributionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelVersionsJson => $composableBuilder(
    column: $table.modelVersionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DriverBaselinesTableAnnotationComposer get baselineId {
    final $$DriverBaselinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.baselineId,
      referencedTable: $db.driverBaselines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriverBaselinesTableAnnotationComposer(
            $db: $db,
            $table: $db.driverBaselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripScoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripScoresTable,
          TripScore,
          $$TripScoresTableFilterComposer,
          $$TripScoresTableOrderingComposer,
          $$TripScoresTableAnnotationComposer,
          $$TripScoresTableCreateCompanionBuilder,
          $$TripScoresTableUpdateCompanionBuilder,
          (TripScore, $$TripScoresTableReferences),
          TripScore,
          PrefetchHooks Function({bool tripId, bool baselineId})
        > {
  $$TripScoresTableTableManager(_$AppDatabase db, $TripScoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripScoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripScoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripScoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<int> scoreSchemaVersion = const Value.absent(),
                Value<String> scoringVersion = const Value.absent(),
                Value<String> dimensionValuesJson = const Value.absent(),
                Value<double?> overallScore = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String> eligibilityState = const Value.absent(),
                Value<String> auditContributionsJson = const Value.absent(),
                Value<String?> baselineId = const Value.absent(),
                Value<String?> modelVersionsJson = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripScoresCompanion(
                id: id,
                tripId: tripId,
                scoreSchemaVersion: scoreSchemaVersion,
                scoringVersion: scoringVersion,
                dimensionValuesJson: dimensionValuesJson,
                overallScore: overallScore,
                confidence: confidence,
                eligibilityState: eligibilityState,
                auditContributionsJson: auditContributionsJson,
                baselineId: baselineId,
                modelVersionsJson: modelVersionsJson,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required int scoreSchemaVersion,
                required String scoringVersion,
                required String dimensionValuesJson,
                Value<double?> overallScore = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                required String eligibilityState,
                required String auditContributionsJson,
                Value<String?> baselineId = const Value.absent(),
                Value<String?> modelVersionsJson = const Value.absent(),
                required int createdAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => TripScoresCompanion.insert(
                id: id,
                tripId: tripId,
                scoreSchemaVersion: scoreSchemaVersion,
                scoringVersion: scoringVersion,
                dimensionValuesJson: dimensionValuesJson,
                overallScore: overallScore,
                confidence: confidence,
                eligibilityState: eligibilityState,
                auditContributionsJson: auditContributionsJson,
                baselineId: baselineId,
                modelVersionsJson: modelVersionsJson,
                createdAtMicros: createdAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripScoresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false, baselineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripScoresTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripScoresTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (baselineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.baselineId,
                                referencedTable: $$TripScoresTableReferences
                                    ._baselineIdTable(db),
                                referencedColumn: $$TripScoresTableReferences
                                    ._baselineIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TripScoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripScoresTable,
      TripScore,
      $$TripScoresTableFilterComposer,
      $$TripScoresTableOrderingComposer,
      $$TripScoresTableAnnotationComposer,
      $$TripScoresTableCreateCompanionBuilder,
      $$TripScoresTableUpdateCompanionBuilder,
      (TripScore, $$TripScoresTableReferences),
      TripScore,
      PrefetchHooks Function({bool tripId, bool baselineId})
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      required String operationId,
      required String idempotencyKey,
      required String entityType,
      required String entityId,
      required int entityVersion,
      required String operationType,
      required String state,
      Value<String?> payloadJson,
      required int attemptCount,
      Value<int?> nextAttemptAtMicros,
      Value<String?> lastErrorCode,
      required int createdAtMicros,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<String> operationId,
      Value<String> idempotencyKey,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> entityVersion,
      Value<String> operationType,
      Value<String> state,
      Value<String?> payloadJson,
      Value<int> attemptCount,
      Value<int?> nextAttemptAtMicros,
      Value<String?> lastErrorCode,
      Value<int> createdAtMicros,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityVersion => $composableBuilder(
    column: $table.entityVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAtMicros => $composableBuilder(
    column: $table.nextAttemptAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityVersion => $composableBuilder(
    column: $table.entityVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAtMicros => $composableBuilder(
    column: $table.nextAttemptAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
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

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get entityVersion => $composableBuilder(
    column: $table.entityVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptAtMicros => $composableBuilder(
    column: $table.nextAttemptAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> entityVersion = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int?> nextAttemptAtMicros = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                operationId: operationId,
                idempotencyKey: idempotencyKey,
                entityType: entityType,
                entityId: entityId,
                entityVersion: entityVersion,
                operationType: operationType,
                state: state,
                payloadJson: payloadJson,
                attemptCount: attemptCount,
                nextAttemptAtMicros: nextAttemptAtMicros,
                lastErrorCode: lastErrorCode,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String idempotencyKey,
                required String entityType,
                required String entityId,
                required int entityVersion,
                required String operationType,
                required String state,
                Value<String?> payloadJson = const Value.absent(),
                required int attemptCount,
                Value<int?> nextAttemptAtMicros = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                required int createdAtMicros,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                operationId: operationId,
                idempotencyKey: idempotencyKey,
                entityType: entityType,
                entityId: entityId,
                entityVersion: entityVersion,
                operationType: operationType,
                state: state,
                payloadJson: payloadJson,
                attemptCount: attemptCount,
                nextAttemptAtMicros: nextAttemptAtMicros,
                lastErrorCode: lastErrorCode,
                createdAtMicros: createdAtMicros,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TripChunksTableTableManager get tripChunks =>
      $$TripChunksTableTableManager(_db, _db.tripChunks);
  $$TripEventsTableTableManager get tripEvents =>
      $$TripEventsTableTableManager(_db, _db.tripEvents);
  $$DriverBaselinesTableTableManager get driverBaselines =>
      $$DriverBaselinesTableTableManager(_db, _db.driverBaselines);
  $$TripScoresTableTableManager get tripScores =>
      $$TripScoresTableTableManager(_db, _db.tripScores);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}

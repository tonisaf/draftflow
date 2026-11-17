// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DatabasesTable extends Databases
    with TableInfo<$DatabasesTable, Database> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatabasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Untitled Database'),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentPageIdMeta = const VerificationMeta(
    'parentPageId',
  );
  @override
  late final GeneratedColumn<String> parentPageId = GeneratedColumn<String>(
    'parent_page_id',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _trashedAtMeta = const VerificationMeta(
    'trashedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trashedAt = GeneratedColumn<DateTime>(
    'trashed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trashBatchIdMeta = const VerificationMeta(
    'trashBatchId',
  );
  @override
  late final GeneratedColumn<String> trashBatchId = GeneratedColumn<String>(
    'trash_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    icon,
    parentPageId,
    createdAt,
    trashedAt,
    trashBatchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'databases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Database> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('parent_page_id')) {
      context.handle(
        _parentPageIdMeta,
        parentPageId.isAcceptableOrUnknown(
          data['parent_page_id']!,
          _parentPageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('trashed_at')) {
      context.handle(
        _trashedAtMeta,
        trashedAt.isAcceptableOrUnknown(data['trashed_at']!, _trashedAtMeta),
      );
    }
    if (data.containsKey('trash_batch_id')) {
      context.handle(
        _trashBatchIdMeta,
        trashBatchId.isAcceptableOrUnknown(
          data['trash_batch_id']!,
          _trashBatchIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Database map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Database(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      parentPageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_page_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      trashedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trashed_at'],
      ),
      trashBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trash_batch_id'],
      ),
    );
  }

  @override
  $DatabasesTable createAlias(String alias) {
    return $DatabasesTable(attachedDatabase, alias);
  }
}

class Database extends DataClass implements Insertable<Database> {
  final String id;
  final String title;
  final String? icon;
  final String? parentPageId;
  final DateTime createdAt;
  final DateTime? trashedAt;
  final String? trashBatchId;
  const Database({
    required this.id,
    required this.title,
    this.icon,
    this.parentPageId,
    required this.createdAt,
    this.trashedAt,
    this.trashBatchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || parentPageId != null) {
      map['parent_page_id'] = Variable<String>(parentPageId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || trashedAt != null) {
      map['trashed_at'] = Variable<DateTime>(trashedAt);
    }
    if (!nullToAbsent || trashBatchId != null) {
      map['trash_batch_id'] = Variable<String>(trashBatchId);
    }
    return map;
  }

  DatabasesCompanion toCompanion(bool nullToAbsent) {
    return DatabasesCompanion(
      id: Value(id),
      title: Value(title),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      parentPageId: parentPageId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentPageId),
      createdAt: Value(createdAt),
      trashedAt: trashedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAt),
      trashBatchId: trashBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(trashBatchId),
    );
  }

  factory Database.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Database(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      icon: serializer.fromJson<String?>(json['icon']),
      parentPageId: serializer.fromJson<String?>(json['parentPageId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      trashedAt: serializer.fromJson<DateTime?>(json['trashedAt']),
      trashBatchId: serializer.fromJson<String?>(json['trashBatchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'icon': serializer.toJson<String?>(icon),
      'parentPageId': serializer.toJson<String?>(parentPageId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'trashedAt': serializer.toJson<DateTime?>(trashedAt),
      'trashBatchId': serializer.toJson<String?>(trashBatchId),
    };
  }

  Database copyWith({
    String? id,
    String? title,
    Value<String?> icon = const Value.absent(),
    Value<String?> parentPageId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> trashedAt = const Value.absent(),
    Value<String?> trashBatchId = const Value.absent(),
  }) => Database(
    id: id ?? this.id,
    title: title ?? this.title,
    icon: icon.present ? icon.value : this.icon,
    parentPageId: parentPageId.present ? parentPageId.value : this.parentPageId,
    createdAt: createdAt ?? this.createdAt,
    trashedAt: trashedAt.present ? trashedAt.value : this.trashedAt,
    trashBatchId: trashBatchId.present ? trashBatchId.value : this.trashBatchId,
  );
  Database copyWithCompanion(DatabasesCompanion data) {
    return Database(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      icon: data.icon.present ? data.icon.value : this.icon,
      parentPageId: data.parentPageId.present
          ? data.parentPageId.value
          : this.parentPageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      trashedAt: data.trashedAt.present ? data.trashedAt.value : this.trashedAt,
      trashBatchId: data.trashBatchId.present
          ? data.trashBatchId.value
          : this.trashBatchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Database(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('parentPageId: $parentPageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('trashBatchId: $trashBatchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    icon,
    parentPageId,
    createdAt,
    trashedAt,
    trashBatchId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Database &&
          other.id == this.id &&
          other.title == this.title &&
          other.icon == this.icon &&
          other.parentPageId == this.parentPageId &&
          other.createdAt == this.createdAt &&
          other.trashedAt == this.trashedAt &&
          other.trashBatchId == this.trashBatchId);
}

class DatabasesCompanion extends UpdateCompanion<Database> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> icon;
  final Value<String?> parentPageId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> trashedAt;
  final Value<String?> trashBatchId;
  final Value<int> rowid;
  const DatabasesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.icon = const Value.absent(),
    this.parentPageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.trashBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatabasesCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.icon = const Value.absent(),
    this.parentPageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.trashBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Database> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? icon,
    Expression<String>? parentPageId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? trashedAt,
    Expression<String>? trashBatchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (icon != null) 'icon': icon,
      if (parentPageId != null) 'parent_page_id': parentPageId,
      if (createdAt != null) 'created_at': createdAt,
      if (trashedAt != null) 'trashed_at': trashedAt,
      if (trashBatchId != null) 'trash_batch_id': trashBatchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatabasesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? icon,
    Value<String?>? parentPageId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? trashedAt,
    Value<String?>? trashBatchId,
    Value<int>? rowid,
  }) {
    return DatabasesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      parentPageId: parentPageId ?? this.parentPageId,
      createdAt: createdAt ?? this.createdAt,
      trashedAt: trashedAt ?? this.trashedAt,
      trashBatchId: trashBatchId ?? this.trashBatchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (parentPageId.present) {
      map['parent_page_id'] = Variable<String>(parentPageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (trashedAt.present) {
      map['trashed_at'] = Variable<DateTime>(trashedAt.value);
    }
    if (trashBatchId.present) {
      map['trash_batch_id'] = Variable<String>(trashBatchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatabasesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('parentPageId: $parentPageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('trashBatchId: $trashBatchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PagesTable extends Pages with TableInfo<$PagesTable, Page> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderKeyMeta = const VerificationMeta(
    'orderKey',
  );
  @override
  late final GeneratedColumn<String> orderKey = GeneratedColumn<String>(
    'order_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _databaseIdMeta = const VerificationMeta(
    'databaseId',
  );
  @override
  late final GeneratedColumn<String> databaseId = GeneratedColumn<String>(
    'database_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES databases (id)',
    ),
  );
  static const VerificationMeta _propertiesMeta = const VerificationMeta(
    'properties',
  );
  @override
  late final GeneratedColumn<String> properties = GeneratedColumn<String>(
    'properties',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleFoldedMeta = const VerificationMeta(
    'titleFolded',
  );
  @override
  late final GeneratedColumn<String> titleFolded = GeneratedColumn<String>(
    'title_folded',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _propertiesFoldedMeta = const VerificationMeta(
    'propertiesFolded',
  );
  @override
  late final GeneratedColumn<String> propertiesFolded = GeneratedColumn<String>(
    'properties_folded',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _trashedAtMeta = const VerificationMeta(
    'trashedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trashedAt = GeneratedColumn<DateTime>(
    'trashed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trashBatchIdMeta = const VerificationMeta(
    'trashBatchId',
  );
  @override
  late final GeneratedColumn<String> trashBatchId = GeneratedColumn<String>(
    'trash_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    parentId,
    icon,
    cover,
    orderKey,
    databaseId,
    properties,
    titleFolded,
    propertiesFolded,
    createdAt,
    trashedAt,
    trashBatchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Page> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('order_key')) {
      context.handle(
        _orderKeyMeta,
        orderKey.isAcceptableOrUnknown(data['order_key']!, _orderKeyMeta),
      );
    }
    if (data.containsKey('database_id')) {
      context.handle(
        _databaseIdMeta,
        databaseId.isAcceptableOrUnknown(data['database_id']!, _databaseIdMeta),
      );
    }
    if (data.containsKey('properties')) {
      context.handle(
        _propertiesMeta,
        properties.isAcceptableOrUnknown(data['properties']!, _propertiesMeta),
      );
    }
    if (data.containsKey('title_folded')) {
      context.handle(
        _titleFoldedMeta,
        titleFolded.isAcceptableOrUnknown(
          data['title_folded']!,
          _titleFoldedMeta,
        ),
      );
    }
    if (data.containsKey('properties_folded')) {
      context.handle(
        _propertiesFoldedMeta,
        propertiesFolded.isAcceptableOrUnknown(
          data['properties_folded']!,
          _propertiesFoldedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('trashed_at')) {
      context.handle(
        _trashedAtMeta,
        trashedAt.isAcceptableOrUnknown(data['trashed_at']!, _trashedAtMeta),
      );
    }
    if (data.containsKey('trash_batch_id')) {
      context.handle(
        _trashBatchIdMeta,
        trashBatchId.isAcceptableOrUnknown(
          data['trash_batch_id']!,
          _trashBatchIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Page map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Page(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      orderKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_key'],
      ),
      databaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}database_id'],
      ),
      properties: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}properties'],
      ),
      titleFolded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_folded'],
      ),
      propertiesFolded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}properties_folded'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      trashedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trashed_at'],
      ),
      trashBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trash_batch_id'],
      ),
    );
  }

  @override
  $PagesTable createAlias(String alias) {
    return $PagesTable(attachedDatabase, alias);
  }
}

class Page extends DataClass implements Insertable<Page> {
  final String id;
  final String title;
  final String? parentId;
  final String? icon;
  final String? cover;
  final String? orderKey;
  final String? databaseId;
  final String? properties;
  final String? titleFolded;
  final String? propertiesFolded;
  final DateTime createdAt;
  final DateTime? trashedAt;
  final String? trashBatchId;
  const Page({
    required this.id,
    required this.title,
    this.parentId,
    this.icon,
    this.cover,
    this.orderKey,
    this.databaseId,
    this.properties,
    this.titleFolded,
    this.propertiesFolded,
    required this.createdAt,
    this.trashedAt,
    this.trashBatchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    if (!nullToAbsent || orderKey != null) {
      map['order_key'] = Variable<String>(orderKey);
    }
    if (!nullToAbsent || databaseId != null) {
      map['database_id'] = Variable<String>(databaseId);
    }
    if (!nullToAbsent || properties != null) {
      map['properties'] = Variable<String>(properties);
    }
    if (!nullToAbsent || titleFolded != null) {
      map['title_folded'] = Variable<String>(titleFolded);
    }
    if (!nullToAbsent || propertiesFolded != null) {
      map['properties_folded'] = Variable<String>(propertiesFolded);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || trashedAt != null) {
      map['trashed_at'] = Variable<DateTime>(trashedAt);
    }
    if (!nullToAbsent || trashBatchId != null) {
      map['trash_batch_id'] = Variable<String>(trashBatchId);
    }
    return map;
  }

  PagesCompanion toCompanion(bool nullToAbsent) {
    return PagesCompanion(
      id: Value(id),
      title: Value(title),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      orderKey: orderKey == null && nullToAbsent
          ? const Value.absent()
          : Value(orderKey),
      databaseId: databaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(databaseId),
      properties: properties == null && nullToAbsent
          ? const Value.absent()
          : Value(properties),
      titleFolded: titleFolded == null && nullToAbsent
          ? const Value.absent()
          : Value(titleFolded),
      propertiesFolded: propertiesFolded == null && nullToAbsent
          ? const Value.absent()
          : Value(propertiesFolded),
      createdAt: Value(createdAt),
      trashedAt: trashedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAt),
      trashBatchId: trashBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(trashBatchId),
    );
  }

  factory Page.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Page(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      icon: serializer.fromJson<String?>(json['icon']),
      cover: serializer.fromJson<String?>(json['cover']),
      orderKey: serializer.fromJson<String?>(json['orderKey']),
      databaseId: serializer.fromJson<String?>(json['databaseId']),
      properties: serializer.fromJson<String?>(json['properties']),
      titleFolded: serializer.fromJson<String?>(json['titleFolded']),
      propertiesFolded: serializer.fromJson<String?>(json['propertiesFolded']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      trashedAt: serializer.fromJson<DateTime?>(json['trashedAt']),
      trashBatchId: serializer.fromJson<String?>(json['trashBatchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'parentId': serializer.toJson<String?>(parentId),
      'icon': serializer.toJson<String?>(icon),
      'cover': serializer.toJson<String?>(cover),
      'orderKey': serializer.toJson<String?>(orderKey),
      'databaseId': serializer.toJson<String?>(databaseId),
      'properties': serializer.toJson<String?>(properties),
      'titleFolded': serializer.toJson<String?>(titleFolded),
      'propertiesFolded': serializer.toJson<String?>(propertiesFolded),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'trashedAt': serializer.toJson<DateTime?>(trashedAt),
      'trashBatchId': serializer.toJson<String?>(trashBatchId),
    };
  }

  Page copyWith({
    String? id,
    String? title,
    Value<String?> parentId = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    Value<String?> orderKey = const Value.absent(),
    Value<String?> databaseId = const Value.absent(),
    Value<String?> properties = const Value.absent(),
    Value<String?> titleFolded = const Value.absent(),
    Value<String?> propertiesFolded = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> trashedAt = const Value.absent(),
    Value<String?> trashBatchId = const Value.absent(),
  }) => Page(
    id: id ?? this.id,
    title: title ?? this.title,
    parentId: parentId.present ? parentId.value : this.parentId,
    icon: icon.present ? icon.value : this.icon,
    cover: cover.present ? cover.value : this.cover,
    orderKey: orderKey.present ? orderKey.value : this.orderKey,
    databaseId: databaseId.present ? databaseId.value : this.databaseId,
    properties: properties.present ? properties.value : this.properties,
    titleFolded: titleFolded.present ? titleFolded.value : this.titleFolded,
    propertiesFolded: propertiesFolded.present
        ? propertiesFolded.value
        : this.propertiesFolded,
    createdAt: createdAt ?? this.createdAt,
    trashedAt: trashedAt.present ? trashedAt.value : this.trashedAt,
    trashBatchId: trashBatchId.present ? trashBatchId.value : this.trashBatchId,
  );
  Page copyWithCompanion(PagesCompanion data) {
    return Page(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      icon: data.icon.present ? data.icon.value : this.icon,
      cover: data.cover.present ? data.cover.value : this.cover,
      orderKey: data.orderKey.present ? data.orderKey.value : this.orderKey,
      databaseId: data.databaseId.present
          ? data.databaseId.value
          : this.databaseId,
      properties: data.properties.present
          ? data.properties.value
          : this.properties,
      titleFolded: data.titleFolded.present
          ? data.titleFolded.value
          : this.titleFolded,
      propertiesFolded: data.propertiesFolded.present
          ? data.propertiesFolded.value
          : this.propertiesFolded,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      trashedAt: data.trashedAt.present ? data.trashedAt.value : this.trashedAt,
      trashBatchId: data.trashBatchId.present
          ? data.trashBatchId.value
          : this.trashBatchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Page(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('parentId: $parentId, ')
          ..write('icon: $icon, ')
          ..write('cover: $cover, ')
          ..write('orderKey: $orderKey, ')
          ..write('databaseId: $databaseId, ')
          ..write('properties: $properties, ')
          ..write('titleFolded: $titleFolded, ')
          ..write('propertiesFolded: $propertiesFolded, ')
          ..write('createdAt: $createdAt, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('trashBatchId: $trashBatchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    parentId,
    icon,
    cover,
    orderKey,
    databaseId,
    properties,
    titleFolded,
    propertiesFolded,
    createdAt,
    trashedAt,
    trashBatchId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Page &&
          other.id == this.id &&
          other.title == this.title &&
          other.parentId == this.parentId &&
          other.icon == this.icon &&
          other.cover == this.cover &&
          other.orderKey == this.orderKey &&
          other.databaseId == this.databaseId &&
          other.properties == this.properties &&
          other.titleFolded == this.titleFolded &&
          other.propertiesFolded == this.propertiesFolded &&
          other.createdAt == this.createdAt &&
          other.trashedAt == this.trashedAt &&
          other.trashBatchId == this.trashBatchId);
}

class PagesCompanion extends UpdateCompanion<Page> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> parentId;
  final Value<String?> icon;
  final Value<String?> cover;
  final Value<String?> orderKey;
  final Value<String?> databaseId;
  final Value<String?> properties;
  final Value<String?> titleFolded;
  final Value<String?> propertiesFolded;
  final Value<DateTime> createdAt;
  final Value<DateTime?> trashedAt;
  final Value<String?> trashBatchId;
  final Value<int> rowid;
  const PagesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.parentId = const Value.absent(),
    this.icon = const Value.absent(),
    this.cover = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.databaseId = const Value.absent(),
    this.properties = const Value.absent(),
    this.titleFolded = const Value.absent(),
    this.propertiesFolded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.trashBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PagesCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.parentId = const Value.absent(),
    this.icon = const Value.absent(),
    this.cover = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.databaseId = const Value.absent(),
    this.properties = const Value.absent(),
    this.titleFolded = const Value.absent(),
    this.propertiesFolded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.trashBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Page> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? parentId,
    Expression<String>? icon,
    Expression<String>? cover,
    Expression<String>? orderKey,
    Expression<String>? databaseId,
    Expression<String>? properties,
    Expression<String>? titleFolded,
    Expression<String>? propertiesFolded,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? trashedAt,
    Expression<String>? trashBatchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (parentId != null) 'parent_id': parentId,
      if (icon != null) 'icon': icon,
      if (cover != null) 'cover': cover,
      if (orderKey != null) 'order_key': orderKey,
      if (databaseId != null) 'database_id': databaseId,
      if (properties != null) 'properties': properties,
      if (titleFolded != null) 'title_folded': titleFolded,
      if (propertiesFolded != null) 'properties_folded': propertiesFolded,
      if (createdAt != null) 'created_at': createdAt,
      if (trashedAt != null) 'trashed_at': trashedAt,
      if (trashBatchId != null) 'trash_batch_id': trashBatchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PagesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? parentId,
    Value<String?>? icon,
    Value<String?>? cover,
    Value<String?>? orderKey,
    Value<String?>? databaseId,
    Value<String?>? properties,
    Value<String?>? titleFolded,
    Value<String?>? propertiesFolded,
    Value<DateTime>? createdAt,
    Value<DateTime?>? trashedAt,
    Value<String?>? trashBatchId,
    Value<int>? rowid,
  }) {
    return PagesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      cover: cover ?? this.cover,
      orderKey: orderKey ?? this.orderKey,
      databaseId: databaseId ?? this.databaseId,
      properties: properties ?? this.properties,
      titleFolded: titleFolded ?? this.titleFolded,
      propertiesFolded: propertiesFolded ?? this.propertiesFolded,
      createdAt: createdAt ?? this.createdAt,
      trashedAt: trashedAt ?? this.trashedAt,
      trashBatchId: trashBatchId ?? this.trashBatchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (orderKey.present) {
      map['order_key'] = Variable<String>(orderKey.value);
    }
    if (databaseId.present) {
      map['database_id'] = Variable<String>(databaseId.value);
    }
    if (properties.present) {
      map['properties'] = Variable<String>(properties.value);
    }
    if (titleFolded.present) {
      map['title_folded'] = Variable<String>(titleFolded.value);
    }
    if (propertiesFolded.present) {
      map['properties_folded'] = Variable<String>(propertiesFolded.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (trashedAt.present) {
      map['trashed_at'] = Variable<DateTime>(trashedAt.value);
    }
    if (trashBatchId.present) {
      map['trash_batch_id'] = Variable<String>(trashBatchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PagesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('parentId: $parentId, ')
          ..write('icon: $icon, ')
          ..write('cover: $cover, ')
          ..write('orderKey: $orderKey, ')
          ..write('databaseId: $databaseId, ')
          ..write('properties: $properties, ')
          ..write('titleFolded: $titleFolded, ')
          ..write('propertiesFolded: $propertiesFolded, ')
          ..write('createdAt: $createdAt, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('trashBatchId: $trashBatchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, Block> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pages (id)',
    ),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderKeyMeta = const VerificationMeta(
    'orderKey',
  );
  @override
  late final GeneratedColumn<String> orderKey = GeneratedColumn<String>(
    'order_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trashedAtMeta = const VerificationMeta(
    'trashedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trashedAt = GeneratedColumn<DateTime>(
    'trashed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trashBatchIdMeta = const VerificationMeta(
    'trashBatchId',
  );
  @override
  late final GeneratedColumn<String> trashBatchId = GeneratedColumn<String>(
    'trash_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pageId,
    parentId,
    type,
    content,
    orderKey,
    trashedAt,
    trashBatchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Block> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('order_key')) {
      context.handle(
        _orderKeyMeta,
        orderKey.isAcceptableOrUnknown(data['order_key']!, _orderKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_orderKeyMeta);
    }
    if (data.containsKey('trashed_at')) {
      context.handle(
        _trashedAtMeta,
        trashedAt.isAcceptableOrUnknown(data['trashed_at']!, _trashedAtMeta),
      );
    }
    if (data.containsKey('trash_batch_id')) {
      context.handle(
        _trashBatchIdMeta,
        trashBatchId.isAcceptableOrUnknown(
          data['trash_batch_id']!,
          _trashBatchIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Block map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Block(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      orderKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_key'],
      )!,
      trashedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trashed_at'],
      ),
      trashBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trash_batch_id'],
      ),
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class Block extends DataClass implements Insertable<Block> {
  final String id;
  final String pageId;
  final String? parentId;
  final String type;
  final String content;
  final String orderKey;
  final DateTime? trashedAt;
  final String? trashBatchId;
  const Block({
    required this.id,
    required this.pageId,
    this.parentId,
    required this.type,
    required this.content,
    required this.orderKey,
    this.trashedAt,
    this.trashBatchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['page_id'] = Variable<String>(pageId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['type'] = Variable<String>(type);
    map['content'] = Variable<String>(content);
    map['order_key'] = Variable<String>(orderKey);
    if (!nullToAbsent || trashedAt != null) {
      map['trashed_at'] = Variable<DateTime>(trashedAt);
    }
    if (!nullToAbsent || trashBatchId != null) {
      map['trash_batch_id'] = Variable<String>(trashBatchId);
    }
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      pageId: Value(pageId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      type: Value(type),
      content: Value(content),
      orderKey: Value(orderKey),
      trashedAt: trashedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAt),
      trashBatchId: trashBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(trashBatchId),
    );
  }

  factory Block.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Block(
      id: serializer.fromJson<String>(json['id']),
      pageId: serializer.fromJson<String>(json['pageId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      type: serializer.fromJson<String>(json['type']),
      content: serializer.fromJson<String>(json['content']),
      orderKey: serializer.fromJson<String>(json['orderKey']),
      trashedAt: serializer.fromJson<DateTime?>(json['trashedAt']),
      trashBatchId: serializer.fromJson<String?>(json['trashBatchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pageId': serializer.toJson<String>(pageId),
      'parentId': serializer.toJson<String?>(parentId),
      'type': serializer.toJson<String>(type),
      'content': serializer.toJson<String>(content),
      'orderKey': serializer.toJson<String>(orderKey),
      'trashedAt': serializer.toJson<DateTime?>(trashedAt),
      'trashBatchId': serializer.toJson<String?>(trashBatchId),
    };
  }

  Block copyWith({
    String? id,
    String? pageId,
    Value<String?> parentId = const Value.absent(),
    String? type,
    String? content,
    String? orderKey,
    Value<DateTime?> trashedAt = const Value.absent(),
    Value<String?> trashBatchId = const Value.absent(),
  }) => Block(
    id: id ?? this.id,
    pageId: pageId ?? this.pageId,
    parentId: parentId.present ? parentId.value : this.parentId,
    type: type ?? this.type,
    content: content ?? this.content,
    orderKey: orderKey ?? this.orderKey,
    trashedAt: trashedAt.present ? trashedAt.value : this.trashedAt,
    trashBatchId: trashBatchId.present ? trashBatchId.value : this.trashBatchId,
  );
  Block copyWithCompanion(BlocksCompanion data) {
    return Block(
      id: data.id.present ? data.id.value : this.id,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      orderKey: data.orderKey.present ? data.orderKey.value : this.orderKey,
      trashedAt: data.trashedAt.present ? data.trashedAt.value : this.trashedAt,
      trashBatchId: data.trashBatchId.present
          ? data.trashBatchId.value
          : this.trashBatchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Block(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('parentId: $parentId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('orderKey: $orderKey, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('trashBatchId: $trashBatchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pageId,
    parentId,
    type,
    content,
    orderKey,
    trashedAt,
    trashBatchId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Block &&
          other.id == this.id &&
          other.pageId == this.pageId &&
          other.parentId == this.parentId &&
          other.type == this.type &&
          other.content == this.content &&
          other.orderKey == this.orderKey &&
          other.trashedAt == this.trashedAt &&
          other.trashBatchId == this.trashBatchId);
}

class BlocksCompanion extends UpdateCompanion<Block> {
  final Value<String> id;
  final Value<String> pageId;
  final Value<String?> parentId;
  final Value<String> type;
  final Value<String> content;
  final Value<String> orderKey;
  final Value<DateTime?> trashedAt;
  final Value<String?> trashBatchId;
  final Value<int> rowid;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.pageId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.trashBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocksCompanion.insert({
    required String id,
    required String pageId,
    this.parentId = const Value.absent(),
    required String type,
    required String content,
    required String orderKey,
    this.trashedAt = const Value.absent(),
    this.trashBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pageId = Value(pageId),
       type = Value(type),
       content = Value(content),
       orderKey = Value(orderKey);
  static Insertable<Block> custom({
    Expression<String>? id,
    Expression<String>? pageId,
    Expression<String>? parentId,
    Expression<String>? type,
    Expression<String>? content,
    Expression<String>? orderKey,
    Expression<DateTime>? trashedAt,
    Expression<String>? trashBatchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pageId != null) 'page_id': pageId,
      if (parentId != null) 'parent_id': parentId,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (orderKey != null) 'order_key': orderKey,
      if (trashedAt != null) 'trashed_at': trashedAt,
      if (trashBatchId != null) 'trash_batch_id': trashBatchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? pageId,
    Value<String?>? parentId,
    Value<String>? type,
    Value<String>? content,
    Value<String>? orderKey,
    Value<DateTime?>? trashedAt,
    Value<String?>? trashBatchId,
    Value<int>? rowid,
  }) {
    return BlocksCompanion(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      content: content ?? this.content,
      orderKey: orderKey ?? this.orderKey,
      trashedAt: trashedAt ?? this.trashedAt,
      trashBatchId: trashBatchId ?? this.trashBatchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (orderKey.present) {
      map['order_key'] = Variable<String>(orderKey.value);
    }
    if (trashedAt.present) {
      map['trashed_at'] = Variable<DateTime>(trashedAt.value);
    }
    if (trashBatchId.present) {
      map['trash_batch_id'] = Variable<String>(trashBatchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('parentId: $parentId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('orderKey: $orderKey, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('trashBatchId: $trashBatchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatabaseColumnsTable extends DatabaseColumns
    with TableInfo<$DatabaseColumnsTable, DatabaseColumn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatabaseColumnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _databaseIdMeta = const VerificationMeta(
    'databaseId',
  );
  @override
  late final GeneratedColumn<String> databaseId = GeneratedColumn<String>(
    'database_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES databases (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _optionsMeta = const VerificationMeta(
    'options',
  );
  @override
  late final GeneratedColumn<String> options = GeneratedColumn<String>(
    'options',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(160.0),
  );
  static const VerificationMeta _orderKeyMeta = const VerificationMeta(
    'orderKey',
  );
  @override
  late final GeneratedColumn<String> orderKey = GeneratedColumn<String>(
    'order_key',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    databaseId,
    name,
    type,
    options,
    width,
    orderKey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'database_columns';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatabaseColumn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('database_id')) {
      context.handle(
        _databaseIdMeta,
        databaseId.isAcceptableOrUnknown(data['database_id']!, _databaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_databaseIdMeta);
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
    if (data.containsKey('options')) {
      context.handle(
        _optionsMeta,
        options.isAcceptableOrUnknown(data['options']!, _optionsMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('order_key')) {
      context.handle(
        _orderKeyMeta,
        orderKey.isAcceptableOrUnknown(data['order_key']!, _orderKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_orderKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DatabaseColumn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatabaseColumn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      databaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}database_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      options: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      orderKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DatabaseColumnsTable createAlias(String alias) {
    return $DatabaseColumnsTable(attachedDatabase, alias);
  }
}

class DatabaseColumn extends DataClass implements Insertable<DatabaseColumn> {
  final String id;
  final String databaseId;
  final String name;
  final String type;
  final String? options;
  final double width;
  final String orderKey;
  final DateTime createdAt;
  const DatabaseColumn({
    required this.id,
    required this.databaseId,
    required this.name,
    required this.type,
    this.options,
    required this.width,
    required this.orderKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['database_id'] = Variable<String>(databaseId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || options != null) {
      map['options'] = Variable<String>(options);
    }
    map['width'] = Variable<double>(width);
    map['order_key'] = Variable<String>(orderKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DatabaseColumnsCompanion toCompanion(bool nullToAbsent) {
    return DatabaseColumnsCompanion(
      id: Value(id),
      databaseId: Value(databaseId),
      name: Value(name),
      type: Value(type),
      options: options == null && nullToAbsent
          ? const Value.absent()
          : Value(options),
      width: Value(width),
      orderKey: Value(orderKey),
      createdAt: Value(createdAt),
    );
  }

  factory DatabaseColumn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatabaseColumn(
      id: serializer.fromJson<String>(json['id']),
      databaseId: serializer.fromJson<String>(json['databaseId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      options: serializer.fromJson<String?>(json['options']),
      width: serializer.fromJson<double>(json['width']),
      orderKey: serializer.fromJson<String>(json['orderKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'databaseId': serializer.toJson<String>(databaseId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'options': serializer.toJson<String?>(options),
      'width': serializer.toJson<double>(width),
      'orderKey': serializer.toJson<String>(orderKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DatabaseColumn copyWith({
    String? id,
    String? databaseId,
    String? name,
    String? type,
    Value<String?> options = const Value.absent(),
    double? width,
    String? orderKey,
    DateTime? createdAt,
  }) => DatabaseColumn(
    id: id ?? this.id,
    databaseId: databaseId ?? this.databaseId,
    name: name ?? this.name,
    type: type ?? this.type,
    options: options.present ? options.value : this.options,
    width: width ?? this.width,
    orderKey: orderKey ?? this.orderKey,
    createdAt: createdAt ?? this.createdAt,
  );
  DatabaseColumn copyWithCompanion(DatabaseColumnsCompanion data) {
    return DatabaseColumn(
      id: data.id.present ? data.id.value : this.id,
      databaseId: data.databaseId.present
          ? data.databaseId.value
          : this.databaseId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      options: data.options.present ? data.options.value : this.options,
      width: data.width.present ? data.width.value : this.width,
      orderKey: data.orderKey.present ? data.orderKey.value : this.orderKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatabaseColumn(')
          ..write('id: $id, ')
          ..write('databaseId: $databaseId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('options: $options, ')
          ..write('width: $width, ')
          ..write('orderKey: $orderKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    databaseId,
    name,
    type,
    options,
    width,
    orderKey,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatabaseColumn &&
          other.id == this.id &&
          other.databaseId == this.databaseId &&
          other.name == this.name &&
          other.type == this.type &&
          other.options == this.options &&
          other.width == this.width &&
          other.orderKey == this.orderKey &&
          other.createdAt == this.createdAt);
}

class DatabaseColumnsCompanion extends UpdateCompanion<DatabaseColumn> {
  final Value<String> id;
  final Value<String> databaseId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> options;
  final Value<double> width;
  final Value<String> orderKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DatabaseColumnsCompanion({
    this.id = const Value.absent(),
    this.databaseId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.options = const Value.absent(),
    this.width = const Value.absent(),
    this.orderKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatabaseColumnsCompanion.insert({
    required String id,
    required String databaseId,
    required String name,
    required String type,
    this.options = const Value.absent(),
    this.width = const Value.absent(),
    required String orderKey,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       databaseId = Value(databaseId),
       name = Value(name),
       type = Value(type),
       orderKey = Value(orderKey);
  static Insertable<DatabaseColumn> custom({
    Expression<String>? id,
    Expression<String>? databaseId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? options,
    Expression<double>? width,
    Expression<String>? orderKey,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (databaseId != null) 'database_id': databaseId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (options != null) 'options': options,
      if (width != null) 'width': width,
      if (orderKey != null) 'order_key': orderKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatabaseColumnsCompanion copyWith({
    Value<String>? id,
    Value<String>? databaseId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? options,
    Value<double>? width,
    Value<String>? orderKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DatabaseColumnsCompanion(
      id: id ?? this.id,
      databaseId: databaseId ?? this.databaseId,
      name: name ?? this.name,
      type: type ?? this.type,
      options: options ?? this.options,
      width: width ?? this.width,
      orderKey: orderKey ?? this.orderKey,
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
    if (databaseId.present) {
      map['database_id'] = Variable<String>(databaseId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (options.present) {
      map['options'] = Variable<String>(options.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (orderKey.present) {
      map['order_key'] = Variable<String>(orderKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatabaseColumnsCompanion(')
          ..write('id: $id, ')
          ..write('databaseId: $databaseId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('options: $options, ')
          ..write('width: $width, ')
          ..write('orderKey: $orderKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EditorDraftsTable extends EditorDrafts
    with TableInfo<$EditorDraftsTable, EditorDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EditorDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<String> baseVersion = GeneratedColumn<String>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    id,
    pageId,
    baseVersion,
    content,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'editor_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EditorDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIdMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseVersionMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EditorDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EditorDraft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_version'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EditorDraftsTable createAlias(String alias) {
    return $EditorDraftsTable(attachedDatabase, alias);
  }
}

class EditorDraft extends DataClass implements Insertable<EditorDraft> {
  final String id;
  final String pageId;
  final String baseVersion;
  final String content;
  final DateTime updatedAt;
  const EditorDraft({
    required this.id,
    required this.pageId,
    required this.baseVersion,
    required this.content,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['page_id'] = Variable<String>(pageId);
    map['base_version'] = Variable<String>(baseVersion);
    map['content'] = Variable<String>(content);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EditorDraftsCompanion toCompanion(bool nullToAbsent) {
    return EditorDraftsCompanion(
      id: Value(id),
      pageId: Value(pageId),
      baseVersion: Value(baseVersion),
      content: Value(content),
      updatedAt: Value(updatedAt),
    );
  }

  factory EditorDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EditorDraft(
      id: serializer.fromJson<String>(json['id']),
      pageId: serializer.fromJson<String>(json['pageId']),
      baseVersion: serializer.fromJson<String>(json['baseVersion']),
      content: serializer.fromJson<String>(json['content']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pageId': serializer.toJson<String>(pageId),
      'baseVersion': serializer.toJson<String>(baseVersion),
      'content': serializer.toJson<String>(content),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EditorDraft copyWith({
    String? id,
    String? pageId,
    String? baseVersion,
    String? content,
    DateTime? updatedAt,
  }) => EditorDraft(
    id: id ?? this.id,
    pageId: pageId ?? this.pageId,
    baseVersion: baseVersion ?? this.baseVersion,
    content: content ?? this.content,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EditorDraft copyWithCompanion(EditorDraftsCompanion data) {
    return EditorDraft(
      id: data.id.present ? data.id.value : this.id,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      content: data.content.present ? data.content.value : this.content,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EditorDraft(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pageId, baseVersion, content, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditorDraft &&
          other.id == this.id &&
          other.pageId == this.pageId &&
          other.baseVersion == this.baseVersion &&
          other.content == this.content &&
          other.updatedAt == this.updatedAt);
}

class EditorDraftsCompanion extends UpdateCompanion<EditorDraft> {
  final Value<String> id;
  final Value<String> pageId;
  final Value<String> baseVersion;
  final Value<String> content;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EditorDraftsCompanion({
    this.id = const Value.absent(),
    this.pageId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.content = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EditorDraftsCompanion.insert({
    required String id,
    required String pageId,
    required String baseVersion,
    required String content,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pageId = Value(pageId),
       baseVersion = Value(baseVersion),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<EditorDraft> custom({
    Expression<String>? id,
    Expression<String>? pageId,
    Expression<String>? baseVersion,
    Expression<String>? content,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pageId != null) 'page_id': pageId,
      if (baseVersion != null) 'base_version': baseVersion,
      if (content != null) 'content': content,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EditorDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? pageId,
    Value<String>? baseVersion,
    Value<String>? content,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EditorDraftsCompanion(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      baseVersion: baseVersion ?? this.baseVersion,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<String>(baseVersion.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
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
    return (StringBuffer('EditorDraftsCompanion(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DatabasesTable databases = $DatabasesTable(this);
  late final $PagesTable pages = $PagesTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $DatabaseColumnsTable databaseColumns = $DatabaseColumnsTable(
    this,
  );
  late final $EditorDraftsTable editorDrafts = $EditorDraftsTable(this);
  late final Index pagesDatabaseOrder = Index(
    'pages_database_order',
    'CREATE INDEX pages_database_order ON pages (database_id, trashed_at, order_key, created_at, id)',
  );
  late final Index pagesParentOrder = Index(
    'pages_parent_order',
    'CREATE INDEX pages_parent_order ON pages (parent_id, trashed_at, order_key)',
  );
  late final Index blocksPageOrder = Index(
    'blocks_page_order',
    'CREATE INDEX blocks_page_order ON blocks (page_id, trashed_at, order_key, id)',
  );
  late final Index databaseColumnsOrder = Index(
    'database_columns_order',
    'CREATE INDEX database_columns_order ON database_columns (database_id, order_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    databases,
    pages,
    blocks,
    databaseColumns,
    editorDrafts,
    pagesDatabaseOrder,
    pagesParentOrder,
    blocksPageOrder,
    databaseColumnsOrder,
  ];
}

typedef $$DatabasesTableCreateCompanionBuilder = DatabasesCompanion Function({
  required String id,
  Value<String> title,
  Value<String?> icon,
  Value<String?> parentPageId,
  Value<DateTime> createdAt,
  Value<DateTime?> trashedAt,
  Value<String?> trashBatchId,
  Value<int> rowid,
});
typedef $$DatabasesTableUpdateCompanionBuilder = DatabasesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> icon,
  Value<String?> parentPageId,
  Value<DateTime> createdAt,
  Value<DateTime?> trashedAt,
  Value<String?> trashBatchId,
  Value<int> rowid,
});

final class $$DatabasesTableReferences
    extends BaseReferences<_$AppDatabase, $DatabasesTable, Database> {
  $$DatabasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PagesTable, List<Page>> _pagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pages,
    aliasName: 'databases__id__pages__database_id',
  );

  $$PagesTableProcessedTableManager get pagesRefs {
    final manager = $$PagesTableTableManager(
      $_db,
      $_db.pages,
    ).filter((f) => f.databaseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DatabaseColumnsTable, List<DatabaseColumn>>
  _databaseColumnsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.databaseColumns,
    aliasName: 'databases__id__database_columns__database_id',
  );

  $$DatabaseColumnsTableProcessedTableManager get databaseColumnsRefs {
    final manager = $$DatabaseColumnsTableTableManager(
      $_db,
      $_db.databaseColumns,
    ).filter((f) => f.databaseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _databaseColumnsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DatabasesTableFilterComposer
    extends Composer<_$AppDatabase, $DatabasesTable> {
  $$DatabasesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentPageId => $composableBuilder(
    column: $table.parentPageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pagesRefs(
    Expression<bool> Function($$PagesTableFilterComposer f) f,
  ) {
    final $$PagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.databaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableFilterComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> databaseColumnsRefs(
    Expression<bool> Function($$DatabaseColumnsTableFilterComposer f) f,
  ) {
    final $$DatabaseColumnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.databaseColumns,
      getReferencedColumn: (t) => t.databaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabaseColumnsTableFilterComposer(
            $db: $db,
            $table: $db.databaseColumns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DatabasesTableOrderingComposer
    extends Composer<_$AppDatabase, $DatabasesTable> {
  $$DatabasesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentPageId => $composableBuilder(
    column: $table.parentPageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatabasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatabasesTable> {
  $$DatabasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get parentPageId => $composableBuilder(
    column: $table.parentPageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get trashedAt =>
      $composableBuilder(column: $table.trashedAt, builder: (column) => column);

  GeneratedColumn<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => column,
  );

  Expression<T> pagesRefs<T extends Object>(
    Expression<T> Function($$PagesTableAnnotationComposer a) f,
  ) {
    final $$PagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.databaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableAnnotationComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> databaseColumnsRefs<T extends Object>(
    Expression<T> Function($$DatabaseColumnsTableAnnotationComposer a) f,
  ) {
    final $$DatabaseColumnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.databaseColumns,
      getReferencedColumn: (t) => t.databaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabaseColumnsTableAnnotationComposer(
            $db: $db,
            $table: $db.databaseColumns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DatabasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DatabasesTable,
          Database,
          $$DatabasesTableFilterComposer,
          $$DatabasesTableOrderingComposer,
          $$DatabasesTableAnnotationComposer,
          $$DatabasesTableCreateCompanionBuilder,
          $$DatabasesTableUpdateCompanionBuilder,
          (Database, $$DatabasesTableReferences),
          Database,
          PrefetchHooks Function({bool pagesRefs, bool databaseColumnsRefs})
        > {
  $$DatabasesTableTableManager(_$AppDatabase db, $DatabasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatabasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatabasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatabasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> parentPageId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<String?> trashBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatabasesCompanion(
                id: id,
                title: title,
                icon: icon,
                parentPageId: parentPageId,
                createdAt: createdAt,
                trashedAt: trashedAt,
                trashBatchId: trashBatchId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> parentPageId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<String?> trashBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatabasesCompanion.insert(
                id: id,
                title: title,
                icon: icon,
                parentPageId: parentPageId,
                createdAt: createdAt,
                trashedAt: trashedAt,
                trashBatchId: trashBatchId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DatabasesTable, Database>(table),
                  $$DatabasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pagesRefs = false, databaseColumnsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pagesRefs) db.pages,
                    if (databaseColumnsRefs) db.databaseColumns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pagesRefs)
                        await $_getPrefetchedDataByColumns<
                          Database,
                          $DatabasesTable,
                          Page,
                          $PagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$DatabasesTableReferences
                              ._pagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DatabasesTableReferences(
                                db,
                                table,
                                p0,
                              ).pagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'database_id',
                          typedResults: items,
                        ),
                      if (databaseColumnsRefs)
                        await $_getPrefetchedDataByColumns<
                          Database,
                          $DatabasesTable,
                          DatabaseColumn,
                          $DatabaseColumnsTable
                        >(
                          currentTable: table,
                          referencedTable: $$DatabasesTableReferences
                              ._databaseColumnsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DatabasesTableReferences(
                                db,
                                table,
                                p0,
                              ).databaseColumnsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'database_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DatabasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DatabasesTable,
      Database,
      $$DatabasesTableFilterComposer,
      $$DatabasesTableOrderingComposer,
      $$DatabasesTableAnnotationComposer,
      $$DatabasesTableCreateCompanionBuilder,
      $$DatabasesTableUpdateCompanionBuilder,
      (Database, $$DatabasesTableReferences),
      Database,
      PrefetchHooks Function({bool pagesRefs, bool databaseColumnsRefs})
    >;
typedef $$PagesTableCreateCompanionBuilder = PagesCompanion Function({
  required String id,
  Value<String> title,
  Value<String?> parentId,
  Value<String?> icon,
  Value<String?> cover,
  Value<String?> orderKey,
  Value<String?> databaseId,
  Value<String?> properties,
  Value<String?> titleFolded,
  Value<String?> propertiesFolded,
  Value<DateTime> createdAt,
  Value<DateTime?> trashedAt,
  Value<String?> trashBatchId,
  Value<int> rowid,
});
typedef $$PagesTableUpdateCompanionBuilder = PagesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> parentId,
  Value<String?> icon,
  Value<String?> cover,
  Value<String?> orderKey,
  Value<String?> databaseId,
  Value<String?> properties,
  Value<String?> titleFolded,
  Value<String?> propertiesFolded,
  Value<DateTime> createdAt,
  Value<DateTime?> trashedAt,
  Value<String?> trashBatchId,
  Value<int> rowid,
});

final class $$PagesTableReferences
    extends BaseReferences<_$AppDatabase, $PagesTable, Page> {
  $$PagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DatabasesTable _databaseIdTable(_$AppDatabase db) =>
      db.databases.createAlias('pages__database_id__databases__id');

  $$DatabasesTableProcessedTableManager? get databaseId {
    final $_column = $_itemColumn<String>('database_id');
    if ($_column == null) return null;
    final manager = $$DatabasesTableTableManager(
      $_db,
      $_db.databases,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_databaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BlocksTable, List<Block>> _blocksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.blocks,
    aliasName: 'pages__id__blocks__page_id',
  );

  $$BlocksTableProcessedTableManager get blocksRefs {
    final manager = $$BlocksTableTableManager(
      $_db,
      $_db.blocks,
    ).filter((f) => f.pageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_blocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PagesTableFilterComposer extends Composer<_$AppDatabase, $PagesTable> {
  $$PagesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderKey => $composableBuilder(
    column: $table.orderKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleFolded => $composableBuilder(
    column: $table.titleFolded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertiesFolded => $composableBuilder(
    column: $table.propertiesFolded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => ColumnFilters(column),
  );

  $$DatabasesTableFilterComposer get databaseId {
    final $$DatabasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.databaseId,
      referencedTable: $db.databases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabasesTableFilterComposer(
            $db: $db,
            $table: $db.databases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> blocksRefs(
    Expression<bool> Function($$BlocksTableFilterComposer f) f,
  ) {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.pageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableFilterComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PagesTableOrderingComposer
    extends Composer<_$AppDatabase, $PagesTable> {
  $$PagesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderKey => $composableBuilder(
    column: $table.orderKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleFolded => $composableBuilder(
    column: $table.titleFolded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertiesFolded => $composableBuilder(
    column: $table.propertiesFolded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => ColumnOrderings(column),
  );

  $$DatabasesTableOrderingComposer get databaseId {
    final $$DatabasesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.databaseId,
      referencedTable: $db.databases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabasesTableOrderingComposer(
            $db: $db,
            $table: $db.databases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PagesTable> {
  $$PagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get orderKey =>
      $composableBuilder(column: $table.orderKey, builder: (column) => column);

  GeneratedColumn<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleFolded => $composableBuilder(
    column: $table.titleFolded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get propertiesFolded => $composableBuilder(
    column: $table.propertiesFolded,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get trashedAt =>
      $composableBuilder(column: $table.trashedAt, builder: (column) => column);

  GeneratedColumn<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => column,
  );

  $$DatabasesTableAnnotationComposer get databaseId {
    final $$DatabasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.databaseId,
      referencedTable: $db.databases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabasesTableAnnotationComposer(
            $db: $db,
            $table: $db.databases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> blocksRefs<T extends Object>(
    Expression<T> Function($$BlocksTableAnnotationComposer a) f,
  ) {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.pageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PagesTable,
          Page,
          $$PagesTableFilterComposer,
          $$PagesTableOrderingComposer,
          $$PagesTableAnnotationComposer,
          $$PagesTableCreateCompanionBuilder,
          $$PagesTableUpdateCompanionBuilder,
          (Page, $$PagesTableReferences),
          Page,
          PrefetchHooks Function({bool databaseId, bool blocksRefs})
        > {
  $$PagesTableTableManager(_$AppDatabase db, $PagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> orderKey = const Value.absent(),
                Value<String?> databaseId = const Value.absent(),
                Value<String?> properties = const Value.absent(),
                Value<String?> titleFolded = const Value.absent(),
                Value<String?> propertiesFolded = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<String?> trashBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PagesCompanion(
                id: id,
                title: title,
                parentId: parentId,
                icon: icon,
                cover: cover,
                orderKey: orderKey,
                databaseId: databaseId,
                properties: properties,
                titleFolded: titleFolded,
                propertiesFolded: propertiesFolded,
                createdAt: createdAt,
                trashedAt: trashedAt,
                trashBatchId: trashBatchId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> orderKey = const Value.absent(),
                Value<String?> databaseId = const Value.absent(),
                Value<String?> properties = const Value.absent(),
                Value<String?> titleFolded = const Value.absent(),
                Value<String?> propertiesFolded = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<String?> trashBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PagesCompanion.insert(
                id: id,
                title: title,
                parentId: parentId,
                icon: icon,
                cover: cover,
                orderKey: orderKey,
                databaseId: databaseId,
                properties: properties,
                titleFolded: titleFolded,
                propertiesFolded: propertiesFolded,
                createdAt: createdAt,
                trashedAt: trashedAt,
                trashBatchId: trashBatchId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PagesTable, Page>(table),
                  $$PagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({databaseId = false, blocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (blocksRefs) db.blocks],
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
                    if (databaseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.databaseId,
                        referencedTable: $$PagesTableReferences
                            ._databaseIdTable(db),
                        referencedColumn: $$PagesTableReferences
                            ._databaseIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (blocksRefs)
                    await $_getPrefetchedDataByColumns<
                      Page,
                      $PagesTable,
                      Block,
                      $BlocksTable
                    >(
                      currentTable: table,
                      referencedTable: $$PagesTableReferences._blocksRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PagesTableReferences(db, table, p0).blocksRefs,
                      currentColumn: 'id',
                      referencedColumn: 'page_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PagesTable,
      Page,
      $$PagesTableFilterComposer,
      $$PagesTableOrderingComposer,
      $$PagesTableAnnotationComposer,
      $$PagesTableCreateCompanionBuilder,
      $$PagesTableUpdateCompanionBuilder,
      (Page, $$PagesTableReferences),
      Page,
      PrefetchHooks Function({bool databaseId, bool blocksRefs})
    >;
typedef $$BlocksTableCreateCompanionBuilder = BlocksCompanion Function({
  required String id,
  required String pageId,
  Value<String?> parentId,
  required String type,
  required String content,
  required String orderKey,
  Value<DateTime?> trashedAt,
  Value<String?> trashBatchId,
  Value<int> rowid,
});
typedef $$BlocksTableUpdateCompanionBuilder = BlocksCompanion Function({
  Value<String> id,
  Value<String> pageId,
  Value<String?> parentId,
  Value<String> type,
  Value<String> content,
  Value<String> orderKey,
  Value<DateTime?> trashedAt,
  Value<String?> trashBatchId,
  Value<int> rowid,
});

final class $$BlocksTableReferences
    extends BaseReferences<_$AppDatabase, $BlocksTable, Block> {
  $$BlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PagesTable _pageIdTable(_$AppDatabase db) =>
      db.pages.createAlias('blocks__page_id__pages__id');

  $$PagesTableProcessedTableManager get pageId {
    final $_column = $_itemColumn<String>('page_id')!;

    final manager = $$PagesTableTableManager(
      $_db,
      $_db.pages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
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

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderKey => $composableBuilder(
    column: $table.orderKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => ColumnFilters(column),
  );

  $$PagesTableFilterComposer get pageId {
    final $$PagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableFilterComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
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

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderKey => $composableBuilder(
    column: $table.orderKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PagesTableOrderingComposer get pageId {
    final $$PagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableOrderingComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get orderKey =>
      $composableBuilder(column: $table.orderKey, builder: (column) => column);

  GeneratedColumn<DateTime> get trashedAt =>
      $composableBuilder(column: $table.trashedAt, builder: (column) => column);

  GeneratedColumn<String> get trashBatchId => $composableBuilder(
    column: $table.trashBatchId,
    builder: (column) => column,
  );

  $$PagesTableAnnotationComposer get pageId {
    final $$PagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableAnnotationComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlocksTable,
          Block,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (Block, $$BlocksTableReferences),
          Block,
          PrefetchHooks Function({bool pageId})
        > {
  $$BlocksTableTableManager(_$AppDatabase db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pageId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> orderKey = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<String?> trashBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion(
                id: id,
                pageId: pageId,
                parentId: parentId,
                type: type,
                content: content,
                orderKey: orderKey,
                trashedAt: trashedAt,
                trashBatchId: trashBatchId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pageId,
                Value<String?> parentId = const Value.absent(),
                required String type,
                required String content,
                required String orderKey,
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<String?> trashBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion.insert(
                id: id,
                pageId: pageId,
                parentId: parentId,
                type: type,
                content: content,
                orderKey: orderKey,
                trashedAt: trashedAt,
                trashBatchId: trashBatchId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlocksTable, Block>(table),
                  $$BlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pageId = false}) {
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
                    if (pageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.pageId,
                        referencedTable: $$BlocksTableReferences._pageIdTable(
                          db,
                        ),
                        referencedColumn: $$BlocksTableReferences
                            ._pageIdTable(db)
                            .id,
                      ) as T;
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

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlocksTable,
      Block,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (Block, $$BlocksTableReferences),
      Block,
      PrefetchHooks Function({bool pageId})
    >;
typedef $$DatabaseColumnsTableCreateCompanionBuilder =
    DatabaseColumnsCompanion Function({
      required String id,
      required String databaseId,
      required String name,
      required String type,
      Value<String?> options,
      Value<double> width,
      required String orderKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DatabaseColumnsTableUpdateCompanionBuilder =
    DatabaseColumnsCompanion Function({
      Value<String> id,
      Value<String> databaseId,
      Value<String> name,
      Value<String> type,
      Value<String?> options,
      Value<double> width,
      Value<String> orderKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$DatabaseColumnsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DatabaseColumnsTable, DatabaseColumn> {
  $$DatabaseColumnsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DatabasesTable _databaseIdTable(_$AppDatabase db) =>
      db.databases.createAlias('database_columns__database_id__databases__id');

  $$DatabasesTableProcessedTableManager get databaseId {
    final $_column = $_itemColumn<String>('database_id')!;

    final manager = $$DatabasesTableTableManager(
      $_db,
      $_db.databases,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_databaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DatabaseColumnsTableFilterComposer
    extends Composer<_$AppDatabase, $DatabaseColumnsTable> {
  $$DatabaseColumnsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderKey => $composableBuilder(
    column: $table.orderKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DatabasesTableFilterComposer get databaseId {
    final $$DatabasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.databaseId,
      referencedTable: $db.databases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabasesTableFilterComposer(
            $db: $db,
            $table: $db.databases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DatabaseColumnsTableOrderingComposer
    extends Composer<_$AppDatabase, $DatabaseColumnsTable> {
  $$DatabaseColumnsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderKey => $composableBuilder(
    column: $table.orderKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DatabasesTableOrderingComposer get databaseId {
    final $$DatabasesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.databaseId,
      referencedTable: $db.databases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabasesTableOrderingComposer(
            $db: $db,
            $table: $db.databases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DatabaseColumnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatabaseColumnsTable> {
  $$DatabaseColumnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get options =>
      $composableBuilder(column: $table.options, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<String> get orderKey =>
      $composableBuilder(column: $table.orderKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DatabasesTableAnnotationComposer get databaseId {
    final $$DatabasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.databaseId,
      referencedTable: $db.databases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DatabasesTableAnnotationComposer(
            $db: $db,
            $table: $db.databases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DatabaseColumnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DatabaseColumnsTable,
          DatabaseColumn,
          $$DatabaseColumnsTableFilterComposer,
          $$DatabaseColumnsTableOrderingComposer,
          $$DatabaseColumnsTableAnnotationComposer,
          $$DatabaseColumnsTableCreateCompanionBuilder,
          $$DatabaseColumnsTableUpdateCompanionBuilder,
          (DatabaseColumn, $$DatabaseColumnsTableReferences),
          DatabaseColumn,
          PrefetchHooks Function({bool databaseId})
        > {
  $$DatabaseColumnsTableTableManager(
    _$AppDatabase db,
    $DatabaseColumnsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatabaseColumnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatabaseColumnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatabaseColumnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> databaseId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> options = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<String> orderKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatabaseColumnsCompanion(
                id: id,
                databaseId: databaseId,
                name: name,
                type: type,
                options: options,
                width: width,
                orderKey: orderKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String databaseId,
                required String name,
                required String type,
                Value<String?> options = const Value.absent(),
                Value<double> width = const Value.absent(),
                required String orderKey,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatabaseColumnsCompanion.insert(
                id: id,
                databaseId: databaseId,
                name: name,
                type: type,
                options: options,
                width: width,
                orderKey: orderKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DatabaseColumnsTable, DatabaseColumn>(table),
                  $$DatabaseColumnsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({databaseId = false}) {
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
                    if (databaseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.databaseId,
                        referencedTable: $$DatabaseColumnsTableReferences
                            ._databaseIdTable(db),
                        referencedColumn: $$DatabaseColumnsTableReferences
                            ._databaseIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DatabaseColumnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DatabaseColumnsTable,
      DatabaseColumn,
      $$DatabaseColumnsTableFilterComposer,
      $$DatabaseColumnsTableOrderingComposer,
      $$DatabaseColumnsTableAnnotationComposer,
      $$DatabaseColumnsTableCreateCompanionBuilder,
      $$DatabaseColumnsTableUpdateCompanionBuilder,
      (DatabaseColumn, $$DatabaseColumnsTableReferences),
      DatabaseColumn,
      PrefetchHooks Function({bool databaseId})
    >;
typedef $$EditorDraftsTableCreateCompanionBuilder =
    EditorDraftsCompanion Function({
      required String id,
      required String pageId,
      required String baseVersion,
      required String content,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EditorDraftsTableUpdateCompanionBuilder =
    EditorDraftsCompanion Function({
      Value<String> id,
      Value<String> pageId,
      Value<String> baseVersion,
      Value<String> content,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$EditorDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $EditorDraftsTable> {
  $$EditorDraftsTableFilterComposer({
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

  ColumnFilters<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EditorDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $EditorDraftsTable> {
  $$EditorDraftsTableOrderingComposer({
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

  ColumnOrderings<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EditorDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EditorDraftsTable> {
  $$EditorDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pageId =>
      $composableBuilder(column: $table.pageId, builder: (column) => column);

  GeneratedColumn<String> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EditorDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EditorDraftsTable,
          EditorDraft,
          $$EditorDraftsTableFilterComposer,
          $$EditorDraftsTableOrderingComposer,
          $$EditorDraftsTableAnnotationComposer,
          $$EditorDraftsTableCreateCompanionBuilder,
          $$EditorDraftsTableUpdateCompanionBuilder,
          (
            EditorDraft,
            BaseReferences<_$AppDatabase, $EditorDraftsTable, EditorDraft>,
          ),
          EditorDraft,
          PrefetchHooks Function()
        > {
  $$EditorDraftsTableTableManager(_$AppDatabase db, $EditorDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EditorDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EditorDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EditorDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pageId = const Value.absent(),
                Value<String> baseVersion = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EditorDraftsCompanion(
                id: id,
                pageId: pageId,
                baseVersion: baseVersion,
                content: content,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pageId,
                required String baseVersion,
                required String content,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EditorDraftsCompanion.insert(
                id: id,
                pageId: pageId,
                baseVersion: baseVersion,
                content: content,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EditorDraftsTable, EditorDraft>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EditorDraftsTable,
                    EditorDraft
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EditorDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EditorDraftsTable,
      EditorDraft,
      $$EditorDraftsTableFilterComposer,
      $$EditorDraftsTableOrderingComposer,
      $$EditorDraftsTableAnnotationComposer,
      $$EditorDraftsTableCreateCompanionBuilder,
      $$EditorDraftsTableUpdateCompanionBuilder,
      (
        EditorDraft,
        BaseReferences<_$AppDatabase, $EditorDraftsTable, EditorDraft>,
      ),
      EditorDraft,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DatabasesTableTableManager get databases =>
      $$DatabasesTableTableManager(_db, _db.databases);
  $$PagesTableTableManager get pages =>
      $$PagesTableTableManager(_db, _db.pages);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$DatabaseColumnsTableTableManager get databaseColumns =>
      $$DatabaseColumnsTableTableManager(_db, _db.databaseColumns);
  $$EditorDraftsTableTableManager get editorDrafts =>
      $$EditorDraftsTableTableManager(_db, _db.editorDrafts);
}

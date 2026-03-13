// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, width, height, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Photo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
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
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class Photo extends DataClass implements Insertable<Photo> {
  final int id;
  final String path;
  final int? width;
  final int? height;
  final DateTime? createdAt;
  const Photo({
    required this.id,
    required this.path,
    this.width,
    this.height,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      path: Value(path),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory Photo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  Photo copyWith({
    int? id,
    String? path,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
  }) => Photo(
    id: id ?? this.id,
    path: path ?? this.path,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, width, height, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.id == this.id &&
          other.path == this.path &&
          other.width == this.width &&
          other.height == this.height &&
          other.createdAt == this.createdAt);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<int> id;
  final Value<String> path;
  final Value<int?> width;
  final Value<int?> height;
  final Value<DateTime?> createdAt;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PhotosCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : path = Value(path);
  static Insertable<Photo> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? width,
    Expression<int>? height,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PhotosCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int?>? width,
    Value<int?>? height,
    Value<DateTime?>? createdAt,
  }) {
    return PhotosCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FacesTable extends Faces with TableInfo<$FacesTable, Face> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photos (id)',
    ),
  );
  static const VerificationMeta _bboxXMeta = const VerificationMeta('bboxX');
  @override
  late final GeneratedColumn<double> bboxX = GeneratedColumn<double>(
    'bbox_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxYMeta = const VerificationMeta('bboxY');
  @override
  late final GeneratedColumn<double> bboxY = GeneratedColumn<double>(
    'bbox_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxWMeta = const VerificationMeta('bboxW');
  @override
  late final GeneratedColumn<double> bboxW = GeneratedColumn<double>(
    'bbox_w',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxHMeta = const VerificationMeta('bboxH');
  @override
  late final GeneratedColumn<double> bboxH = GeneratedColumn<double>(
    'bbox_h',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clusterIdMeta = const VerificationMeta(
    'clusterId',
  );
  @override
  late final GeneratedColumn<int> clusterId = GeneratedColumn<int>(
    'cluster_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    photoId,
    bboxX,
    bboxY,
    bboxW,
    bboxH,
    embedding,
    clusterId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'faces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Face> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('bbox_x')) {
      context.handle(
        _bboxXMeta,
        bboxX.isAcceptableOrUnknown(data['bbox_x']!, _bboxXMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxXMeta);
    }
    if (data.containsKey('bbox_y')) {
      context.handle(
        _bboxYMeta,
        bboxY.isAcceptableOrUnknown(data['bbox_y']!, _bboxYMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxYMeta);
    }
    if (data.containsKey('bbox_w')) {
      context.handle(
        _bboxWMeta,
        bboxW.isAcceptableOrUnknown(data['bbox_w']!, _bboxWMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxWMeta);
    }
    if (data.containsKey('bbox_h')) {
      context.handle(
        _bboxHMeta,
        bboxH.isAcceptableOrUnknown(data['bbox_h']!, _bboxHMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxHMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('cluster_id')) {
      context.handle(
        _clusterIdMeta,
        clusterId.isAcceptableOrUnknown(data['cluster_id']!, _clusterIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Face map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Face(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_id'],
      )!,
      bboxX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_x'],
      )!,
      bboxY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_y'],
      )!,
      bboxW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_w'],
      )!,
      bboxH: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_h'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      clusterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cluster_id'],
      )!,
    );
  }

  @override
  $FacesTable createAlias(String alias) {
    return $FacesTable(attachedDatabase, alias);
  }
}

class Face extends DataClass implements Insertable<Face> {
  final int id;
  final int photoId;
  final double bboxX;
  final double bboxY;
  final double bboxW;
  final double bboxH;
  final Uint8List? embedding;
  final int clusterId;
  const Face({
    required this.id,
    required this.photoId,
    required this.bboxX,
    required this.bboxY,
    required this.bboxW,
    required this.bboxH,
    this.embedding,
    required this.clusterId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['photo_id'] = Variable<int>(photoId);
    map['bbox_x'] = Variable<double>(bboxX);
    map['bbox_y'] = Variable<double>(bboxY);
    map['bbox_w'] = Variable<double>(bboxW);
    map['bbox_h'] = Variable<double>(bboxH);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    map['cluster_id'] = Variable<int>(clusterId);
    return map;
  }

  FacesCompanion toCompanion(bool nullToAbsent) {
    return FacesCompanion(
      id: Value(id),
      photoId: Value(photoId),
      bboxX: Value(bboxX),
      bboxY: Value(bboxY),
      bboxW: Value(bboxW),
      bboxH: Value(bboxH),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      clusterId: Value(clusterId),
    );
  }

  factory Face.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Face(
      id: serializer.fromJson<int>(json['id']),
      photoId: serializer.fromJson<int>(json['photoId']),
      bboxX: serializer.fromJson<double>(json['bboxX']),
      bboxY: serializer.fromJson<double>(json['bboxY']),
      bboxW: serializer.fromJson<double>(json['bboxW']),
      bboxH: serializer.fromJson<double>(json['bboxH']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      clusterId: serializer.fromJson<int>(json['clusterId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'photoId': serializer.toJson<int>(photoId),
      'bboxX': serializer.toJson<double>(bboxX),
      'bboxY': serializer.toJson<double>(bboxY),
      'bboxW': serializer.toJson<double>(bboxW),
      'bboxH': serializer.toJson<double>(bboxH),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'clusterId': serializer.toJson<int>(clusterId),
    };
  }

  Face copyWith({
    int? id,
    int? photoId,
    double? bboxX,
    double? bboxY,
    double? bboxW,
    double? bboxH,
    Value<Uint8List?> embedding = const Value.absent(),
    int? clusterId,
  }) => Face(
    id: id ?? this.id,
    photoId: photoId ?? this.photoId,
    bboxX: bboxX ?? this.bboxX,
    bboxY: bboxY ?? this.bboxY,
    bboxW: bboxW ?? this.bboxW,
    bboxH: bboxH ?? this.bboxH,
    embedding: embedding.present ? embedding.value : this.embedding,
    clusterId: clusterId ?? this.clusterId,
  );
  Face copyWithCompanion(FacesCompanion data) {
    return Face(
      id: data.id.present ? data.id.value : this.id,
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      bboxX: data.bboxX.present ? data.bboxX.value : this.bboxX,
      bboxY: data.bboxY.present ? data.bboxY.value : this.bboxY,
      bboxW: data.bboxW.present ? data.bboxW.value : this.bboxW,
      bboxH: data.bboxH.present ? data.bboxH.value : this.bboxH,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      clusterId: data.clusterId.present ? data.clusterId.value : this.clusterId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Face(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('bboxX: $bboxX, ')
          ..write('bboxY: $bboxY, ')
          ..write('bboxW: $bboxW, ')
          ..write('bboxH: $bboxH, ')
          ..write('embedding: $embedding, ')
          ..write('clusterId: $clusterId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    photoId,
    bboxX,
    bboxY,
    bboxW,
    bboxH,
    $driftBlobEquality.hash(embedding),
    clusterId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Face &&
          other.id == this.id &&
          other.photoId == this.photoId &&
          other.bboxX == this.bboxX &&
          other.bboxY == this.bboxY &&
          other.bboxW == this.bboxW &&
          other.bboxH == this.bboxH &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.clusterId == this.clusterId);
}

class FacesCompanion extends UpdateCompanion<Face> {
  final Value<int> id;
  final Value<int> photoId;
  final Value<double> bboxX;
  final Value<double> bboxY;
  final Value<double> bboxW;
  final Value<double> bboxH;
  final Value<Uint8List?> embedding;
  final Value<int> clusterId;
  const FacesCompanion({
    this.id = const Value.absent(),
    this.photoId = const Value.absent(),
    this.bboxX = const Value.absent(),
    this.bboxY = const Value.absent(),
    this.bboxW = const Value.absent(),
    this.bboxH = const Value.absent(),
    this.embedding = const Value.absent(),
    this.clusterId = const Value.absent(),
  });
  FacesCompanion.insert({
    this.id = const Value.absent(),
    required int photoId,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
    this.embedding = const Value.absent(),
    this.clusterId = const Value.absent(),
  }) : photoId = Value(photoId),
       bboxX = Value(bboxX),
       bboxY = Value(bboxY),
       bboxW = Value(bboxW),
       bboxH = Value(bboxH);
  static Insertable<Face> custom({
    Expression<int>? id,
    Expression<int>? photoId,
    Expression<double>? bboxX,
    Expression<double>? bboxY,
    Expression<double>? bboxW,
    Expression<double>? bboxH,
    Expression<Uint8List>? embedding,
    Expression<int>? clusterId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (photoId != null) 'photo_id': photoId,
      if (bboxX != null) 'bbox_x': bboxX,
      if (bboxY != null) 'bbox_y': bboxY,
      if (bboxW != null) 'bbox_w': bboxW,
      if (bboxH != null) 'bbox_h': bboxH,
      if (embedding != null) 'embedding': embedding,
      if (clusterId != null) 'cluster_id': clusterId,
    });
  }

  FacesCompanion copyWith({
    Value<int>? id,
    Value<int>? photoId,
    Value<double>? bboxX,
    Value<double>? bboxY,
    Value<double>? bboxW,
    Value<double>? bboxH,
    Value<Uint8List?>? embedding,
    Value<int>? clusterId,
  }) {
    return FacesCompanion(
      id: id ?? this.id,
      photoId: photoId ?? this.photoId,
      bboxX: bboxX ?? this.bboxX,
      bboxY: bboxY ?? this.bboxY,
      bboxW: bboxW ?? this.bboxW,
      bboxH: bboxH ?? this.bboxH,
      embedding: embedding ?? this.embedding,
      clusterId: clusterId ?? this.clusterId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (bboxX.present) {
      map['bbox_x'] = Variable<double>(bboxX.value);
    }
    if (bboxY.present) {
      map['bbox_y'] = Variable<double>(bboxY.value);
    }
    if (bboxW.present) {
      map['bbox_w'] = Variable<double>(bboxW.value);
    }
    if (bboxH.present) {
      map['bbox_h'] = Variable<double>(bboxH.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (clusterId.present) {
      map['cluster_id'] = Variable<int>(clusterId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FacesCompanion(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('bboxX: $bboxX, ')
          ..write('bboxY: $bboxY, ')
          ..write('bboxW: $bboxW, ')
          ..write('bboxH: $bboxH, ')
          ..write('embedding: $embedding, ')
          ..write('clusterId: $clusterId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $FacesTable faces = $FacesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [photos, faces];
}

typedef $$PhotosTableCreateCompanionBuilder =
    PhotosCompanion Function({
      Value<int> id,
      required String path,
      Value<int?> width,
      Value<int?> height,
      Value<DateTime?> createdAt,
    });
typedef $$PhotosTableUpdateCompanionBuilder =
    PhotosCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<int?> width,
      Value<int?> height,
      Value<DateTime?> createdAt,
    });

final class $$PhotosTableReferences
    extends BaseReferences<_$AppDatabase, $PhotosTable, Photo> {
  $$PhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FacesTable, List<Face>> _facesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.faces,
    aliasName: $_aliasNameGenerator(db.photos.id, db.faces.photoId),
  );

  $$FacesTableProcessedTableManager get facesRefs {
    final manager = $$FacesTableTableManager(
      $_db,
      $_db.faces,
    ).filter((f) => f.photoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_facesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> facesRefs(
    Expression<bool> Function($$FacesTableFilterComposer f) f,
  ) {
    final $$FacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.faces,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FacesTableFilterComposer(
            $db: $db,
            $table: $db.faces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> facesRefs<T extends Object>(
    Expression<T> Function($$FacesTableAnnotationComposer a) f,
  ) {
    final $$FacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.faces,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FacesTableAnnotationComposer(
            $db: $db,
            $table: $db.faces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosTable,
          Photo,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (Photo, $$PhotosTableReferences),
          Photo,
          PrefetchHooks Function({bool facesRefs})
        > {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
              }) => PhotosCompanion(
                id: id,
                path: path,
                width: width,
                height: height,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
              }) => PhotosCompanion.insert(
                id: id,
                path: path,
                width: width,
                height: height,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PhotosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({facesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (facesRefs) db.faces],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (facesRefs)
                    await $_getPrefetchedData<Photo, $PhotosTable, Face>(
                      currentTable: table,
                      referencedTable: $$PhotosTableReferences._facesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PhotosTableReferences(db, table, p0).facesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.photoId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosTable,
      Photo,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (Photo, $$PhotosTableReferences),
      Photo,
      PrefetchHooks Function({bool facesRefs})
    >;
typedef $$FacesTableCreateCompanionBuilder =
    FacesCompanion Function({
      Value<int> id,
      required int photoId,
      required double bboxX,
      required double bboxY,
      required double bboxW,
      required double bboxH,
      Value<Uint8List?> embedding,
      Value<int> clusterId,
    });
typedef $$FacesTableUpdateCompanionBuilder =
    FacesCompanion Function({
      Value<int> id,
      Value<int> photoId,
      Value<double> bboxX,
      Value<double> bboxY,
      Value<double> bboxW,
      Value<double> bboxH,
      Value<Uint8List?> embedding,
      Value<int> clusterId,
    });

final class $$FacesTableReferences
    extends BaseReferences<_$AppDatabase, $FacesTable, Face> {
  $$FacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PhotosTable _photoIdTable(_$AppDatabase db) => db.photos.createAlias(
    $_aliasNameGenerator(db.faces.photoId, db.photos.id),
  );

  $$PhotosTableProcessedTableManager get photoId {
    final $_column = $_itemColumn<int>('photo_id')!;

    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_photoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FacesTableFilterComposer extends Composer<_$AppDatabase, $FacesTable> {
  $$FacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxX => $composableBuilder(
    column: $table.bboxX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxY => $composableBuilder(
    column: $table.bboxY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxW => $composableBuilder(
    column: $table.bboxW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxH => $composableBuilder(
    column: $table.bboxH,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clusterId => $composableBuilder(
    column: $table.clusterId,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotosTableFilterComposer get photoId {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FacesTableOrderingComposer
    extends Composer<_$AppDatabase, $FacesTable> {
  $$FacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxX => $composableBuilder(
    column: $table.bboxX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxY => $composableBuilder(
    column: $table.bboxY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxW => $composableBuilder(
    column: $table.bboxW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxH => $composableBuilder(
    column: $table.bboxH,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clusterId => $composableBuilder(
    column: $table.clusterId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotosTableOrderingComposer get photoId {
    final $$PhotosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableOrderingComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FacesTable> {
  $$FacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get bboxX =>
      $composableBuilder(column: $table.bboxX, builder: (column) => column);

  GeneratedColumn<double> get bboxY =>
      $composableBuilder(column: $table.bboxY, builder: (column) => column);

  GeneratedColumn<double> get bboxW =>
      $composableBuilder(column: $table.bboxW, builder: (column) => column);

  GeneratedColumn<double> get bboxH =>
      $composableBuilder(column: $table.bboxH, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get clusterId =>
      $composableBuilder(column: $table.clusterId, builder: (column) => column);

  $$PhotosTableAnnotationComposer get photoId {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FacesTable,
          Face,
          $$FacesTableFilterComposer,
          $$FacesTableOrderingComposer,
          $$FacesTableAnnotationComposer,
          $$FacesTableCreateCompanionBuilder,
          $$FacesTableUpdateCompanionBuilder,
          (Face, $$FacesTableReferences),
          Face,
          PrefetchHooks Function({bool photoId})
        > {
  $$FacesTableTableManager(_$AppDatabase db, $FacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> photoId = const Value.absent(),
                Value<double> bboxX = const Value.absent(),
                Value<double> bboxY = const Value.absent(),
                Value<double> bboxW = const Value.absent(),
                Value<double> bboxH = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<int> clusterId = const Value.absent(),
              }) => FacesCompanion(
                id: id,
                photoId: photoId,
                bboxX: bboxX,
                bboxY: bboxY,
                bboxW: bboxW,
                bboxH: bboxH,
                embedding: embedding,
                clusterId: clusterId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int photoId,
                required double bboxX,
                required double bboxY,
                required double bboxW,
                required double bboxH,
                Value<Uint8List?> embedding = const Value.absent(),
                Value<int> clusterId = const Value.absent(),
              }) => FacesCompanion.insert(
                id: id,
                photoId: photoId,
                bboxX: bboxX,
                bboxY: bboxY,
                bboxW: bboxW,
                bboxH: bboxH,
                embedding: embedding,
                clusterId: clusterId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FacesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({photoId = false}) {
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
                    if (photoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.photoId,
                                referencedTable: $$FacesTableReferences
                                    ._photoIdTable(db),
                                referencedColumn: $$FacesTableReferences
                                    ._photoIdTable(db)
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

typedef $$FacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FacesTable,
      Face,
      $$FacesTableFilterComposer,
      $$FacesTableOrderingComposer,
      $$FacesTableAnnotationComposer,
      $$FacesTableCreateCompanionBuilder,
      $$FacesTableUpdateCompanionBuilder,
      (Face, $$FacesTableReferences),
      Face,
      PrefetchHooks Function({bool photoId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$FacesTableTableManager get faces =>
      $$FacesTableTableManager(_db, _db.faces);
}

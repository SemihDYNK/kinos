// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class DatabaseItems extends Table
    with TableInfo<DatabaseItems, DatabaseItemsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DatabaseItems(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> userId =
      GeneratedColumn<String>('user_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<bool> syncing = GeneratedColumn<bool>(
      'syncing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("syncing" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<String> sortName = GeneratedColumn<String>(
      'sort_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> videoFileName = GeneratedColumn<String>(
      'video_file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> trickPlayModel = GeneratedColumn<String>(
      'trick_play_model', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> mediaSegments = GeneratedColumn<String>(
      'media_segments', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
      'images', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> chapters = GeneratedColumn<String>(
      'chapters', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> subtitles = GeneratedColumn<String>(
      'subtitles', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<bool> unSyncedData = GeneratedColumn<bool>(
      'un_synced_data', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("un_synced_data" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<String> userData = GeneratedColumn<String>(
      'user_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        id,
        syncing,
        sortName,
        parentId,
        path,
        fileSize,
        videoFileName,
        trickPlayModel,
        mediaSegments,
        images,
        chapters,
        subtitles,
        unSyncedData,
        userData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'database_items';
  @override
  Set<GeneratedColumn> get $primaryKey => {userId, id};
  @override
  DatabaseItemsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatabaseItemsData(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      syncing: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}syncing'])!,
      sortName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sort_name']),
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path']),
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size']),
      videoFileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_file_name']),
      trickPlayModel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}trick_play_model']),
      mediaSegments: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_segments']),
      images: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}images']),
      chapters: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapters']),
      subtitles: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subtitles']),
      unSyncedData: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}un_synced_data'])!,
      userData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_data']),
    );
  }

  @override
  DatabaseItems createAlias(String alias) {
    return DatabaseItems(attachedDatabase, alias);
  }
}

class DatabaseItemsData extends DataClass
    implements Insertable<DatabaseItemsData> {
  final String userId;
  final String id;
  final bool syncing;
  final String? sortName;
  final String? parentId;
  final String? path;
  final int? fileSize;
  final String? videoFileName;
  final String? trickPlayModel;
  final String? mediaSegments;
  final String? images;
  final String? chapters;
  final String? subtitles;
  final bool unSyncedData;
  final String? userData;
  const DatabaseItemsData(
      {required this.userId,
      required this.id,
      required this.syncing,
      this.sortName,
      this.parentId,
      this.path,
      this.fileSize,
      this.videoFileName,
      this.trickPlayModel,
      this.mediaSegments,
      this.images,
      this.chapters,
      this.subtitles,
      required this.unSyncedData,
      this.userData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['id'] = Variable<String>(id);
    map['syncing'] = Variable<bool>(syncing);
    if (!nullToAbsent || sortName != null) {
      map['sort_name'] = Variable<String>(sortName);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || videoFileName != null) {
      map['video_file_name'] = Variable<String>(videoFileName);
    }
    if (!nullToAbsent || trickPlayModel != null) {
      map['trick_play_model'] = Variable<String>(trickPlayModel);
    }
    if (!nullToAbsent || mediaSegments != null) {
      map['media_segments'] = Variable<String>(mediaSegments);
    }
    if (!nullToAbsent || images != null) {
      map['images'] = Variable<String>(images);
    }
    if (!nullToAbsent || chapters != null) {
      map['chapters'] = Variable<String>(chapters);
    }
    if (!nullToAbsent || subtitles != null) {
      map['subtitles'] = Variable<String>(subtitles);
    }
    map['un_synced_data'] = Variable<bool>(unSyncedData);
    if (!nullToAbsent || userData != null) {
      map['user_data'] = Variable<String>(userData);
    }
    return map;
  }

  DatabaseItemsCompanion toCompanion(bool nullToAbsent) {
    return DatabaseItemsCompanion(
      userId: Value(userId),
      id: Value(id),
      syncing: Value(syncing),
      sortName: sortName == null && nullToAbsent
          ? const Value.absent()
          : Value(sortName),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      videoFileName: videoFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(videoFileName),
      trickPlayModel: trickPlayModel == null && nullToAbsent
          ? const Value.absent()
          : Value(trickPlayModel),
      mediaSegments: mediaSegments == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaSegments),
      images:
          images == null && nullToAbsent ? const Value.absent() : Value(images),
      chapters: chapters == null && nullToAbsent
          ? const Value.absent()
          : Value(chapters),
      subtitles: subtitles == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitles),
      unSyncedData: Value(unSyncedData),
      userData: userData == null && nullToAbsent
          ? const Value.absent()
          : Value(userData),
    );
  }

  factory DatabaseItemsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatabaseItemsData(
      userId: serializer.fromJson<String>(json['userId']),
      id: serializer.fromJson<String>(json['id']),
      syncing: serializer.fromJson<bool>(json['syncing']),
      sortName: serializer.fromJson<String?>(json['sortName']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      path: serializer.fromJson<String?>(json['path']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      videoFileName: serializer.fromJson<String?>(json['videoFileName']),
      trickPlayModel: serializer.fromJson<String?>(json['trickPlayModel']),
      mediaSegments: serializer.fromJson<String?>(json['mediaSegments']),
      images: serializer.fromJson<String?>(json['images']),
      chapters: serializer.fromJson<String?>(json['chapters']),
      subtitles: serializer.fromJson<String?>(json['subtitles']),
      unSyncedData: serializer.fromJson<bool>(json['unSyncedData']),
      userData: serializer.fromJson<String?>(json['userData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'id': serializer.toJson<String>(id),
      'syncing': serializer.toJson<bool>(syncing),
      'sortName': serializer.toJson<String?>(sortName),
      'parentId': serializer.toJson<String?>(parentId),
      'path': serializer.toJson<String?>(path),
      'fileSize': serializer.toJson<int?>(fileSize),
      'videoFileName': serializer.toJson<String?>(videoFileName),
      'trickPlayModel': serializer.toJson<String?>(trickPlayModel),
      'mediaSegments': serializer.toJson<String?>(mediaSegments),
      'images': serializer.toJson<String?>(images),
      'chapters': serializer.toJson<String?>(chapters),
      'subtitles': serializer.toJson<String?>(subtitles),
      'unSyncedData': serializer.toJson<bool>(unSyncedData),
      'userData': serializer.toJson<String?>(userData),
    };
  }

  DatabaseItemsData copyWith(
          {String? userId,
          String? id,
          bool? syncing,
          Value<String?> sortName = const Value.absent(),
          Value<String?> parentId = const Value.absent(),
          Value<String?> path = const Value.absent(),
          Value<int?> fileSize = const Value.absent(),
          Value<String?> videoFileName = const Value.absent(),
          Value<String?> trickPlayModel = const Value.absent(),
          Value<String?> mediaSegments = const Value.absent(),
          Value<String?> images = const Value.absent(),
          Value<String?> chapters = const Value.absent(),
          Value<String?> subtitles = const Value.absent(),
          bool? unSyncedData,
          Value<String?> userData = const Value.absent()}) =>
      DatabaseItemsData(
        userId: userId ?? this.userId,
        id: id ?? this.id,
        syncing: syncing ?? this.syncing,
        sortName: sortName.present ? sortName.value : this.sortName,
        parentId: parentId.present ? parentId.value : this.parentId,
        path: path.present ? path.value : this.path,
        fileSize: fileSize.present ? fileSize.value : this.fileSize,
        videoFileName:
            videoFileName.present ? videoFileName.value : this.videoFileName,
        trickPlayModel:
            trickPlayModel.present ? trickPlayModel.value : this.trickPlayModel,
        mediaSegments:
            mediaSegments.present ? mediaSegments.value : this.mediaSegments,
        images: images.present ? images.value : this.images,
        chapters: chapters.present ? chapters.value : this.chapters,
        subtitles: subtitles.present ? subtitles.value : this.subtitles,
        unSyncedData: unSyncedData ?? this.unSyncedData,
        userData: userData.present ? userData.value : this.userData,
      );
  DatabaseItemsData copyWithCompanion(DatabaseItemsCompanion data) {
    return DatabaseItemsData(
      userId: data.userId.present ? data.userId.value : this.userId,
      id: data.id.present ? data.id.value : this.id,
      syncing: data.syncing.present ? data.syncing.value : this.syncing,
      sortName: data.sortName.present ? data.sortName.value : this.sortName,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      path: data.path.present ? data.path.value : this.path,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      videoFileName: data.videoFileName.present
          ? data.videoFileName.value
          : this.videoFileName,
      trickPlayModel: data.trickPlayModel.present
          ? data.trickPlayModel.value
          : this.trickPlayModel,
      mediaSegments: data.mediaSegments.present
          ? data.mediaSegments.value
          : this.mediaSegments,
      images: data.images.present ? data.images.value : this.images,
      chapters: data.chapters.present ? data.chapters.value : this.chapters,
      subtitles: data.subtitles.present ? data.subtitles.value : this.subtitles,
      unSyncedData: data.unSyncedData.present
          ? data.unSyncedData.value
          : this.unSyncedData,
      userData: data.userData.present ? data.userData.value : this.userData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatabaseItemsData(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('syncing: $syncing, ')
          ..write('sortName: $sortName, ')
          ..write('parentId: $parentId, ')
          ..write('path: $path, ')
          ..write('fileSize: $fileSize, ')
          ..write('videoFileName: $videoFileName, ')
          ..write('trickPlayModel: $trickPlayModel, ')
          ..write('mediaSegments: $mediaSegments, ')
          ..write('images: $images, ')
          ..write('chapters: $chapters, ')
          ..write('subtitles: $subtitles, ')
          ..write('unSyncedData: $unSyncedData, ')
          ..write('userData: $userData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId,
      id,
      syncing,
      sortName,
      parentId,
      path,
      fileSize,
      videoFileName,
      trickPlayModel,
      mediaSegments,
      images,
      chapters,
      subtitles,
      unSyncedData,
      userData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatabaseItemsData &&
          other.userId == this.userId &&
          other.id == this.id &&
          other.syncing == this.syncing &&
          other.sortName == this.sortName &&
          other.parentId == this.parentId &&
          other.path == this.path &&
          other.fileSize == this.fileSize &&
          other.videoFileName == this.videoFileName &&
          other.trickPlayModel == this.trickPlayModel &&
          other.mediaSegments == this.mediaSegments &&
          other.images == this.images &&
          other.chapters == this.chapters &&
          other.subtitles == this.subtitles &&
          other.unSyncedData == this.unSyncedData &&
          other.userData == this.userData);
}

class DatabaseItemsCompanion extends UpdateCompanion<DatabaseItemsData> {
  final Value<String> userId;
  final Value<String> id;
  final Value<bool> syncing;
  final Value<String?> sortName;
  final Value<String?> parentId;
  final Value<String?> path;
  final Value<int?> fileSize;
  final Value<String?> videoFileName;
  final Value<String?> trickPlayModel;
  final Value<String?> mediaSegments;
  final Value<String?> images;
  final Value<String?> chapters;
  final Value<String?> subtitles;
  final Value<bool> unSyncedData;
  final Value<String?> userData;
  final Value<int> rowid;
  const DatabaseItemsCompanion({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    this.syncing = const Value.absent(),
    this.sortName = const Value.absent(),
    this.parentId = const Value.absent(),
    this.path = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.videoFileName = const Value.absent(),
    this.trickPlayModel = const Value.absent(),
    this.mediaSegments = const Value.absent(),
    this.images = const Value.absent(),
    this.chapters = const Value.absent(),
    this.subtitles = const Value.absent(),
    this.unSyncedData = const Value.absent(),
    this.userData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatabaseItemsCompanion.insert({
    required String userId,
    required String id,
    this.syncing = const Value.absent(),
    this.sortName = const Value.absent(),
    this.parentId = const Value.absent(),
    this.path = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.videoFileName = const Value.absent(),
    this.trickPlayModel = const Value.absent(),
    this.mediaSegments = const Value.absent(),
    this.images = const Value.absent(),
    this.chapters = const Value.absent(),
    this.subtitles = const Value.absent(),
    this.unSyncedData = const Value.absent(),
    this.userData = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        id = Value(id);
  static Insertable<DatabaseItemsData> custom({
    Expression<String>? userId,
    Expression<String>? id,
    Expression<bool>? syncing,
    Expression<String>? sortName,
    Expression<String>? parentId,
    Expression<String>? path,
    Expression<int>? fileSize,
    Expression<String>? videoFileName,
    Expression<String>? trickPlayModel,
    Expression<String>? mediaSegments,
    Expression<String>? images,
    Expression<String>? chapters,
    Expression<String>? subtitles,
    Expression<bool>? unSyncedData,
    Expression<String>? userData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (id != null) 'id': id,
      if (syncing != null) 'syncing': syncing,
      if (sortName != null) 'sort_name': sortName,
      if (parentId != null) 'parent_id': parentId,
      if (path != null) 'path': path,
      if (fileSize != null) 'file_size': fileSize,
      if (videoFileName != null) 'video_file_name': videoFileName,
      if (trickPlayModel != null) 'trick_play_model': trickPlayModel,
      if (mediaSegments != null) 'media_segments': mediaSegments,
      if (images != null) 'images': images,
      if (chapters != null) 'chapters': chapters,
      if (subtitles != null) 'subtitles': subtitles,
      if (unSyncedData != null) 'un_synced_data': unSyncedData,
      if (userData != null) 'user_data': userData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatabaseItemsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? id,
      Value<bool>? syncing,
      Value<String?>? sortName,
      Value<String?>? parentId,
      Value<String?>? path,
      Value<int?>? fileSize,
      Value<String?>? videoFileName,
      Value<String?>? trickPlayModel,
      Value<String?>? mediaSegments,
      Value<String?>? images,
      Value<String?>? chapters,
      Value<String?>? subtitles,
      Value<bool>? unSyncedData,
      Value<String?>? userData,
      Value<int>? rowid}) {
    return DatabaseItemsCompanion(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      syncing: syncing ?? this.syncing,
      sortName: sortName ?? this.sortName,
      parentId: parentId ?? this.parentId,
      path: path ?? this.path,
      fileSize: fileSize ?? this.fileSize,
      videoFileName: videoFileName ?? this.videoFileName,
      trickPlayModel: trickPlayModel ?? this.trickPlayModel,
      mediaSegments: mediaSegments ?? this.mediaSegments,
      images: images ?? this.images,
      chapters: chapters ?? this.chapters,
      subtitles: subtitles ?? this.subtitles,
      unSyncedData: unSyncedData ?? this.unSyncedData,
      userData: userData ?? this.userData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (syncing.present) {
      map['syncing'] = Variable<bool>(syncing.value);
    }
    if (sortName.present) {
      map['sort_name'] = Variable<String>(sortName.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (videoFileName.present) {
      map['video_file_name'] = Variable<String>(videoFileName.value);
    }
    if (trickPlayModel.present) {
      map['trick_play_model'] = Variable<String>(trickPlayModel.value);
    }
    if (mediaSegments.present) {
      map['media_segments'] = Variable<String>(mediaSegments.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (chapters.present) {
      map['chapters'] = Variable<String>(chapters.value);
    }
    if (subtitles.present) {
      map['subtitles'] = Variable<String>(subtitles.value);
    }
    if (unSyncedData.present) {
      map['un_synced_data'] = Variable<bool>(unSyncedData.value);
    }
    if (userData.present) {
      map['user_data'] = Variable<String>(userData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatabaseItemsCompanion(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('syncing: $syncing, ')
          ..write('sortName: $sortName, ')
          ..write('parentId: $parentId, ')
          ..write('path: $path, ')
          ..write('fileSize: $fileSize, ')
          ..write('videoFileName: $videoFileName, ')
          ..write('trickPlayModel: $trickPlayModel, ')
          ..write('mediaSegments: $mediaSegments, ')
          ..write('images: $images, ')
          ..write('chapters: $chapters, ')
          ..write('subtitles: $subtitles, ')
          ..write('unSyncedData: $unSyncedData, ')
          ..write('userData: $userData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV1 extends GeneratedDatabase {
  DatabaseAtV1(QueryExecutor e) : super(e);
  late final DatabaseItems databaseItems = DatabaseItems(this);
  late final Index databaseId = Index('database_id',
      'CREATE INDEX database_id ON database_items (user_id, id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [databaseItems, databaseId];
  @override
  int get schemaVersion => 1;
}

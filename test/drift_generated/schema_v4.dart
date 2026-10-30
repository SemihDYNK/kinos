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

class PlaybackQueue extends Table
    with TableInfo<PlaybackQueue, PlaybackQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PlaybackQueue(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> userId =
      GeneratedColumn<String>('user_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<String> itemId =
      GeneratedColumn<String>('item_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> positionTicks = GeneratedColumn<int>(
      'position_ticks', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression(
          'CAST(strftime(\'%s\', CURRENT_TIMESTAMP) AS INTEGER)'));
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        itemId,
        eventType,
        positionTicks,
        createdAt,
        attempts,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_queue';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      positionTicks: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_ticks'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  PlaybackQueue createAlias(String alias) {
    return PlaybackQueue(attachedDatabase, alias);
  }
}

class PlaybackQueueData extends DataClass
    implements Insertable<PlaybackQueueData> {
  final int id;
  final String userId;
  final String itemId;
  final String eventType;
  final int positionTicks;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const PlaybackQueueData(
      {required this.id,
      required this.userId,
      required this.itemId,
      required this.eventType,
      required this.positionTicks,
      required this.createdAt,
      required this.attempts,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['item_id'] = Variable<String>(itemId);
    map['event_type'] = Variable<String>(eventType);
    map['position_ticks'] = Variable<int>(positionTicks);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PlaybackQueueCompanion toCompanion(bool nullToAbsent) {
    return PlaybackQueueCompanion(
      id: Value(id),
      userId: Value(userId),
      itemId: Value(itemId),
      eventType: Value(eventType),
      positionTicks: Value(positionTicks),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PlaybackQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueueData(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      positionTicks: serializer.fromJson<int>(json['positionTicks']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'itemId': serializer.toJson<String>(itemId),
      'eventType': serializer.toJson<String>(eventType),
      'positionTicks': serializer.toJson<int>(positionTicks),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PlaybackQueueData copyWith(
          {int? id,
          String? userId,
          String? itemId,
          String? eventType,
          int? positionTicks,
          DateTime? createdAt,
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      PlaybackQueueData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        itemId: itemId ?? this.itemId,
        eventType: eventType ?? this.eventType,
        positionTicks: positionTicks ?? this.positionTicks,
        createdAt: createdAt ?? this.createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  PlaybackQueueData copyWithCompanion(PlaybackQueueCompanion data) {
    return PlaybackQueueData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      positionTicks: data.positionTicks.present
          ? data.positionTicks.value
          : this.positionTicks,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('eventType: $eventType, ')
          ..write('positionTicks: $positionTicks, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, itemId, eventType, positionTicks,
      createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackQueueData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.itemId == this.itemId &&
          other.eventType == this.eventType &&
          other.positionTicks == this.positionTicks &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PlaybackQueueCompanion extends UpdateCompanion<PlaybackQueueData> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> itemId;
  final Value<String> eventType;
  final Value<int> positionTicks;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PlaybackQueueCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.positionTicks = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PlaybackQueueCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String itemId,
    required String eventType,
    this.positionTicks = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  })  : userId = Value(userId),
        itemId = Value(itemId),
        eventType = Value(eventType);
  static Insertable<PlaybackQueueData> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? itemId,
    Expression<String>? eventType,
    Expression<int>? positionTicks,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (itemId != null) 'item_id': itemId,
      if (eventType != null) 'event_type': eventType,
      if (positionTicks != null) 'position_ticks': positionTicks,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PlaybackQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? itemId,
      Value<String>? eventType,
      Value<int>? positionTicks,
      Value<DateTime>? createdAt,
      Value<int>? attempts,
      Value<String?>? lastError}) {
    return PlaybackQueueCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      eventType: eventType ?? this.eventType,
      positionTicks: positionTicks ?? this.positionTicks,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (positionTicks.present) {
      map['position_ticks'] = Variable<int>(positionTicks.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('eventType: $eventType, ')
          ..write('positionTicks: $positionTicks, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class PaletteCache extends Table
    with TableInfo<PaletteCache, PaletteCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PaletteCache(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> itemId =
      GeneratedColumn<String>('item_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<int> argb = GeneratedColumn<int>(
      'argb', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> extractedAt = GeneratedColumn<DateTime>(
      'extracted_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression(
          'CAST(strftime(\'%s\', CURRENT_TIMESTAMP) AS INTEGER)'));
  @override
  List<GeneratedColumn> get $columns => [itemId, argb, extractedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'palette_cache';
  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  PaletteCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaletteCacheData(
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      argb: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}argb'])!,
      extractedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}extracted_at'])!,
    );
  }

  @override
  PaletteCache createAlias(String alias) {
    return PaletteCache(attachedDatabase, alias);
  }
}

class PaletteCacheData extends DataClass
    implements Insertable<PaletteCacheData> {
  final String itemId;
  final int argb;
  final DateTime extractedAt;
  const PaletteCacheData(
      {required this.itemId, required this.argb, required this.extractedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['argb'] = Variable<int>(argb);
    map['extracted_at'] = Variable<DateTime>(extractedAt);
    return map;
  }

  PaletteCacheCompanion toCompanion(bool nullToAbsent) {
    return PaletteCacheCompanion(
      itemId: Value(itemId),
      argb: Value(argb),
      extractedAt: Value(extractedAt),
    );
  }

  factory PaletteCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaletteCacheData(
      itemId: serializer.fromJson<String>(json['itemId']),
      argb: serializer.fromJson<int>(json['argb']),
      extractedAt: serializer.fromJson<DateTime>(json['extractedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'argb': serializer.toJson<int>(argb),
      'extractedAt': serializer.toJson<DateTime>(extractedAt),
    };
  }

  PaletteCacheData copyWith(
          {String? itemId, int? argb, DateTime? extractedAt}) =>
      PaletteCacheData(
        itemId: itemId ?? this.itemId,
        argb: argb ?? this.argb,
        extractedAt: extractedAt ?? this.extractedAt,
      );
  PaletteCacheData copyWithCompanion(PaletteCacheCompanion data) {
    return PaletteCacheData(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      argb: data.argb.present ? data.argb.value : this.argb,
      extractedAt:
          data.extractedAt.present ? data.extractedAt.value : this.extractedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaletteCacheData(')
          ..write('itemId: $itemId, ')
          ..write('argb: $argb, ')
          ..write('extractedAt: $extractedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, argb, extractedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaletteCacheData &&
          other.itemId == this.itemId &&
          other.argb == this.argb &&
          other.extractedAt == this.extractedAt);
}

class PaletteCacheCompanion extends UpdateCompanion<PaletteCacheData> {
  final Value<String> itemId;
  final Value<int> argb;
  final Value<DateTime> extractedAt;
  final Value<int> rowid;
  const PaletteCacheCompanion({
    this.itemId = const Value.absent(),
    this.argb = const Value.absent(),
    this.extractedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaletteCacheCompanion.insert({
    required String itemId,
    required int argb,
    this.extractedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : itemId = Value(itemId),
        argb = Value(argb);
  static Insertable<PaletteCacheData> custom({
    Expression<String>? itemId,
    Expression<int>? argb,
    Expression<DateTime>? extractedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (argb != null) 'argb': argb,
      if (extractedAt != null) 'extracted_at': extractedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaletteCacheCompanion copyWith(
      {Value<String>? itemId,
      Value<int>? argb,
      Value<DateTime>? extractedAt,
      Value<int>? rowid}) {
    return PaletteCacheCompanion(
      itemId: itemId ?? this.itemId,
      argb: argb ?? this.argb,
      extractedAt: extractedAt ?? this.extractedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (argb.present) {
      map['argb'] = Variable<int>(argb.value);
    }
    if (extractedAt.present) {
      map['extracted_at'] = Variable<DateTime>(extractedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaletteCacheCompanion(')
          ..write('itemId: $itemId, ')
          ..write('argb: $argb, ')
          ..write('extractedAt: $extractedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Settings extends Table with TableInfo<Settings, SettingsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key =
      GeneratedColumn<String>('key', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> scope =
      GeneratedColumn<String>('scope', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, scope];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  Set<GeneratedColumn> get $primaryKey => {key, scope};
  @override
  SettingsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }
}

class SettingsData extends DataClass implements Insertable<SettingsData> {
  final String key;
  final String value;
  final String scope;
  const SettingsData(
      {required this.key, required this.value, required this.scope});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['scope'] = Variable<String>(scope);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      scope: Value(scope),
    );
  }

  factory SettingsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      scope: serializer.fromJson<String>(json['scope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'scope': serializer.toJson<String>(scope),
    };
  }

  SettingsData copyWith({String? key, String? value, String? scope}) =>
      SettingsData(
        key: key ?? this.key,
        value: value ?? this.value,
        scope: scope ?? this.scope,
      );
  SettingsData copyWithCompanion(SettingsCompanion data) {
    return SettingsData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      scope: data.scope.present ? data.scope.value : this.scope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('scope: $scope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, scope);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsData &&
          other.key == this.key &&
          other.value == this.value &&
          other.scope == this.scope);
}

class SettingsCompanion extends UpdateCompanion<SettingsData> {
  final Value<String> key;
  final Value<String> value;
  final Value<String> scope;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.scope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    required String scope,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        scope = Value(scope);
  static Insertable<SettingsData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? scope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (scope != null) 'scope': scope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<String>? scope,
      Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      scope: scope ?? this.scope,
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
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('scope: $scope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RecommendationCacheEntries extends Table
    with TableInfo<RecommendationCacheEntries, RecommendationCacheEntriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RecommendationCacheEntries(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> userId =
      GeneratedColumn<String>('user_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<String> rowKind = GeneratedColumn<String>(
      'row_kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> jellyfinItemId = GeneratedColumn<String>(
      'jellyfin_item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> jellyfinItemType = GeneratedColumn<String>(
      'jellyfin_item_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<int> arrId = GeneratedColumn<int>(
      'arr_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> arrService = GeneratedColumn<String>(
      'arr_service', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> title =
      GeneratedColumn<String>('title', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> justification = GeneratedColumn<String>(
      'justification', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
      'captured_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression(
          'CAST(strftime(\'%s\', CURRENT_TIMESTAMP) AS INTEGER)'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        rowKind,
        position,
        source,
        jellyfinItemId,
        jellyfinItemType,
        arrId,
        arrService,
        title,
        year,
        justification,
        capturedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recommendation_cache_entries';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecommendationCacheEntriesData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecommendationCacheEntriesData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      rowKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}row_kind'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      jellyfinItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}jellyfin_item_id']),
      jellyfinItemType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}jellyfin_item_type']),
      arrId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}arr_id']),
      arrService: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}arr_service']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year']),
      justification: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}justification']),
      capturedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}captured_at'])!,
    );
  }

  @override
  RecommendationCacheEntries createAlias(String alias) {
    return RecommendationCacheEntries(attachedDatabase, alias);
  }
}

class RecommendationCacheEntriesData extends DataClass
    implements Insertable<RecommendationCacheEntriesData> {
  final int id;
  final String userId;
  final String rowKind;
  final int position;
  final String source;
  final String? jellyfinItemId;
  final String? jellyfinItemType;
  final int? arrId;
  final String? arrService;
  final String title;
  final int? year;
  final String? justification;
  final DateTime capturedAt;
  const RecommendationCacheEntriesData(
      {required this.id,
      required this.userId,
      required this.rowKind,
      required this.position,
      required this.source,
      this.jellyfinItemId,
      this.jellyfinItemType,
      this.arrId,
      this.arrService,
      required this.title,
      this.year,
      this.justification,
      required this.capturedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['row_kind'] = Variable<String>(rowKind);
    map['position'] = Variable<int>(position);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || jellyfinItemId != null) {
      map['jellyfin_item_id'] = Variable<String>(jellyfinItemId);
    }
    if (!nullToAbsent || jellyfinItemType != null) {
      map['jellyfin_item_type'] = Variable<String>(jellyfinItemType);
    }
    if (!nullToAbsent || arrId != null) {
      map['arr_id'] = Variable<int>(arrId);
    }
    if (!nullToAbsent || arrService != null) {
      map['arr_service'] = Variable<String>(arrService);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || justification != null) {
      map['justification'] = Variable<String>(justification);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    return map;
  }

  RecommendationCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return RecommendationCacheEntriesCompanion(
      id: Value(id),
      userId: Value(userId),
      rowKind: Value(rowKind),
      position: Value(position),
      source: Value(source),
      jellyfinItemId: jellyfinItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(jellyfinItemId),
      jellyfinItemType: jellyfinItemType == null && nullToAbsent
          ? const Value.absent()
          : Value(jellyfinItemType),
      arrId:
          arrId == null && nullToAbsent ? const Value.absent() : Value(arrId),
      arrService: arrService == null && nullToAbsent
          ? const Value.absent()
          : Value(arrService),
      title: Value(title),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      justification: justification == null && nullToAbsent
          ? const Value.absent()
          : Value(justification),
      capturedAt: Value(capturedAt),
    );
  }

  factory RecommendationCacheEntriesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecommendationCacheEntriesData(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      rowKind: serializer.fromJson<String>(json['rowKind']),
      position: serializer.fromJson<int>(json['position']),
      source: serializer.fromJson<String>(json['source']),
      jellyfinItemId: serializer.fromJson<String?>(json['jellyfinItemId']),
      jellyfinItemType: serializer.fromJson<String?>(json['jellyfinItemType']),
      arrId: serializer.fromJson<int?>(json['arrId']),
      arrService: serializer.fromJson<String?>(json['arrService']),
      title: serializer.fromJson<String>(json['title']),
      year: serializer.fromJson<int?>(json['year']),
      justification: serializer.fromJson<String?>(json['justification']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'rowKind': serializer.toJson<String>(rowKind),
      'position': serializer.toJson<int>(position),
      'source': serializer.toJson<String>(source),
      'jellyfinItemId': serializer.toJson<String?>(jellyfinItemId),
      'jellyfinItemType': serializer.toJson<String?>(jellyfinItemType),
      'arrId': serializer.toJson<int?>(arrId),
      'arrService': serializer.toJson<String?>(arrService),
      'title': serializer.toJson<String>(title),
      'year': serializer.toJson<int?>(year),
      'justification': serializer.toJson<String?>(justification),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
    };
  }

  RecommendationCacheEntriesData copyWith(
          {int? id,
          String? userId,
          String? rowKind,
          int? position,
          String? source,
          Value<String?> jellyfinItemId = const Value.absent(),
          Value<String?> jellyfinItemType = const Value.absent(),
          Value<int?> arrId = const Value.absent(),
          Value<String?> arrService = const Value.absent(),
          String? title,
          Value<int?> year = const Value.absent(),
          Value<String?> justification = const Value.absent(),
          DateTime? capturedAt}) =>
      RecommendationCacheEntriesData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        rowKind: rowKind ?? this.rowKind,
        position: position ?? this.position,
        source: source ?? this.source,
        jellyfinItemId:
            jellyfinItemId.present ? jellyfinItemId.value : this.jellyfinItemId,
        jellyfinItemType: jellyfinItemType.present
            ? jellyfinItemType.value
            : this.jellyfinItemType,
        arrId: arrId.present ? arrId.value : this.arrId,
        arrService: arrService.present ? arrService.value : this.arrService,
        title: title ?? this.title,
        year: year.present ? year.value : this.year,
        justification:
            justification.present ? justification.value : this.justification,
        capturedAt: capturedAt ?? this.capturedAt,
      );
  RecommendationCacheEntriesData copyWithCompanion(
      RecommendationCacheEntriesCompanion data) {
    return RecommendationCacheEntriesData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      rowKind: data.rowKind.present ? data.rowKind.value : this.rowKind,
      position: data.position.present ? data.position.value : this.position,
      source: data.source.present ? data.source.value : this.source,
      jellyfinItemId: data.jellyfinItemId.present
          ? data.jellyfinItemId.value
          : this.jellyfinItemId,
      jellyfinItemType: data.jellyfinItemType.present
          ? data.jellyfinItemType.value
          : this.jellyfinItemType,
      arrId: data.arrId.present ? data.arrId.value : this.arrId,
      arrService:
          data.arrService.present ? data.arrService.value : this.arrService,
      title: data.title.present ? data.title.value : this.title,
      year: data.year.present ? data.year.value : this.year,
      justification: data.justification.present
          ? data.justification.value
          : this.justification,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecommendationCacheEntriesData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowKind: $rowKind, ')
          ..write('position: $position, ')
          ..write('source: $source, ')
          ..write('jellyfinItemId: $jellyfinItemId, ')
          ..write('jellyfinItemType: $jellyfinItemType, ')
          ..write('arrId: $arrId, ')
          ..write('arrService: $arrService, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('justification: $justification, ')
          ..write('capturedAt: $capturedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      userId,
      rowKind,
      position,
      source,
      jellyfinItemId,
      jellyfinItemType,
      arrId,
      arrService,
      title,
      year,
      justification,
      capturedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecommendationCacheEntriesData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.rowKind == this.rowKind &&
          other.position == this.position &&
          other.source == this.source &&
          other.jellyfinItemId == this.jellyfinItemId &&
          other.jellyfinItemType == this.jellyfinItemType &&
          other.arrId == this.arrId &&
          other.arrService == this.arrService &&
          other.title == this.title &&
          other.year == this.year &&
          other.justification == this.justification &&
          other.capturedAt == this.capturedAt);
}

class RecommendationCacheEntriesCompanion
    extends UpdateCompanion<RecommendationCacheEntriesData> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> rowKind;
  final Value<int> position;
  final Value<String> source;
  final Value<String?> jellyfinItemId;
  final Value<String?> jellyfinItemType;
  final Value<int?> arrId;
  final Value<String?> arrService;
  final Value<String> title;
  final Value<int?> year;
  final Value<String?> justification;
  final Value<DateTime> capturedAt;
  const RecommendationCacheEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowKind = const Value.absent(),
    this.position = const Value.absent(),
    this.source = const Value.absent(),
    this.jellyfinItemId = const Value.absent(),
    this.jellyfinItemType = const Value.absent(),
    this.arrId = const Value.absent(),
    this.arrService = const Value.absent(),
    this.title = const Value.absent(),
    this.year = const Value.absent(),
    this.justification = const Value.absent(),
    this.capturedAt = const Value.absent(),
  });
  RecommendationCacheEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String rowKind,
    required int position,
    required String source,
    this.jellyfinItemId = const Value.absent(),
    this.jellyfinItemType = const Value.absent(),
    this.arrId = const Value.absent(),
    this.arrService = const Value.absent(),
    required String title,
    this.year = const Value.absent(),
    this.justification = const Value.absent(),
    this.capturedAt = const Value.absent(),
  })  : userId = Value(userId),
        rowKind = Value(rowKind),
        position = Value(position),
        source = Value(source),
        title = Value(title);
  static Insertable<RecommendationCacheEntriesData> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? rowKind,
    Expression<int>? position,
    Expression<String>? source,
    Expression<String>? jellyfinItemId,
    Expression<String>? jellyfinItemType,
    Expression<int>? arrId,
    Expression<String>? arrService,
    Expression<String>? title,
    Expression<int>? year,
    Expression<String>? justification,
    Expression<DateTime>? capturedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (rowKind != null) 'row_kind': rowKind,
      if (position != null) 'position': position,
      if (source != null) 'source': source,
      if (jellyfinItemId != null) 'jellyfin_item_id': jellyfinItemId,
      if (jellyfinItemType != null) 'jellyfin_item_type': jellyfinItemType,
      if (arrId != null) 'arr_id': arrId,
      if (arrService != null) 'arr_service': arrService,
      if (title != null) 'title': title,
      if (year != null) 'year': year,
      if (justification != null) 'justification': justification,
      if (capturedAt != null) 'captured_at': capturedAt,
    });
  }

  RecommendationCacheEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? rowKind,
      Value<int>? position,
      Value<String>? source,
      Value<String?>? jellyfinItemId,
      Value<String?>? jellyfinItemType,
      Value<int?>? arrId,
      Value<String?>? arrService,
      Value<String>? title,
      Value<int?>? year,
      Value<String?>? justification,
      Value<DateTime>? capturedAt}) {
    return RecommendationCacheEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rowKind: rowKind ?? this.rowKind,
      position: position ?? this.position,
      source: source ?? this.source,
      jellyfinItemId: jellyfinItemId ?? this.jellyfinItemId,
      jellyfinItemType: jellyfinItemType ?? this.jellyfinItemType,
      arrId: arrId ?? this.arrId,
      arrService: arrService ?? this.arrService,
      title: title ?? this.title,
      year: year ?? this.year,
      justification: justification ?? this.justification,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowKind.present) {
      map['row_kind'] = Variable<String>(rowKind.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (jellyfinItemId.present) {
      map['jellyfin_item_id'] = Variable<String>(jellyfinItemId.value);
    }
    if (jellyfinItemType.present) {
      map['jellyfin_item_type'] = Variable<String>(jellyfinItemType.value);
    }
    if (arrId.present) {
      map['arr_id'] = Variable<int>(arrId.value);
    }
    if (arrService.present) {
      map['arr_service'] = Variable<String>(arrService.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (justification.present) {
      map['justification'] = Variable<String>(justification.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecommendationCacheEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowKind: $rowKind, ')
          ..write('position: $position, ')
          ..write('source: $source, ')
          ..write('jellyfinItemId: $jellyfinItemId, ')
          ..write('jellyfinItemType: $jellyfinItemType, ')
          ..write('arrId: $arrId, ')
          ..write('arrService: $arrService, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('justification: $justification, ')
          ..write('capturedAt: $capturedAt')
          ..write(')'))
        .toString();
  }
}

class DiscoveryCacheEntries extends Table
    with TableInfo<DiscoveryCacheEntries, DiscoveryCacheEntriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DiscoveryCacheEntries(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
      'captured_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [scope, cacheKey, payload, capturedAt, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovery_cache_entries';
  @override
  Set<GeneratedColumn> get $primaryKey => {scope, cacheKey};
  @override
  DiscoveryCacheEntriesData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveryCacheEntriesData(
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      capturedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}captured_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
    );
  }

  @override
  DiscoveryCacheEntries createAlias(String alias) {
    return DiscoveryCacheEntries(attachedDatabase, alias);
  }
}

class DiscoveryCacheEntriesData extends DataClass
    implements Insertable<DiscoveryCacheEntriesData> {
  final String scope;
  final String cacheKey;
  final String payload;
  final DateTime capturedAt;
  final DateTime expiresAt;
  const DiscoveryCacheEntriesData(
      {required this.scope,
      required this.cacheKey,
      required this.payload,
      required this.capturedAt,
      required this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  DiscoveryCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return DiscoveryCacheEntriesCompanion(
      scope: Value(scope),
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      capturedAt: Value(capturedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DiscoveryCacheEntriesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveryCacheEntriesData(
      scope: serializer.fromJson<String>(json['scope']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  DiscoveryCacheEntriesData copyWith(
          {String? scope,
          String? cacheKey,
          String? payload,
          DateTime? capturedAt,
          DateTime? expiresAt}) =>
      DiscoveryCacheEntriesData(
        scope: scope ?? this.scope,
        cacheKey: cacheKey ?? this.cacheKey,
        payload: payload ?? this.payload,
        capturedAt: capturedAt ?? this.capturedAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );
  DiscoveryCacheEntriesData copyWithCompanion(
      DiscoveryCacheEntriesCompanion data) {
    return DiscoveryCacheEntriesData(
      scope: data.scope.present ? data.scope.value : this.scope,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryCacheEntriesData(')
          ..write('scope: $scope, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(scope, cacheKey, payload, capturedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryCacheEntriesData &&
          other.scope == this.scope &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.capturedAt == this.capturedAt &&
          other.expiresAt == this.expiresAt);
}

class DiscoveryCacheEntriesCompanion
    extends UpdateCompanion<DiscoveryCacheEntriesData> {
  final Value<String> scope;
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> capturedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const DiscoveryCacheEntriesCompanion({
    this.scope = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscoveryCacheEntriesCompanion.insert({
    required String scope,
    required String cacheKey,
    required String payload,
    required DateTime capturedAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  })  : scope = Value(scope),
        cacheKey = Value(cacheKey),
        payload = Value(payload),
        capturedAt = Value(capturedAt),
        expiresAt = Value(expiresAt);
  static Insertable<DiscoveryCacheEntriesData> custom({
    Expression<String>? scope,
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? capturedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscoveryCacheEntriesCompanion copyWith(
      {Value<String>? scope,
      Value<String>? cacheKey,
      Value<String>? payload,
      Value<DateTime>? capturedAt,
      Value<DateTime>? expiresAt,
      Value<int>? rowid}) {
    return DiscoveryCacheEntriesCompanion(
      scope: scope ?? this.scope,
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      capturedAt: capturedAt ?? this.capturedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryCacheEntriesCompanion(')
          ..write('scope: $scope, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV4 extends GeneratedDatabase {
  DatabaseAtV4(QueryExecutor e) : super(e);
  late final DatabaseItems databaseItems = DatabaseItems(this);
  late final PlaybackQueue playbackQueue = PlaybackQueue(this);
  late final PaletteCache paletteCache = PaletteCache(this);
  late final Settings settings = Settings(this);
  late final RecommendationCacheEntries recommendationCacheEntries =
      RecommendationCacheEntries(this);
  late final DiscoveryCacheEntries discoveryCacheEntries =
      DiscoveryCacheEntries(this);
  late final Index databaseId = Index('database_id',
      'CREATE INDEX database_id ON database_items (user_id, id)');
  late final Index playbackQueueUserItem = Index('playback_queue_user_item',
      'CREATE INDEX playback_queue_user_item ON playback_queue (user_id, item_id)');
  late final Index playbackQueuePending = Index('playback_queue_pending',
      'CREATE INDEX playback_queue_pending ON playback_queue (attempts, created_at)');
  late final Index settingsScope = Index(
      'settings_scope', 'CREATE INDEX settings_scope ON settings (scope)');
  late final Index recommendationCacheUserRow = Index(
      'recommendation_cache_user_row',
      'CREATE INDEX recommendation_cache_user_row ON recommendation_cache_entries (user_id, row_kind, position)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        databaseItems,
        playbackQueue,
        paletteCache,
        settings,
        recommendationCacheEntries,
        discoveryCacheEntries,
        databaseId,
        playbackQueueUserItem,
        playbackQueuePending,
        settingsScope,
        recommendationCacheUserRow
      ];
  @override
  int get schemaVersion => 4;
}

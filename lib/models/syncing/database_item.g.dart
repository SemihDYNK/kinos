// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_item.dart';

// ignore_for_file: type=lint
class $DatabaseItemsTable extends DatabaseItems
    with TableInfo<$DatabaseItemsTable, DatabaseItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatabaseItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId =
      GeneratedColumn<String>('user_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _syncingMeta =
      const VerificationMeta('syncing');
  @override
  late final GeneratedColumn<bool> syncing = GeneratedColumn<bool>(
      'syncing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("syncing" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortNameMeta =
      const VerificationMeta('sortName');
  @override
  late final GeneratedColumn<String> sortName = GeneratedColumn<String>(
      'sort_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _videoFileNameMeta =
      const VerificationMeta('videoFileName');
  @override
  late final GeneratedColumn<String> videoFileName = GeneratedColumn<String>(
      'video_file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trickPlayModelMeta =
      const VerificationMeta('trickPlayModel');
  @override
  late final GeneratedColumn<String> trickPlayModel = GeneratedColumn<String>(
      'trick_play_model', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaSegmentsMeta =
      const VerificationMeta('mediaSegments');
  @override
  late final GeneratedColumn<String> mediaSegments = GeneratedColumn<String>(
      'media_segments', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
      'images', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _chaptersMeta =
      const VerificationMeta('chapters');
  @override
  late final GeneratedColumn<String> chapters = GeneratedColumn<String>(
      'chapters', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subtitlesMeta =
      const VerificationMeta('subtitles');
  @override
  late final GeneratedColumn<String> subtitles = GeneratedColumn<String>(
      'subtitles', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unSyncedDataMeta =
      const VerificationMeta('unSyncedData');
  @override
  late final GeneratedColumn<bool> unSyncedData = GeneratedColumn<bool>(
      'un_synced_data', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("un_synced_data" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _userDataMeta =
      const VerificationMeta('userData');
  @override
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
  VerificationContext validateIntegrity(Insertable<DatabaseItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('syncing')) {
      context.handle(_syncingMeta,
          syncing.isAcceptableOrUnknown(data['syncing']!, _syncingMeta));
    }
    if (data.containsKey('sort_name')) {
      context.handle(_sortNameMeta,
          sortName.isAcceptableOrUnknown(data['sort_name']!, _sortNameMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    }
    if (data.containsKey('video_file_name')) {
      context.handle(
          _videoFileNameMeta,
          videoFileName.isAcceptableOrUnknown(
              data['video_file_name']!, _videoFileNameMeta));
    }
    if (data.containsKey('trick_play_model')) {
      context.handle(
          _trickPlayModelMeta,
          trickPlayModel.isAcceptableOrUnknown(
              data['trick_play_model']!, _trickPlayModelMeta));
    }
    if (data.containsKey('media_segments')) {
      context.handle(
          _mediaSegmentsMeta,
          mediaSegments.isAcceptableOrUnknown(
              data['media_segments']!, _mediaSegmentsMeta));
    }
    if (data.containsKey('images')) {
      context.handle(_imagesMeta,
          images.isAcceptableOrUnknown(data['images']!, _imagesMeta));
    }
    if (data.containsKey('chapters')) {
      context.handle(_chaptersMeta,
          chapters.isAcceptableOrUnknown(data['chapters']!, _chaptersMeta));
    }
    if (data.containsKey('subtitles')) {
      context.handle(_subtitlesMeta,
          subtitles.isAcceptableOrUnknown(data['subtitles']!, _subtitlesMeta));
    }
    if (data.containsKey('un_synced_data')) {
      context.handle(
          _unSyncedDataMeta,
          unSyncedData.isAcceptableOrUnknown(
              data['un_synced_data']!, _unSyncedDataMeta));
    }
    if (data.containsKey('user_data')) {
      context.handle(_userDataMeta,
          userData.isAcceptableOrUnknown(data['user_data']!, _userDataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, id};
  @override
  DatabaseItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatabaseItem(
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
  $DatabaseItemsTable createAlias(String alias) {
    return $DatabaseItemsTable(attachedDatabase, alias);
  }
}

class DatabaseItem extends DataClass implements Insertable<DatabaseItem> {
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
  const DatabaseItem(
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

  factory DatabaseItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatabaseItem(
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

  DatabaseItem copyWith(
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
      DatabaseItem(
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
  DatabaseItem copyWithCompanion(DatabaseItemsCompanion data) {
    return DatabaseItem(
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
    return (StringBuffer('DatabaseItem(')
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
      (other is DatabaseItem &&
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

class DatabaseItemsCompanion extends UpdateCompanion<DatabaseItem> {
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
  static Insertable<DatabaseItem> custom({
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

class $PlaybackQueueTable extends PlaybackQueue
    with TableInfo<$PlaybackQueueTable, PlaybackQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId =
      GeneratedColumn<String>('user_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId =
      GeneratedColumn<String>('item_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<PlaybackQueueEventType, String>
      eventType = GeneratedColumn<String>('event_type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<PlaybackQueueEventType>(
              $PlaybackQueueTable.$convertereventType);
  static const VerificationMeta _positionTicksMeta =
      const VerificationMeta('positionTicks');
  @override
  late final GeneratedColumn<int> positionTicks = GeneratedColumn<int>(
      'position_ticks', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
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
  VerificationContext validateIntegrity(Insertable<PlaybackQueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position_ticks')) {
      context.handle(
          _positionTicksMeta,
          positionTicks.isAcceptableOrUnknown(
              data['position_ticks']!, _positionTicksMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueueEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      eventType: $PlaybackQueueTable.$convertereventType.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}event_type'])!),
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
  $PlaybackQueueTable createAlias(String alias) {
    return $PlaybackQueueTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PlaybackQueueEventType, String, String>
      $convertereventType = const EnumNameConverter<PlaybackQueueEventType>(
          PlaybackQueueEventType.values);
}

class PlaybackQueueEntry extends DataClass
    implements Insertable<PlaybackQueueEntry> {
  final int id;
  final String userId;
  final String itemId;
  final PlaybackQueueEventType eventType;
  final int positionTicks;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const PlaybackQueueEntry(
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
    {
      map['event_type'] = Variable<String>(
          $PlaybackQueueTable.$convertereventType.toSql(eventType));
    }
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

  factory PlaybackQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      eventType: $PlaybackQueueTable.$convertereventType
          .fromJson(serializer.fromJson<String>(json['eventType'])),
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
      'eventType': serializer.toJson<String>(
          $PlaybackQueueTable.$convertereventType.toJson(eventType)),
      'positionTicks': serializer.toJson<int>(positionTicks),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PlaybackQueueEntry copyWith(
          {int? id,
          String? userId,
          String? itemId,
          PlaybackQueueEventType? eventType,
          int? positionTicks,
          DateTime? createdAt,
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      PlaybackQueueEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        itemId: itemId ?? this.itemId,
        eventType: eventType ?? this.eventType,
        positionTicks: positionTicks ?? this.positionTicks,
        createdAt: createdAt ?? this.createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  PlaybackQueueEntry copyWithCompanion(PlaybackQueueCompanion data) {
    return PlaybackQueueEntry(
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
    return (StringBuffer('PlaybackQueueEntry(')
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
      (other is PlaybackQueueEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.itemId == this.itemId &&
          other.eventType == this.eventType &&
          other.positionTicks == this.positionTicks &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PlaybackQueueCompanion extends UpdateCompanion<PlaybackQueueEntry> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> itemId;
  final Value<PlaybackQueueEventType> eventType;
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
    required PlaybackQueueEventType eventType,
    this.positionTicks = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  })  : userId = Value(userId),
        itemId = Value(itemId),
        eventType = Value(eventType);
  static Insertable<PlaybackQueueEntry> custom({
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
      Value<PlaybackQueueEventType>? eventType,
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
      map['event_type'] = Variable<String>(
          $PlaybackQueueTable.$convertereventType.toSql(eventType.value));
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

class $PaletteCacheTable extends PaletteCache
    with TableInfo<$PaletteCacheTable, PaletteCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaletteCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId =
      GeneratedColumn<String>('item_id', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _argbMeta = const VerificationMeta('argb');
  @override
  late final GeneratedColumn<int> argb = GeneratedColumn<int>(
      'argb', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _extractedAtMeta =
      const VerificationMeta('extractedAt');
  @override
  late final GeneratedColumn<DateTime> extractedAt = GeneratedColumn<DateTime>(
      'extracted_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [itemId, argb, extractedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'palette_cache';
  @override
  VerificationContext validateIntegrity(Insertable<PaletteCacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('argb')) {
      context.handle(
          _argbMeta, argb.isAcceptableOrUnknown(data['argb']!, _argbMeta));
    } else if (isInserting) {
      context.missing(_argbMeta);
    }
    if (data.containsKey('extracted_at')) {
      context.handle(
          _extractedAtMeta,
          extractedAt.isAcceptableOrUnknown(
              data['extracted_at']!, _extractedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  PaletteCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaletteCacheEntry(
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      argb: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}argb'])!,
      extractedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}extracted_at'])!,
    );
  }

  @override
  $PaletteCacheTable createAlias(String alias) {
    return $PaletteCacheTable(attachedDatabase, alias);
  }
}

class PaletteCacheEntry extends DataClass
    implements Insertable<PaletteCacheEntry> {
  final String itemId;
  final int argb;
  final DateTime extractedAt;
  const PaletteCacheEntry(
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

  factory PaletteCacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaletteCacheEntry(
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

  PaletteCacheEntry copyWith(
          {String? itemId, int? argb, DateTime? extractedAt}) =>
      PaletteCacheEntry(
        itemId: itemId ?? this.itemId,
        argb: argb ?? this.argb,
        extractedAt: extractedAt ?? this.extractedAt,
      );
  PaletteCacheEntry copyWithCompanion(PaletteCacheCompanion data) {
    return PaletteCacheEntry(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      argb: data.argb.present ? data.argb.value : this.argb,
      extractedAt:
          data.extractedAt.present ? data.extractedAt.value : this.extractedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaletteCacheEntry(')
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
      (other is PaletteCacheEntry &&
          other.itemId == this.itemId &&
          other.argb == this.argb &&
          other.extractedAt == this.extractedAt);
}

class PaletteCacheCompanion extends UpdateCompanion<PaletteCacheEntry> {
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
  static Insertable<PaletteCacheEntry> custom({
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

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key =
      GeneratedColumn<String>('key', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
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
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key, scope};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  final String scope;
  const Setting({required this.key, required this.value, required this.scope});
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

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
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

  Setting copyWith({String? key, String? value, String? scope}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
        scope: scope ?? this.scope,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      scope: data.scope.present ? data.scope.value : this.scope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
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
      (other is Setting &&
          other.key == this.key &&
          other.value == this.value &&
          other.scope == this.scope);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
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
  static Insertable<Setting> custom({
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DatabaseItemsTable databaseItems = $DatabaseItemsTable(this);
  late final $PlaybackQueueTable playbackQueue = $PlaybackQueueTable(this);
  late final $PaletteCacheTable paletteCache = $PaletteCacheTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index databaseId = Index('database_id',
      'CREATE INDEX database_id ON database_items (user_id, id)');
  late final Index playbackQueueUserItem = Index('playback_queue_user_item',
      'CREATE INDEX playback_queue_user_item ON playback_queue (user_id, item_id)');
  late final Index playbackQueuePending = Index('playback_queue_pending',
      'CREATE INDEX playback_queue_pending ON playback_queue (attempts, created_at)');
  late final Index settingsScope = Index(
      'settings_scope', 'CREATE INDEX settings_scope ON settings (scope)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        databaseItems,
        playbackQueue,
        paletteCache,
        settings,
        databaseId,
        playbackQueueUserItem,
        playbackQueuePending,
        settingsScope
      ];
}

typedef $$DatabaseItemsTableCreateCompanionBuilder = DatabaseItemsCompanion
    Function({
  required String userId,
  required String id,
  Value<bool> syncing,
  Value<String?> sortName,
  Value<String?> parentId,
  Value<String?> path,
  Value<int?> fileSize,
  Value<String?> videoFileName,
  Value<String?> trickPlayModel,
  Value<String?> mediaSegments,
  Value<String?> images,
  Value<String?> chapters,
  Value<String?> subtitles,
  Value<bool> unSyncedData,
  Value<String?> userData,
  Value<int> rowid,
});
typedef $$DatabaseItemsTableUpdateCompanionBuilder = DatabaseItemsCompanion
    Function({
  Value<String> userId,
  Value<String> id,
  Value<bool> syncing,
  Value<String?> sortName,
  Value<String?> parentId,
  Value<String?> path,
  Value<int?> fileSize,
  Value<String?> videoFileName,
  Value<String?> trickPlayModel,
  Value<String?> mediaSegments,
  Value<String?> images,
  Value<String?> chapters,
  Value<String?> subtitles,
  Value<bool> unSyncedData,
  Value<String?> userData,
  Value<int> rowid,
});

class $$DatabaseItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DatabaseItemsTable> {
  $$DatabaseItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get syncing => $composableBuilder(
      column: $table.syncing, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sortName => $composableBuilder(
      column: $table.sortName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoFileName => $composableBuilder(
      column: $table.videoFileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trickPlayModel => $composableBuilder(
      column: $table.trickPlayModel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaSegments => $composableBuilder(
      column: $table.mediaSegments, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get images => $composableBuilder(
      column: $table.images, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapters => $composableBuilder(
      column: $table.chapters, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subtitles => $composableBuilder(
      column: $table.subtitles, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get unSyncedData => $composableBuilder(
      column: $table.unSyncedData, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userData => $composableBuilder(
      column: $table.userData, builder: (column) => ColumnFilters(column));
}

class $$DatabaseItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DatabaseItemsTable> {
  $$DatabaseItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get syncing => $composableBuilder(
      column: $table.syncing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sortName => $composableBuilder(
      column: $table.sortName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoFileName => $composableBuilder(
      column: $table.videoFileName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trickPlayModel => $composableBuilder(
      column: $table.trickPlayModel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaSegments => $composableBuilder(
      column: $table.mediaSegments,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get images => $composableBuilder(
      column: $table.images, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapters => $composableBuilder(
      column: $table.chapters, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subtitles => $composableBuilder(
      column: $table.subtitles, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get unSyncedData => $composableBuilder(
      column: $table.unSyncedData,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userData => $composableBuilder(
      column: $table.userData, builder: (column) => ColumnOrderings(column));
}

class $$DatabaseItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatabaseItemsTable> {
  $$DatabaseItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get syncing =>
      $composableBuilder(column: $table.syncing, builder: (column) => column);

  GeneratedColumn<String> get sortName =>
      $composableBuilder(column: $table.sortName, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get videoFileName => $composableBuilder(
      column: $table.videoFileName, builder: (column) => column);

  GeneratedColumn<String> get trickPlayModel => $composableBuilder(
      column: $table.trickPlayModel, builder: (column) => column);

  GeneratedColumn<String> get mediaSegments => $composableBuilder(
      column: $table.mediaSegments, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);

  GeneratedColumn<String> get chapters =>
      $composableBuilder(column: $table.chapters, builder: (column) => column);

  GeneratedColumn<String> get subtitles =>
      $composableBuilder(column: $table.subtitles, builder: (column) => column);

  GeneratedColumn<bool> get unSyncedData => $composableBuilder(
      column: $table.unSyncedData, builder: (column) => column);

  GeneratedColumn<String> get userData =>
      $composableBuilder(column: $table.userData, builder: (column) => column);
}

class $$DatabaseItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DatabaseItemsTable,
    DatabaseItem,
    $$DatabaseItemsTableFilterComposer,
    $$DatabaseItemsTableOrderingComposer,
    $$DatabaseItemsTableAnnotationComposer,
    $$DatabaseItemsTableCreateCompanionBuilder,
    $$DatabaseItemsTableUpdateCompanionBuilder,
    (
      DatabaseItem,
      BaseReferences<_$AppDatabase, $DatabaseItemsTable, DatabaseItem>
    ),
    DatabaseItem,
    PrefetchHooks Function()> {
  $$DatabaseItemsTableTableManager(_$AppDatabase db, $DatabaseItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatabaseItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatabaseItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatabaseItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<bool> syncing = const Value.absent(),
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
            Value<bool> unSyncedData = const Value.absent(),
            Value<String?> userData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DatabaseItemsCompanion(
            userId: userId,
            id: id,
            syncing: syncing,
            sortName: sortName,
            parentId: parentId,
            path: path,
            fileSize: fileSize,
            videoFileName: videoFileName,
            trickPlayModel: trickPlayModel,
            mediaSegments: mediaSegments,
            images: images,
            chapters: chapters,
            subtitles: subtitles,
            unSyncedData: unSyncedData,
            userData: userData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String id,
            Value<bool> syncing = const Value.absent(),
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
            Value<bool> unSyncedData = const Value.absent(),
            Value<String?> userData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DatabaseItemsCompanion.insert(
            userId: userId,
            id: id,
            syncing: syncing,
            sortName: sortName,
            parentId: parentId,
            path: path,
            fileSize: fileSize,
            videoFileName: videoFileName,
            trickPlayModel: trickPlayModel,
            mediaSegments: mediaSegments,
            images: images,
            chapters: chapters,
            subtitles: subtitles,
            unSyncedData: unSyncedData,
            userData: userData,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DatabaseItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DatabaseItemsTable,
    DatabaseItem,
    $$DatabaseItemsTableFilterComposer,
    $$DatabaseItemsTableOrderingComposer,
    $$DatabaseItemsTableAnnotationComposer,
    $$DatabaseItemsTableCreateCompanionBuilder,
    $$DatabaseItemsTableUpdateCompanionBuilder,
    (
      DatabaseItem,
      BaseReferences<_$AppDatabase, $DatabaseItemsTable, DatabaseItem>
    ),
    DatabaseItem,
    PrefetchHooks Function()>;
typedef $$PlaybackQueueTableCreateCompanionBuilder = PlaybackQueueCompanion
    Function({
  Value<int> id,
  required String userId,
  required String itemId,
  required PlaybackQueueEventType eventType,
  Value<int> positionTicks,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});
typedef $$PlaybackQueueTableUpdateCompanionBuilder = PlaybackQueueCompanion
    Function({
  Value<int> id,
  Value<String> userId,
  Value<String> itemId,
  Value<PlaybackQueueEventType> eventType,
  Value<int> positionTicks,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});

class $$PlaybackQueueTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackQueueTable> {
  $$PlaybackQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<PlaybackQueueEventType, PlaybackQueueEventType,
          String>
      get eventType => $composableBuilder(
          column: $table.eventType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get positionTicks => $composableBuilder(
      column: $table.positionTicks, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$PlaybackQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackQueueTable> {
  $$PlaybackQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionTicks => $composableBuilder(
      column: $table.positionTicks,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackQueueTable> {
  $$PlaybackQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlaybackQueueEventType, String>
      get eventType => $composableBuilder(
          column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get positionTicks => $composableBuilder(
      column: $table.positionTicks, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PlaybackQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackQueueTable,
    PlaybackQueueEntry,
    $$PlaybackQueueTableFilterComposer,
    $$PlaybackQueueTableOrderingComposer,
    $$PlaybackQueueTableAnnotationComposer,
    $$PlaybackQueueTableCreateCompanionBuilder,
    $$PlaybackQueueTableUpdateCompanionBuilder,
    (
      PlaybackQueueEntry,
      BaseReferences<_$AppDatabase, $PlaybackQueueTable, PlaybackQueueEntry>
    ),
    PlaybackQueueEntry,
    PrefetchHooks Function()> {
  $$PlaybackQueueTableTableManager(_$AppDatabase db, $PlaybackQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<PlaybackQueueEventType> eventType = const Value.absent(),
            Value<int> positionTicks = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
          }) =>
              PlaybackQueueCompanion(
            id: id,
            userId: userId,
            itemId: itemId,
            eventType: eventType,
            positionTicks: positionTicks,
            createdAt: createdAt,
            attempts: attempts,
            lastError: lastError,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String itemId,
            required PlaybackQueueEventType eventType,
            Value<int> positionTicks = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
          }) =>
              PlaybackQueueCompanion.insert(
            id: id,
            userId: userId,
            itemId: itemId,
            eventType: eventType,
            positionTicks: positionTicks,
            createdAt: createdAt,
            attempts: attempts,
            lastError: lastError,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaybackQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaybackQueueTable,
    PlaybackQueueEntry,
    $$PlaybackQueueTableFilterComposer,
    $$PlaybackQueueTableOrderingComposer,
    $$PlaybackQueueTableAnnotationComposer,
    $$PlaybackQueueTableCreateCompanionBuilder,
    $$PlaybackQueueTableUpdateCompanionBuilder,
    (
      PlaybackQueueEntry,
      BaseReferences<_$AppDatabase, $PlaybackQueueTable, PlaybackQueueEntry>
    ),
    PlaybackQueueEntry,
    PrefetchHooks Function()>;
typedef $$PaletteCacheTableCreateCompanionBuilder = PaletteCacheCompanion
    Function({
  required String itemId,
  required int argb,
  Value<DateTime> extractedAt,
  Value<int> rowid,
});
typedef $$PaletteCacheTableUpdateCompanionBuilder = PaletteCacheCompanion
    Function({
  Value<String> itemId,
  Value<int> argb,
  Value<DateTime> extractedAt,
  Value<int> rowid,
});

class $$PaletteCacheTableFilterComposer
    extends Composer<_$AppDatabase, $PaletteCacheTable> {
  $$PaletteCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get argb => $composableBuilder(
      column: $table.argb, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get extractedAt => $composableBuilder(
      column: $table.extractedAt, builder: (column) => ColumnFilters(column));
}

class $$PaletteCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $PaletteCacheTable> {
  $$PaletteCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get argb => $composableBuilder(
      column: $table.argb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get extractedAt => $composableBuilder(
      column: $table.extractedAt, builder: (column) => ColumnOrderings(column));
}

class $$PaletteCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaletteCacheTable> {
  $$PaletteCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get argb =>
      $composableBuilder(column: $table.argb, builder: (column) => column);

  GeneratedColumn<DateTime> get extractedAt => $composableBuilder(
      column: $table.extractedAt, builder: (column) => column);
}

class $$PaletteCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PaletteCacheTable,
    PaletteCacheEntry,
    $$PaletteCacheTableFilterComposer,
    $$PaletteCacheTableOrderingComposer,
    $$PaletteCacheTableAnnotationComposer,
    $$PaletteCacheTableCreateCompanionBuilder,
    $$PaletteCacheTableUpdateCompanionBuilder,
    (
      PaletteCacheEntry,
      BaseReferences<_$AppDatabase, $PaletteCacheTable, PaletteCacheEntry>
    ),
    PaletteCacheEntry,
    PrefetchHooks Function()> {
  $$PaletteCacheTableTableManager(_$AppDatabase db, $PaletteCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaletteCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaletteCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaletteCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> itemId = const Value.absent(),
            Value<int> argb = const Value.absent(),
            Value<DateTime> extractedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PaletteCacheCompanion(
            itemId: itemId,
            argb: argb,
            extractedAt: extractedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String itemId,
            required int argb,
            Value<DateTime> extractedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PaletteCacheCompanion.insert(
            itemId: itemId,
            argb: argb,
            extractedAt: extractedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PaletteCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PaletteCacheTable,
    PaletteCacheEntry,
    $$PaletteCacheTableFilterComposer,
    $$PaletteCacheTableOrderingComposer,
    $$PaletteCacheTableAnnotationComposer,
    $$PaletteCacheTableCreateCompanionBuilder,
    $$PaletteCacheTableUpdateCompanionBuilder,
    (
      PaletteCacheEntry,
      BaseReferences<_$AppDatabase, $PaletteCacheTable, PaletteCacheEntry>
    ),
    PaletteCacheEntry,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  required String scope,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<String> scope,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<String> scope = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            scope: scope,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required String scope,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            scope: scope,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DatabaseItemsTableTableManager get databaseItems =>
      $$DatabaseItemsTableTableManager(_db, _db.databaseItems);
  $$PlaybackQueueTableTableManager get playbackQueue =>
      $$PlaybackQueueTableTableManager(_db, _db.playbackQueue);
  $$PaletteCacheTableTableManager get paletteCache =>
      $$PaletteCacheTableTableManager(_db, _db.paletteCache);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

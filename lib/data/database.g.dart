// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profilePictureMeta = const VerificationMeta(
    'profilePicture',
  );
  @override
  late final GeneratedColumn<String> profilePicture = GeneratedColumn<String>(
    'profile_picture',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, email, profilePicture];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('profile_picture')) {
      context.handle(
        _profilePictureMeta,
        profilePicture.isAcceptableOrUnknown(
          data['profile_picture']!,
          _profilePictureMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      profilePicture: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_picture'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String name;
  final String email;

  /// A base64 data URI. `image_picker` returns bytes rather than a path on the
  /// web, and the image never leaves the device either way.
  final String? profilePicture;
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicture,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || profilePicture != null) {
      map['profile_picture'] = Variable<String>(profilePicture);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      email: Value(email),
      profilePicture: profilePicture == null && nullToAbsent
          ? const Value.absent()
          : Value(profilePicture),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String>(json['email']),
      profilePicture: serializer.fromJson<String?>(json['profilePicture']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String>(email),
      'profilePicture': serializer.toJson<String?>(profilePicture),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    Value<String?> profilePicture = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    profilePicture: profilePicture.present
        ? profilePicture.value
        : this.profilePicture,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      profilePicture: data.profilePicture.present
          ? data.profilePicture.value
          : this.profilePicture,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('profilePicture: $profilePicture')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, email, profilePicture);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.profilePicture == this.profilePicture);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> email;
  final Value<String?> profilePicture;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.profilePicture = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String email,
    this.profilePicture = const Value.absent(),
  }) : name = Value(name),
       email = Value(email);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? profilePicture,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (profilePicture != null) 'profile_picture': profilePicture,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? email,
    Value<String?>? profilePicture,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (profilePicture.present) {
      map['profile_picture'] = Variable<String>(profilePicture.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('profilePicture: $profilePicture')
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES users(id)',
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
  @override
  List<GeneratedColumn> get $columns => [id, name, userId, createdAt];
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
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final int id;
  final String name;
  final int userId;
  final DateTime createdAt;
  const Trip({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['user_id'] = Variable<int>(userId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      name: Value(name),
      userId: Value(userId),
      createdAt: Value(createdAt),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      userId: serializer.fromJson<int>(json['userId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'userId': serializer.toJson<int>(userId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Trip copyWith({int? id, String? name, int? userId, DateTime? createdAt}) =>
      Trip(
        id: id ?? this.id,
        name: name ?? this.name,
        userId: userId ?? this.userId,
        createdAt: createdAt ?? this.createdAt,
      );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      userId: data.userId.present ? data.userId.value : this.userId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, userId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.name == this.name &&
          other.userId == this.userId &&
          other.createdAt == this.createdAt);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> userId;
  final Value<DateTime> createdAt;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.userId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TripsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int userId,
    required DateTime createdAt,
  }) : name = Value(name),
       userId = Value(userId),
       createdAt = Value(createdAt);
  static Insertable<Trip> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? userId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (userId != null) 'user_id': userId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TripsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? userId,
    Value<DateTime>? createdAt,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SavedPostsTable extends SavedPosts
    with TableInfo<$SavedPostsTable, SavedPost> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedPostsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatorMeta = const VerificationMeta(
    'creator',
  );
  @override
  late final GeneratedColumn<String> creator = GeneratedColumn<String>(
    'creator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalUrlMeta = const VerificationMeta(
    'originalUrl',
  );
  @override
  late final GeneratedColumn<String> originalUrl = GeneratedColumn<String>(
    'original_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importMethodMeta = const VerificationMeta(
    'importMethod',
  );
  @override
  late final GeneratedColumn<String> importMethod = GeneratedColumn<String>(
    'import_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiDestinationMeta = const VerificationMeta(
    'aiDestination',
  );
  @override
  late final GeneratedColumn<String> aiDestination = GeneratedColumn<String>(
    'ai_destination',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiCategoryMeta = const VerificationMeta(
    'aiCategory',
  );
  @override
  late final GeneratedColumn<String> aiCategory = GeneratedColumn<String>(
    'ai_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiSummaryMeta = const VerificationMeta(
    'aiSummary',
  );
  @override
  late final GeneratedColumn<String> aiSummary = GeneratedColumn<String>(
    'ai_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiCountryMeta = const VerificationMeta(
    'aiCountry',
  );
  @override
  late final GeneratedColumn<String> aiCountry = GeneratedColumn<String>(
    'ai_country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiBestTimeMeta = const VerificationMeta(
    'aiBestTime',
  );
  @override
  late final GeneratedColumn<String> aiBestTime = GeneratedColumn<String>(
    'ai_best_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiBudgetNoteMeta = const VerificationMeta(
    'aiBudgetNote',
  );
  @override
  late final GeneratedColumn<String> aiBudgetNote = GeneratedColumn<String>(
    'ai_budget_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL REFERENCES trips(id) ON DELETE SET NULL',
  );
  static const VerificationMeta _personalNoteMeta = const VerificationMeta(
    'personalNote',
  );
  @override
  late final GeneratedColumn<String> personalNote = GeneratedColumn<String>(
    'personal_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateSavedMeta = const VerificationMeta(
    'dateSaved',
  );
  @override
  late final GeneratedColumn<DateTime> dateSaved = GeneratedColumn<DateTime>(
    'date_saved',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastViewedAtMeta = const VerificationMeta(
    'lastViewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastViewedAt = GeneratedColumn<DateTime>(
    'last_viewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteEditedAtMeta = const VerificationMeta(
    'noteEditedAt',
  );
  @override
  late final GeneratedColumn<DateTime> noteEditedAt = GeneratedColumn<DateTime>(
    'note_edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    creator,
    platform,
    originalUrl,
    importMethod,
    thumbnailUrl,
    aiDestination,
    aiCategory,
    aiSummary,
    aiCountry,
    aiBestTime,
    aiBudgetNote,
    tripId,
    personalNote,
    dateSaved,
    lastViewedAt,
    noteEditedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedPost> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('creator')) {
      context.handle(
        _creatorMeta,
        creator.isAcceptableOrUnknown(data['creator']!, _creatorMeta),
      );
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('original_url')) {
      context.handle(
        _originalUrlMeta,
        originalUrl.isAcceptableOrUnknown(
          data['original_url']!,
          _originalUrlMeta,
        ),
      );
    }
    if (data.containsKey('import_method')) {
      context.handle(
        _importMethodMeta,
        importMethod.isAcceptableOrUnknown(
          data['import_method']!,
          _importMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importMethodMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('ai_destination')) {
      context.handle(
        _aiDestinationMeta,
        aiDestination.isAcceptableOrUnknown(
          data['ai_destination']!,
          _aiDestinationMeta,
        ),
      );
    }
    if (data.containsKey('ai_category')) {
      context.handle(
        _aiCategoryMeta,
        aiCategory.isAcceptableOrUnknown(data['ai_category']!, _aiCategoryMeta),
      );
    }
    if (data.containsKey('ai_summary')) {
      context.handle(
        _aiSummaryMeta,
        aiSummary.isAcceptableOrUnknown(data['ai_summary']!, _aiSummaryMeta),
      );
    }
    if (data.containsKey('ai_country')) {
      context.handle(
        _aiCountryMeta,
        aiCountry.isAcceptableOrUnknown(data['ai_country']!, _aiCountryMeta),
      );
    }
    if (data.containsKey('ai_best_time')) {
      context.handle(
        _aiBestTimeMeta,
        aiBestTime.isAcceptableOrUnknown(
          data['ai_best_time']!,
          _aiBestTimeMeta,
        ),
      );
    }
    if (data.containsKey('ai_budget_note')) {
      context.handle(
        _aiBudgetNoteMeta,
        aiBudgetNote.isAcceptableOrUnknown(
          data['ai_budget_note']!,
          _aiBudgetNoteMeta,
        ),
      );
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('personal_note')) {
      context.handle(
        _personalNoteMeta,
        personalNote.isAcceptableOrUnknown(
          data['personal_note']!,
          _personalNoteMeta,
        ),
      );
    }
    if (data.containsKey('date_saved')) {
      context.handle(
        _dateSavedMeta,
        dateSaved.isAcceptableOrUnknown(data['date_saved']!, _dateSavedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateSavedMeta);
    }
    if (data.containsKey('last_viewed_at')) {
      context.handle(
        _lastViewedAtMeta,
        lastViewedAt.isAcceptableOrUnknown(
          data['last_viewed_at']!,
          _lastViewedAtMeta,
        ),
      );
    }
    if (data.containsKey('note_edited_at')) {
      context.handle(
        _noteEditedAtMeta,
        noteEditedAt.isAcceptableOrUnknown(
          data['note_edited_at']!,
          _noteEditedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedPost map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedPost(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      creator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator'],
      ),
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      originalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_url'],
      ),
      importMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_method'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      aiDestination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_destination'],
      ),
      aiCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_category'],
      ),
      aiSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_summary'],
      ),
      aiCountry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_country'],
      ),
      aiBestTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_best_time'],
      ),
      aiBudgetNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_budget_note'],
      ),
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      ),
      personalNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personal_note'],
      ),
      dateSaved: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_saved'],
      )!,
      lastViewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_viewed_at'],
      ),
      noteEditedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}note_edited_at'],
      ),
    );
  }

  @override
  $SavedPostsTable createAlias(String alias) {
    return $SavedPostsTable(attachedDatabase, alias);
  }
}

class SavedPost extends DataClass implements Insertable<SavedPost> {
  final int id;
  final String title;
  final String? creator;

  /// tiktok | instagram | facebook | youtube | other. Parsed from the URL host,
  /// not asked of the model.
  final String platform;

  /// Null when [importMethod] is `note`.
  final String? originalUrl;

  /// link | note
  final String importMethod;
  final String? thumbnailUrl;
  final String? aiDestination;
  final String? aiCategory;
  final String? aiSummary;
  final String? aiCountry;
  final String? aiBestTime;
  final String? aiBudgetNote;
  final int? tripId;
  final String? personalNote;
  final DateTime dateSaved;

  /// Drives the "Recently Viewed" section on Home. See decision 7.
  final DateTime? lastViewedAt;

  /// Drawn as "Last edited …" on the Personal Notes screen. See decision 7.
  final DateTime? noteEditedAt;
  const SavedPost({
    required this.id,
    required this.title,
    this.creator,
    required this.platform,
    this.originalUrl,
    required this.importMethod,
    this.thumbnailUrl,
    this.aiDestination,
    this.aiCategory,
    this.aiSummary,
    this.aiCountry,
    this.aiBestTime,
    this.aiBudgetNote,
    this.tripId,
    this.personalNote,
    required this.dateSaved,
    this.lastViewedAt,
    this.noteEditedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || creator != null) {
      map['creator'] = Variable<String>(creator);
    }
    map['platform'] = Variable<String>(platform);
    if (!nullToAbsent || originalUrl != null) {
      map['original_url'] = Variable<String>(originalUrl);
    }
    map['import_method'] = Variable<String>(importMethod);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || aiDestination != null) {
      map['ai_destination'] = Variable<String>(aiDestination);
    }
    if (!nullToAbsent || aiCategory != null) {
      map['ai_category'] = Variable<String>(aiCategory);
    }
    if (!nullToAbsent || aiSummary != null) {
      map['ai_summary'] = Variable<String>(aiSummary);
    }
    if (!nullToAbsent || aiCountry != null) {
      map['ai_country'] = Variable<String>(aiCountry);
    }
    if (!nullToAbsent || aiBestTime != null) {
      map['ai_best_time'] = Variable<String>(aiBestTime);
    }
    if (!nullToAbsent || aiBudgetNote != null) {
      map['ai_budget_note'] = Variable<String>(aiBudgetNote);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    if (!nullToAbsent || personalNote != null) {
      map['personal_note'] = Variable<String>(personalNote);
    }
    map['date_saved'] = Variable<DateTime>(dateSaved);
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt);
    }
    if (!nullToAbsent || noteEditedAt != null) {
      map['note_edited_at'] = Variable<DateTime>(noteEditedAt);
    }
    return map;
  }

  SavedPostsCompanion toCompanion(bool nullToAbsent) {
    return SavedPostsCompanion(
      id: Value(id),
      title: Value(title),
      creator: creator == null && nullToAbsent
          ? const Value.absent()
          : Value(creator),
      platform: Value(platform),
      originalUrl: originalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(originalUrl),
      importMethod: Value(importMethod),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      aiDestination: aiDestination == null && nullToAbsent
          ? const Value.absent()
          : Value(aiDestination),
      aiCategory: aiCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(aiCategory),
      aiSummary: aiSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(aiSummary),
      aiCountry: aiCountry == null && nullToAbsent
          ? const Value.absent()
          : Value(aiCountry),
      aiBestTime: aiBestTime == null && nullToAbsent
          ? const Value.absent()
          : Value(aiBestTime),
      aiBudgetNote: aiBudgetNote == null && nullToAbsent
          ? const Value.absent()
          : Value(aiBudgetNote),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      personalNote: personalNote == null && nullToAbsent
          ? const Value.absent()
          : Value(personalNote),
      dateSaved: Value(dateSaved),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
      noteEditedAt: noteEditedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(noteEditedAt),
    );
  }

  factory SavedPost.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedPost(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      creator: serializer.fromJson<String?>(json['creator']),
      platform: serializer.fromJson<String>(json['platform']),
      originalUrl: serializer.fromJson<String?>(json['originalUrl']),
      importMethod: serializer.fromJson<String>(json['importMethod']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      aiDestination: serializer.fromJson<String?>(json['aiDestination']),
      aiCategory: serializer.fromJson<String?>(json['aiCategory']),
      aiSummary: serializer.fromJson<String?>(json['aiSummary']),
      aiCountry: serializer.fromJson<String?>(json['aiCountry']),
      aiBestTime: serializer.fromJson<String?>(json['aiBestTime']),
      aiBudgetNote: serializer.fromJson<String?>(json['aiBudgetNote']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      personalNote: serializer.fromJson<String?>(json['personalNote']),
      dateSaved: serializer.fromJson<DateTime>(json['dateSaved']),
      lastViewedAt: serializer.fromJson<DateTime?>(json['lastViewedAt']),
      noteEditedAt: serializer.fromJson<DateTime?>(json['noteEditedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'creator': serializer.toJson<String?>(creator),
      'platform': serializer.toJson<String>(platform),
      'originalUrl': serializer.toJson<String?>(originalUrl),
      'importMethod': serializer.toJson<String>(importMethod),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'aiDestination': serializer.toJson<String?>(aiDestination),
      'aiCategory': serializer.toJson<String?>(aiCategory),
      'aiSummary': serializer.toJson<String?>(aiSummary),
      'aiCountry': serializer.toJson<String?>(aiCountry),
      'aiBestTime': serializer.toJson<String?>(aiBestTime),
      'aiBudgetNote': serializer.toJson<String?>(aiBudgetNote),
      'tripId': serializer.toJson<int?>(tripId),
      'personalNote': serializer.toJson<String?>(personalNote),
      'dateSaved': serializer.toJson<DateTime>(dateSaved),
      'lastViewedAt': serializer.toJson<DateTime?>(lastViewedAt),
      'noteEditedAt': serializer.toJson<DateTime?>(noteEditedAt),
    };
  }

  SavedPost copyWith({
    int? id,
    String? title,
    Value<String?> creator = const Value.absent(),
    String? platform,
    Value<String?> originalUrl = const Value.absent(),
    String? importMethod,
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> aiDestination = const Value.absent(),
    Value<String?> aiCategory = const Value.absent(),
    Value<String?> aiSummary = const Value.absent(),
    Value<String?> aiCountry = const Value.absent(),
    Value<String?> aiBestTime = const Value.absent(),
    Value<String?> aiBudgetNote = const Value.absent(),
    Value<int?> tripId = const Value.absent(),
    Value<String?> personalNote = const Value.absent(),
    DateTime? dateSaved,
    Value<DateTime?> lastViewedAt = const Value.absent(),
    Value<DateTime?> noteEditedAt = const Value.absent(),
  }) => SavedPost(
    id: id ?? this.id,
    title: title ?? this.title,
    creator: creator.present ? creator.value : this.creator,
    platform: platform ?? this.platform,
    originalUrl: originalUrl.present ? originalUrl.value : this.originalUrl,
    importMethod: importMethod ?? this.importMethod,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    aiDestination: aiDestination.present
        ? aiDestination.value
        : this.aiDestination,
    aiCategory: aiCategory.present ? aiCategory.value : this.aiCategory,
    aiSummary: aiSummary.present ? aiSummary.value : this.aiSummary,
    aiCountry: aiCountry.present ? aiCountry.value : this.aiCountry,
    aiBestTime: aiBestTime.present ? aiBestTime.value : this.aiBestTime,
    aiBudgetNote: aiBudgetNote.present ? aiBudgetNote.value : this.aiBudgetNote,
    tripId: tripId.present ? tripId.value : this.tripId,
    personalNote: personalNote.present ? personalNote.value : this.personalNote,
    dateSaved: dateSaved ?? this.dateSaved,
    lastViewedAt: lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
    noteEditedAt: noteEditedAt.present ? noteEditedAt.value : this.noteEditedAt,
  );
  SavedPost copyWithCompanion(SavedPostsCompanion data) {
    return SavedPost(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      creator: data.creator.present ? data.creator.value : this.creator,
      platform: data.platform.present ? data.platform.value : this.platform,
      originalUrl: data.originalUrl.present
          ? data.originalUrl.value
          : this.originalUrl,
      importMethod: data.importMethod.present
          ? data.importMethod.value
          : this.importMethod,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      aiDestination: data.aiDestination.present
          ? data.aiDestination.value
          : this.aiDestination,
      aiCategory: data.aiCategory.present
          ? data.aiCategory.value
          : this.aiCategory,
      aiSummary: data.aiSummary.present ? data.aiSummary.value : this.aiSummary,
      aiCountry: data.aiCountry.present ? data.aiCountry.value : this.aiCountry,
      aiBestTime: data.aiBestTime.present
          ? data.aiBestTime.value
          : this.aiBestTime,
      aiBudgetNote: data.aiBudgetNote.present
          ? data.aiBudgetNote.value
          : this.aiBudgetNote,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      personalNote: data.personalNote.present
          ? data.personalNote.value
          : this.personalNote,
      dateSaved: data.dateSaved.present ? data.dateSaved.value : this.dateSaved,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
      noteEditedAt: data.noteEditedAt.present
          ? data.noteEditedAt.value
          : this.noteEditedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedPost(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('creator: $creator, ')
          ..write('platform: $platform, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('importMethod: $importMethod, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('aiDestination: $aiDestination, ')
          ..write('aiCategory: $aiCategory, ')
          ..write('aiSummary: $aiSummary, ')
          ..write('aiCountry: $aiCountry, ')
          ..write('aiBestTime: $aiBestTime, ')
          ..write('aiBudgetNote: $aiBudgetNote, ')
          ..write('tripId: $tripId, ')
          ..write('personalNote: $personalNote, ')
          ..write('dateSaved: $dateSaved, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('noteEditedAt: $noteEditedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    creator,
    platform,
    originalUrl,
    importMethod,
    thumbnailUrl,
    aiDestination,
    aiCategory,
    aiSummary,
    aiCountry,
    aiBestTime,
    aiBudgetNote,
    tripId,
    personalNote,
    dateSaved,
    lastViewedAt,
    noteEditedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedPost &&
          other.id == this.id &&
          other.title == this.title &&
          other.creator == this.creator &&
          other.platform == this.platform &&
          other.originalUrl == this.originalUrl &&
          other.importMethod == this.importMethod &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.aiDestination == this.aiDestination &&
          other.aiCategory == this.aiCategory &&
          other.aiSummary == this.aiSummary &&
          other.aiCountry == this.aiCountry &&
          other.aiBestTime == this.aiBestTime &&
          other.aiBudgetNote == this.aiBudgetNote &&
          other.tripId == this.tripId &&
          other.personalNote == this.personalNote &&
          other.dateSaved == this.dateSaved &&
          other.lastViewedAt == this.lastViewedAt &&
          other.noteEditedAt == this.noteEditedAt);
}

class SavedPostsCompanion extends UpdateCompanion<SavedPost> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> creator;
  final Value<String> platform;
  final Value<String?> originalUrl;
  final Value<String> importMethod;
  final Value<String?> thumbnailUrl;
  final Value<String?> aiDestination;
  final Value<String?> aiCategory;
  final Value<String?> aiSummary;
  final Value<String?> aiCountry;
  final Value<String?> aiBestTime;
  final Value<String?> aiBudgetNote;
  final Value<int?> tripId;
  final Value<String?> personalNote;
  final Value<DateTime> dateSaved;
  final Value<DateTime?> lastViewedAt;
  final Value<DateTime?> noteEditedAt;
  const SavedPostsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.creator = const Value.absent(),
    this.platform = const Value.absent(),
    this.originalUrl = const Value.absent(),
    this.importMethod = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.aiDestination = const Value.absent(),
    this.aiCategory = const Value.absent(),
    this.aiSummary = const Value.absent(),
    this.aiCountry = const Value.absent(),
    this.aiBestTime = const Value.absent(),
    this.aiBudgetNote = const Value.absent(),
    this.tripId = const Value.absent(),
    this.personalNote = const Value.absent(),
    this.dateSaved = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.noteEditedAt = const Value.absent(),
  });
  SavedPostsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.creator = const Value.absent(),
    required String platform,
    this.originalUrl = const Value.absent(),
    required String importMethod,
    this.thumbnailUrl = const Value.absent(),
    this.aiDestination = const Value.absent(),
    this.aiCategory = const Value.absent(),
    this.aiSummary = const Value.absent(),
    this.aiCountry = const Value.absent(),
    this.aiBestTime = const Value.absent(),
    this.aiBudgetNote = const Value.absent(),
    this.tripId = const Value.absent(),
    this.personalNote = const Value.absent(),
    required DateTime dateSaved,
    this.lastViewedAt = const Value.absent(),
    this.noteEditedAt = const Value.absent(),
  }) : title = Value(title),
       platform = Value(platform),
       importMethod = Value(importMethod),
       dateSaved = Value(dateSaved);
  static Insertable<SavedPost> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? creator,
    Expression<String>? platform,
    Expression<String>? originalUrl,
    Expression<String>? importMethod,
    Expression<String>? thumbnailUrl,
    Expression<String>? aiDestination,
    Expression<String>? aiCategory,
    Expression<String>? aiSummary,
    Expression<String>? aiCountry,
    Expression<String>? aiBestTime,
    Expression<String>? aiBudgetNote,
    Expression<int>? tripId,
    Expression<String>? personalNote,
    Expression<DateTime>? dateSaved,
    Expression<DateTime>? lastViewedAt,
    Expression<DateTime>? noteEditedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (creator != null) 'creator': creator,
      if (platform != null) 'platform': platform,
      if (originalUrl != null) 'original_url': originalUrl,
      if (importMethod != null) 'import_method': importMethod,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (aiDestination != null) 'ai_destination': aiDestination,
      if (aiCategory != null) 'ai_category': aiCategory,
      if (aiSummary != null) 'ai_summary': aiSummary,
      if (aiCountry != null) 'ai_country': aiCountry,
      if (aiBestTime != null) 'ai_best_time': aiBestTime,
      if (aiBudgetNote != null) 'ai_budget_note': aiBudgetNote,
      if (tripId != null) 'trip_id': tripId,
      if (personalNote != null) 'personal_note': personalNote,
      if (dateSaved != null) 'date_saved': dateSaved,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
      if (noteEditedAt != null) 'note_edited_at': noteEditedAt,
    });
  }

  SavedPostsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? creator,
    Value<String>? platform,
    Value<String?>? originalUrl,
    Value<String>? importMethod,
    Value<String?>? thumbnailUrl,
    Value<String?>? aiDestination,
    Value<String?>? aiCategory,
    Value<String?>? aiSummary,
    Value<String?>? aiCountry,
    Value<String?>? aiBestTime,
    Value<String?>? aiBudgetNote,
    Value<int?>? tripId,
    Value<String?>? personalNote,
    Value<DateTime>? dateSaved,
    Value<DateTime?>? lastViewedAt,
    Value<DateTime?>? noteEditedAt,
  }) {
    return SavedPostsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      platform: platform ?? this.platform,
      originalUrl: originalUrl ?? this.originalUrl,
      importMethod: importMethod ?? this.importMethod,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      aiDestination: aiDestination ?? this.aiDestination,
      aiCategory: aiCategory ?? this.aiCategory,
      aiSummary: aiSummary ?? this.aiSummary,
      aiCountry: aiCountry ?? this.aiCountry,
      aiBestTime: aiBestTime ?? this.aiBestTime,
      aiBudgetNote: aiBudgetNote ?? this.aiBudgetNote,
      tripId: tripId ?? this.tripId,
      personalNote: personalNote ?? this.personalNote,
      dateSaved: dateSaved ?? this.dateSaved,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      noteEditedAt: noteEditedAt ?? this.noteEditedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (creator.present) {
      map['creator'] = Variable<String>(creator.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (originalUrl.present) {
      map['original_url'] = Variable<String>(originalUrl.value);
    }
    if (importMethod.present) {
      map['import_method'] = Variable<String>(importMethod.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (aiDestination.present) {
      map['ai_destination'] = Variable<String>(aiDestination.value);
    }
    if (aiCategory.present) {
      map['ai_category'] = Variable<String>(aiCategory.value);
    }
    if (aiSummary.present) {
      map['ai_summary'] = Variable<String>(aiSummary.value);
    }
    if (aiCountry.present) {
      map['ai_country'] = Variable<String>(aiCountry.value);
    }
    if (aiBestTime.present) {
      map['ai_best_time'] = Variable<String>(aiBestTime.value);
    }
    if (aiBudgetNote.present) {
      map['ai_budget_note'] = Variable<String>(aiBudgetNote.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (personalNote.present) {
      map['personal_note'] = Variable<String>(personalNote.value);
    }
    if (dateSaved.present) {
      map['date_saved'] = Variable<DateTime>(dateSaved.value);
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt.value);
    }
    if (noteEditedAt.present) {
      map['note_edited_at'] = Variable<DateTime>(noteEditedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedPostsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('creator: $creator, ')
          ..write('platform: $platform, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('importMethod: $importMethod, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('aiDestination: $aiDestination, ')
          ..write('aiCategory: $aiCategory, ')
          ..write('aiSummary: $aiSummary, ')
          ..write('aiCountry: $aiCountry, ')
          ..write('aiBestTime: $aiBestTime, ')
          ..write('aiBudgetNote: $aiBudgetNote, ')
          ..write('tripId: $tripId, ')
          ..write('personalNote: $personalNote, ')
          ..write('dateSaved: $dateSaved, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('noteEditedAt: $noteEditedAt')
          ..write(')'))
        .toString();
  }
}

class $RecentSearchesTable extends RecentSearches
    with TableInfo<$RecentSearchesTable, RecentSearch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentSearchesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, query, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_searches';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentSearch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentSearch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentSearch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $RecentSearchesTable createAlias(String alias) {
    return $RecentSearchesTable(attachedDatabase, alias);
  }
}

class RecentSearch extends DataClass implements Insertable<RecentSearch> {
  final int id;
  final String query;
  final DateTime searchedAt;
  const RecentSearch({
    required this.id,
    required this.query,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query'] = Variable<String>(query);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  RecentSearchesCompanion toCompanion(bool nullToAbsent) {
    return RecentSearchesCompanion(
      id: Value(id),
      query: Value(query),
      searchedAt: Value(searchedAt),
    );
  }

  factory RecentSearch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentSearch(
      id: serializer.fromJson<int>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'query': serializer.toJson<String>(query),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  RecentSearch copyWith({int? id, String? query, DateTime? searchedAt}) =>
      RecentSearch(
        id: id ?? this.id,
        query: query ?? this.query,
        searchedAt: searchedAt ?? this.searchedAt,
      );
  RecentSearch copyWithCompanion(RecentSearchesCompanion data) {
    return RecentSearch(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearch(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, query, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentSearch &&
          other.id == this.id &&
          other.query == this.query &&
          other.searchedAt == this.searchedAt);
}

class RecentSearchesCompanion extends UpdateCompanion<RecentSearch> {
  final Value<int> id;
  final Value<String> query;
  final Value<DateTime> searchedAt;
  const RecentSearchesCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  RecentSearchesCompanion.insert({
    this.id = const Value.absent(),
    required String query,
    required DateTime searchedAt,
  }) : query = Value(query),
       searchedAt = Value(searchedAt);
  static Insertable<RecentSearch> custom({
    Expression<int>? id,
    Expression<String>? query,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  RecentSearchesCompanion copyWith({
    Value<int>? id,
    Value<String>? query,
    Value<DateTime>? searchedAt,
  }) {
    return RecentSearchesCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearchesCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$NookDatabase extends GeneratedDatabase {
  _$NookDatabase(QueryExecutor e) : super(e);
  $NookDatabaseManager get managers => $NookDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $SavedPostsTable savedPosts = $SavedPostsTable(this);
  late final $RecentSearchesTable recentSearches = $RecentSearchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    trips,
    savedPosts,
    recentSearches,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_posts', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      required String name,
      required String email,
      Value<String?> profilePicture,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> email,
      Value<String?> profilePicture,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$NookDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripsTable, List<Trip>> _tripsRefsTable(
    _$NookDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.trips,
    aliasName: $_aliasNameGenerator(db.users.id, db.trips.userId),
  );

  $$TripsTableProcessedTableManager get tripsRefs {
    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$NookDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilePicture => $composableBuilder(
    column: $table.profilePicture,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripsRefs(
    Expression<bool> Function($$TripsTableFilterComposer f) f,
  ) {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.userId,
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
}

class $$UsersTableOrderingComposer
    extends Composer<_$NookDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilePicture => $composableBuilder(
    column: $table.profilePicture,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$NookDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get profilePicture => $composableBuilder(
    column: $table.profilePicture,
    builder: (column) => column,
  );

  Expression<T> tripsRefs<T extends Object>(
    Expression<T> Function($$TripsTableAnnotationComposer a) f,
  ) {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.userId,
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
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$NookDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({bool tripsRefs})
        > {
  $$UsersTableTableManager(_$NookDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String?> profilePicture = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                email: email,
                profilePicture: profilePicture,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String email,
                Value<String?> profilePicture = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                email: email,
                profilePicture: profilePicture,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tripsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tripsRefs) db.trips],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripsRefs)
                    await $_getPrefetchedData<User, $UsersTable, Trip>(
                      currentTable: table,
                      referencedTable: $$UsersTableReferences._tripsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$UsersTableReferences(db, table, p0).tripsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.userId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$NookDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({bool tripsRefs})
    >;
typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      required String name,
      required int userId,
      required DateTime createdAt,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> userId,
      Value<DateTime> createdAt,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$NookDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$NookDatabase db) =>
      db.users.createAlias($_aliasNameGenerator(db.trips.userId, db.users.id));

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<int>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SavedPostsTable, List<SavedPost>>
  _savedPostsRefsTable(_$NookDatabase db) => MultiTypedResultKey.fromTable(
    db.savedPosts,
    aliasName: $_aliasNameGenerator(db.trips.id, db.savedPosts.tripId),
  );

  $$SavedPostsTableProcessedTableManager get savedPostsRefs {
    final manager = $$SavedPostsTableTableManager(
      $_db,
      $_db.savedPosts,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedPostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$NookDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> savedPostsRefs(
    Expression<bool> Function($$SavedPostsTableFilterComposer f) f,
  ) {
    final $$SavedPostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedPosts,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPostsTableFilterComposer(
            $db: $db,
            $table: $db.savedPosts,
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
    extends Composer<_$NookDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
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
    extends Composer<_$NookDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> savedPostsRefs<T extends Object>(
    Expression<T> Function($$SavedPostsTableAnnotationComposer a) f,
  ) {
    final $$SavedPostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedPosts,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPostsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedPosts,
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
          _$NookDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({bool userId, bool savedPostsRefs})
        > {
  $$TripsTableTableManager(_$NookDatabase db, $TripsTable table)
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
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                name: name,
                userId: userId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int userId,
                required DateTime createdAt,
              }) => TripsCompanion.insert(
                id: id,
                name: name,
                userId: userId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, savedPostsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (savedPostsRefs) db.savedPosts],
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
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$TripsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$TripsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedPostsRefs)
                    await $_getPrefetchedData<Trip, $TripsTable, SavedPost>(
                      currentTable: table,
                      referencedTable: $$TripsTableReferences
                          ._savedPostsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TripsTableReferences(db, table, p0).savedPostsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tripId == item.id),
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
      _$NookDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({bool userId, bool savedPostsRefs})
    >;
typedef $$SavedPostsTableCreateCompanionBuilder =
    SavedPostsCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> creator,
      required String platform,
      Value<String?> originalUrl,
      required String importMethod,
      Value<String?> thumbnailUrl,
      Value<String?> aiDestination,
      Value<String?> aiCategory,
      Value<String?> aiSummary,
      Value<String?> aiCountry,
      Value<String?> aiBestTime,
      Value<String?> aiBudgetNote,
      Value<int?> tripId,
      Value<String?> personalNote,
      required DateTime dateSaved,
      Value<DateTime?> lastViewedAt,
      Value<DateTime?> noteEditedAt,
    });
typedef $$SavedPostsTableUpdateCompanionBuilder =
    SavedPostsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> creator,
      Value<String> platform,
      Value<String?> originalUrl,
      Value<String> importMethod,
      Value<String?> thumbnailUrl,
      Value<String?> aiDestination,
      Value<String?> aiCategory,
      Value<String?> aiSummary,
      Value<String?> aiCountry,
      Value<String?> aiBestTime,
      Value<String?> aiBudgetNote,
      Value<int?> tripId,
      Value<String?> personalNote,
      Value<DateTime> dateSaved,
      Value<DateTime?> lastViewedAt,
      Value<DateTime?> noteEditedAt,
    });

final class $$SavedPostsTableReferences
    extends BaseReferences<_$NookDatabase, $SavedPostsTable, SavedPost> {
  $$SavedPostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$NookDatabase db) => db.trips.createAlias(
    $_aliasNameGenerator(db.savedPosts.tripId, db.trips.id),
  );

  $$TripsTableProcessedTableManager? get tripId {
    final $_column = $_itemColumn<int>('trip_id');
    if ($_column == null) return null;
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

class $$SavedPostsTableFilterComposer
    extends Composer<_$NookDatabase, $SavedPostsTable> {
  $$SavedPostsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creator => $composableBuilder(
    column: $table.creator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importMethod => $composableBuilder(
    column: $table.importMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiDestination => $composableBuilder(
    column: $table.aiDestination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiCategory => $composableBuilder(
    column: $table.aiCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiSummary => $composableBuilder(
    column: $table.aiSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiCountry => $composableBuilder(
    column: $table.aiCountry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiBestTime => $composableBuilder(
    column: $table.aiBestTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiBudgetNote => $composableBuilder(
    column: $table.aiBudgetNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personalNote => $composableBuilder(
    column: $table.personalNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateSaved => $composableBuilder(
    column: $table.dateSaved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get noteEditedAt => $composableBuilder(
    column: $table.noteEditedAt,
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

class $$SavedPostsTableOrderingComposer
    extends Composer<_$NookDatabase, $SavedPostsTable> {
  $$SavedPostsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creator => $composableBuilder(
    column: $table.creator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importMethod => $composableBuilder(
    column: $table.importMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiDestination => $composableBuilder(
    column: $table.aiDestination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiCategory => $composableBuilder(
    column: $table.aiCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiSummary => $composableBuilder(
    column: $table.aiSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiCountry => $composableBuilder(
    column: $table.aiCountry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiBestTime => $composableBuilder(
    column: $table.aiBestTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiBudgetNote => $composableBuilder(
    column: $table.aiBudgetNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personalNote => $composableBuilder(
    column: $table.personalNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateSaved => $composableBuilder(
    column: $table.dateSaved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get noteEditedAt => $composableBuilder(
    column: $table.noteEditedAt,
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

class $$SavedPostsTableAnnotationComposer
    extends Composer<_$NookDatabase, $SavedPostsTable> {
  $$SavedPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get creator =>
      $composableBuilder(column: $table.creator, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importMethod => $composableBuilder(
    column: $table.importMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiDestination => $composableBuilder(
    column: $table.aiDestination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiCategory => $composableBuilder(
    column: $table.aiCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiSummary =>
      $composableBuilder(column: $table.aiSummary, builder: (column) => column);

  GeneratedColumn<String> get aiCountry =>
      $composableBuilder(column: $table.aiCountry, builder: (column) => column);

  GeneratedColumn<String> get aiBestTime => $composableBuilder(
    column: $table.aiBestTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiBudgetNote => $composableBuilder(
    column: $table.aiBudgetNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personalNote => $composableBuilder(
    column: $table.personalNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateSaved =>
      $composableBuilder(column: $table.dateSaved, builder: (column) => column);

  GeneratedColumn<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get noteEditedAt => $composableBuilder(
    column: $table.noteEditedAt,
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

class $$SavedPostsTableTableManager
    extends
        RootTableManager<
          _$NookDatabase,
          $SavedPostsTable,
          SavedPost,
          $$SavedPostsTableFilterComposer,
          $$SavedPostsTableOrderingComposer,
          $$SavedPostsTableAnnotationComposer,
          $$SavedPostsTableCreateCompanionBuilder,
          $$SavedPostsTableUpdateCompanionBuilder,
          (SavedPost, $$SavedPostsTableReferences),
          SavedPost,
          PrefetchHooks Function({bool tripId})
        > {
  $$SavedPostsTableTableManager(_$NookDatabase db, $SavedPostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> creator = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String?> originalUrl = const Value.absent(),
                Value<String> importMethod = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> aiDestination = const Value.absent(),
                Value<String?> aiCategory = const Value.absent(),
                Value<String?> aiSummary = const Value.absent(),
                Value<String?> aiCountry = const Value.absent(),
                Value<String?> aiBestTime = const Value.absent(),
                Value<String?> aiBudgetNote = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<String?> personalNote = const Value.absent(),
                Value<DateTime> dateSaved = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
                Value<DateTime?> noteEditedAt = const Value.absent(),
              }) => SavedPostsCompanion(
                id: id,
                title: title,
                creator: creator,
                platform: platform,
                originalUrl: originalUrl,
                importMethod: importMethod,
                thumbnailUrl: thumbnailUrl,
                aiDestination: aiDestination,
                aiCategory: aiCategory,
                aiSummary: aiSummary,
                aiCountry: aiCountry,
                aiBestTime: aiBestTime,
                aiBudgetNote: aiBudgetNote,
                tripId: tripId,
                personalNote: personalNote,
                dateSaved: dateSaved,
                lastViewedAt: lastViewedAt,
                noteEditedAt: noteEditedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> creator = const Value.absent(),
                required String platform,
                Value<String?> originalUrl = const Value.absent(),
                required String importMethod,
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> aiDestination = const Value.absent(),
                Value<String?> aiCategory = const Value.absent(),
                Value<String?> aiSummary = const Value.absent(),
                Value<String?> aiCountry = const Value.absent(),
                Value<String?> aiBestTime = const Value.absent(),
                Value<String?> aiBudgetNote = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<String?> personalNote = const Value.absent(),
                required DateTime dateSaved,
                Value<DateTime?> lastViewedAt = const Value.absent(),
                Value<DateTime?> noteEditedAt = const Value.absent(),
              }) => SavedPostsCompanion.insert(
                id: id,
                title: title,
                creator: creator,
                platform: platform,
                originalUrl: originalUrl,
                importMethod: importMethod,
                thumbnailUrl: thumbnailUrl,
                aiDestination: aiDestination,
                aiCategory: aiCategory,
                aiSummary: aiSummary,
                aiCountry: aiCountry,
                aiBestTime: aiBestTime,
                aiBudgetNote: aiBudgetNote,
                tripId: tripId,
                personalNote: personalNote,
                dateSaved: dateSaved,
                lastViewedAt: lastViewedAt,
                noteEditedAt: noteEditedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedPostsTableReferences(db, table, e),
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
                                referencedTable: $$SavedPostsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$SavedPostsTableReferences
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

typedef $$SavedPostsTableProcessedTableManager =
    ProcessedTableManager<
      _$NookDatabase,
      $SavedPostsTable,
      SavedPost,
      $$SavedPostsTableFilterComposer,
      $$SavedPostsTableOrderingComposer,
      $$SavedPostsTableAnnotationComposer,
      $$SavedPostsTableCreateCompanionBuilder,
      $$SavedPostsTableUpdateCompanionBuilder,
      (SavedPost, $$SavedPostsTableReferences),
      SavedPost,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$RecentSearchesTableCreateCompanionBuilder =
    RecentSearchesCompanion Function({
      Value<int> id,
      required String query,
      required DateTime searchedAt,
    });
typedef $$RecentSearchesTableUpdateCompanionBuilder =
    RecentSearchesCompanion Function({
      Value<int> id,
      Value<String> query,
      Value<DateTime> searchedAt,
    });

class $$RecentSearchesTableFilterComposer
    extends Composer<_$NookDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableFilterComposer({
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

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentSearchesTableOrderingComposer
    extends Composer<_$NookDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableOrderingComposer({
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

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentSearchesTableAnnotationComposer
    extends Composer<_$NookDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$RecentSearchesTableTableManager
    extends
        RootTableManager<
          _$NookDatabase,
          $RecentSearchesTable,
          RecentSearch,
          $$RecentSearchesTableFilterComposer,
          $$RecentSearchesTableOrderingComposer,
          $$RecentSearchesTableAnnotationComposer,
          $$RecentSearchesTableCreateCompanionBuilder,
          $$RecentSearchesTableUpdateCompanionBuilder,
          (
            RecentSearch,
            BaseReferences<_$NookDatabase, $RecentSearchesTable, RecentSearch>,
          ),
          RecentSearch,
          PrefetchHooks Function()
        > {
  $$RecentSearchesTableTableManager(
    _$NookDatabase db,
    $RecentSearchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentSearchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentSearchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentSearchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => RecentSearchesCompanion(
                id: id,
                query: query,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String query,
                required DateTime searchedAt,
              }) => RecentSearchesCompanion.insert(
                id: id,
                query: query,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentSearchesTableProcessedTableManager =
    ProcessedTableManager<
      _$NookDatabase,
      $RecentSearchesTable,
      RecentSearch,
      $$RecentSearchesTableFilterComposer,
      $$RecentSearchesTableOrderingComposer,
      $$RecentSearchesTableAnnotationComposer,
      $$RecentSearchesTableCreateCompanionBuilder,
      $$RecentSearchesTableUpdateCompanionBuilder,
      (
        RecentSearch,
        BaseReferences<_$NookDatabase, $RecentSearchesTable, RecentSearch>,
      ),
      RecentSearch,
      PrefetchHooks Function()
    >;

class $NookDatabaseManager {
  final _$NookDatabase _db;
  $NookDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$SavedPostsTableTableManager get savedPosts =>
      $$SavedPostsTableTableManager(_db, _db.savedPosts);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(_db, _db.recentSearches);
}

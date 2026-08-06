import 'dart:convert';
import 'dart:typed_data';

import 'package:json_codable/json_codable.dart';

/// Fused converters matching Dart standard library UTF-8 JSON handling.
final Converter<Object?, List<int>> stdJsonEncoder = json.encoder.fuse(
  utf8.encoder,
);

final Converter<List<int>, Object?> stdJsonDecoder = utf8.decoder.fuse(
  json.decoder,
);

/// Auth token response model (~300 B payload).
class AuthResponseModel implements ToJson {
  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.scope,
    required this.userId,
  });

  factory AuthResponseModel.sample() {
    return const AuthResponseModel(
      accessToken:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6'
          'IkFsaWNlIiwiaWF0IjoxNTE2MjM5MDIyfQ.'
          'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c',
      refreshToken: 'd98a2f1b-5e3c-4d2a-8b1c-9f0e1d2c3b4a',
      tokenType: 'Bearer',
      expiresIn: 3600,
      scope: ['read', 'write', 'profile', 'admin'],
      userId: 'usr_987654321',
    );
  }

  factory AuthResponseModel.fromDartMap(Map<String, Object?> map) {
    final scopeList = map['scope'] as List<Object?>?;
    return AuthResponseModel(
      accessToken: map['access_token']! as String,
      refreshToken: map['refresh_token']! as String,
      tokenType: map['token_type']! as String,
      expiresIn: map['expires_in']! as int,
      scope: scopeList?.cast<String>() ?? const [],
      userId: map['user_id']! as String,
    );
  }

  factory AuthResponseModel.fromJsonReader(JsonReader reader) {
    return AuthResponseModel(
      accessToken: reader.readString('access_token') ?? '',
      refreshToken: reader.readString('refresh_token') ?? '',
      tokenType: reader.readString('token_type') ?? '',
      expiresIn: reader.readInt('expires_in') ?? 0,
      scope: reader.readList<String>('scope') ?? const [],
      userId: reader.readString('user_id') ?? '',
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final List<String> scope;
  final String userId;

  Map<String, Object?> toDartMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'scope': scope,
      'user_id': userId,
    };
  }

  @override
  void toJson(JsonWriter writer) {
    writer.string('access_token', accessToken);
    writer.string('refresh_token', refreshToken);
    writer.string('token_type', tokenType);
    writer.integer('expires_in', expiresIn);
    writer.list<String>('scope', scope);
    writer.string('user_id', userId);
  }
}

/// User profile model (~2.5 KB payload).
class UserProfileModel implements ToJson {
  const UserProfileModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.avatarUrl,
    required this.bio,
    required this.isVerified,
    required this.followerCount,
    required this.rating,
    required this.roles,
    required this.preferences,
  });

  factory UserProfileModel.sample() {
    return const UserProfileModel(
      id: 'usr_774920194',
      username: 'salvatore_dev',
      email: 'salvatore.dev@pusk.example.org',
      fullName: 'Salvatore "Code" Master \uD83D\uDE80',
      avatarUrl: 'https://cdn.example.org/avatars/usr_774920194_hd.png',
      bio:
          'Building high performance Dart microservices and tools.\n'
          'Passionate about low-level JSON parsing & benchmark metrics!',
      isVerified: true,
      followerCount: 15420,
      rating: 4.98,
      roles: ['DEVELOPER', 'ADMIN', 'BENCHMARK_HERO', 'CONTRIBUTOR'],
      preferences: {
        'theme': 'dark_emerald',
        'notifications': {
          'email': true,
          'push': false,
          'frequency': 'daily_digest',
        },
        'locale': 'ru_RU',
        'timezone': 'Europe/Moscow',
        'compactView': true,
        'maxItemsPerPage': 50,
      },
    );
  }

  factory UserProfileModel.fromDartMap(Map<String, Object?> map) {
    final rolesList = map['roles'] as List<Object?>?;
    final prefMap = map['preferences'] as Map<Object?, Object?>?;
    final ratingNum = map['rating'] as num?;
    return UserProfileModel(
      id: map['id']! as String,
      username: map['username']! as String,
      email: map['email']! as String,
      fullName: map['full_name']! as String,
      avatarUrl: map['avatar_url']! as String,
      bio: map['bio']! as String,
      isVerified: map['is_verified']! as bool,
      followerCount: map['follower_count']! as int,
      rating: ratingNum?.toDouble() ?? 0.0,
      roles: rolesList?.cast<String>() ?? const [],
      preferences: prefMap?.cast<String, Object?>() ?? const {},
    );
  }

  factory UserProfileModel.fromJsonReader(JsonReader reader) {
    return UserProfileModel(
      id: reader.readString('id') ?? '',
      username: reader.readString('username') ?? '',
      email: reader.readString('email') ?? '',
      fullName: reader.readString('full_name') ?? '',
      avatarUrl: reader.readString('avatar_url') ?? '',
      bio: reader.readString('bio') ?? '',
      isVerified: reader.readBool('is_verified') ?? false,
      followerCount: reader.readInt('follower_count') ?? 0,
      rating: reader.readFloat('rating') ?? 0.0,
      roles: reader.readList<String>('roles') ?? const [],
      preferences: reader.readMap<Object?>('preferences') ?? const {},
    );
  }

  final String id;
  final String username;
  final String email;
  final String fullName;
  final String avatarUrl;
  final String bio;
  final bool isVerified;
  final int followerCount;
  final double rating;
  final List<String> roles;
  final Map<String, Object?> preferences;

  Map<String, Object?> toDartMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_verified': isVerified,
      'follower_count': followerCount,
      'rating': rating,
      'roles': roles,
      'preferences': preferences,
    };
  }

  @override
  void toJson(JsonWriter writer) {
    writer.string('id', id);
    writer.string('username', username);
    writer.string('email', email);
    writer.string('full_name', fullName);
    writer.string('avatar_url', avatarUrl);
    writer.string('bio', bio);
    writer.boolean('is_verified', isVerified);
    writer.integer('follower_count', followerCount);
    writer.float('rating', rating);
    writer.list<String>('roles', roles);
    writer.map<Object?>('preferences', preferences);
  }
}

/// Product item for medium feed (~100 KB payload, 350 items).
class ProductModel implements ToJson {
  const ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rating,
    required this.stock,
    required this.tags,
  });

  factory ProductModel.generate(int index) {
    return ProductModel(
      id: index,
      title: 'High Performance Ultra Product #$index',
      description:
          'This is product description for item #$index with detailed '
          'feature lists and extra text for realistic size.',
      price: 19.99 + (index % 100),
      rating: 4.0 + ((index % 10) / 10.0),
      stock: (index * 7) % 250,
      tags: ['electronics', 'gadget', 'item_$index', 'pusk'],
    );
  }

  factory ProductModel.fromDartMap(Map<String, Object?> map) {
    final tagsList = map['tags'] as List<Object?>?;
    final priceNum = map['price'] as num?;
    final ratingNum = map['rating'] as num?;
    return ProductModel(
      id: map['id']! as int,
      title: map['title']! as String,
      description: map['description']! as String,
      price: priceNum?.toDouble() ?? 0.0,
      rating: ratingNum?.toDouble() ?? 0.0,
      stock: map['stock']! as int,
      tags: tagsList?.cast<String>() ?? const [],
    );
  }

  factory ProductModel.fromJsonReader(JsonReader reader) {
    return ProductModel(
      id: reader.readInt('id') ?? 0,
      title: reader.readString('title') ?? '',
      description: reader.readString('description') ?? '',
      price: reader.readFloat('price') ?? 0.0,
      rating: reader.readFloat('rating') ?? 0.0,
      stock: reader.readInt('stock') ?? 0,
      tags: reader.readList<String>('tags') ?? const [],
    );
  }

  final int id;
  final String title;
  final String description;
  final double price;
  final double rating;
  final int stock;
  final List<String> tags;

  Map<String, Object?> toDartMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'rating': rating,
      'stock': stock,
      'tags': tags,
    };
  }

  @override
  void toJson(JsonWriter writer) {
    writer.integer('id', id);
    writer.string('title', title);
    writer.string('description', description);
    writer.float('price', price);
    writer.float('rating', rating);
    writer.integer('stock', stock);
    writer.list<String>('tags', tags);
  }
}

/// Log event item for 2MB payload dataset (~10,500 items).
class LogEventModel implements ToJson {
  const LogEventModel({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.logger,
    required this.message,
    required this.code,
    required this.processed,
  });

  factory LogEventModel.generate(int index) {
    const levels = ['INFO', 'WARN', 'ERROR', 'DEBUG'];
    final sec = (index % 60).toString().padLeft(2, '0');
    final hash = index.toRadixString(16);
    return LogEventModel(
      id: 100000 + index,
      timestamp: '2026-08-06T12:00:$sec.123Z',
      level: levels[index % levels.length],
      logger: 'com.pusk.services.payment_processor.WorkerPool',
      message:
          'Batch execution event #$index processed successfully with '
          'transaction hash 0x$hash',
      code: 200 + (index % 5),
      processed: index.isEven,
    );
  }

  factory LogEventModel.fromDartMap(Map<String, Object?> map) {
    return LogEventModel(
      id: map['id']! as int,
      timestamp: map['timestamp']! as String,
      level: map['level']! as String,
      logger: map['logger']! as String,
      message: map['message']! as String,
      code: map['code']! as int,
      processed: map['processed']! as bool,
    );
  }

  factory LogEventModel.fromJsonReader(JsonReader reader) {
    return LogEventModel(
      id: reader.readInt('id') ?? 0,
      timestamp: reader.readString('timestamp') ?? '',
      level: reader.readString('level') ?? '',
      logger: reader.readString('logger') ?? '',
      message: reader.readString('message') ?? '',
      code: reader.readInt('code') ?? 0,
      processed: reader.readBool('processed') ?? false,
    );
  }

  final int id;
  final String timestamp;
  final String level;
  final String logger;
  final String message;
  final int code;
  final bool processed;

  Map<String, Object?> toDartMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'level': level,
      'logger': logger,
      'message': message,
      'code': code,
      'processed': processed,
    };
  }

  @override
  void toJson(JsonWriter writer) {
    writer.integer('id', id);
    writer.string('timestamp', timestamp);
    writer.string('level', level);
    writer.string('logger', logger);
    writer.string('message', message);
    writer.integer('code', code);
    writer.boolean('processed', processed);
  }
}

/// Domain sync item for 5MB dataset (~25,000 items).
class SyncItemModel implements ToJson {
  const SyncItemModel({
    required this.uuid,
    required this.sequence,
    required this.title,
    required this.status,
    required this.score,
    required this.metrics,
    required this.active,
  });

  factory SyncItemModel.generate(int index) {
    const statuses = ['PENDING', 'COMPLETED', 'FAILED', 'IN_PROGRESS'];
    return SyncItemModel(
      uuid: 'e4f019a-$index-4b72-9c1a-8294029b3c',
      sequence: index,
      title: 'Database Sync Entity Record #$index for PUSK Ecosystem',
      status: statuses[index % statuses.length],
      score: 99.5 - (index % 50),
      metrics: [index, index * 2, index * 3, index * 4],
      active: true,
    );
  }

  factory SyncItemModel.fromDartMap(Map<String, Object?> map) {
    final metricsList = map['metrics'] as List<Object?>?;
    final scoreNum = map['score'] as num?;
    return SyncItemModel(
      uuid: map['uuid']! as String,
      sequence: map['sequence']! as int,
      title: map['title']! as String,
      status: map['status']! as String,
      score: scoreNum?.toDouble() ?? 0.0,
      metrics: metricsList?.cast<int>() ?? const [],
      active: map['active']! as bool,
    );
  }

  factory SyncItemModel.fromJsonReader(JsonReader reader) {
    return SyncItemModel(
      uuid: reader.readString('uuid') ?? '',
      sequence: reader.readInt('sequence') ?? 0,
      title: reader.readString('title') ?? '',
      status: reader.readString('status') ?? '',
      score: reader.readFloat('score') ?? 0.0,
      metrics: reader.readList<int>('metrics') ?? const [],
      active: reader.readBool('active') ?? false,
    );
  }

  final String uuid;
  final int sequence;
  final String title;
  final String status;
  final double score;
  final List<int> metrics;
  final bool active;

  Map<String, Object?> toDartMap() {
    return {
      'uuid': uuid,
      'sequence': sequence,
      'title': title,
      'status': status,
      'score': score,
      'metrics': metrics,
      'active': active,
    };
  }

  @override
  void toJson(JsonWriter writer) {
    writer.string('uuid', uuid);
    writer.integer('sequence', sequence);
    writer.string('title', title);
    writer.string('status', status);
    writer.float('score', score);
    writer.list<int>('metrics', metrics);
    writer.boolean('active', active);
  }
}

/// Helper container holding prepared dataset artifacts for benchmarks.
class BenchmarkDataset<T extends ToJson> {
  BenchmarkDataset._({
    required this.name,
    required this.dartMap,
    required this.utf8Bytes,
    this.singleModel,
    this.modelList,
  }) : byteSize = utf8Bytes.length;

  /// Creates Auth Response Dataset (~300 B)
  static BenchmarkDataset<AuthResponseModel> authResponse() {
    final model = AuthResponseModel.sample();
    final map = model.toDartMap();
    final bytes = Uint8List.fromList(stdJsonEncoder.convert(map));
    return BenchmarkDataset<AuthResponseModel>._(
      name: 'Auth Response (~300 B)',
      singleModel: model,
      dartMap: map,
      utf8Bytes: bytes,
    );
  }

  /// Creates User Profile Dataset (~2.5 KB)
  static BenchmarkDataset<UserProfileModel> userProfile() {
    final model = UserProfileModel.sample();
    final map = model.toDartMap();
    final bytes = Uint8List.fromList(stdJsonEncoder.convert(map));
    return BenchmarkDataset<UserProfileModel>._(
      name: 'User Profile (~2.5 KB)',
      singleModel: model,
      dartMap: map,
      utf8Bytes: bytes,
    );
  }

  /// Creates Product Catalog Feed Dataset (~100 KB)
  static BenchmarkDataset<ProductModel> productFeed({int count = 350}) {
    final models = List.generate(count, ProductModel.generate);
    final map = {'items': models.map((m) => m.toDartMap()).toList()};
    final bytes = Uint8List.fromList(stdJsonEncoder.convert(map));
    return BenchmarkDataset<ProductModel>._(
      name: 'Product Feed (~${(bytes.length / 1024).toStringAsFixed(1)} KB)',
      modelList: models,
      dartMap: map,
      utf8Bytes: bytes,
    );
  }

  /// Creates Log Events Dataset (~2 MB)
  static BenchmarkDataset<LogEventModel> logEvents({int count = 10500}) {
    final models = List.generate(count, LogEventModel.generate);
    final map = {'items': models.map((m) => m.toDartMap()).toList()};
    final bytes = Uint8List.fromList(stdJsonEncoder.convert(map));
    final mb = bytes.length / (1024 * 1024);
    return BenchmarkDataset<LogEventModel>._(
      name: 'Log Events (~${mb.toStringAsFixed(2)} MB)',
      modelList: models,
      dartMap: map,
      utf8Bytes: bytes,
    );
  }

  /// Creates Heavy Sync Data Dataset (~10 MB)
  static BenchmarkDataset<SyncItemModel> syncDump({int count = 50000}) {
    final models = List.generate(count, SyncItemModel.generate);
    final map = {'items': models.map((m) => m.toDartMap()).toList()};
    final bytes = Uint8List.fromList(stdJsonEncoder.convert(map));
    final mb = bytes.length / (1024 * 1024);
    return BenchmarkDataset<SyncItemModel>._(
      name: 'Heavy Sync Dump (~${mb.toStringAsFixed(2)} MB)',
      modelList: models,
      dartMap: map,
      utf8Bytes: bytes,
    );
  }

  final String name;
  final T? singleModel;
  final List<T>? modelList;
  final Map<String, Object?> dartMap;
  final Uint8List utf8Bytes;
  final int byteSize;
}

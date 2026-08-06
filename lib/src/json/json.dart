import 'dart:convert';
import 'dart:typed_data';

import 'package:json_codable/src/json/reader.dart';
import 'package:json_codable/src/json/writer.dart';
import 'package:json_codable/src/validation.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationError;

part 'dummy.dart';
part 'impl.dart';
part 'schema.dart';

/// Interface for objects that can be serialized to JSON.
abstract interface class ToJson {
  /// Writes this object's fields to [writer].
  void toJson(JsonWriter writer);
}

/// A strongly-typed wrapper around a JSON byte reader
/// for extracting and validating JSON fields.
abstract interface class JsonObject {
  factory JsonObject(
    Uint8List bytes, {
    int offset = 0,
    int? length,
  }) {
    return JsonObject.fromReader(
      JsonReader(bytes, offset: offset, length: length),
    );
  }

  factory JsonObject.fromReader(JsonReader reader) = _JsonObjectImpl;

  factory JsonObject.fromString(String src) {
    return _JsonObjectImpl.fromString(src);
  }

  factory JsonObject.fromMap(Map<String, Object?> map) {
    return _JsonObjectImpl.fromMap(map);
  }

  static Schema schema<T>(
    T Function(JsonObject json) mapper, {
    String? title,
    String? description,
  }) {
    final ctx = _SchemaContext();
    final json = _SchemaJsonObject(ctx);
    mapper(json);

    Schema? objectSchema;
    if (ctx.properties.isNotEmpty || ctx.oneOf.isEmpty) {
      objectSchema = Schema.object(
        title: ctx.oneOf.isEmpty ? title : null,
        description: ctx.oneOf.isEmpty ? description : null,
        properties: ctx.properties.isNotEmpty ? ctx.properties : null,
        required: ctx.requiredFields.isNotEmpty ? ctx.requiredFields : null,
      );
    }

    if (ctx.oneOf.isNotEmpty) {
      final combined = Schema.combined(
        title: objectSchema == null ? title : null,
        description: objectSchema == null ? description : null,
        oneOf: ctx.oneOf,
      );
      if (objectSchema != null) {
        return Schema.combined(
          title: title,
          description: description,
          allOf: [objectSchema, combined],
        );
      }
      return combined;
    }

    return objectSchema!;
  }

  JsonFieldExtractor get field;

  bool has(String key);

  T parse<T>(T Function(JsonObject json) mapper);

  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  );

  Object any(String key);

  Object? anyOrNull(String key);

  String string(String key, {List<ValidationRule<String>> rules = const []});

  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  });

  int integer(String key, {List<ValidationRule<num>> rules = const []});

  int? integerOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  });

  double float(String key, {List<ValidationRule<num>> rules = const []});

  double? floatOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  });

  bool boolean(String key);

  bool? booleanOrNull(String key);

  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  });

  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  });

  DateTime timestamp(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  });

  DateTime? timestampOrNull(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  });

  Uri uri(String key, {List<ValidationRule<String>> rules = const []});

  Uri? uriOrNull(String key, {List<ValidationRule<String>> rules = const []});

  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  });

  T? enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  });

  T object<T>(String key, T Function(JsonObject json) mapper);

  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper);

  List<T> list<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  });

  List<T>? listOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  });

  Map<String, T> map<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  });

  Map<String, T>? mapOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  });
}

/// Represents a field in a JSON object that can be either absent or present
/// (with a value or explicitly `null`).
sealed class JsonField<T> {
  const JsonField();

  const factory JsonField.absent() = JsonFieldAbsent;
  const factory JsonField.present(T value) = JsonFieldPresent<T>;

  /// Whether the field was present in the JSON object.
  bool get isPresent => this is JsonFieldPresent;

  /// Returns the value if present, or throws a [StateError] if absent.
  T get value => switch (this) {
    JsonFieldAbsent() => throw StateError('Field is absent'),
    JsonFieldPresent<T>(:final value) => value,
  };

  /// Returns the value if present, or `null` if absent.
  T? get valueOrNull => switch (this) {
    JsonFieldAbsent() => null,
    JsonFieldPresent<T>(:final value) => value,
  };
}

/// Represents an absent field in a JSON object.
final class JsonFieldAbsent extends JsonField<Never> {
  const JsonFieldAbsent();
}

/// Represents a present field in a JSON object.
final class JsonFieldPresent<T> extends JsonField<T> {
  const JsonFieldPresent(this.value);

  @override
  final T value;
}

/// Helper class for extracting fields as [JsonField] wrappers.
extension type const JsonFieldExtractor(JsonObject _json) {
  @pragma('vm:prefer-inline')
  JsonField<String> string(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.string(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<String?> stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.stringOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<int> integer(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.integer(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<int?> integerOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.integerOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<double> float(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.float(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<double?> floatOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.floatOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<bool> boolean(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.boolean(key));
  }

  @pragma('vm:prefer-inline')
  JsonField<bool?> booleanOrNull(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.booleanOrNull(key));
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime> dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.dateTime(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime?> dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.dateTimeOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime> timestamp(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(
      _json.timestamp(key, isSeconds: isSeconds, rules: rules),
    );
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime?> timestampOrNull(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(
      _json.timestampOrNull(key, isSeconds: isSeconds, rules: rules),
    );
  }

  @pragma('vm:prefer-inline')
  JsonField<Uri> uri(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.uri(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<Uri?> uriOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.uriOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<T> enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.enumeration<T>(key, values, by: by));
  }

  @pragma('vm:prefer-inline')
  JsonField<T?> enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.enumerationOrNull<T>(key, values, by: by));
  }

  @pragma('vm:prefer-inline')
  JsonField<T> object<T>(String key, T Function(JsonObject json) mapper) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.object(key, mapper));
  }

  @pragma('vm:prefer-inline')
  JsonField<T?> objectOrNull<T>(
    String key,
    T Function(JsonObject json) mapper,
  ) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.objectOrNull<T>(key, mapper));
  }

  @pragma('vm:prefer-inline')
  JsonField<List<T>> list<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.list<T>(key, mapper: mapper, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<List<T>?> listOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.listOrNull<T>(key, mapper: mapper, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<Map<String, T>> map<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.map<T>(key, mapper: mapper, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<Map<String, T>?> mapOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.mapOrNull<T>(key, mapper: mapper, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<Object> any(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.any(key));
  }

  @pragma('vm:prefer-inline')
  JsonField<Object?> anyOrNull(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.anyOrNull(key));
  }
}
